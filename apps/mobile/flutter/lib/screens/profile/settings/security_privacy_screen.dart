import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import 'two_factor_screen.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';
import '../../../widgets/novyn_alert.dart';
import '../../security/setup_pin_screen.dart';
import 'active_sessions_screen.dart';
import 'email_password_screen.dart';
import 'blocked_users_screen.dart';
import '../../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';

class SecurityPrivacyScreen extends StatelessWidget {
  const SecurityPrivacyScreen({super.key, this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final socket = context.read<SocketService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Scaffold(
      backgroundColor: dark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            if (category == 'privacy') ...[
              _ScreenHeader(
                title: 'Privacy Controls',
                onBack: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: 10),
              _PrivacyDashboard(
                lastSeen: settings.lastSeenVisibility,
                profilePhoto: settings.profilePhotoVisibility,
                readReceipts: settings.readReceipts,
                socket: socket,
                settings: settings,
                onBlocked: () => _showBlockedUsers(context, socket),
                onStealthModeChanged: (enabled) =>
                    _setStealthMode(context, settings, enabled),
                onDndChanged: settings.setDoNotDisturbEnabled,
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 18),
                child: Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      InkWell(
                        onTap: () {
                          HapticService.vibrate(NovynHapticType.light);
                          Navigator.maybePop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: ink,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Text(
                        category == null
                            ? 'Security & Privacy'
                            : switch (category) {
                                'security' => 'Account Security',
                                'device' => 'Device & Account',
                                'danger' => 'Danger Zone',
                                _ => 'Security & Privacy',
                              },
                        style: TextStyle(
                          color: ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (category == null) ...[
                _sectionHeader('MANAGE'),
                _groupedCard(
                  context,
                  children: [
                    _SettingsRow(
                      leading: _iconBox(
                        Icons.remove_red_eye_outlined,
                        const Color(0xFF10B981),
                        dark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                      ),
                      title: 'Privacy Controls',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityPrivacyScreen(category: 'privacy'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (category == null || category == 'security') ...[
                _sectionHeader('SIGN-IN & DEVICE PROTECTION'),
                _groupedCard(
                  context,
                  children: [
                    _SettingsRow(
                      leading: _iconBox(
                        Icons.alternate_email_rounded,
                        const Color(0xFF10B981),
                        dark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                      ),
                      title: 'Account Info',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
                      ),
                    ),
                    _SettingsRow(
                      leading: _iconBox(                        Icons.devices_rounded,
                        const Color(0xFF2563EB),
                        dark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                      ),
                      title: 'Active Sessions',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()),
                      ),
                    ),
                    _SettingsRow(
                      leading: _iconBox(
                        Icons.verified_user_outlined,
                        const Color(0xFF6366F1),
                        dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                      ),
                      title: 'Two-Factor Authentication',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TwoFactorScreen()),
                      ),
                    ),
                    _SettingsRow(
                      leading: _iconBox(
                        Icons.lock_outline_rounded,
                        const Color(0xFFD97706),
                        dark ? const Color(0xFF382A1B) : const Color(0xFFFEF3C7),
                      ),
                      title: 'App Lock',
                      trailing: _purpleSwitch(
                        value: settings.appLockEnabled,
                        onChanged: (v) => _handleAppLockToggle(context, settings, v),
                        context: context,
                      ),
                    ),
                    if (settings.appLockEnabled) ...[
                      _SettingsRow(
                        leading: _iconBox(
                          Icons.timer_outlined,
                          const Color(0xFF6366F1),
                          dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                        ),
                        title: 'Auto-lock',
                        trailing: _pillDropdown(
                          text: _lockTimeoutLabel(settings.appLockTimeout),
                          onTap: () => _showAutoLockChoice(context, settings),
                          context: context,
                        ),
                      ),
                      _SettingsRow(
                        leading: _iconBox(
                          Icons.password_rounded,
                          const Color(0xFF6366F1),
                          dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                        ),
                        title: 'Change PIN',
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF8F8BA0),
                          size: 20,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SetupPinScreen(isChanging: true),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (category == null || category == 'device' || category == 'danger') ...[
                _sectionHeader('CHAT PRIVACY & ACCOUNT ACTIONS'),
                _groupedCard(
                  context,
                  bg: dark ? const Color(0xFF33191B) : const Color(0xFFFFF1EE),
                  border: Border.all(
                    color: dark ? const Color(0xFF5A2228) : const Color(0xFFFFDDD7),
                  ),
                  children: [
                    _SettingsRow(
                      leading: _iconBox(
                        Icons.delete_outline_rounded,
                        const Color(0xFFD32F2F),
                        dark ? const Color(0xFF4A1B20) : const Color(0xFFFDE8E8),
                      ),
                      title: 'Delete Account',
                      titleColor: const Color(0xFFD32F2F),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFD32F2F),
                        size: 20,
                      ),
                      onTap: () => _showDeleteAccount(context),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF6246EA),
        ),
      ),
    );
  }

  static Widget _iconBox(IconData icon, Color color, Color bg) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  static Widget _purpleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    required BuildContext context,
  }) {    final dark = Theme.of(context).brightness == Brightness.dark;
    return Switch.adaptive(
      value: value,
      activeColor: Colors.white,
      activeTrackColor: Theme.of(context).colorScheme.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: dark ? const Color(0xFF3B394E) : const Color(0xFFE2E0EC),
      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      onChanged: (next) {
        HapticService.vibrate(NovynHapticType.selection);
        onChanged(next);
      },
    );
  }

  static Widget _pillDropdown({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticService.vibrate(NovynHapticType.selection);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2849) : const Color(0xFFECE9FB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _groupedCard(
    BuildContext context, {
    required List<Widget> children,
    Color? bg,
    Border? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = bg ?? (isDark ? const Color(0xFF1E1C2E) : Colors.white);
    final cardBorder = border ??
        Border.all(color: isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: 16,
                color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
              ),
          ],
        ],
      ),
    );
  }

  static String _lockTimeoutLabel(int timeout) {
    return switch (timeout) {
      0 => 'Immediately',
      1 => 'After 1 min',
      5 => 'After 5 mins',
      15 => 'After 15 mins',
      30 => 'After 30 mins',
      _ => 'After ${timeout}m',
    };
  }

  static void _showAutoLockChoice(BuildContext context, SettingsService settings) {
    const options = ['0', '1', '5', '15', '30'];
    const labels = ['Immediately', 'After 1 min', 'After 5 mins', 'After 15 mins', 'After 30 mins'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NovynTheme.cardBg(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-lock timeout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NovynTheme.textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < options.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[i]),
                  trailing: settings.appLockTimeout.toString() == options[i]
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      : Icon(Icons.circle_outlined),
                  onTap: () {
                    settings.setAppLockTimeout(int.parse(options[i]));
                    Navigator.pop(sheetContext);
                  },
                ),
            ],          ),
        ),
      ),
    );
  }

  Future<void> _setStealthMode(
    BuildContext context,
    SettingsService settings,
    bool enabled,
  ) async {
    final socket = context.read<SocketService>();
    final previous = settings.stealthModeEnabled;
    try {
      await settings.setStealthMode(enabled);
      await socket.updateStealthMode(enabled);

      if (!context.mounted) return;
      context.showNovynAlert(
        SnackBar(
          content: Text(enabled
              ? 'Stealth Mode enabled. Your chats are now protected on friends’ Novyn Android devices.'
              : 'Stealth Mode disabled. Your chats can now be captured again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      await settings.setStealthMode(previous);
      if (!context.mounted) return;
      context.showNovynAlert(
        SnackBar(
          content: Text('Could not sync Stealth Mode: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleAppLockToggle(BuildContext context, SettingsService settings, bool enable) async {
    if (enable) {
      if (settings.appLockPin == null) {
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const SetupPinScreen()),
        );
        if (success == true) {
          await settings.setAppLockEnabled(true);
        }
      } else {
        await settings.setAppLockEnabled(true);
      }
    } else {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const SetupPinScreen(isVerifyingOnly: true),
        ),
      );
      if (verified == true) {
        await settings.setAppLockEnabled(false);
        if (context.mounted) {
          NovynAlert.show(
            context,
            'App Lock disabled.',
            title: 'App Lock off',
            icon: Icons.lock_open_rounded,
            tone: NovynAlertTone.neutral,
          );
        }
      }
    }
  }

  void _showBlockedUsers(BuildContext context, SocketService socket) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );
  }

  Future<void> _showDeleteAccount(BuildContext context) async {
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    final username = auth.user?.username ?? '';
    if (username.isEmpty) {
      context.showNovynAlert(
        const SnackBar(content: Text('Please sign in again before deleting your account.')),
      );
      return;
    }

    final confirmationController = TextEditingController();
    final passwordController = TextEditingController();
    String? errorText;
    bool deleting = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final matches = confirmationController.text.trim().toLowerCase() == username.toLowerCase() ||
              confirmationController.text.trim().toLowerCase() == '@${username.toLowerCase()}';
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Expanded(child: Text('Delete Novyn account?')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This permanently deletes your account and associated server data. This cannot be undone.'),
                  const SizedBox(height: 18),
                  Text('Type @$username or $username to confirm.'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() => errorText = null),
                    decoration: const InputDecoration(
                      hintText: '@username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Account password (required if your account has one).'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Current password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: deleting ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: !matches || deleting
                    ? null
                    : () async {
                        setDialogState(() {
                          deleting = true;
                          errorText = null;
                        });
                        try {
                          await socket.deleteAccount(
                            confirmationText: confirmationController.text.trim(),
                            currentPassword: passwordController.text,
                          );
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                        } catch (error) {
                          setDialogState(() {
                            deleting = false;
                            errorText = error.toString().replaceFirst('Bad state: ', '');
                          });
                        }
                      },
                child: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Delete permanently'),
              ),
            ],
          );
        },
      ),
    );
    confirmationController.dispose();
    passwordController.dispose();

    if (confirmed == true && context.mounted) {
      socket.disconnect();
      await auth.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        context.showNovynAlert(
          const SnackBar(content: Text('Your Novyn account has been deleted.')),
        );
      }
    }
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ScreenHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              HapticService.vibrate(NovynHapticType.light);
              onBack();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ink,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsRow({
    this.leading,
    required this.title,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = titleColor ?? (dark ? Colors.white : const Color(0xFF1A1730));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticService.vibrate(NovynHapticType.selection);
                onTap!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],          ),
        ),
      ),
    );
  }
}

class _PrivacyDashboard extends StatefulWidget {
  const _PrivacyDashboard({
    required this.lastSeen,
    required this.profilePhoto,
    required this.readReceipts,
    required this.socket,
    required this.settings,
    required this.onBlocked,
    required this.onStealthModeChanged,
    required this.onDndChanged,
  });

  final String lastSeen;
  final String profilePhoto;
  final bool readReceipts;
  final SocketService socket;
  final SettingsService settings;
  final VoidCallback onBlocked;
  final ValueChanged<bool> onStealthModeChanged;
  final ValueChanged<bool> onDndChanged;

  @override
  State<_PrivacyDashboard> createState() => _PrivacyDashboardState();
}

class _PrivacyDashboardState extends State<_PrivacyDashboard> {
  final Map<String, String> _values = {
    'callPrivacy': 'friends',
    'messagePrivacy': 'friends',
    'groupInvitePrivacy': 'friends',
    'friendRequestPrivacy': 'mutuals',
    'presencePrivacy': 'friends',
    'profilePhotoPrivacy': 'friends',
  };
  bool _typing = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _values['profilePhotoPrivacy'] =
        widget.profilePhoto == 'contacts' ? 'friends' : widget.profilePhoto;
    _values['presencePrivacy'] =
        widget.lastSeen == 'contacts' ? 'friends' : widget.lastSeen;
    _loadAccountSettings();
  }

  Future<void> _loadAccountSettings() async {
    try {
      final result = await widget.socket.fetchAccountSettings();
      if (result['ok'] != true || result['settings'] is! Map) return;
      final data = Map<String, dynamic>.from(result['settings'] as Map);
      const stringKeys = [
        'callPrivacy',
        'messagePrivacy',
        'profilePhotoPrivacy',
        'presencePrivacy',
        'groupInvitePrivacy',
        'friendRequestPrivacy',
      ];
      if (!mounted) return;
      setState(() {
        for (final key in stringKeys) {
          final value = data[key]?.toString();
          if (value != null && value.isNotEmpty) _values[key] = value;
        }
        _typing = data['typingIndicatorsEnabled'] != false;
      });
      final presence = _values['presencePrivacy']!;
      final photo = _values['profilePhotoPrivacy']!;
      await widget.settings.setLastSeenVisibility(
          presence == 'friends' ? 'contacts' : presence,
          recordPresenceOverride: false);
      await widget.settings.setProfilePhotoVisibility(
          photo == 'friends' ? 'contacts' : photo,
          recordPresenceOverride: false);
      await widget.settings.setReadReceipts(
          data['readReceiptsEnabled'] != false,
          recordPresenceOverride: false);
    } catch (_) {
      // Keep defaults
    }
  }

  bool _requireStealthModeOff() {
    if (!widget.settings.stealthModeEnabled) return false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.visibility_off_rounded),
        title: const Text('Stealth Mode is on'),
        content: const Text(
          'Turn off Stealth Mode first to change your privacy settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _save(String key, String value) async {
    if (_requireStealthModeOff()) return;
    if (_saving) return;
    final previous = _values[key] ?? 'everyone';
    setState(() {
      _saving = true;
      _values[key] = value;
    });
    try {
      final result = await widget.socket.updateAccountSettings({key: value});
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ?? 'Could not save setting.');
      }
      if (key == 'presencePrivacy') {
        await widget.settings.setLastSeenVisibility(
            value == 'friends' ? 'contacts' : value,
            recordPresenceOverride: false);
      } else if (key == 'profilePhotoPrivacy') {
        await widget.settings.setProfilePhotoVisibility(
            value == 'friends' ? 'contacts' : value,
            recordPresenceOverride: false);
      }
      await widget.settings.saveSmartPresenceOverride(
          widget.settings.activeSmartPresenceMode, key, value);
      if (mounted) NovynAlert.show(context, 'Privacy setting updated.');
    } catch (error) {
      if (mounted) {
        setState(() => _values[key] = previous);
        NovynAlert.show(
            context, error.toString().replaceFirst('Bad state: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveToggle(String key, bool value) async {    if (_requireStealthModeOff()) return;
    if (_saving) return;
    final previous = key == 'readReceiptsEnabled'
        ? widget.settings.readReceipts
        : _typing;
    setState(() => _saving = true);
    try {
      final result = await widget.socket.updateAccountSettings({key: value});
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ?? 'Could not save setting.');
      }
      if (key == 'readReceiptsEnabled') {
        await widget.settings.setReadReceipts(value, recordPresenceOverride: false);
      } else {
        setState(() => _typing = value);
      }
      await widget.settings.saveSmartPresenceOverride(
          widget.settings.activeSmartPresenceMode, key, value);
      if (mounted) NovynAlert.show(context, 'Privacy setting updated.');
    } catch (error) {
      if (mounted) {
        if (key == 'typingIndicatorsEnabled') {
          setState(() => _typing = previous);
        }
        NovynAlert.show(
            context, error.toString().replaceFirst('Bad state: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(String value) => switch (value) {
        'everyone' => 'Everyone',
        'friends' => 'Friends',
        'contacts' => 'Friends',
        'mutuals' => 'Mutuals',
        'nobody' => 'No one',
        _ => 'Friends',
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CHAT PROTECTION
        SecurityPrivacyScreen._sectionHeader('CHAT PROTECTION'),
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.visibility_off_outlined,
                const Color(0xFFD97706),
                dark ? const Color(0xFF382A1B) : const Color(0xFFFEF3E2),
              ),
              title: 'Stealth Mode',
              trailing: SecurityPrivacyScreen._purpleSwitch(
                value: widget.settings.stealthModeEnabled,
                onChanged: (v) {
                  if (!_saving) widget.onStealthModeChanged(v);
                },
                context: context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // NOTIFICATION PRIVACY
        SecurityPrivacyScreen._sectionHeader('NOTIFICATION PRIVACY'),
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.do_not_disturb_on_outlined,
                const Color(0xFF6366F1),
                dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              ),
              title: 'Do Not Disturb',
              trailing: SecurityPrivacyScreen._purpleSwitch(
                value: widget.settings.doNotDisturbEnabled,
                onChanged: (v) {
                  if (!_saving) widget.onDndChanged(v);
                },
                context: context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // PROFILE VISIBILITY
        SecurityPrivacyScreen._sectionHeader('PROFILE VISIBILITY'),
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.account_circle_outlined,
                const Color(0xFFEC4899),
                dark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
              ),
              title: 'Profile photo',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['profilePhotoPrivacy'] ?? 'friends'),
                onTap: () => _choose('profilePhotoPrivacy',
                    _values['profilePhotoPrivacy'] ?? 'friends',
                    const ['everyone', 'friends', 'nobody']),
                context: context,
              ),
            ),
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.remove_red_eye_outlined,
                const Color(0xFF10B981),
                dark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
              ),
              title: 'Online & last seen',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['presencePrivacy'] ?? 'friends'),
                onTap: () => _choose('presencePrivacy',
                    _values['presencePrivacy'] ?? 'friends',
                    const ['everyone', 'friends', 'nobody']),
                context: context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // WHO CAN REACH YOU
        SecurityPrivacyScreen._sectionHeader('WHO CAN REACH YOU'),
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.phone_outlined,
                const Color(0xFF10B981),
                dark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
              ),
              title: 'Who can call me',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['callPrivacy'] ?? 'friends'),                onTap: () => _choose('callPrivacy',
                    _values['callPrivacy'] ?? 'friends',
                    const ['everyone', 'friends', 'nobody']),
                context: context,
              ),
            ),
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.chat_bubble_outline_rounded,
                const Color(0xFF2563EB),
                dark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
              ),
              title: 'Who can message me',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['messagePrivacy'] ?? 'friends'),
                onTap: () => _choose('messagePrivacy',
                    _values['messagePrivacy'] ?? 'friends',
                    const ['everyone', 'friends', 'nobody']),
                context: context,
              ),
            ),
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.group_outlined,
                const Color(0xFFD97706),
                dark ? const Color(0xFF382A1B) : const Color(0xFFFEF3C7),
              ),
              title: 'Who can add me to groups',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['groupInvitePrivacy'] ?? 'friends'),
                onTap: () => _choose('groupInvitePrivacy',
                    _values['groupInvitePrivacy'] ?? 'friends',
                    const ['everyone', 'friends', 'nobody']),
                context: context,
              ),
            ),
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.person_add_outlined,
                const Color(0xFF6366F1),
                dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              ),
              title: 'Friend requests',
              trailing: SecurityPrivacyScreen._pillDropdown(
                text: _label(_values['friendRequestPrivacy'] ?? 'mutuals'),
                onTap: () => _choose('friendRequestPrivacy',
                    _values['friendRequestPrivacy'] ?? 'mutuals',
                    const ['everyone', 'mutuals', 'nobody']),
                context: context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ACTIVITY & READ STATUS
        SecurityPrivacyScreen._sectionHeader('ACTIVITY & READ STATUS'),
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.done_all_rounded,
                const Color(0xFF6366F1),
                dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              ),
              title: 'Read receipts',
              trailing: SecurityPrivacyScreen._purpleSwitch(
                value: widget.readReceipts,
                onChanged: (v) => _saveToggle('readReceiptsEnabled', v),
                context: context,
              ),
            ),
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.keyboard_outlined,
                const Color(0xFF6366F1),
                dark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
              ),
              title: 'Typing status',
              trailing: SecurityPrivacyScreen._purpleSwitch(
                value: _typing,
                onChanged: (v) => _saveToggle('typingIndicatorsEnabled', v),
                context: context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Blocked contacts & Message retention
        SecurityPrivacyScreen._groupedCard(
          context,
          children: [
            _SettingsRow(
              leading: SecurityPrivacyScreen._iconBox(
                Icons.block_rounded,
                const Color(0xFFEC4899),
                dark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
              ),
              title: 'Blocked contacts',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8F8BA0),
                size: 20,
              ),
              onTap: widget.onBlocked,
            ),

          ],
        ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            'NOVYN · YOUR SPACE, YOUR PEOPLE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Color(0xFFA19DB5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _choose(String key, String current, List<String> options) async {
    if (_requireStealthModeOff()) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {        final colors = Theme.of(sheetContext).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Who can see or contact you?',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                for (final option in options)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: option == current
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: .09)
                        : colors.surfaceContainerHighest.withValues(alpha: .35),
                    leading: Icon(
                      option == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: option == current
                          ? Theme.of(context).colorScheme.primary
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      _label(option),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: option == current
                            ? Theme.of(context).colorScheme.primary
                            : colors.onSurface,
                      ),
                    ),
                    trailing: option == current
                        ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != current) await _save(key, selected);
  }
}