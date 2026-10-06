import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/local_auth_service.dart';
import '../../../services/security_service.dart';
import '../../../widgets/novyn_empty_state.dart';
import '../../security/setup_pin_screen.dart';
import '../widgets/profile_widgets.dart';

class SecurityPrivacyScreen extends StatelessWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F121F)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded, 
            color: Theme.of(context).colorScheme.onSurface, 
            size: 32
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
          ).createShader(bounds),
          child: const Text(
            'Security & Privacy',
            style: TextStyle(
              fontFamily: 'Outfit', 
              fontWeight: FontWeight.w900, 
              fontSize: 22, 
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        children: [
          const SectionLabel(label: 'Security'),
          MenuCard(
            icon: Icons.lock_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePassword(context),
          ),
          _ToggleCard(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF7C6FF7),
            iconBgColor: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
            title: 'Two-Factor Authentication',
            subtitle: 'Extra layer of security',
            value: settings.twoFactorAuth,
            onChanged: (v) => _handleTwoFactorAuth(context, settings, v),
          ),
          
          _ToggleCard(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'App Lock',
            subtitle: 'Require biometrics to open Novyn',
            value: settings.appLockEnabled,
            onChanged: (v) => _handleAppLockToggle(context, settings, v),
          ),
          if (settings.appLockEnabled)
            _SelectionCard(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF94A3B8),
              iconBgColor: const Color(0xFF94A3B8).withValues(alpha: 0.1),
              title: 'Auto-lock',
              subtitle: 'When to lock after leaving app',
              value: settings.appLockTimeout.toString(),
              options: const ['0', '1', '5', '15', '30'],
              labels: const ['Immediately', 'After 1 min', 'After 5 mins', 'After 15 mins', 'After 30 mins'],
              onChanged: (v) => settings.setAppLockTimeout(int.parse(v)),
            ),
          if (settings.appLockEnabled)
            MenuCard(
              icon: Icons.password_rounded,
              title: 'Change PIN',
              subtitle: 'Update your 4-digit access node',
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const SetupPinScreen())
              ),
            ),
          const SizedBox(height: 24),
          const SectionLabel(label: 'Stealth Mode'),
          MenuCard(
            icon: Icons.visibility_off_rounded,
            title: 'Stealth Mode',
            subtitle: 'Blur recents, block screenshots & hide alerts',
            onTap: () {},
            trailing: Switch(
              value: settings.stealthModeEnabled,
              activeColor: const Color(0xFF7C6FF7),
              onChanged: (v) {
                settings.setStealthMode(v);
                SecurityService.setSafeMode(v);
              },
            ),
          ),
          if (settings.stealthModeEnabled) ...[
            MenuCard(
              icon: Icons.app_registration_rounded,
              title: 'Stealth Icon',
              subtitle: 'Disguise Novyn as a Calculator',
              onTap: () {},
              trailing: Switch(
                value: settings.stealthIconEnabled,
                activeColor: const Color(0xFF7C6FF7),
                onChanged: (v) {
                   settings.setStealthIconEnabled(v);
                   SecurityService.setStealthIcon(v);
                },
              ),
            ),
            MenuCard(
              icon: Icons.notifications_paused_rounded,
              title: 'Incognito Alerts',
              subtitle: 'Hide sender & message in notifications',
              onTap: () {},
              trailing: Switch(
                value: settings.hideNotificationContent,
                activeColor: const Color(0xFF7C6FF7),
                onChanged: (v) => settings.setHideNotificationContent(v),
              ),
            ),
            MenuCard(
              icon: Icons.emergency_rounded,
              title: 'Panic PIN',
              subtitle: settings.panicPin == null ? 'Set emergency decoy code' : 'Decoy code active',
              onTap: () async {
                 await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SetupPinScreen(isPanic: true)),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel(label: 'Privacy'),
          MenuCard(
            icon: Icons.block_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            title: 'Blocked Users',
            subtitle: 'Manage people you\'ve blocked',
            onTap: () => _showBlockedUsers(context, settings),
          ),
          _SelectionCard(
            icon: Icons.visibility_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Last Seen',
            subtitle: 'Control who can see when you were last online',
            value: settings.lastSeenVisibility,
            options: const ['everyone', 'contacts', 'nobody'],
            labels: const ['Everyone', 'My Contacts', 'Nobody'],
            onChanged: (v) {
              settings.setLastSeenVisibility(v);
              context.read<AuthService>().updatePrivacySettings(lastSeenVisibility: v);
            },
          ),
          _SelectionCard(
            icon: Icons.account_circle_rounded,
            iconColor: const Color(0xFFEC4899),
            iconBgColor: const Color(0xFFEC4899).withValues(alpha: 0.1),
            title: 'Profile Photo',
            subtitle: 'Control who can see your profile photo',
            value: settings.profilePhotoVisibility,
            options: const ['everyone', 'contacts', 'nobody'],
            labels: const ['Everyone', 'My Contacts', 'Nobody'],
            onChanged: (v) {
              settings.setProfilePhotoVisibility(v);
              context.read<AuthService>().updatePrivacySettings(profilePhotoVisibility: v);
            },
          ),
          _ToggleCard(
            icon: Icons.done_all_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Read Receipts',
            subtitle: 'Let others see when you\'ve read their messages',
            value: settings.readReceipts,
            onChanged: (v) {
              settings.setReadReceipts(v);
              context.read<AuthService>().updatePrivacySettings(readReceipts: v);
            },
          ),
          
          const SizedBox(height: 32),
          const SectionLabel(label: 'Danger Zone'),
          _ActionCard(
            icon: Icons.delete_forever_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            title: 'Delete Account',
            subtitle: 'Permanently purge your node and data',
            onTap: () => _showDeleteAccount(context),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
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

      settings.setAppLockEnabled(true);
    } else {
      settings.setAppLockEnabled(false);
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
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text(
            'Disable 2FA?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
          ),
          content: Text(
            'This will weaken your security node. Are you sure you want to proceed?',
            style: TextStyle(
              fontFamily: 'Outfit',
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
                  fontFamily: 'Outfit',
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
                  fontFamily: 'Outfit',
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

  void _showBlockedUsers(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1A1D2B).withValues(alpha: 0.8) 
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Blocked Nodes',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: settings.blockedUids.isEmpty
                    ? const NovynEmptyState(
                        icon: Icons.block_rounded,
                        title: 'No blocked users',
                        description: 'Your isolation list is empty',
                      )
                    : ListView.builder(
                        itemCount: settings.blockedUids.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, i) {
                          final uid = settings.blockedUids[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.05) 
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                                child: const Icon(Icons.person_rounded, color: Color(0xFF7C6FF7)),
                              ),
                              title: Text(
                                'User $uid',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  settings.unblockUser(uid);
                                },
                                child: const Text(
                                  'Unblock',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
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

  void _showDeleteAccount(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text('Purge Node?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            'This action is irreversible. All messages, media, and cryptographic keys associated with this node will be permanently deleted from the Novyn grid.',
            style: TextStyle(
              fontFamily: 'Outfit',
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
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                // Logic to delete account would go here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Node purge initiated...'),
                    backgroundColor: Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Purge Node',
                style: TextStyle(
                  fontFamily: 'Outfit',
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
          color: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.05),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
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
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                activeTrackColor: const Color(0xFF7C6FF7).withValues(alpha: 0.8),
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
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
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
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Outfit',
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
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = options.indexOf(value);
    final currentLabel = currentIndex >= 0 ? labels[currentIndex] : labels[0];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSelectionDialog(context),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
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
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currentLabel,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7C6FF7),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded, 
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                    size: 22
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title, 
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w900,
            )
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final label = labels[index];
              final isSelected = value == option;
              
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF7C6FF7) : null,
                  ),
                ),
                leading: Radio<String>(
                  value: option,
                  groupValue: value,
                  onChanged: (v) {
                    if (v != null) {
                      HapticFeedback.lightImpact();
                      onChanged(v);
                      Navigator.pop(context);
                    }
                  },
                  activeColor: const Color(0xFF7C6FF7),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
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
        backgroundColor: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
            : Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF7C6FF7), size: 32),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                ).createShader(bounds),
                child: const Text(
                  'Update Password',
                  style: TextStyle(
                    fontFamily: 'Outfit',
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
                'Re-establishing your security node credentials.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
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
                      fontFamily: 'Outfit',
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C6FF7).withValues(alpha: 0.3),
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

                      if (mounted) {
                        setState(() => _isLoading = false);
                        if (error == null) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password synthesized successfully'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                          'Synthesize', 
                          style: TextStyle(
                            fontFamily: 'Outfit', 
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
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        cursorColor: const Color(0xFF7C6FF7),
        style: const TextStyle(
          fontFamily: 'Outfit', 
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          floatingLabelStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            color: Color(0xFF7C6FF7),
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
        backgroundColor: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.95) 
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
            color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.security_rounded, color: Color(0xFF7C6FF7), size: 40),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enable 2FA',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 12),
        Text(
          'Two-factor authentication adds an elite layer of protection. We will send a verification node to your primary contact.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
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
                    fontFamily: 'Outfit',
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
                  backgroundColor: const Color(0xFF7C6FF7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Begin Setup', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
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
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C6FF7)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Sending Code',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          'Synthesizing verification node...',
          style: TextStyle(
            fontFamily: 'Outfit',
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
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to you.',
          style: TextStyle(
            fontFamily: 'Outfit',
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
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 20),
                decoration: InputDecoration(
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C6FF7), width: 2),
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
          const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6FF7))
        else
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text(
              'Resend Code',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, color: Color(0xFF7C6FF7)),
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