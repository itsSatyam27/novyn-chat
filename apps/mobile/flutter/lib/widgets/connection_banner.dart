import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/sync_service.dart';

/// Avoid flashing an orange banner during short Android background/resume
/// socket interruptions. A real outage is still shown after a brief grace period.
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
        _connectDelay = Timer(const Duration(milliseconds: 1200), () {
          _connectDelay = null;
          if (mounted && !context.read<SocketService>().isConnected) {
            setState(() => _showConnecting = true);
          }
        });
      }
      if (!_showConnecting) return const SizedBox.shrink();
    }

    final message = socket.isConnected ? 'Syncing messages...' : 'Connecting...';
    final color = socket.isConnected
        ? const Color(0xFF3B82F6)
        : const Color(0xFFF59E0B);
    final icon = socket.isConnected
        ? Icons.sync_rounded
        : Icons.cloud_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.9)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (sync.isSyncing && socket.isConnected) ...[
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
                fontFamily: 'PlusJakartaSans',
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
