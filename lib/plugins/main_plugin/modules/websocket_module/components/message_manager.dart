import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../../../tools/logging/logger.dart';
import 'result_handler.dart';
import 'room_manager.dart';
import 'socket_connection_manager.dart';
import 'dart:async';

class MessageManager {
  static final Logger _log = Logger();
  final SocketConnectionManager _socketManager;
  final RoomManager _roomManager;
  final ResultHandler _resultHandler = ResultHandler();

  MessageManager(this._roomManager, this._socketManager);

  IO.Socket? get _socket => _socketManager.socket;

  Future<WebSocketResult> sendMessage(String message) async {
    if (_socket == null) {
      return _resultHandler.createNoConnectionResult();
    }

    if (_roomManager.currentRoomId == null) {
      return _resultHandler.createErrorResult('message', 'Not in a room');
    }

    try {
      _log.info("📨 Sending message: $message");
      _socket!.emit('message', {
        'room_id': _roomManager.currentRoomId,
        'message': message
      });
      return _resultHandler.createSuccessResult('message', data: {
        'room_id': _roomManager.currentRoomId,
        'message': message
      });
    } catch (e) {
      _log.error("❌ Error sending message: $e");
      return _resultHandler.createUnknownErrorResult('message', e.toString());
    }
  }

  Future<WebSocketResult> pressButton() async {
    if (_socket == null) {
      return _resultHandler.createNoConnectionResult();
    }

    if (_roomManager.currentRoomId == null) {
      return _resultHandler.createErrorResult('press_button', 'Not in a room');
    }

    try {
      _log.info("🔘 Pressing button");
      _socket!.emit('press_button', {
        'room_id': _roomManager.currentRoomId
      });
      return _resultHandler.createSuccessResult('press_button', data: {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error pressing button: $e");
      return _resultHandler.createUnknownErrorResult('press_button', e.toString());
    }
  }

  Future<WebSocketResult> getCounter() async {
    if (_socket == null) {
      return _resultHandler.createNoConnectionResult();
    }

    if (_roomManager.currentRoomId == null) {
      return _resultHandler.createErrorResult('get_counter', 'Not in a room');
    }

    try {
      _log.info("🔢 Getting counter");
      _socket!.emit('get_counter', {
        'room_id': _roomManager.currentRoomId
      });
      return _resultHandler.createSuccessResult('get_counter', data: {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting counter: $e");
      return _resultHandler.createUnknownErrorResult('get_counter', e.toString());
    }
  }

  Future<WebSocketResult> getUsers() async {
    if (_socket == null) {
      return _resultHandler.createNoConnectionResult();
    }

    if (_roomManager.currentRoomId == null) {
      return _resultHandler.createErrorResult('get_users', 'Not in a room');
    }

    try {
      _log.info("👥 Getting users");
      _socket!.emit('get_users', {
        'room_id': _roomManager.currentRoomId
      });
      return _resultHandler.createSuccessResult('get_users', data: {
        'room_id': _roomManager.currentRoomId
      });
    } catch (e) {
      _log.error("❌ Error getting users: $e");
      return _resultHandler.createUnknownErrorResult('get_users', e.toString());
    }
  }

  Future<WebSocketResult> createRoom(String userId) async {
    if (_socket == null) {
      return _resultHandler.createNoConnectionResult();
    }

    // Wait for socket to be fully connected
    if (!_socketManager.isConnected) {
      _log.info("⏳ Waiting for socket connection...");
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_socketManager.isConnected) {
        return _resultHandler.createErrorResult('create_room', 'Socket not connected');
      }
    }

    try {
      _log.info("🏠 Creating room for user: $userId");
      final data = {
        'user_id': userId
      };

      // Create a completer to wait for the room_created event
      final completer = Completer<WebSocketResult>();
      
      // Set up a one-time listener for the room_created event
      void onRoomCreated(dynamic eventData) {
        _log.info("📨 Received room_created event: $eventData");
        
        if (eventData is! Map<String, dynamic>) {
          _log.error("❌ Invalid room_created event data format: $eventData");
          completer.complete(_resultHandler.createErrorResult('create_room', 'Invalid room_created event data format'));
          return;
        }

        final roomId = eventData['room_id'];
        if (roomId == null) {
          _log.error("❌ Missing room_id in room_created event: $eventData");
          completer.complete(_resultHandler.createErrorResult('create_room', 'Missing room_id in room_created event'));
          return;
        }

        _log.info("✅ Processing room_created event for room: $roomId");
        
        // Update room state
        _roomManager.currentRoomId = roomId;
        _roomManager.rooms[roomId] = _roomManager.rooms[roomId] ?? {};
        _roomManager.rooms[roomId]!.add(_socket!.id!);
        _roomManager.sessionRooms[_socket!.id!] = _roomManager.sessionRooms[_socket!.id!] ?? {};
        _roomManager.sessionRooms[_socket!.id!]!.add(roomId);

        // Prepare response data
        final responseData = {
          'room_id': roomId,
          'current_size': eventData['current_size'] ?? 1,
          'max_size': eventData['max_size'] ?? 2
        };

        _log.info("✅ Room state updated: $responseData");
        completer.complete(_resultHandler.createSuccessResult('create_room', data: responseData));
      }

      // Set up a one-time listener for errors
      void onError(dynamic errorData) {
        _log.error("❌ Received error event: $errorData");
        if (errorData is Map<String, dynamic> && errorData['message']?.contains('Failed to create room') == true) {
          completer.complete(_resultHandler.createErrorResult('create_room', errorData['message']));
        } else {
          completer.complete(_resultHandler.createErrorResult('create_room', 'Unknown error during room creation'));
        }
      }

      // Add event listeners BEFORE emitting the event
      _log.info("👂 Setting up event listeners for room_created and error events");
      _socket!.on('room_created', onRoomCreated);
      _socket!.on('error', onError);
      
      // Emit create_room event
      _log.info("📤 Emitting create_room event with data: $data");
      _socket!.emit('create_room', data);

      // Wait for the room_created event with a timeout
      try {
        _log.info("⏳ Waiting for room_created event (timeout: 5s)");
        final result = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _log.error("❌ Timeout waiting for room_created event");
            return _resultHandler.createErrorResult('create_room', 'Timeout waiting for room creation confirmation');
          },
        );
        
        // Remove event listeners
        _log.info("🧹 Cleaning up event listeners");
        _socket!.off('room_created', onRoomCreated);
        _socket!.off('error', onError);
        
        _log.info("✅ Room creation process completed: ${result.data}");
        return result;
      } catch (e) {
        // Remove event listeners
        _log.error("🧹 Cleaning up event listeners after error");
        _socket!.off('room_created', onRoomCreated);
        _socket!.off('error', onError);
        _log.error("❌ Error during room creation: $e");
        return _resultHandler.createUnknownErrorResult('create_room', e.toString());
      }
    } catch (e) {
      _log.error("❌ Error creating room: $e");
      return _resultHandler.createUnknownErrorResult('create_room', e.toString());
    }
  }
} 