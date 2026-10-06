import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profile_widgets.dart';
import '../../../services/settings_service.dart';

class AppearanceSheet extends StatelessWidget {
  final SettingsService settings;
  const AppearanceSheet({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return SettingsSheet(
      title: 'Appearance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            label: 'System default',
            icon: Icons.brightness_auto_rounded,
            selected: settings.themeMode == ThemeMode.system,
            onTap: () {
              HapticFeedback.selectionClick();
              settings.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          _ThemeOption(
            label: 'Light',
            icon: Icons.light_mode_rounded,
            selected: settings.themeMode == ThemeMode.light,
            onTap: () {
              HapticFeedback.selectionClick();
              settings.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          _ThemeOption(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            selected: settings.themeMode == ThemeMode.dark,
            onTap: () {
              HapticFeedback.selectionClick();
              settings.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SecuritySheet extends StatelessWidget {
  const SecuritySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSheet(
      title: 'Security & Privacy',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTile(
            icon: Icons.password_rounded,
            label: 'Change Password',
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            onTap: () {},
          ),
          _SheetTile(
            icon: Icons.block_rounded,
            label: 'Blocked Users',
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFFF1F2),
            onTap: () {},
          ),
          _SheetTile(
            icon: Icons.fingerprint_rounded,
            label: 'Two-Factor Authentication',
            iconColor: const Color(0xFF7C6FF7),
            iconBg: const Color(0xFFECEAFD),
            onTap: () {},
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class LinkedDevicesSheet extends StatelessWidget {
  const LinkedDevicesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSheet(
      title: 'Linked Devices',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DeviceTile(
            name: 'This device',
            detail: 'Android · Active now',
            isCurrent: true,
            onRemove: null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Log out all other devices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsSheet(
      title: 'About Novyn',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AboutRow(label: 'Version', value: '1.0.0 (build 1)'),
          _AboutRow(label: 'Platform', value: 'Flutter'),
          _AboutRow(label: 'Backend', value: 'Node.js + Socket.io'),
          _AboutRow(label: 'Auth', value: 'Firebase Auth'),
          SizedBox(height: 16),
          Text(
            '© 2026 Novyn. All rights reserved.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Internal Helpers for Sheets ─────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF7C6FF7) : const Color(0xFF94A3B8)),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? const Color(0xFF7C6FF7) : const Color(0xFF1A1D2E))),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7)) : null,
      onTap: onTap,
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.label, required this.iconColor, required this.iconBg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1A1D2E))),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
      onTap: onTap,
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final String name;
  final String detail;
  final bool isCurrent;
  final VoidCallback? onRemove;
  const _DeviceTile({required this.name, required this.detail, required this.isCurrent, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E5F0))),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFF0F2FA), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.phone_android_rounded, color: Color(0xFF7C6FF7), size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          if (isCurrent) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)), child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D2E))),
        ],
      ),
    );
  }
}
