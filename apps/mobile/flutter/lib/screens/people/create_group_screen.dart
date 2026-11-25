import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/friend_service.dart';
import '../../services/haptic_service.dart';
import '../../services/socket_service.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/user_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  final String myUid;

  const CreateGroupScreen({super.key, required this.myUid});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _nameNotifier = ValueNotifier<String>('');
  final List<UserModel> _selected = <UserModel>[];
  String _search = '';
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _nameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final friends = context.read<FriendService>();
    final pageBackground = theme.brightness == Brightness.dark
        ? NovynTheme.pageBg(context)
        : Color.lerp(NovynTheme.pageBg(context), colors.primary, .025)!;

    return Scaffold(
      backgroundColor: pageBackground,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1, -1),
            radius: 1.15,
            colors: [
              colors.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? .08 : .055,
              ),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  children: [
                    _buildGroupNameInput(context),
                    const SizedBox(height: 20),
                    _buildMembersHeading(context),
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildSelectedMembers(context),
                    ],
                    const SizedBox(height: 12),
                    _buildSearchInput(context),
                    const SizedBox(height: 6),
                    _buildFriendList(friends),
                  ],
                ),
              ),
              _buildCreateButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Material(
              color: colors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.close_rounded,
                    size: 25,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'New Group',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupNameInput(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.groups_2_outlined, color: accent, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (value) => _nameNotifier.value = value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Group name',
                hintStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _nameNotifier,
            builder: (context, value, _) => value.isEmpty
                ? const SizedBox(width: 8)
                : IconButton(
                    tooltip: 'Clear group name',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _nameController.clear();
                      _nameNotifier.value = '';
                      _nameFocusNode.requestFocus();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                      size: 19,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersHeading(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Add members',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          '${_selected.length} selected',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: colors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMembers(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final user = _selected[index];
          return Container(
            padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .55),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  name: user.name,
                  photoUrl: user.photoUrl,
                  radius: 15,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    user.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Material(
                  color: colors.primary.withValues(alpha: .11),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _toggleMember(user),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 21, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14.5,
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search friends',
                hintStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  color: colors.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                      _searchFocusNode.requestFocus();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendList(FriendService service) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<UserModel>>(
      stream: service.friendsStream(widget.myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 42),
            child: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildListMessage(
            context,
            icon: Icons.cloud_off_rounded,
            title: 'Could not load friends',
            subtitle: 'Check your connection and try again.',
          );
        }

        final all = snapshot.data ?? const <UserModel>[];
        final filtered = all.where((user) {
          final name = user.name.toLowerCase();
          final username = user.username.toLowerCase();
          return name.contains(_search) || username.contains(_search);
        }).toList();

        if (filtered.isEmpty) {
          return _buildListMessage(
            context,
            icon: Icons.group_outlined,
            title: _search.isEmpty ? 'No friends yet' : 'No friends found',
            subtitle: _search.isEmpty
                ? 'Add friends before starting a group.'
                : 'Try another name or username.',
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              for (final user in filtered) _buildFriendRow(context, user),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 28),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: colors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRow(BuildContext context, UserModel user) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _selected.any((item) => item.uid == user.uid);
    final selectedFill = Color.alphaBlend(
      colors.primary.withValues(alpha: .085),
      colors.surface,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? selectedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _toggleMember(user),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                UserAvatar(
                  name: user.name,
                  photoUrl: user.photoUrl,
                  radius: 21,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: .58),
                      width: isSelected ? 1 : 1.6,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 19,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMember(UserModel user) {
    HapticService.vibrate(
      NovynHapticType.selection,
      category: HapticCategory.buttons,
    );
    setState(() {
      final selected = _selected.any((item) => item.uid == user.uid);
      if (selected) {
        _selected.removeWhere((item) => item.uid == user.uid);
      } else {
        _selected.add(user);
      }
    });
  }

  Widget _buildCreateButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: _nameNotifier,
      builder: (context, name, _) {
        final canCreate = name.trim().isNotEmpty &&
            _selected.isNotEmpty &&
            !_creating;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Material(
                color: canCreate ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(32),
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: canCreate ? _handleCreate : null,
                  child: Center(
                    child: _creating
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: colors.onPrimary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_rounded,
                                color: canCreate
                                    ? colors.onPrimary
                                    : colors.onSurfaceVariant,
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Create group · ${_selected.length} members',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: canCreate
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCreate() async {
    if (_creating ||
        _nameController.text.trim().isEmpty ||
        _selected.isEmpty) {
      return;
    }
    HapticService.vibrate(
      NovynHapticType.heavy,
      category: HapticCategory.buttons,
    );
    setState(() => _creating = true);

    try {
      final socket = context.read<SocketService>();
      final chatId = await socket.createGroup(
        name: _nameController.text.trim(),
        memberIds: _selected
            .map((user) => user.username.trim().isNotEmpty
                ? user.username.trim()
                : user.uid)
            .toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(chatId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create group: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
