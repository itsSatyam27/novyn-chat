import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _accents = <Color>[
    Color(0xFF6D5DFC), Color(0xFF8B5CF6), Color(0xFF2563EB),
    Color(0xFF0D9488), Color(0xFFDB2777), Color(0xFFEA580C),
    Color(0xFF16A34A), Color(0xFF475569),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final selectedAccent = Color(settings.accentColorValue);
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Appearance'),
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Text('MAKE IT YOURS', style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          Text('Personalise how Novyn looks and feels.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          _sectionTitle(context, 'Theme'),
          const SizedBox(height: 12),
          Row(children: [
            _ThemePreviewCard(label: 'Light', mode: ThemeMode.light, selected: settings.themeMode == ThemeMode.light, onTap: () => settings.setThemeMode(ThemeMode.light)),
            const SizedBox(width: 10),
            _ThemePreviewCard(label: 'Dark', mode: ThemeMode.dark, selected: settings.themeMode == ThemeMode.dark, onTap: () => settings.setThemeMode(ThemeMode.dark)),
            const SizedBox(width: 10),
            _ThemePreviewCard(label: 'System', mode: ThemeMode.system, selected: settings.themeMode == ThemeMode.system, onTap: () => settings.setThemeMode(ThemeMode.system)),
          ]),
          const SizedBox(height: 26),
          _sectionTitle(context, 'Accent colour'),
          const SizedBox(height: 5),
          Text('Choose the colour used for highlights and controls.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 14, children: _accents.map((color) {
            final selected = color.value == settings.accentColorValue;
            return Semantics(
              button: true, selected: selected, label: 'Accent colour',
              child: InkWell(
                onTap: () => settings.setAccentColor(color.value),
                borderRadius: BorderRadius.circular(30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(color: selected ? theme.colorScheme.onSurface : Colors.transparent, width: 2.5),
                    boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12)] : null,
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 21) : null,
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 26),
          _sectionTitle(context, 'Text size'),
          const SizedBox(height: 5),
          Text('Adjust text across supported Novyn screens.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('A', style: TextStyle(fontSize: 12)),
                Text('Preview text', style: TextStyle(fontSize: 16 * settings.fontSize, fontWeight: FontWeight.w700)),
                const Text('A', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
              ]),
              Slider(
                value: settings.fontSize.clamp(.85, 1.25),
                min: .85, max: 1.25, divisions: 8,
                label: '${(settings.fontSize * 100).round()}%',
                onChanged: settings.setFontSize,
              ),
              Align(alignment: Alignment.centerRight,
                child: Text('${(settings.fontSize * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800))),
            ]),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(color: selectedAccent.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.auto_awesome_rounded, color: selectedAccent)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your Novyn style', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Changes are saved automatically.', style: TextStyle(fontSize: 12)),
              ])),
              Icon(Icons.check_circle_rounded, color: selectedAccent),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.label, required this.mode, required this.selected, required this.onTap});
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = mode == ThemeMode.dark;
    final bg = dark ? const Color(0xFF11111D) : const Color(0xFFF7F6FF);
    final fg = dark ? const Color(0xFFF4F1FF) : const Color(0xFF27233F);
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent : Theme.of(context).colorScheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Container(
            height: 72, width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 28, height: 6, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(width: 48, height: 5, decoration: BoxDecoration(color: fg.withValues(alpha: .8), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 5),
              Container(width: 65, height: 5, decoration: BoxDecoration(color: fg.withValues(alpha: .25), borderRadius: BorderRadius.circular(4))),
              const Spacer(),
              Align(alignment: Alignment.centerRight, child: Container(width: 22, height: 10, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)))),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (selected) Icon(Icons.check_circle_rounded, size: 14, color: accent),
            if (selected) const SizedBox(width: 4),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ]),
      ),
    ));
  }
}
