import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';
import '../../../theme/novyn_theme.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const BouncingScrollPhysics(),
        children: [
          SettingsPageHeader(title: 'Accessibility', subtitle: 'Make Novyn easier to use'),
          SettingsIntroCard(title: 'Make Novyn easier to use', subtitle: 'Adjust the supported display options and explore accessibility features.', icon: Icons.accessibility_new_rounded),
          const SectionLabel(label: 'Display'),
          _FontSizeCard(
            value: settings.fontSize,
            onChanged: (v) => settings.setFontSize(v),
          ),
          _ToggleCard(
            icon: Icons.contrast_rounded,
            iconColor: Theme.of(context).colorScheme.primary,
            iconBgColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            title: 'High Contrast Mode',
            subtitle: 'Use stronger text and control borders throughout Novyn',
            value: settings.highContrast,
            onChanged: settings.setHighContrast,
          ),
          _ToggleCard(
            icon: Icons.motion_photos_off_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Reduce motion',
            subtitle: 'Reduce interface animations and transitions',
            value: settings.reduceMotion,
            onChanged: settings.setReduceMotion,
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Audio & touch'),
          _ToggleCard(
            icon: Icons.audiotrack_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'Audio Descriptions',
            subtitle: 'Not available yet',
            value: false,
            onChanged: null,
          ),
          _ToggleCard(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFFEC4899),
            iconBgColor: const Color(0xFFEC4899).withValues(alpha: 0.1),
            title: 'Enhanced Tactility',
            subtitle: 'Not available yet',
            value: false,
            onChanged: null,
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Input'),
          _ToggleCard(
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Voice Control',
            subtitle: 'Not available yet',
            value: false,
            onChanged: null,
          ),
          
          const SizedBox(height: 40),
        ],
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
                            if (v != value) HapticFeedback.selectionClick();
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
                      HapticFeedback.mediumImpact();
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