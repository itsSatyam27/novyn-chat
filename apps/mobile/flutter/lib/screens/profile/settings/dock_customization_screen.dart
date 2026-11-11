import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_dock.dart';

class DockCustomizationScreen extends StatelessWidget {
  const DockCustomizationScreen({super.key});

  static const styles = [
    ('floating_pill','Floating Pill','Soft capsule with a highlighted active tab',Icons.view_carousel_rounded),
    ('rounded_bar','Rounded Bar','A structured rounded dock with labels',Icons.crop_16_9_rounded),
    ('minimal','Minimal','Icon-only dock to maximise chat space',Icons.more_horiz_rounded),
    ('glass','Glass','Frosted translucent glass surface',Icons.blur_on_rounded),
    ('sliding','Sliding Indicator','Minimal icons with a moving active marker',Icons.swap_horiz_rounded),
    ('elevated','Elevated Center','Prominent centre action with surrounding tabs',Icons.add_circle_outline_rounded),
    ('full_width','Full Width','Edge-to-edge navigation bar',Icons.view_week_rounded),
    ('glow','Accent Glow','Subtle accent glow around the selected tab',Icons.auto_awesome_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(title: const Text('Dock customization'), backgroundColor: NovynTheme.pageBg(context), surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text('CHOOSE YOUR DOCK', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 5),
          Text('Preview a style and tap it to apply. Your choice is saved on this device.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(
            height: 190,
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: theme.colorScheme.outlineVariant)),
            child: Stack(children: [
              Positioned(left: 16,top: 18,child: Container(width: 74,height: 7,decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha:.65),borderRadius: BorderRadius.circular(8)))),
              Positioned(left: 16,top: 38,child: Container(width: 132,height: 6,decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha:.14),borderRadius: BorderRadius.circular(8)))),
              Positioned(left: 16,top: 54,child: Container(width: 94,height: 6,decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha:.09),borderRadius: BorderRadius.circular(8)))),
              Positioned(left: 16,right: 16,bottom: 8,child: NovynDock(selectedIndex: 0,onSelected: (_) {},style: settings.dockStyle,unreadCount: 2,requestCount: 1,preview: true)),
            ]),
          ),
          const SizedBox(height: 20),
          for (final item in styles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => settings.setDockStyle(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: settings.dockStyle == item.$1 ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: settings.dockStyle == item.$1 ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(width: 42,height: 42,decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha:.10),borderRadius: BorderRadius.circular(13)),child: Icon(item.$4,color: theme.colorScheme.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
                      Text(item.$2,style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(item.$3,style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ])),
                    if (settings.dockStyle == item.$1) Icon(Icons.check_circle_rounded,color: theme.colorScheme.primary),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text('Dock transitions are animated. System reduced-motion settings are respected.',style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
