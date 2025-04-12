import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../tools/logging/logger.dart';
import '../../../../../core/managers/state_manager.dart';

class JoinGame extends StatefulWidget {
  static final Logger _log = Logger();
  
  final TextEditingController roomController;
  final VoidCallback onJoinGame;

  const JoinGame({
    Key? key,
    required this.roomController,
    required this.onJoinGame,
  }) : super(key: key);

  @override
  State<JoinGame> createState() => _JoinGameState();
}

class _JoinGameState extends State<JoinGame> {
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _updateButtonState();
    widget.roomController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    widget.roomController.removeListener(_updateButtonState);
    super.dispose();
  }

  void _updateButtonState() {
    final stateManager = Provider.of<StateManager>(context, listen: false);
    final gameRoomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
    final isConnected = gameRoomState['isConnected'] ?? false;
    final currentRoomId = gameRoomState['roomId'];

    final bool newState = isConnected && 
                         currentRoomId == null && 
                         widget.roomController.text.isNotEmpty;
    
    if (_isButtonEnabled != newState) {
      setState(() {
        _isButtonEnabled = newState;
      });
      
      JoinGame._log.info("Button state updated: $_isButtonEnabled");
      JoinGame._log.info("isConnected: $isConnected");
      JoinGame._log.info("currentRoomId: $currentRoomId");
      JoinGame._log.info("roomController.text: ${widget.roomController.text}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final gameRoomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final isConnected = gameRoomState['isConnected'] ?? false;
        final currentRoomId = gameRoomState['roomId'];

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join Existing Game',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter a room ID to join an existing game.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.roomController,
                  decoration: const InputDecoration(
                    labelText: 'Room ID',
                    hintText: 'Enter room ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  enabled: isConnected && currentRoomId == null,
                  onChanged: (value) {
                    JoinGame._log.info("Room ID text changed: $value");
                    JoinGame._log.info("Button would be enabled: ${isConnected && currentRoomId == null && value.isNotEmpty}");
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  "Button state: ${_isButtonEnabled ? 'Enabled' : 'Disabled'}",
                  style: TextStyle(
                    color: _isButtonEnabled ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isButtonEnabled
                      ? () {
                          JoinGame._log.info("Join Game button pressed");
                          widget.onJoinGame();
                        }
                      : null,
                  icon: const Icon(Icons.login),
                  label: const Text('Join Game'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: _isButtonEnabled ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 