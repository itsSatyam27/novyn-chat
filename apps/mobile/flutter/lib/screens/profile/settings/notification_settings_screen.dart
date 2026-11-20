import 'package:flutter/material.dart';
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
                  color: const Color(0xFF5E4AE3).withValues(alpha: 0.03),
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
            activeTrackColor: const Color(0xFF5E4AE3),
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
