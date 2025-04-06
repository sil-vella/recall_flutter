import '../../../../../../tools/logging/logger.dart';
import 'broadcast_manager.dart';
import 'room_manager.dart';

class MessageManager {
  static final Logger _log = Logger();
  final BroadcastManager _broadcastManager;
  final RoomManager _roomManager;

  MessageManager(this._broadcastManager, this._roomManager);

  bool sendMessage(String message) {
    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot send message: Not in a room");
      return false;
    }

    return _broadcastManager.emitWithRoom('message', _roomManager.currentRoomId!, {
      'message': message
    });
  }

  bool pressButton() {
    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot press button: Not in a room");
      return false;
    }

    return _broadcastManager.emitWithRoom('button_press', _roomManager.currentRoomId!, {});
  }

  bool getCounter() {
    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot get counter: Not in a room");
      return false;
    }

    return _broadcastManager.emitWithRoom('get_counter', _roomManager.currentRoomId!, {});
  }

  bool getUsers() {
    if (_roomManager.currentRoomId == null) {
      _log.error("❌ Cannot get users: Not in a room");
      return false;
    }

    return _broadcastManager.emitWithRoom('get_users', _roomManager.currentRoomId!, {});
  }

  bool createRoom(String userId, {Map<String, dynamic>? additionalData}) {
    final data = {
      'user_id': userId,
      if (additionalData != null) ...additionalData
    };
    
    return _broadcastManager.emit('create_room', data);
  }
} 