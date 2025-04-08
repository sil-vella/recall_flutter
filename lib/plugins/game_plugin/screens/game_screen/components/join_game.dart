import 'package:flutter/material.dart';
import '../../../../../tools/logging/logger.dart';

class JoinGame extends StatefulWidget {
  static final Logger _log = Logger();
  
  final TextEditingController roomController;
  final VoidCallback onJoinGame;
  final bool isConnected;
  final String? currentRoomId;

  const JoinGame({
    Key? key,
    required this.roomController,
    required this.onJoinGame,
    required this.isConnected,
    this.currentRoomId,
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
    // Add listener to the text controller to update button state when text changes
    widget.roomController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    widget.roomController.removeListener(_updateButtonState);
    super.dispose();
  }

  @override
  void didUpdateWidget(JoinGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update button state when widget properties change
    if (oldWidget.isConnected != widget.isConnected || 
        oldWidget.currentRoomId != widget.currentRoomId) {
      _updateButtonState();
    }
  }

  void _updateButtonState() {
    final bool newState = widget.isConnected && 
                         widget.currentRoomId == null && 
                         widget.roomController.text.isNotEmpty;
    
    // Only update state if it has changed
    if (_isButtonEnabled != newState) {
      setState(() {
        _isButtonEnabled = newState;
      });
      
      // Log the button state change
      JoinGame._log.info("Button state updated: $_isButtonEnabled");
      JoinGame._log.info("isConnected: ${widget.isConnected}");
      JoinGame._log.info("currentRoomId: ${widget.currentRoomId}");
      JoinGame._log.info("roomController.text: ${widget.roomController.text}");
    }
  }

  @override
  Widget build(BuildContext context) {
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
              enabled: widget.isConnected && widget.currentRoomId == null,
              onChanged: (value) {
                // Log when text changes
                JoinGame._log.info("Room ID text changed: $value");
                JoinGame._log.info("Button would be enabled: ${widget.isConnected && widget.currentRoomId == null && value.isNotEmpty}");
              },
            ),
            const SizedBox(height: 16),
            // Add a debug text to show button state
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
  }
} 