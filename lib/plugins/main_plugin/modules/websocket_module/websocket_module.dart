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
    _messageManager = MessageManager(_roomManager, _socketManager);
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
      return _resultHandler.createErrorResult('connect', 'ConnectionsApiModule not available');
    }

    // Get fresh token
    _log.info("🔑 Getting valid token for WebSocket connection...");
    String? accessToken = await _tokenManager.getValidToken();
    if (accessToken == null) {
      return _resultHandler.createErrorResult('connect', 'No valid access token available');
    }
    _log.info("✅ Got valid token for WebSocket connection");

    try {
      // Connect to WebSocket server
      final success = await _socketManager.connect(accessToken);
      if (!success) {
        return _resultHandler.createErrorResult('connect', 'Connection failed');
      }

      // Wait for session ID to be available
      int attempts = 0;
      while (_socketManager.socket?.id == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (_socketManager.socket?.id == null) {
        _log.error("❌ Failed to get session ID after connection");
        await disconnect();
        return _resultHandler.createErrorResult('connect', 'Failed to get session ID');
      }

      // Join room if specified
      if (roomId != null) {
        final joinResult = await _roomManager.joinRoom(roomId);
        if (!joinResult.isSuccess) {
          return joinResult;
        }
      }

      // Start token refresh timer
      _tokenManager.startTokenRefreshTimer();
      
      return _resultHandler.createSuccessResult('connect', data: {
        'session_id': _socketManager.socket?.id,
        'connected': _socketManager.isConnected
      });
    } catch (e) {
      _log.error("❌ WebSocket connection error: $e");
      await disconnect();
      return _resultHandler.createUnknownErrorResult('connect', e.toString());
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

  Future<WebSocketResult> joinRoom(String roomId) async {
    return _roomManager.joinRoom(roomId);
  }

  Future<WebSocketResult> joinGame(String roomId) async {
    return _roomManager.joinRoom(roomId);
  }

  Future<WebSocketResult> leaveRoom(String roomId) async {
    return _roomManager.leaveRoom(roomId);
  }

  Future<WebSocketResult> createRoom(String userId) async {
    return _messageManager.createRoom(userId);
  }

  Future<WebSocketResult> sendMessage(String message) async {
    return _messageManager.sendMessage(message);
  }

  Future<WebSocketResult> pressButton() async {
    return _messageManager.pressButton();
  }

  Future<WebSocketResult> getCounter() async {
    return _messageManager.getCounter();
  }

  Future<WebSocketResult> getUsers() async {
    return _messageManager.getUsers();
  }

  String? getCurrentRoomId() {
    return _roomManager.currentRoomId;
  }

  Map<String, dynamic>? getSessionData() {
    return _sessionManager.sessionData;
  }

  String? getUserId() {
    return _sessionManager.getUserId();
  }

  String? getUsername() {
    return _sessionManager.getUsername();
  }

  List<String> getRooms() {
    return _sessionManager.getRooms();
  }

  bool isInRoom(String roomId) {
    return _sessionManager.isInRoom(roomId);
  }

  Stream<Map<String, dynamic>> get eventStream => _eventHandler.eventStream;

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