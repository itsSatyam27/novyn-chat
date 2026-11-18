import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import '../../../services/api_service.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/novyn_theme.dart';
import 'pair_web_device_screen.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<Map<String, dynamic>>? _sessions;
  bool _loading = true;
  String? _revokingId;
  bool _isRevokingAll = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await ApiService.getActiveSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _revokeOne(Map<String, dynamic> session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: Text('Novyn will be signed out on ${session['deviceName'] ?? 'this device'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = session['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _revokingId = id);
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
    final result = await ApiService.revokeSession(id);
    if (!mounted) return;
    setState(() => _revokingId = null);
    if (result['ok'] == true) {
      await _loadSessions();
      if (!mounted) return;
      HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
      context.showNovynAlert(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Device signed out.')));
    } else {
      context.showNovynAlert(SnackBar(behavior: SnackBarBehavior.floating,
          content: Text(result['message']?.toString() ?? 'Could not sign out this device.')));
    }
  }

  Future<void> _revokeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out other devices?'),
        content: const Text('All other Novyn login sessions will be signed out. This device will remain connected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sign out others')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isRevokingAll = true);
    final result = await ApiService.revokeOtherSessions();
    if (!mounted) return;
    setState(() => _isRevokingAll = false);
    if (result['ok'] == true) {
      await _loadSessions();
      if (!mounted) return;
      final count = (result['revoked'] as num?)?.toInt() ?? 0;
      context.showNovynAlert(SnackBar(behavior: SnackBarBehavior.floating,
          content: Text(count == 0 ? 'No other active sessions were found.' : 'Signed out of $count other session(s).')));
    } else {
      context.showNovynAlert(SnackBar(behavior: SnackBarBehavior.floating,
          content: Text(result['message']?.toString() ?? 'Could not sign out other devices.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sessions = _sessions ?? const <Map<String, dynamic>>[];
    final remote = sessions.where((session) => session['current'] != true).toList();
    final currentSessions = sessions.where((session) => session['current'] == true).toList();
    final current = currentSessions.isEmpty ? null : currentSessions.first;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Active Sessions'),
        backgroundColor: NovynTheme.pageBg(context),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [IconButton(tooltip: 'Refresh sessions', onPressed: _loadSessions, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairWebDeviceScreen()))
                  .then((_) => _loadSessions()),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Pair a web device'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
            const SizedBox(height: 22),
            Text('THIS DEVICE', style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            _sessionCard(context, current, isCurrent: true),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text('OTHER DEVICES', style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              if (!_loading && remote.isNotEmpty)
                Text('${remote.length} active', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_sessions == null)
              _emptyMessage(context, Icons.cloud_off_rounded, 'Could not load sessions', 'Check your connection and pull down to retry.')
            else if (remote.isEmpty)
              _emptyMessage(context, Icons.devices_rounded, 'No other active sessions', 'Paired web devices and other signed-in devices will appear here.')
            else
              ...remote.map((session) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _sessionCard(context, session))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isRevokingAll || remote.isEmpty ? null : _revokeAll,
              icon: _isRevokingAll ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout_rounded),
              label: Text(_isRevokingAll ? 'Signing out…' : 'Sign out all other devices'),
              style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 19, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text('Signing out a device revokes its Novyn session. It will need to sign in or pair again.', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, Map<String, dynamic>? session, {bool isCurrent = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = isCurrent ? 'This device' : (session?['deviceName']?.toString() ?? 'Unknown device');
    final rawActiveAt = session?['lastActiveAt'];
    final activeAt = rawActiveAt is num && rawActiveAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(rawActiveAt.toInt())
        : rawActiveAt is String
            ? DateTime.tryParse(rawActiveAt)
            : null;
    final activeLabel = isCurrent ? 'Current session' : activeAt == null ? 'Signed in' : 'Last active ${_relativeTime(activeAt)}';
    final id = session?['id']?.toString() ?? '';
    final revoking = id.isNotEmpty && _revokingId == id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: isCurrent ? const Color(0xFF10B981).withValues(alpha: .5) : colors.outlineVariant.withValues(alpha: .55))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Icon((session?['client'] == 'web') ? Icons.laptop_mac_rounded : Icons.phone_android_rounded, color: colors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(activeLabel, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ])),
        if (isCurrent)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
        else
          IconButton(tooltip: 'Sign out this device', onPressed: revoking ? null : () => _revokeOne(session!),
              icon: revoking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.logout_rounded, color: colors.error)),
      ]),
    );
  }

  Widget _emptyMessage(BuildContext context, IconData icon, String title, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [Icon(icon, color: colors.onSurfaceVariant), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant))]));
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time.toLocal());
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
