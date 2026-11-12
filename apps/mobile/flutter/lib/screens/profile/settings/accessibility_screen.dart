import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';
import '../../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget section(String title, String subtitle, List<Widget> children) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 25, 2, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(), style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 12,
                letterSpacing: 1, fontWeight: FontWeight.w800,
                color: colors.primary)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(
                fontSize: 12, color: colors.onSurfaceVariant)),
            ]),
          ),
          ...children,
        ]);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            const SettingsPageHeader(
              title: 'Accessibility',
              subtitle: 'Make Novyn more comfortable to use',
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                    ? [const Color(0xFF29234B), const Color(0xFF17323B)]
                    : [const Color(0xFFECE9FF), const Color(0xFFE3F7F4)],
                ),
                border: Border.all(color: colors.primary.withValues(alpha: .12)),
              ),
              child: Row(children: [
                Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(17)),
                  child: Icon(Icons.accessibility_new_rounded,
                    size: 29, color: colors.primary)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your comfort, your way',
                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: colors.onSurface)),
                    const SizedBox(height: 5),
                    Text('Personalise text size, contrast and motion.',
                      style: TextStyle(fontSize: 12, height: 1.4,
                        color: colors.onSurfaceVariant)),
                  ],
                )),
              ]),
            ),
            section('Display', 'Make content easier to read.',
              [
                _FontSizeCard(
                  value: settings.fontSize,
                  onChanged: settings.setFontSize,
                ),
                _ToggleCard(
                  icon: Icons.contrast_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: .11),
                  title: 'High contrast',
                  subtitle: 'Strengthen text and control visibility',
                  value: settings.highContrast,
                  onChanged: settings.setHighContrast,
                ),
              ]),
            section('Motion & interaction',
              'Choose how Novyn responds to your actions.',
              [
                _ToggleCard(
                  icon: Icons.motion_photos_off_rounded,
                  iconColor: const Color(0xFF0891B2),
                  iconBgColor: const Color(0xFF0891B2).withValues(alpha: .11),
                  title: 'Reduce motion',
                  subtitle: 'Reduce interface animations and transitions',
                  value: settings.reduceMotion,
                  onChanged: settings.setReduceMotion,
                ),
              ]),
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.tips_and_updates_outlined,
                  size: 19, color: colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Your accessibility preferences are saved on this device. Some assistive features, such as screen reader and voice access, are managed by Android in Settings.',
                  style: TextStyle(fontSize: 11.5, height: 1.5,
                    color: colors.onSurfaceVariant),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

}

class _FontSizeCard extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontSizeCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: NovynTheme.cardBg(context),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.text_fields_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font Scale',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adjust global text size',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Preview Area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Preview text at current scale',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14 * value,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('A', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Theme.of(context).colorScheme.primary,
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                          thumbColor: Theme.of(context).colorScheme.primary,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: value,
                          min: 0.8,
                          max: 1.5,
                          divisions: 7,
                          onChanged: (v) {
                            if (v != value) HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
                            onChanged(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('A', style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                  ],
                ),
              ],
            ),
          ),
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
      opacity: disabled ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: NovynTheme.cardBg(context),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
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
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
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
                      HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
                      onChanged?.call(v);
                    },
                    activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    activeColor: Theme.of(context).colorScheme.primary,
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