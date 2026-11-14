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
  final GlobalKey _usernameFieldKey = GlobalKey();
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
    _hideUsernameSuggestions();
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
        final fieldObject = _usernameFieldKey.currentContext?.findRenderObject();
        final width = fieldObject is RenderBox && fieldObject.hasSize
            ? fieldObject.size.width
            : MediaQuery.sizeOf(overlayContext).width - 80;
        return Stack(
          children: [
            CompositedTransformFollower(
              link: _usernameFieldLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
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
    final canAdd = result.canRequest && status == 'none' && !_sendingRequest;
    final canCancel = status == 'sent' && !_sendingRequest;
    final statusLabel = switch (status) {
      'sent' => 'Request sent',
      'incoming' => 'Check requests',
      'friend' => 'Friends',
      _ => result.canRequest ? '' : 'Unavailable',
    };
    final actionIcon = canAdd
        ? Icons.person_add_alt_1_rounded
        : canCancel
            ? Icons.close_rounded
            : status == 'friend'
                ? Icons.check_circle_rounded
                : status == 'incoming'
                    ? Icons.mark_email_unread_rounded
                    : Icons.lock_outline_rounded;
    final theme = Theme.of(context);
    final actionColor = canAdd
        ? theme.colorScheme.primary
        : canCancel
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          UserAvatar(
            name: user.name.trim().isNotEmpty ? user.name.trim() : user.username,
            photoUrl: user.photoUrl.trim(),
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
                  user.name.trim().isNotEmpty ? user.name.trim() : user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(13, weight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel.isEmpty ? '@${user.username}' : '@${user.username} · $statusLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canAdd
                ? theme.colorScheme.primary.withValues(alpha: .12)
                : canCancel
                    ? theme.colorScheme.error.withValues(alpha: .12)
                    : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: canAdd
                  ? () => _sendFriendRequestTo(context.read<FriendService>(), user)
                  : canCancel
                      ? () => _cancelSentFriendRequest(context.read<FriendService>(), user)
                      : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: canCancel ? 74 : 40,
                height: 40,
                child: canCancel
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(actionIcon, size: 16, color: actionColor),
                          const SizedBox(width: 4),
                          Text(
                            'Cancel',
                            style: NovynText.body(11, weight: FontWeight.w600, color: actionColor),
                          ),
                        ],
                      )
                    : Icon(actionIcon, size: 19, color: actionColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      if (mounted) {
        setState(() => _sendingRequest = false);
        _showUsernameSuggestions();
      }
    }
  }

  Future<void> _cancelSentFriendRequest(FriendService service, UserModel user) async {
    if (_sendingRequest) return;
    setState(() => _sendingRequest = true);
    try {
      await service.cancelSentRequest(user.username);
      if (!mounted) return;
      final key = user.username.toLowerCase();
      setState(() {
        _requestedUsernameKeys.remove(key);
        _usernameSuggestions = _usernameSuggestions.map((result) {
          if (result.user.username.toLowerCase() != key) return result;
          return FriendSearchResult(
            user: result.user,
            requestStatus: 'none',
            canRequest: true,
          );
        }).toList();
      });
      _message('Request to @${user.username} cancelled.');
    } catch (_) {
      if (mounted) _message('Could not cancel request to @${user.username}.');
    } finally {
      if (mounted) {
        setState(() => _sendingRequest = false);
        _showUsernameSuggestions();
      }
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: foreground, size: 25),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Friend Requests', style: NovynText.display(25, color: foreground)),
                        const SizedBox(height: 2),
                        Text('Manage your connections', style: NovynText.body(14, color: muted)),
                      ],
                    ),
                  ),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      onTap: _showMyQrCode,
                      borderRadius: BorderRadius.circular(17),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  _addFriend(service),
                  const SizedBox(height: 18),
                  _sentSection(service),
                ],
              ),
            ),
          ],
        ),
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
    final muted = theme.brightness == Brightness.dark
        ? const Color(0xFFB7B2C9)
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF171622) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a friend', style: NovynText.display(19, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 3),
                    Text('Connect using their Novyn username.', style: NovynText.body(13, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CompositedTransformTarget(
            key: _usernameFieldKey,
            link: _usernameFieldLink,
            child: TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.send,
              onChanged: (value) => _onUsernameChanged(value, service),
              onSubmitted: (_) {
                _hideUsernameSuggestions();
                _sendFriendRequest(service);
              },
              style: NovynText.body(15, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Enter username',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: _searchingUsernames
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sendingRequest ? 'Sending request...' : 'Send friend request'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentSection(FriendService service) {
    final theme = Theme.of(context);
    return StreamBuilder<Set<String>>(
      stream: service.sentPendingUidsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final names = (snap.data ?? <String>{}).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text(
                'SENT REQUESTS · ${names.length}',
                style: NovynText.body(12, weight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant).copyWith(letterSpacing: 1.1),
              ),
            ),
            if (names.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? const Color(0xFF171622) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .38)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: .10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.send_outlined, color: theme.colorScheme.primary, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('No pending requests', style: NovynText.display(18, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 5),
                    Text(
                      'Requests you send will show up here until they accept.',
                      textAlign: TextAlign.center,
                      style: NovynText.body(14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? const Color(0xFF171622) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .38)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < names.length; i++) ...[
                      FutureBuilder<UserModel?>(
                        future: service.getUser(names[i]),
                        builder: (context, userSnap) {
                          final username = names[i];
                          final user = userSnap.data ?? UserModel(
                            uid: username,
                            username: username,
                            name: username,
                            email: '',
                            bio: '',
                            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                          );
                          final palette = <Color>[
                            const Color(0xFF6D4CF5),
                            const Color(0xFF117D73),
                            const Color(0xFF0876A8),
                            const Color(0xFFB85A0A),
                          ];
                          final avatarColor = palette[i % palette.length];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: avatarColor,
                                  backgroundImage: user.photoUrl.trim().isNotEmpty ? NetworkImage(user.photoUrl) : null,
                                  child: user.photoUrl.trim().isEmpty
                                      ? Text(
                                          user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : username[0].toUpperCase(),
                                          style: NovynText.display(18, color: Colors.white),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: NovynText.body(15, weight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                                      const SizedBox(height: 3),
                                      Text('@${user.username} · Pending response',
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: NovynText.body(12, color: theme.colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: _sendingRequest ? null : () => _cancelSentFriendRequest(service, user),
                                  icon: const Icon(Icons.close_rounded, size: 17),
                                  label: const Text('Cancel'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                    backgroundColor: theme.colorScheme.error.withValues(alpha: .08),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (i != names.length - 1)
                        Divider(height: 1, indent: 16, endIndent: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
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
