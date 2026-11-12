import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import '../widgets/profile_widgets.dart';
import 'package:novyn/services/haptic_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _adding = false;
  String _query = '';

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _addBlockedUser(SocketService socket) async {
    final username = _usernameController.text.trim().replaceFirst(RegExp(r'^@+'), '');
    if (username.isEmpty || _adding) return;
    FocusScope.of(context).unfocus();
    setState(() => _adding = true);
    HapticService.vibrate(NovynHapticType.selection);
    try {
      final result = await socket.setBlockedUser(username, blocked: true);
      if (!mounted) return;
      if (result['ok'] == true) {
        _usernameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('@$username has been blocked.'), behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']?.toString() ?? 'Could not block this user.'),
          behavior: SnackBarBehavior.floating));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
        behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _unblock(SocketService socket, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock this user?'),
        content: Text('@$username will be able to contact you again, subject to your privacy settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep blocked')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticService.vibrate(NovynHapticType.medium);
    try {
      final result = await socket.setBlockedUser(username, blocked: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['ok'] == true
            ? '@$username has been unblocked.'
            : result['message']?.toString() ?? 'Could not unblock this user.'),
        behavior: SnackBarBehavior.floating));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: socket,
          builder: (context, _) {
            final allUsers = socket.blockedUsers;
            final query = _query.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
            final visibleUsers = allUsers.where((name) => name.toLowerCase().contains(query)).toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                SettingsPageHeader(title: 'Blocked Users', subtitle: 'Choose who can reach you on Novyn'),
                const SizedBox(height: 20),
                _BlockedHeroCard(count: allUsers.length),
                const SizedBox(height: 22),
                Text('BLOCK SOMEONE', style: TextStyle(
                  color: colors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.35)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: NovynTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.outlineVariant)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add by username', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('Enter their Novyn username. You can unblock them anytime.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.4)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _usernameController, textInputAction: TextInputAction.done,
                        autocorrect: false, enableSuggestions: false,
                        onSubmitted: (_) => _addBlockedUser(socket),
                        decoration: InputDecoration(
                          hintText: '@username', prefixIcon: const Icon(Icons.alternate_email_rounded),
                          filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: .55),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                      )),
                      const SizedBox(width: 10),
                      SizedBox(height: 54, child: FilledButton(
                        onPressed: _adding ? null : () => _addBlockedUser(socket),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 17),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: _adding
                            ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.block_rounded))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Text('YOUR BLOCK LIST', style: TextStyle(
                    color: colors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.35))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)),
                    child: Text(allUsers.length.toString(), style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12))),
                ]),
                const SizedBox(height: 10),
                if (allUsers.isNotEmpty) ...[
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Find a blocked user', prefixIcon: const Icon(Icons.search_rounded),
                      filled: true, fillColor: NovynTheme.cardBg(context),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant))),
                  ),
                  const SizedBox(height: 12),
                ],
                if (allUsers.isEmpty)
                  const _BlockedEmptyState()
                else if (visibleUsers.isEmpty)
                  _BlockedSearchEmptyState(query: _query)
                else
                  ...visibleUsers.map((username) => _BlockedUserTile(
                    username: username, onUnblock: () => _unblock(socket, username))),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: .48),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Blocked contacts are managed by your Novyn account and stay in sync with the server. Blocking someone does not notify them.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.45))),
                  ]),
                ),
                const SizedBox(height: 24),
                Center(child: Text('NOVYN  ·  YOUR SPACE, YOUR PEOPLE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4, fontWeight: FontWeight.w700, color: muted.withValues(alpha: .6)))),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BlockedHeroCard extends StatelessWidget {
  const _BlockedHeroCard({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF7867EA), Color(0xFF5142C8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF6253D8).withValues(alpha: .20),
          blurRadius: 22, offset: const Offset(0, 10))]),
      child: Row(children: [
        Container(width: 58, height: 58,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white.withValues(alpha: .18))),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 29)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your space, your choice',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(count.toString() + (count == 1 ? ' person currently blocked' : ' people currently blocked'),
            style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12.5, fontWeight: FontWeight.w600)),
        ])),
        const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 23),
      ]),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({required this.username, required this.onUnblock});
  final String username;
  final VoidCallback onUnblock;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
      decoration: BoxDecoration(color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(19), border: Border.all(color: colors.outlineVariant)),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(color: const Color(0xFFEF5350).withValues(alpha: .11),
            borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.person_off_rounded, color: Color(0xFFE05252), size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Blocked contact', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ])),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onUnblock,
          style: OutlinedButton.styleFrom(foregroundColor: colors.onSurface,
            side: BorderSide(color: colors.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
      ]),
    );
  }
}

class _BlockedEmptyState extends StatelessWidget {
  const _BlockedEmptyState();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.outlineVariant)),
      child: Column(children: [
        Container(width: 66, height: 66,
          decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(22)),
          child: Icon(Icons.shield_outlined, size: 31, color: colors.primary)),
        const SizedBox(height: 13),
        Text('Your block list is clear',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('People you block will appear here. Add a username above whenever you need to.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
      ]),
    );
  }
}

class _BlockedSearchEmptyState extends StatelessWidget {
  const _BlockedSearchEmptyState({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(child: Text('No blocked user matches "$query".',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
    );
  }
}
