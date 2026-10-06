import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/sync_service.dart';

/// Banner that shows connection status (offline/connecting/syncing)
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final sync = context.watch<SyncService>();

    // Don't show banner if connected and not syncing
    if (socket.isConnected && !sync.isSyncing) {
      return const SizedBox.shrink();
    }

    String message;
    Color color;
    IconData icon;

    if (!socket.isConnected) {
      message = 'Connecting...';
      color = const Color(0xFFF59E0B); // Orange
      icon = Icons.cloud_off_rounded;
    } else if (sync.isSyncing) {
      message = 'Syncing messages...';
      color = const Color(0xFF3B82F6); // Blue
      icon = Icons.sync_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (sync.isSyncing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Offline indicator for chat list
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();

    if (socket.isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: const Color(0xFFF59E0B),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'re offline. Messages will be sent when you reconnect.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: const Color(0xFFF59E0B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
