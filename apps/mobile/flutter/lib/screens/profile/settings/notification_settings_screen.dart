import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_service.dart';
import '../../../theme/novyn_theme.dart';
import '../widgets/profile_widgets.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = settings.notificationsOn;
    final previews = settings.messagePreview;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.45,
          ),
        ),
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        physics: const BouncingScrollPhysics(),
        children: [
          _NotificationHero(enabled: enabled),
          const SectionLabel(label: 'Notification controls'),
          _NotificationToggleCard(
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFEC4899),
            title: 'Push notifications',
            subtitle: 'Receive alerts for new activity in Novyn',
            value: enabled,
            onChanged: settings.setNotifications,
            isPrimary: true,
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : .48,
            child: IgnorePointer(
              ignoring: !enabled,
              child: _NotificationToggleCard(
                icon: Icons.visibility_rounded,
                color: const Color(0xFF6366F1),
                title: 'Message previews',
                subtitle: 'Show message text in notification alerts',
                value: previews,
                onChanged: settings.setMessagePreview,
              ),
            ),
          ),
          const SectionLabel(label: 'Conversation alerts'),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : .48,
            child: IgnorePointer(
              ignoring: !enabled,
              child: _NotificationToggleCard(
                icon: Icons.groups_rounded,
                color: const Color(0xFF10B981),
                title: 'Group notifications',
                subtitle: 'Get notified about activity in your groups',
                value: settings.groupNotifications,
                onChanged: settings.setGroupNotifications,
              ),
            ),
          ),
          const SectionLabel(label: 'Preview'),
          _NotificationPreviewCard(
            enabled: enabled,
            showMessage: previews,
          ),
          const SizedBox(height: 16),
          _NotificationHint(enabled: enabled, previews: previews),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'NOVYN  ·  YOUR SPACE, YOUR PEOPLE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.35,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant.withValues(alpha: .55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHero extends StatelessWidget {
  const _NotificationHero({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = enabled ? const Color(0xFFEC4899) : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .78),
                  accent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .20),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Stay connected' : 'Notifications paused',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  enabled
                      ? 'Choose what you want to hear about and what stays private.'
                      : 'You will not receive Novyn alerts until notifications are turned on.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: enabled ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      enabled ? 'Alerts are enabled' : 'Alerts are turned off',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: enabled ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  const _NotificationToggleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isPrimary = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: value && isPrimary
              ? color.withValues(alpha: .35)
              : colors.outlineVariant,
        ),
        boxShadow: [
          if (value && isPrimary)
            BoxShadow(
              color: color.withValues(alpha: .07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: value ? .15 : .08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: value ? color : colors.onSurfaceVariant,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: value,
                  onChanged: (next) {
                    HapticFeedback.selectionClick();
                    onChanged(next);
                  },
                  activeTrackColor: colors.primary.withValues(alpha: .48),
                  activeColor: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPreviewCard extends StatelessWidget {
  const _NotificationPreviewCard({
    required this.enabled,
    required this.showMessage,
  });

  final bool enabled;
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android_rounded,
                  size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Lock screen preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'EXAMPLE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : .5,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 21,
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
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'now',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showMessage ? 'Hey, are you free to chat?' : 'New message',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            !enabled
                ? 'This is only a preview. Notifications are currently turned off.'
                : showMessage
                    ? 'Message text will be visible in notification previews.'
                    : 'Message content is hidden. You will only see that a new message arrived.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHint extends StatelessWidget {
  const _NotificationHint({
    required this.enabled,
    required this.previews,
  });

  final bool enabled;
  final bool previews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final message = !enabled
        ? 'Turning notifications off does not delete messages. You can still open Novyn and read your chats.'
        : previews
            ? 'Want more privacy? Turn off Message previews to hide message text from notification alerts.'
            : 'Your message content stays hidden in notification previews while this setting is off.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 19, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
