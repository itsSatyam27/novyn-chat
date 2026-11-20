import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_alert.dart';
import 'dock_customization_screen.dart';
import 'alert_customization_screen.dart';
import 'quick_toggle_customization_screen.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _callMiniStyles = <(String, String)>[
    ('top_banner', 'Top call banner'),
    ('floating_avatar', 'Floating avatar'),
    ('compact_pill', 'Compact call pill'),
    ('bottom_bar', 'Bottom control bar'),
    ('video_card', 'Video mini card'),
    ('edge_chip', 'Edge call chip'),
  ];

  static const _dockLabels = {
    'slide_pill': 'Slide Pill',
    'expand_capsule': 'Expand Capsule',
    'edge_to_edge': 'Edge to Edge',
    'dot_minimal': 'Dot Minimal',
    'soft_glow_glass': 'Soft Glow Glass',
    'liquid_stretch': 'Liquid Stretch',
    'flip_tiles': 'Flip Tiles',
    'draw_ring': 'Draw Ring',
  };

  static const _accents = <(String, Color)>[
    ('Indigo', Color(0xFF6D5DFC)),
    ('Violet', Color(0xFF8B5CF6)),
    ('Blue', Color(0xFF2563EB)),
    ('Teal', Color(0xFF0D9488)),
    ('Pink', Color(0xFFDB2777)),
    ('Orange', Color(0xFFEA580C)),
    ('Green', Color(0xFF16A34A)),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final username = context.watch<AuthService>().user?.username ?? 'user';
    final quickToggleCount = settings.quickToggleIdsFor(username).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Color(settings.accentColorValue);
    final selectedAccent = _accents.indexWhere((item) => item.$2.value == accent.value);

    final currentCallStyle = _callMiniStyles.firstWhere(
      (item) => item.$1 == settings.callMiniStyle,
      orElse: () => _callMiniStyles.first,
    ).$2;

    final currentAlertStyle = NovynAlertStyles.byId(settings.alertStyle).name;
    final currentDockStyle = _dockLabels[settings.dockStyle] ?? 'Slide Pill';

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Appearance',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // THEME Section
            _sectionHeader('THEME'),
            Row(
              children: [
                _ThemeChoiceCard(
                  label: 'Light',
                  mode: ThemeMode.light,
                  selected: settings.themeMode == ThemeMode.light,
                  onTap: () => settings.setThemeMode(ThemeMode.light),
                ),
                const SizedBox(width: 12),
                _ThemeChoiceCard(
                  label: 'Dark',
                  mode: ThemeMode.dark,
                  selected: settings.themeMode == ThemeMode.dark,
                  onTap: () => settings.setThemeMode(ThemeMode.dark),
                ),
                const SizedBox(width: 12),
                _ThemeChoiceCard(
                  label: 'System',
                  mode: ThemeMode.system,
                  selected: settings.themeMode == ThemeMode.system,
                  onTap: () => settings.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ACCENT COLOUR Section
            _sectionHeader('ACCENT COLOUR'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.palette_outlined,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Apply selected accent',
                  trailing: Switch.adaptive(
                    value: settings.accentColorEnabled,
                    activeColor: Colors.white,
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: isDark ? const Color(0xFF3B394E) : const Color(0xFFE2E0EC),
                    trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                    onChanged: (val) {
                      HapticService.vibrate(NovynHapticType.selection);
                      settings.setAccentColorEnabled(val);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 8,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 7) {
                        return _AccentItem(
                          name: 'Custom',
                          color: const Color(0xFF6D5DFC),
                          selected: selectedAccent < 0,
                          custom: true,
                          onTap: () async {
                            final picked = await _showCustomAccentPicker(context, accent);
                            if (picked != null) await settings.setAccentColor(picked.value);
                          },
                        );
                      }
                      final item = _accents[index];
                      final isSelected = accent.value == item.$2.value;
                      return _AccentItem(
                        name: item.$1,
                        color: item.$2,
                        selected: isSelected,
                        onTap: () => settings.setAccentColor(item.$2.value),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // QUICK CUSTOMIZATION Section
            _sectionHeader('QUICK CUSTOMIZATION'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.widgets_rounded,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Quick toggles',
                  trailing: _trailingValueWithChevron('$quickToggleCount/4'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickToggleCustomizationScreen(accountKey: username),
                    ),
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.dock_rounded,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Dock style',
                  trailing: _trailingValueWithChevron(currentDockStyle),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DockCustomizationScreen()),
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.notifications_none_rounded,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Alert style',
                  trailing: _trailingValueWithChevron(currentAlertStyle),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertCustomizationScreen()),
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.phone_outlined,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Minimized call',
                  trailing: _trailingValueWithChevron(currentCallStyle),
                  onTap: () => _showCallMiniStylePicker(context, settings),
                ),
              ],
            ),
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

  static Widget _trailingValueWithChevron(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF8F8BA0),
          size: 20,
        ),
      ],
    );
  }

  static Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
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

  static void _showCallMiniStylePicker(BuildContext context, SettingsService settings) {
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
                'Minimized call style',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NovynTheme.textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 14),
              for (final style in _callMiniStyles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    style.$2,
                    style: TextStyle(
                      fontWeight: settings.callMiniStyle == style.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: settings.callMiniStyle == style.$1
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      : Icon(Icons.circle_outlined),
                  onTap: () {
                    settings.setCallMiniStyle(style.$1);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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

  const _SettingsRow({
    this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

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
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoiceCard({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = mode == ThemeMode.dark;
    final system = mode == ThemeMode.system;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF1A1730);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.vibrate(NovynHapticType.selection);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF242042) : Colors.white)
                : (isDark ? const Color(0xFF1E1C2E) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6)),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Mockup box
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF1C1930)
                      : (system ? Colors.transparent : const Color(0xFFF1EEFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF2E2B46)
                        : (system ? Colors.transparent : const Color(0xFFE5E0F8)),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: system
                    ? Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFFF1EEFC),
                              padding: const EdgeInsets.only(left: 8, top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6D5DFC),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 32,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9E9AA8),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: const Color(0xFF1C1930),
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 10, top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D5DFC),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF635E7D)
                                    : const Color(0xFF9E9AA8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Color(0xFF1A1730),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? (isDark ? Colors.white : const Color(0xFF1A1730))
                          : (isDark ? const Color(0xFF8F8BA0) : const Color(0xFF646078)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentItem extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final bool custom;
  final VoidCallback onTap;

  const _AccentItem({
    required this.name,
    required this.color,
    required this.selected,
    this.custom = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticService.vibrate(NovynHapticType.selection);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: dark ? Colors.white : const Color(0xFF1A1730),
                      width: 2,
                    )
                  : null,
            ),
            padding: EdgeInsets.all(selected ? 3 : 0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: selected
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : (custom
                        ? Icon(Icons.edit_outlined, color: Colors.white, size: 18)
                        : null),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: dark ? const Color(0xFFC0BDCC) : const Color(0xFF5A5670),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Color?> _showCustomAccentPicker(BuildContext context, Color initial) {
  var hsv = HSVColor.fromColor(initial);
  return showDialog<Color>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final preview = hsv.toColor();
        return AlertDialog(
          title: const Text('Custom accent colour'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: preview,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _PickerSlider(
                  label: 'Hue',
                  value: hsv.hue,
                  max: 360,
                  onChanged: (v) => setState(() => hsv = hsv.withHue(v)),
                ),
                _PickerSlider(
                  label: 'Saturation',
                  value: hsv.saturation,
                  max: 1,
                  onChanged: (v) => setState(() => hsv = hsv.withSaturation(v)),
                ),
                _PickerSlider(
                  label: 'Brightness',
                  value: hsv.value,
                  max: 1,
                  onChanged: (v) => setState(() => hsv = hsv.withValue(v)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '#${preview.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, preview),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}

class _PickerSlider extends StatelessWidget {
  const _PickerSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                max == 360 ? '${value.round()}°' : '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Slider(
            value: value.clamp(0, max),
            min: 0,
            max: max,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      );
}
