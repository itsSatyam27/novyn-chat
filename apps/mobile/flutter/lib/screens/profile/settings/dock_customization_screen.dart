import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_dock.dart';

class DockCustomizationScreen extends StatelessWidget {
  const DockCustomizationScreen({super.key});

  static const styles = [
    ('floating_pill', 'Floating Pill',
        'A soft capsule with a clear active tab', Icons.view_carousel_rounded),
    ('rounded_bar', 'Rounded Bar',
        'A structured bar with comfortable labels', Icons.crop_16_9_rounded),
    ('minimal', 'Minimal',
        'Icon-only navigation for more chat space', Icons.more_horiz_rounded),
    ('glass', 'Glass',
        'A frosted surface with gentle depth', Icons.blur_on_rounded),
    ('sliding', 'Sliding Indicator',
        'A moving highlight beneath the active tab', Icons.swap_horiz_rounded),
    ('elevated', 'Elevated Center',
        'A stronger visual focus on the middle tab', Icons.add_circle_outline_rounded),
    ('full_width', 'Full Width',
        'An edge-to-edge navigation surface', Icons.view_week_rounded),
    ('glow', 'Accent Glow',
        'A subtle glow using your selected accent', Icons.auto_awesome_rounded),
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
                '8 styles',
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.style,
  });

  final String style;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: colors.primary),
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
              selectedIndex: 0,
              onSelected: (_) {},
              style: style,
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
    final base = colors.primary.withValues(alpha: .08);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(13)),
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Row(children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(5))),
          const Spacer(),
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17, color: selected ? accent : colors.outlineVariant),
        ]),
        const Spacer(),
        if (style == 'minimal')
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (i) => Icon(Icons.circle, size: 7, color: i == 0 ? accent : accent.withValues(alpha: .35))))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: style == 'glass' || style == 'glow' ? accent.withValues(alpha: .13) : colors.surface,
              borderRadius: BorderRadius.circular(style == 'floating_pill' ? 20 : 9),
              boxShadow: style == 'glow' ? [BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 9)] : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => Container(
                width: style == 'elevated' && i == 2 ? 13 : 7,
                height: style == 'elevated' && i == 2 ? 13 : 7,
                decoration: BoxDecoration(color: i == 0 ? accent : accent.withValues(alpha: .35), shape: BoxShape.circle),
              ))),
          ),
      ]),
    );
  }
}
