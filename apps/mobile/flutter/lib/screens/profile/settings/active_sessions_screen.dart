import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../theme/novyn_theme.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  bool _isRevoking = false;
  int? _lastRevokedCount;

  Future<void> _confirmAndRevoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out other devices?'),
        content: const Text(
          'All other Novyn login sessions will be signed out. This device will remain connected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out others'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRevoking = true);
    HapticFeedback.mediumImpact();
    final result = await ApiService.revokeOtherSessions();
    if (!mounted) return;
    setState(() {
      _isRevoking = false;
      if (result['ok'] == true) {
        _lastRevokedCount = (result['revoked'] as num?)?.toInt() ?? 0;
      }
    });

    final success = result['ok'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          success
              ? (_lastRevokedCount == 0
                  ? 'No other active sessions were found.'
                  : 'Signed out of $_lastRevokedCount other session(s).')
              : (result['message']?.toString() ?? 'Could not sign out other devices.'),
        ),
      ),
    );
    if (success) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Active Sessions'),
        backgroundColor: NovynTheme.pageBg(context),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.phone_android_rounded, color: colors.primary, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This device', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Current Novyn session · stays signed in',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('REMOTE SIGN-OUT', style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          )),
          const SizedBox(height: 10),
          Text(
            'If you used Novyn on a shared or unfamiliar device, sign out all other sessions. Your current device will not be affected.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isRevoking ? null : _confirmAndRevoke,
            icon: _isRevoking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded),
            label: Text(_isRevoking ? 'Signing out…' : 'Sign out all other devices'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_lastRevokedCount != null) ...[
            const SizedBox(height: 14),
            Text(
              _lastRevokedCount == 0
                  ? 'No other sessions were active when you checked.'
                  : '$_lastRevokedCount other session(s) were revoked.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 19, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'For account safety, update your password if you signed out a device you do not recognize.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
