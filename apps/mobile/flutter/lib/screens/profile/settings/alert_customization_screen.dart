import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_alert.dart';

class AlertCustomizationScreen extends StatelessWidget {
  const AlertCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = settings.alertStyle;
    final selectedOption = NovynAlertStyles.byId(selected);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 16,
          20,
          32,
        ),
        children: [
          Text(
            'Alert appearance',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Choose how in-app alerts appear across Novyn',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _SelectedPreview(styleId: selected),
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              selectedOption.description,
              key: ValueKey(selected),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => NovynAlert.preview(context, selected),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Preview selected style'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Alert styles',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '6 styles',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: NovynAlertStyles.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .96,
            ),
            itemBuilder: (context, index) {
              final option = NovynAlertStyles.all[index];
              final isSelected = option.id == selected;
              return _AlertStyleTile(
                option: option,
                selected: isSelected,
                onTap: () async {
                  await settings.setAlertStyle(option.id);
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your choice is saved on this device and applies to in-app alerts immediately.',
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

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({required this.styleId});

  final String styleId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = NovynAlertStyles.byId(styleId);
    return Container(
      height: 154,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Text(
              'LIVE PREVIEW',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
            ),
          ),
          Positioned.fill(
            top: 28,
            child: Center(child: _AlertStyleArtwork(styleId: styleId)),
          ),
        ],
      ),
    );
  }
}

class _AlertStyleTile extends StatelessWidget {
  const _AlertStyleTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final NovynAlertStyleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _AlertStyleArtwork(styleId: option.id, compact: true),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded,
                        color: colors.primary, size: 19),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                option.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.25,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertStyleArtwork extends StatelessWidget {
  const _AlertStyleArtwork({
    required this.styleId,
    this.compact = false,
  });

  final String styleId;
  final bool compact;

  static const _purple = Color(0xFF6C4DF6);
  static const _softPurple = Color(0xFFEAE4FF);
  static const _green = Color(0xFF15803D);
  static const _softGreen = Color(0xFFDDF3E8);
  static const _muted = Color(0xFF6B6880);

  @override
  Widget build(BuildContext context) {
    final height = compact ? 74.0 : 92.0;
    switch (styleId) {
      case 'snackbar':
        return Container(
          height: compact ? 48 : 58,
          width: compact ? 160 : 260,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B29),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Profile saved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Undo',
                style: TextStyle(
                  color: const Color(0xFFC4B9FF),
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      case 'top_banner':
        return Container(
          height: compact ? 56 : 66,
          width: compact ? 166 : 270,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: .10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _softGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: _green, size: 18),
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Profile saved',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: _softGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('ON',
                          style: TextStyle(
                              color: _green,
                              fontSize: 8,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: const LinearProgressIndicator(
                  value: .62,
                  minHeight: 3,
                  backgroundColor: _softPurple,
                  valueColor: AlwaysStoppedAnimation<Color>(_purple),
                ),
              ),
            ],
          ),
        );
      case 'capsule':
        return Container(
          height: 44,
          width: compact ? 160 : 230,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: .22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Profile saved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'switch_card':
        return Container(
          height: 58,
          width: compact ? 168 : 270,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded,
                    color: _green, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Profile saved',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                width: 36,
                height: 22,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerRight,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'centre_hud':
        return Container(
          height: compact ? 74 : 104,
          width: compact ? 74 : 104,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 31 : 42,
                height: compact ? 31 : 42,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.check_rounded,
                    color: _green, size: compact ? 19 : 24),
              ),
              const SizedBox(height: 5),
              const Text(
                'Saved',
                style: TextStyle(
                  color: Color(0xFF1C1B29),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      case 'countdown_card':
        return Container(
          height: 58,
          width: compact ? 168 : 270,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: .62,
                        strokeWidth: 3,
                        color: _purple,
                      ),
                    ),
                    const Icon(Icons.check_rounded,
                        color: _green, size: 17),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Profile saved',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Undo',
                style: TextStyle(
                  color: _purple,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      default:
        return SizedBox(height: height);
    }
  }
}
