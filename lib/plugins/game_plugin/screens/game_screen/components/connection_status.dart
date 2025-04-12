import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/state_manager.dart';

class ConnectionStatus extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ConnectionStatus({
    Key? key,
    required this.onConnect,
    required this.onDisconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final gameRoomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final isConnected = gameRoomState['isConnected'] ?? false;
        final currentRoomId = gameRoomState['roomId'];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isConnected)
                      ElevatedButton.icon(
                        onPressed: onDisconnect,
                        icon: const Icon(Icons.logout),
                        label: const Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: onConnect,
                        icon: const Icon(Icons.login),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                if (currentRoomId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current Room: $currentRoomId',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
} 