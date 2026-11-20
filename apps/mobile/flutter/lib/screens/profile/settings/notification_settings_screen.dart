import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:novyn/widgets/novyn_alert.dart';

import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import 'muted_chats_screen.dart';
import 'sound_vibration_screen.dart';
import 'quiet_hours_screen.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _saveServerToggle(
    BuildContext context,
    String key,
    bool value,
    Future<void> Function(bool) saveLocal,
  ) async {
    try {
      final result = await context
          .read<SocketService>()
          .updateAccountSettings({key: value});
      if (result['ok'] != true) {
        throw StateError(
            result['message']?.toString() ?? 'Setting update was not confirmed.');
      }
      await saveLocal(value);
    } catch (error) {
      if (context.mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not save notification setting: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = settings.notificationsOn;
    final previews = settings.messagePreview;

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
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

            // NOTIFICATION CONTROLS Section
            _sectionHeader('NOTIFICATION CONTROLS'),
            _groupedCard(
              context,
              children: [
                _NotificationToggleRow(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBgColor: isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                  title: 'Push notifications',
                  value: enabled,
                  onChanged: (val) => _saveServerToggle(
                    context,
                    'notificationsEnabled',
                    val,
                    settings.setNotifications,
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled ? 1.0 : 0.45,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: _NotificationToggleRow(
                      icon: Icons.remove_red_eye_outlined,
                      iconColor: const Color(0xFF6366F1),
                      iconBgColor: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                      title: 'Message previews',
                      value: previews,
                      onChanged: (val) => _saveServerToggle(
                        context,
                        'messagePreviewEnabled',
                        val,
                        settings.setMessagePreview,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // CONVERSATION ALERTS Section
            _sectionHeader('CONVERSATION ALERTS'),
            _groupedCard(
              context,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled ? 1.0 : 0.45,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: _NotificationToggleRow(
                      icon: Icons.group_outlined,
                      iconColor: const Color(0xFF10B981),
                      iconBgColor: isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                      title: 'Group notifications',
                      value: settings.groupNotifications,
                      onChanged: (val) => _saveServerToggle(
                        context,
                        'groupNotificationsEnabled',
                        val,
                        settings.setGroupNotifications,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            const SizedBox(height: 22),
            const _NotificationCategoryControls(),
            const SizedBox(height: 22),
            _sectionHeader('SOUND & SCHEDULE'),
            _groupedCard(
              context,
              children: [
                _NavigationPreferenceRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound & vibration',
                  subtitle: 'Choose notification sounds and vibration',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SoundVibrationScreen()),
                  ),
                ),
                _NavigationPreferenceRow(
                  icon: Icons.schedule_rounded,
                  title: 'Quiet hours',
                  subtitle: 'Set a schedule for silencing notifications',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const QuietHoursScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionHeader('CHAT NOTIFICATIONS'),
            _groupedCard(
              context,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MutedChatsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Muted chats',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1A1730),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Manage conversations with muted notifications',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF8F8BA0) : const Color(0xFF9A96AA)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
        style: TextStyle(
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
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
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ink,
                size: 20,
              ),
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
                letterSpacing: -0.4,
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
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: ink,
                letterSpacing: -0.2,
              ),
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


class _NavigationPreferenceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavigationPreferenceRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.vibrate(NovynHapticType.selection);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF1A1730))),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 12, color: dark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94))),
            ])),
            Icon(Icons.chevron_right_rounded, color: dark ? const Color(0xFF8F8BA0) : const Color(0xFF9A96AA)),
          ]),
        ),
      ),
    );
  }
}

class _NotificationCategoryControls extends StatefulWidget {
  const _NotificationCategoryControls();

  @override
  State<_NotificationCategoryControls> createState() => _NotificationCategoryControlsState();
}

class _NotificationCategoryControlsState extends State<_NotificationCategoryControls> {
  static const _sections = <String, List<(String, String, IconData)>>{
    'MESSAGES': [
      ('directMessagesEnabled', 'Direct messages', Icons.chat_bubble_outline_rounded),
      ('groupMessagesEnabled', 'Group messages', Icons.groups_outlined),
      ('mentionsRepliesEnabled', 'Mentions & replies', Icons.alternate_email_rounded),
    ],
    'SOCIAL ALERTS': [
      ('friendRequestsEnabled', 'Friend requests', Icons.person_add_alt_1_rounded),
      ('friendRequestAcceptedEnabled', 'Request accepted', Icons.person_check_alt_1_rounded),
      ('groupInvitationsEnabled', 'Group invitations', Icons.group_add_outlined),
    ],
    'CALLS': [
      ('voiceCallsEnabled', 'Voice calls', Icons.call_outlined),
      ('videoCallsEnabled', 'Video calls', Icons.videocam_outlined),
      ('missedCallsEnabled', 'Missed calls', Icons.call_missed_outgoing_rounded),
    ],
    'NOVYN GAMES': [
      ('gameInvitationsEnabled', 'Game invitations', Icons.sports_esports_outlined),
      ('gameTurnEnabled', 'Your turn', Icons.hourglass_bottom_rounded),
      ('gameResultsEnabled', 'Game results', Icons.emoji_events_outlined),
    ],
  };

  final Map<String, bool> _values = {};
  bool _loading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<SocketService>().fetchAccountSettings();
      if (result['ok'] == true && result['settings'] is Map) {
        final raw = Map<String, dynamic>.from(result['settings'] as Map);
        if (!mounted) return;
        setState(() {
          for (final rows in _sections.values) {
            for (final row in rows) {
              _values[row.$1] = raw[row.$1] != false;
            }
          }
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      for (final rows in _sections.values) {
        for (final row in rows) { _values.putIfAbsent(row.$1, () => true); }
      }
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    try {
      final result = await context.read<SocketService>().updateAccountSettings({key: value});
      if (result['ok'] != true) throw StateError(result['message']?.toString() ?? 'Could not save this preference.');
      if (!mounted) return;
      setState(() => _values[key] = value);
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(SnackBar(content: Text('Could not save notification preference: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsService>().notificationsOn;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled || _loading,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final section in _sections.entries) ...[
            NotificationSettingsScreen._sectionHeader(section.key),
            NotificationSettingsScreen._groupedCard(
              context,
              children: [
                for (var i = 0; i < section.value.length; i++)
                  _NotificationToggleRow(
                    icon: section.value[i].$3,
                    iconColor: const Color(0xFF6366F1),
                    iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                    title: section.value[i].$2,
                    value: _values[section.value[i].$1] ?? true,
                    onChanged: (value) => _set(section.value[i].$1, value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ]),
      ),
    );
  }
}
