import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/security_service.dart';
import '../../../widgets/novyn_empty_state.dart';
import '../../../widgets/novyn_alert.dart';
import '../../security/setup_pin_screen.dart';
import 'active_sessions_screen.dart';
import 'email_password_screen.dart';
import '../../../theme/novyn_theme.dart';
import '../widgets/profile_widgets.dart';

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
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          SettingsPageHeader(
            title: category == null ? 'Security & Privacy' : switch (category) {
              'security' => 'Account Security',
              'privacy' => 'Privacy Controls',
              'device' => 'Device & Account',
              'danger' => 'Danger Zone',
              _ => 'Security & Privacy',
            },
            subtitle: category == null
                ? 'Keep your account and chats safe'
                : switch (category) {
                    'security' => 'Manage sign-in and device protection',
                    'privacy' => 'Control your visibility and interactions',
                    'device' => 'Device privacy and account actions',
                    'danger' => 'Manage permanent account actions',
                    _ => 'Keep your account and chats safe',
                  },
          ),
          const SizedBox(height: 20),
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
              'Email & Password', 'Manage email verification and sign-in password',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailPasswordScreen()))),
            nav(Icons.devices_rounded, const Color(0xFF2A78B8),
              'Active Sessions', 'Sign out of other devices remotely',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()))),
            _SecurityPrivacyToggleTile(
              icon: Icons.verified_user_outlined, accent: const Color(0xFF7565D9),
              title: 'Two-Factor Authentication',
              subtitle: 'Unavailable until secure server-side login challenges are supported',
              value: false, onChanged: null,
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
          if (category == null || category == 'device') section('Device privacy & account actions', [
            _SecurityPrivacyToggleTile(
              icon: Icons.visibility_off_outlined, accent: const Color(0xFFC2540F),
              title: 'Stealth Mode',
              subtitle: 'Hide app previews in Recents, block screenshots and mask notification content',
              value: settings.stealthModeEnabled,
              onChanged: (v) => _setStealthMode(context, settings, v),
            ),
            if (settings.stealthModeEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F9D61).withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF1F9D61), size: 18),
                    const SizedBox(width: 9),
                    Expanded(child: Text(
                      'Protection is active on this device. Notification previews are hidden and screenshots or screen recordings are blocked while Novyn is open.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
                    )),
                  ]),
                ),
              ),
            _SecurityPrivacyTile(
              icon: Icons.delete_outline_rounded,
              accent: const Color(0xFFB3261E),
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and associated data',
              isDanger: true,
              onTap: () => _showDeleteAccount(context),
            ),
          ], color: const Color(0xFFB3261E)),
          if (category == 'privacy') ...[
            const SettingsIntroCard(
              title: 'Your privacy at a glance',
              subtitle: 'Review what others can see and how they can reach you.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 12),
          ],
          if (category == 'privacy') _PrivacyDashboard(
            lastSeen: settings.lastSeenVisibility,
            profilePhoto: settings.profilePhotoVisibility,
            readReceipts: settings.readReceipts,
            socket: socket,
            settings: settings,
            onBlocked: () => _showBlockedUsers(context, socket),
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
    final auth = context.read<AuthService>();
    final savedLastSeen = settings.configuredLastSeenVisibility;
    final savedProfilePhoto = settings.configuredProfilePhotoVisibility;

    try {
      // Persist the preference and apply the Android FLAG_SECURE protection.
      await settings.setStealthMode(enabled);
      await SecurityService.setSafeMode(enabled);

      // Keep the server-side privacy profile in sync with the local override.
      await auth.updatePrivacySettings(
        lastSeenVisibility: enabled ? 'nobody' : savedLastSeen,
        profilePhotoVisibility: enabled ? 'nobody' : savedProfilePhoto,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'Stealth Mode enabled. Screen capture and previews are blocked.'
              : 'Stealth Mode disabled. Your previous privacy settings are restored.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fully apply Stealth Mode: $error'),
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
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                settings.setTwoFactorAuth(false);
                ScaffoldMessenger.of(context).showSnackBar(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Blocked Users',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: socket,
                  builder: (context, _) {
                    final blockedUsers = socket.blockedUsers;
                    if (blockedUsers.isEmpty) {
                      return const NovynEmptyState(
                        icon: Icons.block_rounded,
                        title: 'No blocked users',
                        description: 'Your server-synced block list is empty',
                      );
                    }
                    return ListView.builder(
                      itemCount: blockedUsers.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final username = blockedUsers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(
                              '@$username',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                try {
                                  final result = await socket.setBlockedUser(
                                    username,
                                    blocked: false,
                                  );
                                  if (result['ok'] != true && sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                                      SnackBar(
                                        content: Text(result['message']?.toString() ?? 'Could not unblock user.'),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                                      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Unblock',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccount(BuildContext context) async {
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    final username = auth.user?.username ?? '';
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
                  HapticFeedback.lightImpact();
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
            HapticFeedback.selectionClick();
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
                  : 'After \$option \${option == '1' ? 'minute' : 'minutes'}';
                return Material(
                  color: selected ? colors.primary.withValues(alpha: .10)
                    : colors.surfaceContainerHighest.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.selectionClick();
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields'), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      if (_newPasswordController.text != _confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);
                      HapticFeedback.mediumImpact();

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
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Password updated. Please sign in again.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
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
      HapticFeedback.mediumImpact();
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
                    HapticFeedback.selectionClick();
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
    HapticFeedback.mediumImpact();
    
    // Simulate verification delay
    await Future.delayed(const Duration(seconds: 1));
    
    widget.settings.setTwoFactorAuth(true);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
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
  });

  final String lastSeen;
  final String profilePhoto;
  final bool readReceipts;
  final SocketService socket;
  final SettingsService settings;
  final VoidCallback onBlocked;

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
    _loading = false;
  }


  Future<void> _save(String key, String value) async {
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
        await widget.settings.setLastSeenVisibility(value == 'friends' ? 'contacts' : value);
      } else if (key == 'profilePhotoPrivacy') {
        await widget.settings.setProfilePhotoVisibility(value == 'friends' ? 'contacts' : value);
      }
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await widget.socket.updateAccountSettings({key: value});
      if (result['ok'] != true) throw StateError(
        result['message']?.toString() ?? 'Could not save this privacy setting.');
      if (key == 'readReceiptsEnabled') {
        await widget.settings.setReadReceipts(value);
      } else {
        setState(() => _typing = value);
      }
      if (mounted) NovynAlert.show(context, 'Privacy setting updated.');
    } catch (error) {
      if (mounted) NovynAlert.show(context,
        error.toString().replaceFirst('Bad state: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(String value) => switch (value) {
    'everyone' => 'Everyone',
    'friends' => 'Friends',
    'mutuals' => 'Mutuals',
    'nobody' => 'No one',
    _ => 'Everyone',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final presence = _values['presencePrivacy'] == 'everyone' && widget.lastSeen != 'everyone'
        ? (widget.lastSeen == 'contacts' ? 'friends' : widget.lastSeen)
        : _values['presencePrivacy']!;
    final photo = widget.profilePhoto == 'contacts' ? 'friends' : widget.profilePhoto;
    final visibility = [
      ('Profile photo', 'profilePhotoPrivacy', photo,
        Icons.account_circle_outlined, 'Control who can view your profile picture'),
      ('Online & last seen', 'presencePrivacy', presence,
        Icons.visibility_outlined, 'Choose who can see when you are online or last active'),
    ];
    Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.05)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant)),
      ]),
    );
    Widget card(List<Widget> children) => Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
    Widget divider() => Divider(height: 1, indent: 66,
      color: colors.outlineVariant.withValues(alpha: .7));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        _PrivacyToggleTile(icon: Icons.done_all_rounded, title: 'Read receipts',
          subtitle: 'Let others know when you have read their messages',
          value: widget.readReceipts, enabled: !_saving,
          onChanged: (v) => _saveToggle('readReceiptsEnabled', v)),
        divider(),
        _PrivacyToggleTile(icon: Icons.keyboard_alt_outlined, title: 'Typing status',
          subtitle: 'Let others know when you are typing',
          value: _typing, enabled: !_saving,
          onChanged: (v) => _saveToggle('typingIndicatorsEnabled', v)),
      ]),
      const SizedBox(height: 18),
      card([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          leading: CircleAvatar(backgroundColor: colors.errorContainer,
            child: Icon(Icons.block_rounded, color: colors.error)),
          title: const Text('Blocked contacts',
            style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('View and manage people you have blocked'),
          trailing: Icon(Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant),
          onTap: widget.onBlocked,
        ),
      ]),
      const SizedBox(height: 18),
      card([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          leading: CircleAvatar(backgroundColor: colors.secondaryContainer,
            child: Icon(Icons.history_rounded, color: colors.onSecondaryContainer)),
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

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({required this.icon, this.accent, required this.title,
    required this.subtitle, required this.value, required this.enabled,
    required this.onTap});
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
    final tint = accent ?? colors.primary;
    return Opacity(opacity: enabled ? 1 : .55,
      child: InkWell(onTap: enabled ? onTap : null,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(children: [
            CircleAvatar(radius: 21,
              backgroundColor: tint.withValues(alpha: .12),
              child: Icon(icon, color: tint, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant)),
              ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: TextStyle(color: colors.primary,
                fontSize: 11, fontWeight: FontWeight.w800)),
              Icon(Icons.keyboard_arrow_down_rounded,
                color: colors.onSurfaceVariant, size: 19),
            ]),
          ]),
        )),
    );
  }
}

class _PrivacyToggleTile extends StatelessWidget {
  const _PrivacyToggleTile({required this.icon, required this.title,
    required this.subtitle, required this.value, required this.enabled,
    required this.onChanged});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      child: Row(children: [
        CircleAvatar(radius: 21,
          backgroundColor: colors.primary.withValues(alpha: .10),
          child: Icon(icon, color: colors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant)),
          ])),
        Switch.adaptive(value: value, onChanged: enabled ? onChanged : null),
      ]),
    );
  }
}
