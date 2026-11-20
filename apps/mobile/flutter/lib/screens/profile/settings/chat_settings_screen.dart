import 'dart:ui';
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
                                  style: const TextStyle(fontSize: 26),
                                ),
                                if (active)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      decoration: const BoxDecoration(
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Chat Settings',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 14),

            // Top Hero Card
            _ChatHeroCard(isDark: isDark),
            const SizedBox(height: 22),

            // CHAT BEHAVIOR Section
            _sectionLabel('CHAT BEHAVIOR', colors),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _ChatToggleRow(
                  icon: Icons.keyboard_return_rounded,
                  iconColor: const Color(0xFF6366F1),
                  iconBgColor:
                      isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  title: 'Enter to send',
                  subtitle:
                      'Pressing Enter sends your message instead of adding a new line',
                  value: settings.chatEnterToSend,
                  onChanged: settings.setChatEnterToSend,
                ),
                _ChatToggleRow(
                  icon: Icons.visibility_outlined,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor:
                      isDark ? const Color(0xFF1B3330) : const Color(0xFFCCFBF1),
                  title: 'Message preview',
                  subtitle: 'Show message text in chat notifications',
                  value: settings.messagePreview,
                  onChanged: settings.setMessagePreview,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // QUICK REACTIONS Section
            _sectionLabel('QUICK REACTIONS', colors),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _ChatActionRow(
                  icon: Icons.emoji_emotions_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor:
                      isDark ? const Color(0xFF382D1B) : const Color(0xFFFEF3C7),
                  title: 'Quick reaction emojis',
                  subtitle:
                      '${_quickReactionEmojis.length} selected for the chat composer',
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2E2A44)
                          : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_quickReactionEmojis.length}/$maxQuickReactionEmojiCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  onTap: _showQuickReactionSettings,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // CHAT DISPLAY & TYPOGRAPHY Section
            _sectionLabel('CHAT DISPLAY & TYPOGRAPHY', colors),
            const SizedBox(height: 8),
            _groupedCard(
              context,
              children: [
                _ChatToggleRow(
                  icon: Icons.link_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor:
                      isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                  title: 'Link previews',
                  subtitle: 'Show website previews below shared links',
                  value: settings.chatLinkPreviews,
                  onChanged: settings.setChatLinkPreviews,
                ),
                _ChatSliderRow(
                  icon: Icons.text_fields_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor:
                      isDark ? const Color(0xFF291E3B) : const Color(0xFFF3E8FF),
                  title: 'Message text size',
                  subtitle: 'Change the font size of chat messages',
                  value: settings.fontSize,
                  min: 0.85,
                  max: 1.25,
                  divisions: 8,
                  onChanged: settings.setFontSize,
                ),
                _ChatSliderRow(
                  icon: Icons.format_size_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBgColor:
                      isDark ? const Color(0xFF3B1D2C) : const Color(0xFFFCE7F3),
                  title: 'Chat labels size',
                  subtitle: 'Change timestamps, edited tags and info labels',
                  value: settings.chatLabelSize,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  onChanged: settings.setChatLabelSize,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // CHAT BACKUP & RESTORE Section
            _sectionLabel('CHAT BACKUP & RESTORE', colors),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF202035)
                    : const Color(0xFFF0EDFF).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 19,
                    color: Color(0xFF6D5DFC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your chat backup is encrypted with a password you choose. Drive backups are stored in Novyn’s private app folder. It restores locally cached messages, contacts and conversation keys. Keep your recovery passwords safe.',
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
            const SizedBox(height: 10),
            _groupedCard(
              context,
              children: [
                _ChatActionRow(
                  icon: Icons.file_upload_outlined,
                  iconColor: const Color(0xFF6366F1),
                  iconBgColor:
                      isDark ? const Color(0xFF28234B) : const Color(0xFFEDE9FE),
                  title: 'Back up chats',
                  subtitle: 'Create a password-protected local backup file',
                  onTap: _working ? null : () => _runBackup(restore: false),
                ),
                _ChatActionRow(
                  icon: Icons.settings_backup_restore_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor:
                      isDark ? const Color(0xFF1B3330) : const Color(0xFFCCFBF1),
                  title: 'Restore chats',
                  subtitle: 'Import a Novyn backup file for this account',
                  onTap: _working ? null : () => _runBackup(restore: true),
                ),
                _ChatActionRow(
                  icon: Icons.add_to_drive_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor:
                      isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                  title: 'Back up to Google Drive',
                  subtitle: 'Save encrypted backup in your private Drive folder',
                  onTap: _working ? null : () => _runDriveBackup(restore: false),
                ),
                _ChatActionRow(
                  icon: Icons.cloud_download_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor:
                      isDark ? const Color(0xFF291E3B) : const Color(0xFFF3E8FF),
                  title: 'Restore from Google Drive',
                  subtitle: 'Restore the latest backup saved in Google Drive',
                  onTap: _working ? null : () => _runDriveBackup(restore: true),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // E2EE ACCOUNT RECOVERY Section
            _sectionLabel('E2EE ACCOUNT RECOVERY', colors),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C2C27)
                    : const Color(0xFFE8F8F0).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D4B3F)
                      : const Color(0xFFB8EAD1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.enhanced_encryption_rounded,
                    size: 19,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Save your message identity as an encrypted backup. Only your recovery password can unlock it; Novyn servers cannot read your private key. Use the same password when switching devices.',
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
            const SizedBox(height: 10),
            _groupedCard(
              context,
              children: [
                _ChatActionRow(
                  icon: Icons.cloud_upload_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor:
                      isDark ? const Color(0xFF183327) : const Color(0xFFE8F8F0),
                  title: 'Back up encryption key',
                  subtitle: 'Securely sync your device identity to your account',
                  onTap: _working ? null : () => _runE2eeRecovery(restore: false),
                ),
                _ChatActionRow(
                  icon: Icons.key_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor:
                      isDark ? const Color(0xFF382D1B) : const Color(0xFFFEF3C7),
                  title: 'Restore encryption key',
                  subtitle: 'Recover your previous identity on this device',
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
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Working on backup…',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please keep Novyn open until finished.',
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
            const SizedBox(height: 24),
            Center(
              child: Text(
                'NOVYN · YOUR SPACE, YOUR PEOPLE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, ColorScheme colors) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant,
          ),
        ),
      );

  static Widget _groupedCard(BuildContext context,
      {required List<Widget> children}) {
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
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the recovery password you used when backing up this account’s E2EE identity.'
                : 'Create a recovery password with at least 12 characters. You will need this same password after reinstalling or changing phones.',
                style: const TextStyle(fontSize: 13, height: 1.4)),
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
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the password used when this backup was created.'
                : 'Choose a password with at least 8 characters. You will need it to restore this backup.',
                style: const TextStyle(fontSize: 13, height: 1.4)),
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

// ── Components ─────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ScreenHeader({required this.title, required this.onBack});

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

class _ChatHeroCard extends StatelessWidget {
  final bool isDark;

  const _ChatHeroCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.forum_rounded,
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
                  'Chat experience',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalise your chat behavior, font sizing and backups.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B3327)
                        : const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'E2EE protected',
                        style: TextStyle(
                          color: Color(0xFF10B981),
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

class _ChatToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ChatToggleRow({
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
            activeTrackColor: const Color(0xFF6366F1),
            onChanged: (val) {
              HapticService.vibrate(NovynHapticType.selection);
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}

class _ChatActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ChatActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticService.vibrate(NovynHapticType.light);
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null) trailing!,
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatSliderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _ChatSliderRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = '${(value * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          Row(
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
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2E2A44)
                      : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percent,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 58),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: const Color(0xFF6366F1),
                    thumbColor: const Color(0xFF6366F1),
                    overlayColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
