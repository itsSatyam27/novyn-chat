import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:novyn/widgets/novyn_alert.dart';

import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import 'muted_chats_screen.dart';
import 'sound_vibration_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final Set<String> _savingKeys = <String>{};
  late Future<int> _mutedCountFuture;

  @override
  void initState() {
    super.initState();
    _mutedCountFuture = MutedChatsScreen.countMutedChats(
      context.read<SocketService>(),
    );
  }

  Future<void> _saveServerToggle(
    String key,
    bool value,
    Future<void> Function(bool) saveLocal,
  ) async {
    if (_savingKeys.contains(key)) return;
    setState(() => _savingKeys.add(key));
    try {
      final payload = <String, dynamic>{key: value};
      if (key == 'groupMessagesEnabled') {
        // Retain compatibility with older Novyn clients and the previous
        // Group notifications preference.
        payload['groupNotificationsEnabled'] = value;
      }
      final result = await context
          .read<SocketService>()
          .updateAccountSettings(payload);
      if (result['ok'] != true) {
        throw StateError(
          result['message']?.toString() ?? 'Setting update was not confirmed.',
        );
      }
      await saveLocal(value);
      if (key == 'groupMessagesEnabled') {
        await context.read<SettingsService>().setGroupNotifications(value);
      }
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not save notification setting: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  Future<void> _saveMasterToggle(bool value) async {
    await _saveServerToggle(
      'notificationsEnabled',
      value,
      context.read<SettingsService>().setNotifications,
    );
  }

  Future<void> _savePreviewToggle(bool value) async {
    await _saveServerToggle(
      'messagePreviewEnabled',
      value,
      context.read<SettingsService>().setMessagePreview,
    );
  }

  Future<void> _saveGameTurnDelivery(String value) async {
    const key = 'gameTurnDelivery';
    if (_savingKeys.contains(key)) return;
    setState(() => _savingKeys.add(key));
    try {
      final result = await context.read<SocketService>().updateAccountSettings({
        'gameTurnDelivery': value,
        'gameTurnEnabled': value != 'off',
      });
      if (result['ok'] != true) {
        throw StateError(
          result['message']?.toString() ?? 'Your Turn setting was not saved.',
        );
      }
      await context.read<SettingsService>().setGameTurnDelivery(value);
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not save Your Turn setting: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  Future<void> _pickQuietHours(bool isStart) async {
    final settings = context.read<SettingsService>();
    final current = isStart ? settings.quietHoursStart : settings.quietHoursEnd;
    final pieces = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(pieces.first) ?? (isStart ? 22 : 7),
      minute: pieces.length > 1 ? int.tryParse(pieces[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'QUIET HOURS START' : 'QUIET HOURS END',
    );
    if (picked == null || !mounted) return;
    final start = isStart ? _formatTime(picked) : settings.quietHoursStart;
    final end = isStart ? settings.quietHoursEnd : _formatTime(picked);
    setState(() => _savingKeys.add('quietHoursSchedule'));
    try {
      final result = await context.read<SocketService>().updateAccountSettings({
        'quietHoursStart': start,
        'quietHoursEnd': end,
        'quietHoursOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ?? 'Quiet hours were not saved.');
      }
      await settings.setQuietHoursSchedule(
        start: start,
        end: end,
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not save quiet hours: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove('quietHoursSchedule'));
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _saveQuietHoursToggle(bool value) async {
    final settings = context.read<SettingsService>();
    setState(() => _savingKeys.add('quietHoursEnabled'));
    try {
      final result = await context.read<SocketService>().updateAccountSettings({
        'quietHoursEnabled': value,
        'quietHoursStart': settings.quietHoursStart,
        'quietHoursEnd': settings.quietHoursEnd,
        'quietHoursOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ?? 'Quiet hours were not saved.');
      }
      await settings.setNotificationPreference('quietHoursEnabled', value);
      await settings.setQuietHoursSchedule(
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not save quiet hours: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove('quietHoursEnabled'));
    }
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    HapticService.vibrate(NovynHapticType.light);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) {
      setState(() {
        _mutedCountFuture = MutedChatsScreen.countMutedChats(
          context.read<SocketService>(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = settings.notificationsOn;
    final previews = settings.messagePreview;

    Widget toggle({
      required String key,
      required IconData icon,
      required Color iconColor,
      required Color iconBgColor,
      required String title,
      String? subtitle,
    }) {
      final value = settings.notificationPreference(key);
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .45,
        child: IgnorePointer(
          ignoring: !enabled || _savingKeys.contains(key),
          child: _NotificationToggleRow(
            icon: icon,
            iconColor: iconColor,
            iconBgColor: iconBgColor,
            title: title,
            subtitle: subtitle,
            value: value,
            onChanged: (next) => _saveServerToggle(
              key,
              next,
              (v) => settings.setNotificationPreference(key, v),
            ),
          ),
        ),
      );
    }

    final pink = const Color(0xFFEC4899);
    final indigo = const Color(0xFF6366F1);
    final green = const Color(0xFF10B981);
    final orange = const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: isDark
          ? NovynTheme.pageBg(context)
          : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Notifications',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            _sectionHeader('NOTIFICATION CONTROLS'),
            _groupedCard(context, children: [
              _NotificationToggleRow(
                icon: Icons.notifications_none_rounded,
                iconColor: pink,
                iconBgColor: isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                title: 'Push notifications',
                subtitle: 'Master control for all Novyn alerts',
                value: enabled,
                onChanged: _saveMasterToggle,
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: enabled ? 1 : .45,
                child: IgnorePointer(
                  ignoring: !enabled || _savingKeys.contains('messagePreviewEnabled'),
                  child: _NotificationToggleRow(
                    icon: Icons.remove_red_eye_outlined,
                    iconColor: indigo,
                    iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                    title: 'Message previews',
                    subtitle: 'Show message content in alerts',
                    value: previews,
                    onChanged: _savePreviewToggle,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('MESSAGES'),
            _groupedCard(context, children: [
              toggle(
                key: 'directMessagesEnabled',
                icon: Icons.mark_chat_unread_outlined,
                iconColor: indigo,
                iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                title: 'Direct messages',
              ),
              toggle(
                key: 'groupMessagesEnabled',
                icon: Icons.groups_outlined,
                iconColor: green,
                iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                title: 'Group messages',
              ),
              toggle(
                key: 'mentionsRepliesEnabled',
                icon: Icons.alternate_email_rounded,
                iconColor: orange,
                iconBgColor: isDark ? const Color(0xFF382D1C) : const Color(0xFFFFF2D9),
                title: 'Mentions & replies',
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('SOCIAL ALERTS'),
            _groupedCard(context, children: [
              toggle(
                key: 'friendRequestsEnabled',
                icon: Icons.person_add_alt_1_rounded,
                iconColor: green,
                iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                title: 'Friend requests',
              ),
              toggle(
                key: 'friendRequestAcceptedEnabled',
                icon: Icons.person_add_alt_rounded,
                iconColor: indigo,
                iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                title: 'Request accepted',
              ),
              toggle(
                key: 'groupInvitationsEnabled',
                icon: Icons.group_add_outlined,
                iconColor: pink,
                iconBgColor: isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                title: 'Group invitations',
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('CALLS'),
            _groupedCard(context, children: [
              toggle(
                key: 'voiceCallsEnabled',
                icon: Icons.call_outlined,
                iconColor: green,
                iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                title: 'Voice calls',
              ),
              toggle(
                key: 'videoCallsEnabled',
                icon: Icons.videocam_outlined,
                iconColor: indigo,
                iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                title: 'Video calls',
              ),
              toggle(
                key: 'missedCallsEnabled',
                icon: Icons.call_missed_outgoing_rounded,
                iconColor: orange,
                iconBgColor: isDark ? const Color(0xFF382D1C) : const Color(0xFFFFF2D9),
                title: 'Missed calls',
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('NOVYN GAMES'),
            _groupedCard(context, children: [
              toggle(
                key: 'gameInvitationsEnabled',
                icon: Icons.sports_esports_outlined,
                iconColor: pink,
                iconBgColor: isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                title: 'Game invitations',
              ),
              _GameTurnDeliveryRow(
                value: settings.gameTurnDelivery,
                enabled: enabled,
                saving: _savingKeys.contains('gameTurnDelivery'),
                onChanged: _saveGameTurnDelivery,
              ),
              toggle(
                key: 'gameResultsEnabled',
                icon: Icons.emoji_events_outlined,
                iconColor: orange,
                iconBgColor: isDark ? const Color(0xFF382D1C) : const Color(0xFFFFF2D9),
                title: 'Game results',
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('SOUND & VIBRATION'),
            _groupedCard(context, children: [
              toggle(
                key: 'notificationSoundEnabled',
                icon: Icons.volume_up_outlined,
                iconColor: indigo,
                iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                title: 'Notification sound',
              ),
              toggle(
                key: 'notificationVibrationEnabled',
                icon: Icons.vibration_rounded,
                iconColor: green,
                iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                title: 'Vibration',
              ),
              _NavigationRow(
                icon: Icons.tune_rounded,
                iconColor: orange,
                iconBgColor: isDark ? const Color(0xFF382D1C) : const Color(0xFFFFF2D9),
                title: 'Customize tones & haptics',
                subtitle: 'Choose notification sounds and vibration patterns',
                onTap: () => _open(context, const SoundVibrationScreen()),
              ),
            ]),
            const SizedBox(height: 22),

            _sectionHeader('SCHEDULE'),
            _groupedCard(context, children: [
              _NotificationToggleRow(
                icon: Icons.bedtime_outlined,
                iconColor: indigo,
                iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                title: 'Quiet hours',
                subtitle: 'Silence message, social and game alerts',
                value: settings.notificationPreference('quietHoursEnabled'),
                onChanged: _saveQuietHoursToggle,
              ),
              if (settings.notificationPreference('quietHoursEnabled')) ...[
                _TimeChoiceRow(
                  title: 'Start',
                  value: settings.quietHoursStart,
                  onTap: _savingKeys.contains('quietHoursSchedule')
                      ? null
                      : () => _pickQuietHours(true),
                ),
                _TimeChoiceRow(
                  title: 'End',
                  value: settings.quietHoursEnd,
                  onTap: _savingKeys.contains('quietHoursSchedule')
                      ? null
                      : () => _pickQuietHours(false),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
                  child: Text(
                    'Uses this device’s current time zone. Incoming calls remain available.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 22),

            _sectionHeader('CHAT NOTIFICATIONS'),
            _groupedCard(context, children: [
              FutureBuilder<int>(
                future: _mutedCountFuture,
                builder: (context, snapshot) => _NavigationRow(
                  icon: Icons.notifications_off_outlined,
                  iconColor: pink,
                  iconBgColor: isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                  title: 'Muted chats',
                  subtitle: snapshot.hasData
                      ? '${snapshot.data} muted conversations'
                      : 'Manage muted conversations',
                  onTap: () => _open(context, const MutedChatsScreen()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF6246EA),
        ),
      ),
    );
  }

  static Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                endIndent: 16,
                color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _ScreenHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              HapticService.vibrate(NovynHapticType.light);
              onBack();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    letterSpacing: -.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: dark ? const Color(0xFF3B394E) : const Color(0xFFE2E0EC),
            trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
            onChanged: (next) {
              HapticService.vibrate(NovynHapticType.selection);
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _GameTurnDeliveryRow extends StatelessWidget {
  final String value;
  final bool enabled;
  final bool saving;
  final ValueChanged<String> onChanged;

  const _GameTurnDeliveryRow({
    required this.value,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    final primary = Theme.of(context).colorScheme.primary;
    const choices = <(String, String)>[
      ('in_app', 'In-App'),
      ('push', 'Push + App'),
      ('off', 'Off'),
    ];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : .45,
      child: IgnorePointer(
        ignoring: !enabled || saving,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF10B981), size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your turn', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: ink, letterSpacing: -.2)),
                        const SizedBox(height: 2),
                        Text('Choose how game-turn reminders reach you', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (saving)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final choice in choices) ...[
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticService.vibrate(NovynHapticType.selection);
                          if (choice.$1 != value) onChanged(choice.$1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          decoration: BoxDecoration(
                            color: value == choice.$1 ? primary.withValues(alpha: dark ? .24 : .10) : (dark ? const Color(0xFF28253E) : const Color(0xFFF5F2FA)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: value == choice.$1 ? primary : (dark ? const Color(0xFF37334F) : const Color(0xFFEDE9F6))),
                          ),
                          child: Text(choice.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: value == choice.$1 ? FontWeight.w700 : FontWeight.w500, color: value == choice.$1 ? primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      ),
                    ),
                    if (choice != choices.last) const SizedBox(width: 7),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TimeChoiceRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _TimeChoiceRow({required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 73, right: 18),
      title: Text(title),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(value),
      ),
    );
  }
}
