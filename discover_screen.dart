// discover_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'novyn_ui.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    return NovynScaffold(
      currentTab: 2,
      onTabSelected: onTabSelected,
      body: Column(
        children: [
          const NovynHeader(
            title: 'Discover',
            subtitle: '● Live online radar',
            subtitleColor: NovynColors.violet,
            actions: [NovynIconButton(icon: Icons.auto_awesome_outlined)],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: const [
                _RadarCard(),
                _StatsRow(),
                _AddFriendCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Radar card ─────────────────────────

class _RadarCard extends StatelessWidget {
  const _RadarCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NovynColors.glassBorder),
        gradient: const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 0.8,
          colors: [Color(0x478F5BFF), Color(0x008F5BFF)],
        ),
      ),
      child: Column(
        children: [
          const _Radar(),
          const SizedBox(height: 14),
          Text('No one online yet',
              style: NovynText.display(20, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Check back in a moment.',
              style: NovynText.body(13, color: NovynColors.textMuted)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {}, // TODO: refresh online people
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                gradient: NovynGradients.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x807A3EF0),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Refresh people',
                      style: NovynText.body(14,
                          weight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Radar extends StatelessWidget {
  const _Radar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // sweep beam
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(-math.pi / 3),
                colors: [
                  Color(0x80A173FF),
                  Color(0x00A173FF),
                  Color(0x00A173FF),
                ],
                stops: [0, 0.26, 1],
              ),
            ),
          ),
          const _Ring(size: 150, color: Color(0x59A173FF)),
          const _Ring(size: 100, color: Color(0x4DA173FF)),
          const _Ring(size: 50, color: Color(0x4DA173FF)),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: NovynColors.violet,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
    );
  }
}

// ───────────────────────── Requests / Sent ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.group_outlined,
              count: 0,
              label: 'Requests',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.person_add_alt_1_outlined,
              count: 0,
              label: 'Sent',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NovynColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovynColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: NovynColors.violetSoft),
              Text('$count',
                  style: NovynText.body(18,
                      weight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label,
              style: NovynText.body(12.5, color: NovynColors.textChip)),
        ],
      ),
    );
  }
}

// ───────────────────────── Add a friend ─────────────────────────

class _AddFriendCard extends StatelessWidget {
  const _AddFriendCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovynColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NovynColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovynSectionLabel(
            'ADD A FRIEND',
            padding: EdgeInsets.only(bottom: 10),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0B1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NovynColors.glassBorder),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    cursorColor: NovynColors.violet,
                    style: NovynText.body(13.5),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Username or email',
                      hintStyle: NovynText.body(13.5,
                          color: NovynColors.chevron),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {}, // TODO: send friend request
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: NovynGradients.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_alt_1_outlined,
                          size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Send',
                          style: NovynText.body(13.5,
                              weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {}, // TODO: open QR share sheet
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    size: 16, color: NovynColors.violetSoft),
                const SizedBox(width: 8),
                Text('Share my QR code',
                    style:
                        NovynText.body(12.5, color: NovynColors.violetSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
