// calls_screen.dart
import 'package:flutter/material.dart';

import 'novyn_ui.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  static const _filters = ['All', 'Missed', 'Audio', 'Video'];

  static const _quickCall = [
    _Contact('Raju Kaka', 'R', AvatarPalette.blue),
    _Contact('shreyansh', 'S', AvatarPalette.purple),
    _Contact('Harsh', 'H', AvatarPalette.pink),
  ];

  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return NovynScaffold(
      currentTab: 1,
      onTabSelected: widget.onTabSelected,
      body: Column(
        children: [
          const NovynHeader(
            title: 'Calls',
            subtitle: '5 calls this week · 0 missed',
            actions: [NovynIconButton(icon: Icons.more_horiz_rounded)],
          ),
          const NovynSearchField(hint: 'Search calls…'),
          NovynChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                const NovynSectionLabel('QUICK CALL',
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 4)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    children: [
                      for (final c in _quickCall)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _QuickCallItem(contact: c),
                        ),
                    ],
                  ),
                ),
                const NovynSectionLabel('TODAY'),
                const _CallTile(
                  name: 'raju kaka',
                  letter: 'R',
                  colors: AvatarPalette.blue,
                  count: 2,
                  detail: 'Video · 0:22',
                  time: '11:49 am',
                ),
                const NovynSectionLabel(
                  '17 AUG',
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 2),
                ),
                const _CallTile(
                  name: 'shreyanshpatel',
                  letter: 'S',
                  colors: AvatarPalette.purple,
                  count: 3,
                  detail: 'Audio',
                  time: '11:06 am',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact {
  const _Contact(this.name, this.letter, this.colors);
  final String name;
  final String letter;
  final List<Color> colors;
}

class _QuickCallItem extends StatelessWidget {
  const _QuickCallItem({required this.contact});

  final _Contact contact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NovynAvatar(
                size: 54,
                letter: contact.letter,
                colors: contact.colors,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: NovynGradients.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: NovynColors.bg, width: 2.5),
                  ),
                  child:
                      const Icon(Icons.call, size: 11, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NovynText.body(11.5, color: NovynColors.textChip),
          ),
        ],
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({
    required this.name,
    required this.letter,
    required this.colors,
    required this.count,
    required this.detail,
    required this.time,
  });

  final String name;
  final String letter;
  final List<Color> colors;
  final int count;
  final String detail;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          NovynAvatar(size: 50, letter: letter, colors: colors),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NovynText.body(16, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: NovynColors.badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: NovynText.body(11,
                            weight: FontWeight.w700,
                            color: NovynColors.violetSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.north_east_rounded,
                        size: 14, color: NovynColors.violet),
                    const SizedBox(width: 6),
                    Text(detail,
                        style:
                            NovynText.body(13, color: NovynColors.textSub)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time,
                  style: NovynText.body(11.5, color: NovynColors.timeMuted)),
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NovynIconButton(
                    icon: Icons.call,
                    primary: true,
                    size: 34,
                    radius: 12,
                    iconSize: 16,
                  ),
                  SizedBox(width: 8),
                  NovynIconButton(
                    icon: Icons.videocam_outlined,
                    size: 34,
                    radius: 12,
                    iconSize: 17,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
