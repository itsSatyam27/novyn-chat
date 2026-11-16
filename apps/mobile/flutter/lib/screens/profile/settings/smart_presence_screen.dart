import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';

class SmartPresenceScreen extends StatefulWidget {
  const SmartPresenceScreen({super.key});
  @override
  State<SmartPresenceScreen> createState() => _SmartPresenceScreenState();
}
class _SmartPresenceScreenState extends State<SmartPresenceScreen> {
  static const modes = ['online', 'idle', 'busy', 'invisible'];
  static const audiences = ['everyone', 'friends', 'nobody'];
  static const localKeys = {'inAppSoundsEnabled', 'inAppVibrationEnabled'};
  late String editingMode;
  bool saving = false;
  bool hydrating = true;

  @override
  void initState() {
    super.initState();
    final status = context.read<AuthService>().user?.presenceMode ?? 'online';
    editingMode = SettingsService.normalizeSmartPresenceMode(status);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hydrateCurrentMode();
    });
  }

  Future<void> _hydrateCurrentMode() async {
    final settings = context.read<SettingsService>();
    final auth = context.read<AuthService>();
    final mode = SettingsService.normalizeSmartPresenceMode(
      auth.user?.presenceMode ?? 'online',
    );
    try {
      final result = await context.read<SocketService>().fetchAccountSettings();
      if (result['ok'] == true && result['settings'] is Map) {
        final latestMode = SettingsService.normalizeSmartPresenceMode(
          auth.user?.presenceMode ?? mode,
        );
        if (mounted && latestMode == mode) {
          await settings.hydrateSmartPresenceModeFromServer(
            mode,
            Map<String, dynamic>.from(result['settings'] as Map),
          );
          await settings.applySmartPresenceLocalPolicy(mode);
        }
      }
    } catch (_) {
      // Keep the last locally saved preset when the server cannot be reached.
    } finally {
      if (mounted) {
        final latestMode = SettingsService.normalizeSmartPresenceMode(
          auth.user?.presenceMode ?? mode,
        );
        if (settings.activeSmartPresenceMode != latestMode) {
          await settings.applySmartPresenceLocalPolicy(latestMode);
        }
        if (mounted) setState(() => hydrating = false);
      }
    }
  }
  String title(String mode) => switch (mode) {
    'idle' => 'Idle', 'busy' => 'Busy', 'invisible' => 'Invisible', _ => 'Online',
  };
  String audienceLabel(String value) => switch (value) {
    'friends' => 'Friends', 'mutuals' => 'Mutual friends', 'nobody' => 'No one', _ => 'Everyone',
  };

  Future<void> activate() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await context.read<AuthService>().updateStatus(SettingsService.presenceStatusForSmartMode(editingMode));
    } catch (error) {
      if (mounted) context.showNovynAlert(SnackBar(content: Text('Could not activate mode: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Future<void> changePolicy(String key, dynamic value) async {
    if (saving) return;
    final settings = context.read<SettingsService>();
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    final next = {...settings.smartPresencePolicyFor(editingMode), key: value};
    final active = SettingsService.normalizeSmartPresenceMode(auth.user?.presenceMode ?? 'online');
    setState(() => saving = true);
    try {
      if (editingMode == active && !localKeys.contains(key)) {
        final result = await socket.updateAccountSettings({key: value});
        if (result['ok'] != true) throw StateError(result['message']?.toString() ?? 'Setting was not saved.');
      }
      await settings.saveSmartPresenceOverride(editingMode, key, value);
      if (editingMode == active) await settings.applySmartPresenceLocalPolicy(editingMode, policy: next);
    } catch (error) {
      if (mounted) context.showNovynAlert(SnackBar(content: Text('Could not save setting: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Future<void> resetMode() async {
    if (saving) return;
    final settings = context.read<SettingsService>();
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    final active = SettingsService.normalizeSmartPresenceMode(auth.user?.presenceMode ?? 'online');
    final defaults = SettingsService.smartPresenceDefaults(editingMode);
    setState(() => saving = true);
    try {
      if (editingMode == active) {
        final result = await socket.updateAccountSettings(SettingsService.smartPresenceServerFields(defaults));
        if (result['ok'] != true) throw StateError(result['message']?.toString() ?? 'Default policy was not saved.');
        await settings.applySmartPresenceLocalPolicy(editingMode, policy: defaults);
      }
      await settings.resetSmartPresenceOverrides(editingMode);
    } catch (error) {
      if (mounted) context.showNovynAlert(SnackBar(content: Text('Could not reset mode: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Widget heading(BuildContext context, String text, String hint) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
      Text(hint, style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );
  Widget audienceRow(BuildContext context, Map<String, dynamic> p, String key, String label,
      {List<String> options = audiences}) {
    final value = options.contains(p[key]) ? p[key] as String : options.first;
    return ListTile(dense: true, title: Text(label), trailing: DropdownButton<String>(
      value: value, underline: const SizedBox.shrink(),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(audienceLabel(o)))).toList(),
      onChanged: saving || hydrating ? null : (v) { if (v != null) changePolicy(key, v); },
    ));
  }
  Widget toggleRow(Map<String, dynamic> p, String key, String label) => SwitchListTile.adaptive(
    value: p[key] != false, dense: true, title: Text(label),
    onChanged: saving || hydrating ? null : (v) => changePolicy(key, v),
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final active = SettingsService.normalizeSmartPresenceMode(auth.user?.presenceMode ?? 'online');
    final p = settings.smartPresencePolicyFor(editingMode);
    final customized = settings.hasSmartPresenceCustomizations(editingMode);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(title: const Text('Smart Presence'), backgroundColor: NovynTheme.pageBg(context)),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 30), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose a mode', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: modes.map((m) => ChoiceChip(
              selected: editingMode == m, onSelected: saving || hydrating ? null : (_) => setState(() => editingMode = m),
              label: Text('${title(m)}${active == m ? ' · Active' : ''}'),
            )).toList()),
            const SizedBox(height: 9),
            Text(switch (editingMode) {
              'idle' => 'Visible to friends; calls and alerts stay enabled.',
              'busy' => 'Friends see Busy; calls and alerts are disabled.',
              'invisible' => 'Others see Offline, but messages remain available.',
              _ => 'Everyone can see your profile and activity.',
            }),
            Row(children: [
              Text(
                hydrating
                    ? 'Syncing active privacy…'
                    : customized
                        ? 'Customized'
                        : 'Mode defaults',
                style: TextStyle(color: customized ? colors.tertiary : colors.onSurfaceVariant),
              ),
              const Spacer(),
              TextButton(onPressed: saving || hydrating ? null : resetMode, child: const Text('Reset defaults')),
            ]),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: saving || hydrating ? null : activate,
              child: Text(saving ? 'Saving…' : active == editingMode ? 'Reapply mode' : 'Activate ${title(editingMode)}'),
            )),
          ],
        ))),
        heading(context, 'Visibility & privacy', 'Who can see or discover you.'),
        Card(child: Column(children: [
          audienceRow(context, p, 'presencePrivacy', 'Online & last seen'),
          audienceRow(context, p, 'profilePhotoPrivacy', 'Profile photo'),
          audienceRow(context, p, 'discoverPrivacy', 'Discover profile'),
          audienceRow(context, p, 'friendRequestPrivacy', 'Friend requests', options: const ['everyone', 'mutuals', 'nobody']),
        ])),
        heading(context, 'Interactions', 'Who can contact or invite you.'),
        Card(child: Column(children: [
          audienceRow(context, p, 'messagePrivacy', 'Messages'),
          toggleRow(p, 'callsEnabled', 'Allow voice & video calls'),
          audienceRow(context, p, 'callPrivacy', 'Who can call me'),
          audienceRow(context, p, 'groupInvitePrivacy', 'Group invitations'),
        ])),
        heading(context, 'Chat privacy', 'Activity signals shown in conversations.'),
        Card(child: Column(children: [
          toggleRow(p, 'readReceiptsEnabled', 'Read receipts'),
          toggleRow(p, 'typingIndicatorsEnabled', 'Typing indicators'),
        ])),
        heading(context, 'Notifications', 'Alerts can be off while message delivery remains on.'),
        Card(child: Column(children: [
          toggleRow(p, 'notificationsEnabled', 'Push notifications'),
          toggleRow(p, 'messagePreviewEnabled', 'Message previews'),
          toggleRow(p, 'groupNotificationsEnabled', 'Group notifications'),
          toggleRow(p, 'inAppSoundsEnabled', 'In-app sounds'),
          toggleRow(p, 'inAppVibrationEnabled', 'In-app vibration'),
        ])),
        Text(editingMode == 'invisible'
          ? 'Invisible hides presence, last seen, typing and Discover visibility. Messages can still be sent and received.'
          : 'Changes are saved for this mode only and restored when you switch back.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      ]),
    );
  }
}
