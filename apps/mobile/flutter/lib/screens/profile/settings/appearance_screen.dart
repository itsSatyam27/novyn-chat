import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_alert.dart';
import 'dock_customization_screen.dart';
import 'alert_customization_screen.dart';
import 'quick_toggle_customization_screen.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _callMiniStyles = <(String, String)>[
    ('top_banner', 'Top call banner'),
    ('floating_avatar', 'Floating avatar'),
    ('compact_pill', 'Compact call pill'),
    ('bottom_bar', 'Bottom control bar'),
    ('video_card', 'Video mini card'),
    ('edge_chip', 'Edge call chip'),
  ];

  static const _accents = <(String, Color)>[
    ('Indigo', Color(0xFF6D5DFC)),
    ('Violet', Color(0xFF8B5CF6)),
    ('Blue', Color(0xFF2563EB)),
    ('Teal', Color(0xFF0D9488)),
    ('Pink', Color(0xFFDB2777)),
    ('Orange', Color(0xFFEA580C)),
    ('Green', Color(0xFF16A34A)),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final username = context.watch<AuthService>().user?.username ?? 'user';
    final quickToggleCount = settings.quickToggleIdsFor(username).length;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = Color(settings.accentColorValue);
    final selectedAccent = _accents.indexWhere((item) => item.$2.value == accent.value);
    final accentName = selectedAccent < 0 ? 'Custom' : _accents[selectedAccent].$1;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Appearance'),
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _AppearanceHero(
            themeMode: settings.themeMode,
            accent: accent,
            accentName: accentName,
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Theme',
            subtitle: 'Choose how Novyn looks on your device',
            trailing: _ValuePill(_themeLabel(settings.themeMode)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeChoice(
                label: 'Light',
                mode: ThemeMode.light,
                selected: settings.themeMode == ThemeMode.light,
                onTap: () => settings.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              _ThemeChoice(
                label: 'Dark',
                mode: ThemeMode.dark,
                selected: settings.themeMode == ThemeMode.dark,
                onTap: () => settings.setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(width: 10),
              _ThemeChoice(
                label: 'System',
                mode: ThemeMode.system,
                selected: settings.themeMode == ThemeMode.system,
                onTap: () => settings.setThemeMode(ThemeMode.system),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _SectionHeading(
            title: 'Accent colour',
            subtitle: 'Choose a colour for highlights and active states',
            trailing: _ValuePill(accentName),
          ),
          const SizedBox(height: 10),
          _SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply selected accent'),
              subtitle: Text(settings.accentColorEnabled
                  ? 'Icons and active elements use your selected colour'
                  : 'Keep the default colourful appearance'),
              value: settings.accentColorEnabled,
              onChanged: settings.setAccentColorEnabled,
            ),
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 8,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) {
                if (index == 7) {
                  return _AccentChoice(
                    name: 'Custom',
                    color: accent,
                    selected: selectedAccent < 0,
                    onTap: () async {
                      final picked = await _showCustomAccentPicker(context, accent);
                      if (picked != null) await settings.setAccentColor(picked.value);
                    },
                    custom: true,
                  );
                }
                final item = _accents[index];
                final selected = accent.value == item.$2.value;
                return _AccentChoice(
                  name: item.$1,
                  color: item.$2,
                  selected: selected,
                  onTap: () => settings.setAccentColor(item.$2.value),
                );
              },
            ),
          ),
          const SizedBox(height: 25),
          _SectionHeading(
            title: 'Quick Toggles',
            subtitle: 'Choose up to four shortcuts for your Settings screen',
            trailing: _ValuePill('$quickToggleCount/4'),
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.dashboard_customize_rounded, color: colors.primary),
              ),
              title: const Text(
                'Customize quick toggles',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Select, remove and reorder your shortcuts'),
              trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuickToggleCustomizationScreen(
                    accountKey: username,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          _SectionHeading(
            title: 'Navigation',
            subtitle: 'Personalise your bottom dock',
          ),
          const SizedBox(height: 12),
          _DockStyleTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DockCustomizationScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Alerts',
            subtitle: 'Choose how in-app notifications and confirmations appear',
          ),
          const SizedBox(height: 12),
          _AlertStyleTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertCustomizationScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Minimized call',
            subtitle: 'Choose the floating controls shown while you browse Novyn',
            trailing: _ValuePill(
              _callMiniStyles
                  .firstWhere((item) => item.$1 == settings.callMiniStyle,
                      orElse: () => _callMiniStyles.first)
                  .$2,
            ),
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (final style in _callMiniStyles)
                  _CallMiniStyleChoice(
                    id: style.$1,
                    label: style.$2,
                    selected: settings.callMiniStyle == style.$1,
                    onTap: () => settings.setCallMiniStyle(style.$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Appearance preferences are saved on this device. Quick Toggle selections are saved separately for each account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

class _CallMiniStyleChoice extends StatelessWidget {
  const _CallMiniStyleChoice({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label minimized call style',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: .09) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors.primary.withValues(alpha: .45) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: _CallMiniStylePreview(id: id)),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallMiniStylePreview extends StatelessWidget {
  const _CallMiniStylePreview({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF18A979);
    const coral = Color(0xFFE94A54);
    const ink = Color(0xFF151515);
    Widget avatar({double size = 25}) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFD87958), shape: BoxShape.circle),
          child: Text('R', style: TextStyle(color: Colors.white, fontSize: size * .52, fontWeight: FontWeight.w800)),
        );
    Widget endButton({double size = 22}) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: coral, shape: BoxShape.circle),
          child: const Icon(Icons.call_end_rounded, size: 12, color: Colors.white),
        );
    Widget darkPill({required Widget child, double height = 38}) => Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(height / 2)),
          child: child,
        );

    return Container(
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: switch (id) {
        'top_banner' => Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 25,
              color: green,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const Icon(Icons.call_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 5),
                const Expanded(child: Text('Tap to return to call', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
                const Text('02:14', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        'floating_avatar' => Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: green, width: 3)),
                  child: avatar(size: 27),
                ),
                const SizedBox(height: 2),
                darkPill(height: 17, child: const Row(children: [
                  Icon(Icons.circle, size: 5, color: green),
                  SizedBox(width: 4),
                  Text('02:14', style: TextStyle(color: Colors.white, fontSize: 7)),
                ])),
              ]),
            ),
          ),
        'compact_pill' => Center(
            child: darkPill(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                avatar(size: 24),
                const SizedBox(width: 6),
                const Icon(Icons.graphic_eq_rounded, color: green, size: 20),
                const SizedBox(width: 8),
                const Text('02:14', style: TextStyle(color: Colors.white, fontSize: 9)),
                const SizedBox(width: 7),
                endButton(),
              ]),
            ),
          ),
        'bottom_bar' => Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: darkPill(
                height: 43,
                child: Row(children: [
                  avatar(size: 30),
                  const SizedBox(width: 7),
                  const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Riya Shah', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                    Text('On call · 02:14', style: TextStyle(color: green, fontSize: 7)),
                  ])),
                  const Icon(Icons.mic_none_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  endButton(size: 28),
                ]),
              ),
            ),
          ),
        'video_card' => Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 48,
              height: 53,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF62564B), Color(0xFFD48664)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: const BoxDecoration(color: ink, borderRadius: BorderRadius.all(Radius.circular(10))), child: const Text('02:14', style: TextStyle(color: Colors.white, fontSize: 7))),
                avatar(size: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.mic_none_rounded, size: 10, color: Colors.white), const SizedBox(width: 4), endButton(size: 17)]),
              ]),
            ),
          ),
        _ => Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: darkPill(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  avatar(size: 27),
                  const SizedBox(width: 6),
                  const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Riya', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    Text('02:14', style: TextStyle(color: green, fontSize: 8)),
                  ]),
                  const SizedBox(width: 8),
                  endButton(size: 26),
                ]),
              ),
            ),
          ),
      },
    );
  }
}

class _AppearanceHero extends StatelessWidget {
  const _AppearanceHero({
    required this.themeMode,
    required this.accent,
    required this.accentName,
  });

  final ThemeMode themeMode;
  final Color accent;
  final String accentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = themeMode == ThemeMode.dark;
    final previewBg = dark ? const Color(0xFF171426) : const Color(0xFFF7F5FF);
    final previewFg = dark ? const Color(0xFFF4F0FF) : const Color(0xFF28243D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: .13),
            colors.primary.withValues(alpha: .045),
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.palette_rounded, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your style, your Novyn',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('A quick look at your current setup',
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.auto_awesome_rounded, color: accent),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 105,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 28, height: 28,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white)),
                    const SizedBox(width: 9),
                    Container(width: 82, height: 7,
                      decoration: BoxDecoration(color: previewFg.withValues(alpha: .75), borderRadius: BorderRadius.circular(5))),
                    const Spacer(),
                    Container(width: 24, height: 24,
                      decoration: BoxDecoration(color: accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.more_horiz_rounded, size: 17, color: accent)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    _PreviewLine(width: 104, color: previewFg.withValues(alpha: .18)),
                    const SizedBox(width: 8),
                    _PreviewLine(width: 58, color: accent.withValues(alpha: .28)),
                  ],
                ),
                const SizedBox(height: 7),
                _PreviewLine(width: 150, color: previewFg.withValues(alpha: .12)),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTag(icon: Icons.brightness_6_rounded, label: AppearanceScreen._themeLabel(themeMode)),
              _HeroTag(icon: Icons.circle, label: accentName, tint: accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
  );
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label, this.tint});
  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint ?? colors.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(value, style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.primary, fontWeight: FontWeight.w800)),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = mode == ThemeMode.dark;
    final system = mode == ThemeMode.system;
    final previewBg = dark ? const Color(0xFF171426) : const Color(0xFFF6F4FF);
    final previewFg = dark ? const Color(0xFFEDE9FF) : const Color(0xFF39334F);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label theme',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? colors.primary.withValues(alpha: .07) : colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    height: 66,
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(child: Container(color: system ? const Color(0xFFF6F4FF) : previewBg,
                          padding: const EdgeInsets.all(8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 24, height: 5, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 7),
                            Container(width: 39, height: 4, color: system ? const Color(0xFF39334F) : previewFg),
                            const SizedBox(height: 5),
                            Container(width: 27, height: 4, color: previewFg.withValues(alpha: .25)),
                          ]),
                        )),
                        if (system)
                          Expanded(child: Container(color: const Color(0xFF171426),
                            padding: const EdgeInsets.all(8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 24, height: 5, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 7),
                              Container(width: 39, height: 4, color: const Color(0xFFEDE9FF)),
                              const SizedBox(height: 5),
                              Container(width: 27, height: 4, color: const Color(0xFF77718F)),
                            ]),
                          )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) Icon(Icons.check_circle_rounded, size: 14, color: colors.primary),
                    if (selected) const SizedBox(width: 4),
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<Color?> _showCustomAccentPicker(BuildContext context, Color initial) {
  var hsv = HSVColor.fromColor(initial);
  return showDialog<Color>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final preview = hsv.toColor();
        return AlertDialog(
          title: const Text('Custom accent colour'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: preview,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                  ),
                ),
                const SizedBox(height: 18),
                _PickerSlider(
                  label: 'Hue',
                  value: hsv.hue,
                  max: 360,
                  onChanged: (v) => setState(() => hsv = hsv.withHue(v)),
                ),
                _PickerSlider(
                  label: 'Saturation',
                  value: hsv.saturation,
                  max: 1,
                  onChanged: (v) => setState(() => hsv = hsv.withSaturation(v)),
                ),
                _PickerSlider(
                  label: 'Brightness',
                  value: hsv.value,
                  max: 1,
                  onChanged: (v) => setState(() => hsv = hsv.withValue(v)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('#${preview.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: Theme.of(context).textTheme.labelMedium),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, preview), child: const Text('Apply')),
          ],
        );
      },
    ),
  );
}

class _PickerSlider extends StatelessWidget {
  const _PickerSlider({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(max == 360 ? '${value.round()}°' : '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      Slider(value: value.clamp(0, max), min: 0, max: max, onChanged: onChanged),
    ],
  );
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.custom = false,
  });
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name accent colour',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 39,
              height: 39,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.onSurface : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 19, color: Colors.white)
                    : (custom ? const Icon(Icons.colorize_rounded, size: 18, color: Colors.white) : null),
              ),
            ),
            const SizedBox(height: 5),
            Text(name, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AlertStyleTile extends StatelessWidget {
  const _AlertStyleTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = NovynAlertStyles.byId(settings.alertStyle);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.notifications_active_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert style', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(selected.name,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockStyleTile extends StatelessWidget {
  const _DockStyleTile({required this.onTap});
  final VoidCallback onTap;

  static const _labels = {
    'slide_pill': 'Slide Pill',
    'expand_capsule': 'Expand Capsule',
    'edge_to_edge': 'Edge to Edge',
    'dot_minimal': 'Dot Minimal',
    'soft_glow_glass': 'Soft Glow Glass',
    'liquid_stretch': 'Liquid Stretch',
    'flip_tiles': 'Flip Tiles',
    'draw_ring': 'Draw Ring',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.space_dashboard_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dock style', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(_labels[settings.dockStyle] ?? 'Slide Pill',
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
