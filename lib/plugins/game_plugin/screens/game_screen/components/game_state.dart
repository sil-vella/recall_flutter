import 'package:flutter/material.dart';

class GameState extends StatelessWidget {
  final bool isConnected;
  final String? currentRoomId;
  final Map<String, dynamic>? roomState;

  const GameState({
    Key? key,
    required this.isConnected,
    this.currentRoomId,
    this.roomState,
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
              'Game State',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildStateItem(
              'Connection Status',
              isConnected ? 'Connected' : 'Disconnected',
              isConnected ? Colors.green : Colors.red,
            ),
            if (currentRoomId != null)
              _buildStateItem('Current Room', currentRoomId!, Colors.blue),
            if (roomState != null) ...[
              _buildStateItem(
                'Room Size',
                '${roomState!['current_size'] ?? 0}/${roomState!['max_size'] ?? 0}',
                Colors.orange,
              ),
              if (roomState!['users'] != null)
                _buildStateItem(
                  'Users',
                  '${(roomState!['users'] as List).length}',
                  Colors.purple,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStateItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 