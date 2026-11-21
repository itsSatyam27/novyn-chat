import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/backup_automation_service.dart';
import '../../../services/chat_backup_service.dart';
import '../../../services/google_drive_backup_service.dart';
import '../../../services/socket_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _working = false;
  bool _dailyEnabled = false;
  DateTime? _lastAutomaticBackup;
  String? _activeAction;

  @override
  void initState() {
    super.initState();
    _loadAutomaticBackupStatus();
  }

  Future<void> _loadAutomaticBackupStatus() async {
    final username = context.read<AuthService>().user?.username;
    final enabled = await BackupAutomationService.isEnabled(username: username);
    final last = await BackupAutomationService.lastSuccessfulBackup(username: username);
    if (!mounted) return;
    setState(() {
      _dailyEnabled = enabled;
      _lastAutomaticBackup = last;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF111019) : const Color(0xFFF5F2FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 6),
              Expanded(child: Text('Backup & restore', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: dark
                    ? const [Color(0xFF292148), Color(0xFF1C1A2B)]
                    : const [Color(0xFFEDE8FF), Color(0xFFFFFFFF)]),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: colors.primary.withValues(alpha: .18)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.shield_moon_rounded, color: colors.primary, size: 28),
                const SizedBox(height: 12),
                Text('Your chats, protected', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Backup files are encrypted on this device with AES‑256‑GCM. A backup password is needed to restore them.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 24),
            _heading(context, 'AUTOMATIC BACKUP'),
            const SizedBox(height: 10),
            Container(
              decoration: _cardDecoration(context),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4285F4))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily Google Drive backup', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(_dailyEnabled ? 'Enabled · runs when Novyn opens on Wi-Fi' : 'Off',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ])),
                  Switch(value: _dailyEnabled, onChanged: _working ? null : _setDailyBackup),
                ]),
                const SizedBox(height: 8),
                Text(_lastAutomaticBackup == null
                    ? 'Your first encrypted backup is created when you turn this on.'
                    : 'Last successful backup: ${_lastAutomaticBackup!.toString().substring(0, 16)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 6),
                Text('The password is stored in this device’s secure storage. Automatic uploads use Wi-Fi to avoid mobile data charges and run on app launch/resume; the OS may suspend Novyn while it is closed.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 24),
            _heading(context, 'CREATE A BACKUP'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.add_to_drive_rounded, const Color(0xFF4285F4), 'Back up to Google Drive',
                  'Save an encrypted copy to Novyn’s private Drive app folder.', () => _drive(restore: false)),
              _ActionItem(Icons.file_upload_outlined, const Color(0xFF7C5CFF), 'Export backup file',
                  'Save an encrypted .json backup somewhere you control.', () => _file(restore: false)),
            ]),
            const SizedBox(height: 22),
            _heading(context, 'RESTORE A BACKUP'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.cloud_download_outlined, const Color(0xFF4285F4), 'Restore from Google Drive',
                  'Find the latest Novyn backup in the Google account you select.', () => _drive(restore: true)),
              _ActionItem(Icons.file_download_outlined, const Color(0xFF10A783), 'Restore from backup file',
                  'Choose a Novyn backup file from your device or storage.', () => _file(restore: true)),
            ]),
            const SizedBox(height: 22),
            _heading(context, 'INCLUDED IN BACKUP'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: _cardDecoration(context),
              child: Column(children: [
                _included(context, Icons.chat_bubble_outline_rounded, 'Messages and conversations'),
                _included(context, Icons.people_alt_outlined, 'Saved contacts and chat list'),
                _included(context, Icons.call_outlined, 'On-device call history'),
                _included(context, Icons.key_outlined, 'Conversation encryption keys'),
                const Divider(height: 22),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 9),
                Expanded(child: Text('Attachments are included as encrypted file bytes (up to 45 MB of media per backup; total backup limit 100 MB). E2EE identity recovery is a separate option below. Restore merges data without erasing newer local chats.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.45))),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            _heading(context, 'ENCRYPTION IDENTITY'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.vpn_key_outlined, const Color(0xFFD18A12), 'Protect encryption identity',
                  'Save an encrypted recovery copy to your Novyn account.', () => _identity(restore: false)),
              _ActionItem(Icons.key_rounded, const Color(0xFF9A6B0A), 'Restore encryption identity',
                  'Recover your existing identity before decrypting old messages.', () => _identity(restore: true)),
            ]),
            if (_working) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 8),
              Center(child: Text(_activeAction ?? 'Working…', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: colors.errorContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(18)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: colors.error),
                const SizedBox(width: 10),
                Expanded(child: Text('Keep your backup password safe. Novyn cannot decrypt or reset a forgotten backup password.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface, height: 1.4))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800, letterSpacing: 1.15));

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .65)),
  );

  Widget _actionCard(BuildContext context, List<_ActionItem> items) => Container(
    decoration: _cardDecoration(context),
    child: Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        _actionRow(context, items[i]),
        if (i != items.length - 1) Padding(
          padding: const EdgeInsets.only(left: 66),
          child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
        ),
      ],
    ]),
  );

  Widget _actionRow(BuildContext context, _ActionItem item) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _working ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(
            color: item.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Icon(item.icon, color: item.color, size: 21)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.35)),
          ])),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ]),
      ),
    );
  }

  Widget _included(BuildContext context, IconData icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 11),
      Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium))]),
  );

  Future<void> _file({required bool restore}) => _run(
    label: restore ? 'Restoring backup file…' : 'Creating encrypted backup…',
    restore: restore,
    action: (username, password) async {
      final socket = context.read<SocketService>();
      if (restore) {
        final counts = await ChatBackupService.restoreBackup(
          username: username,
          password: password,
          encryption: socket.encryption,
        );
        return counts == null
            ? 'Backup selection was cancelled.'
            : _restoreSummary(counts);
      }
      final saved = await ChatBackupService.exportBackup(
        username: username,
        password: password,
        encryption: socket.encryption,
      );
      return saved
          ? 'Encrypted backup file saved.'
          : 'Backup selection was cancelled.';
    },
  );

  Future<void> _drive({required bool restore}) => _run(
    label: restore ? 'Restoring from Google Drive…' : 'Saving encrypted backup to Drive…',
    restore: restore,
    action: (username, password) async {
      final socket = context.read<SocketService>();
      if (restore) {
        final bytes = await GoogleDriveBackupService.restore();
        if (bytes == null) return 'No Novyn backup was found in that Google Drive account.';
        return _restoreSummary(await ChatBackupService.restoreBackupBytes(
          bytes: bytes, username: username, password: password, encryption: socket.encryption));
      }
      final bytes = await ChatBackupService.createEncryptedBackup(
        username: username, password: password, encryption: socket.encryption);
      await GoogleDriveBackupService.save(bytes);
      return 'Encrypted backup saved to your Google Drive app folder.';
    },
  );

  String _restoreSummary(Map<String, int> counts) =>
      'Restored ${counts['messages'] ?? 0} messages, ${counts['chats'] ?? 0} chats, ${counts['contacts'] ?? 0} contacts, ${counts['callLogs'] ?? 0} call logs, ${counts['encryptionKeys'] ?? 0} conversation keys and ${counts['mediaFiles'] ?? 0} media files. Reopen Chats to refresh.';

  Future<void> _identity({required bool restore}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) return _show('Sign in to your Novyn account first.');
    final password = await _passwordDialog(restore: restore, identity: true);
    if (password == null || !mounted) return;
    await _busy(restore ? 'Restoring encryption identity…' : 'Saving encryption identity…', () async {
      final socket = context.read<SocketService>();
      if (restore) {
        await socket.restoreE2eeIdentityBackup(password);
        return 'Encryption identity restored. Reopen chats to decrypt messages.';
      }
      await socket.saveE2eeIdentityBackup(password);
      return 'Encrypted identity recovery backup saved to your Novyn account.';
    });
  }

  Future<void> _setDailyBackup(bool enabled) async {
    if (!enabled) {
      try {
        await BackupAutomationService.disableDaily(
          username: context.read<AuthService>().user?.username,
        );
        if (!mounted) return;
        setState(() => _dailyEnabled = false);
        _show('Daily automatic backup turned off.');
      } catch (error) {
        if (mounted) _show('Could not update the backup setting: $error');
      }
      return;
    }
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) {
      _show('Sign in to your Novyn account first.');
      return;
    }
    final password = await _passwordDialog(restore: false);
    if (password == null || !mounted) return;
    await _busy('Creating first encrypted Drive backup…', () async {
      final savedAt = await BackupAutomationService.enableDaily(
        username: username,
        password: password,
        encryption: context.read<SocketService>().encryption,
      );
      if (mounted) {
        setState(() {
          _dailyEnabled = true;
          _lastAutomaticBackup = savedAt;
        });
      }
      return 'Daily backup enabled. Your first encrypted Drive backup is saved.';
    });
  }

  Future<void> _run({required String label, required bool restore,
      required Future<String> Function(String username, String password) action}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) return _show('Sign in to your Novyn account first.');
    final password = await _passwordDialog(restore: restore);
    if (password == null || !mounted) return;
    await _busy(label, () => action(username, password));
  }

  Future<void> _busy(String label, Future<String> Function() action) async {
    setState(() { _working = true; _activeAction = label; });
    try {
      final message = await action();
      if (mounted) _show(message);
    } catch (error) {
      if (mounted) _show(error.toString().replaceFirst('FormatException: ', '').replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() { _working = false; _activeAction = null; });
    }
  }

  Future<String?> _passwordDialog({required bool restore, bool identity = false}) async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var obscure = true;
    final minLength = identity ? 12 : 8;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, refresh) => AlertDialog(
        title: Text(identity ? (restore ? 'Restore encryption identity' : 'Protect encryption identity')
            : (restore ? 'Restore chat backup' : 'Protect your backup')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(restore ? 'Enter the password used to protect this backup.'
              : 'Create a password with at least $minLength characters. You will need it to restore this backup.',
              style: const TextStyle(height: 1.4)),
          const SizedBox(height: 14),
          TextField(controller: controller, autofocus: true, obscureText: obscure,
            decoration: InputDecoration(labelText: identity ? 'Recovery password' : 'Backup password',
              border: const OutlineInputBorder(), suffixIcon: IconButton(
                onPressed: () => refresh(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          if (!restore) ...[
            const SizedBox(height: 10),
            TextField(controller: confirm, obscureText: obscure, decoration: const InputDecoration(
              labelText: 'Confirm password', border: OutlineInputBorder())),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (controller.text.trim().length < minLength || (!restore && controller.text != confirm.text)) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(controller.text.trim().length < minLength
                    ? 'Use at least $minLength characters.'
                    : 'The passwords do not match.'),
              ));
              return;
            }
            Navigator.pop(dialogContext, controller.text);
          }, child: Text(restore ? 'Continue' : 'Create backup')),
        ],
      )),
    );
    controller.dispose();
    confirm.dispose();
    return result;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class _ActionItem {
  const _ActionItem(this.icon, this.color, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
