import 'dart:ui';
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
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: _ConfirmRevokeDialog(
          title: 'Sign out this device?',
          content: 'Novyn will be signed out on ${session['deviceName'] ?? 'this device'}.',
          confirmLabel: 'Sign out',
        ),
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
      context.showNovynAlert(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Device signed out.'),
        ),
      );
    } else {
      context.showNovynAlert(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result['message']?.toString() ?? 'Could not sign out this device.'),
        ),
      );
    }
  }

  Future<void> _revokeAll() async {
    final remoteCount =
        (_sessions ?? []).where((s) => s['current'] != true).length;
    final countText = remoteCount == 1 ? '1 device' : '$remoteCount devices';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: _ConfirmRevokeDialog(
          title: 'Sign out all other devices?',
          content: '$countText will be signed out. It will need to sign in or pair again.',
          confirmLabel: 'Sign out',
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isRevokingAll = true);
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
    final result = await ApiService.revokeOtherSessions();
    if (!mounted) return;
    setState(() => _isRevokingAll = false);
    if (result['ok'] == true) {
      await _loadSessions();
      if (!mounted) return;
      final count = (result['revoked'] as num?)?.toInt() ?? 0;
      context.showNovynAlert(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(count == 0
              ? 'No other active sessions were found.'
              : 'Signed out of $count other session(s).'),
        ),
      );
    } else {
      context.showNovynAlert(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result['message']?.toString() ?? 'Could not sign out other devices.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sessions = _sessions ?? const <Map<String, dynamic>>[];
    final remote = sessions.where((session) => session['current'] != true).toList();
    final currentSessions = sessions.where((session) => session['current'] == true).toList();
    final current = currentSessions.isEmpty ? null : currentSessions.first;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSessions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            children: [
              _ActiveSessionsHeader(
                title: 'Active Sessions',
                onBack: () => Navigator.maybePop(context),
                onRefresh: () {
                  HapticService.vibrate(NovynHapticType.light);
                  _loadSessions();
                },
              ),
              const SizedBox(height: 14),

              // THIS DEVICE Section
              Text(
                'This device',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _ThisDeviceCard(session: current),
              const SizedBox(height: 22),

              const SizedBox(height: 20),
              // Pair a web device action card
              _PairWebDeviceCard(
                onTap: () {
                  HapticService.vibrate(NovynHapticType.selection);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PairWebDeviceScreen()),
                  ).then((_) => _loadSessions());
                },
              ),
              const SizedBox(height: 22),

              const SizedBox(height: 22),
              // OTHER DEVICES Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Other devices',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!_loading && remote.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${remote.length} active',
                        style: const TextStyle(
                          color: Color(0xFF6D5DFC),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6D5DFC)),
                  ),
                )
              else if (_sessions == null)
                _emptyMessage(
                  context,
                  Icons.cloud_off_rounded,
                  'Could not load sessions',
                  'Check your connection and pull down to retry.',
                )
              else if (remote.isEmpty)
                _emptyMessage(
                  context,
                  Icons.devices_rounded,
                  'No other active sessions',
                  'Paired web devices and other signed-in devices will appear here.',
                )
              else
                ...remote.map((session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RemoteDeviceCard(
                        session: session,
                        revoking: _revokingId == session['id']?.toString(),
                        onSignOut: () => _revokeOne(session),
                      ),
                    )),
              const SizedBox(height: 8),

              // Sign out all other devices button
              if (!_loading && remote.isNotEmpty) ...[
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isRevokingAll ? null : _revokeAll,
                    icon: _isRevokingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      _isRevokingAll ? 'Signing out…' : 'Sign out all other devices',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFFE11D48).withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Info note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF202035)
                      : const Color(0xFFF0EDFF).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF6D5DFC),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Signing out a device revokes its Novyn session. It will need to sign in or pair again.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(
      BuildContext context, IconData icon, String title, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colors.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionsHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _ActiveSessionsHeader({
    required this.title,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Material(
            color: dark ? const Color(0xFF161726) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.arrow_back_rounded, color: ink, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          Material(
            color: dark ? const Color(0xFF161726) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.refresh_rounded, color: ink, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairWebDeviceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PairWebDeviceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF221F3A)
                : const Color(0xFFF5F3FF).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF6D5DFC).withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DFC),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D5DFC).withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pair a web device',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6D5DFC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Scan a code to link a browser',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6D5DFC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThisDeviceCard extends StatelessWidget {
  final Map<String, dynamic>? session;

  const _ThisDeviceCard({this.session});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Color(0xFF6D5DFC),
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This device',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Android · Current session',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF10B981),
                ),
                SizedBox(width: 5),
                Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteDeviceCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool revoking;
  final VoidCallback onSignOut;

  const _RemoteDeviceCard({
    required this.session,
    required this.revoking,
    required this.onSignOut,
  });

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time.toLocal());
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = session['client'] == 'web';
    final deviceName = session['deviceName']?.toString().trim() ?? '';
    final title = deviceName.isNotEmpty
        ? deviceName
        : (isWeb ? 'Chrome · Windows browser' : 'Mobile device');

    final rawActiveAt = session['lastActiveAt'];
    final activeAt = rawActiveAt is num && rawActiveAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(rawActiveAt.toInt())
        : rawActiveAt is String
            ? DateTime.tryParse(rawActiveAt)
            : null;
    final activeLabel = activeAt == null ? 'Signed in' : 'Last active ${_relativeTime(activeAt)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isWeb ? Icons.laptop_mac_rounded : Icons.phone_android_rounded,
              color: const Color(0xFF6D5DFC),
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: revoking ? null : onSignOut,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF381F26) : const Color(0xFFFEE8E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: revoking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE11D48),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sign out',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRevokeDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;

  const _ConfirmRevokeDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.outlineVariant),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF381F26) : const Color(0xFFFEE8E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF252538)
                            : const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
