import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        return StatefulBuilder(
          builder: (context, refresh) => SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * .72,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick reaction emojis',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose up to $maxQuickReactionEmojiCount emojis for the chat composer.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: novynCustomEmojiNames.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (_, index) {
                        final emoji = novynCustomEmojiNames[index];
                        final active = selected.contains(emoji);
                        return Material(
                          color: active
                              ? scheme.primary.withValues(alpha: .16)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () {
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
                                  style: const TextStyle(fontSize: 25),
                                ),
                                if (active)
                                  Positioned(
                                    right: 3,
                                    top: 3,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: scheme.primary,
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
                    child: FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () =>
                              Navigator.pop(sheetContext, selected.toList()),
                      child: Text(
                          'Save ${selected.length}/$maxQuickReactionEmojiCount emojis'),
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        title: const Text('Chat Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _section('CHAT BEHAVIOR'),
          _settingTile(
            context,
            icon: Icons.keyboard_return_rounded,
            title: 'Enter to send',
            subtitle:
                'Pressing Enter sends your message instead of adding a new line',
            trailing: Switch.adaptive(
              value: settings.chatEnterToSend,
              onChanged: settings.setChatEnterToSend,
            ),
          ),
          _settingTile(
            context,
            icon: Icons.visibility_outlined,
            title: 'Message preview',
            subtitle: 'Show message text in chat notifications',
            trailing: Switch.adaptive(
              value: settings.messagePreview,
              onChanged: settings.setMessagePreview,
            ),
          ),
          const SizedBox(height: 22),
          _section('QUICK REACTIONS'),
          _backupAction(
            context,
            icon: Icons.emoji_emotions_outlined,
            title: 'Quick reaction emojis',
            subtitle:
                '${_quickReactionEmojis.length} selected for the chat composer',
            onTap: _showQuickReactionSettings,
          ),
          const SizedBox(height: 22),
          _section('CHAT DISPLAY'),
          _settingTile(
            context,
            icon: Icons.link_rounded,
            title: 'Link previews',
            subtitle: 'Show website previews below shared links',
            trailing: Switch.adaptive(
              value: settings.chatLinkPreviews,
              onChanged: settings.setChatLinkPreviews,
            ),
          ),
          _sizeSettingTile(
            context,
            icon: Icons.text_fields_rounded,
            title: 'Message text size',
            subtitle: 'Change the size of message content',
            value: settings.fontSize,
            min: 0.85,
            max: 1.25,
            divisions: 8,
            onChanged: settings.setFontSize,
          ),
          _sizeSettingTile(
            context,
            icon: Icons.label_outline_rounded,
            title: 'Chat labels size',
            subtitle: 'Change timestamps, edited tags and link details',
            value: settings.chatLabelSize,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            onChanged: settings.setChatLabelSize,
          ),
          const SizedBox(height: 22),
          _section('CHAT BACKUP & RESTORE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.primary.withValues(alpha: .16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your chat backup is encrypted with a password you choose. Drive backups are stored in Novyn’s private app folder and will not appear in Drive browsing. It restores locally cached messages, contacts and conversation keys, but not the account’s private E2EE identity; use E2EE Account Recovery below for that. Keep both recovery passwords safe—Novyn cannot recover them.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45, color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _backupAction(
            context,
            icon: Icons.cloud_upload_outlined,
            title: 'Back up chats',
            subtitle: 'Create a password-protected backup file',
            onTap: _working ? null : () => _runBackup(restore: false),
          ),
          _backupAction(
            context,
            icon: Icons.settings_backup_restore_rounded,
            title: 'Restore chats',
            subtitle: 'Import a Novyn backup for this account',
            onTap: _working ? null : () => _runBackup(restore: true),
          ),
          _backupAction(
            context,
            icon: Icons.add_to_drive_rounded,
            title: 'Back up to Google Drive',
            subtitle:
                'Save an encrypted backup in your private Drive app folder',
            onTap: _working ? null : () => _runDriveBackup(restore: false),
          ),
          _backupAction(
            context,
            icon: Icons.cloud_download_outlined,
            title: 'Restore from Google Drive',
            subtitle: 'Restore the latest backup saved by Novyn',
            onTap: _working ? null : () => _runDriveBackup(restore: true),
          ),
          const SizedBox(height: 22),
          _section('E2EE ACCOUNT RECOVERY'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.primary.withValues(alpha: .16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.enhanced_encryption_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Save your message identity to your Novyn account as an encrypted backup. Only your recovery password can unlock it; Novyn cannot read your private key. Use the same password after reinstalling or moving to a new phone. This is separate from your Novyn sign-in password.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _backupAction(
            context,
            icon: Icons.cloud_upload_outlined,
            title: 'Back up encryption key',
            subtitle: 'Securely sync this device identity to your account',
            onTap: _working ? null : () => _runE2eeRecovery(restore: false),
          ),
          _backupAction(
            context,
            icon: Icons.key_rounded,
            title: 'Restore encryption key',
            subtitle: 'Recover your previous identity on this device',
            onTap: _working ? null : () => _runE2eeRecovery(restore: true),
          ),
          if (_working) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Please keep Novyn open…')),
          ],
        ],
      ),
    );
  }

  String _downloadLabel(String value) => switch (value) {
        'all' => 'All media',
        'photos' => 'Photos only',
        _ => 'Never',
      };

  String _qualityLabel(String value) => switch (value) {
        'high' => 'High quality',
        'medium' => 'Balanced',
        _ => 'Data saver',
      };

  Widget _choiceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .55)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.expand_more_rounded),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      )),
                  const SizedBox(height: 12),
                  ...options.entries.map((entry) => ListTile(
                        title: Text(entry.value),
                        trailing: value == entry.key
                            ? Icon(Icons.check_circle_rounded,
                                color:
                                    Theme.of(sheetContext).colorScheme.primary)
                            : null,
                        onTap: () {
                          onChanged(entry.key);
                          Navigator.pop(sheetContext);
                        },
                      )),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Text(title,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.35,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            )),
      );

  Widget _settingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .55)),
        ),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
          trailing,
        ]),
      );

  Widget _sizeSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final percent = (value * 100).round().toString() + '%';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .55))),
      child: Column(children: [
        Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
          Text(percent,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary)),
        ]),
        Row(children: [
          const Text('A',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
              child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged)),
          const Text('A',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _backupAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .55)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

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
          title: Text(restore
              ? 'Restore encryption identity'
              : 'Protect encryption identity'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the recovery password you used when backing up this account’s E2EE identity.'
                : 'Create a recovery password with at least 12 characters. You will need this same password after reinstalling or changing phones.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'E2EE recovery password',
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!restore) ...[
              const SizedBox(height: 10),
              TextField(
                controller: confirm,
                obscureText: obscure,
                decoration: const InputDecoration(
                    labelText: 'Confirm recovery password'),
              ),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
          title: Text(restore ? 'Restore chat backup' : 'Protect your backup'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(restore
                ? 'Enter the password used when this backup was created.'
                : 'Choose a password with at least 8 characters. You will need it to restore this backup.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Backup password',
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!restore) ...[
              const SizedBox(height: 10),
              TextField(
                  controller: confirm,
                  obscureText: obscure,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password')),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
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
