import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../widgets/novyn_brand_mark.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/novyn_theme.dart';
import '../../../services/api_service.dart';

const _releasesApi = 'https://api.github.com/repos/itsSatyam27/novyn-chat/releases/latest';
const _arm64ApkName = 'Novyn-Android-ARM64.apk';
const _installerChannel = MethodChannel('com.example.novyn/apk_installer');

class AboutNovynScreen extends StatefulWidget {
  const AboutNovynScreen({super.key});
  @override
  State<AboutNovynScreen> createState() => _AboutNovynScreenState();
}

class _AboutNovynScreenState extends State<AboutNovynScreen> {
  bool _checking = false, _downloading = false, _installing = false;
  String? _status, _releaseName, _apkUrl, _expectedSha256, _downloadedApkPath;
  int? _apkSize;
  int _installedBuild = 0, _latestBuild = 0;
  double _downloadProgress = 0;
  String _appVersion = '—', _buildNumber = '0';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
        _installedBuild = int.tryParse(info.buildNumber) ?? 0;
      });
    });
  }

  Future<void> _checkForUpdates() async {
    final installedInfo = await PackageInfo.fromPlatform();
    _installedBuild = int.tryParse(installedInfo.buildNumber) ?? 0;
    _appVersion = installedInfo.version;
    _buildNumber = installedInfo.buildNumber;
    setState(() {
      _latestBuild = 0;
      _checking = true;
      _status = null;
      _apkUrl = null;
      _expectedSha256 = null;
      _downloadedApkPath = null;
      _releaseName = null;
      _apkSize = null;
    });
    try {
      final response = await http.get(Uri.parse(_releasesApi),
          headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        setState(() => _status = 'No public Android release is available yet.');
        return;
      }
      if (response.statusCode != 200) throw Exception('Update service unavailable.');
      final data = jsonDecode(response.body);
      if (data is! Map || data['draft'] == true) throw const FormatException('Invalid release.');
      final tag = (data['tag_name'] ?? '').toString();
      final match = RegExp(r'^novyn-arm64-build-(\d+)(?:-\d+)?$').firstMatch(tag);
      if (match == null) throw const FormatException('Latest release is not a supported ARM64 build.');
      final build = int.parse(match.group(1)!);
      final assets = data['assets'];
      if (assets is! List) throw const FormatException('Release assets are missing.');
      Map? asset;
      for (final item in assets) {
        if (item is Map && item['name'] == _arm64ApkName) { asset = item; break; }
      }
      if (asset == null) throw const FormatException('ARM64 APK is missing.');
      final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
      final digest = (asset['digest'] ?? '').toString();
      final size = int.tryParse((asset['size'] ?? '').toString());
      if (url == null || url.host != 'github.com' ||
          !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
          !url.path.endsWith('/' + _arm64ApkName) ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
          size == null || size < 10 * 1024 * 1024 || size > 100 * 1024 * 1024) {
        throw const FormatException('ARM64 APK metadata failed validation.');
      }
      setState(() {
        _latestBuild = build;
        _releaseName = (data['name'] ?? tag).toString();
        _apkUrl = url.toString();
        _expectedSha256 = digest.substring(7).toLowerCase();
        _apkSize = size;
        _status = build > _installedBuild
            ? 'A new ARM64 update is available.'
            : 'You are up to date. Novyn is running the latest ARM64 release.';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not verify updates. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadUpdate() async {
    final url = _apkUrl, hash = _expectedSha256;
    final size = _apkSize;
    if (url == null || hash == null || size == null) return;
    setState(() { _downloading = true; _downloadProgress = 0; _status = 'Downloading ARM64 update…'; });
    final client = http.Client();
    String? path;
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || (response.contentLength ?? size) != size) {
        throw const FormatException('APK download response is invalid.');
      }
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/' + _arm64ApkName);
      path = file.path;
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();
      final hashSink = AccumulatorSink<Digest>();
      final converter = sha256.startChunkedConversion(hashSink);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (received > size) throw const FormatException('APK exceeds expected size.');
          converter.add(chunk);
          sink.add(chunk);
          if (mounted) setState(() => _downloadProgress = received / size);
        }
      } finally {
        converter.close();
        await sink.flush();
        await sink.close();
      }
      if (received != size || hashSink.events.single.toString() != hash) {
        await file.delete();
        throw const FormatException('APK checksum verification failed.');
      }
      if (!mounted) return;
      setState(() { _downloadedApkPath = file.path; _status = 'ARM64 APK downloaded and verified. Ready to install.'; });
    } catch (_) {
      if (path != null) {
        final partial = File(path);
        if (await partial.exists()) await partial.delete();
      }
      if (mounted) setState(() => _status = 'Download or verification failed. Please try again.');
    } finally {
      client.close();
      if (mounted) setState(() => _downloading = false);
    }
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = _latestBuild > _installedBuild;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(backgroundColor: NovynTheme.pageBg(context), elevation: 0,
        title: const Text('About Novyn', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 36), children: [
        Center(child: Column(children: [
          Container(width: 92, height: 92, padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(27),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF7C6CFF), Color(0xFF5141CD)]),
              boxShadow: [BoxShadow(color: const Color(0xFF5141CD).withValues(alpha: .22),
                blurRadius: 22, offset: const Offset(0, 9))]),
            child: const NovynBrandMark(size: 76)),
          const SizedBox(height: 16),
          Text('Novyn', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Your space, your people.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
        ])),
        const SizedBox(height: 28),
        _infoCard(context, [
          _InfoRow(label: 'App version', value: _appVersion + ' (' + _buildNumber + ')'),
          _InfoRow(label: 'Platform', value: 'Flutter · Android ARM64'),
          _InfoRow(label: '©', value: '2026 Novyn'),
        ]),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.system_update_alt_rounded, color: colors.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('App updates', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))]),
            const SizedBox(height: 8),
            Text('Check and install the latest ARM64 Android release.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _checking || _downloading ? null : _checkForUpdates,
              icon: _checking ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: Text(_checking ? 'Checking…' : 'Check for updates'))),
            if (_downloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 6),
              Text('Downloading ARM64 APK · ' + (_downloadProgress * 100).toStringAsFixed(0) + '%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: available ? colors.primary : colors.onSurfaceVariant, height: 1.45)),
              if (available && _releaseName != null) ...[
                const SizedBox(height: 6),
                Text(_releaseName! + ' · ' + ((_apkSize ?? 0) / 1000000).toStringAsFixed(1) + ' MB · ARM64-v8a',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (_downloadedApkPath == null)
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: _downloading ? null : _downloadUpdate,
                    icon: const Icon(Icons.download_rounded), label: const Text('Download update')))
                else
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: _installing ? null : _installUpdate,
                    icon: _installing ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.install_mobile_rounded),
                    label: Text(_installing ? 'Opening installer…' : 'Install update'))),
              ],
            ],
          ])),
        const SizedBox(height: 22),
        Center(child: Text('MADE TO KEEP YOUR PEOPLE CLOSE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2,
            color: colors.onSurfaceVariant.withValues(alpha: .65), fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .6))),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _openIssues(BuildContext context) async {
    final uri = Uri.parse('https://github.com/itsSatyam27/novyn-chat/issues');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open support page.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write at least 5 characters.')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), behavior: SnackBarBehavior.floating));
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
