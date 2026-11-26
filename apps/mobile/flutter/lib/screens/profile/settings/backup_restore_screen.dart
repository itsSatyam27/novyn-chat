import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/backup_automation_service.dart';
import '../../../services/backup_password_service.dart';
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
  String _networkPreference = BackupAutomationService.wifiOnly;
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
    final network = await BackupAutomationService.networkPreference();
    if (!mounted) return;
    setState(() {
      _dailyEnabled = enabled;
      _lastAutomaticBackup = last;
      _networkPreference = network;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1D1933);
    final muted = dark ? Colors.white70 : const Color(0xFF6D6885);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF111019) : const Color(0xFFF5F1FC),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_rounded, color: ink, size: 25),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Backup & restore',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ink, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF292342) : const Color(0xFFEDE8FB),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(children: [
                Icon(Icons.verified_user_outlined, color: colors.primary, size: 23),
                const SizedBox(width: 12),
                Expanded(child: Text('AES-256 encrypted · password required to restore',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.primary, fontWeight: FontWeight.w800, height: 1.15))),
              ]),
            ),
            const SizedBox(height: 30),
            _heading(context, 'AUTOMATIC BACKUP'),
            const SizedBox(height: 10),
            Container(
              decoration: _cardDecoration(context).copyWith(borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Column(children: [
                Row(children: [
                  _backupIcon(Icons.calendar_month_rounded, const Color(0xFF3478C5),
                    const Color(0xFFE6F0FC)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily Google Drive backup',
                      style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                    Text('Wi-Fi only',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ])),
                  Switch.adaptive(value: _dailyEnabled,
                    onChanged: _working ? null : _setDailyBackup),
                ]),
                if (_dailyEnabled || _lastAutomaticBackup != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text(
                    _lastAutomaticBackup == null
                      ? 'Enabled · runs when Novyn opens on Wi-Fi'
                      : 'Last backup · ${_lastAutomaticBackup!.toString().substring(0, 16)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted))),
                ],
              ]),
            ),
            const SizedBox(height: 30),
            _heading(context, 'CREATE A BACKUP'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.add_to_drive_rounded, const Color(0xFF3478C5), 'Back up to Google Drive',
                'Save an encrypted copy to your private Drive app folder.', () => _drive(restore: false)),
              _ActionItem(Icons.file_upload_outlined, const Color(0xFF7652F5), 'Export backup file',
                'Save an encrypted backup file to your device.', () => _file(restore: false)),
            ]),
            const SizedBox(height: 30),
            _heading(context, 'RESTORE A BACKUP'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.cloud_download_outlined, const Color(0xFF3478C5), 'Restore from Google Drive',
                'Find a Novyn backup in the Google account you select.', () => _drive(restore: true)),
              _ActionItem(Icons.file_download_outlined, const Color(0xFF15966C), 'Restore from backup file',
                'Choose a backup file from your device or storage.', () => _file(restore: true)),
            ]),
            const SizedBox(height: 30),
            _heading(context, 'INCLUDED IN BACKUP'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: _cardDecoration(context).copyWith(borderRadius: BorderRadius.circular(28)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _included(context, Icons.chat_bubble_outline_rounded, 'Messages')),
                  Expanded(child: _included(context, Icons.people_alt_outlined, 'Contacts')),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _included(context, Icons.call_outlined, 'Call history')),
                  Expanded(child: _included(context, Icons.key_outlined, 'Encryption keys')),
                ]),
                const SizedBox(height: 18),
                Divider(color: colors.outlineVariant.withValues(alpha: .6), height: 1),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: muted, size: 19),
                  const SizedBox(width: 11),
                  Expanded(child: Text(
                    'Media up to 45 MB per backup, 100 MB in total. Restoring merges data and never erases newer local chats.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.45))),
                ]),
              ]),
            ),
            const SizedBox(height: 30),
            _heading(context, 'ENCRYPTION IDENTITY'),
            const SizedBox(height: 10),
            _actionCard(context, [
              _ActionItem(Icons.cloud_upload_outlined, const Color(0xFFAD7416), 'Protect encryption identity',
                'Save an encrypted recovery copy to your Novyn account.', () => _identity(restore: false)),
              _ActionItem(Icons.key_rounded, const Color(0xFFAD7416), 'Restore encryption identity',
                'Recover your existing identity to decrypt old messages.', () => _identity(restore: true)),
            ]),
            if (_working) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 8),
              Center(child: Text(_activeAction ?? 'Working…',
                style: theme.textTheme.bodySmall?.copyWith(color: muted))),
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF3A2027) : const Color(0xFFFDEBEC),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFC52E2E), size: 23),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Keep your backup password safe. Novyn can’t decrypt or reset a forgotten backup password.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xFFFFB8B8) : const Color(0xFF9F2525),
                    height: 1.4, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupIcon(IconData icon, Color foreground, Color background) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
    child: Icon(icon, color: foreground, size: 29),
  );

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
