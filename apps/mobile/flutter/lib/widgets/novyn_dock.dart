import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:novyn/services/haptic_service.dart';

import '../services/auth_service.dart';
import 'user_avatar.dart';

/// The eight animated dock styles available in Novyn's appearance settings.
///
/// Keep these ids in sync with SettingsService and DockCustomizationScreen.
class NovynDock extends StatelessWidget {
  const NovynDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadCount = 0,
    this.requestCount = 0,
    this.style = 'slide_pill',
    this.preview = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final int requestCount;
  final String style;
  final bool preview;

  static const styleIds = <String>[
    'slide_pill',
    'expand_capsule',
    'edge_to_edge',
    'dot_minimal',
    'soft_glow_glass',
    'liquid_stretch',
    'flip_tiles',
    'draw_ring',
  ];

  static const labels = <String>[
    'Messages',
    'Calls',
    'Games',
    'Contacts',
    'Settings',
  ];

  static const icons = <IconData>[
    LucideIcons.messageCircle,
    LucideIcons.phone,
    Icons.sports_esports_rounded,
    LucideIcons.users,
    LucideIcons.userRound,
  ];

  @override
  Widget build(BuildContext context) {
    final safeStyle = styleIds.contains(style) ? style : 'slide_pill';
    final selected = selectedIndex.clamp(0, labels.length - 1).toInt();
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduceMotion ? 0 : 420);
    final user = context.watch<AuthService?>()?.user;
    final profileName = user?.displayName ?? 'Profile';
    final profilePhotoUrl = user?.photoUrl ?? '';

    final Widget dock = SizedBox(
      key: const ValueKey('novyn-dock-shell'),
      height: 96,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedPadding(
          duration: Duration(milliseconds: reduceMotion ? 0 : 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            safeStyle == 'edge_to_edge' ? 0 : 14,
            0,
            safeStyle == 'edge_to_edge' ? 0 : 14,
            safeStyle == 'edge_to_edge' ? 0 : 12,
          ),
          child: SizedBox(
            height: safeStyle == 'edge_to_edge' ? 74 : 82,
            width: double.infinity,
            child: _buildStyle(
              context: context,
              style: safeStyle,
              selected: selected,
              duration: duration,
              reduceMotion: reduceMotion,
              profileName: profileName,
              profilePhotoUrl: profilePhotoUrl,
            ),
          ),
        ),
      ),
    );

    if (preview) return dock;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(top: false, child: dock),
    );
  }

  Widget _buildStyle({
    required BuildContext context,
    required String style,
    required int selected,
    required Duration duration,
    required bool reduceMotion,
    required String profileName,
    required String profilePhotoUrl,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final surface = colors.surface;
    final inactive = colors.onSurfaceVariant;

    Widget item(int index, Widget child) => _press(index, selected, child);

    Widget labeledItem(int index, {bool pill = false, bool compact = false}) {
      final active = index == selected;
      final iconColor = pill && active ? colors.onPrimary : (active ? accent : inactive);
      final labelColor = pill && active ? colors.onPrimary : (active ? accent : inactive);
      return item(
        index,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Bounce(
                active: active,
                reduceMotion: reduceMotion,
                child: _glyph(
                  index,
                  iconColor,
                  profileName,
                  profilePhotoUrl,
                  size: 22,
                  avatarFallback: pill && active ? colors.onPrimary : accent,
                  avatarBorder: pill && active
                      ? colors.onPrimary.withValues(alpha: .9)
                      : inactive.withValues(alpha: .45),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.1,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    switch (style) {
      case 'slide_pill':
        return Container(
          height: 76,
          padding: const EdgeInsets.all(8),
          decoration: _shell(context, 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: _spring,
                    left: selected * itemWidth,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: .28),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      labels.length,
                      (index) => Expanded(
                        child: labeledItem(index, pill: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );

      case 'expand_capsule':
        return Container(
          height: 76,
          padding: const EdgeInsets.all(6),
          decoration: _shell(context, 30),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit = constraints.maxWidth / 6;
              return Row(
                children: List.generate(labels.length, (index) {
                  final active = index == selected;
                  return SizedBox(
                    width: unit * (active ? 2 : 1),
                    child: _press(
                      index,
                      selected,
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        height: 60,
                        padding: EdgeInsets.symmetric(
                          horizontal: active ? 4 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? accent.withValues(alpha: .13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Bounce(
                              active: active,
                              reduceMotion: reduceMotion,
                              child: _glyph(
                                index,
                                active ? accent : inactive,
                                profileName,
                                profilePhotoUrl,
                                size: 22,
                                avatarFallback: accent,
                                avatarBorder: inactive.withValues(alpha: .45),
                              ),
                            ),
                            ClipRect(
                              child: AnimatedAlign(
                                alignment: Alignment.centerLeft,
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                widthFactor: active ? 1 : 0,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    labels[index],
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        );

      case 'edge_to_edge':
        return Container(
          height: 74,
          decoration: BoxDecoration(
            color: surface,
            border: Border(
              top: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: selected * itemWidth + (itemWidth - 36) / 2,
                    top: 0,
                    width: 36,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      labels.length,
                      (index) => Expanded(
                        child: labeledItem(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );

      case 'dot_minimal':
        return Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: _shell(context, 30),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: _springSoft,
                    left: selected * itemWidth + (itemWidth - 5) / 2,
                    bottom: 7,
                    width: 5,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (index) {
                      final active = index == selected;
                      return Expanded(
                        child: item(
                          index,
                          Center(
                            child: AnimatedSlide(
                              duration: duration,
                              curve: _spring,
                              offset: active ? const Offset(0, -.12) : Offset.zero,
                              child: AnimatedScale(
                                duration: duration,
                                curve: _spring,
                                scale: active ? 1.12 : 1,
                                child: _glyph(
                                  index,
                                  active ? accent : inactive,
                                  profileName,
                                  profilePhotoUrl,
                                  size: 24,
                                  avatarFallback: accent,
                                  avatarBorder: inactive.withValues(alpha: .45),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );

      case 'soft_glow_glass':
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark ? .24 : .14,
                ),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: surface.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? .88 : .76,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / labels.length;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: duration,
                          curve: _spring,
                          left: selected * itemWidth + (itemWidth - 70) / 2,
                          top: 0,
                          bottom: 0,
                          width: 70,
                          child: Center(
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: .28),
                                    accent.withValues(alpha: .0),
                                  ],
                                  stops: const [0, .72],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(labels.length, (index) {
                            final active = index == selected;
                            return Expanded(
                              child: item(
                                index,
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                        duration: duration,
                                        curve: _spring,
                                        scale: active ? 1.16 : 1,
                                        child: _glyph(
                                          index,
                                          active ? accent : inactive,
                                          profileName,
                                          profilePhotoUrl,
                                          size: 23,
                                          avatarFallback: accent,
                                          avatarBorder: inactive.withValues(alpha: .45),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        labels[index],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                          color: active ? accent : inactive,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

      case 'liquid_stretch':
        return Container(
          height: 76,
          padding: const EdgeInsets.all(8),
          decoration: _shell(context, 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  _LiquidStretchIndicator(
                      itemWidth: itemWidth,
                      index: selected,
                      reduceMotion: reduceMotion,
                      color: accent,
                      radius: 21,
                    ),
                  Row(
                    children: List.generate(
                      labels.length,
                      (index) => Expanded(
                        child: labeledItem(index, pill: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );

      case 'flip_tiles':
        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: _shell(context, 28),
          child: Row(
            children: List.generate(labels.length, (index) {
              final active = index == selected;
              return Expanded(
                child: item(
                  index,
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FlipTile(
                          active: active,
                          reduceMotion: reduceMotion,
                          front: _glyph(
                            index,
                            inactive,
                            profileName,
                            profilePhotoUrl,
                            size: 22,
                            avatarFallback: accent,
                            avatarBorder: inactive.withValues(alpha: .45),
                          ),
                          back: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: .25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _glyph(
                              index,
                              colors.onPrimary,
                              profileName,
                              profilePhotoUrl,
                              size: 22,
                              avatarFallback: colors.onPrimary,
                              avatarBorder: colors.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? accent : inactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );

      case 'draw_ring':
        return Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: _shell(context, 30),
          child: Row(
            children: List.generate(labels.length, (index) {
              final active = index == selected;
              return Expanded(
                child: item(
                  index,
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(end: active ? 1 : 0),
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 620),
                                curve: Curves.easeInOutCubic,
                                builder: (_, progress, __) => CustomPaint(
                                  size: const Size(42, 42),
                                  painter: _RingPainter(progress, accent),
                                ),
                              ),
                              _Bounce(
                                active: active,
                                reduceMotion: reduceMotion,
                                child: _glyph(
                                  index,
                                  active ? accent : inactive,
                                  profileName,
                                  profilePhotoUrl,
                                  size: 22,
                                  avatarFallback: accent,
                                  avatarBorder: inactive.withValues(alpha: .45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? accent : inactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _press(int index, int selected, Widget child) {
    return Semantics(
      label: labels[index],
      button: true,
      selected: index == selected,
      child: GestureDetector(
        key: ValueKey('dock-tab-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: index == selected
            ? null
            : () {
                HapticService.vibrate(
                  NovynHapticType.selection,
                  category: HapticCategory.navigation,
                );
                onSelected(index);
              },
        child: child,
      ),
    );
  }

  Widget _glyph(
    int index,
    Color color,
    String profileName,
    String profilePhotoUrl, {
    double size = 22,
    required Color avatarFallback,
    required Color avatarBorder,
  }) {
    final Widget icon = index == 4
        ? UserAvatar(
            name: profileName,
            photoUrl: profilePhotoUrl,
            radius: 12,
            fallbackColor: avatarFallback,
            borderWidth: 1.6,
            borderColor: avatarBorder,
          )
        : Icon(icons[index], size: size, color: color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (index == 0 && unreadCount > 0)
          Positioned(
            top: -8,
            right: -13,
            child: PositionedBadge(
              value: unreadCount > 99 ? '99+' : '$unreadCount',
            ),
          ),
        if (index == 3 && requestCount > 0)
          const Positioned(
            top: -5,
            right: -8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFF5C85),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
      ],
    );
  }

  BoxDecoration _shell(BuildContext context, double radius) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colors.outlineVariant.withValues(alpha: dark ? .7 : .55),
      ),
      boxShadow: [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: .28)
              : colors.primary.withValues(alpha: .09),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static const Curve _spring = Cubic(.34, 1.35, .5, 1);
  static const Curve _springSoft = Cubic(.34, 1.5, .5, 1);
}

class _Bounce extends StatefulWidget {
  const _Bounce({
    required this.active,
    required this.reduceMotion,
    required this.child,
  });

  final bool active;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.22).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.22, end: .96).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: .96, end: 1.0),
      weight: 30,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _Bounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !widget.reduceMotion) {
      _controller.forward(from: 0);
    } else if (widget.reduceMotion) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class _LiquidStretchIndicator extends StatefulWidget {
  const _LiquidStretchIndicator({
    required this.itemWidth,
    required this.index,
    required this.reduceMotion,
    required this.color,
    required this.radius,
  });

  final double itemWidth;
  final int index;
  final bool reduceMotion;
  final Color color;
  final double radius;

  @override
  State<_LiquidStretchIndicator> createState() => _LiquidStretchIndicatorState();
}

class _LiquidStretchIndicatorState extends State<_LiquidStretchIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  late int _from = widget.index;
  late int _to = widget.index;

  static const _lead = Interval(
    0,
    .45,
    curve: Cubic(.3, .9, .3, 1),
  );
  static const _lag = Interval(
    .1,
    1,
    curve: Cubic(.3, 1, .4, 1),
  );

  @override
  void didUpdateWidget(covariant _LiquidStretchIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = oldWidget.index;
      _to = widget.index;
      if (widget.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return Positioned(
        left: widget.index * widget.itemWidth,
        top: 0,
        bottom: 0,
        width: widget.itemWidth,
        child: _indicator(),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final movingForward = _to >= _from;
        final lead = _lead.transform(_controller.value);
        final lag = _lag.transform(_controller.value);
        final left = lerpDouble(
          _from * widget.itemWidth,
          _to * widget.itemWidth,
          movingForward ? lag : lead,
        )!;
        final right = lerpDouble(
          (_from + 1) * widget.itemWidth,
          (_to + 1) * widget.itemWidth,
          movingForward ? lead : lag,
        )!;
        return Positioned(
          left: left,
          top: 0,
          bottom: 0,
          width: math.max(0.0, right - left),
          child: _indicator(),
        );
      },
    );
  }

  Widget _indicator() => DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: .26),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      );
}

class _FlipTile extends StatelessWidget {
  const _FlipTile({
    required this.active,
    required this.reduceMotion,
    required this.front,
    required this.back,
  });

  final bool active;
  final bool reduceMotion;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return active ? back : front;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: active ? 1 : 0),
      duration: const Duration(milliseconds: 620),
      curve: const Cubic(.3, 1.25, .5, 1),
      builder: (_, value, __) {
        final angle = value * math.pi;
        final showBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0022)
            ..rotateY(angle),
          child: SizedBox(
            width: 42,
            height: 42,
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: back,
                  )
                : Center(child: front),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.5;
    final p = progress.clamp(0.0, 1.0).toDouble();

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: .10 * p),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class PositionedBadge extends StatelessWidget {
  const PositionedBadge({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFE34D73),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF171325)
                : Colors.white,
            width: 1.5,
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
