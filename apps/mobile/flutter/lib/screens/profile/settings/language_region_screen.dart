import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';

class LanguageRegionScreen extends StatelessWidget {
  const LanguageRegionScreen({super.key});

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
            'Language & Region',
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
          const SectionLabel(label: 'Linguistic Profile'),
          _SelectionCard(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF8B5CF6),
            iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            title: 'App Language',
            subtitle: 'Choose your preferred linguistic node',
            value: settings.language,
            options: settings.getLanguagesForRegion(settings.region).keys.toList(),
            labels: settings.getLanguagesForRegion(settings.region).values.toList(),
            onChanged: (v) => settings.setLanguage(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Geographic Coordination'),
          _ActionCard(
            icon: Icons.public_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Region',
            subtitle: settings.region,
            onTap: () => _showRegionDialog(context, settings),
          ),
          _ActionCard(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'Time Zone',
            subtitle: _getTimeZoneString(),
            onTap: () => _showTimezoneDialog(context),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Data Serialization'),
          _ActionCard(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Date Format',
            subtitle: _getDateFormatString(),
            onTap: () => _showDateFormatDialog(context),
          ),
          _ActionCard(
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFFEC4899),
            iconBgColor: const Color(0xFFEC4899).withValues(alpha: 0.1),
            title: 'Time Format',
            subtitle: MediaQuery.of(context).alwaysUse24HourFormat ? '24-hour' : '12-hour',
            onTap: () => _showTimeFormatDialog(context),
          ),
          _ActionCard(
            icon: Icons.numbers_rounded,
            iconColor: const Color(0xFF7C6FF7),
            iconBgColor: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
            title: 'Number Format',
            subtitle: '1,234.56',
            onTap: () => _showNumberFormatDialog(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showRegionDialog(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final regions = [
      'India', 'United States', 'United Kingdom', 'Canada', 'Australia',
      'Germany', 'France', 'Spain', 'Italy', 'Japan', 'South Korea', 'Russia'
    ];

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
          title: const Text('Select Region', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: regions.map((region) {
                final isSelected = settings.region == region;
                return ListTile(
                  title: Text(
                    region, 
                    style: TextStyle(
                      fontFamily: 'Outfit', 
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF7C6FF7) : null,
                    )
                  ),
                  trailing: isSelected 
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7)) 
                      : null,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    settings.setRegion(region);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showTimezoneDialog(BuildContext context) {
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
          title: const Text('Select Time Zone', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
          content: const Text(
            'Time zone will be automatically synchronized based on your cryptographic location nodes.',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Confirm', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, color: Color(0xFF7C6FF7))),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFormatDialog(BuildContext context) {
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
          title: const Text('Date Format', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD', 'DD MMM YYYY'].map((format) => ListTile(
              title: Text(format, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showTimeFormatDialog(BuildContext context) {
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
          title: const Text('Time Format', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['12-hour', '24-hour'].map((format) => ListTile(
              title: Text(format, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showNumberFormatDialog(BuildContext context) {
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
          title: const Text('Number Format', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['1,234.56', '1.234,56', '1 234,56'].map((format) => ListTile(
              title: Text(format, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
  String _getTimeZoneString() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    final absHours = hours.abs();
    
    return 'GMT$sign${absHours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')} (${now.timeZoneName})';
  }

  String _getDateFormatString() {
    // This could be dynamic based on locale
    return 'DD/MM/YYYY';
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
                  Icon(
                    Icons.chevron_right_rounded, 
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                    size: 20
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
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _showSelectionDialog(context);
            },
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentLabel,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded, 
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                        size: 20
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
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
                      color: isSelected ? const Color(0xFF7C6FF7) : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected 
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7)) 
                      : null,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onChanged(option);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}