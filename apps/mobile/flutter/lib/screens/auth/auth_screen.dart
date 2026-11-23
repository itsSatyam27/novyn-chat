import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../main_screen.dart';

// ── Palette constants ───────────────────────────────────────────────────────
const _kBg = Color(0xFFF3F0FB);
const _kAccent = Color(0xFF6C4DF6);
const _kAccentDim = Color(0xFF5B3FE0);
const _kGlow = Color(0xFF6C4DF6);
const _kGreen = Color(0xFF15803D);
const _kRed = Color(0xFFC62828);
const _kPink = Color(0xFFE9A7CD);
const _kText = Color(0xFF1C1B29);
const _kSub = Color(0xFF6B6880);
const _kLine = Color(0xFFE4DFFB);
const _kField = Color(0xFFF6F4FD);
const _kSegment = Color(0xFFE8E2FA);

class AuthScreen extends StatefulWidget {
  /// Opens directly on sign-in (0) or account creation (1).
  final int initialTab;
  const AuthScreen({super.key, this.initialTab = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artworkHeight = keyboardOpen
                  ? 0.0
                  : math.min(
                      constraints.maxHeight * .44,
                      constraints.maxWidth * 620 / 864,
                    );
              return Column(
                children: [
                  if (!keyboardOpen)
                    SizedBox(
                      width: double.infinity,
                      height: artworkHeight,
                      child: Image.asset(
                        'assets/images/novyn_auth_hero.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE8E0FF),
                          child: Center(
                            child: Icon(
                              Icons.chat_bubble_rounded,
                              color: _kAccent,
                              size: 52,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(38),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F6C4DF6),
                            blurRadius: 24,
                            offset: Offset(0, -7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _kLine,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 480),
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _LoginTab(
                                      onSwitchToRegister: () =>
                                          _tabController.animateTo(1),
                                    ),
                                    _RegisterTab(
                                      onSwitchToLogin: () =>
                                          _tabController.animateTo(0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
//  Login Tab
// ══════════════════════════════════════════════════════════════════════════════
class _LoginTab extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  const _LoginTab({required this.onSwitchToRegister});

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  bool _rememberMe = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _fillFromSession(SavedSession s) {
    _emailCtrl.text = s.email;
    setState(() {});
    FocusScope.of(context).nextFocus();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your email or username and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthService>();
    final err  = await auth.login(identifier: _emailCtrl.text, password: _passCtrl.text, remember: _rememberMe);
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else if (auth.isTwoFactorPending) {
      final verified = await _showTwoFactorChallenge();
      if (!mounted) return;
      if (verified) {
        _navigateToMain();
      } else {
        auth.cancelTwoFactorChallenge();
        setState(() => _loading = false);
      }
    } else {
      _navigateToMain();
    }
  }

  Future<bool> _showTwoFactorChallenge() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TwoFactorVerificationScreen(),
      ),
    );
    return verified == true;
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ForgotPasswordDialog(),
    );
  }

  void _navigateToMain() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder:        (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthService>();
    var error = await auth.signInWithGoogle();
    String? selectionError;

    while (error == null && auth.isGoogleUsernamePending) {
      if (!mounted) return;
      final username = await _promptForGoogleUsername(
        context,
        auth,
        errorMessage: selectionError,
      );
      if (!mounted) return;
      if (username == null) {
        await auth.cancelGoogleUsernameSelection();
        if (mounted) setState(() => _loading = false);
        return;
      }

      final signupError = await auth.completeGoogleSignUp(username);
      if (signupError == null) {
        error = null;
        break;
      }
      if (auth.isGoogleUsernamePending) {
        selectionError = signupError;
        continue;
      }
      error = signupError;
    }

    if (!mounted) return;
    if (error != null && error != 'Sign-in cancelled.') {
      setState(() { _error = error; _loading = false; });
    } else if (error == null && auth.isTwoFactorPending) {
      final verified = await _showTwoFactorChallenge();
      if (!mounted) return;
      if (verified) {
        _navigateToMain();
      } else {
        auth.cancelTwoFactorChallenge();
        setState(() => _loading = false);
      }
    } else if (error == null) {
      _navigateToMain();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SettingsService>().savedSessions;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: _kText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your chats and your people are waiting',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, color: _kSub),
          ),
          const SizedBox(height: 22),
          _Field(
            controller: _emailCtrl,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 13),
          _Field(
            controller: _passCtrl,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: _EyeToggle(
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: _rememberMe ? _kAccent : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _rememberMe ? _kAccent : _kLine,
                              width: 1.4,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 19)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Remember me',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: _kSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _showForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: _kAccentDim,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                ),
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kAccentDim,
                  ),
                ),
              ),
            ],
          ),
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 4),
            const _SectionLabel('SAVED ACCOUNTS'),
            const SizedBox(height: 8),
            ...sessions.map((session) => _SavedAccountTile(
              session: session,
              onTap: () => _fillFromSession(session),
              onRemove: () =>
                  context.read<SettingsService>().removeSession(session.uid),
            )),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 9),
          _PrimaryButton(
            label: 'Sign in  →',
            loading: _loading,
            onTap: _submit,
          ),
          const SizedBox(height: 19),
          const _OrDivider(label: 'Or continue with'),
          const SizedBox(height: 14),
          _GoogleButton(
            label: 'Google',
            loading: _loading,
            onTap: _googleSignIn,
          ),
          const SizedBox(height: 18),
          _SwitchLink(
            prefix: 'Don’t have an account? ',
            action: 'Create an account',
            onTap: widget.onSwitchToRegister,
          ),
        ],
      ),
    );
  }
}


class TwoFactorVerificationScreen extends StatefulWidget {
  const TwoFactorVerificationScreen({super.key});

  @override
  State<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends State<TwoFactorVerificationScreen> {
  final _codeCtrl = TextEditingController();
  bool _backupCode = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _codeCtrl.text.trim();
    if (_backupCode ? code.isEmpty : !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = _backupCode
          ? 'Enter one of your unused backup codes.'
          : 'Enter the 6-digit authenticator code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await context.read<AuthService>().verifyTwoFactor(code);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _verifying = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10101B) : const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _verifying ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kAccent, _kAccentDim],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: _kAccent.withValues(alpha: .25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Verify it's you",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                      color: isDark ? Colors.white : const Color(0xFF211D38),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _backupCode
                        ? 'Enter one of the backup codes you saved when you enabled two-factor authentication.'
                        : 'Open your authenticator app and enter the 6-digit code for your Novyn account.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color: isDark ? Colors.white70 : const Color(0xFF77738A),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1B2B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: .08)
                            : const Color(0xFFEAE7F5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? .12 : .04),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _backupCode ? 'BACKUP CODE' : 'AUTHENTICATOR CODE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: isDark ? Colors.white60 : const Color(0xFF858098),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _codeCtrl,
                          autofocus: true,
                          keyboardType: _backupCode
                              ? TextInputType.text
                              : TextInputType.number,
                          textCapitalization: _backupCode
                              ? TextCapitalization.characters
                              : TextCapitalization.none,
                          textInputAction: TextInputAction.done,
                          maxLength: _backupCode ? 12 : 6,
                          onSubmitted: (_) => _verify(),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: _backupCode ? 20 : 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: _backupCode ? 2 : 10,
                            color: isDark ? Colors.white : const Color(0xFF292442),
                          ),
                          decoration: InputDecoration(
                            hintText: _backupCode ? 'ABCD1234' : '000000',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white24 : const Color(0xFFD1CDE0),
                              letterSpacing: _backupCode ? 2 : 10,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF141321)
                                : const Color(0xFFF8F7FC),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE7E3F2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: _kAccent, width: 1.6),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: _kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _verifying ? null : _verify,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kAccentDim,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _verifying
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Verify and continue',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: TextButton(
                      onPressed: _verifying
                          ? null
                          : () {
                              setState(() {
                                _backupCode = !_backupCode;
                                _codeCtrl.clear();
                                _error = null;
                              });
                            },
                      child: Text(
                        _backupCode
                            ? 'Use authenticator app instead'
                            : 'Use a backup code',
                        style: GoogleFonts.inter(
                          color: _kAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account stays protected until this code is verified.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFFA09BAF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _identifierCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Enter your registered email or username.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    final result = await context.read<AuthService>().requestPasswordReset(identifier);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['ok'] == true) {
        _codeSent = true;
        _message = result['message']?.toString() ??
            'If an account exists, a reset code has been sent.';
      } else {
        _error = result['message']?.toString() ?? 'Could not send reset code.';
      }
    });
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (code.isEmpty) {
      setState(() => _error = 'Enter the reset code from your email.');
      return;
    }
    if (password.length < 12) {
      setState(() => _error = 'Password must be at least 12 characters.');
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    final result = await context.read<AuthService>().confirmPasswordReset(
      identifier: _identifierCtrl.text.trim(),
      code: code,
      newPassword: password,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result['ok'] == true) {
      Navigator.of(context).pop();
      context.showNovynAlert(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Password updated. Please sign in.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Could not reset password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101827),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: .09)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: _kAccent, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Reset password', style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18,
                  )),
                ),
                IconButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'Enter the code sent to your registered email and choose a new password.'
                  : 'Enter the email address or username linked to your Novyn account.',
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: .58), fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('EMAIL OR USERNAME'),
            const SizedBox(height: 8),
            _Field(controller: _identifierCtrl, hint: 'Email address or username',
              icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              const _SectionLabel('RESET CODE'),
              const SizedBox(height: 8),
              _Field(controller: _codeCtrl, hint: 'Enter email code',
                icon: Icons.password_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              const _SectionLabel('NEW PASSWORD'),
              const SizedBox(height: 8),
              _Field(controller: _passwordCtrl, hint: 'At least 12 characters',
                icon: Icons.lock_outline_rounded, obscure: _obscurePassword,
                suffix: _EyeToggle(obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword))),
              const SizedBox(height: 14),
              const _SectionLabel('CONFIRM NEW PASSWORD'),
              const SizedBox(height: 8),
              _Field(controller: _confirmCtrl, hint: 'Re-enter new password',
                icon: Icons.lock_outline_rounded, obscure: _obscureConfirm,
                suffix: _EyeToggle(obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm))),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: GoogleFonts.inter(color: _kGreen, fontSize: 12, height: 1.45)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            _PrimaryButton(
              label: _codeSent ? 'Update password' : 'Send reset code',
              loading: _loading,
              onTap: _codeSent ? _resetPassword : _requestCode,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 8),
              Center(child: TextButton(
                onPressed: _loading ? null : _requestCode,
                child: const Text('Send a new code'),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Register Tab
// ══════════════════════════════════════════════════════════════════════════════
class _RegisterTab extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const _RegisterTab({required this.onSwitchToLogin});

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();

  bool _obscurePass    = true;
  bool _loading        = false;
  String? _error;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  int _usernameCheckSequence = 0;
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _checkUsername(String value) {
    final sequence = ++_usernameCheckSequence;
    _usernameDebounce?.cancel();
    final username = value.trim();

    if (username.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final available =
          await context.read<AuthService>().isUsernameAvailable(username);
      if (!mounted || sequence != _usernameCheckSequence) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = available;
      });
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    final name     = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final pass     = _passCtrl.text;

    if (name.isEmpty) { setState(() => _error = 'Please enter your name.'); return; }
    if (username.length < 3) { setState(() => _error = 'Username must be at least 3 characters.'); return; }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) { setState(() => _error = 'Username: letters, numbers & underscores only.'); return; }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) { setState(() => _error = 'Please enter a valid email address.'); return; }
    if (_checkingUsername) { setState(() => _error = 'Please wait while we check your username.'); return; }
    if (_usernameAvailable == false) { setState(() => _error = 'That username is already taken.'); return; }
    if (pass.length < 12) { setState(() => _error = 'Password must be at least 12 characters.'); return; }

    setState(() { _loading = true; _error = null; });

    final err = await context.read<AuthService>().register(
      name: name, username: username, email: email, password: pass,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      _showSuccess();
    }
  }

  Future<void> _googleSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    var error = await auth.signInWithGoogle();
    String? selectionError;

    while (error == null && auth.isGoogleUsernamePending) {
      if (!mounted) return;
      final username = await _promptForGoogleUsername(
        context,
        auth,
        initialUsername: _usernameCtrl.text,
        errorMessage: selectionError,
      );
      if (!mounted) return;
      if (username == null) {
        await auth.cancelGoogleUsernameSelection();
        if (mounted) setState(() => _loading = false);
        return;
      }

      final signupError = await auth.completeGoogleSignUp(username);
      if (signupError == null) {
        error = null;
        break;
      }
      if (auth.isGoogleUsernamePending) {
        selectionError = signupError;
        continue;
      }
      error = signupError;
    }

    if (!mounted) return;
    if (error != null && error != 'Sign-in cancelled.') {
      setState(() {
        _error = error;
        _loading = false;
      });
      return;
    }

    if (error == null && auth.isTwoFactorPending) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const TwoFactorVerificationScreen(),
        ),
      );
      if (!mounted) return;

      if (verified == true) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (_) => false,
        );
      } else {
        auth.cancelTwoFactorChallenge();
        setState(() => _loading = false);
      }
      return;
    }

    if (error == null) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false,
      );
    } else {
      setState(() => _loading = false);
    }
  }


  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _kLine),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _kGreen.withValues(alpha: 0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreen.withValues(alpha: 0.15),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                    boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.check_rounded, color: _kGreen, size: 30),
                ),
              ]),
              const SizedBox(height: 20),
              Text(
                'Account Created!',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _kText),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to Novyn,\n@${_usernameCtrl.text.trim().toLowerCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _kSub, height: 1.5),
              ),
              const SizedBox(height: 28),
              _PrimaryButton(
                label: 'Start Chatting',
                loading: false,
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder:        (_, __, ___) => const MainScreen(),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (_) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create your account',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: _kText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Join Novyn and start chatting',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, color: _kSub),
          ),
          const SizedBox(height: 19),
          _Field(
            controller: _nameCtrl,
            hint: 'Your full name',
            icon: Icons.person_outline_rounded,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _usernameCtrl,
            hint: 'Choose a username',
            icon: Icons.person_outline_rounded,
            onChanged: (value) {
              _checkUsername(value);
              if (_error != null) setState(() => _error = null);
            },
            suffix: _checkingUsername
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kAccent,
                    ),
                  )
                : _usernameAvailable == null
                    ? null
                    : Icon(
                        _usernameAvailable!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _usernameAvailable! ? _kGreen : _kRed,
                        size: 20,
                      ),
          ),
          if (_usernameAvailable == false) ...[
            const SizedBox(height: 5),
            const _StatusLine(
              text: 'This username is taken. Try another.',
              color: _kRed,
            ),
          ],
          if (_usernameAvailable == true) ...[
            const SizedBox(height: 5),
            const _StatusLine(
              text: '✓  Username is available',
              color: _kGreen,
            ),
          ],
          const SizedBox(height: 12),
          _Field(
            controller: _emailCtrl,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _passCtrl,
            hint: 'Create a password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            suffix: _EyeToggle(
              obscure: _obscurePass,
              onToggle: () => setState(() => _obscurePass = !_obscurePass),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 17),
          _PrimaryButton(
            label: 'Create account',
            loading: _loading,
            onTap: _submit,
          ),
          const SizedBox(height: 19),
          const _OrDivider(label: 'Or sign up with'),
          const SizedBox(height: 14),
          _GoogleButton(
            label: 'Google',
            loading: _loading,
            onTap: _googleSignIn,
          ),
          const SizedBox(height: 18),
          _SwitchLink(
            prefix: 'Already have an account? ',
            action: 'Sign in',
            onTap: widget.onSwitchToLogin,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
          color: _kSub,
        ),
      );
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _focused ? const Color(0xFFF1EEFC) : _kField,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: _focused ? _kAccent : _kLine,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _kGlow.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : [],
      ),
      child: Theme(
        // Kill Material's surface tint so our container color shows through
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.transparent,
          ),
        ),
        child: TextField(
          controller:   widget.controller,
          focusNode:    _focus,
          obscureText:  widget.obscure,
          keyboardType: widget.keyboardType,
          onChanged:    widget.onChanged,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize:   15,
            color:      Color(0xFF211D42),
            height:     1.4,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                widget.icon,
                color: _focused ? _kAccent : _kSub,
                size: 20,
              ),
            ),
            suffixIcon: widget.suffix != null
                ? Padding(padding: const EdgeInsets.only(right: 4), child: widget.suffix)
                : null,
            hintText:  widget.hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              color:      Color(0xFF9691B4),
              fontSize:   15,
            ),
            border:         InputBorder.none,
            enabledBorder:  InputBorder.none,
            focusedBorder:  InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;
  const _EyeToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF686487),
          size: 20,
        ),
        onPressed: onToggle,
      );
}

class _StatusLine extends StatelessWidget {
  final String text;
  final Color  color;
  const _StatusLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize:   12,
            color:      color.withValues(alpha: 0.85),
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        _kRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: _kRed.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: _kRed.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kRed.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool   loading;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 19),
          decoration: BoxDecoration(
            gradient: loading
                ? LinearGradient(colors: [
                    _kAccent.withValues(alpha: 0.4),
                    _kAccentDim.withValues(alpha: 0.4),
                  ])
                : const LinearGradient(
                    colors: [Color(0xFF9B8FFF), _kAccentDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: loading
                ? []
                : [
                    BoxShadow(
                      color:  _kGlow.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color:  _kGlow.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
            border: Border.all(
              color: Colors.white.withValues(alpha: loading ? 0.0 : 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width:  22,
                    height: 22,
                    child:  CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({this.label = 'OR'});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: _kLine, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kSub)),
          ),
          const Expanded(child: Divider(color: _kLine, height: 1)),
        ],
      );
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  final String label;

  const _GoogleButton({
    required this.onTap,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 60,
        child: OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _kText,
            side: const BorderSide(color: _kLine, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
            backgroundColor: Colors.white,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _kAccent),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleLogo(),
                    const SizedBox(width: 12),
                    Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kText)),
                  ],
                ),
        ),
      );
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);
  static const _blue = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final strokeWidth = w * .2;
    final radius = (w - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: radius);
    Paint stroke(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    double radians(double degrees) => degrees * math.pi / 180;
    canvas.drawArc(rect, radians(215), radians(100), false, stroke(_red));
    canvas.drawArc(rect, radians(135), radians(80), false, stroke(_yellow));
    canvas.drawArc(rect, radians(45), radians(90), false, stroke(_green));
    canvas.drawArc(rect, radians(0), radians(45), false, stroke(_blue));
    canvas.drawRect(
      Rect.fromLTRB(w / 2, w / 2 - strokeWidth / 2, w, w / 2 + strokeWidth / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwitchLink extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;
  const _SwitchLink({required this.prefix, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _kSub),
            children: [
              TextSpan(text: prefix),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: onTap,
                  child: Text(
                    action,
                    style: GoogleFonts.inter(color: _kAccentDim, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SavedAccountTile extends StatelessWidget {
  final SavedSession session;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedAccountTile({
    required this.session,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: _kField,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_kAccent, _kPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            session.initial,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.name.isNotEmpty ? session.name : session.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _kText),
                            ),
                            if (session.name.isNotEmpty)
                              Text(
                                session.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: _kSub),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Fill', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kAccentDim)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove saved account',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18, color: _kSub),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
}


/// Shared first-time Google signup username chooser for both auth tabs.
Future<String?> _promptForGoogleUsername(
  BuildContext context,
  AuthService auth, {
  String? initialUsername,
  String? errorMessage,
}) async {
  final initial = initialUsername?.trim() ?? '';
  final controller = TextEditingController(
    text: initial.isNotEmpty ? initial : auth.googleUsernameSuggestion,
  );
  String? validationMessage = errorMessage;
  bool checking = false;

  bool isValidUsername(String value) {
    final username = value.trim().toLowerCase();
    return username.length >= 3 &&
        username.length <= 24 &&
        !RegExp(r'[^a-z0-9_]').hasMatch(username);
  }

  Future<void> validateAndSubmit(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    final username = controller.text.trim().toLowerCase();
    if (!isValidUsername(username)) {
      setDialogState(() {
        checking = false;
        validationMessage =
            'Use 3–24 lowercase letters, numbers, or underscores.';
      });
      return;
    }

    setDialogState(() {
      checking = true;
      validationMessage = null;
    });
    final available = await auth.isUsernameAvailable(username);
    if (!dialogContext.mounted) return;
    setDialogState(() => checking = false);
    if (!available) {
      setDialogState(() {
        validationMessage =
            'That username is taken or could not be checked.';
      });
      return;
    }
    Navigator.pop(dialogContext, username);
  }

  final selected = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Choose your Novyn username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Google name stays as your display name. Choose a unique handle people can use to find you.',
              style: TextStyle(fontSize: 13, height: 1.45, color: _kSub),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                LengthLimitingTextInputFormatter(24),
              ],
              decoration: InputDecoration(
                prefixText: '@',
                hintText: 'your_username',
                helperText: '3–24 characters · letters, numbers, underscores',
                errorText: validationMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) =>
                  setDialogState(() => validationMessage = null),
              onSubmitted: (_) =>
                  validateAndSubmit(dialogContext, setDialogState),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: checking
                ? null
                : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: checking
                ? null
                : () => validateAndSubmit(dialogContext, setDialogState),
            child: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return selected;
}
