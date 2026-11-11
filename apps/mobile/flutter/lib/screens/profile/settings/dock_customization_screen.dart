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
      appBar: AppBar(
        title: const Text('Dock appearance'),
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(
            'MAKE NAVIGATION YOURS',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how your navigation looks. Changes apply instantly and are saved on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _PreviewCard(
            style: selectedStyle,
            styleName: _styleName(selectedStyle),
            description: _styleDescription(selectedStyle),
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
          for (final item in styles)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _DockStyleTile(
                id: item.$1,
                title: item.$2,
                subtitle: item.$3,
                icon: item.$4,
                selected: selectedStyle == item.$1,
                onTap: () => settings.setDockStyle(item.$1),
              ),
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
    required this.styleName,
    required this.description,
  });

  final String style;
  final String styleName;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      height: 222,
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
            top: 86,
            left: 17,
            child: Container(
              width: 96,
              height: 6,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: .08),
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
          Positioned(
            left: 17,
            bottom: 112,
            right: 17,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey(style),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    styleName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockStyleTile extends StatelessWidget {
  const _DockStyleTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title dock style',
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .075)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.7 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? colors.onPrimary : colors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Icon(Icons.check_circle_rounded,
                          key: ValueKey('$id-selected'),
                          color: colors.primary,
                          size: 22)
                      : Icon(Icons.circle_outlined,
                          key: ValueKey('$id-unselected'),
                          color: colors.outlineVariant,
                          size: 21),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
