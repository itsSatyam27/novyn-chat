import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121F) : const Color(0xFFF8FAFC),
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
            'Accessibility',
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
          const SectionLabel(label: 'Visual Synthesis'),
          _FontSizeCard(
            value: settings.fontSize,
            onChanged: (v) => settings.setFontSize(v),
          ),
          _ToggleCard(
            icon: Icons.contrast_rounded,
            iconColor: const Color(0xFF7C6FF7),
            iconBgColor: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
            title: 'High Contrast Mode',
            subtitle: 'Enhance visual serialization clarity',
            value: false,
            onChanged: (v) => _showComingSoon(context, 'High Contrast'),
          ),
          _ToggleCard(
            icon: Icons.motion_photos_off_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Reduce Motion Flux',
            subtitle: 'Minimize transition entropy',
            value: false,
            onChanged: (v) => _showComingSoon(context, 'Reduce Motion'),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Resonance & Perception'),
          _ToggleCard(
            icon: Icons.audiotrack_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'Audio Descriptions',
            subtitle: 'Auditory stream for visual nodes',
            value: false,
            onChanged: (v) => _showComingSoon(context, 'Audio Descriptions'),
          ),
          _ToggleCard(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFFEC4899),
            iconBgColor: const Color(0xFFEC4899).withValues(alpha: 0.1),
            title: 'Enhanced Tactility',
            subtitle: 'Stronger neural haptic feedback',
            value: false,
            onChanged: (v) => _showComingSoon(context, 'Enhanced Haptics'),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Input Orchestration'),
          _ToggleCard(
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Voice Control',
            subtitle: 'Navigate via vocal resonance',
            value: false,
            onChanged: (v) => _showComingSoon(context, 'Voice Control'),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature integration pending...', style: const TextStyle(fontFamily: 'Outfit')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
                        color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.text_fields_rounded, color: Color(0xFF7C6FF7), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font Scale',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adjust global text serialization',
                            style: TextStyle(
                              fontFamily: 'Outfit',
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
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C6FF7),
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
                    'Node preview at current scale',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14 * value,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF7C6FF7),
                    inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                    thumbColor: Colors.white,
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
          color: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Outfit',
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
                    activeTrackColor: const Color(0xFF7C6FF7).withValues(alpha: 0.5),
                    activeColor: const Color(0xFF7C6FF7),
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