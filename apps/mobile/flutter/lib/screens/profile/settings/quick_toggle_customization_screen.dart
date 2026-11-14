import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';

class QuickToggleCustomizationScreen extends StatefulWidget {
  const QuickToggleCustomizationScreen({
    super.key,
    required this.accountKey,
  });

  final String accountKey;

  @override
  State<QuickToggleCustomizationScreen> createState() =>
      _QuickToggleCustomizationScreenState();
}

class _QuickToggleCustomizationScreenState
    extends State<QuickToggleCustomizationScreen> {
  static const _catalog = <_QuickToggleOption>[
    _QuickToggleOption(
      id: 'app_lock',
      title: 'App Lock',
      description: 'Protect Novyn with your PIN',
      icon: Icons.lock_rounded,
    ),
    _QuickToggleOption(
      id: 'do_not_disturb',
      title: 'Do Not Disturb',
      description: 'Limit incoming alerts',
      icon: Icons.do_not_disturb_on_rounded,
    ),
    _QuickToggleOption(
      id: 'read_receipts',
      title: 'Read Receipts',
      description: 'Control message read indicators',
      icon: Icons.done_all_rounded,
    ),
    _QuickToggleOption(
      id: 'in_app_sounds',
      title: 'In-App Sounds',
      description: 'Play sounds inside Novyn',
      icon: Icons.volume_up_rounded,
    ),
    _QuickToggleOption(
      id: 'in_app_vibration',
      title: 'In-App Vibration',
      description: 'Use vibration feedback in Novyn',
      icon: Icons.vibration_rounded,
    ),
    _QuickToggleOption(
      id: 'group_notifications',
      title: 'Group Alerts',
      description: 'Control group notifications',
      icon: Icons.groups_rounded,
    ),
  ];

  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = context
        .read<SettingsService>()
        .quickToggleIdsFor(widget.accountKey);
  }

  _QuickToggleOption _optionFor(String id) =>
      _catalog.firstWhere((option) => option.id == id);

  Future<void> _save(List<String> ids) async {
    try {
      await context
          .read<SettingsService>()
          .setQuickToggleIdsFor(widget.accountKey, ids);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save Quick Toggles: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleOption(String id) async {
    final updated = List<String>.from(_selectedIds);
    if (updated.contains(id)) {
      if (updated.length == 1) {
        _showMessage('Keep at least one quick toggle visible.');
        return;
      }
      updated.remove(id);
    } else {
      if (updated.length >= SettingsService.maxQuickToggles) {
        _showMessage(
          'You can show a maximum of ${SettingsService.maxQuickToggles} quick toggles.',
        );
        return;
      }
      updated.add(id);
    }

    setState(() => _selectedIds = updated);
    await _save(updated);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<String>.from(_selectedIds);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    setState(() => _selectedIds = updated);
    await _save(updated);
  }

  Future<void> _restoreDefaults() async {
    final defaults = List<String>.from(SettingsService.defaultQuickToggleIds);
    setState(() => _selectedIds = defaults);
    await _save(defaults);
    if (mounted) _showMessage('Default Quick Toggles restored.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = _catalog
        .where((option) => !_selectedIds.contains(option.id))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Quick Toggles'),
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _restoreDefaults,
            child: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: colors.primary.withValues(alpha: .16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_rounded,
                    color: colors.primary, size: 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedIds.length}/${SettingsService.maxQuickToggles} selected',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose the shortcuts that appear on your Settings screen.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'VISIBLE NOW',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Drag the handle to change their order. Remove a shortcut without changing its setting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _selectedIds.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final option = _optionFor(_selectedIds[index]);
              return Container(
                key: ValueKey(option.id),
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  leading: _OptionIcon(option: option),
                  title: Text(
                    option.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(option.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove ${option.title}',
                        onPressed: () => _toggleOption(option.id),
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          color: colors.error,
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 17),
          Text(
            'AVAILABLE SHORTCUTS',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add another shortcut whenever you need it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final option in available)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                leading: _OptionIcon(option: option),
                title: Text(
                  option.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(option.description),
                trailing: TextButton.icon(
                  onPressed: () => _toggleOption(option.id),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This only changes which shortcuts are shown. Your App Lock, DND and other setting values stay as they are.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
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
}

class _QuickToggleOption {
  const _QuickToggleOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

class _OptionIcon extends StatelessWidget {
  const _OptionIcon({required this.option});

  final _QuickToggleOption option;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(option.icon, color: colors.primary, size: 21),
    );
  }
}
