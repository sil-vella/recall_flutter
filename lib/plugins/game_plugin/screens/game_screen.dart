import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/managers/module_manager.dart';
import '../../../core/00_base/screen_base.dart';
import '../../../plugins/main_plugin/modules/login_module/login_module.dart';
import '../../../plugins/main_plugin/modules/websocket_module/websocket_module.dart';
import '../../../core/managers/app_manager.dart';

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
    if (_currentRoomId == null) return;
    
    try {
      bool joined = await _websocketModule?.joinRoom(_currentRoomId!) ?? false;
      if (joined) {
        _logController.text += "⚡ Joining game: $_currentRoomId\n";
      } else {
        _logController.text += "❌ Failed to join game\n";
      }
    } catch (e) {
      _logController.text += "❌ Error joining game: $e\n";
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

  void _updateRoomId(String value) {
    setState(() {
      _currentRoomId = value;
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: 'Game Room ID',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _updateRoomId,
                  enabled: !_isConnected && _isLoggedIn,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isLoggedIn ? (_currentRoomId == null ? _joinGame : _leaveGame) : null,
                child: Text(_currentRoomId == null ? 'Join Game' : 'Leave Game'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentRoomId != null && _isLoggedIn)
            ElevatedButton(
              onPressed: _startGame,
              child: const Text('Start Game'),
            ),
          const SizedBox(height: 16),
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
} 