import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../widgets/novyn_brand_mark.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/novyn_theme.dart';
import '../../../services/api_service.dart';

const _appVersion = '1.0.0';
const _buildNumber = '1';
const _releasesApi = 'https://api.github.com/repos/itsSatyam27/novyn-chat/releases/latest';

class AboutNovynScreen extends StatefulWidget {
  const AboutNovynScreen({super.key});

  @override
  State<AboutNovynScreen> createState() => _AboutNovynScreenState();
}

class _AboutNovynScreenState extends State<AboutNovynScreen> {
  bool _checking = false;
  String? _status;
  Uri? _releaseUrl;
  bool? _updateAvailable;

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _status = null;
      _releaseUrl = null;
      _updateAvailable = null;
    });
    try {
      final response = await http.get(
        Uri.parse(_releasesApi),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() => _status = 'No public release is available yet. You are using Novyn v$_appVersion.');
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Update service returned status ${response.statusCode}.');
      }
      final data = jsonDecode(response.body);
      if (data is! Map) throw const FormatException('Invalid release information.');
      final tag = (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), '');
      final url = Uri.tryParse((data['html_url'] ?? '').toString());
      if (tag.isEmpty || url == null || !url.hasScheme) {
        throw const FormatException('Latest release information is incomplete.');
      }
      final available = _compareVersions(tag, _appVersion) > 0;
      setState(() {
        _releaseUrl = url;
        _updateAvailable = available;
        _status = available
          ? 'Novyn v$tag is available. Open the release page to view release notes and download options.'
          : 'You are up to date. Novyn v$_appVersion is the latest published release.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not check for updates. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  int _compareVersions(String left, String right) {
    List<int> parts(String value) => value.split('.').map((part) {
      final digits = RegExp(r'^\d+').firstMatch(part)?.group(0);
      return int.tryParse(digits ?? '') ?? 0;
    }).toList();
    final a = parts(left), b = parts(right);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  Future<void> _openRelease() async {
    final url = _releaseUrl;
    if (url == null) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the release page.')));
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
        title: const Text('About Novyn', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Center(
            child: Column(children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C6CFF), Color(0xFF5141CD)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5141CD).withValues(alpha: .22),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: const NovynBrandMark(size: 76),
              ),
              const SizedBox(height: 16),
              Text('Novyn', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('Your space, your people.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 28),
          _infoCard(context, [
            _InfoRow(label: 'App version', value: '$_appVersion ($_buildNumber)'),
            _InfoRow(label: 'Platform', value: 'Flutter'),
            _InfoRow(label: '©', value: '2026 Novyn'),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.system_update_alt_rounded, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('App updates', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              ]),
              const SizedBox(height: 8),
              Text('Check the latest published Novyn release.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checking ? null : _checkForUpdates,
                  icon: _checking
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                  label: Text(_checking ? 'Checking…' : 'Check for updates'),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _updateAvailable == true ? colors.primary : colors.onSurfaceVariant,
                  height: 1.45,
                )),
                if (_updateAvailable == true) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openRelease,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('View update'),
                  ),
                ],
              ],
            ]),
          ),
          const SizedBox(height: 22),
          Center(child: Text('MADE TO KEEP YOUR PEOPLE CLOSE', style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2, color: colors.onSurfaceVariant.withValues(alpha: .65), fontWeight: FontWeight.w800,
          ))),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .6)),
    ),
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
