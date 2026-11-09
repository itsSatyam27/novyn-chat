// contacts_screen.dart
import 'package:flutter/material.dart';

import 'novyn_ui.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _filters = ['All 7', 'Online 0', 'Favourites'];

  static const _pinned = [
    PinnedPerson('anushkadas', eyes: true),
    PinnedPerson('Miyouna', letter: 'M'),
  ];

  static const _friends = [
    _Friend(name: 'anushkadas', eyes: true),
    _Friend(name: 'Harsh', letter: 'H', colors: AvatarPalette.pink),
    _Friend(name: 'harsh', letter: 'H', colors: AvatarPalette.green),
    _Friend(name: 'Miyouna', letter: 'M', colors: AvatarPalette.blue),
    _Friend(name: 'Raju Kaka', letter: 'R', colors: AvatarPalette.blue),
  ];

  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return NovynScaffold(
      currentTab: 3,
      onTabSelected: widget.onTabSelected,
      body: Column(
        children: [
          const NovynHeader(
            title: 'Contacts',
            subtitle: '7 friends · 0 online',
            actions: [
              NovynIconButton(
                icon: Icons.person_add_alt_1_outlined,
                primary: true,
              ),
            ],
          ),
          const NovynSearchField(hint: 'Search friends…'),
          NovynChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
            bottomPadding: 8,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                const NovynSectionLabel(
                  'PINNED',
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                ),
                const PinnedAvatarRow(
                  people: _pinned,
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                ),
                const NovynSectionLabel(
                  'A – Z',
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                ),
                for (final f in _friends) _FriendTile(friend: f),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Friend {
  const _Friend({
    required this.name,
    this.letter,
    this.colors = AvatarPalette.blue,
    this.eyes = false,
  });

  final String name;
  final String? letter;
  final List<Color> colors;
  final bool eyes;
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final _Friend friend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          NovynAvatar(
            size: 46,
            letter: friend.letter,
            colors: friend.colors,
            eyes: friend.eyes,
            statusColor: NovynColors.offline,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: NovynText.body(16, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Offline',
                    style: NovynText.body(13, color: NovynColors.timeMuted)),
              ],
            ),
          ),
          const NovynIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            size: 36,
            radius: 12,
            iconSize: 17,
          ),
          const SizedBox(width: 14),
          const NovynIconButton(
            icon: Icons.call,
            primary: true,
            size: 36,
            radius: 12,
            iconSize: 17,
          ),
        ],
      ),
    );
  }
}
