// settings_screen.dart
import 'package:flutter/material.dart';

import 'novyn_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onTabSelected, this.onLogout});

  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return NovynScaffold(
      currentTab: 4,
      onTabSelected: onTabSelected,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const NovynHeader(
            title: 'Settings',
            titleColor: NovynColors.violetSoft,
          ),
          const _ProfileCard(),
          const _Section(
            label: 'PREFERENCES',
            tiles: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                value: 'Dark',
              ),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Sounds & Notifications',
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language & Region',
                value: 'English',
              ),
              _SettingsTile(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility',
              ),
            ],
          ),
          const _Section(
            label: 'ACCOUNT',
            tiles: [
              _SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Data & Storage',
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Security',
                accent: NovynColors.amber,
                badge: '2 to fix',
              ),
              _SettingsTile(
                icon: Icons.visibility_outlined,
                title: 'Privacy',
              ),
            ],
          ),
          const _Section(
            radius: 22,
            topPadding: 12,
            tiles: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
              ),
            ],
          ),
          _LogoutButton(onTap: onLogout),
        ],
      ),
    );
  }
}

// ───────────────────────── Profile card ─────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x66A173FF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x598F5BFF), Color(0x335B2BD6)],
        ),
      ),
      child: Row(
        children: [
          const NovynAvatar(
            size: 58,
            letter: 'S',
            colors: AvatarPalette.purple,
            statusColor: NovynColors.mint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('satyam',
                    style: NovynText.body(18, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('● Online',
                    style: NovynText.body(13, color: NovynColors.mint)),
              ],
            ),
          ),
          const Icon(Icons.qr_code_2_rounded,
              size: 20, color: Color(0xFFE6DCFF)),
          const SizedBox(width: 14),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: NovynColors.navIcon),
        ],
      ),
    );
  }
}

// ───────────────────────── Grouped list ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.tiles,
    this.label,
    this.radius = 24,
    this.topPadding = 10,
  });

  final String? label;
  final List<_SettingsTile> tiles;
  final double radius;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            NovynSectionLabel(
              label!,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            ),
          Container(
            decoration: BoxDecoration(
              color: NovynColors.card,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: NovynColors.glassBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Material(
                color: Colors.transparent,
                child: Column(children: tiles),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.badge,
    this.accent = NovynColors.violet,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? badge;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(0x22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: NovynText.body(15.5, weight: FontWeight.w600)),
            ),
            if (value != null)
              Text(value!,
                  style: NovynText.body(13, color: NovynColors.textMuted)),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(0x29),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge!,
                    style: NovynText.body(11,
                        weight: FontWeight.w700, color: accent)),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: NovynColors.chevron),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Log out ─────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: BoxDecoration(
          color: const Color(0x14FF5C7A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x4DFF5C7A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded,
                size: 19, color: NovynColors.danger),
            const SizedBox(width: 10),
            Text('Log out',
                style: NovynText.body(15,
                    weight: FontWeight.w700, color: NovynColors.danger)),
          ],
        ),
      ),
    );
  }
}
