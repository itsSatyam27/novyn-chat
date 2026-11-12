import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/chat_backup_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        title: const Text('Chat Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _section('CHAT BEHAVIOR'),
          _settingTile(
            context,
            icon: Icons.keyboard_return_rounded,
            title: 'Enter to send',
            subtitle: 'Pressing Enter sends your message instead of adding a new line',
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
                    'Your backup is encrypted with a password you choose. Keep that password safe—Novyn cannot recover it. Restore merges locally cached messages, contacts and conversation encryption keys into this account without deleting newer local data. Keep the backup password private because it protects both your chats and E2EE keys.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45, color: colors.onSurfaceVariant),
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

  Widget _choiceTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
    ),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
              Align(alignment: Alignment.centerLeft, child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              )),
              const SizedBox(height: 12),
              ...options.entries.map((entry) => ListTile(
                title: Text(entry.value),
                trailing: value == entry.key
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(sheetContext).colorScheme.primary)
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
    child: Text(title, style: TextStyle(
      fontSize: 11, letterSpacing: 1.35, fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.primary,
    )),
  );

  Widget _settingTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
    ),
    child: Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      trailing,
    ]),
  );

  Widget _sizeSettingTile(BuildContext context, {
    required IconData icon, required String title, required String subtitle,
    required double value, required double min, required double max,
    required int divisions, required ValueChanged<double> onChanged,
  }) {
    final percent = (value * 100).round().toString() + '%';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: NovynTheme.cardBg(context), borderRadius: BorderRadius.circular(17), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55))),
      child: Column(children: [
        Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Text(percent, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
        ]),
        Row(children: [
          const Text('A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged)),
          const Text('A', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
  Widget _backupAction(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        _message('Restored ${counts['messages']} messages, ${counts['chats']} chats, ${counts['contacts']} contacts and ${counts['encryptionKeys']} encryption keys. Reopen Chats to refresh the list.');
      } else {
        final saved = await ChatBackupService.exportBackup(
          username: username,
          password: password,
          encryption: context.read<SocketService>().encryption,
        );
        if (!mounted) return;
        _message(saved ? 'Encrypted chat backup saved.' : 'Backup export was cancelled.');
      }
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('FormatException: ', '').replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!restore) ...[
              const SizedBox(height: 10),
              TextField(controller: confirm, obscureText: obscure, decoration: const InputDecoration(labelText: 'Confirm password')),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final password = controller.text;
                if (password.length < 8 || (!restore && password != confirm.text)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                    content: Text(password.length < 8 ? 'Password must be at least 8 characters.' : 'Passwords do not match.'),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
