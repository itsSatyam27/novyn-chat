import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../theme/novyn_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/app_update_service.dart';

const _installerChannel = MethodChannel('com.example.novyn/apk_installer');
const _appSupportEmail = 'novynchat.app@gmail.com';


class AboutNovynScreen extends StatefulWidget {
  const AboutNovynScreen({super.key});
  @override
  State<AboutNovynScreen> createState() => _AboutNovynScreenState();
}

class _AboutNovynScreenState extends State<AboutNovynScreen> {
  bool _checking = true, _downloading = false, _installing = false;
  bool _readySheetOpen = false, _readySheetDismissed = false;
  String? _status, _apkUrl, _expectedSha256, _downloadedApkPath, _releaseName;
  List<String> _releaseNotes = const [];
  int? _apkSize;
  int _installedBuild = 0, _latestBuild = 0;
  double _downloadProgress = 0;
  DateTime? _lastProgressAt;
  int _lastProgressBytes = 0;
  double _downloadSpeedBytesPerSecond = 0;
  String _appVersion = AppUpdateService.displayVersion, _buildNumber = '0';
  final AppUpdateService _updateService = AppUpdateService.instance;

  bool get _paused => !_ready && !_downloading &&
      (_updateService.isPaused || _updateService.hasPartialDownload);
  bool get _available => _latestBuild > _installedBuild;
  bool get _ready => _downloadedApkPath != null;

  @override
  void initState() {
    super.initState();
    _updateService.addListener(_handleDownloadStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForUpdates();
    });
  }

  void _handleDownloadStateChanged() {
    if (!mounted) return;
    final now = DateTime.now();
    final bytes = _updateService.downloadedBytes;
    if (_updateService.isDownloading) {
      final previousAt = _lastProgressAt;
      if (previousAt != null) {
        final elapsed = now.difference(previousAt).inMilliseconds / 1000;
        final received = bytes - _lastProgressBytes;
        if (elapsed > 0 && received >= 0) {
          _downloadSpeedBytesPerSecond = received / elapsed;
        }
      }
      _lastProgressAt = now;
      _lastProgressBytes = bytes;
    } else {
      _lastProgressAt = null;
      _lastProgressBytes = bytes;
      _downloadSpeedBytesPerSecond = 0;
    }

    final previousPath = _downloadedApkPath;
    setState(() {
      _downloading = _updateService.isDownloading;
      _downloadProgress = _updateService.downloadProgress;
      _downloadedApkPath = _updateService.downloadedApkPath;
      if (_updateService.downloadError != null) {
        _status = _updateService.downloadError;
      } else if (_downloadedApkPath != null) {
        _status = 'Verified update ready to install.';
      } else if (_downloading) {
        _status = null;
      } else if (_updateService.isPaused) {
        _status = 'Download paused. Your progress is saved.';
      } else {
        _status = null;
      }
    });

    if (_downloadedApkPath != null &&
        previousPath == null &&
        !_readySheetDismissed &&
        !_readySheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateReadySheet();
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (mounted) {
      setState(() {
        _checking = true;
        _status = null;
        _latestBuild = 0;
        _apkUrl = null;
        _expectedSha256 = null;
        _apkSize = null;
        _releaseName = null;
        _releaseNotes = const [];
      });
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
          _buildNumber = packageInfo.buildNumber;
          _appVersion = AppUpdateService.displayVersion;
        });
      }
      final result = await _updateService.checkForUpdates();
      if (!mounted) return;
      _installedBuild = result.installedBuild;
      _appVersion = AppUpdateService.displayVersion;
      _buildNumber = result.buildNumber;
      final release = result.release;
      if (release != null) {
        _latestBuild = release.build;
        _apkUrl = release.url;
        _expectedSha256 = release.sha256;
        _apkSize = release.size;
        _releaseName = release.name.isNotEmpty ? release.name : 'Build ${release.build}';
        _releaseNotes = release.notes;
      }
      setState(() {
        _status = result.release != null ? null : result.message;
        _checking = false;
      });
      _handleDownloadStateChanged();
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not verify updates. Check your connection and try again.';
          _checking = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    _readySheetDismissed = false;
    await _updateService.downloadUpdate();
  }

  Future<void> _pauseUpdate() async {
    await _updateService.pauseDownload();
  }

  Future<void> _cancelUpdate() async {
    await _updateService.cancelDownload();
  }

  Future<void> _installUpdate() async {
    final path = _downloadedApkPath;
    if (path == null) return;
    setState(() => _installing = true);
    try {
      final allowed = await _installerChannel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!allowed) {
        await _installerChannel.invokeMethod<void>('openInstallPermissionSettings');
        if (mounted) {
          setState(() => _status = 'Allow Novyn to install updates, then tap Install update again.');
        }
        return;
      }
      await _installerChannel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException {
      if (mounted) setState(() => _status = 'Could not open Android installer. Please try again.');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _showUpdateReadySheet() async {
    if (!mounted || _readySheetOpen || _downloadedApkPath == null) return;
    _readySheetOpen = true;
    final install = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        final sizeMb = ((_apkSize ?? _updateService.expectedBytes) / 1000000)
            .toStringAsFixed(1);
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D3EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.install_mobile_rounded,
                    color: Color(0xFF7048F8), size: 30),
                ),
                const SizedBox(height: 12),
                const Text('Update ready to install',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF1D1B2B), fontSize: 20,
                    letterSpacing: -.4, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${_releaseName ?? 'New update'} · $sizeMb MB',
                  style: const TextStyle(color: Color(0xFF777487), fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F3FC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _UpdateNote(text: 'Faster chat loading'),
                      SizedBox(height: 7),
                      _UpdateNote(text: 'Better call quality'),
                      SizedBox(height: 7),
                      _UpdateNote(text: 'Bug fixes'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8052FF), Color(0xFF6741F4)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(
                        color: Color(0x337048F8), blurRadius: 16,
                        offset: Offset(0, 5))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(sheetContext).pop(true),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.install_mobile_rounded,
                              color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Install update', style: TextStyle(
                              color: Colors.white, fontSize: 14.5,
                              fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Later', style: TextStyle(
                    color: Color(0xFF777487), fontSize: 14,
                    fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                const Text('Novyn will restart after installing',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF777487), fontSize: 12.5)),
              ],
            ),
          ),
        );
      },
    );
    _readySheetOpen = false;
    _readySheetDismissed = true;
    if (!mounted) return;
    if (install == true) await _installUpdate();
  }

  @override
  void dispose() {
    _updateService.removeListener(_handleDownloadStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = dark ? NovynTheme.pageBg(context) : const Color(0xFFF5F1FF);
    final ink = dark ? const Color(0xFFF0EFFF) : const Color(0xFF1D1B2B);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF777487);
    final surface = dark ? const Color(0xFF171622) : Colors.white;
    final border = dark ? const Color(0xFF39345F) : const Color(0xFFE5DFFF);
    final primary = const Color(0xFF7048F8);
    final updateName = _releaseName ?? 'Build $_latestBuild';
    final updateNotes = _releaseNotes.isEmpty
        ? <String>['Build $_latestBuild is ready to download.']
        : _releaseNotes;
    final activeDownload = !_ready &&
        (_downloading || _paused || _updateService.hasPartialDownload);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Material(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
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
                    child: Text('About Novyn', style: TextStyle(color: ink,
                      fontSize: 17, letterSpacing: -.3, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 42),
              ]),
              const SizedBox(height: 12),
              Center(
                child: Column(children: [
                  Image.asset(
                    'assets/icons/novyn-badge.png',
                    width: 68,
                    height: 68,
                    semanticLabel: 'Novyn',
                  ),
                  const SizedBox(height: 8),
                  Text('Novyn', style: TextStyle(color: ink, fontSize: 26,
                    letterSpacing: -.6, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Your space, your people.',
                    style: TextStyle(color: muted, fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: border),
                    ),
                    child: Text('Version $_appVersion',
                      style: TextStyle(color: ink, fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border.withValues(alpha: .65)),
                  boxShadow: const [BoxShadow(
                    color: Color(0x0D5038A0), blurRadius: 16,
                    offset: Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.download_rounded,
                          color: Color(0xFF7048F8), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _checking ? 'Checking for updates' :
                                _ready ? 'Update downloaded' :
                                  _paused ? 'Download paused' :
                                    _downloading ? 'Downloading update' :
                                      _available ? 'Update available' :
                                        (!_checking && _status != null &&
                                          !_status!.toLowerCase().contains('up to date')
                                          ? 'Could not check for updates' : 'You are up to date'),
                              style: TextStyle(color: ink, fontSize: 16,
                                letterSpacing: -.2, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(
                              _available ? updateName :
                                _checking ? 'Looking for the latest version' :
                                (!_available && _status != null &&
                                  !_status!.toLowerCase().contains('up to date')
                                  ? _status! : 'Novyn is running the latest version'),
                              style: TextStyle(color: muted, fontSize: 12.5,
                                fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ]),
                    if (activeDownload) ...[
                      const SizedBox(height: 12),
                      _LiquidDownloadProgress(
                        progress: _downloadProgress,
                        downloadedBytes: _updateService.downloadedBytes,
                        totalBytes: _apkSize ?? _updateService.expectedBytes,
                        speedBytesPerSecond: _downloadSpeedBytesPerSecond,
                        paused: _paused,
                        primary: primary,
                        muted: muted,
                      ),
                      const SizedBox(height: 12),
                    ] else if (_ready) ...[
                      const SizedBox(height: 10),
                      Text('Your update is verified and ready to install.',
                        style: TextStyle(color: muted, fontSize: 13, height: 1.35)),
                      const SizedBox(height: 12),
                    ] else if (_status != null && !_checking && !_available) ...[
                      const SizedBox(height: 10),
                      Text(_status!, style: TextStyle(color: muted,
                        fontSize: 12.5, height: 1.35)),
                    ],
                    if (activeDownload) ...[
                      Row(children: [
                        Expanded(
                          child: _updateAction(
                            label: _paused ? 'Resume' : 'Pause',
                            icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            background: const Color(0xFFEDE7FF),
                            foreground: const Color(0xFF6542E8),
                            onTap: _paused ? _downloadUpdate : _pauseUpdate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _updateAction(
                            label: 'Cancel',
                            icon: Icons.close_rounded,
                            background: const Color(0xFFFFEBEC),
                            foreground: const Color(0xFFD22B3A),
                            onTap: _cancelUpdate,
                          ),
                        ),
                      ]),
                    ] else if (_ready) ...[
                      _primaryUpdateButton(
                        label: 'Install update',
                        icon: Icons.install_mobile_rounded,
                        onTap: _installing ? null : _installUpdate,
                      ),
                    ] else if (_available) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF211D32) : const Color(0xFFF6F3FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WHAT’S NEW', style: TextStyle(
                              color: muted, fontSize: 10.5,
                              letterSpacing: .8, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            ...updateNotes.map((note) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: _UpdateNote(text: note),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _primaryUpdateButton(
                        label: _updateService.hasPartialDownload ? 'Resume download' : 'Download update',
                        icon: Icons.download_rounded,
                        onTap: _checking ? null : _downloadUpdate,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text('Later', style: TextStyle(color: muted,
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                    ] else ...[
                      _primaryUpdateButton(
                        label: _checking ? 'Checking for updates' :
                          (_status?.toLowerCase().contains('up to date') == true
                            ? 'Check for updates' : 'Try again'),
                        icon: _checking ? Icons.sync_rounded : Icons.refresh_rounded,
                        onTap: _checking ? null : _checkForUpdates,
                      ),
                    ],
                    if (_status != null && (_available || _ready)) ...[
                      const SizedBox(height: 8),
                      Text(_status!, textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 11.5, height: 1.3)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _infoCard(context, [
                _InfoRow(label: 'App version', value: '$_appVersion (build $_buildNumber)'),
                Divider(height: 1, color: border.withValues(alpha: .8)),
                const _InfoRow(label: 'Platform', value: 'Flutter · Android'),
              ]),
              const SizedBox(height: 12),
              Center(child: Text('MADE TO KEEP YOUR PEOPLE CLOSE',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11,
                  letterSpacing: 1.2, fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _updateAction({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required Future<void> Function() onTap,
  }) {
    return SizedBox(
      height: 44,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 16),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: foreground,
                fontSize: 13.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryUpdateButton({
    required String label,
    required IconData icon,
    required Future<void> Function()? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? const [Color(0xFF8052FF), Color(0xFF6741F4)]
                : const [Color(0xFFB7A7ED), Color(0xFFA895E8)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? const [BoxShadow(
                  color: Color(0x337048F8), blurRadius: 18,
                  offset: Offset(0, 6))]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap == null ? null : () => onTap(),
            borderRadius: BorderRadius.circular(18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white.withValues(alpha: enabled ? 1 : .8), size: 19),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white,
                fontSize: 14.5, letterSpacing: .1, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF39345F) : const Color(0xFFE5DFFF)),
    ),
    child: Column(children: children),
  );
}

class _UpdateNote extends StatelessWidget {
  const _UpdateNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
    const Icon(Icons.circle, color: Color(0xFF8052FF), size: 6),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(
      color: Color(0xFF39364D), fontSize: 13.5, fontWeight: FontWeight.w500))),
  ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          color: dark ? const Color(0xFFAAA8C6) : const Color(0xFF5D5A85),
          fontSize: 13, fontWeight: FontWeight.w500))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: dark ? const Color(0xFFF0EFFF) : const Color(0xFF1E1B49),
            fontSize: 13, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}


class _LiquidDownloadProgress extends StatefulWidget {
  const _LiquidDownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.paused,
    required this.primary,
    required this.muted,
  });
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final bool paused;
  final Color primary;
  final Color muted;

  @override
  State<_LiquidDownloadProgress> createState() => _LiquidDownloadProgressState();
}

class _LiquidDownloadProgressState extends State<_LiquidDownloadProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  @override
  void initState() {
    super.initState();
    _wave = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1700))..repeat();
  }
  @override
  void dispose() { _wave.dispose(); super.dispose(); }

  String _mb(int bytes) => (bytes / 1000000).toStringAsFixed(1);
  String _eta() {
    final remaining = (widget.totalBytes - widget.downloadedBytes)
        .clamp(0, widget.totalBytes);
    if (widget.paused || widget.totalBytes <= 0 ||
        widget.speedBytesPerSecond <= 0) {
      return '0:00';
    }
    final seconds = (remaining / widget.speedBytesPerSecond)
        .ceil().clamp(0, 86400);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${(seconds ~/ 60)}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress.clamp(0.0, 1.0) * 100).round();
    final speed = widget.speedBytesPerSecond <= 0
        ? '0 KB/s'
        : widget.speedBytesPerSecond >= 1000000
            ? '${(widget.speedBytesPerSecond / 1000000).toStringAsFixed(1)} MB/s'
            : '${(widget.speedBytesPerSecond / 1000).toStringAsFixed(1)} KB/s';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _wave,
          builder: (context, child) {
            final phase = _wave.value * 2 * math.pi;
            final progress = widget.progress.clamp(0.0, 1.0).toDouble();
            return SizedBox(
              width: 104,
              height: 104,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: widget.primary.withValues(alpha: .13)),
                    CustomPaint(painter: _LiquidWavePainter(
                      progress: progress, phase: phase, color: widget.primary)),
                    Center(
                      child: Text('$pct%', style: TextStyle(
                        color: widget.primary, fontSize: 25,
                        fontWeight: FontWeight.w900, letterSpacing: -1)),
                    ),
                    ClipPath(
                      clipper: _LiquidWaveClipper(progress: progress, phase: phase),
                      child: Center(
                        child: Text('$pct%', style: const TextStyle(
                          color: Colors.white, fontSize: 25,
                          fontWeight: FontWeight.w900, letterSpacing: -1)),
                      ),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: widget.primary.withValues(alpha: .24),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_mb(widget.downloadedBytes)} of ${_mb(widget.totalBytes)} MB',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.2)),
              const SizedBox(height: 8),
              Text(
                widget.paused ? 'Download paused' : '$speed · ${_eta()}',
                textAlign: TextAlign.start,
                style: TextStyle(color: widget.muted, fontSize: 12.5,
                  fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiquidWavePainter extends CustomPainter {
  const _LiquidWavePainter({required this.progress,required this.phase,
    required this.color});
  final double progress,phase;
  final Color color;
  Path _path(Size size) {
    if(progress>=1) return Path()..addRect(Offset.zero&size);
    final level=size.height*(1-progress);
    final path=Path()..moveTo(0,level);
    for(double x=0;x<=size.width;x+=2){
      final y=level+math.sin((x/size.width*2*math.pi)+phase)*4.5;
      path.lineTo(x,y);
    }
    return path..lineTo(size.width,size.height)
      ..lineTo(0,size.height)..close();
  }
  @override
  void paint(Canvas canvas,Size size){
    if(progress>0) canvas.drawPath(_path(size),Paint()..color=color);
  }
  @override
  bool shouldRepaint(covariant _LiquidWavePainter old)=>old.progress!=progress||
    old.phase!=phase||old.color!=color;
}

class _LiquidWaveClipper extends CustomClipper<Path> {
  const _LiquidWaveClipper({required this.progress,required this.phase});
  final double progress,phase;
  @override
  Path getClip(Size size){
    if(progress<=0) return Path();
    if(progress>=1) return Path()..addRect(Offset.zero&size);
    final level=size.height*(1-progress);
    final path=Path()..moveTo(0,level);
    for(double x=0;x<=size.width;x+=2){
      final y=level+math.sin((x/size.width*2*math.pi)+phase)*4.5;
      path.lineTo(x,y);
    }
    return path..lineTo(size.width,size.height)
      ..lineTo(0,size.height)..close();
  }
  @override
  bool shouldReclip(covariant _LiquidWaveClipper old)=>
    old.progress!=progress||old.phase!=phase;
}

class _HelpEntry {
  const _HelpEntry(this.title, this.subtitle, this.detail, this.icon,
      this.accent, this.kind);
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final Color accent;
  final String kind;
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _expandedFaq = 'How do I back up my chats?';
  final Map<String, bool> _votes = {};

  static const _topics = <_HelpEntry>[
    _HelpEntry('Getting started','Chats, contacts, calls and settings',
      'Start conversations from Chats, find people in Friends, and personalize Novyn from your profile settings.',
      Icons.menu_book_rounded,Color(0xFF8B6DF6),'Help topic'),
    _HelpEntry('Account & privacy','Privacy controls and security',
      'Review your account details, app lock, blocked contacts, presence and privacy controls from Settings.',
      Icons.lock_outline_rounded,Color(0xFF4A956A),'Help topic'),
    _HelpEntry('Chat backup','Create and restore a chat backup',
      'Open Settings → Chat Settings → Chat backup. Create a backup before changing devices, then use Restore when setting up Novyn again.',
      Icons.cloud_upload_outlined,Color(0xFF5488C7),'Help topic'),
    _HelpEntry('Friends & requests','Add people by username',
      'Open Friends, search for a person by their Novyn username, and send a friend request. You can review incoming requests in the same area.',
      Icons.group_outlined,Color(0xFFB45E91),'Help topic'),
    _HelpEntry('Calls & video','Audio and video calling',
      'Open a conversation and use its call controls to start an audio or video call. Check microphone and camera permissions if a call cannot start.',
      Icons.call_outlined,Color(0xFF4C9A91),'Help topic'),
    _HelpEntry('Notifications','Alerts, sounds and Do Not Disturb',
      'Open Settings → Notifications to manage message previews, sounds, vibration and Do Not Disturb preferences.',
      Icons.notifications_none_rounded,Color(0xFFBD8744),'Help topic'),
  ];

  static const _faqs = <_HelpEntry>[
    _HelpEntry('How do I back up my chats?','Popular question',
      'Open Settings → Chat Settings and choose Chat backup. Backups are encrypted, and you can restore them when you set up Novyn again.',
      Icons.description_outlined,Color(0xFF8B6DF6),'Popular question'),
    _HelpEntry('How do I stop screenshots in chats?','Popular question',
      'Open the conversation settings and review the privacy controls available for that chat. Availability can depend on the current app build and device.',
      Icons.description_outlined,Color(0xFF8B6DF6),'Popular question'),
    _HelpEntry('Who can see when I am online?','Popular question',
      'Your presence is shown according to your current presence and privacy settings. Review the privacy controls in Settings for the options available in your build.',
      Icons.description_outlined,Color(0xFF8B6DF6),'Popular question'),
    _HelpEntry('How do I add a friend?','Popular question',
      'Open Friends, search by the person’s Novyn username, and send a friend request.',
      Icons.description_outlined,Color(0xFF8B6DF6),'Popular question'),
  ];

  static const _articles = <_HelpEntry>[
    _HelpEntry('Restore a backup on a new phone','Article',
      'Install Novyn on your new phone, sign in to the same account, open Settings → Chat Settings → Chat backup, and follow the restore flow for your saved backup.',
      Icons.article_outlined,Color(0xFF8B6DF6),'Article'),
  ];

  List<_HelpEntry> get _results {
    final q=_query.trim().toLowerCase();
    if(q.isEmpty) return const [];
    return <_HelpEntry>[..._topics,..._faqs,..._articles].where((e)=>
      e.title.toLowerCase().contains(q) ||
      e.subtitle.toLowerCase().contains(q) ||
      e.detail.toLowerCase().contains(q)).take(8).toList();
  }

  @override
  void dispose(){_searchController.dispose();super.dispose();}

  Future<void> _openIssues({bool newBug=false}) async {
    final uri = newBug
      ? Uri.https('github.com','/itsSatyam27/novyn-chat/issues/new',
          {'title':'Novyn app bug report'})
      : Uri(scheme: 'mailto', path: _appSupportEmail,
          queryParameters: {'subject': 'Novyn support request'});
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted){
      context.showNovynAlert(const SnackBar(content:Text('Could not open the support page.')));
    }
  }

  void _openFeedback()=>Navigator.of(context).push(
    MaterialPageRoute<void>(builder:(_)=>const FeedbackScreen()));

  void _showEntry(_HelpEntry e){
    final dark=Theme.of(context).brightness==Brightness.dark;
    showModalBottomSheet<void>(
      context:context,isScrollControlled:true,backgroundColor:Colors.transparent,
      builder:(sheetContext){
        final surface=dark?const Color(0xFF171622):Colors.white;
        final ink=dark?const Color(0xFFF2F0FF):const Color(0xFF1C1B29);
        final muted=dark?const Color(0xFFAAA7BE):const Color(0xFF6B6880);
        return SafeArea(top:false,child:Container(
          padding:const EdgeInsets.fromLTRB(22,12,22,28),
          decoration:BoxDecoration(color:surface,borderRadius:
            const BorderRadius.vertical(top:Radius.circular(28))),
          child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:
            CrossAxisAlignment.start,children:[
            Center(child:Container(width:42,height:4,decoration:BoxDecoration(
              color:muted.withValues(alpha:.35),borderRadius:BorderRadius.circular(8)))),
            const SizedBox(height:22),
            Row(children:[
              Container(width:46,height:46,decoration:BoxDecoration(
                color:e.accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(15)),
                child:Icon(e.icon,color:e.accent,size:23)),
              const SizedBox(width:12),
              Expanded(child:Text(e.kind.toUpperCase(),style:TextStyle(color:muted,
                fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1))),
              IconButton(onPressed:()=>Navigator.pop(sheetContext),
                icon:Icon(Icons.close_rounded,color:muted)),
            ]),
            const SizedBox(height:12),
            Text(e.title,style:TextStyle(color:ink,fontSize:21,
              fontWeight:FontWeight.w900,letterSpacing:-.45)),
            const SizedBox(height:9),
            Text(e.detail,style:TextStyle(color:muted,fontSize:14,height:1.55)),
            const SizedBox(height:22),
            SizedBox(width:double.infinity,height:48,child:FilledButton(
              onPressed:()=>Navigator.pop(sheetContext),child:const Text('Got it'))),
          ]),
        ));
      },
    );
  }

  Widget _header(Color ink,Color surface,Color border)=>Row(children:[
    Material(color:surface,borderRadius:BorderRadius.circular(15),child:InkWell(
      onTap:()=>Navigator.of(context).maybePop(),borderRadius:BorderRadius.circular(15),
      child:Container(width:44,height:44,decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:border.withValues(alpha:.65))),
        child:Icon(Icons.arrow_back_rounded,color:ink,size:21)))),
    const Expanded(child:Text('Help & Support',textAlign:TextAlign.center,
      style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,letterSpacing:-.25))),
    const SizedBox(width:44),
  ]);

  Widget _search(Color ink,Color muted,Color surface,Color primary)=>Container(
    height:50,
    decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(26),
      boxShadow:[BoxShadow(color:primary.withValues(alpha:.07),
        blurRadius:15,offset:const Offset(0,4))]),
    child:TextField(
      controller:_searchController,
      onChanged:(v)=>setState(()=>_query=v),
      textInputAction:TextInputAction.search,
      style:TextStyle(color:ink,fontSize:14),
      decoration:InputDecoration(
        hintText:'Search help topics',
        hintStyle:TextStyle(color:muted,fontSize:14),
        prefixIcon:Icon(Icons.search_rounded,color:primary,size:21),
        suffixIcon:_query.isEmpty?null:IconButton(
          onPressed:(){_searchController.clear();setState(()=>_query='');},
          icon:Icon(Icons.close_rounded,color:muted,size:20)),
        border:InputBorder.none,
        contentPadding:const EdgeInsets.symmetric(vertical:14),
      ),
    ),
  );

  Widget _action(String title,IconData icon,Color accent,VoidCallback tap,
      {bool external=false}){
    final dark=Theme.of(context).brightness==Brightness.dark;
    final surface=dark?const Color(0xFF191824):Colors.white;
    return Expanded(child:Material(color:surface,borderRadius:BorderRadius.circular(21),
      child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(21),
        child:Container(height:102,padding:const EdgeInsets.fromLTRB(6,10,6,9),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(21),
            border:Border.all(color:Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha:.28)),
            boxShadow:[BoxShadow(color:accent.withValues(alpha:.045),
              blurRadius:12,offset:const Offset(0,4))]),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Container(width:38,height:38,decoration:BoxDecoration(
              color:accent.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),
              child:Icon(icon,color:accent,size:20)),
            const SizedBox(height:7),
            Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              Flexible(child:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:Theme.of(context).colorScheme.onSurface,
                  fontSize:11.5,fontWeight:FontWeight.w900))),
              if(external) ...[const SizedBox(width:3),
                Icon(Icons.open_in_new_rounded,color:accent,size:11)],
            ]),
          ]),
        ),
      ),
    ));
  }

  Widget _section(String title,Color muted)=>Padding(
    padding:const EdgeInsets.only(left:3,bottom:10),
    child:Text(title.toUpperCase(),style:TextStyle(color:muted,fontSize:10.5,
      fontWeight:FontWeight.w900,letterSpacing:1.4)));

  Widget _topicCard(_HelpEntry e,Color ink,Color muted,Color surface)=>Material(
    color:surface,borderRadius:BorderRadius.circular(20),
    child:InkWell(onTap:()=>_showEntry(e),borderRadius:BorderRadius.circular(20),
      child:Container(padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),
          border:Border.all(color:Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha:.25)),
          boxShadow:[BoxShadow(color:e.accent.withValues(alpha:.035),
            blurRadius:12,offset:const Offset(0,3))]),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:34,height:34,decoration:BoxDecoration(
            color:e.accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(11)),
            child:Icon(e.icon,color:e.accent,size:18)),
          const SizedBox(height:8),
          Text(e.title,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:ink,fontSize:12.3,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text(e.subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:muted,fontSize:10.8,height:1.28)),
        ]),
      ),
    ),
  );

  Widget _vote(IconData icon,bool selected,VoidCallback tap)=>Material(
    color:selected?const Color(0xFFEAE4FF):const Color(0xFFF5F3FA),
    borderRadius:BorderRadius.circular(12),
    child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(12),
      child:SizedBox(width:36,height:30,child:Icon(icon,
        color:selected?const Color(0xFF6C4DF6):const Color(0xFF777389),size:16))));

  Widget _faqList(Color ink,Color muted,Color surface,Color border)=>Container(
    decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(22),
      border:Border.all(color:border.withValues(alpha:.45)),
      boxShadow:[BoxShadow(color:const Color(0xFF6C4DF6).withValues(alpha:.045),
        blurRadius:16,offset:const Offset(0,5))]),
    child:Column(children:List.generate(_faqs.length,(i){
      final e=_faqs[i],expanded=_expandedFaq==_faqs[i].title;
      final vote=_votes[e.title];
      return Column(children:[
        InkWell(onTap:()=>setState(()=>_expandedFaq=expanded?null:e.title),
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:13),
            child:Row(children:[
              Expanded(child:Text(e.title,style:TextStyle(color:ink,fontSize:12.5,
                fontWeight:FontWeight.w800))),
              const SizedBox(width:9),
              Container(width:27,height:27,decoration:const BoxDecoration(
                color:Color(0xFFF1EDFF),shape:BoxShape.circle),
                child:Icon(expanded?Icons.keyboard_arrow_up_rounded:
                  Icons.keyboard_arrow_down_rounded,
                  color:const Color(0xFF6C4DF6),size:19)),
            ]))),
        if(expanded) Padding(padding:const EdgeInsets.fromLTRB(15,0,15,13),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(e.detail,style:TextStyle(color:muted,fontSize:12.2,height:1.5)),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:Text('Was this helpful?',style:TextStyle(color:muted,
                fontSize:11.5,fontWeight:FontWeight.w700))),
              _vote(Icons.thumb_up_alt_outlined,vote==true,
                ()=>setState(()=>_votes[e.title]=true)),
              const SizedBox(width:7),
              _vote(Icons.thumb_down_alt_outlined,vote==false,
                ()=>setState(()=>_votes[e.title]=false)),
            ]),
          ])),
        if(i!=_faqs.length-1) Divider(height:1,color:border.withValues(alpha:.38)),
      ]);
    })),
  );

  Widget _cantFind(Color ink,Color muted,Color surface)=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(20)),
    child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(
        color:const Color(0xFFBD8744).withValues(alpha:.13),
        borderRadius:BorderRadius.circular(14)),
        child:const Icon(Icons.headset_mic_rounded,
          color:Color(0xFFBD8744),size:20)),
      const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Can’t find it?',style:TextStyle(color:ink,fontSize:13.5,
          fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text('Open the support page and tell us.',
          style:TextStyle(color:muted,fontSize:11.5)),
      ])),
      IconButton.filled(onPressed:()=>_openIssues(),
        style:IconButton.styleFrom(
          backgroundColor:Theme.of(context).colorScheme.primary,
          foregroundColor:Theme.of(context).colorScheme.onPrimary,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
        icon:const Icon(Icons.open_in_new_rounded,size:19)),
    ]),
  );

  Widget _searchResults(Color ink,Color muted,Color surface,Color border){
    final results=_results;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _section(results.length.toString()+' results',muted),
      if(results.isEmpty) Container(padding:const EdgeInsets.all(22),
        decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(22)),
        child:Center(child:Text('No matching topics found. Try another search.',
          textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:13))))
      else Container(
        decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(22),
          border:Border.all(color:border.withValues(alpha:.35))),
        child:Column(children:List.generate(results.length,(i){
          final e=results[i];
          return Column(children:[
            ListTile(onTap:()=>_showEntry(e),
              contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:3),
              leading:Container(width:42,height:42,decoration:BoxDecoration(
                color:e.accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),
                child:Icon(e.icon,color:e.accent,size:20)),
              title:Text(e.title,style:TextStyle(color:ink,fontSize:13,
                fontWeight:FontWeight.w800)),
              subtitle:Text(e.kind,style:TextStyle(color:muted,fontSize:11.5)),
              trailing:Icon(Icons.chevron_right_rounded,color:muted)),
            if(i!=results.length-1) Divider(height:1,
              color:border.withValues(alpha:.35),indent:70),
          ]);
        })),
      ),
      const SizedBox(height:18),
      _cantFind(ink,muted,surface),
    ]);
  }

  Widget _stillNeedHelp(Color ink,Color muted,Color surface){
    final primary=Theme.of(context).colorScheme.primary;
    return Container(padding:const EdgeInsets.all(17),
      decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(23),
        border:Border.all(color:Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha:.25)),
        boxShadow:[BoxShadow(color:primary.withValues(alpha:.045),
          blurRadius:14,offset:const Offset(0,5))]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(
            color:primary.withValues(alpha:.12),borderRadius:BorderRadius.circular(14)),
            child:Icon(Icons.support_agent_rounded,color:primary,size:22)),
          const SizedBox(width:11),
          Text('Still need help?',style:TextStyle(color:ink,fontSize:15,
            fontWeight:FontWeight.w900)),
        ]),
        const SizedBox(height:10),
        Text('Open the Novyn project issue tracker to report a problem or share feedback.',
          style:TextStyle(color:muted,fontSize:12.5,height:1.45)),
        const SizedBox(height:13),
        SizedBox(width:double.infinity,height:45,child:FilledButton.icon(
          onPressed:()=>_openIssues(),
          icon:const Icon(Icons.open_in_new_rounded,size:18),
          label:const Text('Open support page',
            style:TextStyle(fontWeight:FontWeight.w800)),
          style:FilledButton.styleFrom(shape:RoundedRectangleBorder(
            borderRadius:BorderRadius.circular(16))))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    final pageBg=dark?NovynTheme.pageBg(context):const Color(0xFFF3F0FB);
    final surface=dark?const Color(0xFF191824):Colors.white;
    final ink=dark?const Color(0xFFF0EFFF):const Color(0xFF1C1B29);
    final muted=dark?const Color(0xFFAAA8C6):const Color(0xFF6B6880);
    final border=dark?const Color(0xFF39345F):const Color(0xFFE4DFFB);
    final primary=Theme.of(context).colorScheme.primary;
    return Scaffold(backgroundColor:pageBg,body:SafeArea(child:ListView(
      physics:const BouncingScrollPhysics(),
      padding:const EdgeInsets.fromLTRB(16,8,16,28),
      children:[
        _header(ink,surface,border),
        const SizedBox(height:17),
        if(_query.isEmpty) ...[
          Container(
            padding:const EdgeInsets.fromLTRB(17,17,17,16),
            decoration:BoxDecoration(
              gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:dark?const [Color(0xFF292342),Color(0xFF211E35)]:
                  const [Color(0xFFE8E1FF),Color(0xFFDCD3FF)]),
              borderRadius:BorderRadius.circular(25)),
            child:Stack(children:[
              Positioned(right:4,top:-20,child:Container(width:80,height:80,
                decoration:BoxDecoration(shape:BoxShape.circle,
                  border:Border.all(color:primary.withValues(alpha:.10),width:1.5)))),
              Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('How can we help?',style:TextStyle(color:ink,fontSize:22,
                  fontWeight:FontWeight.w900,letterSpacing:-.65)),
                const SizedBox(height:4),
                Text('Find answers or report a problem\nwith Novyn.',
                  style:TextStyle(color:muted,fontSize:12.5,height:1.35)),
                const SizedBox(height:14),
                _search(ink,muted,surface,primary),
              ]),
            ]),
          ),
          const SizedBox(height:12),
          Row(children:[
            _action('Contact support',Icons.headset_mic_rounded,
              const Color(0xFF8065ED),()=>_openIssues(),external:true),
            const SizedBox(width:9),
            _action('Report a bug',Icons.bug_report_rounded,
              const Color(0xFFD45B56),()=>_openIssues(newBug:true),external:true),
            const SizedBox(width:9),
            _action('Send feedback',Icons.chat_bubble_outline_rounded,
              const Color(0xFFBD8744),_openFeedback),
          ]),
          const SizedBox(height:22),
          _section('Help topics',muted),
          GridView.builder(
            shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
            itemCount:_topics.length,
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,
              mainAxisExtent:119),
            itemBuilder:(context,i)=>_topicCard(_topics[i],ink,muted,surface)),
          const SizedBox(height:21),
          _section('Popular questions',muted),
          _faqList(ink,muted,surface,border),
          const SizedBox(height:15),
          _stillNeedHelp(ink,muted,surface),
        ] else ...[
          _search(ink,muted,surface,primary),
          const SizedBox(height:21),
          _searchResults(ink,muted,surface,border),
        ],
        const SizedBox(height:22),
        Center(child:Text('NOVYN · YOUR SPACE, YOUR PEOPLE',
          style:TextStyle(color:muted,fontSize:10.5,fontWeight:FontWeight.w800,
            letterSpacing:1.6))),
      ],
    )));
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _types = <(String, String, IconData, Color)>[
    ('general', 'General', Icons.chat_bubble_outline_rounded, Color(0xFF7257F4)),
    ('bug', 'Bug report', Icons.bug_report_outlined, Color(0xFFD7473E)),
    ('feature', 'Feature request', Icons.lightbulb_outline_rounded, Color(0xFFB86A17)),
    ('praise', 'Praise', Icons.favorite_border_rounded, Color(0xFFB83E70)),
  ];

  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  String _type = 'general';
  int _rating = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _emailController.text.trim().isNotEmpty) return;
      final accountEmail = context.read<AuthService>().user?.email.trim() ?? '';
      if (accountEmail.isNotEmpty) {
        setState(() => _emailController.text = accountEmail);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(
    String title, {
    String? optionalLabel,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.25,
          ),
        ),
        if (optionalLabel != null) ...[
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              optionalLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _categoryCard((String, String, IconData, Color) item) {
    final colors = Theme.of(context).colorScheme;
    final selected = _type == item.$1;
    return Expanded(
      child: InkWell(
        onTap: _sending ? null : () => setState(() => _type = item.$1),
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant.withValues(alpha: .75),
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.$4.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.$3, color: item.$4, size: 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, color: colors.onPrimary, size: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    final email = _emailController.text.trim();
    if (message.length < 5) {
      context.showNovynAlert(const SnackBar(
        content: Text('Please write at least 5 characters.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      context.showNovynAlert(const SnackBar(
        content: Text('Enter a valid email address or leave it blank.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await ApiService.submitFeedback(
        type: _type,
        message: message,
        email: email,
        rating: _rating == 0 ? null : _rating,
      );
      if (!mounted) return;

      final delivery = result['email'] is Map
          ? Map<String, dynamic>.from(result['email'] as Map)
          : <String, dynamic>{};
      final adminSent = delivery['adminSent'] == true;
      final receiptSent = delivery['receiptSent'] == true;
      final reference = result['id']?.toString() ?? 'saved';

      String statusText;
      if (adminSent && receiptSent) {
        statusText = 'Your feedback was saved and delivered to the Novyn team. A receipt was sent to $email.';
      } else if (adminSent) {
        statusText = 'Your feedback was saved and delivered to the Novyn team. No email receipt was sent.';
      } else if (receiptSent) {
        statusText = 'Your feedback was saved. A receipt was sent to $email, but the team email could not be delivered right now.';
      } else {
        statusText = 'Your feedback was saved (reference: $reference), but email delivery is not confirmed. The team can still review your submission.';
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 46,
          ),
          title: const Text('Feedback received'),
          content: Text(statusText),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) {
        _messageController.clear();
        _rating = 0;
        setState(() => _type = 'general');
      }
    } catch (error) {
      if (!mounted) return;
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      context.showNovynAlert(SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 66,
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.35),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: Material(
            color: NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.maybePop(context),
              child: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? .17 : .09),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: .25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: colors.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help us improve Novyn',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -.3),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Share an idea, report a bug, or tell us what you love.',
                        style: TextStyle(fontSize: 12.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('What would you like to share?'),
          const SizedBox(height: 12),
          Row(
            children: [
              _categoryCard(_types[0]),
              const SizedBox(width: 12),
              _categoryCard(_types[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _categoryCard(_types[2]),
              const SizedBox(width: 12),
              _categoryCard(_types[3]),
            ],
          ),
          const SizedBox(height: 27),
          _sectionTitle('Rate your experience', optionalLabel: 'Optional'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
            decoration: BoxDecoration(
              color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? const [] : [
                BoxShadow(
                  color: const Color(0xFF6D55C7).withValues(alpha: .06),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    final selected = value <= _rating;
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      onPressed: _sending
                          ? null
                          : () => setState(() => _rating = _rating == value ? 0 : value),
                      icon: Icon(
                        selected ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 31,
                        color: selected ? const Color(0xFFF4A51C) : colors.onSurfaceVariant.withValues(alpha: .42),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 1),
                Text(
                  _rating == 0
                      ? 'Tap a star to rate (optional)'
                      : ['', 'Needs work', 'Fair', 'Good', 'Loving it', 'Excellent'][_rating],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _rating > 0 ? const Color(0xFFB96A17) : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          _sectionTitle('Your feedback'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? const [] : [
                BoxShadow(
                  color: const Color(0xFF6D55C7).withValues(alpha: .05),
                  blurRadius: 17,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 4,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 5),
                    child: Text(
                      '$currentLength / 2000',
                      style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ),
              decoration: InputDecoration(
                hintText: 'Tell us what is on your mind...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.fromLTRB(15, 13, 15, 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.primary.withValues(alpha: .45), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Email for a reply', optionalLabel: 'Optional'),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              filled: true,
              fillColor: NovynTheme.cardBg(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: colors.primary.withValues(alpha: .45), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .25),
                    blurRadius: 19,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colors.onPrimary,
                  disabledBackgroundColor: colors.primary.withValues(alpha: .55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                ),
                icon: _sending
                    ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending ? 'Sending...' : 'Send feedback',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your feedback is securely saved for the Novyn team.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
