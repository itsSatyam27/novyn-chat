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
    final level = _fontLevel(settings.fontSize);

    // Reduced motion silences tickers globally. Keep this screen's controls
    // interactive and self-contained so the user can always turn it back off.
    return TickerMode(
      enabled: true,
      child: Scaffold(
        backgroundColor: NovynTheme.pageBg(context),
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _AccessibilityHeader(),
              const SizedBox(height: 25),
              const _SectionLabel(
                title: 'Display',
                subtitle: null,
              ),
              _FontSizeCard(
                value: settings.fontSize,
                level: level,
                labels: _fontLabels,
                highContrast: settings.highContrast,
                onChanged: settings.setFontSize,
                onHighContrastChanged: settings.setHighContrast,
              ),
              const SizedBox(height: 24),
              const _SectionLabel(
                title: 'Motion',
                subtitle: null,
              ),
              _AccessibilityToggleCard(
                icon: Icons.monitor_heart_outlined,
                iconColor: const Color(0xFF287D9A),
                iconBackground: const Color(0xFFE2F2F6),
                title: 'Reduce motion',
                subtitle: 'Fewer animations and transitions',
                value: settings.reduceMotion,
                onChanged: settings.setReduceMotion,
              ),
              const SizedBox(height: 22),
              _AccessibilityHelpCard(
                onOpenAndroidSettings: () =>
                    _openAndroidAccessibility(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessibilityHeader extends StatelessWidget {
  const _AccessibilityHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Material(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 46,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: colors.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 25,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accessibility',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.55,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Make Novyn more comfortable to use',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
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
    required this.highContrast,
    required this.onChanged,
    required this.onHighContrastChanged,
  });

  final double value;
  final int level;
  final List<String> labels;
  final bool highContrast;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onHighContrastChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
            child: Row(
              children: [
                _FeatureIcon(
                  icon: Icons.text_fields_rounded,
                  background: colors.primary.withValues(alpha: .11),
                  foreground: colors.primary,
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
                        'Adjust global text size',
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
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceContainerHighest.withValues(alpha: .45)
                    : const Color(0xFFF5F1FC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                      letterSpacing: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                          fontSize: 14 * value,
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF7047F5),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomRight: Radius.circular(5),
                          bottomLeft: Radius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Haan, 5 baje milte hain',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * value,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 9),
            child: Column(
              children: [
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: colors.primary,
                          inactiveTrackColor: isDark
                              ? Colors.white24
                              : const Color(0xFFD7D0E9),
                          thumbColor: colors.primary,
                          overlayColor: colors.primary.withValues(alpha: .12),
                        ),
                        child: Slider(
                          value: level.toDouble(),
                          min: 0,
                          max: 4,
                          divisions: 4,
                          semanticFormatterCallback: (position) =>
                              '${labels[position.round().clamp(0, 4).toInt()]} font size',
                          onChanged: (position) {
                            final nextLevel =
                                position.round().clamp(0, 4).toInt();
                            final nextValue =
                                AccessibilityScreen._fontScales[nextLevel];
                            if (nextValue == value) return;
                            HapticService.vibrate(
                              NovynHapticType.selection,
                              category: HapticCategory.buttons,
                            );
                            onChanged(nextValue);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                          fontSize: 9.2,
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
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant.withValues(alpha: .7),
          ),
          _AccessibilityToggleCard(
            icon: Icons.contrast_rounded,
            iconColor: const Color(0xFFB65D12),
            iconBackground: const Color(0xFFFFF0E0),
            title: 'High contrast',
            subtitle: 'Stronger text and clearer controls',
            value: highContrast,
            onChanged: onHighContrastChanged,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: foreground, size: 23),
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
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  void _toggle() {
    HapticService.vibrate(
      NovynHapticType.medium,
      category: HapticCategory.buttons,
    );
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconBackground = dark
        ? iconColor.withValues(alpha: .16)
        : iconBackground;

    return Semantics(
      container: true,
      label: title,
      value: value ? 'On' : 'Off',
      toggled: value,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 17 : 16,
              vertical: compact ? 13 : 15,
            ),
            child: Row(
              children: [
                _FeatureIcon(
                  icon: icon,
                  background: effectiveIconBackground,
                  foreground: iconColor,
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
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StaticToggle(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticToggle extends StatelessWidget {
  const _StaticToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 54,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value
            ? colors.primary
            : (dark ? const Color(0xFF4C4A5B) : const Color(0xFFD8D3E9)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Align(
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessibilityHelpCard extends StatelessWidget {
  const _AccessibilityHelpCard({required this.onOpenAndroidSettings});

  final VoidCallback onOpenAndroidSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.primary.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 19,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saved on this device. Screen reader and voice access are managed by Android.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenAndroidSettings,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Android accessibility settings'),
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: 7,
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
