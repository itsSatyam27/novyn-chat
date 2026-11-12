import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';
import '../../../theme/novyn_theme.dart';

class LanguageRegionScreen extends StatelessWidget {
  const LanguageRegionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final languages = settings.getLanguagesForRegion(settings.region);
    final languageLabel = languages[settings.language] ?? 'English';
    final now = DateTime.now();
    final datePreview = MaterialLocalizations.of(context).formatMediumDate(now);
    final timePreview = TimeOfDay.now().format(context);
    final regionFlag = switch (settings.region) {
      'India' => '🇮🇳',
      'United States' => '🇺🇸',
      'United Kingdom' => '🇬🇧',
      'Canada' => '🇨🇦',
      'Australia' => '🇦🇺',
      'Germany' => '🇩🇪',
      'France' => '🇫🇷',
      'Spain' => '🇪🇸',
      'Italy' => '🇮🇹',
      'Japan' => '🇯🇵',
      'South Korea' => '🇰🇷',
      'Russia' => '🇷🇺',
      _ => '🌐',
    };

    Widget sectionTitle(String title, String caption) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
          fontFamily: 'PlusJakartaSans', fontSize: 13, letterSpacing: .7,
          fontWeight: FontWeight.w800, color: colors.primary)),
        const SizedBox(height: 3),
        Text(caption, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
      ]),
    );

    Widget settingTile({
      required IconData icon,
      required Color tint,
      required String title,
      required String value,
      required String subtitle,
      required VoidCallback onTap,
    }) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: tint.withValues(alpha: isDark ? .18 : .10),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: tint, size: 21)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: colors.onSurface)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
            ])),
            const SizedBox(width: 8),
            Flexible(child: Text(value, textAlign: TextAlign.end, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.primary))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.onSurfaceVariant),
          ]),
        ),
      ),
    );

    Widget group(List<Widget> children) => Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .8)),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1)
            Divider(height: 1, indent: 69, endIndent: 14,
              color: colors.outlineVariant.withValues(alpha: .65)),
        ],
      ]),
    );

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            const SettingsPageHeader(
              title: 'Language & Region',
              subtitle: 'Personalise your language and local formats',
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: isDark
                    ? [const Color(0xFF29234B), const Color(0xFF172D3A)]
                    : [const Color(0xFFECE9FF), const Color(0xFFE4F7F5)],
                ),
                border: Border.all(color: colors.primary.withValues(alpha: .12)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.language_rounded, color: colors.primary, size: 25)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(color: colors.surface.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(30)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF159B78)),
                      const SizedBox(width: 5),
                      Text('Saved automatically', style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: colors.onSurface)),
                    ])),
                ]),
                const SizedBox(height: 16),
                Text('Make Novyn feel local',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 19,
                    fontWeight: FontWeight.w800, color: colors.onSurface)),
                const SizedBox(height: 5),
                Text('Choose the language you prefer and how dates and times appear.',
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(children: [
                  Text(regionFlag, style: const TextStyle(fontSize: 25)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(settings.region,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: colors.onSurface))),
                  Container(width: 1, height: 28, color: colors.outlineVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text(languageLabel, textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: colors.primary))),
                ]),
              ]),
            ),

            sectionTitle('APP LANGUAGE', 'Language used by the app interface'),
            group([
              settingTile(
                icon: Icons.translate_rounded,
                tint: const Color(0xFF8B5CF6),
                title: 'App language',
                value: languageLabel,
                subtitle: 'Select your preferred language',
                onTap: () => _showLanguageDialog(context, settings),
              ),
            ]),

            sectionTitle('REGION & TIME ZONE', 'Set the location and local time reference'),
            group([
              settingTile(
                icon: Icons.public_rounded,
                tint: const Color(0xFF0891B2),
                title: 'Region',
                value: '$regionFlag  ${settings.region}',
                subtitle: 'Country or regional preference',
                onTap: () => _showRegionDialog(context, settings),
              ),
              settingTile(
                icon: Icons.schedule_rounded,
                tint: const Color(0xFFF59E0B),
                title: 'Time zone',
                value: _getTimeZoneString(),
                subtitle: 'Automatically follows your device',
                onTap: () => _showTimezoneDialog(context),
              ),
            ]),

            sectionTitle('FORMATS', 'Preview of the formats used on this device'),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              decoration: BoxDecoration(
                color: NovynTheme.cardBg(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: .8)),
              ),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.calendar_month_rounded, color: const Color(0xFF10B981), size: 20),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Date format', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: colors.onSurface)),
                    Text('Device regional settings', style: TextStyle(fontSize: 11,
                      color: colors.onSurfaceVariant)),
                  ])),
                  Text(datePreview, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: colors.primary)),
                  IconButton(tooltip: 'About date format', onPressed: () => _showDateFormatDialog(context),
                    icon: Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant)),
                ]),
                Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .65)),
                Row(children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFFEC4899), size: 20),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Time format', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: colors.onSurface)),
                    Text('Device 12 / 24-hour preference', style: TextStyle(fontSize: 11,
                      color: colors.onSurfaceVariant)),
                  ])),
                  Text(timePreview, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: colors.primary)),
                  IconButton(tooltip: 'About time format', onPressed: () => _showTimeFormatDialog(context),
                    icon: Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant)),
                ]),
                Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .65)),
                Row(children: [
                  Icon(Icons.numbers_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Number format', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: colors.onSurface)),
                    Text('Device locale', style: TextStyle(fontSize: 11,
                      color: colors.onSurfaceVariant)),
                  ])),
                  Text(settings.region == 'India' ? '1,23,456.78' : '123,456.78',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: colors.primary)),
                  IconButton(tooltip: 'About number format', onPressed: () => _showNumberFormatDialog(context),
                    icon: Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 17, color: colors.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  'Time zone, date, time and number formats currently follow your Android device settings. You can change them in Android Settings.',
                  style: TextStyle(fontSize: 11, height: 1.45, color: colors.onSurfaceVariant),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsService settings) {
    final languages = settings.getLanguagesForRegion(settings.region);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Choose app language',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: languages.entries.map((entry) {
            final selected = settings.language == entry.key;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(entry.value, style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface)),
              trailing: selected ? Icon(Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                HapticFeedback.selectionClick();
                settings.setLanguage(entry.key);
                Navigator.pop(dialogContext);
              },
            );
          }).toList()),
        ),
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          title: const Text('Select Region', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900)),
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
                      fontFamily: 'PlusJakartaSans', 
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    )
                  ),
                  trailing: isSelected 
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) 
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
    _showDeviceFormatInfo(
      context,
      title: 'Time zone is automatic',
      message: 'Novyn uses the time zone configured on your device. To change it, open Android Settings → System → Date & time.',
    );
  }

  void _showDateFormatDialog(BuildContext context) {
    _showDeviceFormatInfo(
      context,
      title: 'Date format',
      message: 'Novyn currently follows your device language and regional settings for dates. Custom date formats are not available yet.',
    );
  }

  void _showTimeFormatDialog(BuildContext context) {
    _showDeviceFormatInfo(
      context,
      title: 'Time format',
      message: 'Novyn follows your device 12-hour or 24-hour preference. You can change it in Android Settings → System → Date & time.',
    );
  }

  void _showNumberFormatDialog(BuildContext context) {
    _showDeviceFormatInfo(
      context,
      title: 'Number format',
      message: 'Novyn currently follows your device locale for number formatting. Custom number formats are not available yet.',
    );
  }
  void _showDeviceFormatInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
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

  String _getDateFormatString() => 'Device locale';
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
        color: NovynTheme.cardBg(context),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
        color: NovynTheme.cardBg(context),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentLabel,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          title: Text(
            title,
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900),
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
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) 
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