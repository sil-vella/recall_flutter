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
import 'components/result_handler.dart';
import 'components/broadcast_manager.dart';
import 'components/message_manager.dart';

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
  late ResultHandler _resultHandler;
  late BroadcastManager _broadcastManager;
  late MessageManager _messageManager;

  WebSocketModule() : super("websocket_module") {
    _log.info('✅ WebSocketModule initialized.');
    
    // Initialize components with default values
    _socketManager = SocketConnectionManager(_setupEventHandlers);
    _roomManager = RoomManager(_socketManager.socket);
    _sessionManager = SessionManager();
    _tokenManager = TokenManager(null); // Will be updated in _initDependencies
    _eventHandler = EventHandler();
    _resultHandler = ResultHandler();
    _broadcastManager = BroadcastManager();
    _messageManager = MessageManager(_broadcastManager, _roomManager);
  }

  void _initDependencies(BuildContext context) {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _connectionModule = _moduleManager.getLatestModule<ConnectionsApiModule>();
    _currentContext = context;

    // Update TokenManager with the connection module
    _tokenManager = TokenManager(_connectionModule);
  }

  void _setupEventHandlers(IO.Socket socket) {
    _roomManager.setSocket(socket);
    _eventHandler.setSocket(socket);
    _broadcastManager.setSocket(socket);
    _eventHandler.setupEventHandlers();
  }

  Future<WebSocketResult> connect(BuildContext context, {String? roomId}) async {
    _initDependencies(context);

    if (_connectionModule == null) {
      _log.error("❌ ConnectionsApiModule not available.");
      return _resultHandler.createErrorResult(WebSocketError.noConnectionModule);
    }

    // Get fresh token
    _log.info("🔑 Getting valid token for WebSocket connection...");
    String? accessToken = await _tokenManager.getValidToken();
    if (accessToken == null) {
      _log.error("❌ No valid access token available.");
      return _resultHandler.createErrorResult(WebSocketError.noValidToken);
    }
    _log.info("✅ Got valid token for WebSocket connection");

    try {
      // Connect to WebSocket server
      final success = await _socketManager.connect(accessToken);
      if (!success) {
        return _resultHandler.createErrorResult(WebSocketError.connectionFailed);
      }

      // Join room if specified
      if (roomId != null) {
        await _roomManager.joinRoom(roomId);
      }

      // Start token refresh timer
      _tokenManager.startTokenRefreshTimer();
      
      return _resultHandler.createSuccessResult();
    } catch (e) {
      _log.error("❌ WebSocket connection error: $e");
      await disconnect();
      return _resultHandler.createUnknownErrorResult("WebSocket connection error: $e");
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

  Future<bool> joinRoom(String roomId) async {
    return _roomManager.joinRoom(roomId);
  }

  Future<bool> joinGame(String roomId) async {
    _log.info("🎮 Joining game room: $roomId");
    if (_socketManager.socket == null) {
      _log.error("❌ Cannot join game: Socket not connected");
      return false;
    }

    try {
      _socketManager.socket!.emit('join_game', {
        'session_id': roomId
      });
      return true;
    } catch (e) {
      _log.error("❌ Error joining game: $e");
      return false;
    }
  }

  Future<bool> leaveRoom(String roomId) async {
    return await _roomManager.leaveRoom(roomId);
  }

  /// Creates a new room
  Future<bool> createRoom(String userId) async {
    return _messageManager.createRoom(userId);
  }

  /// Sends a message to the current room
  Future<void> sendMessage(String message) async {
    _messageManager.sendMessage(message);
  }

  /// Presses a button in the current room
  Future<void> pressButton() async {
    _messageManager.pressButton();
  }

  /// Gets the counter value from the current room
  Future<void> getCounter() async {
    _messageManager.getCounter();
  }

  /// Gets the users in the current room
  Future<void> getUsers() async {
    _messageManager.getUsers();
  }

  /// Gets the current room ID
  String? getCurrentRoomId() {
    return _roomManager.currentRoomId;
  }

  /// Gets the session data
  Map<String, dynamic>? getSessionData() {
    return _sessionManager.sessionData;
  }

  /// Gets the user ID from the session
  String? getUserId() {
    return _sessionManager.getUserId();
  }

  /// Gets the username from the session
  String? getUsername() {
    return _sessionManager.getUsername();
  }

  /// Gets the rooms the user is in
  List<String> getRooms() {
    return _sessionManager.getRooms();
  }

  /// Checks if the user is in a specific room
  bool isInRoom(String roomId) {
    return _sessionManager.isInRoom(roomId);
  }

  /// Gets the event stream
  Stream<Map<String, dynamic>> get eventStream => _eventHandler.eventStream;

  /// Registers a handler for a specific event
  void registerEventHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandler.registerHandler(event, handler);
  }

  @override
  void dispose() {
    _mounted = false;
    disconnect();
    _eventHandler.dispose();
    _tokenManager.dispose();
  }
} 