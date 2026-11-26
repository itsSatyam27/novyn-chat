import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/backup_automation_service.dart';
import '../../../services/backup_password_service.dart';
import '../../../services/chat_backup_service.dart';
import '../../../services/google_drive_backup_service.dart';
import '../../../services/message_encryption_service.dart';
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
    final muted = dark ? Colors.white70 : const Color(0xFF625D85);
    final lastBackupLabel = _lastAutomaticBackup == null
        ? 'No successful backup yet'
        : 'Last backup · ${DateFormat('dd MMM yyyy, HH:mm').format(_lastAutomaticBackup!.toLocal())}';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF111019) : const Color(0xFFF6F4FD),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            Row(
              children: [
                Material(
                  color: dark ? const Color(0xFF211E32) : Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.maybePop(context),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(Icons.arrow_back_rounded, color: ink, size: 25),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'Backup & restore',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.65,
                      fontSize: 25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF292342) : const Color(0xFFEDE9FB),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: colors.primary, size: 25),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'AES-256 encrypted · password required to restore',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _heading(context, 'Automatic backup'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(context).copyWith(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _backupIcon(
                        Icons.calendar_month_rounded,
                        colors.primary,
                        colors.primary.withValues(alpha: .11),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Google Drive backup',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Runs once a day',
                              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _dailyEnabled,
                        onChanged: _working ? null : _setDailyBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Back up using',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _networkOption(
                            value: BackupAutomationService.wifiOnly,
                            label: 'Wi-Fi',
                            icon: Icons.wifi_rounded,
                          ),
                        ),
                        Expanded(
                          child: _networkOption(
                            value: BackupAutomationService.mobileDataOnly,
                            label: 'Mobile data',
                            icon: Icons.signal_cellular_alt_rounded,
                          ),
                        ),
                        Expanded(
                          child: _networkOption(
                            value: BackupAutomationService.wifiAndMobileData,
                            label: 'Both',
                            icon: Icons.swap_vert_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF211E32) : const Color(0xFFF5F3FC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: muted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lastBackupLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: dark ? Colors.white : const Color(0xFF3D3868),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _heading(context, 'Back up'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _backupGridTile(
                    context,
                    icon: Icons.cloud_upload_outlined,
                    title: 'Google Drive',
                    onTap: () => _drive(restore: false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _backupGridTile(
                    context,
                    icon: Icons.upload_rounded,
                    title: 'Backup file',
                    onTap: () => _file(restore: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _heading(context, 'Restore'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _backupGridTile(
                    context,
                    icon: Icons.cloud_download_outlined,
                    title: 'Google Drive',
                    onTap: () => _drive(restore: true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _backupGridTile(
                    context,
                    icon: Icons.download_rounded,
                    title: 'Backup file',
                    onTap: () => _file(restore: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _heading(context, 'Encryption identity'),
            const SizedBox(height: 12),
            _actionCard(context, [
              _ActionItem(
                Icons.cloud_upload_outlined,
                colors.primary,
                'Protect encryption identity',
                'Save an encrypted recovery copy to your Novyn account.',
                () => _identity(restore: false),
              ),
              _ActionItem(
                Icons.key_rounded,
                colors.primary,
                'Restore encryption identity',
                'Recover your existing identity to decrypt old messages.',
                () => _identity(restore: true),
              ),
            ]),
            if (_working) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _activeAction ?? 'Working…',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF3A2027) : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFC52E2E), size: 23),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keep your backup password safe. Novyn stores it securely on this device to reuse it for future backups. It is never uploaded in plaintext, and it cannot unlock backups on a new device.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: dark ? const Color(0xFFFFB8B8) : const Color(0xFF9F2525),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
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

  Widget _networkOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = _networkPreference == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _working ? null : () => _setNetworkPreference(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: selected ? Colors.white : colors.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: selected ? Colors.white : colors.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backupGridTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _working ? null : onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 156,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: dark ? colors.primary.withValues(alpha: .17) : const Color(0xFFEDE9FC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: colors.primary, size: 31),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backupIcon(IconData icon, Color foreground, Color background) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
    child: Icon(icon, color: foreground, size: 29),
  );

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600, letterSpacing: -.2)),
  );

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .25)),
  );

  Widget _actionCard(BuildContext context, List<_ActionItem> items) => Container(
    decoration: _cardDecoration(context),
    child: Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        _actionRow(context, items[i]),
        if (i != items.length - 1)
          Padding(
            padding: const EdgeInsets.only(left: 80, right: 16),
            child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
          ),
      ],
    ]),
  );

  Widget _actionRow(BuildContext context, _ActionItem item) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: _working ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)),
            child: Icon(item.icon, color: colors.primary, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.onSurface, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant, size: 25),
        ]),
      ),
    );
  }

  Future<String?> _passwordForNewBackup(String username) async {
    final remembered = await BackupPasswordService.read(username);
    if (remembered != null) return remembered;
    return _passwordDialog(restore: false);
  }

  Future<String?> _askRestorePassword({bool identity = false}) async {
    if (mounted && _working) {
      setState(() {
        _working = false;
        _activeAction = null;
      });
    }
    final password = await _passwordDialog(restore: true, identity: identity);
    if (mounted && password != null) {
      setState(() {
        _working = true;
        _activeAction = 'Verifying backup password…';
      });
    }
    return password;
  }

  Future<void> _file({required bool restore}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) return _show('Sign in to your Novyn account first.');
    final encryption = context.read<SocketService>().encryption;

    if (restore) {
      await _busy('Restoring encrypted backup file…', () async {
        final bytes = await ChatBackupService.pickBackupFileBytes();
        if (bytes == null) return 'Backup selection was cancelled.';
        return _restoreBackupBytes(bytes, username, encryption);
      });
      return;
    }

    final password = await _passwordForNewBackup(username);
    if (password == null || !mounted) return;
    await _busy('Creating encrypted backup file…', () async {
      final saved = await ChatBackupService.exportBackup(
        username: username,
        password: password,
        encryption: encryption,
      );
      if (saved) {
        await BackupPasswordService.save(username, password);
        return 'Encrypted backup file saved. Your backup password is remembered securely on this device.';
      }
      return 'Backup selection was cancelled.';
    });
  }

  Future<void> _drive({required bool restore}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) return _show('Sign in to your Novyn account first.');
    final encryption = context.read<SocketService>().encryption;

    if (restore) {
      await _busy('Restoring from Google Drive…', () async {
        final bytes = await GoogleDriveBackupService.restore();
        if (bytes == null) return 'No Novyn backup was found in that Google Drive account.';
        return _restoreBackupBytes(bytes, username, encryption);
      });
      return;
    }

    final password = await _passwordForNewBackup(username);
    if (password == null || !mounted) return;
    await _busy('Saving encrypted backup to Drive…', () async {
      final bytes = await ChatBackupService.createEncryptedBackup(
        username: username,
        password: password,
        encryption: encryption,
      );
      await GoogleDriveBackupService.save(bytes);
      await BackupPasswordService.save(username, password);
      return 'Encrypted backup saved to your Google Drive app folder. Your backup password is remembered securely on this device.';
    });
  }

  Future<String> _restoreBackupBytes(
    Uint8List bytes,
    String username,
    MessageEncryptionService encryption,
  ) async {
    final remembered = await BackupPasswordService.read(username);
    if (remembered != null) {
      try {
        final counts = await ChatBackupService.restoreBackupBytes(
          bytes: bytes, username: username, password: remembered, encryption: encryption,
        );
        return _restoreSummary(counts);
      } on FormatException catch (error) {
        if (!error.message.toLowerCase().contains('incorrect backup password')) rethrow;
      }
    }
    final entered = await _askRestorePassword();
    if (entered == null || !mounted) return 'Restore was cancelled.';
    final counts = await ChatBackupService.restoreBackupBytes(
      bytes: bytes, username: username, password: entered, encryption: encryption,
    );
    await BackupPasswordService.save(username, entered);
    return _restoreSummary(counts);
  }

  String _restoreSummary(Map<String, int> counts) =>
      'Restored ${counts['messages'] ?? 0} messages, ${counts['chats'] ?? 0} chats, ${counts['contacts'] ?? 0} contacts, ${counts['callLogs'] ?? 0} call logs, ${counts['encryptionKeys'] ?? 0} conversation keys and ${counts['mediaFiles'] ?? 0} media files. Reopen Chats to refresh.';

  Future<void> _identity({required bool restore}) async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    if (username.isEmpty) return _show('Sign in to your Novyn account first.');
    var password = await BackupPasswordService.read(username, identity: true);
    password ??= await _passwordDialog(restore: restore, identity: true);
    if (password == null || !mounted) return;

    await _busy(
      restore ? 'Restoring encryption identity…' : 'Saving encryption identity…',
      () async {
        final socket = context.read<SocketService>();
        if (restore) {
          try {
            await socket.restoreE2eeIdentityBackup(password!);
          } on FormatException {
            final replacement = await _askRestorePassword(identity: true);
            if (replacement == null || !mounted) return 'Identity restore was cancelled.';
            await socket.restoreE2eeIdentityBackup(replacement);
            password = replacement;
          }
          await BackupPasswordService.save(username, password!, identity: true);
          return 'Encryption identity restored. Reopen chats to decrypt messages.';
        }
        await socket.saveE2eeIdentityBackup(password!);
        await BackupPasswordService.save(username, password, identity: true);
        return 'Encrypted identity recovery backup saved. Its recovery password is remembered securely on this device.';
      },
    );
  }

  Future<void> _setNetworkPreference(String preference) async {
    try {
      await BackupAutomationService.setNetworkPreference(preference);
      if (!mounted) return;
      setState(() => _networkPreference = preference);
      final label = switch (preference) {
        BackupAutomationService.mobileDataOnly => 'Mobile data',
        BackupAutomationService.wifiAndMobileData => 'Wi-Fi and mobile data',
        _ => 'Wi-Fi',
      };
      _show('Automatic backups will use $label.');
    } catch (error) {
      if (mounted) _show('Could not update the network preference: $error');
    }
  }

  Future<void> _setDailyBackup(bool enabled) async {
    if (!enabled) {
      try {
        await BackupAutomationService.disableDaily(
          username: context.read<AuthService>().user?.username,
        );
        if (!mounted) return;
        setState(() => _dailyEnabled = false);
        _show('Daily automatic backup turned off. Your saved backup password is kept for future restores.');
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
    var password = await BackupPasswordService.read(username);
    password ??= await _passwordDialog(restore: false);
    if (password == null || !mounted) return;
    final selectedPassword = password;
    await _busy('Creating first encrypted Drive backup…', () async {
      final savedAt = await BackupAutomationService.enableDaily(
        username: username,
        password: selectedPassword,
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
