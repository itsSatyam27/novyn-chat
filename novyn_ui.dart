// novyn_ui.dart
// Shared theme + reusable widgets for the Novyn screens.
// Needs:  google_fonts  (flutter pub add google_fonts)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────── Colors ───────────────────────────

class NovynColors {
  static const bg = Color(0xFF0E0B20);
  static const violet = Color(0xFFA173FF);
  static const violetDeep = Color(0xFF7A3EF0);
  static const violetSoft = Color(0xFFC9B3FF);
  static const text = Color(0xFFF2F0FA);
  static const textMuted = Color(0xFF9A94B8);
  static const textSub = Color(0xFFA9A2C8);
  static const textChip = Color(0xFFC9C5DE);
  static const timeMuted = Color(0xFF8E8AA8);
  static const navIcon = Color(0xFFB9B2D6);
  static const chevron = Color(0xFF6E6890);
  static const mint = Color(0xFF3DDC97);
  static const offline = Color(0xFF6B6880);
  static const amber = Color(0xFFFFB547);
  static const danger = Color(0xFFFF8FA6);
  static const statusRing = Color(0xFF120E26);

  // translucent surfaces
  static const glass = Color(0x12FFFFFF); // white 7%
  static const card = Color(0x0FFFFFFF); // white 6%
  static const glassBorder = Color(0x1AFFFFFF); // white 10%
  static const tagBg = Color(0x2E8F5BFF);
  static const tagBorder = Color(0x668F5BFF);
  static const badgeBg = Color(0x338F5BFF);
  static const violetShadow = Color(0x737A3EF0);
}

class NovynGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA173FF), Color(0xFF7A3EF0)],
  );
}

class AvatarPalette {
  static const List<Color> blue = [Color(0xFF6A8CFF), Color(0xFF3B4FD8)];
  static const List<Color> pink = [Color(0xFFFF6FB5), Color(0xFFC2185B)];
  static const List<Color> green = [Color(0xFF2EC48A), Color(0xFF12805A)];
  static const List<Color> purple = [Color(0xFF8F5BFF), Color(0xFF5B2BD6)];
}

// ─────────────────────────── Text styles ───────────────────────────

class NovynText {
  /// Syne – titles and avatar letters
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = NovynColors.text,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// DM Sans – everything else
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = NovynColors.text,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

// ─────────────────────────── Page scaffold + dock ───────────────────────────

/// Background glow + safe area + floating bottom dock.
/// [currentTab]: 0 Messages, 1 Calls, 2 Discover, 3 Contacts, 4 Settings
class NovynScaffold extends StatelessWidget {
  const NovynScaffold({
    super.key,
    required this.body,
    required this.currentTab,
    this.onTabSelected,
  });

  final Widget body;
  final int currentTab;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: NovynColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(bottom: false, child: body),
          if (!keyboardOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: NovynDock(
                    selectedIndex: currentTab,
                    onSelected: onTabSelected,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.1),
                radius: 0.95,
                colors: [Color(0x668F5BFF), Color(0x008F5BFF)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1, 1),
                radius: 0.8,
                colors: [Color(0x26FF5CC8), Color(0x00FF5CC8)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NovynDock extends StatelessWidget {
  const NovynDock({super.key, required this.selectedIndex, this.onSelected});

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const _items = <(String, IconData)>[
    ('Messages', Icons.chat_bubble_outline_rounded),
    ('Calls', Icons.call_outlined),
    ('Discover', Icons.explore_outlined),
    ('Contacts', Icons.group_outlined),
    ('Settings', Icons.wb_sunny_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xEB18142C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected?.call(i),
              child: i == selectedIndex
                  ? Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        gradient: NovynGradients.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: NovynColors.violetShadow,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_items[i].$2, size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            _items[i].$1,
                            style: NovynText.body(13,
                                weight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: 44,
                      height: 46,
                      child: Icon(_items[i].$2,
                          size: 20, color: NovynColors.navIcon),
                    ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Header, search, chips, labels ───────────────────────────

class NovynHeader extends StatelessWidget {
  const NovynHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor = NovynColors.textMuted,
    this.titleColor = NovynColors.text,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final Color titleColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NovynText.display(28,
                      color: titleColor, letterSpacing: -0.28),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: NovynText.body(13, color: subtitleColor)),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Rounded square icon button. [primary] = purple gradient, otherwise glass.
class NovynIconButton extends StatelessWidget {
  const NovynIconButton({
    super.key,
    required this.icon,
    this.primary = false,
    this.size = 44,
    this.radius = 15,
    this.iconSize = 19,
    this.onTap,
  });

  final IconData icon;
  final bool primary;
  final double size;
  final double radius;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: primary ? NovynGradients.primary : null,
          color: primary ? null : NovynColors.glass,
          border: primary ? null : Border.all(color: NovynColors.glassBorder),
          boxShadow: primary
              ? const [
                  BoxShadow(
                    color: NovynColors.violetShadow,
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: primary ? Colors.white : NovynColors.violetSoft,
        ),
      ),
    );
  }
}

class NovynSearchField extends StatelessWidget {
  const NovynSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: NovynColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovynColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 18, color: NovynColors.violet),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: NovynColors.violet,
                style: NovynText.body(14),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: NovynText.body(14, color: NovynColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NovynChipRow extends StatelessWidget {
  const NovynChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.bottomPadding = 14,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: i == selected
                      ? BoxDecoration(
                          gradient: NovynGradients.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x667A3EF0),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: NovynColors.glass,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: NovynColors.glassBorder),
                        ),
                  child: Text(
                    labels[i],
                    style: NovynText.body(
                      13,
                      weight: FontWeight.w600,
                      color: i == selected
                          ? Colors.white
                          : NovynColors.textChip,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NovynSectionLabel extends StatelessWidget {
  const NovynSectionLabel(
    this.text, {
    super.key,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 2),
  });

  final String text;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: NovynColors.violet),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: NovynText.body(11,
                weight: FontWeight.w700,
                color: NovynColors.violet,
                letterSpacing: 1.32),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Avatars ───────────────────────────

class NovynAvatar extends StatelessWidget {
  const NovynAvatar({
    super.key,
    required this.size,
    this.letter,
    this.colors = AvatarPalette.blue,
    this.eyes = false,
    this.statusColor,
  });

  final double size;
  final String? letter;
  final List<Color> colors;

  /// The "two mint dots" robot-style avatar (anushkadas)
  final bool eyes;

  /// Small presence dot (bottom-right). null = hidden
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: eyes ? _eyesFace() : _letterFace()),
          if (statusColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: NovynColors.statusRing, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _letterFace() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Text(
        letter ?? '',
        style: NovynText.display(size * 0.4, color: Colors.white),
      ),
    );
  }

  Widget _eyesFace() {
    Widget dot() => Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: NovynColors.mint,
            shape: BoxShape.circle,
          ),
        );
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F6F66), Color(0xFF0F3B38)],
        ),
        border: Border.all(color: NovynColors.mint, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [dot(), const SizedBox(width: 5), dot()],
      ),
    );
  }
}

class PinnedPerson {
  const PinnedPerson(
    this.name, {
    this.letter,
    this.colors = AvatarPalette.blue,
    this.eyes = false,
  });

  final String name;
  final String? letter;
  final List<Color> colors;
  final bool eyes;
}

/// Horizontal row of pinned avatars followed by the dashed "+ Pin" button.
class PinnedAvatarRow extends StatelessWidget {
  const PinnedAvatarRow({
    super.key,
    required this.people,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 14),
    this.onAdd,
  });

  final List<PinnedPerson> people;
  final EdgeInsets padding;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    NovynAvatar(
                      size: 56,
                      letter: p.letter,
                      colors: p.colors,
                      eyes: p.eyes,
                      statusColor: NovynColors.offline,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          NovynText.body(11.5, color: NovynColors.textChip),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: 64,
            child: Column(
              children: [
                DashedCircleButton(size: 56, onTap: onAdd),
                const SizedBox(height: 6),
                Text('Pin',
                    style: NovynText.body(11.5, color: NovynColors.violet)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashedCircleButton extends StatelessWidget {
  const DashedCircleButton({super.key, this.size = 56, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        size: Size.square(size),
        painter: _DashedCirclePainter(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text('+',
                style: NovynText.body(22, color: NovynColors.violet)),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x80A173FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - 1.5) / 2,
    );
    const dashes = 28;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
