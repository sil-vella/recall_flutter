import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../plugins/main_plugin/modules/websocket_module/websocket_module.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WebSocketModule? _websocketModule;
  String? _currentRoomId;
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _logController = TextEditingController();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _websocketModule = Provider.of<WebSocketModule>(context, listen: false);
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dutch Card Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectWebSocket,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    enabled: !_isConnected,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _currentRoomId == null ? _joinGame : _leaveGame,
                  child: Text(_currentRoomId == null ? 'Join Game' : 'Leave Game'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentRoomId != null)
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
      ),
    );
  }
} 