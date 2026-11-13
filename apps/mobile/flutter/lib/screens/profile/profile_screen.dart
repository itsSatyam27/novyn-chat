import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/profile_avatar_with_orbit.dart';
import '../../widgets/presence_dock.dart';
import '../../widgets/novyn_ui.dart';
import '../../theme/novyn_theme.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../../services/settings_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../services/auth_service.dart';
import '../auth/onboarding_screen.dart';
import '../security/setup_pin_screen.dart';
import 'widgets/profile_widgets.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/security_privacy_screen.dart';
import 'settings/data_storage_screen.dart';
import 'settings/language_region_screen.dart';
import 'settings/accessibility_screen.dart';
import 'settings/sound_vibration_screen.dart';
import 'settings/appearance_screen.dart';
import 'settings/chat_settings_screen.dart';
import 'settings/support_screens.dart';
import 'package:novyn/services/haptic_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context)!;
    final profile = auth.user;
    final displayName = profile?.displayName.isNotEmpty == true ? profile!.displayName : 'You';
    final username = profile?.username ?? 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _NovynSettingsBackdrop()),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
              children: [
                NovynHeader(
                  title: 'Settings',
                  titleSize: 30,
                  subtitle: 'Make Novyn feel like yours',
                  actions: [
                    NovynIconButton(
                      icon: Icons.search_rounded,
                      onTap: () => _showSettingsSearch(context, settings),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _NovynSettingsProfileCard(
                  displayName: displayName,
                  username: username,
                  photoUrl: profile?.photoUrl,
                  bio: profile?.bio ?? '',
                  status: profile?.presenceMode ?? 'online',
                  busy: auth.updatingPresence,
                  onStatusSelected: (mode) => _updateStatus(context, auth, mode),
                  onQr: () => _showQRCode(context),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsQuickToggle(
                        title: 'App Lock',
                        activeIcon: Icons.lock_rounded,
                        inactiveIcon: Icons.lock_open_rounded,
                        value: settings.appLockEnabled,
                        accent: const Color(0xFF64748B),
                        onChanged: (value) => _toggleAppLock(context, settings, value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsQuickToggle(
                        title: 'Busy Mode',
                        activeIcon: Icons.notifications_off_rounded,
                        inactiveIcon: Icons.notifications_active_rounded,
                        value: auth.user?.presenceMode == 'busy',
                        accent: const Color(0xFF159C91),
                        onChanged: (value) => _toggleBusyMode(context, auth, settings, value),
                      ),
                    ),
                  ],
                ),
                NovynSectionLabel('ACCOUNT', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
                _NovynSettingsGroup(children: [
                  _NovynSettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Security & Privacy',
                    subtitle: 'Privacy and account protection',
                    accent: const Color(0xFF047857),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat Settings',
                    subtitle: 'Chat behavior and backup & restore',
                    accent: const Color(0xFF0F9B8E),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.storage_rounded,
                    title: 'Data & Storage',
                    subtitle: 'Storage usage and downloads',
                    accent: const Color(0xFF64748B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataStorageScreen())),
                    showDivider: false,
                  ),
                ]),
                NovynSectionLabel('PREFERENCES', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
                _NovynSettingsGroup(children: [
                  _NovynSettingsTile(
                    icon: Icons.palette_outlined,
                    title: l10n.appearance,
                    subtitle: 'Theme, colours and text size',
                    accent: Theme.of(context).colorScheme.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: l10n.notifications,
                    subtitle: 'Messages and call alerts',
                    accent: const Color(0xFFD97706),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.volume_up_outlined,
                    title: l10n.soundVibration,
                    subtitle: 'Ringtones and haptics',
                    accent: const Color(0xFF0284C7),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundVibrationScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.language_rounded,
                    title: l10n.languageRegion,
                    subtitle: 'App language and region',
                    accent: const Color(0xFF0F9B8E),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageRegionScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    subtitle: 'Make Novyn easier to use',
                    accent: const Color(0xFFDB2777),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilityScreen())),
                    showDivider: false,
                  ),
                ]),
                NovynSectionLabel(l10n.support.toUpperCase(), padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
                _NovynSettingsGroup(children: [
                  _NovynSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: l10n.helpSupport,
                    subtitle: 'FAQs and get help',
                    accent: const Color(0xFF7C6CF2),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.rate_review_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Share ideas, report bugs or rate Novyn',
                    accent: const Color(0xFF7C6CF2),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                  ),
                  _NovynSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Novyn',
                    subtitle: 'App information and credits',
                    accent: const Color(0xFF64748B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutNovynScreen())),
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: 26),
                _NovynLogoutTile(title: l10n.logOut, onTap: () => _confirmLogout(context, auth)),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'NOVYN · YOUR SPACE, YOUR PEOPLE',
                    style: NovynText.body(12, weight: FontWeight.w700, color: NovynColors.timeMuted, letterSpacing: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    SettingsService settings,
    bool enabled,
  ) async {
    if (enabled) {
      if (settings.appLockPin == null) {
        final configured = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const SetupPinScreen()),
        );
        if (configured != true || !context.mounted) return;
      }
      try {
        await settings.setAppLockEnabled(true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App Lock enabled.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not enable App Lock: $error')),
          );
        }
      }
    } else {
      await settings.setAppLockEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock disabled.')),
        );
      }
    }
  }

  Future<void> _toggleBusyMode(
    BuildContext context,
    AuthService auth,
    SettingsService settings,
    bool enabled,
  ) async {
    final currentMode = auth.user?.presenceMode ?? 'online';
    try {
      if (enabled) {
        if (currentMode != 'busy') {
          await settings.setBusyPreviousPresenceMode(currentMode);
          await auth.updateStatus('busy');
        }
      } else if (currentMode == 'busy') {
        final restoreMode = settings.busyPreviousPresenceMode ?? 'online';
        await auth.updateStatus(restoreMode);
        await settings.setBusyPreviousPresenceMode(null);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Busy Mode could not be updated: ${error.toString()}'),
      ));
    }
  }

  Future<void> _updateStatus(BuildContext context, AuthService auth, String mode) async {
    try {
      await auth.updateStatus(mode);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status could not be saved: ${error.toString()}'),
      ));
    }
  }

  void _showSettingsSearch(BuildContext context, SettingsService settings) {
    final controller = TextEditingController();
    final items = <Map<String, dynamic>>[
      {'title': 'Appearance', 'subtitle': 'Theme, colours and text size', 'icon': Icons.palette_outlined, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen()))},
      {'title': 'Sound & Vibration', 'subtitle': 'Ringtones and haptics', 'icon': Icons.volume_up_outlined, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundVibrationScreen()))},
      {'title': 'Notifications', 'subtitle': 'Messages and call alerts', 'icon': Icons.notifications_none_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))},
      {'title': 'Language & Region', 'subtitle': 'App language and region', 'icon': Icons.language_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageRegionScreen()))},
      {'title': 'Chat Settings', 'subtitle': 'Chat behavior and backup & restore', 'icon': Icons.chat_bubble_outline_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsScreen()))},
      {'title': 'Data & Storage', 'subtitle': 'Storage usage and downloads', 'icon': Icons.storage_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataStorageScreen()))},
      {'title': 'Accessibility', 'subtitle': 'Make Novyn easier to use', 'icon': Icons.accessibility_new_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilityScreen()))},
      {'title': 'Security & Privacy', 'subtitle': 'Privacy and account protection', 'icon': Icons.shield_outlined, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen()))},
      {'title': 'QR Code', 'subtitle': 'Share your Novyn profile', 'icon': Icons.qr_code_2_rounded, 'open': () => _showQRCode(context)},
      {'title': 'Help & Support', 'subtitle': 'FAQs and get help', 'icon': Icons.help_outline_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))},
      {'title': 'Send Feedback', 'subtitle': 'Share ideas, report bugs or rate Novyn', 'icon': Icons.rate_review_outlined, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()))},
      {'title': 'About Novyn', 'subtitle': 'App information and credits', 'icon': Icons.info_outline_rounded, 'open': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutNovynScreen()))},
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = controller.text.trim().toLowerCase();
          final filtered = items.where((item) =>
            (item['title'] as String).toLowerCase().contains(query) ||
            (item['subtitle'] as String).toLowerCase().contains(query)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              decoration: BoxDecoration(
                color: NovynTheme.cardBg(sheetContext),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Theme.of(sheetContext).colorScheme.outlineVariant),
              ),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(sheetContext).colorScheme.onSurface.withValues(alpha: .2), borderRadius: BorderRadius.circular(4))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search settings...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                    ? Center(child: Text('No settings found', style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(sheetContext).dividerColor),
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
                              child: Icon(item['icon'] as IconData, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item['subtitle'] as String),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              (item['open'] as VoidCallback)();
                            },
                          );
                        },
                      ),
                ),
              ]),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  void _showAboutNovyn(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.hub_rounded, color: Theme.of(context).colorScheme.primary, size: 38),
        title: const Text('Novyn'),
        content: const Text('Your space, your people.\\n\\nA place to stay connected with the people who matter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are some ways to get support:'),
            SizedBox(height: 16),
            Text('• Check our FAQ section'),
            Text('• Contact support team'),
            Text('• Join our community forum'),
            Text('• Report bugs or issues'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Contact Support');
            },
            child: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'By using Novyn, you agree to our terms of service. '
            'These terms govern your use of our messaging platform and services. '
            'Please read them carefully.\n\n'
            'Key points:\n'
            '• Respect other users\n'
            '• Don\'t share inappropriate content\n'
            '• Protect your account security\n'
            '• Report violations\n\n'
            'For the complete terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This policy explains how we collect, '
            'use, and protect your personal information.\n\n'
            'What we collect:\n'
            '• Account information\n'
            '• Messages and media\n'
            '• Usage analytics\n'
            '• Device information\n\n'
            'How we protect your data:\n'
            '• End-to-end encryption\n'
            '• Secure servers\n'
            '• Limited data retention\n'
            '• No selling to third parties\n\n'
            'For detailed information, visit our website.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Keep the user informed while the server session and local
              // authentication providers are being cleared.
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PopScope(
                  canPop: false,
                  child: Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 26,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Logging out…',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Securing your account and signing you out',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                await auth.logout();
              } finally {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              }

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    final auth = context.read<AuthService>();
    final username = auth.user?.username ?? 'user';
    final profileUrl = 'https://novyn.app/user/$username';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? const Color(0xFFF7F8FC) : const Color(0xFF172033);
    final muted = isDark ? const Color(0xFFA8B1C4) : const Color(0xFF647087);
    final panel = isDark ? const Color(0xFF191F30) : const Color(0xFFF4F6FB);
    final accent = Theme.of(context).colorScheme.primary;

    Future<void> showFeedback(String message) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.of(dialogContext).size.height * 0.88),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFDCE3EF)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12), blurRadius: 34, offset: const Offset(0, 18)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.qr_code_2_rounded, color: accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('My QR code', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 20, fontWeight: FontWeight.w900, color: foreground)),
                        const SizedBox(height: 2),
                        Text('Let people find you on Novyn', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE3E8F1)),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: QrImageView(
                        data: profileUrl,
                        version: QrVersions.auto,
                        size: 214,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF172033)),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF172033)),
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('@$username', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 19, fontWeight: FontWeight.w900, color: foreground)),
                    const SizedBox(height: 5),
                    Text('Scan this code to open your profile', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _QRActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy link',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: profileUrl));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      await showFeedback('Profile link copied');
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _QRActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    primary: true,
                    onTap: () async {
                      await Share.share(profileUrl, subject: 'Connect with me on Novyn');
                    },
                  )),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final painter = QrPainter(
                          data: profileUrl,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          gapless: true,
                          color: const Color(0xFF172033),
                          emptyColor: Colors.white,
                        );
                        final bytes = await painter.toImageData(1024, format: ImageByteFormat.png);
                        if (bytes == null) throw Exception('Could not render QR image');
                        final hasGalleryAccess = await Gal.hasAccess();
                        if (!hasGalleryAccess) {
                          final granted = await Gal.requestAccess();
                          if (!granted) throw Exception('Gallery permission denied');
                        }
                        await Gal.putImageBytes(bytes.buffer.asUint8List(), album: 'Novyn');
                        await showFeedback('QR code saved to gallery');
                      } catch (error) {
                        await showFeedback('Could not save QR code. Please allow gallery access.');
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save QR image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: foreground,
                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD5DDEA)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Your QR code contains only your public profile link.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Backup Options', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose what to backup:'),
            SizedBox(height: 16),
            Text('✓ Messages and chats'),
            Text('✓ Media files'),
            Text('✓ Settings and preferences'),
            Text('✓ Contact list'),
            SizedBox(height: 16),
            Text(
              'Backups are encrypted and stored securely.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Backup');
            },
            child: const Text('Start Backup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'online':
        return const Color(0xFF10B981);
      case 'away':
        return const Color(0xFFF59E0B);
      case 'busy':
        return const Color(0xFFEC4899);
      case 'invisible':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
    }
  }

  void _showAppearanceDialog(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                    ).createShader(bounds),
                    child: const Text(
                      'Appearance',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ThemeOption(
                    label: 'System Default',
                    icon: Icons.brightness_auto_rounded,
                    iconColor: const Color(0xFFE0E0E0),
                    isSelected: settings.themeMode == ThemeMode.system,
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection);
                      settings.setThemeMode(ThemeMode.system);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    label: 'Light Mode',
                    icon: Icons.light_mode_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isSelected: settings.themeMode == ThemeMode.light,
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection);
                      settings.setThemeMode(ThemeMode.light);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    label: 'Dark Mode',
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    isSelected: settings.themeMode == ThemeMode.dark,
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection);
                      settings.setThemeMode(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 28),
                  _AuroraDialogButton(
                    label: 'Close',
                    onTap: () => Navigator.pop(context),
                    isSecondary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Aurora Support Widgets ─────────────────────────────────────────────────


class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusDot({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService.vibrate(NovynHapticType.selection);
        onTap();
      },
      child: Container(
        width: 65,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
        child: Column(
          children: [
            // Glowing Dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 14 : 10,
              height: isSelected ? 14 : 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)]
                    : [],
                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
              ),
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _InnovationTopEditIcon extends StatefulWidget {
  const _InnovationTopEditIcon();
  @override
  State<_InnovationTopEditIcon> createState() => _InnovationTopEditIconState();
}

class _InnovationTopEditIconState extends State<_InnovationTopEditIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(20, 20),
          painter: _InnovationTopEditPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _InnovationTopEditPainter extends CustomPainter {
  final double progress;
  _InnovationTopEditPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = const Color(0xFFBDBDBD);
    
    // 1. Core Node
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);
    canvas.drawCircle(center, 2.5, corePaint);
    canvas.drawCircle(center, 1, Paint()..color = Colors.white);

    // 2. Orbiting Particles
    final orbitPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final angle = (progress * 2 * math.pi) + (i * (2 * math.pi / 3));
      final radius = 6.0 + (math.sin(progress * 4 * math.pi + i) * 1.5);
      final pPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawCircle(pPos, 1.2, orbitPaint);
      if (i == 0) {
        // Add a tiny trail for one particle
        canvas.drawCircle(pPos, 3, Paint()..color = color.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }

    // 3. Geometric Outer Ring (Faint)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, 8, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final Gradient gradient;

  _GradientBorderPainter({required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnovationEditIcon extends StatefulWidget {
  const _InnovationEditIcon();
  @override
  State<_InnovationEditIcon> createState() => _InnovationEditIconState();
}

class _InnovationEditIconState extends State<_InnovationEditIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(24, 24),
          painter: _InnovationEditPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _InnovationEditPainter extends CustomPainter {
  final double progress;
  _InnovationEditPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFFBDBDBD).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    // Quill Body (Sharp & Futuristic)
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.1);
    
    // Feather Detailing
    path.moveTo(size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.4, size.width * 0.6, size.height * 0.2);
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Ink Node (Glowing Tip)
    final tipPos = Offset(size.width * 0.2, size.height * 0.8);
    final pulse = 2 + (progress * 2);
    canvas.drawCircle(tipPos, pulse, Paint()..color = const Color(0xFFBDBDBD));
    canvas.drawCircle(tipPos, 1, Paint()..color = Colors.white);

    // Floating Ink Particles
    for (int i = 0; i < 3; i++) {
      final pPos = Offset(
        size.width * 0.4 + (math.sin(progress * 2 * math.pi + i) * 3),
        size.height * 0.4 + (math.cos(progress * 2 * math.pi + i) * 3),
      );
      canvas.drawCircle(pPos, 0.8, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AuroraMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  const _AuroraMenuCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          HapticService.vibrate(NovynHapticType.light);
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1D2B).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected 
                  ? iconColor.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for selection state if needed
  bool get isSelected => false; 
}

class _AuroraSectionLabel extends StatelessWidget {
  final String label;
  const _AuroraSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 24, 6, 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE0E0E0).withValues(alpha: 0.3),
                    const Color(0xFFBDBDBD).withValues(alpha: 0.1),
                    Colors.transparent,
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

// ── Theme Option Widget ────────────────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected 
              ? iconColor.withValues(alpha: 0.1) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? iconColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: -2,
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? iconColor.withValues(alpha: 0.2) : iconColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFFE0E0E0) : Colors.grey.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFFE0E0E0) : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFE0E0E0),
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}

class _QRActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _QRActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: primary
          ? accent
          : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F3F9)),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuroraDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  const _AuroraDialogButton({
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSecondary 
              ? null 
              : const LinearGradient(
                  colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isSecondary 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
              : null,
          border: isSecondary 
              ? Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: isSecondary 
                ? Theme.of(context).colorScheme.onSurface 
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AnimatedQRContainer extends StatefulWidget {
  final String data;
  final bool isDark;

  const _AnimatedQRContainer({required this.data, required this.isDark});

  @override
  State<_AnimatedQRContainer> createState() => _AnimatedQRContainerState();
}

class _AnimatedQRContainerState extends State<_AnimatedQRContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isGenerating = false;
  bool _isGenerated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startGeneration() async {
    setState(() {
      _isGenerating = true;
    });
    HapticService.vibrate(NovynHapticType.medium);
    
    _controller.repeat();
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _isGenerated = true;
      });
      _controller.stop();
      HapticService.vibrate(NovynHapticType.error, category: HapticCategory.buttons);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Initial State: Generate Button ──────────────────────
            if (!_isGenerating && !_isGenerated)
              GestureDetector(
                onTap: _startGeneration,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE0E0E0).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFFE0E0E0)),
                      const SizedBox(height: 12),
                      Text(
                        'Generate Node',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: const Color(0xFFE0E0E0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Generating State: Scanning Animation ────────────────
            if (_isGenerating)
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.2,
                    child: QrImageView(
                      data: widget.data,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: _ScanningPainter(progress: _controller.value),
                      );
                    },
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 100),
                      Text(
                        'Synthesizing...',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            // ── Resolved State: Final QR Code ───────────────────────
            if (_isGenerated)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: widget.data,
                              version: QrVersions.auto,
                              size: 180.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.circle,
                                color: Color(0xFF1A1D2E),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.hub_rounded, color: Color(0xFFE0E0E0), size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanningPainter extends CustomPainter {
  final double progress;
  _ScanningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFBDBDBD).withValues(alpha: 0),
          const Color(0xFFBDBDBD),
          const Color(0xFFBDBDBD).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, (size.height * progress) - 10, size.width, 20))
      ..style = PaintingStyle.fill;

    final y = size.height * progress;
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), paint);
    
    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFFBDBDBD).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(Rect.fromLTWH(0, y - 5, size.width, 10), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class _NovynSettingsBackdrop extends StatelessWidget {
  const _NovynSettingsBackdrop();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: NovynTheme.pageBg(context),
    child: const SizedBox.expand(),
  );
}

class _NovynSettingsProfileCard extends StatefulWidget {
  const _NovynSettingsProfileCard({
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.bio,
    required this.status,
    required this.busy,
    required this.onStatusSelected,
    this.onQr,
  });

  final String displayName, username, status, bio;
  final String? photoUrl;
  final bool busy;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback? onQr;

  @override
  State<_NovynSettingsProfileCard> createState() => _NovynSettingsProfileCardState();
}

class _NovynSettingsProfileCardState extends State<_NovynSettingsProfileCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  bool _editing = false;
  bool _saving = false;
  File? _pendingPhoto;

  bool get _hasChanges =>
      _nameController.text.trim() != widget.displayName.trim() ||
      _bioController.text.trim() != widget.bio.trim() ||
      _pendingPhoto != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
    _bioController = TextEditingController(text: widget.bio);
  }

  @override
  void didUpdateWidget(covariant _NovynSettingsProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && (oldWidget.displayName != widget.displayName || oldWidget.bio != widget.bio)) {
      _nameController.text = widget.displayName;
      _bioController.text = widget.bio;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _beginEdit() {
    _nameController.text = widget.displayName;
    _bioController.text = widget.bio;
    setState(() {
      _pendingPhoto = null;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _pendingPhoto = null;
      _editing = false;
      _nameController.text = widget.displayName;
      _bioController.text = widget.bio;
    });
  }

  Future<void> _choosePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 86,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final file = File(image.path);
      if (!await file.exists() || await file.length() == 0) {
        _showMessage('The selected photo could not be read.');
        return;
      }
      if (await file.length() > 15 * 1024 * 1024) {
        _showMessage('Please choose a photo smaller than 15 MB.');
        return;
      }
      setState(() => _pendingPhoto = file);
    } catch (_) {
      _showMessage('Could not open your gallery. Please try again.');
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    final auth = context.read<AuthService>();
    final settings = context.read<SettingsService>();
    setState(() => _saving = true);
    try {
      if (_pendingPhoto != null) {
        final photoError = await auth.uploadProfilePicture(_pendingPhoto!);
        if (photoError != null) {
          if (mounted) setState(() => _saving = false);
          _showMessage(photoError);
          return;
        }
      }
      final error = await auth.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (error != null) {
        if (mounted) setState(() => _saving = false);
        _showMessage(error);
        return;
      }
      await settings.setProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _pendingPhoto = null;
      });
      _showMessage('Profile updated successfully');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      _showMessage('Could not save your profile. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: NovynTheme.cardBg(context),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutQuart,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0, .035),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            final scale = Tween<double>(
              begin: .985,
              end: 1,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(scale: scale, child: child),
              ),
            );
          },
          child: _editing ? _buildEditor(theme) : _buildSummary(theme),
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) => Column(
    key: const ValueKey('profile-summary'),
    children: [
      Row(children: [
        SizedBox(
          width: 92,
          height: 92,
          child: ProfileAvatarWithOrbit(
            photoUrl: widget.photoUrl,
            displayName: widget.displayName,
            status: widget.status,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: NovynText.display(19, weight: FontWeight.w700).copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text('@${widget.username}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: NovynText.body(13, weight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: .72))),
            if (widget.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(widget.bio, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: NovynText.body(12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        )),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Tooltip(
            message: 'Edit profile',
            child: Material(
              color: theme.colorScheme.primary.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _beginEdit,
                borderRadius: BorderRadius.circular(14),
                splashColor: theme.colorScheme.primary.withValues(alpha: .16),
                highlightColor: theme.colorScheme.primary.withValues(alpha: .07),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: .22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: .10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: PresenceDock(status: widget.status, busy: widget.busy, onSelected: widget.onStatusSelected),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: theme.colorScheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onQr,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_2_rounded, size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 7),
                Text('My QR code', style: NovynText.body(13, weight: FontWeight.w700, color: theme.colorScheme.primary)),
              ]),
            ),
          ),
        ),
      ]),
    ],
  );

  Widget _buildEditor(ThemeData theme) => Column(
    key: const ValueKey('profile-inline-editor'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
        Stack(children: [
          ProfileAvatarWithOrbit(
            photoUrl: widget.photoUrl,
            localFile: _pendingPhoto,
            displayName: _nameController.text.trim().isEmpty ? widget.displayName : _nameController.text.trim(),
            status: widget.status,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _saving ? null : _choosePhoto,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit profile', style: NovynText.display(18, weight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('Update your photo and details', style: NovynText.body(12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          Text('@${widget.username}', style: NovynText.body(12, weight: FontWeight.w700, color: theme.colorScheme.primary)),
        ])),
      ]),
      const SizedBox(height: 18),
      _inlineField(theme, 'Full name', _nameController, maxLines: 1),
      const SizedBox(height: 10),
      _inlineField(theme, 'Bio', _bioController, maxLines: 3),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : _cancelEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: (!_hasChanges || _saving) ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: .22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ],
  );

  Widget _inlineField(ThemeData theme, String label, TextEditingController controller, {required int maxLines}) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      maxLines: maxLines,
      maxLength: label == 'Bio' ? 160 : 50,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .38),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .65))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4)),
      ),
    );
  }
}

class _SettingsQuickToggle extends StatelessWidget {
  const _SettingsQuickToggle({
    required this.title,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: value
                  ? accent.withValues(alpha: dark ? .48 : .30)
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: value ? (dark ? .24 : .14) : .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    value ? activeIcon : inactiveIcon,
                    key: ValueKey(value),
                    size: 22,
                    color: value ? accent : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Transform.scale(
                scale: .88,
                alignment: Alignment.centerRight,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  activeTrackColor: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NovynSettingsGroup extends StatelessWidget {
  const _NovynSettingsGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: NovynTheme.cardBg(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Column(children: children)),
    );
  }
}

class _NovynSettingsTile extends StatelessWidget {
  const _NovynSettingsTile({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap, this.showDivider = true});
  final IconData icon;
  final String title, subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 20)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 21),
          ]),
        ),
        if (showDivider) Padding(padding: const EdgeInsets.only(left: 69), child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor)),
      ]),
    ),
  );
}

class _NovynLogoutTile extends StatelessWidget {
  const _NovynLogoutTile({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).brightness == Brightness.dark ? const Color(0x33F87171) : const Color(0xFFFFF1F2),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x66F87171) : const Color(0xFFFFC9D0))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 19),
          const SizedBox(width: 10),
          Text(title, style: NovynText.body(14, weight: FontWeight.w700, color: const Color(0xFFEF4444))),
        ]),
      ),
    ),
  );
}
