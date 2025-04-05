import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../../../tools/logging/logger.dart';

class RoomManager {
  static final Logger _log = Logger();
  final Map<String, Set<String>> _rooms = {};
  final Map<String, Set<String>> _sessionRooms = {};
  String? _currentRoomId;
  IO.Socket? _socket;

  RoomManager(this._socket);

  String? get currentRoomId => _currentRoomId;
  Map<String, Set<String>> get rooms => _rooms;
  Map<String, Set<String>> get sessionRooms => _sessionRooms;

  void setSocket(IO.Socket socket) {
    _socket = socket;
  }

  Future<bool> joinRoom(String roomId, {Map<String, dynamic>? data}) async {
    if (_socket == null) {
      _log.error("❌ Cannot join room: Socket not connected");
      return false;
    }

    try {
      _log.info("🚪 Joining room: $roomId");
      
      // Leave current room if any
      if (_currentRoomId != null) {
        await leaveRoom(_currentRoomId!);
      }

      // Join new room
      _socket!.emit('join_room', {
        'room_id': roomId,
        if (data != null) ...data
      });

      // Update state
      _currentRoomId = roomId;
      if (_socket!.id != null) {
        _rooms.putIfAbsent(roomId, () => {}).add(_socket!.id!);
        _sessionRooms.putIfAbsent(_socket!.id!, () => {}).add(roomId);
      }

      _log.info("✅ Joined room: $roomId");
      return true;
    } catch (e) {
      _log.error("❌ Error joining room: $e");
      return false;
    }
  }

  Future<bool> leaveRoom(String roomId) async {
    if (_socket == null) {
      _log.error("❌ Cannot leave room: Socket not connected");
      return false;
    }

    try {
      _log.info("🚪 Leaving room: $roomId");
      
      // Leave room
      _socket!.emit('leave_room', {
        'room_id': roomId
      });

      // Update state
      _rooms[roomId]?.remove(_socket!.id);
      _sessionRooms[_socket!.id]?.remove(roomId);
      
      if (_currentRoomId == roomId) {
        _currentRoomId = null;
      }

      _log.info("✅ Left room: $roomId");
      return true;
    } catch (e) {
      _log.error("❌ Error leaving room: $e");
      return false;
    }
  }

  void clearRooms() {
    _rooms.clear();
    _sessionRooms.clear();
    _currentRoomId = null;
  }
} 