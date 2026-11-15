import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_dock.dart';

class DockCustomizationScreen extends StatelessWidget {
  const DockCustomizationScreen({super.key});

  static const styles = [
    ('slide_pill', 'Slide Pill',
        'A springy accent pill moves beneath the active tab', Icons.view_carousel_rounded),
    ('expand_capsule', 'Expand Capsule',
        'The active tab widens to reveal its label', Icons.unfold_more_rounded),
    ('edge_to_edge', 'Edge to Edge',
        'A clean full-width bar with a moving top marker', Icons.view_week_rounded),
    ('dot_minimal', 'Dot Minimal',
        'Icon-only navigation with a gliding active dot', Icons.more_horiz_rounded),
    ('soft_glow_glass', 'Soft Glow Glass',
        'A frosted dock with a soft accent glow', Icons.blur_on_rounded),
    ('liquid_stretch', 'Liquid Stretch',
        'The active pill stretches as it moves between tabs', Icons.water_drop_rounded),
    ('flip_tiles', 'Flip Tiles',
        'The selected icon flips into an accent tile', Icons.flip_rounded),
    ('draw_ring', 'Draw Ring',
        'An accent ring draws around the selected icon', Icons.radio_button_checked_rounded),
  ];

  String _styleName(String value) =>
      styles.firstWhere((item) => item.$1 == value,
          orElse: () => styles.first).$2;

  String _styleDescription(String value) =>
      styles.firstWhere((item) => item.$1 == value,
          orElse: () => styles.first).$3;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedStyle = settings.dockStyle;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 32),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dock appearance', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.6)),
              Text('Changes apply instantly and are saved on this device', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 22),
          _PreviewCard(style: selectedStyle),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(selectedStyle),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _styleName(selectedStyle),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _styleDescription(selectedStyle),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Dock styles',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '8 animated styles',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: styles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final item = styles[index];
              return _DockStyleTile(
                id: item.$1, title: item.$2, subtitle: item.$3,
                icon: item.$4, selected: selectedStyle == item.$1,
                onTap: () => settings.setDockStyle(item.$1),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dock transitions respect your device’s reduced-motion setting.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatefulWidget {
  const _PreviewCard({required this.style});

  final String style;

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 17,
            left: 17,
            right: 17,
            child: Row(
              children: [
                Text(
                  'LIVE PREVIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'APPLIED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 55,
            left: 17,
            child: Container(
              width: 72,
              height: 7,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: 17,
            child: Container(
              width: 136,
              height: 6,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: NovynDock(
              selectedIndex: _selectedIndex,
              onSelected: (index) => setState(() => _selectedIndex = index),
              style: widget.style,
              unreadCount: 2,
              requestCount: 1,
              preview: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockStyleTile extends StatelessWidget {
  const _DockStyleTile({required this.id, required this.title, required this.subtitle,
    required this.icon, required this.selected, required this.onTap});
  final String id, title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(button: true, selected: selected, label: '$title dock style',
      child: Material(
        color: selected ? colors.primary.withValues(alpha: .055) : colors.surface,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(19),
              border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 1.7 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _DockMiniPreview(style: id, selected: selected)),
              const SizedBox(height: 9),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant, height: 1.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DockMiniPreview extends StatelessWidget {
  const _DockMiniPreview({required this.style, required this.selected});

  final String style;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final inactive = colors.onSurfaceVariant;
    final base = colors.primary.withValues(alpha: .07);

    Widget dot(int index, {bool active = false}) => Container(
      width: active ? 14 : 8,
      height: active ? 14 : 8,
      decoration: BoxDecoration(
        color: active ? accent : inactive.withValues(alpha: .36),
        shape: BoxShape.circle,
      ),
    );

    if (style == 'dot_minimal') {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (i) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: i == 0 ? 13 : 10, color: i == 0 ? accent : inactive.withValues(alpha: .45)),
              const SizedBox(height: 5),
              if (i == 0) Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            ],
          )),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(13)),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: accent.withValues(alpha: .20), borderRadius: BorderRadius.circular(5))),
            const Spacer(),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: selected ? accent : colors.outlineVariant),
          ]),
          const Spacer(),
          if (style == 'edge_to_edge')
            Container(
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.only(top: 5, left: 5, right: 5, bottom: 7),
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: Container(width: 15, height: 2.5, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (i) => dot(i, active: i == 0))),
              ]),
            )
          else if (style == 'expand_capsule')
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [dot(0, active: true), const SizedBox(width: 5), Container(width: 24, height: 4, color: accent.withValues(alpha: .7))]),
              ),
              const SizedBox(width: 5),
              ...List.generate(4, (_) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: dot(1))),
            ])
          else if (style == 'draw_ring')
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (i) => Container(
              width: 24, height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, border: i == 0 ? Border.all(color: accent, width: 2) : null),
              alignment: Alignment.center,
              child: dot(i, active: i == 0),
            )))
          else if (style == 'flip_tiles')
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (i) => Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: i == 0 ? accent : colors.surface, borderRadius: BorderRadius.circular(7)),
              alignment: Alignment.center,
              child: dot(i, active: i == 0),
            )))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: style == 'soft_glow_glass' ? accent.withValues(alpha: .12) : colors.surface,
                borderRadius: BorderRadius.circular(style == 'slide_pill' || style == 'liquid_stretch' ? 18 : 10),
                border: style == 'soft_glow_glass' ? Border.all(color: accent.withValues(alpha: .18)) : null,
                boxShadow: style == 'soft_glow_glass' ? [BoxShadow(color: accent.withValues(alpha: .16), blurRadius: 10)] : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (i) => dot(i, active: i == 0))),
            ),
        ],
      ),
    );
  }
}
