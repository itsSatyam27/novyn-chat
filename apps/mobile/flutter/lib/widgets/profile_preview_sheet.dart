import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import '../widgets/user_avatar.dart';
import 'package:novyn/services/haptic_service.dart';

class ProfilePreviewSheet extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSharedMedia;
  final VoidCallback? onWallpaper;
  final bool showActions;

  const ProfilePreviewSheet({
    super.key,
    required this.user,
    this.onVoiceCall,
    this.onVideoCall,
    this.onSharedMedia,
    this.onWallpaper,
    this.showActions = true,
  });

  @override
  State<ProfilePreviewSheet> createState() => _ProfilePreviewSheetState();
}

class _ProfilePreviewSheetState extends State<ProfilePreviewSheet> {
  bool _muted = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final socket = context.watch<SocketService>();
    final isBlocked = socket.blockedUsers.any(
      (username) => username.toLowerCase() == user.username.toLowerCase(),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final statusColor = user.isOnline
        ? const Color(0xFF10B981)
        : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'USER PROFILE',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13141D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              gradient: const RadialGradient(
                center: Alignment(-0.7, -1),
                radius: 1.1,
                colors: [Color(0x406D5DFC), Color(0x006D5DFC)],
              ),
            ),
            child: Row(
              children: [
                UserAvatar(
                  name: user.name,
                  photoUrl: user.photoUrl,
                  radius: 36,
                  showOnlineIndicator: true,
                  isOnline: user.isOnline,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.showActions) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.call_rounded,
                    label: 'Voice\ncall',
                    color: accent,
                    onTap: widget.onVoiceCall ?? () {},
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.videocam_rounded,
                    label: 'Video\ncall',
                    color: const Color(0xFF0EA5E9),
                    onTap: widget.onVideoCall ?? () {},
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: _muted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_rounded,
                    label: _muted ? 'Unmute' : 'Mute',
                    color: _muted
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection);
                      setState(() => _muted = !_muted);
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.block_rounded,
                    label: isBlocked ? 'Unblock' : 'Block',
                    color: const Color(0xFFEF4444),
                    onTap: () => _confirmBlock(context, isBlocked),
                  ),
                ],
              ),
            ),
          ],

          if (widget.onSharedMedia != null || widget.onWallpaper != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (widget.onSharedMedia != null)
                    _InfoTile(
                      icon: Icons.perm_media_outlined,
                      label: 'Shared media',
                      onTap: widget.onSharedMedia!,
                    ),
                  if (widget.onWallpaper != null)
                    _InfoTile(
                      icon: Icons.wallpaper_rounded,
                      label: 'Chat wallpaper',
                      onTap: widget.onWallpaper!,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
              thickness: 1),

          if (user.bio.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BIO',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.bio,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                height: 1,
                thickness: 1),
          ],
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context, bool currentlyBlocked) async {
    final action = currentlyBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$action ${widget.user.name}?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          currentlyBlocked
              ? 'They will be able to message and call you again.'
              : 'They won\'t be able to message or call you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await context.read<SocketService>().setBlockedUser(
        widget.user.username,
        blocked: !currentlyBlocked,
      );
      if (!context.mounted) return;
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentlyBlocked
              ? 'User unblocked successfully.'
              : 'User blocked successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            result['message']?.toString() ?? 'Could not update block settings.',
          )),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.36),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13141D) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 19,
                    color: isDark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
