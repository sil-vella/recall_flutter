import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/state_manager.dart';

class GameState extends StatelessWidget {
  const GameState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final gameRoomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final isConnected = gameRoomState['isConnected'] ?? false;
        final currentRoomId = gameRoomState['roomId'];
        final roomState = gameRoomState['roomState'];

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
                  _buildStateItem('Current Room', currentRoomId, Colors.blue),
                if (roomState != null) ...[
                  _buildStateItem(
                    'Room Size',
                    '${roomState['current_size'] ?? 0}/${roomState['max_size'] ?? 0}',
                    Colors.orange,
                  ),
                  if (roomState['users'] != null)
                    _buildStateItem(
                      'Users',
                      '${(roomState['users'] as List).length}',
                      Colors.purple,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
} 