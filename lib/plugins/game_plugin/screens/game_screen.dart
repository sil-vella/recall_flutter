import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/managers/module_manager.dart';
import '../../../core/00_base/screen_base.dart';
import '../../../plugins/main_plugin/modules/login_module/login_module.dart';
import '../../../plugins/main_plugin/modules/websocket_module/websocket_module.dart';
import '../../../core/managers/app_manager.dart';
import '../../../utils/consts/theme_consts.dart';

class GameScreen extends BaseScreen {
  const GameScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) => 'Dutch Card Game';

  @override
  BaseScreenState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends BaseScreenState<GameScreen> {
  WebSocketModule? _websocketModule;
  LoginModule? _loginModule;
  String? _currentRoomId;
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _logController = TextEditingController();
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _username;
  bool _showCreateGame = false; // Toggle between join and create game

  @override
  void initState() {
    super.initState();
    _logController.text = "Initializing game screen...\n";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) {
      final moduleManager = Provider.of<ModuleManager>(context, listen: false);
      
      // Get the latest WebSocket module instance
      _websocketModule = moduleManager.getLatestModule<WebSocketModule>();
      
      // Get the login module
      _loginModule = moduleManager.getLatestModule<LoginModule>();
      
      // Check login status
      _checkLoginStatus();
      
      if (_websocketModule == null) {
        _logController.text += "❌ Error: WebSocket module not available. Please restart the app.\n";
      } else {
        _logController.text += "✅ WebSocket module found. Ready to connect.\n";
        _setupWebSocketListeners();
      }
      
      _isInitialized = true;
    }
  }

  Future<void> _checkLoginStatus() async {
    if (_loginModule == null) {
      _logController.text += "❌ Error: Login module not available.\n";
      return;
    }
    
    final status = await _loginModule!.getUserStatus(context);
    
    setState(() {
      _isLoggedIn = status["status"] == "logged_in";
      _username = status["username"];
    });
    
    if (_isLoggedIn) {
      _logController.text += "✅ Logged in as: $_username\n";
    } else {
      _logController.text += "⚠️ You need to log in to play the game.\n";
    }
  }

  void _navigateToAccount() {
    context.go('/account');
  }

  void _setupWebSocketListeners() {
    if (_websocketModule == null) return;
    
    _websocketModule?.eventStream.listen((event) {
      switch (event['type']) {
        case 'room_joined':
          setState(() {
            _isConnected = true;
          });
          _logController.text += "✅ Successfully joined game room\n";
          break;
        case 'user_joined':
          _logController.text += "👤 ${event['data']['username']} joined the game\n";
          break;
        case 'user_left':
          _logController.text += "👋 ${event['data']['username']} left the game\n";
          break;
        case 'room_state':
          _logController.text += "🏠 Room state updated: ${event['data']['current_size']}/${event['data']['max_size']} players\n";
          break;
        case 'error':
          setState(() {
            _isConnected = false;
          });
          _logController.text += "❌ Error: ${event['data']['message']}\n";
          break;
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (_roomController.text.isEmpty) {
      _logController.text += "❌ Please enter a game room ID\n";
      return;
    }

    try {
      bool connected = await _websocketModule?.connect(context) ?? false;
      if (connected) {
        setState(() {
          _isConnected = true;
        });
        _logController.text += "✅ Connected to WebSocket server\n";
        await _joinGame();
      } else {
        setState(() {
          _isConnected = false;
        });
        _logController.text += "❌ Failed to connect to WebSocket server\n";
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      _logController.text += "❌ Error connecting to WebSocket: $e\n";
    }
  }

  Future<void> _joinGame() async {
    if (_roomController.text.isEmpty) return;
    
    try {
      // First, ensure we're connected to the WebSocket server
      if (!_isConnected) {
        bool connected = await _websocketModule?.connect(context) ?? false;
        if (!connected) {
          setState(() {
            _isConnected = false;
            _currentRoomId = null;
          });
          _logController.text += "❌ Failed to connect to WebSocket server\n";
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to connect to WebSocket server'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _isConnected = true;
        });
        _logController.text += "✅ Connected to WebSocket server\n";
      }
      
      // Now that we're connected, set the room ID and join the room
      setState(() {
        _currentRoomId = _roomController.text;
      });
      
      bool joined = await _websocketModule?.joinRoom(_currentRoomId!) ?? false;
      if (joined) {
        _logController.text += "✅ Successfully joined game room: $_currentRoomId\n";
      } else {
        setState(() {
          _isConnected = false;
          _currentRoomId = null;
        });
        _logController.text += "❌ Failed to join game room\n";
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to join game room'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _currentRoomId = null;
      });
      _logController.text += "❌ Error joining game: $e\n";
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Room does not exist') 
              ? 'Room does not exist' 
              : 'Failed to join game room'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveGame() async {
    if (_currentRoomId == null) return;
    
    try {
      await _websocketModule?.leaveRoom(_currentRoomId!);
      setState(() {
        _currentRoomId = null;
        _isConnected = false;
      });
      _logController.text += "⚡ Left game: $_currentRoomId\n";
    } catch (e) {
      _logController.text += "❌ Error leaving game: $e\n";
    }
  }

  Future<void> _startGame() async {
    if (_currentRoomId == null) return;
    
    try {
      await _websocketModule?.sendMessage('start_game');
      _logController.text += "⚡ Starting game\n";
    } catch (e) {
      _logController.text += "❌ Error starting game: $e\n";
    }
  }

  Future<void> _createGame() async {
    try {
      // First, ensure we're connected to the WebSocket server
      if (!_isConnected) {
        bool connected = await _websocketModule?.connect(context) ?? false;
        if (!connected) {
          setState(() {
            _isConnected = false;
          });
          _logController.text += "❌ Failed to connect to WebSocket server\n";
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to connect to WebSocket server'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _isConnected = true;
        });
        _logController.text += "✅ Connected to WebSocket server\n";
      }
      
      // Generate a random room ID
      final randomRoomId = DateTime.now().millisecondsSinceEpoch.toString().substring(0, 6);
      
      setState(() {
        _currentRoomId = randomRoomId;
        _roomController.text = randomRoomId;
      });
      
      _logController.text += "🏠 Created new game room: $randomRoomId\n";
      
      // Join the room
      bool joined = await _websocketModule?.joinRoom(randomRoomId) ?? false;
      if (joined) {
        _logController.text += "✅ Successfully joined game room: $randomRoomId\n";
      } else {
        setState(() {
          _isConnected = false;
          _currentRoomId = null;
        });
        _logController.text += "❌ Failed to join game room\n";
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to join game room'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _currentRoomId = null;
      });
      _logController.text += "❌ Error creating game: $e\n";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating game: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateRoomId(String value) {
    setState(() {
      _currentRoomId = value;
    });
  }

  void _toggleGameMode() {
    setState(() {
      _showCreateGame = !_showCreateGame;
    });
  }

  @override
  void dispose() {
    _websocketModule?.disconnect();
    _roomController.dispose();
    _logController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoggedIn ? _connectWebSocket : null,
              ),
            ],
          ),
          if (!_isLoggedIn)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                children: [
                  const Text(
                    'You need to log in to play the game',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToAccount,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Go to Account'),
                  ),
                ],
              ),
            ),
          if (!_isLoggedIn) const SizedBox(height: 16),
          
          // Game mode toggle
          if (_isLoggedIn)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Game Mode: '),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Join Game'),
                          icon: Icon(Icons.group_add),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Create Game'),
                          icon: Icon(Icons.add_circle),
                        ),
                      ],
                      selected: {_showCreateGame},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _showCreateGame = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Game components based on selected mode
          if (_isLoggedIn)
            _showCreateGame
                ? _buildCreateGameComponent()
                : _buildJoinGameComponent(),
          
          const SizedBox(height: 16),
          
          // Game log
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _logController,
                  maxLines: null,
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Game logs will appear here...',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildJoinGameComponent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join Existing Game',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Game Room ID',
                border: OutlineInputBorder(),
                hintText: 'Enter the room ID to join',
              ),
              onChanged: _updateRoomId,
              enabled: !_isConnected,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _isConnected ? null : () async {
                  if (_roomController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a room ID')),
                    );
                    return;
                  }
                  await _joinGame();
                },
                child: Text(_isConnected ? 'Connected' : 'Join Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreateGameComponent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Game',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a new game room and invite friends to join.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _createGame,
                icon: const Icon(Icons.add_circle),
                label: const Text('Create Game Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            if (_currentRoomId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Game Room Created!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Room ID: $_currentRoomId'),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this ID with friends to join your game.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 