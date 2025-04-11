import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/module_manager.dart';
import '../../../../../core/managers/services_manager.dart';
import '../../../../../tools/logging/logger.dart';
import '../../../../../core/00_base/screen_base.dart';
import '../../../../../core/managers/navigation_manager.dart';
import '../../../main_plugin/modules/websocket_module/components/result_handler.dart';
import '../../../main_plugin/modules/websocket_module/websocket_module.dart';
import '../../../main_plugin/modules/login_module/login_module.dart';
import 'components/components.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class GameScreen extends BaseScreen {
  const GameScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) => 'Dutch Card Game';

  @override
  BaseScreenState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends BaseScreenState<GameScreen> {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  WebSocketModule? _websocketModule;
  LoginModule? _loginModule;
  
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _logController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnected = false;
  String? _currentRoomId;
  Map<String, dynamic>? _roomState;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initDependencies();
    _setupWebSocketListeners();
    _getUserId();
  }

  void _initDependencies() {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _websocketModule = _moduleManager.getLatestModule<WebSocketModule>();
    _loginModule = _moduleManager.getLatestModule<LoginModule>();
  }

  Future<void> _getUserId() async {
    try {
      if (_loginModule == null) {
        _log.error("❌ LoginModule not available");
        _logController.text += "❌ Error: Login module not available\n";
        _scrollToBottom();
        return;
      }

      final userStatus = await _loginModule!.getUserStatus(context);
      
      if (userStatus["status"] != "logged_in") {
        _log.error("❌ User is not logged in");
        _logController.text += "❌ Error: User is not logged in\n";
        _scrollToBottom();
        // Navigate to account screen using GoRouter
        if (mounted) {
          _log.info("🔀 Navigating to account screen due to token expiration");
          context.go('/account');
        }
        return;
      }

      final userId = userStatus["user_id"];
      if (userId == null) {
        _log.error("❌ User ID not found");
        _logController.text += "❌ Error: User ID not found\n";
        _scrollToBottom();
        return;
      }

      setState(() {
        _userId = userId.toString();
      });
      _logController.text += "✅ User ID retrieved: $_userId\n";
      _scrollToBottom();
    } catch (e) {
      _log.error("❌ Error getting user ID: $e");
      _logController.text += "❌ Error getting user ID: $e\n";
      _scrollToBottom();
    }
  }

  void _setupWebSocketListeners() {
    _websocketModule?.eventStream.listen((event) {
      if (!mounted) return;

      switch (event['type']) {
        case 'room_joined':
          setState(() {
            _currentRoomId = event['data']['room_id'];
          });
          _logController.text += "✅ Successfully joined room: ${event['data']['room_id']}\n";
          _scrollToBottom();
          break;
        case 'room_created':
          setState(() {
            _currentRoomId = event['data']['room_id'];
          });
          _logController.text += "✅ Room created: ${event['data']['room_id']}\n";
          _scrollToBottom();
          break;
        case 'room_state':
          setState(() {
            _roomState = event['data'];
          });
          _logController.text += "📊 Room state updated\n";
          _scrollToBottom();
          break;
        case 'error':
          if (event['data']['message']?.contains('Failed to join room') == true) {
            setState(() {
              _currentRoomId = null;
            });
          }
          _logController.text += "❌ Error: ${event['data']['message']}\n";
          _scrollToBottom();
          break;
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _connectToWebSocket() async {
    try {
      _logController.text += "⏳ Connecting to WebSocket server...\n";
      _scrollToBottom();
      
      // Check if user is logged in before attempting to connect
      if (_loginModule != null) {
        final userStatus = await _loginModule!.getUserStatus(context);
        if (userStatus["status"] != "logged_in") {
          _logController.text += "❌ User is not logged in. Please log in again.\n";
          _scrollToBottom();
          // Navigate to account screen using GoRouter
          if (mounted) {
            _log.info("🔀 Navigating to account screen due to token expiration");
            context.go('/account');
          }
          return;
        }
      }
      
      final result = await _websocketModule?.connect(context);
      if (result == null || !result.isSuccess) {
        setState(() {
          _isConnected = false;
          _currentRoomId = null;
        });
        _logController.text += "❌ Failed to connect to WebSocket server: ${result?.error ?? 'Unknown error'}\n";
        
        // Handle token expiration
        if (result?.error?.contains('token') == true && _loginModule != null) {
          _logController.text += "❌ Session expired. Please log in again.\n";
          _scrollToBottom();
          
          // Logout user
          await _loginModule!.logoutUser(context);
          
          // Navigate to account screen using GoRouter
          if (mounted) {
            _log.info("🔀 Navigating to account screen due to token expiration");
            context.go('/account');
          }
          return;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to WebSocket server: ${result?.error ?? 'Unknown error'}'),
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
      _scrollToBottom();
      
    } catch (e) {
      setState(() {
        _isConnected = false;
        _currentRoomId = null;
      });
      _logController.text += "❌ Error connecting to WebSocket server: $e\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to WebSocket server: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectFromWebSocket() async {
    try {
      _logController.text += "⏳ Disconnecting from WebSocket server...\n";
      _scrollToBottom();
      
      await _websocketModule?.disconnect();
      
      setState(() {
        _isConnected = false;
        _currentRoomId = null;
      });
      _logController.text += "✅ Disconnected from WebSocket server\n";
      _scrollToBottom();
      
    } catch (e) {
      _logController.text += "❌ Error disconnecting from WebSocket server: $e\n";
      _scrollToBottom();
    }
  }

  Future<void> _createRoom() async {
    if (_userId == null) {
      _logController.text += "❌ Cannot create room: User ID not available\n";
      _scrollToBottom();
      return;
    }

    try {
      _log.info("🔍 _createRoom method called");
      _log.info("🔍 User ID: $_userId");
      _log.info("🔍 WebSocket module: ${_websocketModule != null ? 'available' : 'null'}");
      
      _logController.text += "⏳ Creating new room...\n";
      _scrollToBottom();
      
      // Create the room
      final result = await _websocketModule?.createRoom(_userId!);
      _log.info("🔍 Create room result: ${result?.isSuccess}");
      
      if (result == null || !result.isSuccess) {
        _log.error("❌ Failed to create room: ${result?.error ?? 'Unknown error'}");
        _logController.text += "❌ Failed to create room: ${result?.error ?? 'Unknown error'}\n";
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create room: ${result?.error ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // The room state will be updated by the event listener in _setupWebSocketListeners
      _logController.text += "✅ Room creation request sent\n";
      _scrollToBottom();
      
    } catch (e) {
      _log.error("❌ Error creating room: $e");
      _logController.text += "❌ Error creating room: $e\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinGame() async {
    _log.info("🔍 _joinGame method called");
    _log.info("🔍 Room ID: ${_roomController.text}");
    _log.info("🔍 WebSocket module: ${_websocketModule != null ? 'available' : 'null'}");
    
    if (_roomController.text.isEmpty) {
      _log.error("❌ Cannot join game: Room ID is empty");
      return;
    }
    
    try {
      _log.info("⏳ Attempting to join game: ${_roomController.text}");
      
      // Create a completer to wait for the room_joined event
      final completer = Completer<bool>();
      
      // Set up a one-time listener for the room_joined event
      final subscription = _websocketModule?.eventStream.listen((event) {
        if (event['type'] == 'room_joined' && event['data']['room_id'] == _roomController.text) {
          completer.complete(true);
        } else if (event['type'] == 'error' && event['data']['message']?.contains('Failed to join room') == true) {
          completer.complete(false);
        }
      });
      
      // Join the game room
      final result = await _websocketModule?.joinGame(_roomController.text);
      _log.info("🔍 Join game result: ${result?.isSuccess}");
      
      if (result == null || !result.isSuccess) {
        _log.error("❌ Failed to join game room: ${result?.error ?? 'Unknown error'}");
        _logController.text += "❌ Failed to join game room: ${result?.error ?? 'Unknown error'}\n";
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join game room: ${result?.error ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        subscription?.cancel();
        return;
      }
      
      // Wait for the room_joined event with a timeout
      final success = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log.error("❌ Timeout waiting for room join confirmation");
          return false;
        },
      );
      
      subscription?.cancel();
      
      if (!success) {
        _log.error("❌ Failed to join game room: Room does not exist or join failed");
        _logController.text += "❌ Failed to join game room: Room does not exist or join failed\n";
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to join game room: Room does not exist or join failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // State update is now handled by the event listener
      _logController.text += "✅ Successfully joined game room: ${_roomController.text}\n";
      _scrollToBottom();
      
    } catch (e) {
      _log.error("❌ Error joining game: $e");
      _logController.text += "❌ Error joining game: $e\n";
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _logController.dispose();
    _scrollController.dispose();
    _websocketModule?.disconnect();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ConnectionStatus(
              isConnected: _isConnected,
              onConnect: _connectToWebSocket,
              onDisconnect: _disconnectFromWebSocket,
              currentRoomId: _currentRoomId,
            ),
            const SizedBox(height: 8),
            if (_isConnected) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CreateGame(
                      onCreateGame: _createRoom,
                      isConnected: _isConnected,
                      currentRoomId: _currentRoomId,
                      userId: _userId,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: JoinGame(
                      roomController: _roomController,
                      onJoinGame: _joinGame,
                      isConnected: _isConnected,
                      currentRoomId: _currentRoomId,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GameState(
                isConnected: _isConnected,
                currentRoomId: _currentRoomId,
                roomState: _roomState,
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 200, // Fixed height for the log
              child: GameLog(
                logController: _logController,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 