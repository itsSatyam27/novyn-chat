import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import '../../../theme/novyn_theme.dart';
import 'feedback_screen.dart';

const _appSupportEmail = 'novynchat.app@gmail.com';

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
    _HelpEntry(
      'Getting started',
      'Chats, contacts, calls and settings',
      'Start conversations from Chats, find people in Friends, and personalize Novyn from your profile settings.',
      Icons.menu_book_rounded,
      Color(0xFF7257F4),
      'Help topic',
    ),
    _HelpEntry(
      'Account & privacy',
      'Privacy controls and security',
      'Review your account details, app lock, blocked contacts, presence and privacy controls from Settings.',
      Icons.lock_outline_rounded,
      Color(0xFF289868),
      'Help topic',
    ),
    _HelpEntry(
      'Chat backup',
      'Create and restore a chat backup',
      'Open Settings → Chat Settings → Chat backup. Create a backup before changing devices, then use Restore when setting up Novyn again.',
      Icons.cloud_upload_outlined,
      Color(0xFF3888E9),
      'Help topic',
    ),
    _HelpEntry(
      'Friends & requests',
      'Add people by username',
      'Open Friends, search for a person by their Novyn username, and send a friend request. You can review incoming requests in the same area.',
      Icons.people_outline_rounded,
      Color(0xFFD34F88),
      'Help topic',
    ),
    _HelpEntry(
      'Calls & video',
      'Audio and video calling',
      'Open a conversation and use its call controls to start an audio or video call. Check microphone and camera permissions if a call cannot start.',
      Icons.call_outlined,
      Color(0xFF2A9D8F),
      'Help topic',
    ),
    _HelpEntry(
      'Notifications',
      'Alerts, sounds and Do Not Disturb',
      'Open Settings → Notifications to manage message previews, sounds, vibration and Do Not Disturb preferences.',
      Icons.notifications_none_rounded,
      Color(0xFFD69836),
      'Help topic',
    ),
  ];

  static const _faqs = <_HelpEntry>[
    _HelpEntry(
      'How do I back up my chats?',
      'Popular question',
      'Open Settings → Chat Settings and choose Chat backup. Backups are encrypted, and you can restore them when you set up Novyn again.',
      Icons.description_outlined,
      Color(0xFF7257F4),
      'Popular question',
    ),
    _HelpEntry(
      'How do I stop screenshots in chats?',
      'Popular question',
      'Open the conversation settings and review the privacy controls available for that chat. Availability can depend on the current app build and device.',
      Icons.description_outlined,
      Color(0xFF7257F4),
      'Popular question',
    ),
    _HelpEntry(
      'Who can see when I am online?',
      'Popular question',
      'Your presence is shown according to your current presence and privacy settings. Review the privacy controls in Settings for the options available in your build.',
      Icons.description_outlined,
      Color(0xFF7257F4),
      'Popular question',
    ),
    _HelpEntry(
      'How do I add a friend?',
      'Popular question',
      'Open Friends, search by the person’s Novyn username, and send a friend request.',
      Icons.description_outlined,
      Color(0xFF7257F4),
      'Popular question',
    ),
  ];

  static const _articles = <_HelpEntry>[
    _HelpEntry(
      'Restore a backup on a new phone',
      'Article',
      'Install Novyn on your new phone, sign in to the same account, open Settings → Chat Settings → Chat backup, and follow the restore flow for your saved backup.',
      Icons.article_outlined,
      Color(0xFF7257F4),
      'Article',
    ),
  ];

  List<_HelpEntry> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return <_HelpEntry>[..._topics, ..._faqs, ..._articles]
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q) ||
            e.detail.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openIssues({bool newBug = false}) async {
    final uri = newBug
        ? Uri.https('github.com', '/itsSatyam27/novyn-chat/issues/new',
            {'title': 'Novyn app bug report'})
        : Uri(
            scheme: 'mailto',
            path: _appSupportEmail,
            queryParameters: {'subject': 'Novyn support request'});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      context.showNovynAlert(
          const SnackBar(content: Text('Could not open the support page.')));
    }
  }

  void _openFeedback() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()));

  void _showEntry(_HelpEntry e) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final surface = dark ? const Color(0xFF171622) : Colors.white;
        final ink = dark ? const Color(0xFFF2F0FF) : const Color(0xFF1C1B29);
        final muted = dark ? const Color(0xFFAAA7BE) : const Color(0xFF6B6880);
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: e.accent.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(e.icon, color: e.accent, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.kind.toUpperCase(),
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  e.title,
                  style: TextStyle(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.45,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  e.detail,
                  style: TextStyle(color: muted, fontSize: 14, height: 1.55),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5E4AE3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color ink) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: ink,
              onPressed: () => Navigator.maybePop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 14),
            Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );

  Widget _search(Color ink, Color muted, Color surface, Color border) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border.withValues(alpha: 0.5)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: TextStyle(color: ink, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Search help topics',
            hintStyle: TextStyle(color: muted, fontSize: 14.5),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF6246EA), size: 22),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: Icon(Icons.close_rounded, color: muted, size: 20),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      );

  Widget _actionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    bool external = false,
    required Color ink,
    required Color muted,
    required Color surface,
    required Color border,
  }) {
    return Expanded(
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 106,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withValues(alpha: 0.5)),
            ),
            child: Stack(
              children: [
                if (external)
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: muted.withValues(alpha: 0.7),
                      size: 13,
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 22, bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6246EA),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _topicItem(
    _HelpEntry e,
    Color ink,
    Color surface,
    Color border,
  ) {
    Color iconBg;
    if (e.icon == Icons.menu_book_rounded) {
      iconBg = const Color(0xFFEFE9FE);
    } else if (e.icon == Icons.lock_outline_rounded) {
      iconBg = const Color(0xFFE3F7EE);
    } else if (e.icon == Icons.cloud_upload_outlined) {
      iconBg = const Color(0xFFE5F1FD);
    } else if (e.icon == Icons.people_outline_rounded) {
      iconBg = const Color(0xFFFCE8F0);
    } else if (e.icon == Icons.call_outlined) {
      iconBg = const Color(0xFFE4F7F4);
    } else {
      iconBg = const Color(0xFFFCF4E4);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalIconBg = isDark ? e.accent.withValues(alpha: 0.16) : iconBg;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showEntry(e),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: finalIconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(e.icon, color: e.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqList(Color ink, Color muted, Color surface, Color border) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? const Color(0xFF2B2844) : const Color(0xFFEFEBFD);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: List.generate(_faqs.length, (i) {
          final e = _faqs[i];
          final expanded = _expandedFaq == e.title;
          final vote = _votes[e.title];

          return Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expandedFaq = expanded ? null : e.title),
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(24) : Radius.zero,
                  bottom: i == _faqs.length - 1 && !expanded
                      ? const Radius.circular(24)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.title,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: pillBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF6246EA),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.detail,
                        style: TextStyle(color: muted, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Was this helpful?',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _voteButton(
                            Icons.thumb_up_alt_outlined,
                            vote == true,
                            () => setState(() => _votes[e.title] = true),
                          ),
                          const SizedBox(width: 8),
                          _voteButton(
                            Icons.thumb_down_alt_outlined,
                            vote == false,
                            () => setState(() => _votes[e.title] = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (i != _faqs.length - 1)
                Divider(
                  height: 1,
                  color: border.withValues(alpha: 0.4),
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _voteButton(IconData icon, bool selected, VoidCallback tap) {
    return Material(
      color: selected ? const Color(0xFFEAE4FF) : const Color(0xFFF5F3FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 30,
          child: Icon(
            icon,
            color: selected ? const Color(0xFF6246EA) : const Color(0xFF777389),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _searchResults(Color ink, Color muted, Color surface, Color border) {
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '${results.length} RESULTS',
            style: const TextStyle(
              color: Color(0xFF6246EA),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (results.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                'No matching topics found. Try another search.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13.5),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: List.generate(results.length, (i) {
                final e = results[i];
                return Column(
                  children: [
                    ListTile(
                      onTap: () => _showEntry(e),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: e.accent.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(e.icon, color: e.accent, size: 20),
                      ),
                      title: Text(
                        e.title,
                        style: TextStyle(
                            color: ink, fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(e.kind,
                          style: TextStyle(color: muted, fontSize: 11.5)),
                      trailing: Icon(Icons.chevron_right_rounded, color: muted),
                    ),
                    if (i != results.length - 1)
                      Divider(
                        height: 1,
                        color: border.withValues(alpha: 0.4),
                        indent: 68,
                        endIndent: 16,
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = dark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB);
    final surface = dark ? const Color(0xFF191824) : Colors.white;
    final ink = dark ? const Color(0xFFF0EFFF) : const Color(0xFF1D1B26);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94);
    final border = dark ? const Color(0xFF39345F) : const Color(0xFFE4DFFB);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _header(ink),
            _search(ink, muted, surface, border),
            const SizedBox(height: 16),
            if (_query.isEmpty) ...[
              Row(
                children: [
                  _actionCard(
                    title: 'Contact\nsupport',
                    icon: Icons.headset_mic_rounded,
                    iconColor: const Color(0xFF6246EA),
                    iconBg: dark
                        ? const Color(0xFF2C2455)
                        : const Color(0xFFEBE7FD),
                    onTap: () => _openIssues(),
                    external: true,
                    ink: ink,
                    muted: muted,
                    surface: surface,
                    border: border,
                  ),
                  const SizedBox(width: 10),
                  _actionCard(
                    title: 'Report a bug',
                    icon: Icons.pest_control_rounded,
                    iconColor: const Color(0xFFE25241),
                    iconBg: dark
                        ? const Color(0xFF3F2124)
                        : const Color(0xFFFDECEB),
                    onTap: () => _openIssues(newBug: true),
                    external: true,
                    ink: ink,
                    muted: muted,
                    surface: surface,
                    border: border,
                  ),
                  const SizedBox(width: 10),
                  _actionCard(
                    title: 'Send feedback',
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: const Color(0xFFD4973B),
                    iconBg: dark
                        ? const Color(0xFF3D3220)
                        : const Color(0xFFFBF4E6),
                    onTap: _openFeedback,
                    external: false,
                    ink: ink,
                    muted: muted,
                    surface: surface,
                    border: border,
                  ),
                ],
              ),
              _section('Help topics'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topics.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 64,
                ),
                itemBuilder: (context, i) =>
                    _topicItem(_topics[i], ink, surface, border),
              ),
              _section('Popular questions'),
              _faqList(ink, muted, surface, border),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _openIssues(),
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  label: const Text(
                    'Open support page',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5E4AE3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ] else ...[
              _searchResults(ink, muted, surface, border),
            ],
            const SizedBox(height: 28),
            Center(
              child: Text(
                'NOVYN · YOUR SPACE, YOUR PEOPLE',
                style: TextStyle(
                  color: muted.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
