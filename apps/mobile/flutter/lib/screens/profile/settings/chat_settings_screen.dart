import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:novyn/widgets/novyn_alert.dart';

import '../../../services/auth_service.dart';
import '../../../services/chat_backup_service.dart';
import '../../../services/google_drive_backup_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../utils/quick_reaction_preferences.dart';
import '../../../widgets/custom_emoji.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _working = false;
  List<String> _quickReactionEmojis =
      List<String>.from(defaultQuickReactionEmojis);

  @override
  void initState() {
    super.initState();
    _loadQuickReactionEmojis();
  }

  Future<void> _loadQuickReactionEmojis() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(quickReactionEmojisPreferenceKey);
    if (!mounted) return;
    setState(
      () => _quickReactionEmojis = normalizeQuickReactionEmojis(saved),
    );
  }

  Future<void> _showMessageRetentionInfo() async {
    final socket = context.read<SocketService>();
    var label = 'Forever';
    try {
      final result = await socket.fetchAccountSettings();
      final raw = result['settings'] is Map ? (result['settings'] as Map)['retentionDays'] : null;
      final days = raw is num ? raw.toInt() : 0;
      label = days <= 0 ? 'Forever' : '$days days';
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context, backgroundColor: NovynTheme.cardBg(context), showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Message retention', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [Icon(Icons.history_rounded, color: Theme.of(sheetContext).colorScheme.primary), const SizedBox(width: 10), Text(label, style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          Text('Your account keeps messages in chat history until you or the chat participants explicitly delete them. Any disappearing-message timer configured inside an individual chat still applies to that chat.', style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 14),
          Text('The account-wide retention setting currently supports Forever.', style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      )),
    );
  }

  Future<void> _showQuickReactionSettings() async {
    final selected = Set<String>.from(_quickReactionEmojis);
    final next = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, refresh) => SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * .75,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: NovynTheme.cardBg(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick reaction emojis',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose up to $maxQuickReactionEmojiCount emojis for one-tap reactions in the chat composer.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: novynCustomEmojiNames.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, index) {
                        final emoji = novynCustomEmojiNames[index];
                        final active = selected.contains(emoji);
                        return Material(
                          color: active
                              ? scheme.primary.withValues(alpha: .18)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticService.vibrate(NovynHapticType.selection);
                              if (active) {
                                refresh(() => selected.remove(emoji));
                              } else if (selected.length <
                                  maxQuickReactionEmojiCount) {
                                refresh(() => selected.add(emoji));
                              } else {
                                NovynAlert.show(
                                  context,
                                  'You can select up to $maxQuickReactionEmojiCount quick emojis.',
                                  isError: true,
                                  title: 'Emoji limit reached',
                                  icon: Icons.emoji_emotions_rounded,
                                );
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  novynCustomEmojis[emoji] ?? '',
                                  style: TextStyle(fontSize: 26),
                                ),
                                if (active)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              HapticService.vibrate(NovynHapticType.medium);
                              Navigator.pop(sheetContext, selected.toList());
                            },
                      child: Text(
                        'Save ${selected.length}/$maxQuickReactionEmojiCount emojis',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (next == null) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(quickReactionEmojisPreferenceKey, next);
      if (!mounted) return;
      setState(
        () => _quickReactionEmojis = normalizeQuickReactionEmojis(next),
      );
    } catch (error) {
      if (mounted) {
        NovynAlert.show(
          context,
          'Could not save quick reaction emojis: $error',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Chat Settings',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // CHAT BEHAVIOR Section
            _sectionHeader('CHAT BEHAVIOR'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.keyboard_return_rounded,
                    const Color(0xFF6366F1),
                    isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  ),
                  title: 'Enter to send',
                  trailing: _purpleSwitch(
                    value: settings.chatEnterToSend,
                    onChanged: settings.setChatEnterToSend,
                    context: context,
                  ),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.remove_red_eye_outlined,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFCCFBF1),
                  ),
                  title: 'Message preview',
                  trailing: _purpleSwitch(
                    value: settings.messagePreview,
                    onChanged: settings.setMessagePreview,
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CHAT HISTORY & RETENTION
            _sectionHeader('CHAT HISTORY & RETENTION'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(Icons.history_rounded, const Color(0xFF10B981), isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0)),
                  title: 'Message retention',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0), borderRadius: BorderRadius.circular(12)),
                      child: Text('Forever', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669))),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline_rounded, color: Color(0xFF8F8BA0), size: 19),
                  ]),
                  onTap: _showMessageRetentionInfo,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // QUICK REACTIONS Section
            _sectionHeader('QUICK REACTIONS'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.sentiment_satisfied_alt_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF382A1B) : const Color(0xFFFEF3C7),
                  ),
                  title: 'Quick reaction emojis',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_quickReactionEmojis.length}/$maxQuickReactionEmojiCount',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showQuickReactionSettings,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CHAT DISPLAY & TYPOGRAPHY Section
            _sectionHeader('CHAT DISPLAY & TYPOGRAPHY'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.link_rounded,
                    const Color(0xFF2563EB),
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                  ),
                  title: 'Link previews',
                  trailing: _purpleSwitch(
                    value: settings.chatLinkPreviews,
                    onChanged: settings.setChatLinkPreviews,
                    context: context,
                  ),
                ),
                _ChatTypographySliderRow(
                  icon: Icons.text_fields_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: isDark ? const Color(0xFF291E3B) : const Color(0xFFF3E8FF),
                  title: 'Message text size',
                  value: settings.messageTextSize,
                  min: 0.85,
                  max: 1.25,
                  divisions: 8,
                  onChanged: settings.setMessageTextSize,
                ),
                _ChatTypographySliderRow(
                  icon: Icons.format_size_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBgColor: isDark ? const Color(0xFF3B1D2C) : const Color(0xFFFCE7F3),
                  title: 'Chat labels size',
                  value: settings.chatLabelSize,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  onChanged: settings.setChatLabelSize,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CHAT BACKUP & RESTORE Section
            _sectionHeader('CHAT BACKUP & RESTORE'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.arrow_upward_rounded,
                    const Color(0xFF6366F1),
                    isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  ),
                  title: 'Back up chats',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runBackup(restore: false),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.history_rounded,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                  ),
                  title: 'Restore chats',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runBackup(restore: true),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.add_to_drive_rounded,
                    const Color(0xFF2563EB),
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                  ),
                  title: 'Back up to Google Drive',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runDriveBackup(restore: false),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.cloud_download_outlined,
                    const Color(0xFF8B5CF6),
                    isDark ? const Color(0xFF291E3B) : const Color(0xFFF3E8FF),
                  ),
                  title: 'Restore from Google Drive',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runDriveBackup(restore: true),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // E2EE ACCOUNT RECOVERY Section
            _sectionHeader('E2EE ACCOUNT RECOVERY'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.cloud_upload_outlined,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE8F8F0),
                  ),
                  title: 'Back up encryption key',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runE2eeRecovery(restore: false),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.key_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF382A1B) : const Color(0xFFFEF3C7),
                  ),
                  title: 'Restore encryption key',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8F8BA0),
                    size: 20,
                  ),
                  onTap: _working ? null : () => _runE2eeRecovery(restore: true),
                ),
              ],
            ),

            if (_working) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: NovynTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Working on backup…',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Please keep Novyn open until finished.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF646078),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'NOVYN · YOUR SPACE, YOUR PEOPLE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Color(0xFFA19DB5),
                ),
              ),
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

  static Widget _iconBox(IconData icon, Color color, Color bg) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  static Widget _purpleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    required BuildContext context,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Switch.adaptive(
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
                indent: 68,
                endIndent: 16,
                color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _runBackup({required bool restore}) async {
    final auth = context.read<AuthService>();
    final username = auth.user?.username.trim() ?? '';
    if (username.isEmpty) {
      _message('Sign in to a Novyn account before using chat backup.');
      return;
    }
    final password = await _askBackupPassword(restore: restore);
    if (password == null || !mounted) return;
    setState(() => _working = true);
    try {
      if (restore) {
        final counts = await ChatBackupService.restoreBackup(
          username: username,
          password: password,
          encryption: context.read<SocketService>().encryption,
        );
        if (!mounted || counts == null) return;
        _message(
            'Restored ${counts['messages']} messages, ${counts['chats']} chats, ${counts['contacts']} contacts and ${counts['encryptionKeys']} encryption keys. Reopen Chats to refresh the list.');
      } else {
        final saved = await ChatBackupService.exportBackup(
          username: username,
          password: password,
          encryption: context.read<SocketService>().encryption,
        );
        if (!mounted) return;
        _message(saved
            ? 'Encrypted chat backup saved.'
            : 'Backup export was cancelled.');
      }
    } catch (error) {
      if (!mounted) return;
      _message(error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _runDriveBackup({required bool restore}) async {
    final auth = context.read<AuthService>();
    final username = auth.user?.username.trim() ?? '';
    if (username.isEmpty) {
      _message('Sign in to a Novyn account before using chat backup.');
      return;
    }
    final password = await _askBackupPassword(restore: restore);
    if (password == null || !mounted) return;
    setState(() => _working = true);
    try {
      if (restore) {
        final bytes = await GoogleDriveBackupService.restore();
        if (!mounted) return;
        if (bytes == null) {
          _message(
              'No Novyn chat backup was found in this Google Drive account.');
          return;
        }
        final counts = await ChatBackupService.restoreBackupBytes(
          bytes: bytes,
          username: username,
          password: password,
          encryption: context.read<SocketService>().encryption,
        );
        if (!mounted) return;
        _message(
            'Restored ${counts['messages']} messages, ${counts['chats']} chats, ${counts['contacts']} contacts and ${counts['encryptionKeys']} encryption keys. Reopen Chats to refresh the list.');
      } else {
        final bytes = await ChatBackupService.createEncryptedBackup(
          username: username,
          password: password,
          encryption: context.read<SocketService>().encryption,
        );
        await GoogleDriveBackupService.save(bytes);
        if (!mounted) return;
        _message(
            'Encrypted chat backup saved to your Google Drive app folder.');
      }
    } catch (error) {
      if (!mounted) return;
      _message(error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _runE2eeRecovery({required bool restore}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) {
      _message('Sign in to a Novyn account before using E2EE recovery.');
      return;
    }
    final password = await _askE2eeRecoveryPassword(restore: restore);
    if (password == null || !mounted) return;
    setState(() => _working = true);
    try {
      final socket = context.read<SocketService>();
      if (restore) {
        await socket.restoreE2eeIdentityBackup(password);
        if (!mounted) return;
        _message(
            'Your E2EE identity has been restored and re-registered. Reopen chats to decrypt messages.');
      } else {
        await socket.saveE2eeIdentityBackup(password);
        if (!mounted) return;
        _message('Encrypted E2EE identity backup saved to your Novyn account.');
      }
    } catch (error) {
      if (!mounted) return;
      _message(error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askE2eeRecoveryPassword({required bool restore}) async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var obscure = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(restore
              ? 'Restore encryption identity'
              : 'Protect encryption identity',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the recovery password you used when backing up this account’s E2EE identity.'
                : 'Create a recovery password with at least 12 characters. You will need this same password after reinstalling or changing phones.',
                style: TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'E2EE recovery password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!restore) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Confirm recovery password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final password = controller.text;
                if (password.trim().length < 12 ||
                    (!restore && password != confirm.text)) {
                  dialogContext.showNovynAlert(SnackBar(
                    content: Text(password.trim().length < 12
                        ? 'Recovery password must be at least 12 characters.'
                        : 'Recovery passwords do not match.'),
                  ));
                  return;
                }
                Navigator.pop(dialogContext, password);
              },
              child: Text(restore ? 'Restore' : 'Save recovery backup'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    confirm.dispose();
    return result;
  }

  Future<String?> _askBackupPassword({required bool restore}) async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var obscure = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(restore ? 'Restore chat backup' : 'Protect your backup',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the password used when this backup was created.'
                : 'Choose a password with at least 8 characters. You will need it to restore this backup.',
                style: TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Backup password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!restore) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final password = controller.text;
                if (password.length < 8 ||
                    (!restore && password != confirm.text)) {
                  dialogContext.showNovynAlert(SnackBar(
                    content: Text(password.length < 8
                        ? 'Password must be at least 8 characters.'
                        : 'Passwords do not match.'),
                  ));
                  return;
                }
                Navigator.pop(dialogContext, password);
              },
              child: Text(restore ? 'Continue' : 'Create backup'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    confirm.dispose();
    return result;
  }

  void _message(String message) {
    context.showNovynAlert(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
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

class _SettingsRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticService.vibrate(NovynHapticType.selection);
                onTap!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
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
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTypographySliderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _ChatTypographySliderRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF1A1730);
    final percent = '${(value * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percent,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 56),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8F8BA0) : const Color(0xFF7A768E),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: isDark ? const Color(0xFF2C2844) : const Color(0xFFECE9FB),
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: (v) {
                      HapticService.vibrate(NovynHapticType.selection);
                      onChanged(v);
                    },
                  ),
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
