import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../tools/logging/logger.dart';
import 'websocket_module.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({Key? key}) : super(key: key);

  @override
  _WebSocketTestScreenState createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  WebSocketModule? _websocketModule;
  final _roomController = TextEditingController();
  final _messageController = TextEditingController();
  final _logController = TextEditingController();
  bool _isConnected = false;
  String? _currentRoomId;
  int _counter = 0;
  List<String> _users = [];
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initDependencies();
  }

  void _initDependencies() {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _websocketModule = _moduleManager.getModuleInstance<WebSocketModule>('websocket_module');
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _eventSubscription?.cancel();
    _eventSubscription = _websocketModule?.eventStream.listen((event) {
      setState(() {
        switch (event['type']) {
          case 'session_data':
            _logController.text += "✅ Session data received\n";
            break;
          case 'user_joined':
            _logController.text += "👤 User joined: ${event['data']}\n";
            _users.add(event['data']['user_id']);
            break;
          case 'user_left':
            _logController.text += "👋 User left: ${event['data']}\n";
            _users.remove(event['data']['user_id']);
            break;
          case 'counter_update':
            _logController.text += "🔢 Counter updated: ${event['data']}\n";
            _counter = event['data']['value'];
            break;
          case 'users_list':
            _logController.text += "👥 Users list updated: ${event['data']}\n";
            _users = List<String>.from(event['data']['users']);
            break;
          case 'error':
            _logController.text += "❌ Error: ${event['data']}\n";
            break;
        }
      });
    });
  }

  Future<void> _connectWebSocket() async {
    if (_roomController.text.isEmpty) {
      _log.error("❌ Please enter a room ID");
      return;
    }

    final success = await _websocketModule?.connect(context, roomId: _roomController.text);
    if (success == true) {
      setState(() {
        _isConnected = true;
        _currentRoomId = _roomController.text;
      });
      _logController.text += "✅ Connected to WebSocket server\n";
      await _joinRoom();
    } else {
      _logController.text += "❌ Failed to connect to WebSocket server\n";
    }
  }

  Future<void> _joinRoom() async {
    if (_currentRoomId == null) return;
    await _websocketModule?.joinRoom(_currentRoomId!);
    _logController.text += "⚡ Joining room: $_currentRoomId\n";
  }

  Future<void> _leaveRoom() async {
    if (_currentRoomId == null) return;
    await _websocketModule?.leaveRoom(_currentRoomId!);
    setState(() {
      _currentRoomId = null;
      _users.clear();
    });
    _logController.text += "⚡ Left room: $_currentRoomId\n";
  }

  Future<void> _getCounter() async {
    await _websocketModule?.getCounter();
    _logController.text += "⚡ Requesting counter value\n";
  }

  Future<void> _getUsers() async {
    await _websocketModule?.getUsers();
    _logController.text += "⚡ Requesting users list\n";
  }

  Future<void> _pressButton() async {
    await _websocketModule?.pressButton();
    _logController.text += "⚡ Button pressed\n";
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    await _websocketModule?.sendMessage(_messageController.text);
    _logController.text += "⚡ Sending message: ${_messageController.text}\n";
    _messageController.clear();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _roomController.dispose();
    _messageController.dispose();
    _logController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status and Room Selection
            Card(
              child: Padding(
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
                              labelText: 'Room ID',
                              hintText: 'Enter room ID',
                            ),
                            enabled: !_isConnected,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (_isConnected)
                          ElevatedButton(
                            onPressed: _leaveRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Leave Room'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _connectWebSocket,
                            child: const Text('Connect'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${_isConnected ? "Connected" : "Disconnected"}',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_currentRoomId != null)
                      Text('Current Room: $_currentRoomId'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Counter Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Counter: $_counter',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _pressButton,
                          child: const Text('Press Button'),
                        ),
                        ElevatedButton(
                          onPressed: _getCounter,
                          child: const Text('Get Counter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Users Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Users in Room',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _getUsers,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_users.isEmpty)
                      const Text('No users in room')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(_users[index]),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Enter message',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: const Text('Send Message'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Log Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Log',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: TextField(
                        controller: _logController,
                        maxLines: null,
                        readOnly: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 