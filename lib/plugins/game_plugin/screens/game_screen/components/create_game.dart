import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../tools/logging/logger.dart';

class CreateGame extends StatelessWidget {
  static final Logger _log = Logger();
  
  final Future<void> Function() onCreateGame;
  final bool isConnected;
  final String? currentRoomId;
  final String? userId;
  final String? joinLink;

  const CreateGame({
    Key? key,
    required this.onCreateGame,
    required this.isConnected,
    this.currentRoomId,
    this.userId,
    this.joinLink,
  }) : super(key: key);

  Future<void> _shareGameLink(BuildContext context) async {
    if (joinLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No game link available to share'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await Share.share(joinLink!);
      _log.info("✅ Game link shared successfully");
    } catch (e) {
      _log.error("❌ Error sharing game link: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share game link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              const SizedBox(height: 16),
              Text(
                'Current Room: $currentRoomId',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: joinLink != null ? () => _shareGameLink(context) : null,
                icon: const Icon(Icons.share),
                label: const Text('Share Game Link'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 