import 'package:flutter/material.dart';
import '../../../../../tools/logging/logger.dart';

class CreateGame extends StatelessWidget {
  static final Logger _log = Logger();
  
  final Function() onCreateGame;
  final bool isConnected;
  final String? currentRoomId;
  final String? userId;

  const CreateGame({
    Key? key,
    required this.onCreateGame,
    required this.isConnected,
    this.currentRoomId,
    this.userId,
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
              'Create New Game',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a new game room and invite friends to join.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isConnected && currentRoomId == null && userId != null 
                  ? onCreateGame
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New Game'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (currentRoomId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Current Room: $currentRoomId',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
} 