import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../../../../../../tools/logging/logger.dart';

class EventHandler {
  static final Logger _log = Logger();
  final StreamController<Map<String, dynamic>> _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Function(Map<String, dynamic>)> _eventHandlers = {};
  IO.Socket? _socket;

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  void setSocket(IO.Socket socket) {
    _socket = socket;
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

    // Call registered handler if exists
    final handler = _eventHandlers[event];
    if (handler != null) {
      handler(eventData);
    }

    // Broadcast event to stream
    _eventStreamController.add(eventData);
  }

  void dispose() {
    _eventStreamController.close();
    _eventHandlers.clear();
  }
} 