import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/sync_service.dart';

/// A compact, delayed connection hint. Brief Android resume/reconnect gaps
/// should not push the conversation timeline down with a full-width banner.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  Timer? _connectDelay;
  bool _showConnecting = false;

  @override
  void dispose() {
    _connectDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final sync = context.watch<SyncService>();

    if (socket.isConnected) {
      _connectDelay?.cancel();
      _connectDelay = null;
      _showConnecting = false;
      if (!sync.isSyncing) return const SizedBox.shrink();
    } else {
      if (!_showConnecting && _connectDelay == null) {
        _connectDelay = Timer(const Duration(seconds: 4), () {
          _connectDelay = null;
          if (mounted && !context.read<SocketService>().isConnected) {
            setState(() => _showConnecting = true);
          }
        });
      }
      if (!_showConnecting) return const SizedBox.shrink();
    }

    final isOffline = !socket.isConnected;
    final scheme = Theme.of(context).colorScheme;
    final foreground = isOffline ? scheme.onSurfaceVariant : scheme.primary;
    final background = isOffline
        ? scheme.surfaceContainerHighest
        : scheme.primaryContainer.withValues(alpha: 0.72);

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
              Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.sync_rounded,
                color: foreground,
                size: 14,
              ),
              const SizedBox(width: 7),
              Text(
                isOffline ? 'Reconnecting…' : 'Syncing messages…',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              if (sync.isSyncing && socket.isConnected) ...[
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

/// Offline indicator for chat list
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    if (socket.isConnected) return const SizedBox.shrink();

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
