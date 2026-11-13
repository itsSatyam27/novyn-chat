import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_toast.dart';

class ProfileInfoScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSharedMedia;
  final VoidCallback? onWallpaper;
  final VoidCallback? onQuickEmojis;
  final bool initiallyBlocked;
  final bool initiallyMuted;
  final VoidCallback? onMute;
  final VoidCallback? onBlock;
  final VoidCallback? onClearChat;
  final VoidCallback? onRemoveFriend;
  final VoidCallback? onExportChat;
  final bool chatProtected;

  const ProfileInfoScreen({
    super.key,
    required this.user,
    this.onVoiceCall,
    this.onVideoCall,
    this.onSharedMedia,
    this.onWallpaper,
    this.onQuickEmojis,
    this.initiallyBlocked = false,
    this.initiallyMuted = false,
    this.onMute,
    this.onBlock,
    this.onClearChat,
    this.onRemoveFriend,
    this.onExportChat,
    this.chatProtected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final online = user.isOnline;
    final mutedText = scheme.onSurfaceVariant;
    var isMuted = initiallyMuted;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to chat',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile info',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              '@${user.username}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .08),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 94,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [scheme.primaryContainer, scheme.secondaryContainer],
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 43, left: 0, right: 0,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.surfaceContainerLow,
                                  border: Border.all(color: scheme.outlineVariant, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: scheme.shadow.withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 7)),
                                  ],
                                ),
                                child: Hero(
                                  tag: 'avatar_${user.uid}',
                                  child: UserAvatar(
                                    name: user.name, photoUrl: user.photoUrl, radius: 48,
                                    showOnlineIndicator: false, isOnline: online, presence: user.status,
                                  ),
                                ),
                              ),
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: online ? const Color(0xFF10B981) : mutedText,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.surfaceContainerLow, width: 3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(children: [
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 23,
                    letterSpacing: -.45,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: '@${user.username}'));
                    if (context.mounted) {
                      NovynToast.show(context, 'Username copied');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alternate_email_rounded, size: 15, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          user.username,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 7),
                        Icon(Icons.copy_rounded, size: 12, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: (online ? const Color(0xFF10B981) : mutedText).withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: online ? const Color(0xFF10B981) : mutedText,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        online ? 'Online now' : (user.status.isNotEmpty ? user.status : 'Offline'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: online ? const Color(0xFF059669) : mutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, size: 17, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('On Novyn since ${_date(user.createdAt)}',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 22),
                if (onVoiceCall != null || onVideoCall != null) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (onVoiceCall != null)
                        Expanded(child: _ActionButton(icon: Icons.call_rounded, label: 'Audio call', onTap: onVoiceCall!, primary: true)),
                      if (onVoiceCall != null && onVideoCall != null) const SizedBox(width: 10),
                      if (onVideoCall != null)
                        Expanded(child: _ActionButton(icon: Icons.videocam_rounded, label: 'Video call', onTap: onVideoCall!)),
                    ],
                  ),
                ],
                ]),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (user.bio.trim().isNotEmpty) ...[
            _SectionTitle(title: 'ABOUT'),
            _InfoCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.stars_rounded, color: scheme.primary, size: 19),
                  const SizedBox(width: 12),
                  Expanded(child: Text(user.bio, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.55, color: scheme.onSurface))),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(children: [
            if (onSharedMedia != null)
              Expanded(child: _FeatureTile(icon: Icons.image_outlined, title: 'Shared media', subtitle: 'Photos, videos, files', tint: const Color(0xFFE4F1FC), accent: const Color(0xFF347DBB), onTap: onSharedMedia!)),
            if (onSharedMedia != null && onWallpaper != null) const SizedBox(width: 10),
            if (onWallpaper != null)
              Expanded(child: _FeatureTile(icon: Icons.palette_outlined, title: 'Wallpaper', subtitle: 'Personalise chat', tint: const Color(0xFFFCE8F1), accent: const Color(0xFFC92B72), onTap: onWallpaper!)),
            if ((onSharedMedia != null || onWallpaper != null) && onQuickEmojis != null) const SizedBox(width: 10),
            if (onQuickEmojis != null)
              Expanded(child: _FeatureTile(icon: Icons.qr_code_2_rounded, title: 'QR code', subtitle: 'Scannable profile', tint: const Color(0xFFEEE9FF), accent: const Color(0xFF6554D9), onTap: () => _showContactQr(context))),
          ]),
          const SizedBox(height: 26),
          const _SectionHeading(title: 'CHAT SETTINGS', color: Color(0xFF6554D9)),
          _SettingsCard(children: [
            if (onMute != null)
              StatefulBuilder(
                builder: (context, refreshMute) {
                  void toggleMute() {
                    refreshMute(() => isMuted = !isMuted);
                    onMute!();
                  }
                  return _SettingsTile(
                    icon: isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_outlined,
                    title: 'Mute notifications',
                    subtitle: isMuted ? 'Notifications are muted for this contact' : 'Silence alerts from this contact',
                    tint: const Color(0xFFFFF0D9), accent: const Color(0xFFB87512),
                    trailing: Switch.adaptive(value: isMuted, onChanged: (_) => toggleMute()),
                    onTap: toggleMute,
                  );
                },
              ),
            if (onMute != null && onExportChat != null)
              const _SettingsDivider(),
            if (onExportChat != null)
              _SettingsTile(icon: Icons.ios_share_rounded, title: 'Export chat',
                subtitle: chatProtected
                    ? 'Only your messages will be included'
                    : 'Export as HTML or text file',
                tint: const Color(0xFFE0F4ED), accent: const Color(0xFF168B61),
                onTap: onExportChat!),
          ]),
          const SizedBox(height: 26),
          const _SectionHeading(title: 'DANGER ZONE', color: Color(0xFFC52D25)),
          _SettingsCard(danger: true, children: [
            if (onBlock != null)
              _SettingsTile(icon: initiallyBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                title: initiallyBlocked ? 'Unblock contact' : 'Block contact',
                subtitle: initiallyBlocked ? 'Allow this contact to reach you' : 'Stop messages and calls from this contact',
                tint: const Color(0xFFFCE8E8), accent: const Color(0xFFC52D25), danger: true, onTap: onBlock!),
            if (onBlock != null && onClearChat != null) const _SettingsDivider(danger: true),
            if (onClearChat != null)
              _SettingsTile(icon: Icons.delete_outline_rounded, title: 'Clear chat history',
                subtitle: 'Remove messages from this conversation',
                tint: const Color(0xFFFCE8E8), accent: const Color(0xFFC52D25), danger: true,
                onTap: () => _confirmContactAction(context, 'Clear chat history?', 'This clears the conversation history from your account and cannot be undone.', 'Clear', onClearChat!)),
            if ((onBlock != null || onClearChat != null) && onRemoveFriend != null) const _SettingsDivider(danger: true),
            if (onRemoveFriend != null)
              _SettingsTile(icon: Icons.person_remove_alt_1_rounded, title: 'Remove contact',
                subtitle: 'Remove this person from your friends',
                tint: const Color(0xFFFCE8E8), accent: const Color(0xFFC52D25), danger: true,
                onTap: () => _confirmContactAction(context, 'Remove contact?', 'You will need to send a new friend request to chat again.', 'Remove', onRemoveFriend!)),
          ]),

        ],
      ),
    );
  }

  void _showContactQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact QR code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: 'novyn://user/${user.username}', size: 220, backgroundColor: Colors.white),
            const SizedBox(height: 12),
            Text('@${user.username}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('Scan to identify this Novyn account', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: 'novyn://user/${user.username}'));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copy profile link'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmContactAction(BuildContext context, String title, String message, String action, VoidCallback callback) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) callback();
  }

  static String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} ${value.year}';
  static String _dateTime(DateTime value) => '${_date(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  static String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
    child: Text(title, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, letterSpacing: 1.15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7)),
    ),
    child: child,
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: primary ? scheme.primary : scheme.secondaryContainer,
        foregroundColor: primary ? scheme.onPrimary : scheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
          const SizedBox(width: 10),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface))),
        ],
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavigationRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 21),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  final Color tint; final Color accent; final VoidCallback onTap;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle, required this.tint, required this.accent, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(22),
    child: Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.fromLTRB(7, 14, 7, 12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: accent, size: 27)),
        const SizedBox(height: 10),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text(subtitle, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, height: 1.25, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  final String title; final Color color;
  const _SectionHeading({required this.title, required this.color});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Text(title, style: TextStyle(fontSize: 12, letterSpacing: 1.15, fontWeight: FontWeight.w900, color: color)),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children; final bool danger;
  const _SettingsCard({required this.children, this.danger = false});
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: danger ? scheme.error.withValues(alpha: .28) : scheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final bool danger; const _SettingsDivider({this.danger = false});
  @override Widget build(BuildContext context) => Divider(height: 1, thickness: 1, indent: 76, color: danger ? Theme.of(context).colorScheme.error.withValues(alpha: .18) : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  final Color tint; final Color accent; final Widget? trailing;
  final VoidCallback onTap; final bool danger;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.tint, required this.accent, required this.onTap, this.trailing, this.danger = false});
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: accent, size: 25)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: danger ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.25)),
        ])),
        trailing ?? Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
      ]),
    ),
  );
}
