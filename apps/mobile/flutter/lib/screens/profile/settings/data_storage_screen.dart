import 'dart:io';
import 'dart:ui';
import 'package:novyn/services/haptic_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Data & Storage',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            _DeviceStorageCard(
              usageKey: _usageRefreshKey,
              clearingCache: _clearingCache,
              onClearCache: _confirmClearCache,
              onRefresh: () {
                HapticService.vibrate(NovynHapticType.light);
                setState(() => _usageRefreshKey++);
              },
            ),
            const SizedBox(height: 24),

            _sectionHeader('AUTOMATIC DOWNLOADS'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.wifi_rounded,
                    const Color(0xFF0D9488),
                    isDark ? const Color(0xFF1B3330) : const Color(0xFFE0F7F4),
                  ),
                  title: 'Wi-Fi Networks',
                  trailing: _pillDropdown(
                    text: _downloadLabel(settings.autoDownloadWifi, photosLabel: 'Photos only'),
                    onTap: () => _showDownloadChoice(settings, isWifi: true),
                    context: context,
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.cell_tower_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF382A1B) : const Color(0xFFFEF3E2),
                  ),
                  title: 'Mobile data',
                  trailing: _pillDropdown(
                    text: _downloadLabel(settings.autoDownloadMobile, photosLabel: 'Photos only'),
                    onTap: () => _showDownloadChoice(settings, isWifi: false),
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _sectionHeader('MEDIA QUALITY'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    null,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                    customIcon: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'HL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: 'Media quality',
                  trailing: _pillDropdown(
                    text: _qualityLabel(settings.photoQuality),
                    onTap: () => _showQualityChoice(settings),
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _sectionHeader('DOWNLOADS'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.arrow_downward_rounded,
                    Theme.of(context).colorScheme.primary,
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Your downloads',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YourDownloadsScreen()),
                  ).then((_) {
                    if (mounted) setState(() => _usageRefreshKey++);
                  }),
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

  static Widget _iconBox(IconData? icon, Color color, Color bg, {Widget? customIcon}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: customIcon ?? Icon(icon, color: color, size: 21),
    );
  }

  static Widget _pillDropdown({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticService.vibrate(NovynHapticType.selection);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2849) : const Color(0xFFECE9FB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
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
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: NovynTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWifi ? 'Wi-Fi downloads' : 'Mobile data downloads',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('New incoming attachments are downloaded automatically when Novyn is connected and the selected network policy allows it.'),
              const SizedBox(height: 12),
              for (final option in ['all', 'photos', 'none'])
                RadioListTile<String>(
                  value: option,
                  groupValue: current,
                  title: Text(option == 'all' ? 'All media' : option == 'photos' ? 'Photos only' : 'Off'),
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
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
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: NovynTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Media quality',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final option in ['high', 'medium', 'low'])
                RadioListTile<String>(
                  value: option,
                  groupValue: settings.photoQuality,
                  title: Text(option == 'high' ? 'High quality' : option == 'medium' ? 'Balanced' : 'Data saver'),
                  subtitle: Text(option == 'high' ? 'Best detail, larger files' : option == 'medium' ? 'Balanced size and clarity' : 'Smaller files, saves data'),
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
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
        await for (final entity in temporaryDirectory.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            // Skip files held by OS
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

class _DeviceStorageCard extends StatelessWidget {
  static const MethodChannel _storageChannel = MethodChannel('com.example.novyn/storage');

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
          // ignore
        }
      }
    }
    return total;
  }

  Future<Map<String, int>> _loadUsage() async {
    if (Platform.isAndroid) {
      final nativeUsage = await _storageChannel.invokeMapMethod<String, dynamic>('getStorageUsage');
      if (nativeUsage != null) {
        return {
          'installed': (nativeUsage['installed'] as num?)?.toInt() ?? 0,
          'app': (nativeUsage['appData'] as num?)?.toInt() ?? 0,
          'temporary': (nativeUsage['cache'] as num?)?.toInt() ?? 0,
        };
      }
    }

    // Non-Android fallback: count the app's accessible persistent and temporary files.
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await getTemporaryDirectory();
    return {
      'installed': 0,
      'app': await _directoryBytes(documents),
      'temporary': await _directoryBytes(temporary),
    };
  }

  Widget _storageLegendRow({
    required Color color,
    required String label,
    required String value,
    required Color ink,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
        ),
      ],
    );
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    final cardBg = dark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = dark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);

    return FutureBuilder<Map<String, int>>(
      key: ValueKey(usageKey),
      future: _loadUsage(),
      builder: (context, snapshot) {
        final installedBytes = snapshot.data?['installed'] ?? 0;
        final appBytes = snapshot.data?['app'] ?? 0;
        final temporaryBytes = snapshot.data?['temporary'] ?? 0;
        final total = installedBytes + appBytes + temporaryBytes;

        final isReady = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
        final totalFormatted = isReady ? _formatBytes(total) : 'Calculating';
        final totalParts = totalFormatted.split(' ');
        final numberText = totalParts.first;
        final unitText = totalParts.length > 1 ? totalParts.last : 'KB';

        final installedFlex = total == 0 ? 1 : (installedBytes / total * 1000).round().clamp(1, 1000);
        final appFlex = total == 0 ? 1 : (appBytes / total * 1000).round().clamp(1, 1000);
        final tempFlex = total == 0 ? 1 : (temporaryBytes / total * 1000).round().clamp(1, 1000);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        const Text(
                          'USED ON THIS DEVICE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF646078),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              numberText,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unitText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ink.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRefresh,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Segmented bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 7,
                  child: Row(
                    children: [
                      Expanded(
                        flex: installedFlex,
                        child: Container(color: const Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        flex: appFlex,
                        child: Container(color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        flex: tempFlex,
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              _storageLegendRow(
                color: const Color(0xFFF59E0B),
                label: 'Installed app (APK)',
                value: isReady ? _formatBytes(installedBytes) : '—',
                ink: ink,
              ),
              const SizedBox(height: 10),
              _storageLegendRow(
                color: Theme.of(context).colorScheme.primary,
                label: 'App data & local database',
                value: isReady ? _formatBytes(appBytes) : '—',
                ink: ink,
              ),
              const SizedBox(height: 10),
              _storageLegendRow(
                color: const Color(0xFF10B981),
                label: 'Temporary files & cache',
                value: isReady ? _formatBytes(temporaryBytes) : '—',
                ink: ink,
              ),
              const SizedBox(height: 8),
              Text(
                'Installed size includes the base and split APK files. Android may report a different total because it also accounts for optimized system files.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: ink.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 18),

              // Clear Cache Button
              Material(
                color: dark ? const Color(0xFF33191B) : const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: clearingCache ? null : onClearCache,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark ? const Color(0xFF5A2228) : const Color(0xFFFFD4D4),
                      ),
                    ),
                    child: Center(
                      child: clearingCache
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cleaning_services_rounded,
                                  color: Color(0xFFD32F2F),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Clear cache',
                                  style: TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
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
                        icon: Icon(Icons.refresh_rounded),
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
