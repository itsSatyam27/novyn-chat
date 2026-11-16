import 'package:flutter/material.dart';

/// The Chats overflow sheet follows the Novyn reference layout while keeping
/// each entry as a real, explicit action supplied by ChatsScreen.
class ChatOverflowMenu extends StatelessWidget {
  const ChatOverflowMenu({
    super.key,
    required this.archivedCount,
    required this.lockedCount,
    required this.onCreateGroup,
    required this.onInviteFriends,
    required this.onArchivedChats,
    required this.onLockedChats,
    required this.onStarredMessages,
    required this.onSelectChats,
    required this.onMarkAllRead,
    required this.onChatSettings,
  });

  final int archivedCount;
  final int lockedCount;
  final VoidCallback onCreateGroup;
  final VoidCallback onInviteFriends;
  final VoidCallback onArchivedChats;
  final VoidCallback onLockedChats;
  final VoidCallback onStarredMessages;
  final VoidCallback onSelectChats;
  final VoidCallback onMarkAllRead;
  final VoidCallback onChatSettings;

  void _show(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close chat actions',
      barrierColor: Colors.black.withValues(alpha: .26),
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(dialogContext);
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final panelColor = isDark ? const Color(0xFF191B2B) : Colors.white;
        final lineColor = isDark
            ? Colors.white.withValues(alpha: .08)
            : const Color(0xFFECE7F7);

        Widget item({
          required IconData icon,
          required String title,
          required Color tint,
          required VoidCallback action,
          Widget? trailing,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () {
                Navigator.of(dialogContext).pop();
                action();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: isDark ? .17 : .12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: tint, size: 23),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF20213E),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.15,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing,
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 3),
          child: Divider(height: 1, color: lineColor),
        );

        Widget countBadge(int count, Color color) => Container(
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: media.padding.top + 72,
              right: 14,
              child: SafeArea(
                child: Material(
                  color: panelColor,
                  elevation: 18,
                  shadowColor: Colors.black.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(29),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: (media.size.width - 28).clamp(280.0, 350.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: media.size.height * .76),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            item(
                              icon: Icons.group_add_rounded,
                              title: 'Create group',
                              tint: const Color(0xFF6853F2),
                              action: onCreateGroup,
                            ),
                            item(
                              icon: Icons.ios_share_rounded,
                              title: 'Invite friends',
                              tint: const Color(0xFF318A9A),
                              action: onInviteFriends,
                            ),
                            divider(),
                            item(
                              icon: Icons.archive_outlined,
                              title: 'Archived chats',
                              tint: const Color(0xFFB96D2A),
                              action: onArchivedChats,
                              trailing: archivedCount > 0
                                  ? countBadge(archivedCount, const Color(0xFF7053E8))
                                  : null,
                            ),
                            item(
                              icon: Icons.lock_outline_rounded,
                              title: 'Locked chats',
                              tint: const Color(0xFFC04B77),
                              action: onLockedChats,
                              trailing: const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF77718F),
                                size: 21,
                              ),
                            ),
                            item(
                              icon: Icons.star_outline_rounded,
                              title: 'Starred messages',
                              tint: const Color(0xFFB77921),
                              action: onStarredMessages,
                            ),
                            divider(),
                            item(
                              icon: Icons.check_box_outlined,
                              title: 'Select chats',
                              tint: const Color(0xFF64748B),
                              action: onSelectChats,
                            ),
                            item(
                              icon: Icons.done_all_rounded,
                              title: 'Mark all as read',
                              tint: const Color(0xFF43896F),
                              action: onMarkAllRead,
                            ),
                            divider(),
                            item(
                              icon: Icons.tune_rounded,
                              title: 'Chat settings',
                              tint: const Color(0xFF6853F2),
                              action: onChatSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: isDark ? const Color(0xFF191B2B) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _show(context),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.more_horiz_rounded, color: color, size: 25),
        ),
      ),
    );
  }
}
