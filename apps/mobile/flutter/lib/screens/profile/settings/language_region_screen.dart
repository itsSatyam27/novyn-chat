import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';

import '../../../services/settings_service.dart';
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
    final currentTime = TimeOfDay.now();
    final timePreview = settings.timeFormat == '24h'
        ? '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}'
        : currentTime.format(context);
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
    final numberPreview = settings.region == 'India' ? '1,23,456.78' : '123,456.78';

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Language & Region',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 14),

            // Hero Card
            _LanguageHeroCard(
              regionFlag: regionFlag,
              regionName: settings.region,
              languageName: languageLabel,
            ),
            const SizedBox(height: 22),

            // APP LANGUAGE Section
            _sectionHeader(
              title: 'APP LANGUAGE',
              subtitle: 'Language used by the app interface',
              context: context,
            ),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _PreferenceRow(
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  title: 'App language',
                  subtitle: 'Select your preferred app language',
                  onTap: () => _showLanguageDialog(context, settings),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        languageLabel,
                        style: const TextStyle(
                          color: Color(0xFF6D5DFC),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6D5DFC),
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // REGION & TIME ZONE Section
            _sectionHeader(
              title: 'REGION & TIME ZONE',
              subtitle: 'Set the location and local time reference',
              context: context,
            ),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _PreferenceRow(
                  icon: Icons.public_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: isDark ? const Color(0xFF1B2E33) : const Color(0xFFE0F7F4),
                  title: 'Region',
                  subtitle: 'Country or regional setting',
                  onTap: () => _showRegionDialog(context, settings),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(regionFlag, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        settings.region,
                        style: const TextStyle(
                          color: Color(0xFF6D5DFC),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6D5DFC),
                        size: 19,
                      ),
                    ],
                  ),
                ),
                _PreferenceRow(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: isDark ? const Color(0xFF332717) : const Color(0xFFFEF3E2),
                  title: 'Time zone',
                  subtitle: 'Automatically follows your device',
                  onTap: () => _showTimezoneDialog(context),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTimeZoneString(),
                        style: const TextStyle(
                          color: Color(0xFF6D5DFC),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6D5DFC),
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // FORMATS Section
            _sectionHeader(
              title: 'FORMATS',
              subtitle: 'Preview of the formats used on this device',
              context: context,
            ),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _PreferenceRow(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                  title: 'Date format',
                  subtitle: 'Device regional settings',
                  onTap: () => _showDateFormatDialog(context),
                  trailing: _PillBadge(label: datePreview),
                ),
                _PreferenceRow(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBgColor: isDark ? const Color(0xFF361F2E) : const Color(0xFFFCE7F3),
                  title: 'Time format',
                  subtitle: 'Device 12 / 24-hour preference',
                  onTap: () => _showTimeFormatOptions(context, settings),
                  trailing: _PillBadge(label: timePreview),
                ),
                _PreferenceRow(
                  icon: Icons.tag_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  title: 'Number format',
                  subtitle: 'Device locale',
                  onTap: () => _showNumberFormatDialog(context),
                  trailing: _PillBadge(label: numberPreview),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Info Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF202035)
                    : const Color(0xFFF0EDFF).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF6D5DFC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Time zone, date, time and number formats currently follow your Android device settings. You can change them in Android Settings.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
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

  static Widget _sectionHeader(
      {required String title, required String subtitle, required BuildContext context}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: colors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  static Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 72,
                  endIndent: 16,
                  color: border.withValues(alpha: 0.65),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTimeFormatOptions(BuildContext context, SettingsService settings) {
    HapticService.vibrate(NovynHapticType.selection);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time format',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              RadioListTile<String>(
                value: '12h',
                groupValue: settings.timeFormat,
                title: const Text('12-hour (e.g. 6:43 AM)'),
                onChanged: (val) {
                  if (val != null) settings.setTimeFormat(val);
                  Navigator.pop(sheetContext);
                },
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                value: '24h',
                groupValue: settings.timeFormat,
                title: const Text('24-hour (e.g. 18:43)'),
                onChanged: (val) {
                  if (val != null) settings.setTimeFormat(val);
                  Navigator.pop(sheetContext);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
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
        title: const Text(
          'Choose app language',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.entries.map((entry) {
              final selected = settings.language == entry.key;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  HapticService.vibrate(NovynHapticType.selection);
                  settings.setLanguage(entry.key);
                  Navigator.pop(dialogContext);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showRegionDialog(BuildContext context, SettingsService settings) {
    final regions = [
      'India',
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'Germany',
      'France',
      'Spain',
      'Italy',
      'Japan',
      'South Korea',
      'Russia'
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          title: const Text(
            'Select Region',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900),
          ),
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
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    HapticService.vibrate(NovynHapticType.medium);
                    settings.setRegion(region);
                    Navigator.pop(dialogContext);
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
      message:
          'Novyn uses the time zone configured on your device. To change it, open Android Settings → System → Date & time.',
    );
  }

  void _showDateFormatDialog(BuildContext context) {
    _showDeviceFormatInfo(
      context,
      title: 'Date format',
      message:
          'Novyn currently follows your device language and regional settings for dates. Custom date formats are not available yet.',
    );
  }

  void _showNumberFormatDialog(BuildContext context) {
    _showDeviceFormatInfo(
      context,
      title: 'Number format',
      message:
          'Novyn currently follows your device locale for number formatting. Custom number formats are not available yet.',
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ScreenHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Material(
            color: dark ? const Color(0xFF161726) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticService.vibrate(NovynHapticType.light);
                onBack();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.arrow_back_rounded, color: ink, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _LanguageHeroCard extends StatelessWidget {
  final String regionFlag;
  final String regionName;
  final String languageName;

  const _LanguageHeroCard({
    required this.regionFlag,
    required this.regionName,
    required this.languageName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF29234B), const Color(0xFF172D3A)]
              : [const Color(0xFFECE9FF), const Color(0xFFE4F7F5)],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DFC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D5DFC).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.language_rounded, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? colors.surface.withValues(alpha: 0.85) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                    SizedBox(width: 5),
                    Text(
                      'Saved automatically',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Make Novyn feel local',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose the language you prefer and how dates and times appear.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroChip(
                leading: Text(regionFlag, style: const TextStyle(fontSize: 16)),
                label: regionName,
              ),
              const SizedBox(width: 10),
              _HeroChip(
                leading: const Icon(
                  Icons.translate_rounded,
                  size: 15,
                  color: Color(0xFF6D5DFC),
                ),
                label: languageName,
                labelColor: const Color(0xFF6D5DFC),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final Widget leading;
  final String label;
  final Color? labelColor;

  const _HeroChip({
    required this.leading,
    required this.label,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? colors.surface.withValues(alpha: 0.85) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: labelColor ?? colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _PreferenceRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.vibrate(NovynHapticType.selection);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;

  const _PillBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6D5DFC),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
