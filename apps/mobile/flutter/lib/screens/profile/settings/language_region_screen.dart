import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';

class LanguageRegionScreen extends StatelessWidget {
  const LanguageRegionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languages = settings.getLanguagesForRegion(settings.region);
    final languageLabel = languages[settings.language] ?? 'English';
    final now = DateTime.now();
    final datePreview = MaterialLocalizations.of(context).formatMediumDate(now);
    final currentTime = TimeOfDay.now();
    final timePreview = settings.timeFormat == '24h'
        ? '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}'
        : currentTime.format(context);
    final numberPreview = settings.region == 'India' ? '1,23,456.78' : '123,456.78';

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Language & Region',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // LANGUAGE & REGION Section
            _sectionHeader('LANGUAGE & REGION'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.translate_rounded,
                    const Color(0xFF8B5CF6),
                    isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  ),
                  title: 'App language',
                  trailing: _trailingValueWithChevron(languageLabel),
                  onTap: () => _showLanguageDialog(context, settings),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.language_rounded,
                    const Color(0xFF0D9488),
                    isDark ? const Color(0xFF1B2E33) : const Color(0xFFE0F7F4),
                  ),
                  title: 'Region',
                  trailing: _trailingValueWithChevron(settings.region),
                  onTap: () => _showRegionDialog(context, settings),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.access_time_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF332717) : const Color(0xFFFEF3E2),
                  ),
                  title: 'Time zone',
                  trailing: _trailingValueWithChevron(_getTimeZoneString()),
                  onTap: () => _showTimezoneDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // FORMATS Section
            _sectionHeader('FORMATS'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.calendar_month_rounded,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                  ),
                  title: 'Date format',
                  trailing: _formatPill(datePreview, isDark),
                  onTap: () => _showDateFormatDialog(context),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.access_time_rounded,
                    const Color(0xFFEC4899),
                    isDark ? const Color(0xFF361F2E) : const Color(0xFFFCE7F3),
                  ),
                  title: 'Time format',
                  trailing: _formatPill(timePreview, isDark),
                  onTap: () => _showTimeFormatOptions(context, settings),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.tag_rounded,
                    const Color(0xFF8B5CF6),
                    isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  ),
                  title: 'Number format',
                  trailing: _formatPill(numberPreview, isDark),
                  onTap: () => _showNumberFormatDialog(context),
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

  static Widget _formatPill(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
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

  String _getTimeZoneString() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    final absHours = hours.abs();
    return 'GMT$sign${absHours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')} (${now.timeZoneName})';
  }

  void _showTimeFormatOptions(BuildContext context, SettingsService settings) {
    HapticService.vibrate(NovynHapticType.selection);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: NovynTheme.cardBg(context),
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
                'Time format',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NovynTheme.textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 14),
              RadioListTile<String>(
                value: '12h',
                groupValue: settings.timeFormat,
                title: const Text('12-hour (e.g. 6:43 PM)'),
                activeColor: Theme.of(context).colorScheme.primary,
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
                activeColor: Theme.of(context).colorScheme.primary,
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
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
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
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
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
