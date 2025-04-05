import 'package:flutter/material.dart';
import '../../../../../tools/logging/logger.dart';

class JoinGame extends StatelessWidget {
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
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                hintText: 'Enter room ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
              enabled: isConnected && currentRoomId == null,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isConnected && currentRoomId == null && roomController.text.isNotEmpty
                  ? onJoinGame
                  : null,
              icon: const Icon(Icons.login),
              label: const Text('Join Game'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 