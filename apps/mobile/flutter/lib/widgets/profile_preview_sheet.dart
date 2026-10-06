import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../widgets/user_avatar.dart';

class ProfilePreviewSheet extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final bool showActions;

  const ProfilePreviewSheet({
    super.key,
    required this.user,
    this.onVoiceCall,
    this.onVideoCall,
    this.showActions = true,
  });

  @override
  State<ProfilePreviewSheet> createState() => _ProfilePreviewSheetState();
}

class _ProfilePreviewSheetState extends State<ProfilePreviewSheet> {
  bool _muted = false;
  bool _blocked = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    final statusColor = user.isOnline
        ? const Color(0xFF10B981)
        : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    fontFamily: 'Inter',
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                UserAvatar(
                  name: user.name,
                  photoUrl: user.photoUrl,
                  radius: 32,
                  showOnlineIndicator: true,
                  isOnline: user.isOnline,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontFamily: 'Inter',
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
                    color: const Color(0xFF7C6FF7),
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
                        : const Color(0xFF64748B),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _muted = !_muted);
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.block_rounded,
                    label: _blocked ? 'Unblock' : 'Block',
                    color: const Color(0xFFEF4444),
                    onTap: () => _confirmBlock(context),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: theme.colorScheme.surfaceContainerHighest, thickness: 6),

          if (user.bio.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BIO',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.surfaceContainerHighest, thickness: 6),
          ],
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmBlock(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _blocked ? 'Unblock ${widget.user.name}?' : 'Block ${widget.user.name}?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _blocked
              ? 'They will be able to message and call you again.'
              : 'They won\'t be able to message or call you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _blocked = !_blocked);
            },
            child: Text(
              _blocked ? 'Unblock' : 'Block',
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
