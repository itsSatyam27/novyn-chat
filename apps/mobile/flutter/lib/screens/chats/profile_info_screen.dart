import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';

class ProfileInfoScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSharedMedia;
  final VoidCallback? onWallpaper;
  final bool initiallyBlocked;
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
    this.initiallyBlocked = false,
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

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to chat',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile info',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
            ),
            child: Column(
              children: [
                Hero(
                  tag: 'avatar_${user.uid}',
                  child: UserAvatar(
                    name: user.name,
                    photoUrl: user.photoUrl,
                    radius: 48,
                    showOnlineIndicator: true,
                    isOnline: online,
                    presence: user.status,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                const SizedBox(height: 7),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: '@${user.username}'));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Username copied')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alternate_email_rounded, size: 15, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(user.username, style: TextStyle(fontFamily: 'PlusJakartaSans', color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 13, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: (online ? const Color(0xFF10B981) : mutedText).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: online ? const Color(0xFF10B981) : mutedText, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Text(online ? 'Online' : (user.status.isNotEmpty ? user.status : 'Offline'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: online ? const Color(0xFF059669) : mutedText)),
                    ],
                  ),
                ),
                if (onVoiceCall != null || onVideoCall != null) ...[
                  const SizedBox(height: 20),
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
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          _SectionTitle(title: 'CONTACT DETAILS'),
          _InfoCard(
            child: Column(
              children: [
                _DetailRow(icon: Icons.alternate_email_rounded, label: 'Username', value: '@${user.username}'),
                if (user.gender.trim().isNotEmpty) _DetailRow(icon: Icons.person_outline_rounded, label: 'Gender', value: user.gender),
                if (user.age != null) _DetailRow(icon: Icons.cake_outlined, label: 'Age', value: user.age.toString()),
                _DetailRow(icon: Icons.calendar_today_outlined, label: 'On Novyn since', value: _date(user.createdAt)),
                if (!online && user.lastSeen != null)
                  _DetailRow(icon: Icons.access_time_rounded, label: 'Last seen', value: _dateTime(user.lastSeen!)),
              ],
            ),
          ),
          if (onSharedMedia != null || onWallpaper != null) ...[
            const SizedBox(height: 18),
            _SectionTitle(title: 'CHAT'),
            _InfoCard(
              child: Column(
                children: [
                  if (onSharedMedia != null)
                    _NavigationRow(icon: Icons.photo_library_outlined, title: 'Shared media', subtitle: 'Photos, videos and files', onTap: onSharedMedia!),
                  if (onSharedMedia != null && onWallpaper != null)
                    Divider(height: 18, color: scheme.outlineVariant.withValues(alpha: .6)),
                  if (onWallpaper != null)
                    _NavigationRow(icon: Icons.wallpaper_rounded, title: 'Chat wallpaper', subtitle: 'Personalise this conversation', onTap: onWallpaper!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _SectionTitle(title: 'NOTIFICATIONS & SAFETY'),
          _InfoCard(
            child: Column(
              children: [
                if (onMute != null)
                  _NavigationRow(icon: Icons.notifications_off_outlined, title: 'Mute notifications', subtitle: 'Silence alerts from this contact', onTap: onMute!),
                if (onMute != null) Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .6)),
                if (onBlock != null)
                  _NavigationRow(icon: initiallyBlocked ? Icons.lock_open_rounded : Icons.block_rounded, title: initiallyBlocked ? 'Unblock contact' : 'Block contact', subtitle: initiallyBlocked ? 'Allow this contact to reach you' : 'Stop messages and calls from this contact', onTap: onBlock!),
                if (onBlock != null) Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .6)),
                _NavigationRow(icon: Icons.qr_code_2_rounded, title: 'Contact QR code', subtitle: 'Show a scannable profile code', onTap: () => _showContactQr(context)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'CHAT MANAGEMENT'),
          _InfoCard(
            child: Column(
              children: [
                if (chatProtected)
                  _NavigationRow(icon: Icons.shield_rounded, title: 'Chat export disabled', subtitle: 'This contact enabled Stealth Mode', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export is disabled because this contact enabled Stealth Mode.')),
                    );
                  }),
                if (!chatProtected && onExportChat != null)
                  _NavigationRow(icon: Icons.ios_share_rounded, title: 'Export chat', subtitle: 'Save this conversation as a file', onTap: onExportChat!),
                if ((chatProtected || onExportChat != null) && onClearChat != null) Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .6)),
                if (onClearChat != null)
                  _NavigationRow(icon: Icons.delete_sweep_outlined, title: 'Clear chat history', subtitle: 'Remove messages from this conversation', onTap: () => _confirmContactAction(context, 'Clear chat history?', 'This clears the conversation history from your account and cannot be undone.', 'Clear', onClearChat!)),
                if (onClearChat != null && onRemoveFriend != null) Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .6)),
                if (onRemoveFriend != null)
                  _NavigationRow(icon: Icons.person_remove_alt_1_rounded, title: 'Remove contact', subtitle: 'Remove this person from your friends', onTap: () => _confirmContactAction(context, 'Remove contact?', 'You will need to send a new friend request to chat again.', 'Remove', onRemoveFriend!)),
              ],
            ),
          ),
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
