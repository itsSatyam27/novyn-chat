import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';
import '../widgets/profile_widgets.dart';

const _accessibilityChannel = MethodChannel('com.example.novyn/accessibility');

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  static const _fontScales = <double>[0.85, 1.0, 1.10, 1.18, 1.25];
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
    final colors = Theme.of(context).colorScheme;
    final level = _fontLevel(settings.fontSize);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const SettingsPageHeader(
              title: 'Accessibility',
              subtitle: 'Make Novyn more comfortable to use',
            ),
            const SizedBox(height: 22),
            _SectionLabel(
              title: 'Display',
              subtitle: 'Make content easier to read.',
            ),
            _FontSizeCard(
              value: settings.fontSize,
              level: level,
              labels: _fontLabels,
              onChanged: settings.setFontSize,
            ),
            const SizedBox(height: 8),
            _AccessibilityToggleCard(
              icon: Icons.contrast_rounded,
              iconColor: const Color(0xFFB65D12),
              iconBackground: const Color(0xFFFFF0E0),
              title: 'High contrast',
              subtitle: 'Make text, borders and controls easier to distinguish',
              value: settings.highContrast,
              onChanged: settings.setHighContrast,
            ),
            const SizedBox(height: 24),
            _SectionLabel(
              title: 'Motion',
              subtitle: 'Choose how Novyn moves and responds.',
            ),
            _AccessibilityToggleCard(
              icon: Icons.graphic_eq_rounded,
              iconColor: const Color(0xFF287D9A),
              iconBackground: const Color(0xFFE2F2F6),
              title: 'Reduce motion',
              subtitle: 'Limit interface animations and transitions',
              value: settings.reduceMotion,
              onChanged: settings.setReduceMotion,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .075),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 21,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Your Novyn display preferences are applied throughout the app. Screen reader, voice access and other assistive services are managed by Android.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openAndroidAccessibility(context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Open Android accessibility settings'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeCard extends StatelessWidget {
  const _FontSizeCard({
    required this.value,
    required this.level,
    required this.labels,
    required this.onChanged,
  });

  final double value;
  final int level;
  final List<String> labels;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  color: colors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font size',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Adjust text throughout Novyn',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceContainerHighest.withValues(alpha: .45)
                  : const Color(0xFFF6F3FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 245),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                        bottomLeft: Radius.circular(5),
                      ),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Text(
                      'Kal ka plan final hai?',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 245),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                        bottomRight: Radius.circular(5),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Haan, 5 baje milte hain',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'A',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: isDark
                        ? Colors.white24
                        : const Color(0xFFD8D2EC),
                    thumbColor: colors.primary,
                    overlayColor: colors.primary.withValues(alpha: .12),
                  ),
                  child: Slider(
                    value: level.toDouble(),
                    min: 0,
                    max: 4,
                    divisions: 4,
                    semanticFormatterCallback: (position) =>
                        '${labels[position.round().clamp(0, 4)]} font size',
                    onChanged: (position) {
                      final nextLevel = position.round().clamp(0, 4);
                      final nextValue = AccessibilityScreen._fontScales[nextLevel];
                      if (nextValue != value) {
                        HapticService.vibrate(
                          NovynHapticType.selection,
                          category: HapticCategory.buttons,
                        );
                        onChanged(nextValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'A',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(
              labels.length,
              (index) => Expanded(
                child: Text(
                  labels[index],
                  textAlign: index == 0
                      ? TextAlign.start
                      : index == labels.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                  style: TextStyle(
                    color: index == level
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: index == level
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessibilityToggleCard extends StatelessWidget {
  const _AccessibilityToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconBackground = dark
        ? iconColor.withValues(alpha: .16)
        : iconBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: effectiveIconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: (next) {
              HapticService.vibrate(
                NovynHapticType.medium,
                category: HapticCategory.buttons,
              );
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}
