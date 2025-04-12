import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/module_manager.dart';
import '../../../../../core/managers/services_manager.dart';
import '../../../../../tools/logging/logger.dart';
import '../../../../../core/00_base/screen_base.dart';
import '../../../../../core/managers/navigation_manager.dart';
import '../../../../../core/managers/state_manager.dart';
import '../../../../../core/services/shared_preferences.dart';
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
  StateManager? _stateManager;
  WebSocketModule? _websocketModule;
  LoginModule? _loginModule;
  
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _logController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Add completers for room operations
  Completer<bool>? _roomCreationCompleter;
  Completer<bool>? _roomJoinCompleter;

  @override
  void initState() {
    super.initState();
    _initDependencies();
    _setupWebSocketListeners();
    // Move _getUserId to after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getUserId();
    });
  }

  void _initDependencies() {
    try {
      _moduleManager = Provider.of<ModuleManager>(context, listen: false);
      _servicesManager = Provider.of<ServicesManager>(context, listen: false);
      _stateManager = Provider.of<StateManager>(context, listen: false);
      _websocketModule = _moduleManager.getLatestModule<WebSocketModule>();
      _loginModule = _moduleManager.getLatestModule<LoginModule>();

      if (_stateManager == null) {
        _log.error("❌ StateManager not available");
        _logController.text += "❌ Error: State manager not available\n";
        _scrollToBottom();
      }
    } catch (e) {
      _log.error("❌ Error initializing dependencies: $e");
      _logController.text += "❌ Error initializing dependencies: $e\n";
      _scrollToBottom();
    }
  }

  void _updateRoomState(Map<String, dynamic> newState) {
    if (!mounted || _stateManager == null) return;
    try {
      final currentState = _stateManager!.getPluginState<Map<String, dynamic>>("game_room") ?? {};
      _stateManager!.updatePluginState("game_room", <String, dynamic>{...currentState, ...newState});
    } catch (e) {
      _log.error("❌ Error updating room state: $e");
      _logController.text += "❌ Error updating room state: $e\n";
      _scrollToBottom();
    }
  }

  Map<String, dynamic> get roomState {
    if (_stateManager == null) return {};
    try {
      return _stateManager!.getPluginState<Map<String, dynamic>>("game_room") ?? {};
    } catch (e) {
      _log.error("❌ Error getting room state: $e");
      return {};
    }
  }

  String? get currentRoomId => roomState["roomId"];
  bool get isConnected => roomState["isConnected"] ?? false;
  String? get userId => roomState["userId"];
  String? get joinLink {
    if (currentRoomId == null || _servicesManager == null) return null;
    try {
      return '${_servicesManager.getService<SharedPrefManager>('shared_pref')?.get('base_url')}/game/join/$currentRoomId';
    } catch (e) {
      _log.error("❌ Error getting join link: $e");
      return null;
    }
  }

  Future<void> _getUserId() async {
    if (!mounted) return;
    
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

      _updateRoomState(<String, dynamic>{"userId": userId.toString()});
      _logController.text += "✅ User ID retrieved: $userId\n";
      _scrollToBottom();
    } catch (e) {
      _log.error("❌ Error getting user ID: $e");
      _logController.text += "❌ Error getting user ID: $e\n";
      _scrollToBottom();
    }
  }

  void _setupWebSocketListeners() {
    if (_websocketModule == null || _stateManager == null) {
      _log.error("❌ WebSocket module or state manager not available");
      _logController.text += "❌ Error: WebSocket module or state manager not available\n";
      _scrollToBottom();
      return;
    }

    _websocketModule!.eventStream.listen((event) {
      if (!mounted || _stateManager == null) return;

      try {
        switch (event['type']) {
          case 'room_joined':
            _stateManager!.updatePluginState("game_room", <String, dynamic>{
              "roomId": event['data']['room_id'],
              "isConnected": true,
              "roomState": <String, dynamic>{
                "current_size": event['data']['current_size'],
                "max_size": event['data']['max_size'],
              },
              "isLoading": false,
              "error": null,
            });
            _logController.text += "✅ Successfully joined room: ${event['data']['room_id']}\n";
            _scrollToBottom();
            _roomJoinCompleter?.complete(true);
            _roomJoinCompleter = null;
            break;
          case 'room_created':
            _log.info("📨 Received room_created event: ${event['data']}");
            _stateManager!.updatePluginState("game_room", <String, dynamic>{
              "roomId": event['data']['room_id'],
              "isConnected": true,
              "roomState": <String, dynamic>{
                "current_size": event['data']['current_size'],
                "max_size": event['data']['max_size'],
                "owner_id": event['data']['owner_id'],
                "owner_username": event['data']['owner_username'],
                "permission": event['data']['permission'],
                "allowed_users": event['data']['allowed_users'],
                "allowed_roles": event['data']['allowed_roles'],
                "join_link": event['data']['join_link'],
              },
              "joinLink": event['data']['join_link'],
              "isLoading": false,
              "error": null,
            });
            _log.info("✅ Updated state for 'game_room': ${_stateManager!.getPluginState<Map<String, dynamic>>("game_room")}");
            _logController.text += "✅ Room created: ${event['data']['room_id']}\n";
            _scrollToBottom();
            _roomCreationCompleter?.complete(true);
            _roomCreationCompleter = null;
            break;
          case 'room_state':
            final currentState = _stateManager!.getPluginState<Map<String, dynamic>>("game_room") ?? {};
            _stateManager!.updatePluginState("game_room", <String, dynamic>{
              ...currentState,
              "roomState": <String, dynamic>{
                ...currentState["roomState"] ?? {},
                ...event['data'],
              },
            });
            _logController.text += "📊 Room state updated\n";
            _scrollToBottom();
            break;
          case 'error':
            if (event['data']['message']?.contains('Failed to join room') == true) {
              _stateManager!.updatePluginState("game_room", <String, dynamic>{
                "roomId": null,
                "roomState": null,
                "isLoading": false,
                "error": event['data']['message'],
              });
              _roomJoinCompleter?.complete(false);
              _roomJoinCompleter = null;
            }
            _logController.text += "❌ Error: ${event['data']['message']}\n";
            _scrollToBottom();
            break;
        }
      } catch (e) {
        _log.error("❌ Error handling WebSocket event: $e");
        _logController.text += "❌ Error handling WebSocket event: $e\n";
        _scrollToBottom();
      }
    });
  }

  Future<void> _connectToWebSocket() async {
    try {
      _logController.text += "⏳ Connecting to WebSocket server...\n";
      _scrollToBottom();
      
      if (_loginModule != null) {
        final userStatus = await _loginModule!.getUserStatus(context);
        if (userStatus["status"] != "logged_in") {
          _logController.text += "❌ User is not logged in. Please log in again.\n";
          _scrollToBottom();
          if (mounted) {
            _log.info("🔀 Navigating to account screen due to token expiration");
            context.go('/account');
          }
          return;
        }
      }
      
      final result = await _websocketModule?.connect(context);
      if (result == null || !result) {
        _stateManager!.updatePluginState("game_room", {
          "isConnected": false,
          "roomId": null,
          "isLoading": false,
          "error": "Failed to connect to WebSocket server"
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
      
      _stateManager!.updatePluginState("game_room", {
        "isConnected": true,
        "isLoading": false,
        "error": null
      });
      _logController.text += "✅ Connected to WebSocket server\n";
      _scrollToBottom();
      
    } catch (e) {
      _stateManager!.updatePluginState("game_room", {
        "isConnected": false,
        "roomId": null,
        "isLoading": false,
        "error": e.toString()
      });
      _logController.text += "❌ Error connecting to WebSocket server: $e\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting to WebSocket server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectFromWebSocket() async {
    if (!mounted || _websocketModule == null) return;
    
    try {
      _logController.text += "⏳ Disconnecting from WebSocket server...\n";
      _scrollToBottom();
      
      await _websocketModule?.disconnect();
      
      _updateRoomState({
        "isConnected": false,
        "roomId": null,
        "roomState": null,
        "isLoading": false,
        "error": null
      });
      _logController.text += "✅ Disconnected from WebSocket server\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from WebSocket server'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _log.error("❌ Error disconnecting from WebSocket server: $e");
      _logController.text += "❌ Error disconnecting from WebSocket server: $e\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _createRoom() async {
    if (userId == null) {
      _logController.text += "❌ Cannot create room: User ID not available\n";
      _scrollToBottom();
      return;
    }

    try {
      _log.info("🔍 _createRoom method called");
      _log.info("🔍 User ID: $userId");
      _log.info("🔍 WebSocket module: ${_websocketModule != null ? 'available' : 'null'}");
      
      _updateRoomState(<String, dynamic>{"isLoading": true});
      _logController.text += "⏳ Creating new room...\n";
      _scrollToBottom();
      
      // Create a completer to wait for the room_created event
      _roomCreationCompleter = Completer<bool>();
      
      // Send the createRoom request
      final result = await _websocketModule?.createRoom(userId!);
      _log.info("🔍 Create room result: ${result?.isSuccess}");
      
      if (result == null || !result.isSuccess) {
        _updateRoomState(<String, dynamic>{
          "isLoading": false,
          "error": result?.error ?? 'Unknown error',
        });
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

      // Wait for the room_created event with a timeout
      try {
        await _roomCreationCompleter?.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _log.error("❌ Timeout waiting for room_created event");
            return false;
          },
        );
      } finally {
        _roomCreationCompleter = null;
      }
      
      _logController.text += "✅ Room created successfully\n";
      _scrollToBottom();
      
    } catch (e) {
      _updateRoomState(<String, dynamic>{
        "isLoading": false,
        "error": e.toString(),
      });
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
      _updateRoomState({
        "error": "Room ID cannot be empty",
      });
      _log.error("❌ Cannot join game: Room ID is empty");
      return;
    }
    
    try {
      _log.info("⏳ Attempting to join game: ${_roomController.text}");
      _updateRoomState({"isLoading": true});
      
      final completer = Completer<bool>();
      
      final subscription = _websocketModule?.eventStream.listen((event) {
        if (event['type'] == 'room_joined' && event['data']['room_id'] == _roomController.text) {
          completer.complete(true);
        } else if (event['type'] == 'error' && event['data']['message']?.contains('Failed to join room') == true) {
          completer.complete(false);
        }
      });
      
      final result = await _websocketModule?.joinGame(_roomController.text);
      _log.info("🔍 Join game result: ${result?.isSuccess}");
      
      if (result == null || !result.isSuccess) {
        _updateRoomState({
          "isLoading": false,
          "error": result?.error ?? 'Unknown error',
        });
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
      
      final success = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log.error("❌ Timeout waiting for room join confirmation");
          return false;
        },
      );
      
      subscription?.cancel();
      
      if (!success) {
        _updateRoomState({
          "isLoading": false,
          "error": "Room does not exist or join failed",
        });
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
      
      _updateRoomState({
        "isLoading": false,
        "error": null,
      });
      _logController.text += "✅ Successfully joined game room: ${_roomController.text}\n";
      _scrollToBottom();
      
    } catch (e) {
      _updateRoomState({
        "isLoading": false,
        "error": e.toString(),
      });
      _log.error("❌ Error joining game: $e");
      _logController.text += "❌ Error joining game: $e\n";
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void deactivate() {
    _log.info("🔄 Game screen deactivated - maintaining WebSocket connection");
    super.deactivate();
  }

  @override
  void dispose() {
    _log.info("🗑️ Game screen disposed - cleaning up resources");
    _roomController.dispose();
    _logController.dispose();
    _scrollController.dispose();
    _disconnectFromWebSocket();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final roomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final currentRoomId = roomState["roomId"];
        final isConnected = roomState["isConnected"] ?? false;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ConnectionStatus(
                  isConnected: isConnected,
                  onConnect: _connectToWebSocket,
                  onDisconnect: _disconnectFromWebSocket,
                  currentRoomId: currentRoomId,
                ),
                const SizedBox(height: 8),
                if (isConnected) ...[
                  if (currentRoomId == null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CreateGame(
                            onCreateGame: _createRoom,
                            isConnected: isConnected,
                            currentRoomId: currentRoomId,
                            userId: userId,
                            joinLink: joinLink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: JoinGame(
                            roomController: _roomController,
                            onJoinGame: _joinGame,
                            isConnected: isConnected,
                            currentRoomId: currentRoomId,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    GameState(
                      isConnected: isConnected,
                      currentRoomId: currentRoomId,
                      roomState: roomState["roomState"],
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: GameLog(
                    logController: _logController,
                    scrollController: _scrollController,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 