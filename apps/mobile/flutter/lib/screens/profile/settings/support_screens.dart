import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../theme/novyn_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/app_update_service.dart';

const _installerChannel = MethodChannel('com.example.novyn/apk_installer');

class AboutNovynScreen extends StatefulWidget {
  const AboutNovynScreen({super.key});
  @override
  State<AboutNovynScreen> createState() => _AboutNovynScreenState();
}

class _AboutNovynScreenState extends State<AboutNovynScreen> {
  bool _checking = true, _downloading = false, _installing = false;
  String? _status, _apkUrl, _expectedSha256, _downloadedApkPath;
  int? _apkSize;
  int _installedBuild = 0, _latestBuild = 0;
  double _downloadProgress = 0;
  String _appVersion = AppUpdateService.displayVersion, _buildNumber = '0';
  final AppUpdateService _updateService = AppUpdateService.instance;

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
    setState(() {
      _downloading = _updateService.isDownloading;
      _downloadProgress = _updateService.downloadProgress;
      _downloadedApkPath = _updateService.downloadedApkPath;
      if (_updateService.downloadError != null) {
        _status = _updateService.downloadError;
      } else if (_downloadedApkPath != null) {
        _status = 'ARM64 APK downloaded and verified. Ready to install.';
      } else if (_downloading) {
        _status = 'Downloading ARM64 update…';
      }
    });
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
      });
    }
    try {
      // Show the installed package metadata even when GitHub is unreachable.
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
      }
      setState(() {
        _status = result.message;
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
    await _updateService.downloadUpdate();
  }

  Future<void> _installUpdate() async {
    final path = _downloadedApkPath;
    if (path == null) return;
    setState(() => _installing = true);
    try {
      final allowed = await _installerChannel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!allowed) {
        await _installerChannel.invokeMethod<void>('openInstallPermissionSettings');
        if (mounted) setState(() => _status = 'Allow Novyn to install updates, then tap Install update again.');
        return;
      }
      await _installerChannel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException {
      if (mounted) setState(() => _status = 'Could not open Android installer. Please try again.');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  void dispose() {
    _updateService.removeListener(_handleDownloadStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = dark ? NovynTheme.pageBg(context) : const Color(0xFFF5F3FF);
    final ink = dark ? const Color(0xFFF0EFFF) : const Color(0xFF1E1B49);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF5D5A85);
    final surface = dark ? const Color(0xFF13141D) : Colors.white;
    final border = dark ? const Color(0xFF39345F) : const Color(0xFFDDD8FF);
    final primary = Theme.of(context).colorScheme.primary;
    final available = _latestBuild > _installedBuild;
    final upToDate = !_checking && !available &&
        (_status?.toLowerCase().contains('up to date') == true);
    final error = !_checking && !available && !upToDate;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Material(
                  color: surface,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: border),
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: ink, size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text('About Novyn', style: TextStyle(color: ink, fontSize: 26,
                  letterSpacing: -.7, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 22),
              Center(
                child: Column(children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF806FFF), Color(0xFF5141CD)],
                      ),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF5141CD).withValues(alpha: .23),
                        blurRadius: 28, offset: const Offset(0, 11))],
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 47),
                  ),
                  const SizedBox(height: 16),
                  Text('Novyn', style: TextStyle(color: ink, fontSize: 34,
                    letterSpacing: -1.1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text('Your space, your people.',
                    style: TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: border),
                    ),
                    child: Text('Version $_appVersion (build $_buildNumber)',
                      style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  color: available
                      ? (dark ? const Color(0xFF211D3B) : const Color(0xFFF0EDFF))
                      : surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: available ? primary : border,
                    width: available ? 1.5 : 1),
                  boxShadow: available ? [BoxShadow(
                    color: primary.withValues(alpha: .08),
                    blurRadius: 22, offset: const Offset(0, 8))] : const [],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: available
                            ? primary
                            : upToDate
                                ? const Color(0xFFDDFBE8)
                                : error
                                    ? const Color(0xFFFFF0D9)
                                    : primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(strokeWidth: 2.2))
                          : Icon(
                              available ? Icons.download_rounded :
                                upToDate ? Icons.check_rounded :
                                  error ? Icons.error_outline_rounded : Icons.sync_rounded,
                              color: available ? Colors.white :
                                upToDate ? const Color(0xFF176B3B) :
                                  error ? const Color(0xFF9A5A08) : primary,
                              size: 25),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          available ? 'Update available' :
                            upToDate ? 'You are up to date' :
                              error ? 'Could not check for updates' : 'Checking for updates',
                          style: TextStyle(color: ink, fontSize: 18,
                            letterSpacing: -.35, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          available ? 'A newer build is ready to install.' :
                            upToDate ? 'Last checked just now' :
                              error ? (_status ?? 'Check your connection and try again.') :
                                'Looking for the latest Novyn build.',
                          style: TextStyle(color: muted, fontSize: 13, height: 1.35,
                            fontWeight: FontWeight.w500)),
                      ],
                    )),
                  ]),
                  if (available) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _updateChip(((_apkSize ?? 0) / 1000000).toStringAsFixed(1) + ' MB',
                        surface, ink, border),
                      _updateChip('ARM64-v8a', surface, ink, border),
                    ]),
                    if (_downloading || _updateService.hasPartialDownload) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          minHeight: 5,
                          backgroundColor: primary.withValues(alpha: .15)),
                      ),
                      const SizedBox(height: 6),
                      Text('Downloading ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    if (_updateService.downloadError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _updateService.downloadError!,
                        style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF705DFF), Color(0xFF5543E8)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [BoxShadow(
                            color: primary.withValues(alpha: .24),
                            blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _downloading || _installing
                                ? null
                                : (_downloadedApkPath == null ? _downloadUpdate : _installUpdate),
                            borderRadius: BorderRadius.circular(32),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              if (_downloading || _installing)
                                const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              else
                                Icon(_downloadedApkPath == null
                                  ? Icons.download_rounded : Icons.install_mobile_rounded,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                _downloading ? 'Downloading update' :
                                  _installing ? 'Opening installer' :
                                    _downloadedApkPath == null
                                        ? (_updateService.hasPartialDownload ? 'Resume download' : 'Download update')
                                        : 'Install update',
                                style: const TextStyle(color: Colors.white,
                                  fontSize: 15.5, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Center(child: TextButton(
                      onPressed: _checking || _downloading || _installing ? null : _checkForUpdates,
                      style: TextButton.styleFrom(foregroundColor: primary,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      child: const Text('Check again'))),
                  ] else ...[
                    if (error) ...[
                      const SizedBox(height: 12),
                      Text('$_status', style: TextStyle(color: muted, fontSize: 12.5, height: 1.4)),
                    ],
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _checking ? null : _checkForUpdates,
                        icon: _checking
                            ? SizedBox(width: 19, height: 19,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(ink)))
                            : Icon(Icons.refresh_rounded, color: ink, size: 21),
                        label: Text(
                          _checking ? 'Checking for updates' :
                            upToDate ? 'Check for updates' : 'Try again',
                          style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 15),
              _infoCard(context, [
                _InfoRow(label: 'App version', value: '$_appVersion (build $_buildNumber)'),
                Divider(height: 1, color: border.withValues(alpha: .8)),
                const _InfoRow(label: 'Platform', value: 'Flutter · Android ARM64'),
              ]),
              const SizedBox(height: 23),
              Center(child: Text('MADE TO KEEP YOUR PEOPLE CLOSE',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12.5, letterSpacing: 1.7,
                  fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              Center(child: Text('© ${DateTime.now().year} Novyn',
                style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _updateChip(String text, Color surface, Color ink, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: ink, fontSize: 13,
        fontWeight: FontWeight.w700)),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF39345F) : const Color(0xFFDDD8FF)),
    ),
    child: Column(children: children),
  );


}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          color: dark ? const Color(0xFFAAA8C6) : const Color(0xFF5D5A85),
          fontSize: 14.5, fontWeight: FontWeight.w500))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: dark ? const Color(0xFFF0EFFF) : const Color(0xFF1E1B49),
            fontSize: 14.5, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _openIssues(BuildContext context) async {
    final uri = Uri.parse('https://github.com/itsSatyam27/novyn-chat/issues');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showNovynAlert(const SnackBar(content: Text('Could not open support page.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          Text('How can we help?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text('Find answers or report a problem with Novyn.', style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 22),
          _helpCard(context, icon: Icons.menu_book_rounded, title: 'Getting started', description: 'Learn how to use chats, contacts, calls and settings.'),
          _helpCard(context, icon: Icons.lock_outline_rounded, title: 'Account & privacy', description: 'Review privacy controls and account security settings.'),
          _helpCard(context, icon: Icons.backup_outlined, title: 'Chat backup', description: 'Create an encrypted backup from Settings → Chat Settings.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Report a bug or issue', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Open the Novyn project issue tracker to report a problem or share feedback.', style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => _openIssues(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open support page'),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _helpCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
    ),
    child: Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
    ]),
  );
}


class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _types = <(String, String, IconData)>[
    ('general', 'General', Icons.chat_bubble_outline_rounded),
    ('bug', 'Bug report', Icons.bug_report_outlined),
    ('feature', 'Feature request', Icons.lightbulb_outline_rounded),
    ('praise', 'Praise', Icons.favorite_border_rounded),
  ];
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  String _type = 'general';
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.length < 5) {
      ScaffoldMessenger.of(context).showNovynAlert(const SnackBar(content: Text('Please write at least 5 characters.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.submitFeedback(
        type: _type,
        message: message,
        email: _emailController.text,
        rating: _rating == 0 ? null : _rating,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 42),
          title: const Text('Thanks for your feedback!'),
          content: const Text('We read every submission and use it to make Novyn better.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))],
        ),
      );
      if (mounted) {
        _messageController.clear();
        _emailController.clear();
        setState(() => _rating = 0);
      }
    } catch (error) {
      if (!mounted) return;
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showNovynAlert(SnackBar(content: Text(errorMessage), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        title: const Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.primary.withValues(alpha: .16)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.mark_chat_unread_rounded, color: colors.primary, size: 28),
              const SizedBox(width: 13),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Help us improve Novyn', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                SizedBox(height: 5),
                Text('Share an idea, report a bug, or tell us what you love.', style: TextStyle(height: 1.4)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),
          Text('What would you like to share?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 9, runSpacing: 9, children: _types.map((item) {
            final selected = _type == item.$1;
            return ChoiceChip(
              avatar: Icon(item.$3, size: 17, color: selected ? colors.onPrimary : colors.onSurfaceVariant),
              label: Text(item.$2),
              selected: selected,
              onSelected: _sending ? null : (_) => setState(() => _type = item.$1),
              showCheckmark: false,
            );
          }).toList()),
          const SizedBox(height: 24),
          Text('Rate your experience (optional)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            ...List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                tooltip: '$value star${value == 1 ? '' : 's'}',
                onPressed: _sending ? null : () => setState(() => _rating = _rating == value ? 0 : value),
                icon: Icon(value <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: value <= _rating ? const Color(0xFFF59E0B) : colors.onSurfaceVariant, size: 30),
              );
            }),
            if (_rating > 0) Text(['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'][_rating],
              style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 18),
          Text('Your feedback', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          TextField(
            controller: _messageController, enabled: !_sending, minLines: 5, maxLines: 7, maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tell us what is on your mind…', alignLabelWithHint: true, filled: true,
              fillColor: NovynTheme.cardBg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: colors.outlineVariant)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Email for a reply (optional)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          TextField(
            controller: _emailController, enabled: !_sending, keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'you@example.com', prefixIcon: const Icon(Icons.mail_outline_rounded), filled: true,
              fillColor: NovynTheme.cardBg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(height: 54, child: FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Sending…' : 'Send feedback', style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
          const SizedBox(height: 10),
          Center(child: Text('Your feedback is sent securely to the Novyn team.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))),
        ],
      ),
    );
  }
}
