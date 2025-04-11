import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../../../tools/logging/logger.dart';
import 'result_handler.dart';
import 'room_manager.dart';

class MessageManager {
  static final Logger _log = Logger();
  final IO.Socket? _socket;
  final RoomManager _roomManager;
  final ResultHandler _resultHandler = ResultHandler();

  MessageManager(this._roomManager, this._socket);

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

    try {
      _log.info("🏠 Creating room for user: $userId");
      final data = {
        'user_id': userId
      };
      
      _socket!.emit('create_room', data);
      return _resultHandler.createSuccessResult('create_room', data: data);
    } catch (e) {
      _log.error("❌ Error creating room: $e");
      return _resultHandler.createUnknownErrorResult('create_room', e.toString());
    }
  }
} 