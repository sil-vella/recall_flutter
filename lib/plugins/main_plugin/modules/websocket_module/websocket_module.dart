import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../core/managers/state_manager.dart';
import '../../../../plugins/main_plugin/modules/connections_api_module/connections_api_module.dart';
import '../../../../utils/consts/config.dart';
import '../../../../plugins/main_plugin/modules/login_module/login_module.dart';

import 'components/socket_connection_manager.dart';
import 'components/room_manager.dart';
import 'components/session_manager.dart';
import 'components/token_manager.dart';
import 'components/event_handler.dart';

class WebSocketModule extends ModuleBase {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  SharedPrefManager? _sharedPref;
  ConnectionsApiModule? _connectionModule;
  BuildContext? _currentContext;
  bool _mounted = true;

  // Components
  late SocketConnectionManager _socketManager;
  late RoomManager _roomManager;
  late SessionManager _sessionManager;
  late TokenManager _tokenManager;
  late EventHandler _eventHandler;

  WebSocketModule() : super("websocket_module") {
    _log.info('✅ WebSocketModule initialized.');
  }

  void _initDependencies(BuildContext context) {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _connectionModule = _moduleManager.getLatestModule<ConnectionsApiModule>();
    _currentContext = context;

    // Initialize components
    _tokenManager = TokenManager(_connectionModule!);
    _socketManager = SocketConnectionManager(_setupEventHandlers);
    _roomManager = RoomManager(_socketManager.socket);
    _sessionManager = SessionManager();
    _eventHandler = EventHandler();
  }

  void _setupEventHandlers(IO.Socket socket) {
    _roomManager.setSocket(socket);
    _eventHandler.setSocket(socket);
    _eventHandler.setupEventHandlers();
  }

  Future<bool> connect(BuildContext context, {String? roomId}) async {
    _initDependencies(context);

    if (_connectionModule == null) {
      _log.error("❌ ConnectionsApiModule not available.");
      return false;
    }

    // Get fresh token
    _log.info("🔑 Getting valid token for WebSocket connection...");
    String? accessToken = await _tokenManager.getValidToken();
    if (accessToken == null) {
      _log.error("❌ No valid access token available.");
      return false;
    }
    _log.info("✅ Got valid token for WebSocket connection");

    try {
      // Connect to WebSocket server
      final success = await _socketManager.connect(accessToken);
      if (!success) {
        return false;
      }

      // Join room if specified
      if (roomId != null) {
        await _roomManager.joinRoom(roomId);
      }

      // Start token refresh timer
      _tokenManager.startTokenRefreshTimer();
      
      return true;
    } catch (e) {
      _log.error("❌ WebSocket connection error: $e");
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      // Stop token refresh timer
      _tokenManager.dispose();
      
      // Leave current room if any
      if (_roomManager.currentRoomId != null) {
        await _roomManager.leaveRoom(_roomManager.currentRoomId!);
      }
      
      // Disconnect socket
      await _socketManager.disconnect();
      
      // Clear state
      _sessionManager.clearSessionData();
      _roomManager.clearRooms();
      _currentContext = null;
      
      _log.info("✅ WebSocket disconnected and cleaned up");
    } catch (e) {
      _log.error("❌ Error during disconnect: $e");
    }
  }

  Future<bool> joinRoom(String roomId, {Map<String, dynamic>? data}) async {
    return await _roomManager.joinRoom(roomId, data: data);
  }

  Future<bool> leaveRoom(String roomId) async {
    return await _roomManager.leaveRoom(roomId);
  }

  /// Creates a new room
  Future<bool> createRoom(String userId) async {
    if (!_socketManager.isConnected) {
      _log.error('Cannot create room: WebSocket is not connected');
      return false;
    }

    try {
      _log.info('Creating new room with user ID: $userId');
      _socketManager.socket?.emit('create_room', {'user_id': userId});
      return true;
    } catch (e) {
      _log.error('Error creating room: $e');
      return false;
    }
  }

  /// Sends a message to the current room
  Future<void> sendMessage(String message) async {
    if (!_socketManager.isConnected) {
      _log.error("❌ Cannot send message: WebSocket not connected");
      return;
    }

    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot send message: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Sending message: $message");
      _socketManager.socket?.emit('message', {
        'message': message,
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error sending message: $e");
    }
  }

  /// Presses a button in the current room
  Future<void> pressButton() async {
    if (!_socketManager.isConnected) {
      _log.error("❌ Cannot press button: WebSocket not connected");
      return;
    }

    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot press button: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Pressing button");
      _socketManager.socket?.emit('button_press', {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error pressing button: $e");
    }
  }

  /// Gets the counter value from the current room
  Future<void> getCounter() async {
    if (!_socketManager.isConnected) {
      _log.error("❌ Cannot get counter: WebSocket not connected");
      return;
    }

    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot get counter: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Getting counter value");
      _socketManager.socket?.emit('get_counter', {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting counter: $e");
    }
  }

  /// Gets the list of users in the current room
  Future<void> getUsers() async {
    if (!_socketManager.isConnected) {
      _log.error("❌ Cannot get users: WebSocket not connected");
      return;
    }

    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot get users: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Getting users list");
      _socketManager.socket?.emit('get_users', {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting users: $e");
    }
  }

  void registerEventHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandler.registerHandler(event, handler);
  }

  Stream<Map<String, dynamic>> get eventStream => _eventHandler.eventStream;

  bool get isConnected => _socketManager.isConnected;
  String? get currentRoomId => _roomManager.currentRoomId;
  Map<String, dynamic>? get sessionData => _sessionManager.sessionData;
  Map<String, Set<String>> get rooms => _roomManager.rooms;
  Map<String, Set<String>> get sessionRooms => _roomManager.sessionRooms;

  @override
  void dispose() {
    _mounted = false;
    disconnect();
    super.dispose();
  }
} 