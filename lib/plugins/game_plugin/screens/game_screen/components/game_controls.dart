import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/state_manager.dart';

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
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final roomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final isLoading = roomState["isLoading"] ?? false;
        final error = roomState["error"];
        final isInRoom = currentRoomId != null;

        // Don't show controls if we're in a room
        if (isInRoom) {
          return const SizedBox.shrink();
        }

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
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isConnected && !isLoading ? onCreateGame : null,
                        child: isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Create New Game'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isConnected && roomController.text.isNotEmpty && !isLoading
                            ? onJoinGame
                            : null,
                        child: isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Join Game'),
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
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