import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import 'two_factor_screen.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';
import '../../../widgets/novyn_alert.dart';
import '../../../widgets/import_message_keys_dialog.dart';
import '../../security/setup_pin_screen.dart';
import 'active_sessions_screen.dart';
import 'email_password_screen.dart';
import 'blocked_users_screen.dart';
import '../../../theme/novyn_theme.dart';
import '../widgets/profile_widgets.dart';
import 'package:novyn/services/haptic_service.dart';

class SecurityPrivacyScreen extends StatelessWidget {
  const SecurityPrivacyScreen({super.key, this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final socket = context.read<SocketService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = Theme.of(context).colorScheme.primary;

    Widget heading(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: color ?? accent)),
    );
    Widget group(List<Widget> children) => Container(
      decoration: BoxDecoration(color: NovynTheme.cardBg(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) Padding(padding: const EdgeInsets.only(left: 70), child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor)), children[i]]]),
    );
    Widget section(String title, List<Widget> children, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading(title, color: color), group(children), const SizedBox(height: 22)]);
    Widget nav(IconData icon, Color color, String title, String subtitle, VoidCallback onTap, {Widget? trailing}) => _SecurityPrivacyTile(icon: icon, accent: color, title: title, subtitle: subtitle, onTap: onTap, trailing: trailing);

    return Scaffold(
      backgroundColor: category == 'privacy' && !dark
          ? const Color(0xFFF4F0FB)
          : NovynTheme.pageBg(context),
      body: SafeArea(child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, category == 'privacy' ? 5 : 12, 20, 30),
        children: [
          if (category == 'privacy')
            const _PrivacyPageHeader(
              title: 'Privacy Controls',
              subtitle: 'Control your visibility and interactions',
            )
          else
            SettingsPageHeader(
              title: category == null ? 'Security & Privacy' : switch (category) {
                'security' => 'Account Security',
                'device' => 'Device & Account',
                'danger' => 'Danger Zone',
                _ => 'Security & Privacy',
              },
              subtitle: category == null
                  ? 'Keep your account and chats safe'
                  : switch (category) {
                      'security' => 'Manage sign-in and device protection',
                      'device' => 'Device privacy and account actions',
                      'danger' => 'Manage permanent account actions',
                      _ => 'Keep your account and chats safe',
                    },
            ),
          SizedBox(height: category == 'privacy' ? 8 : 20),
          if (category == null) ...[
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: NovynTheme.cardBg(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF8172F2), Color(0xFF4B3BC8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(settings.appLockEnabled ? 'Your account is protected' : 'Your account, protected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Your security and privacy settings, neatly organised.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.4)),
                  ])),
                ]),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FB56A).withValues(alpha: dark ? .16 : .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1F9D61)),
                      const SizedBox(width: 7),
                      Text(settings.appLockEnabled ? 'App Lock enabled' : 'Privacy controls available',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F9D61))),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            section('Manage', [
              nav(Icons.visibility_outlined, const Color(0xFF238B9B),
                'Privacy Controls', 'Profile visibility, read receipts and blocked contacts',
                () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SecurityPrivacyScreen(category: 'privacy')))),
            ]),
          ],
          if (category == null || category == 'security') section('Sign-in & device protection', [
            nav(Icons.alternate_email_rounded, const Color(0xFF1F8A63),
              'Account Info', 'Manage your username, email and password',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountInfoScreen()))),
            nav(Icons.devices_rounded, const Color(0xFF2A78B8),
              'Active Sessions', 'Sign out of other devices remotely',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()))),
            nav(Icons.key_rounded, const Color(0xFF8B5CF6),
              'Import message keys', 'Sync encrypted chat history from your Novyn web browser',
              () => showImportMessageKeys(context)),
            _SecurityPrivacyTile(
              icon: Icons.verified_user_outlined,
              accent: const Color(0xFF7565D9),
              title: 'Two-Factor Authentication',
              subtitle: 'Authenticator app and one-time backup codes',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TwoFactorScreen(),
              )),
            ),
            _SecurityPrivacyToggleTile(
              icon: Icons.fingerprint_rounded, accent: const Color(0xFFB7791F),
              title: 'App Lock', subtitle: 'Require your PIN or available biometrics to open Novyn',
              value: settings.appLockEnabled,
              onChanged: (v) => _handleAppLockToggle(context, settings, v),
            ),
            if (settings.appLockEnabled) _SelectionCard(
              icon: Icons.timer_outlined, iconColor: const Color(0xFF64748B),
              iconBgColor: const Color(0xFF64748B).withValues(alpha: .12),
              title: 'Auto-lock', subtitle: 'When to lock after leaving app',
              value: settings.appLockTimeout.toString(),
              options: const ['0', '1', '5', '15', '30'],
              labels: const ['Immediately', 'After 1 min', 'After 5 mins', 'After 15 mins', 'After 30 mins'],
              onChanged: (v) {
                settings.setAppLockTimeout(int.parse(v));
                const labels = ['Immediately', 'After 1 min', 'After 5 mins', 'After 15 mins', 'After 30 mins'];
                const values = ['0', '1', '5', '15', '30'];
                NovynAlert.show(context, 'Auto-lock updated: ${labels[values.indexOf(v)]}.');
              },
            ),
            if (settings.appLockEnabled) nav(
              Icons.password_rounded, const Color(0xFF64748B), 'Change PIN',
              'Verify your current PIN and set a new one',
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SetupPinScreen(isChanging: true))),
            ),
          ]),
          if (category == null || category == 'device') section('Chat privacy & account actions', [
            _SecurityPrivacyTile(
              icon: Icons.delete_outline_rounded,
              accent: const Color(0xFFB3261E),
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and associated data',
              isDanger: true,
              onTap: () => _showDeleteAccount(context),
            ),
          ], color: const Color(0xFFB3261E)),
          if (category == 'privacy')
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
          const SizedBox(height: 4),
          Center(child: Text('NOVYN · YOUR SPACE, YOUR PEOPLE',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
              letterSpacing: 1.4, color: muted))),
        ],
      )),
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
      // Save locally for immediate UI state, then persist the account preference.
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

  void _showChangePassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }

  void _handleAppLockToggle(BuildContext context, SettingsService settings, bool enable) async {
    if (enable) {
      // 1. Check if PIN is already set
      if (settings.appLockPin == null) {
        final success = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SetupPinScreen()),
        );
        if (success != true) return; // User cancelled PIN setup
      }

      try {
        await settings.setAppLockEnabled(true);
        if (context.mounted) NovynAlert.show(context, 'App Lock enabled successfully.');
      } catch (error) {
        if (context.mounted) {
          NovynAlert.show(
            context,
            error.toString().replaceFirst('Bad state: ', ''),
            isError: true,
          );
        }
      }
    } else {
      await settings.setAppLockEnabled(false);
      if (context.mounted) NovynAlert.show(context, 'App Lock disabled.');
    }
  }

  void _handleTwoFactorAuth(BuildContext context, SettingsService settings, bool enable) {
    if (enable) {
      _showTwoFactorSetup(context, settings);
    } else {
      _showTwoFactorDisable(context, settings);
    }
  }

  void _showTwoFactorSetup(BuildContext context, SettingsService settings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TwoFactorSetupDialog(settings: settings),
    );
  }

  void _showTwoFactorDisable(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          title: const Text(
            'Disable 2FA?',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900),
          ),
          content: Text(
            'This will weaken your security node. Are you sure you want to proceed?',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticService.vibrate(NovynHapticType.heavy, category: HapticCategory.buttons);
                Navigator.pop(context);
                settings.setTwoFactorAuth(false);
                context.showNovynAlert(
                  const SnackBar(
                    content: Text('Two-factor authentication disabled'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Disable',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  Text('Type @${username} or ${username} to confirm.'),
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
                    Text(errorText!, style: const TextStyle(color: Color(0xFFEF4444))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: deleting ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
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

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onChanged == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: disabled ? null : (v) {
                  HapticService.vibrate(NovynHapticType.light, category: HapticCategory.buttons);
                  onChanged?.call(v);
                },
                activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                activeColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                  size: 22
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const _SelectionCard({
    required this.icon, required this.iconColor, required this.iconBgColor,
    required this.title, required this.subtitle, required this.value,
    required this.options, required this.labels, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final index = options.indexOf(value);
    final selectedLabel = index >= 0 ? labels[index] : labels.first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSelectionSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: iconBgColor,
                borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.schedule_rounded, color: iconColor, size: 23)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant, height: 1.3)),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(selectedLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 3),
                Icon(Icons.keyboard_arrow_down_rounded, color: colors.primary, size: 18),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showSelectionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .14),
              blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(color: iconBgColor,
                  borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.access_time_rounded, color: iconColor, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Choose when Novyn should lock itself',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant)),
              ])),
            ]),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                childAspectRatio: 1.28),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = value == option;
                final label = labels[index];
                final detail = option == '0' ? 'On leaving the app'
                  : 'After ' + option + ' ' + (option == '1' ? 'minute' : 'minutes');
                return Material(
                  color: selected ? colors.primary.withValues(alpha: .10)
                    : colors.surfaceContainerHighest.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
                      onChanged(option);
                      Navigator.pop(sheetContext);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: selected ? colors.primary : colors.outlineVariant,
                          width: selected ? 1.5 : 1)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Container(width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: selected ? colors.primary.withValues(alpha: .14) : colors.surface,
                                borderRadius: BorderRadius.circular(11)),
                              child: Icon(option == '0' ? Icons.lock_clock_rounded : Icons.schedule_rounded,
                                color: selected ? colors.primary : colors.onSurfaceVariant, size: 19)),
                            if (selected) Icon(Icons.check_circle_rounded,
                              color: colors.primary, size: 19),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: selected ? colors.primary : colors.onSurface)),
                            const SizedBox(height: 2),
                            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.read<AuthService>();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        title: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary, Color(0xFF40E0D0)],
                ).createShader(bounds),
                child: const Text(
                  'Update Password',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Use at least 12 characters for your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),
              _buildDialogField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscure: _obscureCurrentPassword,
                onToggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                controller: _newPasswordController,
                label: 'New Password',
                obscure: _obscureNewPassword,
                onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscure: _obscureConfirmPassword,
                onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary, Color(0xFF40E0D0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      if (_newPasswordController.text.isEmpty || _currentPasswordController.text.isEmpty) {
                        context.showNovynAlert(
                          const SnackBar(content: Text('Please fill all fields'), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      if (_newPasswordController.text != _confirmPasswordController.text) {
                        context.showNovynAlert(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);
                      HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);

                      final error = await auth.changePassword(
                        _currentPasswordController.text,
                        _newPasswordController.text,
                      );

                      if (mounted && context.mounted) {
                        setState(() => _isLoading = false);
                        final messenger = ScaffoldMessenger.of(context);
                        if (error == null) {
                          // The backend revokes every refresh session after a password
                          // change. Clear this device's local auth state as well so the
                          // user is explicitly required to sign in with the new password.
                          await auth.logout();
                          if (!mounted) return;
                          Navigator.pop(context);
                          messenger.showNovynAlert(
                            const SnackBar(
                              content: Text('Password updated. Please sign in again.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } else {
                          messenger.showNovynAlert(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans', 
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: NovynTheme.inputBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        cursorColor: Theme.of(context).colorScheme.primary,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans', 
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          floatingLabelStyle: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, 
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _TwoFactorSetupDialog extends StatefulWidget {
  final SettingsService settings;
  const _TwoFactorSetupDialog({required this.settings});

  @override
  State<_TwoFactorSetupDialog> createState() => _TwoFactorSetupDialogState();
}

class _TwoFactorSetupDialogState extends State<_TwoFactorSetupDialog> {
  int _step = 0; // 0: Intro, 1: Loading/Sending, 2: OTP Input
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isFinalizing = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    setState(() => _step++);
    if (_step == 1) {
      HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _step = 2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildIntro();
      case 1: return _buildSending();
      case 2: return _buildOTPInput();
      default: return const SizedBox();
    }
  }

  Widget _buildIntro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.security_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enable 2FA',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 12),
        Text(
          'Two-factor authentication adds an elite layer of protection. We will send a verification node to your primary contact.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Begin Setup', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSending() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Sending Code',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          'Synthesizing verification node...',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Verify Identity',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900, fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to you.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 42,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900, fontSize: 20),
                decoration: InputDecoration(
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
                    if (index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else {
                      _focusNodes[index].unfocus();
                      _finalize();
                    }
                  } else if (index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        if (_isFinalizing)
          CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)
        else
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: Text(
              'Resend Code',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
            ),
          ),
      ],
    );
  }

  void _finalize() async {
    setState(() => _isFinalizing = true);
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
    
    // Simulate verification delay
    await Future.delayed(const Duration(seconds: 1));
    
    widget.settings.setTwoFactorAuth(true);
    
    if (mounted) {
      Navigator.pop(context);
      context.showNovynAlert(
        const SnackBar(
          content: Text('Security Node Established Successfully'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SecurityPrivacyTile extends StatelessWidget {
  const _SecurityPrivacyTile({required this.icon, required this.accent, required this.title, required this.subtitle, required this.onTap, this.trailing, this.isDanger = false});
  final IconData icon; final Color accent; final String title; final String subtitle; final VoidCallback onTap; final Widget? trailing; final bool isDanger;
  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(color: isDanger ? const Color(0xFFB3261E).withValues(alpha: dark ? .10 : .055) : Colors.transparent, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13), child: Row(children: [
      Container(width: 43, height: 43, decoration: BoxDecoration(color: accent.withValues(alpha: dark ? .18 : .11), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 21)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: isDanger ? const Color(0xFFB3261E) : Theme.of(context).colorScheme.onSurface)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5, height: 1.35, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
      const SizedBox(width: 8), trailing ?? Icon(Icons.chevron_right_rounded, color: isDanger ? const Color(0xFFB3261E) : Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
    ]))));
  }
}

class _SecurityPrivacyToggleTile extends StatelessWidget {
  const _SecurityPrivacyToggleTile({required this.icon, required this.accent, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon; final Color accent; final String title; final String subtitle; final bool value; final ValueChanged<bool>? onChanged;
  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(opacity: onChanged == null ? .58 : 1, child: _SecurityPrivacyTile(icon: icon, accent: accent, title: title, subtitle: subtitle, onTap: onChanged == null ? () {} : () => onChanged!(!value), trailing: Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: Theme.of(context).colorScheme.primary, activeColor: Colors.white, inactiveTrackColor: dark ? const Color(0xFF454456) : const Color(0xFFD7D2F0))));
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
    'friendRequestPrivacy': 'everyone',
    'presencePrivacy': 'everyone',
  };
  bool _typing = true;
  bool _loading = true;
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
      if (result['ok'] != true || result['settings'] is! Map) {
        throw StateError(result['message']?.toString() ??
            'Could not load your privacy settings.');
      }
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
        _loading = false;
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      NovynAlert.show(
        context,
        'Could not load privacy settings: ${error.toString().replaceFirst('Bad state: ', '')}',
        isError: true,
      );
    }
  }

  bool _requireStealthModeOff() {
    if (!widget.settings.stealthModeEnabled) return false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.visibility_off_rounded),
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
      if (result['ok'] != true) throw StateError(
        result['message']?.toString() ?? 'Could not save this privacy setting.');
      if (key == 'presencePrivacy') {
        // Server uses this setting for both online and last-seen visibility.
        await widget.settings.setLastSeenVisibility(value == 'friends' ? 'contacts' : value, recordPresenceOverride: false);
      } else if (key == 'profilePhotoPrivacy') {
        await widget.settings.setProfilePhotoVisibility(value == 'friends' ? 'contacts' : value, recordPresenceOverride: false);
      }
      await widget.settings.saveSmartPresenceOverride(widget.settings.activeSmartPresenceMode, key, value);
      if (mounted) NovynAlert.show(context, 'Privacy setting updated.');
    } catch (error) {
      if (mounted) {
        setState(() => _values[key] = previous);
        NovynAlert.show(context,
          error.toString().replaceFirst('Bad state: ', ''),
          isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    if (_requireStealthModeOff()) return;
    if (_saving) return;
    final previous = key == 'readReceiptsEnabled'
        ? widget.settings.readReceipts
        : _typing;
    setState(() => _saving = true);
    try {
      final result = await widget.socket.updateAccountSettings({key: value});
      if (result['ok'] != true) throw StateError(
        result['message']?.toString() ?? 'Could not save this privacy setting.');
      if (key == 'readReceiptsEnabled') {
        await widget.settings.setReadReceipts(value, recordPresenceOverride: false);
      } else {
        setState(() => _typing = value);
      }
      await widget.settings.saveSmartPresenceOverride(widget.settings.activeSmartPresenceMode, key, value);
      if (mounted) NovynAlert.show(context, 'Privacy setting updated.');
    } catch (error) {
      if (mounted) {
        if (key == 'typingIndicatorsEnabled') {
          setState(() => _typing = previous);
        }
        NovynAlert.show(context,
          error.toString().replaceFirst('Bad state: ', ''),
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
    _ => 'Everyone',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = colors.onSurfaceVariant;
    final presence = _values['presencePrivacy']!;
    final photo = _values['profilePhotoPrivacy']!;
    final visibility = [
      ('Profile photo', 'profilePhotoPrivacy', photo,
        Icons.account_circle_outlined, 'Control who can view your profile picture'),
      ('Online & last seen', 'presencePrivacy', presence,
        Icons.visibility_outlined, 'Choose who can see when you are online or last active'),
    ];
    Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant, fontSize: 11.5,
          fontWeight: FontWeight.w900, letterSpacing: 1.25)),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant, fontSize: 13, height: 1.3)),
      ]),
    );
    Widget card(List<Widget> children) => Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: dark ? .55 : .45)),
        boxShadow: dark ? const [] : [
          BoxShadow(color: const Color(0xFF6550B4).withValues(alpha: .055),
            blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
    Widget divider() => Divider(height: 1, indent: 66,
      color: colors.outlineVariant.withValues(alpha: .7));
    Widget summaryChip(String title, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? colors.primary.withValues(alpha: .15) : const Color(0xFFF2EFFB),
        borderRadius: BorderRadius.circular(22),
      ),
      child: RichText(text: TextSpan(
        style: TextStyle(fontFamily: NovynTheme.fontFamily, color: muted,
          fontSize: 12.5, fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: '$title  '),
          TextSpan(text: value, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900)),
        ],
      )),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: dark ? .55 : .45)),
          boxShadow: dark ? const [] : [
            BoxShadow(color: const Color(0xFF6550B4).withValues(alpha: .055),
              blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF8157FF), Color(0xFF6847F5)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .20),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your privacy at a glance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17.5, fontWeight: FontWeight.w900, letterSpacing: -.35)),
              const SizedBox(height: 4),
              Text('Review what others can see and how they can reach you.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted, fontSize: 13.5, height: 1.35)),
            ])),
          ]),
          const SizedBox(height: 15),
          Wrap(spacing: 8, runSpacing: 8, children: [
            summaryChip('Profile', _label(_values['profilePhotoPrivacy'] ?? 'everyone')),
            summaryChip('Reach', _label(_values['messagePrivacy'] ?? 'friends')),
            summaryChip('Read receipts', widget.readReceipts ? 'On' : 'Off'),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 10),
        child: Text('CHAT PROTECTION', style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.25)),
      ),
      card([
        _PrivacyControlToggleTile(
          icon: Icons.visibility_off_outlined, accent: const Color(0xFFC86A16),
          title: 'Stealth Mode',
          subtitle: 'Prevent screenshots of your conversations on supported Novyn Android devices',
          value: widget.settings.stealthModeEnabled, enabled: !_saving,
          onChanged: widget.onStealthModeChanged,
        ),
      ]),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 10),
        child: Text('NOTIFICATION PRIVACY', style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.25)),
      ),
      card([
        _PrivacyControlToggleTile(
          icon: Icons.do_not_disturb_on_outlined, accent: const Color(0xFF7654FF),
          title: 'Do Not Disturb',
          subtitle: 'Only messages and call alerts from your favourite contacts will notify you',
          value: widget.settings.doNotDisturbEnabled, enabled: !_saving,
          onChanged: widget.onDndChanged,
        ),
        if (widget.settings.doNotDisturbEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
            child: Text('Manage your favourites from the Chats screen. DND does not change your online presence or block incoming calls.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.4)),
          ),
      ]),
      const SizedBox(height: 22),
      heading('Profile visibility', 'Decide what people can see about you.'),
      card([
        for (var i = 0; i < visibility.length; i++) ...[
          _PrivacyOptionTile(
            icon: visibility[i].$4,
            accent: visibility[i].$2 == 'profilePhotoPrivacy'
              ? const Color(0xFFD65A91) : const Color(0xFF2795A8),
            title: visibility[i].$1,
            subtitle: visibility[i].$5,
            value: _label(visibility[i].$3),
            enabled: !_saving,
            onTap: () => _choose(visibility[i].$2, visibility[i].$3,
              visibility[i].$2 == 'presencePrivacy'
                ? const ['everyone', 'friends', 'nobody']
                : const ['everyone', 'friends', 'nobody']),
          ),
          if (i == 0) divider(),
        ],
      ]),
      const SizedBox(height: 18),
      heading('Who can reach you', 'Choose who can contact or invite you.'),
      card([
        _PrivacyOptionTile(icon: Icons.call_outlined, accent: const Color(0xFF269B76), title: 'Who can call me',
          subtitle: 'Control incoming calls', value: _label(_values['callPrivacy']!),
          enabled: !_saving, onTap: () => _choose('callPrivacy', _values['callPrivacy']!,
            const ['everyone', 'friends', 'nobody'])),
        divider(),
        _PrivacyOptionTile(icon: Icons.chat_bubble_outline_rounded, accent: const Color(0xFF3988C8),
          title: 'Who can message me', subtitle: 'Control who can start a conversation',
          value: _label(_values['messagePrivacy']!), enabled: !_saving,
          onTap: () => _choose('messagePrivacy', _values['messagePrivacy']!,
            const ['everyone', 'friends', 'nobody'])),
        divider(),
        _PrivacyOptionTile(icon: Icons.groups_outlined, accent: const Color(0xFFD39A35),
          title: 'Who can add me to groups', subtitle: 'Manage group invitations',
          value: _label(_values['groupInvitePrivacy']!), enabled: !_saving,
          onTap: () => _choose('groupInvitePrivacy', _values['groupInvitePrivacy']!,
            const ['everyone', 'friends', 'nobody'])),
        divider(),
        _PrivacyOptionTile(icon: Icons.person_add_alt_1_rounded, accent: const Color(0xFF8B70D8),
          title: 'Friend requests', subtitle: 'Choose who can send you requests',
          value: _label(_values['friendRequestPrivacy']!), enabled: !_saving,
          onTap: () => _choose('friendRequestPrivacy', _values['friendRequestPrivacy']!,
            const ['everyone', 'mutuals', 'nobody'])),
      ]),
      const SizedBox(height: 18),
      heading('Activity & read status', 'Choose what activity information is shared.'),
      card([
        _PrivacyToggleTile(icon: Icons.done_all_rounded, accent: const Color(0xFF7654FF), title: 'Read receipts',
          subtitle: 'Let others know when you have read their messages',
          value: widget.readReceipts, enabled: !_saving,
          onChanged: (v) => _saveToggle('readReceiptsEnabled', v)),
        divider(),
        _PrivacyToggleTile(icon: Icons.keyboard_alt_outlined, accent: const Color(0xFF7654FF), title: 'Typing status',
          subtitle: 'Let others know when you are typing',
          value: _typing, enabled: !_saving,
          onChanged: (v) => _saveToggle('typingIndicatorsEnabled', v)),
      ]),
      const SizedBox(height: 18),
      card([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          leading: Container(width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFE34C56).withValues(alpha: .13), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.block_rounded, color: Color(0xFFE34C56))),
          title: const Text('Blocked contacts',
            style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('View and manage people you have blocked'),
          trailing: Icon(Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant),
          onTap: () {
            if (_requireStealthModeOff()) return;
            widget.onBlocked();
          },
        ),
      ]),
      const SizedBox(height: 18),
      card([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          leading: Container(width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFF0B938C).withValues(alpha: .13), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.history_rounded, color: Color(0xFF0B938C))),
          title: const Text('Message retention',
            style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Messages are kept until explicitly deleted'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Forever', style: TextStyle(color: colors.primary,
              fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ),
      ]),
      if (_loading) const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      const SizedBox(height: 22),
    ]);
  }

  Future<void> _choose(String key, String current, List<String> options) async {
    if (_requireStealthModeOff()) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outlineVariant)),
          child: SafeArea(top: false, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4,
                decoration: BoxDecoration(color: colors.onSurfaceVariant.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 18),
              Text('Who can see or contact you?',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              for (final option in options)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: option == current
                    ? colors.primary.withValues(alpha: .09)
                    : colors.surfaceContainerHighest.withValues(alpha: .35),
                  leading: Icon(option == current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                    color: option == current ? colors.primary : colors.onSurfaceVariant),
                  title: Text(_label(option),
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: option == current ? colors.primary : colors.onSurface)),
                  trailing: option == current
                    ? Icon(Icons.check_rounded, color: colors.primary) : null,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          )),
        );
      },
    );
    if (selected != null && selected != current) await _save(key, selected);
  }
}

class _PrivacyPageHeader extends StatelessWidget {
  const _PrivacyPageHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 18),
      child: Row(children: [
        SizedBox(width: 42, height: 48, child: IconButton(
          onPressed: () => Navigator.maybePop(context),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.arrow_back_rounded, size: 27, color: colors.onSurface),
        )),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.85, height: 1.12)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant, fontSize: 14.5, height: 1.25)),
        ])),
      ]),
    );
  }
}

class _PrivacyControlToggleTile extends StatelessWidget {
  const _PrivacyControlToggleTile({
    required this.icon, required this.accent, required this.title,
    required this.subtitle, required this.value, required this.enabled,
    required this.onChanged,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Opacity(opacity: enabled ? 1 : .58, child: InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: accent.withValues(alpha: dark ? .18 : .13),
              borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: accent, size: 23)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant, fontSize: 13.3, height: 1.32)),
          ])),
          const SizedBox(width: 8),
          Switch.adaptive(value: value, onChanged: enabled ? onChanged : null,
            activeTrackColor: colors.primary, activeColor: Colors.white,
            inactiveTrackColor: dark ? const Color(0xFF454456) : const Color(0xFFA49DBB)),
        ]),
      ),
    ));
  }
}

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({
    required this.icon, this.accent, required this.title, required this.subtitle,
    required this.value, required this.enabled, required this.onTap,
  });
  final IconData icon;
  final Color? accent;
  final String title;
  final String subtitle;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = accent ?? colors.primary;
    return Opacity(opacity: enabled ? 1 : .55, child: InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: tint.withValues(alpha: dark ? .18 : .13),
              borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: tint, size: 23)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15.3, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant, fontSize: 13.2, height: 1.32)),
          ])),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dark ? colors.primary.withValues(alpha: .15) : const Color(0xFFF3F0FB),
              borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded, color: colors.primary, size: 18),
            ]),
          ),
        ]),
      ),
    ));
  }
}

class _PrivacyToggleTile extends StatelessWidget {
  const _PrivacyToggleTile({
    required this.icon, required this.accent, required this.title, required this.subtitle,
    required this.value, required this.enabled, required this.onChanged,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: accent.withValues(alpha: dark ? .18 : .13),
            borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: accent, size: 23)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 15.3, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant, fontSize: 13.2, height: 1.32)),
        ])),
        Switch.adaptive(value: value, onChanged: enabled ? onChanged : null,
          activeTrackColor: colors.primary, activeColor: Colors.white),
      ]),
    );
  }
}
