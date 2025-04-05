import 'package:flutter/material.dart';

class GameActions extends StatelessWidget {
  final VoidCallback onPressButton;
  final VoidCallback onGetCounter;
  final VoidCallback onGetUsers;
  final bool isConnected;
  final String? currentRoomId;

  const GameActions({
    Key? key,
    required this.onPressButton,
    required this.onGetCounter,
    required this.onGetUsers,
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
            Text(
              'Game Actions',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isConnected && currentRoomId != null ? onPressButton : null,
              child: const Text('Press Button'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isConnected && currentRoomId != null ? onGetCounter : null,
              child: const Text('Get Counter'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isConnected && currentRoomId != null ? onGetUsers : null,
              child: const Text('Get Users'),
            ),
          ],
        ),
      ),
    );
  }
} 