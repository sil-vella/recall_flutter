import 'package:flutter/material.dart';

class GameControls extends StatelessWidget {
  final TextEditingController roomController;
  final VoidCallback onCreateGame;
  final VoidCallback onJoinGame;
  final bool isConnected;
  final String? currentRoomId;

  const GameControls({
    Key? key,
    required this.roomController,
    required this.onCreateGame,
    required this.onJoinGame,
    required this.isConnected,
    this.currentRoomId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                hintText: 'Enter room ID to join',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected ? onCreateGame : null,
                    child: const Text('Create New Game'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected && roomController.text.isNotEmpty
                        ? onJoinGame
                        : null,
                    child: const Text('Join Game'),
                  ),
                ),
              ],
            ),
            if (currentRoomId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Current Room: $currentRoomId',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
} 