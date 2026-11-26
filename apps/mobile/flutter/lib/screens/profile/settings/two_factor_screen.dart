import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/novyn_theme.dart';

class _TwoFactorStep extends StatelessWidget {
  final String number;
  final String text;
  final bool isLast;
  const _TwoFactorStep({required this.number, required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 45,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34, height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.primary.withValues(alpha: .11), shape: BoxShape.circle),
                  child: Text(number, style: TextStyle(color: colors.primary, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: colors.primary.withValues(alpha: .12))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(text, style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool _reuseExistingSecret = false;
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
    if (result['setupToken'] is String && result['reuseExisting'] == true) {
      setState(() {
        _setupToken = result['setupToken'].toString();
        _secret = null;
        _otpauthUri = null;
        _reuseExistingSecret = true;
        _working = false;
      });
    } else if (result['setupToken'] is String &&
        result['secret'] is String &&
        result['otpauthUri'] is String) {
      setState(() {
        _setupToken = result['setupToken'].toString();
        _secret = result['secret'].toString();
        _otpauthUri = result['otpauthUri'].toString();
        _reuseExistingSecret = false;
        _working = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Could not start setup.';
        _working = false;
      });
    }
  }

  Future<void> _copySetupKey() async {
    final key = _secret;
    if (key == null || key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    context.showNovynAlert(const SnackBar(
        content: Text('Setup key copied. Paste it into your authenticator app.'),
        behavior: SnackBarBehavior.floating,
      ));
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
          title: Text(_reuseExistingSecret ? 'Re-enable two-factor authentication' : 'Verify authenticator'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_reuseExistingSecret
                ? 'Your existing authenticator is still linked. Enter its current 6-digit code to turn protection back on.'
                : 'Enter the current 6-digit code shown in your authenticator app.'),
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
                if (!RegExp(r'^\d{6}$').hasMatch(codeController.text.trim())) {
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
                  : Text(_reuseExistingSecret ? 'Verify & re-enable' : 'Verify & enable'),
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
      _reuseExistingSecret = false;
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
      setState(() { _enabled = false; _backupCount = 0; _setupToken = null; _reuseExistingSecret = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final card = NovynTheme.cardBg(context);
    final border = theme.colorScheme.outlineVariant;
    final accent = theme.colorScheme.primary;

    Widget infoCard({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      child: child,
    );

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          child: Material(
            color: NovynTheme.cardBg(context),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: Icon(Icons.arrow_back_rounded, color: ink, size: 23),
            ),
          ),
        ),
        titleSpacing: 8,
        title: const Text('Two-Factor Authentication',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.55)),
      ),
      body: _loading
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: accent),
              const SizedBox(height: 14),
              Text('Checking your security settings…', style: TextStyle(color: muted)),
            ]))
          : _error != null && _setupToken == null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: infoCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: .10), shape: BoxShape.circle),
                        child: Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text('Security status unavailable', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _working ? null : _loadStatus,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ])),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
                        child: Center(
                          child: Text(
                            'Add a second step to your sign-in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: muted, height: 1.4),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: infoCard(child: Row(children: [
                            Icon(Icons.info_outline_rounded, color: theme.colorScheme.error),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, height: 1.4))),
                          ])),
                        ),
                      if (_enabled) ...[
                        infoCard(child: Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF16A36A).withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.shield_rounded, color: Color(0xFF16A36A))),
                          const SizedBox(width: 13),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Authenticator protection enabled', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('$_backupCount backup codes remaining', style: TextStyle(color: muted, fontSize: 12)),
                          ])),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A36A)),
                        ])),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _working ? null : _disable,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Disable two-factor authentication'),
                          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error, side: BorderSide(color: theme.colorScheme.error.withValues(alpha: .45)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        ),
                      ] else if (_setupToken != null && _reuseExistingSecret) ...[
                        infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.verified_user_rounded, color: accent),
                            const SizedBox(width: 9),
                            Expanded(child: Text('Reuse your existing authenticator', style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w800))),
                          ]),
                          const SizedBox(height: 10),
                          Text('No new QR code or setup key is needed. Your previously linked authenticator will work as before.', style: TextStyle(color: muted, height: 1.5, fontSize: 13)),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: FilledButton.icon(
                            onPressed: _working ? null : _confirmSetup,
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Re-enable with existing authenticator'),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          )),
                          TextButton(
                            onPressed: _working ? null : () => setState(() { _setupToken = null; _reuseExistingSecret = false; }),
                            child: const Text('Cancel'),
                          ),
                        ])),
                      ] else if (_setupToken == null) ...[
                        infoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: .11),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(Icons.phone_iphone_rounded, color: accent, size: 25),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Authenticator app', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 3),
                                        Text('Google, Microsoft, 1Password', style: TextStyle(color: muted, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Text('Off', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Divider(color: border),
                              const SizedBox(height: 18),
                              Text('HOW IT WORKS', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .9)),
                              const SizedBox(height: 18),
                              const _TwoFactorStep(number: '1', text: 'Install an authenticator app'),
                              const _TwoFactorStep(number: '2', text: 'Scan the QR code we show you'),
                              const _TwoFactorStep(number: '3', text: 'Enter the one-time code to finish', isLast: true),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton.icon(
                                  onPressed: _working ? null : _beginSetup,
                                  icon: _working
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.qr_code_2_rounded, size: 20),
                                  label: const Text('Set up authenticator', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        infoCard(
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.receipt_long_rounded, color: accent, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Backup codes', style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text('Generated once during setup', style: TextStyle(color: muted, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, color: accent, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Keep your backup codes private and store them somewhere safe.',
                                  style: TextStyle(color: ink, fontSize: 13, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(Icons.qr_code_2_rounded, color: accent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Connect your authenticator', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('Step 1 of 2 · Add your Novyn account', style: TextStyle(color: muted, fontSize: 11)),
                            ])),
                          ]),
                          const SizedBox(height: 17),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: accent.withValues(alpha: .16)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.info_outline_rounded, color: accent, size: 19),
                              const SizedBox(width: 9),
                              Expanded(child: Text(
                                'If Novyn is open on the same phone, you cannot scan its QR with that phone’s camera. Open this screen on another device, or copy the setup key below and enter it manually.',
                                style: TextStyle(color: ink, fontSize: 12, height: 1.45),
                              )),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          Center(child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7))],
                            ),
                            child: QrImageView(
                              data: _otpauthUri!,
                              size: 218,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(color: Color(0xFF172033)),
                              dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF172033)),
                            ),
                          )),
                          const SizedBox(height: 11),
                          Center(child: Text('Scan with Google Authenticator, Microsoft Authenticator, or 1Password', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11, height: 1.4))),
                          const SizedBox(height: 22),
                          Row(children: [
                            Expanded(child: Divider(color: border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('OR ENTER MANUALLY', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                            ),
                            Expanded(child: Divider(color: border)),
                          ]),
                          const SizedBox(height: 15),
                          Text('Your setup key', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 5),
                          Text('In your authenticator app, choose “Enter a setup key” and paste this code.', style: TextStyle(color: muted, fontSize: 12, height: 1.4)),
                          const SizedBox(height: 11),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                            decoration: BoxDecoration(
                              color: NovynTheme.inputBg(context),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: border),
                            ),
                            child: Row(children: [
                              Expanded(child: SelectableText(
                                _secret!,
                                style: TextStyle(color: ink, fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13),
                              )),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: 'Copy setup key',
                                onPressed: _copySetupKey,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.lock_outline_rounded, color: muted, size: 15),
                            const SizedBox(width: 7),
                            Expanded(child: Text('Keep this key private. Anyone with it could generate your sign-in codes.', style: TextStyle(color: muted, fontSize: 11, height: 1.4))),
                          ]),
                          const SizedBox(height: 20),
                          SizedBox(width: double.infinity, child: FilledButton.icon(
                            onPressed: _working ? null : _confirmSetup,
                            icon: const Icon(Icons.verified_user_rounded),
                            label: const Text('I’ve added it · Verify code'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          )),
                          SizedBox(width: double.infinity, child: TextButton(
                            onPressed: _working ? null : () => setState(() { _setupToken = null; _secret = null; _otpauthUri = null; }),
                            child: const Text('Cancel setup'),
                          )),
                        ])),
                      ],
                    ],
                  ),
                ),
    );
  }
}