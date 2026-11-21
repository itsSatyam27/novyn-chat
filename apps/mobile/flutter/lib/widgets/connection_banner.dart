import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/sync_service.dart';

/// Makes connection and sync state visible while keeping cached chats usable.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final sync = context.watch<SyncService>();

    final isOnline = socket.isConnected && socket.isAuthenticated;
    final pending = sync.pendingMessages
        .where((message) => message.chatId.toLowerCase() == chatId.toLowerCase())
        .toList(growable: false);
    final queuedCount = pending.where((message) => !message.isFailed).length;
    final failedCount = pending.where((message) => message.isFailed).length;
    if (isOnline && !sync.isSyncing && queuedCount == 0 && failedCount == 0) {
      return const SizedBox.shrink();
    }

    final String label;
    final IconData icon;
    final bool showProgress;
    if (queuedCount > 0) {
      label = isOnline
          ? 'Sending $queuedCount queued message${queuedCount == 1 ? '' : 's'}…'
          : '$queuedCount message${queuedCount == 1 ? '' : 's'} queued. Sending when connected.';
      icon = isOnline ? Icons.outbox_rounded : Icons.schedule_rounded;
      showProgress = isOnline || socket.isConnecting;
    } else if (failedCount > 0) {
      label = '$failedCount message${failedCount == 1 ? '' : 's'} failed. Tap the red retry icon.';
      icon = Icons.error_outline_rounded;
      showProgress = false;
    } else if (isOnline) {
      label = 'Syncing messages…';
      icon = Icons.sync_rounded;
      showProgress = true;
    } else if (socket.isConnected) {
      label = 'Restoring secure connection…';
      icon = Icons.lock_reset_rounded;
      showProgress = true;
    } else if (socket.isConnecting) {
      label = 'Reconnecting to Novyn…';
      icon = Icons.sync_rounded;
      showProgress = true;
    } else {
      label = 'Connection lost. Messages will send when Novyn reconnects.';
      icon = Icons.cloud_off_rounded;
      showProgress = false;
    }

    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.primary;
    final background = scheme.primaryContainer.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: foreground.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 14),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (showProgress) ...[
                const SizedBox(width: 7),
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation(foreground),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline hint for the conversation list.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    if (socket.isConnected && socket.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Messages will be sent when you reconnect.",
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
