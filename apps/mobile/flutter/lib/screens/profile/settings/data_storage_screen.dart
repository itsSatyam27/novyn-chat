import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 36),
        physics: const BouncingScrollPhysics(),
        children: [
          _DataScreenHeader(),
          const SizedBox(height: 22),
          _DataSummaryCard(usageKey: _usageRefreshKey),
          const SectionLabel(label: 'Storage'),
          _ActionCard(
            icon: Icons.delete_sweep_rounded,
            color: const Color(0xFFEF5350),
            title: 'Clear Cache',
            subtitle: 'Remove temporary files and cached images',
            trailing: _clearingCache
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _clearingCache ? null : _confirmClearCache,
          ),
          const SizedBox(height: 22),
          const SectionLabel(label: 'Automatic downloads'),
          _PreferenceChoiceCard(
            icon: Icons.wifi_rounded, color: const Color(0xFF06B6D4),
            title: 'Wi-Fi Networks',
            selectedValue: _downloadLabel(settings.autoDownloadWifi, photosLabel: 'Photos only'),
            detail: 'Preferred media download policy',
            onTap: () => _showDownloadChoice(settings, isWifi: true),
          ),
          _PreferenceChoiceCard(
            icon: Icons.cell_tower_rounded, color: const Color(0xFFF59E0B),
            title: 'Mobile data',
            selectedValue: _downloadLabel(settings.autoDownloadMobile, photosLabel: 'Photos only'),
            detail: 'Preferred media download policy',
            onTap: () => _showDownloadChoice(settings, isWifi: false),
          ),
          const SizedBox(height: 22),
          const SectionLabel(label: 'Media quality'),
          _PreferenceChoiceCard(
            icon: Icons.high_quality_rounded, color: const Color(0xFF10B981),
            title: 'Media quality',
            selectedValue: _qualityLabel(settings.photoQuality),
            detail: 'Choose your preferred upload quality',
            onTap: () => _showQualityChoice(settings),
          ),
          const SizedBox(height: 22),
          const SectionLabel(label: 'Storage usage'),
          _StorageUsageCard(
            key: ValueKey(_usageRefreshKey),
            onRefresh: () => setState(() => _usageRefreshKey++),
          ),
          const SizedBox(height: 22),
          const SectionLabel(label: 'Your downloads'),
          _DownloadedFilesCard(refreshKey: _usageRefreshKey,
            onChanged: () => setState(() => _usageRefreshKey++)),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Incoming attachments now follow your Wi-Fi/mobile download policy while Novyn is running. Image uploads use your selected quality. Images and videos can be saved to Gallery; other files can be exported through the system Files picker.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'NOVYN  ·  YOUR SPACE, YOUR PEOPLE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
            ),
          ),
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
    HapticFeedback.mediumImpact();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary cache cleared. Your chats are safe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear cache: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DataScreenHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data & Storage', style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900, letterSpacing: -.6)),
        Text('Downloads, media and storage', style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant)),
      ])),
    ]);
  }
}

class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({required this.usageKey});
  final int usageKey;

  Future<int> _bytes(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final item in directory.list(recursive: true, followLinks: false)) {
      if (item is File) {
        try { total += await item.length(); } on FileSystemException { }
      }
    }
    return total;
  }

  String _format(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<int> _total() async {
    final docs = await getApplicationDocumentsDirectory();
    final temp = await getTemporaryDirectory();
    return await _bytes(docs) + await _bytes(temp);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.outlineVariant)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: .72)]),
            borderRadius: BorderRadius.circular(32)),
          child: const Icon(Icons.storage_rounded, color: Colors.white, size: 30)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Manage your data', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Control automatic downloads, media quality and temporary storage.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 12),
          FutureBuilder<int>(key: ValueKey(usageKey), future: _total(), builder: (context, snap) {
            return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)),
              child: Text('●  ${snap.hasData ? _format(snap.data!) : 'Calculating…'} used on this device',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w800)));
          }),
        ])),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CardShell(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconTile(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadedFilesCard extends StatefulWidget {
  const _DownloadedFilesCard({required this.refreshKey, required this.onChanged});
  final int refreshKey;
  final VoidCallback onChanged;
  @override
  State<_DownloadedFilesCard> createState() => _DownloadedFilesCardState();
}

class _DownloadedFilesCardState extends State<_DownloadedFilesCard> {
  Future<List<File>> _load() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(docs.path + '/Novyn Downloads');
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final item in dir.list(followLinks: false)) {
      if (item is File) files.add(item);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? (bytes / 1024).toStringAsFixed(1) + ' KB'
      : (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<File>>(
      key: ValueKey(widget.refreshKey), future: _load(),
      builder: (context, snapshot) {
        final files = snapshot.data ?? [];
        Widget content;
        if (snapshot.connectionState == ConnectionState.waiting) {
          content = const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          content = Text('Could not load downloaded files: ' + snapshot.error.toString());
        } else if (files.isEmpty) {
          content = Row(children: [
            Icon(Icons.download_for_offline_outlined, color: theme.colorScheme.onSurfaceVariant, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No downloads yet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('Use Download on a chat attachment to save it here.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ])),
          ]);
        } else {
          content = Column(children: files.map((file) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(file.uri.pathSegments.last, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: FutureBuilder<int>(future: file.length(), builder: (_, size) =>
              Text(size.hasData ? _size(size.data!) : 'Calculating size…')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Open downloaded file',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () async {
                  final opened = await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No app can open this file type.')),
                    );
                  }
                },
              ),
              IconButton(
              tooltip: 'Delete download', icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete downloaded file?'),
                    content: Text(file.uri.pathSegments.last),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await file.delete();
                  if (mounted) setState(() {});
                  widget.onChanged();
                }
              },
              ),
            ]),
          )).toList());
        }
        return _CardShell(child: Padding(padding: const EdgeInsets.all(16), child: content));
      },
    );
  }
}

class _StorageUsageCard extends StatelessWidget {
  final VoidCallback onRefresh;

  const _StorageUsageCard({super.key, required this.onRefresh});

  Future<int> _directoryBytes(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
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
    return {
      'app': await _directoryBytes(documents),
      'temporary': await _directoryBytes(temporary),
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
    final foreground = theme.colorScheme.onSurface;
    return FutureBuilder<Map<String, int>>(
      future: _loadUsage(),
      builder: (context, snapshot) {
        final appBytes = snapshot.data?['app'] ?? 0;
        final temporaryBytes = snapshot.data?['temporary'] ?? 0;
        final total = appBytes + temporaryBytes;
        final appRatio = total == 0 ? 0.0 : appBytes / total;
        final temporaryRatio =
            total == 0 ? 0.0 : temporaryBytes / total;

        return _CardShell(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Storage used on this device',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh storage',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(minHeight: 3),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Storage details are currently unavailable.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  )
                else ...[
                  _UsageRow(
                    label: 'App data & local database',
                    value: _formatBytes(appBytes),
                    ratio: appRatio,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _UsageRow(
                    label: 'Temporary files & cache',
                    value: _formatBytes(temporaryBytes),
                    ratio: temporaryRatio,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total measured usage',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Calculating…'
                            : _formatBytes(total),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Measured from this app’s documents and temporary folders. System-managed cache may vary.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _UsageRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
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
