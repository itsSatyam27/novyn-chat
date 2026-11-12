import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _loading = true;
  bool _working = false;
  bool _enabled = false;
  int _backupCount = 0;
  String? _error;
  String? _setupToken;
  String? _secret;
  String? _otpauthUri;
  List<String> _backupCodes = const [];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.getTwoFactorStatus();
    if (!mounted) return;
    if (result['enabled'] is bool) {
      setState(() {
        _enabled = result['enabled'] == true;
        _backupCount = (result['backupCodesCount'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Could not load security status.';
        _loading = false;
      });
    }
  }

  Future<void> _beginSetup() async {
    setState(() { _working = true; _error = null; });
    final result = await ApiService.beginTwoFactorSetup();
    if (!mounted) return;
    if (result['setupToken'] is String &&
        result['secret'] is String &&
        result['otpauthUri'] is String) {
      setState(() {
        _setupToken = result['setupToken'].toString();
        _secret = result['secret'].toString();
        _otpauthUri = result['otpauthUri'].toString();
        _working = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Could not start setup.';
        _working = false;
      });
    }
  }

  Future<void> _confirmSetup() async {
    final codeController = TextEditingController();
    String? dialogError;
    bool submitting = false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Verify authenticator'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Enter the current 6-digit code shown in your authenticator app.'),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
            ),
            if (dialogError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting ? null : () async {
                final token = _setupToken;
                if (token == null) return;
                if (!RegExp(r'^\d{6}).hasMatch(codeController.text.trim())) {
                  setDialogState(() => dialogError = 'Enter all 6 digits.');
                  return;
                }
                setDialogState(() { submitting = true; dialogError = null; });
                final response = await ApiService.enableTwoFactor(
                  setupToken: token,
                  code: codeController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                if (response['enabled'] == true && response['backupCodes'] is List) {
                  Navigator.pop(dialogContext, response);
                } else {
                  setDialogState(() {
                    submitting = false;
                    dialogError = response['message']?.toString() ?? 'Code verification failed.';
                  });
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify & enable'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    if (!mounted || result == null) return;
    final codes = (result['backupCodes'] as List).map((value) => value.toString()).toList();
    setState(() {
      _enabled = true;
      _backupCount = codes.length;
      _backupCodes = codes;
      _setupToken = null;
      _secret = null;
      _otpauthUri = null;
    });
    await _showBackupCodes();
  }

  Future<void> _showBackupCodes() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A36A)),
          SizedBox(width: 9),
          Expanded(child: Text('Save your backup codes')),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Each code can be used once if you cannot access your authenticator. Save them somewhere private. They will not be shown again.'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                _backupCodes.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, height: 1.8),
              ),
            ),
          ]),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('I saved my codes'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _backupCodes = const []);
  }

  Future<void> _disable() async {
    final auth = context.read<AuthService>();
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    String? dialogError;
    bool submitting = false;
    final user = auth.user;
    final requiresPassword = user?.hasPassword == true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Turn off two-factor authentication?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(requiresPassword
                ? 'Confirm with your current account password.'
                : 'Confirm with a current authenticator code.'),
            const SizedBox(height: 12),
            if (requiresPassword)
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              )
            else
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Authenticator code', counterText: ''),
              ),
            if (dialogError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: submitting ? null : () async {
                setDialogState(() { submitting = true; dialogError = null; });
                final response = await ApiService.disableTwoFactor(
                  currentPassword: passwordController.text,
                  code: codeController.text,
                );
                if (!dialogContext.mounted) return;
                if (response['enabled'] == false) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() {
                    submitting = false;
                    dialogError = response['message']?.toString() ?? 'Could not disable 2FA.';
                  });
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Disable'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
    codeController.dispose();
    if (result == true && mounted) {
      setState(() { _enabled = false; _backupCount = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Authentication')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: _enabled
                          ? [const Color(0xFF147D59), const Color(0xFF24A879)]
                          : [const Color(0xFF5140C9), const Color(0xFF8878F4)],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_enabled ? 'Extra protection is on' : 'Protect your Novyn account',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(_enabled
                          ? 'Your sign-ins require a second verification step.'
                          : 'Use an authenticator app to add a second sign-in check.',
                        style: const TextStyle(color: Colors.white70, height: 1.35)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (_enabled) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_rounded, color: Color(0xFF16A36A)),
                    title: const Text('Authenticator protection enabled'),
                    subtitle: Text('$_backupCount backup codes remaining'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _disable,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Disable two-factor authentication'),
                  ),
                ] else if (_setupToken == null) ...[
                  Text('You will need an authenticator app such as Google Authenticator, Microsoft Authenticator, or 1Password.',
                    style: TextStyle(color: muted, height: 1.5)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _working ? null : _beginSetup,
                    icon: _working
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Set up authenticator'),
                  ),
                ] else ...[
                  const Text('1. Scan this QR code with your authenticator app.'),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: QrImageView(data: _otpauthUri!, size: 210),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Or enter this setup key manually:', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(_secret!, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _working ? null : _confirmSetup,
                    child: const Text('Continue to verification'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _setupToken = null;
                      _secret = null;
                      _otpauthUri = null;
                    }),
                    child: const Text('Cancel setup'),
                  ),
                ],
                if (!_enabled && _setupToken == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('Backup codes are generated once during setup. Keep them private and do not share them.',
                      style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
                  ),
              ],
            ),
    );
  }
}
).hasMatch(codeController.text.trim())) {
                  setDialogState(() => dialogError = 'Enter all 6 digits.');
                  return;
                }
                setDialogState(() { submitting = true; dialogError = null; });
                final response = await ApiService.enableTwoFactor(
                  setupToken: token,
                  code: codeController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                if (response['enabled'] == true && response['backupCodes'] is List) {
                  Navigator.pop(dialogContext, response);
                } else {
                  setDialogState(() {
                    submitting = false;
                    dialogError = response['message']?.toString() ?? 'Code verification failed.';
                  });
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify & enable'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    if (!mounted || result == null) return;
    final codes = (result['backupCodes'] as List).map((value) => value.toString()).toList();
    setState(() {
      _enabled = true;
      _backupCount = codes.length;
      _backupCodes = codes;
      _setupToken = null;
      _secret = null;
      _otpauthUri = null;
    });
    await _showBackupCodes();
  }

  Future<void> _showBackupCodes() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A36A)),
          SizedBox(width: 9),
          Expanded(child: Text('Save your backup codes')),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Each code can be used once if you cannot access your authenticator. Save them somewhere private. They will not be shown again.'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                _backupCodes.join('\\n'),
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, height: 1.8),
              ),
            ),
          ]),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('I saved my codes'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _backupCodes = const []);
  }

  Future<void> _disable() async {
    final auth = context.read<AuthService>();
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    String? dialogError;
    bool submitting = false;
    final user = auth.user;
    final requiresPassword = user?.hasPassword == true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Turn off two-factor authentication?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(requiresPassword
                ? 'Confirm with your current account password.'
                : 'Confirm with a current authenticator code.'),
            const SizedBox(height: 12),
            if (requiresPassword)
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              )
            else
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Authenticator code', counterText: ''),
              ),
            if (dialogError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: submitting ? null : () async {
                setDialogState(() { submitting = true; dialogError = null; });
                final response = await ApiService.disableTwoFactor(
                  currentPassword: passwordController.text,
                  code: codeController.text,
                );
                if (!dialogContext.mounted) return;
                if (response['enabled'] == false) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() {
                    submitting = false;
                    dialogError = response['message']?.toString() ?? 'Could not disable 2FA.';
                  });
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Disable'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
    codeController.dispose();
    if (result == true && mounted) {
      setState(() { _enabled = false; _backupCount = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Authentication')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: _enabled
                          ? [const Color(0xFF147D59), const Color(0xFF24A879)]
                          : [const Color(0xFF5140C9), const Color(0xFF8878F4)],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_enabled ? 'Extra protection is on' : 'Protect your Novyn account',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(_enabled
                          ? 'Your sign-ins require a second verification step.'
                          : 'Use an authenticator app to add a second sign-in check.',
                        style: const TextStyle(color: Colors.white70, height: 1.35)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (_enabled) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_rounded, color: Color(0xFF16A36A)),
                    title: const Text('Authenticator protection enabled'),
                    subtitle: Text('$_backupCount backup codes remaining'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _disable,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Disable two-factor authentication'),
                  ),
                ] else if (_setupToken == null) ...[
                  Text('You will need an authenticator app such as Google Authenticator, Microsoft Authenticator, or 1Password.',
                    style: TextStyle(color: muted, height: 1.5)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _working ? null : _beginSetup,
                    icon: _working
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Set up authenticator'),
                  ),
                ] else ...[
                  const Text('1. Scan this QR code with your authenticator app.'),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: QrImageView(data: _otpauthUri!, size: 210),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Or enter this setup key manually:', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(_secret!, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _working ? null : _confirmSetup,
                    child: const Text('Continue to verification'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _setupToken = null;
                      _secret = null;
                      _otpauthUri = null;
                    }),
                    child: const Text('Cancel setup'),
                  ),
                ],
                if (!_enabled && _setupToken == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('Backup codes are generated once during setup. Keep them private and do not share them.',
                      style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
                  ),
              ],
            ),
    );
  }
}
