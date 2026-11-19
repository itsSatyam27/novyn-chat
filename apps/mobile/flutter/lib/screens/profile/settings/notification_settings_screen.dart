import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:novyn/widgets/novyn_alert.dart';

import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enabled = settings.notificationsOn;
    final previews = settings.messagePreview;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _NotificationHeader(
              title: 'Notifications',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 14),

            // Top Hero Card
            _NotificationHeroCard(enabled: enabled),
            const SizedBox(height: 22),

            // NOTIFICATION CONTROLS Section
            Text(
              'NOTIFICATION CONTROLS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _NotificationToggleRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBgColor:
                      isDark ? const Color(0xFF381F2E) : const Color(0xFFFCE7F3),
                  title: 'Push notifications',
                  subtitle: 'Receive alerts for new activity in Novyn',
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
                      icon: Icons.visibility_rounded,
                      iconColor: const Color(0xFF6366F1),
                      iconBgColor:
                          isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                      title: 'Message previews',
                      subtitle: 'Show message text in notification alerts',
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
            Text(
              'CONVERSATION ALERTS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled ? 1.0 : 0.45,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: _NotificationToggleRow(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF10B981),
                      iconBgColor:
                          isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                      title: 'Group notifications',
                      subtitle: 'Get notified about activity in your groups',
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

            // PREVIEW Section
            Text(
              'PREVIEW',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _LockScreenPreviewCard(
              enabled: enabled,
              showMessage: previews,
            ),
            const SizedBox(height: 18),

            // Info note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF202035)
                    : const Color(0xFFF0EDFF).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF6D5DFC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !enabled
                          ? 'Notifications are paused. You will not receive alerts until notifications are turned back on.'
                          : previews
                              ? 'Message previews are on. Turn them off to hide message text from notification alerts.'
                              : 'Your message content stays hidden in notification previews while this setting is off.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                  color: border.withValues(alpha: 0.65),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _NotificationHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Material(
            color: dark ? const Color(0xFF161726) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticService.vibrate(NovynHapticType.light);
                onBack();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.arrow_back_rounded, color: ink, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _NotificationHeroCard extends StatelessWidget {
  final bool enabled;

  const _NotificationHeroCard({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)]
                    : [colors.onSurfaceVariant.withValues(alpha: 0.5), colors.onSurfaceVariant],
              ),
              boxShadow: [
                BoxShadow(
                  color: (enabled ? const Color(0xFFE11D48) : Colors.black)
                      .withValues(alpha: enabled ? 0.28 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Stay connected' : 'Notifications paused',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Choose what you want to hear about and what stays private.'
                      : 'You will not receive Novyn alerts until notifications are turned on.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: enabled
                        ? (isDark ? const Color(0xFF1B3327) : const Color(0xFFE8F8F0))
                        : (isDark ? const Color(0xFF282833) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: enabled ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        enabled ? 'Alerts are enabled' : 'Alerts are paused',
                        style: TextStyle(
                          color: enabled ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF6D5DFC),
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

class _LockScreenPreviewCard extends StatelessWidget {
  final bool enabled;
  final bool showMessage;

  const _LockScreenPreviewCard({
    required this.enabled,
    required this.showMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 19,
                color: Color(0xFF6D5DFC),
              ),
              const SizedBox(width: 8),
              Text(
                'Lock screen preview',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'EXAMPLE',
                  style: TextStyle(
                    color: Color(0xFF6D5DFC),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lock screen mockup container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1E2140), const Color(0xFF2E2244)]
                    : [const Color(0xFFD6DBFF), const Color(0xFFF3E8FF)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Wed, Nov 18',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '9:41',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 14),

                // Simulated incoming message banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222438) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D5DFC),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Novyn · Alex',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  'now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              !enabled
                                  ? 'Notifications paused'
                                  : showMessage
                                      ? 'Hey, are you free to chat?'
                                      : 'New message',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            !enabled
                ? 'This is only a preview. Notifications are currently turned off.'
                : showMessage
                    ? 'Message text will be visible in notification previews.'
                    : 'Message content is hidden. You will only see that a new message arrived.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
