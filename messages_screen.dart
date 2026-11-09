// messages_screen.dart
import 'package:flutter/material.dart';

import 'novyn_ui.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const _filters = ['All', 'Unread', 'Favourites', 'Groups'];

  static const _pinned = [
    PinnedPerson('anushkadas', eyes: true),
    PinnedPerson('Miyouna', letter: 'M'),
  ];

  static const _chats = [
    _Chat(
      name: 'Raju Kaka',
      letter: 'R',
      colors: AvatarPalette.blue,
      time: '11:51 am',
      preview: 'Started a game',
      tag: _ChatTag('Up or Down', Icons.sports_esports_outlined),
    ),
    _Chat(
      name: 'Harsh',
      letter: 'H',
      colors: AvatarPalette.pink,
      time: '12 Oct',
      preview: 'Started a game',
      tag: _ChatTag('Doodle Duel', Icons.sports_esports_outlined),
    ),
    _Chat(
      name: 'anushkadas',
      eyes: true,
      time: '12 Oct',
      preview: 'Tap to unlock',
      tag: _ChatTag('Riddle lock', Icons.lock_outline_rounded),
    ),
    _Chat(
      name: 'Miyouna',
      letter: 'M',
      colors: AvatarPalette.blue,
      time: '18 Aug',
      preview: 'Tap to chat',
    ),
    _Chat(
      name: 'harsh',
      letter: 'H',
      colors: AvatarPalette.green,
      time: '18 Aug',
      preview: 'Tap to chat',
    ),
  ];

  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return NovynScaffold(
      currentTab: 0,
      onTabSelected: widget.onTabSelected,
      body: Column(
        children: [
          const NovynHeader(
            title: 'Messages',
            subtitle: '8 chats · all caught up',
            actions: [
              NovynIconButton(icon: Icons.vpn_key_outlined),
              NovynIconButton(icon: Icons.edit_outlined, primary: true),
            ],
          ),
          const NovynSearchField(hint: 'Search conversations…'),
          NovynChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                const NovynSectionLabel(
                  'PINNED',
                  icon: Icons.push_pin_outlined,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                ),
                const PinnedAvatarRow(people: _pinned),
                const NovynSectionLabel('ALL CHATS'),
                for (final chat in _chats) _ChatTile(chat: chat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTag {
  const _ChatTag(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Chat {
  const _Chat({
    required this.name,
    required this.time,
    required this.preview,
    this.letter,
    this.colors = AvatarPalette.blue,
    this.eyes = false,
    this.tag,
  });

  final String name;
  final String time;
  final String preview;
  final String? letter;
  final List<Color> colors;
  final bool eyes;
  final _ChatTag? tag;
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final _Chat chat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          NovynAvatar(
            size: 50,
            letter: chat.letter,
            colors: chat.colors,
            eyes: chat.eyes,
            statusColor: NovynColors.offline,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(chat.name,
                        style: NovynText.body(16, weight: FontWeight.w700)),
                    Text(chat.time,
                        style: NovynText.body(12,
                            color: NovynColors.timeMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (chat.tag != null) _TagChip(tag: chat.tag!),
                    Flexible(
                      child: Text(
                        chat.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            NovynText.body(13, color: NovynColors.textSub),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final _ChatTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: NovynColors.tagBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NovynColors.tagBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 12, color: NovynColors.violetSoft),
          const SizedBox(width: 5),
          Text(
            tag.label,
            style: NovynText.body(11.5,
                weight: FontWeight.w700, color: NovynColors.violetSoft),
          ),
        ],
      ),
    );
  }
}
