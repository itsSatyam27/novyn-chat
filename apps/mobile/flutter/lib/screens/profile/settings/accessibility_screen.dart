import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';

const _accessibilityChannel = MethodChannel('com.example.novyn/accessibility');

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  static const _fontScales = <double>[0.95, 1.05, 1.30, 1.38, 1.45];
  static const _fontLabels = <String>[
    'Small',
    'Default',
    'Large',
    'Larger',
    'Largest',
  ];

  int _fontLevel(double value) {
    var closest = 0;
    var distance = double.infinity;
    for (var i = 0; i < _fontScales.length; i++) {
      final nextDistance = (value - _fontScales[i]).abs();
      if (nextDistance < distance) {
        closest = i;
        distance = nextDistance;
      }
    }
    return closest;
  }

  Future<void> _openAndroidAccessibility(BuildContext context) async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open your device Settings and choose Accessibility.'),
        ),
      );
      return;
    }

    try {
      await _accessibilityChannel.invokeMethod<void>(
        'openAccessibilitySettings',
      );
    } on PlatformException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Android Accessibility settings.'),
        ),
      );
    } on MissingPluginException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accessibility settings are not available right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = _fontLevel(settings.fontSize);

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            _ScreenHeader(
              title: 'Accessibility',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // DISPLAY Section
            _sectionHeader(context, 'DISPLAY'),
            _groupedCard(
              context,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _iconBox(
                            Icons.text_fields_rounded,
                            const Color(0xFF6366F1),
                            isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Font size',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1730),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(settings.fontSize * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 5,
                            activeTrackColor: Theme.of(context).colorScheme.primary,
                            inactiveTrackColor: isDark ? const Color(0xFF2C2844) : const Color(0xFFECE9FB),
                            thumbColor: Theme.of(context).colorScheme.primary,
                            overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                            activeTickMarkColor: Colors.transparent,
                            inactiveTickMarkColor: const Color(0xFF9E9AA8),
                          ),
                          child: Slider(
                            value: level.toDouble(),
                            min: 0,
                            max: 4,
                            divisions: 4,
                            onChanged: (position) {
                              final nextLevel = position.round().clamp(0, 4).toInt();
                              final nextValue = _fontScales[nextLevel];
                              if (nextValue == settings.fontSize) return;
                              HapticService.vibrate(NovynHapticType.selection);
                              settings.setFontSize(nextValue);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: List.generate(
                            _fontLabels.length,
                            (index) => Expanded(
                              child: Text(
                                _fontLabels[index],
                                textAlign: index == 0
                                    ? TextAlign.start
                                    : index == _fontLabels.length - 1
                                        ? TextAlign.end
                                        : TextAlign.center,
                                style: TextStyle(
                                  color: index == level
                                      ? Theme.of(context).colorScheme.primary
                                      : (isDark ? const Color(0xFF8F8BA0) : const Color(0xFF5A5670)),
                                  fontSize: 12,
                                  fontWeight: index == level ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.contrast_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF382A1B) : const Color(0xFFFEF3E2),
                  ),
                  title: 'High contrast',
                  trailing: _purpleSwitch(
                    value: settings.highContrast,
                    onChanged: settings.setHighContrast,
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // MOTION Section
            _sectionHeader(context, 'MOTION'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.show_chart_rounded,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                  ),
                  title: 'Reduce motion',
                  trailing: _purpleSwitch(
                    value: settings.reduceMotion,
                    onChanged: settings.setReduceMotion,
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Android accessibility settings link card
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.open_in_new_rounded,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Open Android accessibility settings',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: () => _openAndroidAccessibility(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
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
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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

  static Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = Theme.of(context).colorScheme.outlineVariant;
    final highContrast = context.watch<SettingsService>().highContrast;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: highContrast ? 2 : 1),
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
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
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
