import 'package:flutter/material.dart';

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final String? currentRoomId;

  const ConnectionStatus({
    Key? key,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
    this.currentRoomId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                  Text(
                    'Current Room: $currentRoomId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
} 