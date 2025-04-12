import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../../../../../../tools/logging/logger.dart';
import '../../../../../../core/managers/state_manager.dart';
import 'websocket_state.dart';

class EventHandler {
  static final Logger _log = Logger();
  final StreamController<Map<String, dynamic>> _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Function(Map<String, dynamic>)> _eventHandlers = {};
  IO.Socket? _socket;
  late StateManager _stateManager;

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  void setSocket(IO.Socket socket) {
    _socket = socket;
  }

  void setStateManager(StateManager stateManager) {
    _stateManager = stateManager;
  }

  void registerHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandlers[event] = handler;
    _log.info("✅ Registered handler for event: $event");
  }

  void setupEventHandlers() {
    if (_socket == null) {
      _log.error("❌ Cannot setup event handlers: Socket not connected");
      return;
    }

    // Connection events
    _socket!.onConnect((_) {
      _log.info("✅ Connected to WebSocket server");
      _handleEvent('connect', {});
    });

    _socket!.onDisconnect((_) {
      _log.info("❌ Disconnected from WebSocket server");
      _handleEvent('disconnect', {});
    });

    _socket!.onError((error) {
      _log.error("❌ WebSocket error: $error");
      _handleEvent('error', {'error': error.toString()});
    });

    // Room events
    _socket!.on('room_joined', (data) {
      _log.info("✅ Joined room: $data");
      _handleEvent('room_joined', data);
    });

    _socket!.on('room_left', (data) {
      _log.info("✅ Left room: $data");
      _handleEvent('room_left', data);
    });

    _socket!.on('room_error', (data) {
      _log.error("❌ Room error: $data");
      _handleEvent('room_error', data);
    });

    // Message events
    _socket!.on('message', (data) {
      _log.info("📨 Received message: $data");
      _handleEvent('message', data);
    });

    _socket!.on('message_error', (data) {
      _log.error("❌ Message error: $data");
      _handleEvent('message_error', data);
    });

    // Session events
    _socket!.on('session_update', (data) {
      _log.info("✅ Session updated: $data");
      _handleEvent('session_update', data);
    });

    _socket!.on('session_error', (data) {
      _log.error("❌ Session error: $data");
      _handleEvent('session_error', data);
    });

    // Register custom event handlers
    _eventHandlers.forEach((event, handler) {
      _socket!.on(event, (data) {
        _log.info("📨 Received custom event '$event': $data");
        _handleEvent(event, data);
      });
    });
  }

  void _handleEvent(String event, Map<String, dynamic> data) {
    // Add event type to data
    final eventData = {
      'event': event,
      ...data
    };

    // Update state based on event
    switch (event) {
      case 'connect':
        _updateState({
          'isConnected': true,
          'sessionId': _socket?.id,
          'connectionTime': DateTime.now().toIso8601String(),
          'error': null
        });
        break;
      case 'disconnect':
        _updateState({
          'isConnected': false,
          'sessionId': null,
          'currentRoomId': null,
          'roomState': null,
          'error': null
        });
        break;
      case 'room_joined':
        final currentState = _stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};
        final joinedRooms = List<String>.from(currentState['joinedRooms'] ?? []);
        joinedRooms.add(data['room_id']);
        
        _updateState({
          'currentRoomId': data['room_id'],
          'roomState': data['room_state'],
          'joinedRooms': joinedRooms,
          'error': null
        });
        break;
      case 'room_left':
        final currentState = _stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};
        final joinedRooms = List<String>.from(currentState['joinedRooms'] ?? []);
        joinedRooms.remove(data['room_id']);
        
        _updateState({
          'currentRoomId': null,
          'roomState': null,
          'joinedRooms': joinedRooms,
          'error': null
        });
        break;
      case 'session_update':
        _updateState({
          'sessionData': data['session_data'],
          'userId': data['user_id'],
          'username': data['username'],
          'lastActivity': DateTime.now().toIso8601String(),
          'error': null
        });
        break;
      case 'error':
        _updateState({
          'error': data['error'],
          'isLoading': false
        });
        break;
    }

    // Call registered handler if exists
    final handler = _eventHandlers[event];
    if (handler != null) {
      handler(eventData);
    }

    // Broadcast event to stream
    _eventStreamController.add(eventData);
  }

  void _updateState(Map<String, dynamic> newState) {
    final currentState = _stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};
    _stateManager.updatePluginState("websocket", {...currentState, ...newState});
  }

  void dispose() {
    _eventStreamController.close();
    _eventHandlers.clear();
  }
} 