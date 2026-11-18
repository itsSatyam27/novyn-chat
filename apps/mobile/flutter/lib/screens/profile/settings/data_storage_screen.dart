import 'dart:io';
import 'dart:ui';
import 'package:novyn/services/haptic_service.dart';

import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../widgets/profile_widgets.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  int _usageRefreshKey = 0;
  bool _clearingCache = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            const _DataStorageHeader(),
            _DeviceStorageCard(
              usageKey: _usageRefreshKey,
              clearingCache: _clearingCache,
              onClearCache: _confirmClearCache,
              onRefresh: () {
                HapticService.vibrate(NovynHapticType.light);
                setState(() => _usageRefreshKey++);
              },
            ),
            const SizedBox(height: 22),
            _sectionHeading('Automatic downloads', context),
            _groupedCard(
              context,
              children: [
                _PreferenceDropdownRow(
                  icon: Icons.wifi_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: const Color(0xFFE0F7F4),
                  title: 'Wi-Fi Networks',
                  subtitle: 'Preferred media download policy',
                  value: _downloadLabel(settings.autoDownloadWifi, photosLabel: 'Photos only'),
                  onTap: () => _showDownloadChoice(settings, isWifi: true),
                ),
                _PreferenceDropdownRow(
                  icon: Icons.cell_tower_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEF3E2),
                  title: 'Mobile data',
                  subtitle: 'Preferred media download policy',
                  value: _downloadLabel(settings.autoDownloadMobile, photosLabel: 'Photos only'),
                  onTap: () => _showDownloadChoice(settings, isWifi: false),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionHeading('Media quality', context),
            _groupedCard(
              context,
              children: [
                _PreferenceDropdownRow(
                  icon: Icons.high_quality_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFE8F8F0),
                  title: 'Media quality',
                  subtitle: 'Choose your preferred upload quality',
                  value: _qualityLabel(settings.photoQuality),
                  onTap: () => _showQualityChoice(settings),
                  isHighQuality: true,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionHeading('Downloads', context),
            _groupedCard(
              context,
              children: [
                _NavigationRow(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF6D5DFC),
                  iconBgColor: const Color(0xFFEDE9FE),
                  title: 'Your downloads',
                  subtitle: 'View, open and manage downloaded files',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YourDownloadsScreen()),
                  ).then((_) {
                    if (mounted) setState(() => _usageRefreshKey++);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _InfoNoticeCard(),
            const SizedBox(height: 24),
            const _FooterBrandText(),
          ],
        ),
      ),
    );
  }

  String _downloadLabel(String value, {required String photosLabel}) {
    switch (value) {
      case 'all':
        return 'All media';
      case 'photos':
        return photosLabel;
      case 'none':
        return 'Deactivated';
      default:
        return 'Not set';
    }
  }

  String _qualityLabel(String value) {
    switch (value) {
      case 'high':
        return 'Ultra quality';
      case 'medium':
        return 'Balanced';
      case 'low':
        return 'Data saver';
      default:
        return 'Not set';
    }
  }

  Future<void> _showDownloadChoice(SettingsService settings, {required bool isWifi}) async {
    final current = isWifi ? settings.autoDownloadWifi : settings.autoDownloadMobile;
    final selected = await showModalBottomSheet<String>(
      context: context, useSafeArea: true, showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isWifi ? 'Wi-Fi downloads' : 'Mobile data downloads',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('New incoming attachments are downloaded automatically when Novyn is connected and the selected network policy allows it.'),
            const SizedBox(height: 12),
            for (final option in ['all', 'photos', 'none'])
              RadioListTile<String>(
                value: option, groupValue: current,
                title: Text(option == 'all' ? 'All media' : option == 'photos' ? 'Photos only' : 'Off'),
                onChanged: (value) => Navigator.pop(sheetContext, value),
                contentPadding: EdgeInsets.zero,
              ),
          ]),
        ),
      ),
    );
    if (selected == null) return;
    if (isWifi) {
      await settings.setAutoDownloadWifi(selected);
    } else {
      await settings.setAutoDownloadMobile(selected);
    }
  }

  Future<void> _showQualityChoice(SettingsService settings) async {
    final selected = await showModalBottomSheet<String>(
      context: context, useSafeArea: true, showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Media quality', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final option in ['high', 'medium', 'low'])
              RadioListTile<String>(
                value: option, groupValue: settings.photoQuality,
                title: Text(option == 'high' ? 'High quality' : option == 'medium' ? 'Balanced' : 'Data saver'),
                subtitle: Text(option == 'high' ? 'Best detail, larger files' : option == 'medium' ? 'Balanced size and clarity' : 'Smaller files, saves data'),
                onChanged: (value) => Navigator.pop(sheetContext, value),
                contentPadding: EdgeInsets.zero,
              ),
          ]),
        ),
      ),
    );
    if (selected != null) await settings.setPhotoQuality(selected);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: Theme.of(dialogContext).colorScheme.outlineVariant,
            ),
          ),
          title: const Text('Clear temporary cache?'),
          content: const Text(
            'This removes files from Novyn’s temporary folder and clears cached images. Your chats, account and saved settings will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear cache'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _clearingCache = true);
    HapticService.vibrate(NovynHapticType.medium);

    try {
      final temporaryDirectory = await getTemporaryDirectory();
      if (await temporaryDirectory.exists()) {
        await for (final entity
            in temporaryDirectory.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            // Skip files currently held by the operating system.
          }
        }
      }

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      setState(() {
        _clearingCache = false;
        _usageRefreshKey++;
      });
      context.showNovynAlert(
        const SnackBar(
          content: Text('Temporary cache cleared. Your chats are safe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _clearingCache = false);
      context.showNovynAlert(
        SnackBar(
          content: Text('Could not clear cache: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DataStorageHeader extends StatelessWidget {
  const _DataStorageHeader();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final border = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: dark ? const Color(0xFF161726) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
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
                    'Data & Storage',
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
          const SizedBox(height: 12),
          Text(
            'Downloads, media and storage',
            style: TextStyle(
              color: muted,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStorageCard extends StatelessWidget {
  final int usageKey;
  final bool clearingCache;
  final VoidCallback onClearCache;
  final VoidCallback onRefresh;

  const _DeviceStorageCard({
    required this.usageKey,
    required this.clearingCache,
    required this.onClearCache,
    required this.onRefresh,
  });

  Future<int> _directoryBytes(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Ignore files that disappear or become inaccessible mid-scan.
        }
      }
    }
    return total;
  }

  Future<Map<String, int>> _loadUsage() async {
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await getTemporaryDirectory();
    final appBytes = await _directoryBytes(documents);
    final temporaryBytes = await _directoryBytes(temporary);
    return {
      'app': appBytes,
      'temporary': temporaryBytes,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ink = colors.onSurface;
    final muted = colors.onSurfaceVariant;

    return FutureBuilder<Map<String, int>>(
      key: ValueKey(usageKey),
      future: _loadUsage(),
      builder: (context, snapshot) {
        final appBytes = snapshot.data?['app'] ?? 0;
        final temporaryBytes = snapshot.data?['temporary'] ?? 0;
        final total = appBytes + temporaryBytes;

        final isReady = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
        final totalFormatted = isReady ? _formatBytes(total) : '2.8 MB';
        final totalParts = totalFormatted.split(' ');
        final numberText = totalParts.first;
        final unitText = totalParts.length > 1 ? totalParts.last : 'MB';

        // Calculate progress bar fractions
        final appRatio = (total == 0) ? 0.48 : (appBytes / total).clamp(0.05, 0.95);
        final tempRatio = (total == 0) ? 0.50 : (temporaryBytes / total).clamp(0.05, 0.95);

        final appFlex = (appRatio * 100).round().clamp(5, 95);
        final tempFlex = (tempRatio * 100).round().clamp(5, 95);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: USED ON THIS DEVICE & Refresh button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USED ON THIS DEVICE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              numberText,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: ink,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              unitText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ink.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: colors.primary.withValues(alpha: dark ? 0.20 : 0.09),
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Multi-segment storage bar
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 9,
                  color: dark ? const Color(0xFF232236) : const Color(0xFFECE8F7),
                  child: Row(
                    children: [
                      Expanded(
                        flex: appFlex,
                        child: Container(color: colors.primary),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: tempFlex,
                        child: Container(color: const Color(0xFF22C55E)),
                      ),
                      const Expanded(
                        flex: 3,
                        child: SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Legend items
              Row(
                children: [
                  Container(
                    width: 7.5,
                    height: 7.5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'App data & local database',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isReady ? _formatBytes(appBytes) : '1.3 MB',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Container(
                    width: 7.5,
                    height: 7.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Temporary files & cache',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isReady ? _formatBytes(temporaryBytes) : '1.4 MB',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Footnote
              Text(
                'Measured from this app\'s documents and temporary folders. System-managed cache may vary.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // Clear Cache Button
              Material(
                color: dark ? const Color(0xFF2C1619) : const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: clearingCache ? null : onClearCache,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark ? const Color(0xFF5A2228) : const Color(0xFFFDD8DC),
                      ),
                    ),
                    child: Center(
                      child: clearingCache
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB3261E)),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cleaning_services_rounded,
                                  color: Color(0xFFB3261E),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Clear cache',
                                  style: TextStyle(
                                    color: Color(0xFFB3261E),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Removes temporary files and cached images',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _sectionHeading(String title, BuildContext context) {
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 9),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: muted,
      ),
    ),
  );
}

Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class _PreferenceDropdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final bool isHighQuality;

  const _PreferenceDropdownRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.isHighQuality = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: dark ? 0.22 : 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isHighQuality
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: iconColor, width: 1.6),
                            borderRadius: BorderRadius.circular(4.5),
                          ),
                          child: Text(
                            'HL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: iconColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 21),
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
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF242042) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: dark ? 0.22 : 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 21),
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
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNoticeCard extends StatelessWidget {
  const _InfoNoticeCard();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF19172E) : const Color(0xFFEDE9FE).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Incoming attachments now follow your Wi-Fi/mobile download policy while Novyn is running. Image uploads use your selected quality. Images and videos can be saved to Gallery; other files can be exported through the system Files picker.',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: dark ? 0.85 : 0.75),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBrandText extends StatelessWidget {
  const _FooterBrandText();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Text(
        'NOVYN · YOUR SPACE, YOUR PEOPLE',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: muted.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

class YourDownloadsScreen extends StatefulWidget {
  const YourDownloadsScreen({super.key});

  @override
  State<YourDownloadsScreen> createState() => _YourDownloadsScreenState();
}

class _YourDownloadsScreenState extends State<YourDownloadsScreen> {
  int _refreshKey = 0;

  Future<List<File>> _load() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Novyn Downloads');
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final item in dir.list(followLinks: false)) {
      if (item is File) files.add(item);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _open(File file) async {
    try {
      final opened = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        context.showNovynAlert(
          const SnackBar(content: Text('No app can open this file type.')),
        );
      }
    } catch (_) {
      if (mounted) {
        context.showNovynAlert(
          const SnackBar(content: Text('Could not open this file.')),
        );
      }
    }
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete downloaded file?'),
        content: Text(file.uri.pathSegments.last),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
      if (mounted) {
        setState(() => _refreshKey++);
        context.showNovynAlert(
          const SnackBar(content: Text('Download deleted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        context.showNovynAlert(
          const SnackBar(content: Text('Could not delete this file.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Your downloads'),
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<File>>(
        key: ValueKey(_refreshKey),
        future: _load(),
        builder: (context, snapshot) {
          final files = snapshot.data ?? [];
          final totalBytes = files.fold<int>(0, (sum, file) {
            try { return sum + file.lengthSync(); } catch (_) { return sum; }
          });
          return RefreshIndicator(
            onRefresh: () async => setState(() => _refreshKey++),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: .16),
                        colors.primary.withValues(alpha: .06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(Icons.folder_rounded,
                            color: colors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Saved on this device',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              snapshot.connectionState == ConnectionState.waiting
                                  ? 'Loading your files…'
                                  : '${files.length} files  ·  ${_size(totalBytes)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh downloads',
                        onPressed: () => setState(() => _refreshKey++),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _CardShell(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Could not load downloaded files. Please try again.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else if (files.isEmpty)
                  _CardShell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 34),
                      child: Column(
                        children: [
                          Icon(Icons.download_for_offline_outlined,
                              size: 48, color: colors.onSurfaceVariant),
                          const SizedBox(height: 14),
                          Text('No downloads yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 6),
                          Text(
                            'Files you download from chat attachments will appear here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _CardShell(
                    child: Column(
                      children: [
                        for (var i = 0; i < files.length; i++) ...[
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(Icons.insert_drive_file_outlined,
                                  color: colors.primary),
                            ),
                            title: Text(
                              files[i].uri.pathSegments.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: FutureBuilder<int>(
                              future: files[i].length(),
                              builder: (_, size) => Text(
                                size.hasData
                                    ? _size(size.data!)
                                    : 'Calculating size…',
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'File actions',
                              onSelected: (action) {
                                if (action == 'open') _open(files[i]);
                                if (action == 'delete') _delete(files[i]);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: ListTile(
                                    leading: Icon(Icons.open_in_new_rounded),
                                    title: Text('Open'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline_rounded),
                                    title: Text('Delete'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i != files.length - 1)
                            Divider(
                              height: 1,
                              indent: 72,
                              color: colors.outlineVariant,
                            ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Downloads are stored locally in Novyn and remain on this device until you delete them.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconTile({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}
