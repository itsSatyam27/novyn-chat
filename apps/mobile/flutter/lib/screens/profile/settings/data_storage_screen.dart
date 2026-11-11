import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';
import '../../../theme/novyn_theme.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: Text(
          'Data & Storage',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const BouncingScrollPhysics(),
        children: [
          SettingsIntroCard(title: 'Manage your data', subtitle: 'Control automatic downloads, media quality and temporary storage.', icon: Icons.database_rounded),
          const SectionLabel(label: 'Storage'),
          MenuCard(
            icon: Icons.delete_sweep_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            title: 'Clear Cache',
            subtitle: 'Remove temporary files without deleting chats',
            onTap: () => _showClearCacheDialog(context),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Automatic downloads'),
          _SelectionCard(
            icon: Icons.wifi_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Wi-Fi Networks',
            subtitle: 'Choose what downloads automatically on Wi-Fi',
            value: settings.autoDownloadWifi,
            options: const ['all', 'photos', 'none'],
            labels: const ['All Media', 'Photos Only', 'Deactivated'],
            onChanged: (v) => settings.setAutoDownloadWifi(v),
          ),
          _SelectionCard(
            icon: Icons.cell_tower_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'Mobile data',
            subtitle: 'Choose what downloads automatically on mobile data',
            value: settings.autoDownloadMobile,
            options: const ['all', 'photos', 'none'],
            labels: const ['All Media', 'Photos Only', 'Deactivated'],
            onChanged: (v) => settings.setAutoDownloadMobile(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Media quality'),
          _SelectionCard(
            icon: Icons.high_quality_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Media Fidelity',
            subtitle: 'Choose the quality of photos you send',
            value: settings.photoQuality,
            options: const ['high', 'medium', 'low'],
            labels: const ['Ultra (Lossless)', 'Balanced', 'Data Saver'],
            onChanged: (v) => settings.setPhotoQuality(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Storage usage'),
          _StorageInfoCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
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
          title: const Text(
            'Purge Cache?',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900),
          ),
          content: Text(
            'This will clear temporary artifacts and cached nodes. Your encrypted messages will remain intact.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                try {
                  final temp = await getTemporaryDirectory();
                  if (await temp.exists()) {
                    await for (final entity in temp.list(followLinks: false)) {
                      try { await entity.delete(recursive: true); } catch (_) {}
                    }
                  }
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Temporary cache cleared. Chats and account data were kept.'), behavior: SnackBarBehavior.floating),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not clear cache: $error'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: const Text(
                'Purge',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
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
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D5DFC),
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
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                    color: isSelected ? const Color(0xFF6D5DFC) : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected 
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6D5DFC)) 
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
    );
  }
}

class _StorageInfoCard extends StatelessWidget {
  const _StorageInfoCard();

  Future<int> _directoryBytes(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try { total += await entity.length(); } catch (_) {}
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<Map<String, int>> _loadUsage() async {
    final docs = await getApplicationDocumentsDirectory();
    final temp = await getTemporaryDirectory();
    return {
      'app': await _directoryBytes(docs),
      'temporary': await _directoryBytes(temp),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return FutureBuilder<Map<String, int>>(
      future: _loadUsage(),
      builder: (context, snapshot) {
        final usage = snapshot.data;
        final appBytes = usage?['app'] ?? 0;
        final tempBytes = usage?['temporary'] ?? 0;
        final total = appBytes + tempBytes;
        final appRatio = total == 0 ? 0.0 : appBytes / total;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF1A1D2B) : Colors.white,
            border: Border.all(color: foreground.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.storage_rounded, color: foreground),
                const SizedBox(width: 10),
                Text('Storage used on this device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: foreground)),
                const Spacer(),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 18),
              _StorageItem(label: 'App data & local database', size: _formatBytes(appBytes), color: foreground, percentage: appRatio),
              _StorageItem(label: 'Temporary files & cache', size: _formatBytes(tempBytes), color: foreground.withValues(alpha: 0.55), percentage: total == 0 ? 0 : tempBytes / total),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total measured usage', style: TextStyle(fontSize: 13, color: foreground.withValues(alpha: 0.65))),
                Text(snapshot.hasError ? 'Unavailable' : _formatBytes(total), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: foreground)),
              ]),
              const SizedBox(height: 6),
              Text('Measured from this app’s documents and temporary folders. System-managed cache may vary.', style: TextStyle(fontSize: 11, color: foreground.withValues(alpha: 0.5))),
            ],
          ),
        );
      },
    );
  }
}

class _StorageItem extends StatelessWidget {
  final String label;
  final String size;
  final Color color;
  final double percentage;

  const _StorageItem({required this.label, required this.size, required this.color, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: foreground.withValues(alpha: 0.75)))),
          Text(size, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: foreground)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: foreground.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }
}
