import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/novyn_theme.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  final String myUid;
  final int initialTab;
  const DiscoverPeopleScreen({super.key, required this.myUid, this.initialTab = 0});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  late int _activeTab;
  final TextEditingController _usernameController = TextEditingController();
  final LayerLink _usernameFieldLink = LayerLink();
  OverlayEntry? _usernameSuggestionsOverlay;
  Timer? _usernameSearchDebounce;
  List<FriendSearchResult> _usernameSuggestions = [];
  final Set<String> _requestedUsernameKeys = {};
  int _usernameSearchGeneration = 0;
  bool _searchingUsernames = false;
  String? _usernameSearchError;
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 2).toInt();
  }

  @override
  void dispose() {
    _usernameSearchDebounce?.cancel();
    _usernameSearchGeneration++;
    _usernameSuggestionsOverlay?.remove();
    _usernameSuggestionsOverlay?.dispose();
    _usernameSuggestionsOverlay = null;
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest(FriendService service) async {
    final username = _usernameController.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isEmpty || _sendingRequest) return;
    setState(() => _sendingRequest = true);
    try {
      final user = await service.getUser(username);
      if (!mounted) return;
      if (user == null) {
        _message('No Novyn user found. Check the username and try again.');
        return;
      }
      if (user.username.toLowerCase() == widget.myUid.toLowerCase()) {
        _message('You cannot add yourself.');
        return;
      }
      await service.sendRequest(widget.myUid, user.uid);
      if (!mounted) return;
      _usernameController.clear();
      _message('Friend request sent to @${user.username}.');
      setState(() => _activeTab = 1);
    } catch (_) {
      _message('Could not send request. Please try again.');
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  void _onUsernameChanged(String value, FriendService service) {
    final query = value.trim().replaceFirst(RegExp(r'^@'), '');
    _usernameSearchDebounce?.cancel();
    final generation = ++_usernameSearchGeneration;

    if (query.length < 2) {
      _hideUsernameSuggestions();
      setState(() {
        _usernameSuggestions = [];
        _searchingUsernames = false;
        _usernameSearchError = null;
      });
      return;
    }

    setState(() {
      _usernameSuggestions = [];
      _searchingUsernames = true;
      _usernameSearchError = null;
    });
    _showUsernameSuggestions();

    _usernameSearchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final matches = await service.searchUsers(query);
        if (!mounted || generation != _usernameSearchGeneration) return;
        setState(() {
          _usernameSuggestions = matches
              .where((result) =>
                  result.user.username.toLowerCase() != widget.myUid.toLowerCase())
              .toList();
          _searchingUsernames = false;
          _usernameSearchError = null;
        });
        _showUsernameSuggestions();
      } catch (_) {
        if (!mounted || generation != _usernameSearchGeneration) return;
        setState(() {
          _usernameSuggestions = [];
          _searchingUsernames = false;
          _usernameSearchError = 'Could not search usernames. Check your connection.';
        });
        _showUsernameSuggestions();
      }
    });
  }

  void _showUsernameSuggestions() {
    if (!mounted || _activeTab != 2) return;
    if (_usernameSuggestionsOverlay != null) {
      _usernameSuggestionsOverlay!.markNeedsBuild();
      return;
    }

    _usernameSuggestionsOverlay = OverlayEntry(
      builder: (overlayContext) {
        final theme = Theme.of(context);
        final width = MediaQuery.sizeOf(overlayContext).width - 40;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideUsernameSuggestions,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _usernameFieldLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 7),
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 16,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: _usernameSuggestionsContent(theme),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_usernameSuggestionsOverlay!);
  }

  void _hideUsernameSuggestions() {
    _usernameSearchDebounce?.cancel();
    _usernameSearchGeneration++;
    final entry = _usernameSuggestionsOverlay;
    _usernameSuggestionsOverlay = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
  }

  Widget _usernameSuggestionsContent(ThemeData theme) {
    if (_searchingUsernames) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Searching usernames...'),
          ],
        ),
      );
    }

    if (_usernameSearchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Text(
          _usernameSearchError!,
          style: NovynText.body(12, color: theme.colorScheme.error),
        ),
      );
    }

    if (_usernameSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(Icons.person_search_rounded, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No matching usernames. Check the spelling and try again.',
                style: NovynText.body(12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _usernameSuggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 66,
        endIndent: 14,
        color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
      ),
      itemBuilder: (context, index) =>
          _usernameSuggestionTile(_usernameSuggestions[index]),
    );
  }

  Widget _usernameSuggestionTile(FriendSearchResult result) {
    final user = result.user;
    final key = user.username.toLowerCase();
    final status = _requestedUsernameKeys.contains(key)
        ? 'sent'
        : result.requestStatus;
    final canAdd = result.canRequest &&
        status == 'none' &&
        !_sendingRequest;
    final statusLabel = switch (status) {
      'sent' => 'Requested',
      'incoming' => 'Check requests',
      'friend' => 'Friends',
      _ => result.canRequest ? '' : 'Unavailable',
    };
    final actionIcon = canAdd
        ? Icons.person_add_alt_1_rounded
        : status == 'sent' || status == 'friend'
            ? Icons.check_circle_rounded
            : status == 'incoming'
                ? Icons.mark_email_unread_rounded
                : Icons.lock_outline_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 21,
            showOnlineIndicator: true,
            isOnline: user.isOnline,
            presence: user.status,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(
                    13,
                    weight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(
                    11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (statusLabel.isNotEmpty && !canAdd)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                statusLabel,
                style: NovynText.body(
                  10.5,
                  weight: FontWeight.w700,
                  color: status == 'sent' || status == 'friend'
                      ? themeOrPrimary(context)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Material(
            color: canAdd
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: canAdd
                  ? () => _sendFriendRequestTo(context.read<FriendService>(), user)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  actionIcon,
                  size: 19,
                  color: canAdd
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color themeOrPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  Future<void> _sendFriendRequestTo(FriendService service, UserModel user) async {
    if (_sendingRequest) return;
    setState(() => _sendingRequest = true);
    try {
      await service.sendRequest(widget.myUid, user.uid);
      if (!mounted) return;
      final key = user.username.toLowerCase();
      setState(() {
        _requestedUsernameKeys.add(key);
        _usernameSuggestions = _usernameSuggestions.map((result) {
          if (result.user.username.toLowerCase() != key) return result;
          return FriendSearchResult(
            user: result.user,
            requestStatus: 'sent',
            canRequest: false,
          );
        }).toList();
      });
      _showUsernameSuggestions();
      _message('Friend request sent to @${user.username}.');
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message?.toString() ?? 'Could not send friend request.'
          : 'Could not send request to @${user.username}. Please try again.';
      _message(message);
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  void _showMyQrCode() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your Novyn QR code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(
              data: 'https://novyn.app/user/${widget.myUid}',
              size: 210,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text('@${widget.myUid}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Let a friend scan this code to find your profile.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FriendService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? const Color(0xFFF4F1FF) : theme.colorScheme.onSurface;
    final muted = isDark ? const Color(0xFFB7B2C9) : theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Friend Requests',
          style: NovynText.display(20, color: foreground)),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Text('Manage your connections',
              style: NovynText.body(13, color: muted)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF171622) : const Color(0xFFF0EDFA),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
              ),
              child: Row(children: [
                _tab('Received', 0, service),
                _tab('Sent', 1, service),
                _tab('Add friend', 2, service),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_activeTab) {
                0 => _received(service),
                1 => _sent(service),
                _ => _addFriend(service),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, FriendService service) {
    final selected = _activeTab == index;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index != 2) _hideUsernameSuggestions();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? NovynGradients.selected(context) : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected ? [
              BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .2),
                blurRadius: 12, offset: const Offset(0, 4))
            ] : null,
          ),
          child: Center(child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: NovynText.body(13, weight: FontWeight.w700,
                color: selected ? Colors.white : (theme.brightness == Brightness.dark ? const Color(0xFFB7B2C9) : theme.colorScheme.onSurfaceVariant))),
              if (index == 0) ...[
                const SizedBox(width: 6),
                StreamBuilder<int>(
                  stream: service.pendingRequestsCountStream(widget.myUid),
                  builder: (_, snap) {
                    final count = snap.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: .2) : theme.colorScheme.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count', style: NovynText.body(10, weight: FontWeight.w800,
                        color: selected ? Colors.white : theme.colorScheme.primary)),
                    );
                  },
                ),
              ],
            ],
          )),
        ),
      ),
    );
  }

  Widget _addFriend(FriendService service) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('add-friend'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? const Color(0xFF171622) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add a friend', style: NovynText.display(17, color: theme.brightness == Brightness.dark ? const Color(0xFFF4F1FF) : theme.colorScheme.onSurface)),
                  const SizedBox(height: 3),
                  Text('Connect using their Novyn username.', style: NovynText.body(12, color: theme.brightness == Brightness.dark ? const Color(0xFFB7B2C9) : theme.colorScheme.onSurfaceVariant)),
                ])),
              ]),
              const SizedBox(height: 20),
              CompositedTransformTarget(
                link: _usernameFieldLink,
                child: TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.send,
                  onChanged: (value) => _onUsernameChanged(value, service),
                  onSubmitted: (_) {
                    _hideUsernameSuggestions();
                    _sendFriendRequest(service);
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter username',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    suffixIcon: _searchingUsernames
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sendingRequest ? null : () => _sendFriendRequest(service),
                  icon: _sendingRequest
                      ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(_sendingRequest ? 'Sending request...' : 'Send friend request'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .15)),
          ),
          child: Row(children: [
            Icon(Icons.qr_code_2_rounded, size: 34, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Share your QR code', style: NovynText.body(13, weight: FontWeight.w800, color: theme.brightness == Brightness.dark ? const Color(0xFFF4F1FF) : theme.colorScheme.onSurface)),
              const SizedBox(height: 3),
              Text('Let friends scan your profile to find you.', style: NovynText.body(11, color: theme.brightness == Brightness.dark ? const Color(0xFFB7B2C9) : theme.colorScheme.onSurfaceVariant)),
            ])),
            IconButton(
              tooltip: 'Show my QR code',
              onPressed: _showMyQrCode,
              icon: Icon(Icons.open_in_new_rounded, color: theme.colorScheme.primary),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _received(FriendService service) {
    return StreamBuilder<List<FriendRequest>>(
      key: const ValueKey('received-requests'),
      stream: service.pendingRequestsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return _empty(Icons.error_outline_rounded, 'Could not load requests', 'Please check your connection and try again.');
        final requests = snap.data ?? [];
        if (requests.isEmpty) return _empty(Icons.mark_email_read_outlined, 'No received requests', 'When someone sends you a friend request, it will appear here.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final request = requests[i];
            final user = request.fromUser;
            if (user == null) return const SizedBox.shrink();
            return _RequestCard(
              user: user,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _actionIcon(Icons.close_rounded, NovynColors.danger, () async {
                  try { await service.declineRequest(request.id); }
                  catch (_) { _message('Could not decline request.'); }
                }),
                const SizedBox(width: 7),
                _actionIcon(Icons.check_rounded, NovynColors.mint, () async {
                  try {
                    await service.acceptRequest(request.id, widget.myUid, request.fromUid);
                    _message('You are now friends with @${user.username}.');
                  } catch (_) { _message('Could not accept request.'); }
                }),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _sent(FriendService service) {
    return StreamBuilder<Set<String>>(
      key: const ValueKey('sent-requests'),
      stream: service.sentPendingUidsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final names = (snap.data ?? <String>{}).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (names.isEmpty) return _empty(Icons.send_rounded, 'No sent requests', 'Friend requests you send will be listed here.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final username = names[i];
            return FutureBuilder<UserModel?>(
              future: service.getUser(username),
              builder: (context, userSnap) {
                final user = userSnap.data ?? UserModel(
                  uid: username, username: username, name: username,
                  email: '', bio: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                );
                return _RequestCard(
                  user: user,
                  trailing: OutlinedButton(
                    onPressed: () async {
                      try {
                        await service.cancelSentRequest(username);
                        _message('Request to @${username} cancelled.');
                      } catch (_) { _message('Could not cancel request.'); }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NovynColors.danger,
                      side: BorderSide(color: NovynColors.danger.withValues(alpha: .45)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    ),
                    child: Text('Cancel', style: NovynText.body(12, weight: FontWeight.w700, color: NovynColors.danger)),
                  ),
                  subtitle: 'Pending response',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) {
    return NovynEmptyState(icon: icon, title: title, description: subtitle);
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: color, size: 19)),
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _RequestCard extends StatelessWidget {
  final UserModel user;
  final Widget trailing;
  final String? subtitle;
  const _RequestCard({required this.user, required this.trailing, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF13141D) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .48)),
      ),
      child: Row(children: [
        UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 23,
          showOnlineIndicator: true, isOnline: user.isOnline, presence: user.status),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: NovynText.body(13.5, weight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 3),
          Text('@${user.username}', style: NovynText.body(11.5, color: theme.colorScheme.onSurfaceVariant)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: NovynText.body(10.5, color: theme.colorScheme.primary, weight: FontWeight.w600)),
          ],
        ])),
        const SizedBox(width: 8),
        trailing,
      ]),
    );
  }
}
