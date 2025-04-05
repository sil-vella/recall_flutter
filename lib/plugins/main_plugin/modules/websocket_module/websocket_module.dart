import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../core/managers/state_manager.dart';
import 'dart:convert';
import 'dart:async';
import '../../../../plugins/main_plugin/modules/connections_api_module/connections_api_module.dart';
import '../../../../utils/consts/config.dart';
import '../../../../plugins/main_plugin/modules/login_module/login_module.dart';

class WebSocketModule extends ModuleBase {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  SharedPrefManager? _sharedPref;
  ConnectionsApiModule? _connectionModule;
  IO.Socket? _socket;
  bool _isConnected = false;
  final Map<String, Set<String>> _rooms = {};
  final Map<String, Set<String>> _sessionRooms = {};
  Map<String, dynamic>? _sessionData;
  String? _currentRoomId;
  String? _currentToken;
  Timer? _tokenRefreshTimer;
  BuildContext? _currentContext;
  final _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();
  bool _mounted = true;

  WebSocketModule() : super("websocket_module") {
    _log.info('✅ WebSocketModule initialized.');
  }

  void _initDependencies(BuildContext context) {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _connectionModule = _moduleManager.getLatestModule<ConnectionsApiModule>();
    _currentContext = context;
  }

  Future<bool> connect(BuildContext context, {String? roomId}) async {
    _initDependencies(context);

    if (_connectionModule == null) {
      _log.error("❌ ConnectionsApiModule not available.");
      return false;
    }

    // Get fresh token
    _log.info("🔑 Getting valid token for WebSocket connection...");
    String? accessToken = await _getValidToken();
    if (accessToken == null) {
      _log.error("❌ No valid access token available.");
      return false;
    }
    _log.info("✅ Got valid token for WebSocket connection");

    try {
      _log.info("⚡ Connecting to WebSocket server...");
      _log.info("🔧 Connection options: {");
      _log.info("   - transports: ['websocket']");
      _log.info("   - autoConnect: false");
      _log.info("   - reconnection: true");
      _log.info("   - reconnectionAttempts: 3");
      _log.info("   - reconnectionDelay: 1000");
      _log.info("   - reconnectionDelayMax: 5000");
      _log.info("   - timeout: 20000");
      _log.info("   - forceNew: true");
      _log.info("}");
      
      // Disconnect existing socket if any
      await disconnect();

      // Create new socket connection
      _socket = IO.io(Config.wsUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'token': accessToken
        },
        'reconnection': true,
        'reconnectionAttempts': 3,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'timeout': 20000,
        'forceNew': true
      });

      // Set up event handlers
      _setupEventHandlers();

      // Connect to server
      _log.info("🔌 Connecting socket...");
      _socket!.connect();
      _isConnected = true;
      _currentRoomId = roomId;
      _currentToken = accessToken;
      
      // Start token refresh timer
      _startTokenRefreshTimer();
      
      _log.info("✅ Connected to WebSocket server");
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
      _stopTokenRefreshTimer();
      
      // Leave current room if any
      if (_currentRoomId != null) {
        await leaveRoom(_currentRoomId!);
      }
      
      // Disconnect socket
      if (_socket != null) {
        _socket!.disconnect();
        _socket = null;
      }
      
      // Clear state
      _isConnected = false;
      _currentRoomId = null;
      _currentToken = null;
      _sessionData = null;
      _rooms.clear();
      _sessionRooms.clear();
      _currentContext = null;
      
      _log.info("✅ WebSocket disconnected and cleaned up");
    } catch (e) {
      _log.error("❌ Error during disconnect: $e");
    }
  }

  Future<String?> _getValidToken() async {
    try {
      // Get token from secure storage
      String? token = await _connectionModule!.getAccessToken();
      if (token == null) {
        _log.error("❌ No access token found in secure storage");
        return null;
      }

      // Check if token is expired
      if (_isTokenExpired(token)) {
        _log.info("🔄 Access token expired, refreshing...");
        // Try to refresh token
        token = await _refreshToken();
        if (token == null) {
          _log.error("❌ Failed to refresh token");
          return null;
        }
      }

      return token;
    } catch (e) {
      _log.error("❌ Error getting valid token: $e");
      return null;
    }
  }

  bool _isTokenExpired(String token) {
    try {
      // Decode token without verification
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'] as int?;
      
      if (exp == null) return true;
      
      // Add 5 minutes buffer for token refresh
      return DateTime.now().millisecondsSinceEpoch >= (exp * 1000) - 300000;
    } catch (e) {
      _log.error("❌ Error checking token expiration: $e");
      return true;
    }
  }

  Future<String?> _refreshToken() async {
    try {
      // Get refresh token from secure storage
      String? refreshToken = await _connectionModule!.getRefreshToken();
      if (refreshToken == null) {
        _log.error("❌ No refresh token available");
        return null;
      }

      // Send refresh token request
      final response = await _connectionModule!.sendPostRequest(
        "/auth/refresh",
        {"refresh_token": refreshToken},
      );

      if (response is Map) {
        if (response["error"] != null) {
          _log.error("❌ Token refresh failed: ${response["error"]}");
          // If we get an unauthorized error, the session has expired
          if (response["error"] == "Invalid refresh token" || response["error"] == "Unauthorized") {
            _log.info("🔄 Session expired, logging out user...");
            
            // Let the login module handle the logout process
            final loginModule = _moduleManager.getLatestModule<LoginModule>();
            if (loginModule != null) {
              await loginModule.handleSessionExpired();
            }
            
            // Disconnect WebSocket after logout
            await disconnect();
            
            // Notify listeners about session expiration
            _notifyListeners("session_expired");
            return null;
          }
          return null;
        }

        if (response["tokens"] != null) {
          final newTokens = response["tokens"];
          await _connectionModule!.updateAuthTokens(
            accessToken: newTokens["access_token"],
            refreshToken: newTokens["refresh_token"],
          );
          return newTokens["access_token"];
        }
      }

      _log.error("❌ Invalid refresh token response: $response");
      return null;
    } catch (e) {
      _log.error("❌ Error refreshing token: $e");
      return null;
    }
  }

  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 25), (timer) async {
      if (_isConnected) {
        _log.info("🔄 Checking token validity...");
        String? newToken = await _getValidToken();
        if (newToken == null) {
          _log.error("❌ Failed to refresh token, disconnecting...");
          await disconnect();
        } else if (newToken != _currentToken) {
          _log.info("🔄 Token refreshed, reconnecting with new token...");
          await disconnect();
          if (_currentContext != null) {
            await connect(_currentContext!, roomId: _currentRoomId);
          } else {
            _log.error("❌ No context available for reconnection");
          }
        }
      }
    });
  }

  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  void _setupEventHandlers() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      if (!_isConnected) {
        _log.info("✅ WebSocket connected");
        _log.info("📊 Current state:");
        _log.info("   - isConnected: $_isConnected");
        _log.info("   - currentRoomId: $_currentRoomId");
        _log.info("   - currentToken: ${_currentToken != null ? 'Present' : 'None'}");
        _isConnected = true;
        
        // If we have a current room, try to rejoin it
        if (_currentRoomId != null) {
          _log.info("🔄 Rejoining room: $_currentRoomId");
          _socket!.emit('join', {
            'room_id': _currentRoomId
          });
        }
      }
    });

    _socket!.onDisconnect((_) {
      if (_isConnected) {
        _log.info("❌ WebSocket disconnected");
        _log.info("📊 Current state before disconnect:");
        _log.info("   - isConnected: $_isConnected");
        _log.info("   - currentRoomId: $_currentRoomId");
        _log.info("   - currentToken: ${_currentToken != null ? 'Present' : 'None'}");
        disconnect();
      }
    });

    _socket!.onConnectError((error) {
      if (_isConnected) {
        _log.error("❌ WebSocket connection error: $error");
        _log.error("📊 Error details:");
        _log.error("   - error type: ${error.runtimeType}");
        _log.error("   - error message: $error");
        disconnect();
      }
    });

    _socket!.on('join_response', (data) {
      _log.info("✅ Join response received: $data");
      if (data['success'] == false) {
        _log.error("❌ Failed to join room: ${data['error']}");
        _log.error("📊 Current state:");
        _log.error("   - currentRoomId: $_currentRoomId");
        _log.error("   - isConnected: $_isConnected");
        _currentRoomId = null;
        _eventStreamController.add({
          'type': 'error',
          'data': {'message': 'Failed to join room: ${data['error']}'}
        });
      } else {
        _log.info("✅ Successfully joined room");
        _log.info("📊 Room details:");
        _log.info("   - room_id: ${data['room_id']}");
        _log.info("   - message: ${data['message']}");
        _eventStreamController.add({
          'type': 'room_joined',
          'data': data
        });
      }
    });

    _socket!.on('session_data', (data) {
      _sessionData = data;
      _log.info("✅ Received session data:");
      _log.info("   - user_id: ${data['user_id']}");
      _log.info("   - username: ${data['username']}");
      _log.info("   - token_type: ${data['token_type']}");
      _log.info("   - connected_at: ${data['connected_at']}");
      _log.info("   - last_active: ${data['last_active']}");
      _log.info("   - rooms: ${data['rooms']}");
      _log.info("   - client_id: ${data['client_id']}");
      _log.info("   - origin: ${data['origin']}");
      _eventStreamController.add({
        'type': 'session_data',
        'data': data
      });
    });

    _socket!.on('room_state', (data) {
      _log.info("🏠 Room state updated:");
      _log.info("   - room_id: ${data['room_id']}");
      _log.info("   - current_size: ${data['current_size']}");
      _log.info("   - max_size: ${data['max_size']}");
      _eventStreamController.add({
        'type': 'room_state',
        'data': data
      });
    });

    _socket!.on('user_joined', (data) {
      _log.info("👤 User joined:");
      _log.info("   - user_id: ${data['user_id']}");
      _log.info("   - username: ${data['username']}");
      _log.info("   - roles: ${data['roles']}");
      _log.info("   - current_size: ${data['current_size']}");
      _log.info("   - max_size: ${data['max_size']}");
      _eventStreamController.add({
        'type': 'user_joined',
        'data': data
      });
    });

    _socket!.on('user_left', (data) {
      _log.info("👋 User left:");
      _log.info("   - user_id: ${data['user_id']}");
      _log.info("   - username: ${data['username']}");
      _eventStreamController.add({
        'type': 'user_left',
        'data': data
      });
    });

    _socket!.on('error', (data) {
      _log.error("❌ WebSocket error:");
      _log.error("   - message: ${data['message']}");
      _log.error("   - type: ${data['type']}");
      _log.error("   - timestamp: ${DateTime.now().toIso8601String()}");
      _eventStreamController.add({
        'type': 'error',
        'data': data
      });
    });
  }

  Future<bool> joinRoom(String roomId) async {
    if (!_isConnected) {
      _log.error('Cannot join room: WebSocket not connected');
      return false;
    }

    try {
      _log.info('Joining room: $roomId');
      _socket?.emit('join', {'room_id': roomId});
      return true;
    } catch (e) {
      _log.error('Error joining room: $e');
      return false;
    }
  }

  /// Creates a new room
  Future<bool> createRoom(String userId) async {
    if (!_isConnected) {
      _log.error('Cannot create room: WebSocket is not connected');
      return false;
    }

    try {
      _log.info('Creating new room with user ID: $userId');
      _socket?.emit('create_room', {'user_id': userId});
      return true;
    } catch (e) {
      _log.error('Error creating room: $e');
      return false;
    }
  }

  Future<void> leaveRoom(String roomId) async {
    if (!_isConnected || _socket == null) {
      _log.error("❌ Cannot leave room: WebSocket not connected");
      return;
    }

    try {
      _log.info("⚡ Leaving room: $roomId");
      _socket!.emit('leave', {
        'room_id': roomId
      });
      if (_currentRoomId == roomId) {
        _currentRoomId = null;
      }
    } catch (e) {
      _log.error("❌ Error leaving room: $e");
    }
  }

  Future<void> sendMessage(String message) async {
    if (!_isConnected || _socket == null) {
      _log.error("❌ Cannot send message: WebSocket not connected");
      return;
    }

    if (_currentRoomId == null) {
      _log.error("❌ Cannot send message: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Sending message: $message");
      _socket!.emit('message', {
        'message': message,
        'room_id': _currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error sending message: $e");
    }
  }

  Future<void> pressButton() async {
    if (!_isConnected || _socket == null) {
      _log.error("❌ Cannot press button: WebSocket not connected");
      return;
    }

    if (_currentRoomId == null) {
      _log.error("❌ Cannot press button: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Pressing button");
      _socket!.emit('button_press', {
        'room_id': _currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error pressing button: $e");
    }
  }

  Future<void> getCounter() async {
    if (!_isConnected || _socket == null) {
      _log.error("❌ Cannot get counter: WebSocket not connected");
      return;
    }

    if (_currentRoomId == null) {
      _log.error("❌ Cannot get counter: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Getting counter value");
      _socket!.emit('get_counter', {
        'room_id': _currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting counter: $e");
    }
  }

  Future<void> getUsers() async {
    if (!_isConnected || _socket == null) {
      _log.error("❌ Cannot get users: WebSocket not connected");
      return;
    }

    if (_currentRoomId == null) {
      _log.error("❌ Cannot get users: Not in a room");
      return;
    }

    try {
      _log.info("⚡ Getting users list");
      _socket!.emit('get_users', {
        'room_id': _currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting users: $e");
    }
  }

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;
  String? get currentToken => _currentToken;
  bool get mounted => _mounted;
  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  /// Notifies listeners about important events
  void _notifyListeners(String event) {
    switch (event) {
      case "session_expired":
        _log.info("🔄 Session expired, notifying listeners...");
        // The WebSocket will disconnect automatically due to token refresh failure
        break;
      default:
        _log.error("⚠️ Unknown event type: $event");
    }
  }

  void _setupWebSocketListeners(BuildContext context) {
    if (_socket == null) return;
    
    _socket!.on('room_joined', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      if (data['success'] == false) {
        _log.error("❌ Failed to join room: ${data['error']}");
        _log.error("📊 Current state:");
        _log.error("   - currentRoomId: $_currentRoomId");
        _log.error("   - isConnected: $_isConnected");
        _currentRoomId = null;
        _eventStreamController.add({
          'type': 'error',
          'data': {'message': 'Failed to join room: ${data['error']}'}
        });
      } else {
        _log.info("✅ Successfully joined room");
        _log.info("📊 Room details:");
        _log.info("   - room_id: ${data['room_id']}");
        _log.info("   - message: ${data['message']}");
        _eventStreamController.add({
          'type': 'room_joined',
          'data': data
        });
      }
    });

    _socket!.on('room_created', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      _log.info("✅ Successfully created game room");
      _eventStreamController.add({
        'type': 'room_created',
        'data': data
      });
    });

    _socket!.on('user_joined', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      _log.info("👤 User joined:");
      _log.info("   - user_id: ${data['user_id']}");
      _log.info("   - username: ${data['username']}");
      _log.info("   - roles: ${data['roles']}");
      _log.info("   - current_size: ${data['current_size']}");
      _log.info("   - max_size: ${data['max_size']}");
      _eventStreamController.add({
        'type': 'user_joined',
        'data': data
      });
    });

    _socket!.on('user_left', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      _log.info("👋 User left:");
      _log.info("   - user_id: ${data['user_id']}");
      _log.info("   - username: ${data['username']}");
      _eventStreamController.add({
        'type': 'user_left',
        'data': data
      });
    });

    _socket!.on('room_state', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      _log.info("🏠 Room state updated:");
      _log.info("   - room_id: ${data['room_id']}");
      _log.info("   - current_size: ${data['current_size']}");
      _log.info("   - max_size: ${data['max_size']}");
      _eventStreamController.add({
        'type': 'room_state',
        'data': data
      });
    });

    _socket!.on('error', (data) {
      if (!mounted) return;  // Don't process events if widget is disposed
      
      _log.error("❌ WebSocket error:");
      _log.error("   - message: ${data['message']}");
      _log.error("   - type: ${data['type']}");
      _log.error("   - timestamp: ${DateTime.now().toIso8601String()}");
      _eventStreamController.add({
        'type': 'error',
        'data': data
      });
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _socket?.disconnect();
    _eventStreamController.close();
    super.dispose();
  }
} 