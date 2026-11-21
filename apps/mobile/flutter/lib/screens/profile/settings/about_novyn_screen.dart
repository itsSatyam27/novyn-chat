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
  DateTime? _lastCheckedAt;
  int _lastProgressBytes = 0;
  double _downloadSpeedBytesPerSecond = 0;
  String _appVersion = AppUpdateService.displayVersion, _buildNumber = '0';
  final AppUpdateService _updateService = AppUpdateService.instance;

  String _lastCheckedLabel() {
    if (_lastCheckedAt == null) return 'Last checked just now';
    final diff = DateTime.now().difference(_lastCheckedAt!);
    if (diff.inSeconds < 60) return 'Last checked just now';
    if (diff.inMinutes < 60) return 'Last checked ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last checked ${diff.inHours}h ago';
    return 'Last checked today';
  }

  bool get _paused => !_ready && !_downloading &&
      (_updateService.isPaused || _updateService.hasPartialDownload);
  bool get _available => _latestBuild > _installedBuild;
  bool get _ready => _downloadedApkPath != null;

  List<String> _displayReleaseNotes() {
    final notes = _releaseNotes
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList(growable: false);
    return notes.isEmpty
        ? <String>['Build $_latestBuild is ready with the latest Novyn improvements.']
        : notes;
  }

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
        _lastCheckedAt = DateTime.now();
        _status = result.release != null ? null : result.message;
        _checking = false;
      });
      _handleDownloadStateChanged();
    } catch (_) {
      if (mounted) {
        setState(() {
          _lastCheckedAt = DateTime.now();
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
    _showInstallingSheet();
    try {
      final allowed = await _installerChannel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!allowed) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        await _installerChannel.invokeMethod<void>('openInstallPermissionSettings');
        if (mounted) {
          setState(() => _status = 'Allow Novyn to install updates, then tap Install update again.');
        }
        return;
      }
      await _installerChannel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) setState(() => _status = 'Could not open Android installer. Please try again.');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _showInstallingSheet() {
    final sizeMb = ((_apkSize ?? _updateService.expectedBytes) / 1000000).toStringAsFixed(1);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const SizedBox(height: 18),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF7048F8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Installing update...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1D1B2B),
                    fontSize: 20,
                    letterSpacing: -.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Novyn ${_releaseName ?? 'Beta v1.1'} · $sizeMb MB',
                  style: const TextStyle(
                    color: Color(0xFF777487),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Color(0xFFEDE7FF),
                    color: Color(0xFF7048F8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Novyn will restart when this finishes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF777487),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _displayReleaseNotes().asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 7),
                        child: _UpdateNote(text: entry.value),
                      );
                    }).toList(growable: false),
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
    final muted = dark ? const Color(0xFFC4C1DD) : const Color(0xFF777487);
    final surface = dark ? const Color(0xFF171622) : Colors.white;
    final border = dark ? const Color(0xFF39345F) : const Color(0xFFE5DFFF);
    final primary = const Color(0xFF7048F8);
    final updateName = _releaseName ?? 'Build $_latestBuild';
    final updateNotes = _displayReleaseNotes();
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
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8060FF), Color(0xFF5938D8)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x337048F8),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/icons/app_icon_foreground.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Novyn',
                      ),
                    ),
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
                padding: const EdgeInsets.all(16),
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
                          color: (_checking || _installing)
                              ? (dark ? const Color(0xFF28234B) : const Color(0xFFEDE7FF))
                              : (_available || activeDownload || _ready)
                                  ? (dark ? const Color(0xFF28234B) : const Color(0xFFEDE7FF))
                                  : (!_checking && _status != null && !_status!.toLowerCase().contains('up to date'))
                                      ? (dark ? const Color(0xFF381F23) : const Color(0xFFFEECEE))
                                      : (dark ? const Color(0xFF1B3324) : const Color(0xFFE8F7EE)),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: (_checking || _installing)
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF7048F8),
                                  ),
                                ),
                              )
                            : (_available || activeDownload || _ready)
                                ? const Icon(
                                    Icons.download_rounded,
                                    color: Color(0xFF7048F8),
                                    size: 24,
                                  )
                                : (!_checking && _status != null && !_status!.toLowerCase().contains('up to date'))
                                    ? const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 24,
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        color: Color(0xFF16A34A),
                                        size: 24,
                                      ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _checking ? 'Checking for updates' :
                                _installing ? 'Installing update...' :
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
                              _installing
                                  ? "Please don't close Novyn"
                                  : _available
                                      ? '${_releaseName ?? 'Beta v1.1'} · ${((_apkSize ?? _updateService.expectedBytes) / 1000000).toStringAsFixed(1)} MB'
                                      : _downloading
                                          ? (_releaseName ?? 'Beta v1.1')
                                          : _checking
                                              ? 'Looking for the latest version'
                                              : (!_available && _status != null && !_status!.toLowerCase().contains('up to date')
                                                  ? _status!
                                                  : _lastCheckedLabel()),
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
                          color: dark ? const Color(0xFF242037) : const Color(0xFFF6F3FC),
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
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: Material(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: (_checking || _installing) ? null : _checkForUpdates,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_checking)
                                    const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Color(0xFF7048F8),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.refresh_rounded,
                                      color: _installing ? muted.withValues(alpha: .5) : ink,
                                      size: 19,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _checking ? 'Checking for updates...' : 'Check for updates',
                                    style: TextStyle(
                                      color: _installing ? muted.withValues(alpha: .5) : ink,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                _InfoRow(label: 'App version', value: _appVersion),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, color: Color(0xFF956BFF), size: 6),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: dark ? const Color(0xFFE6E2F5) : const Color(0xFF39364D),
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
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
