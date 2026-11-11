import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../main_screen.dart';

// ── Palette constants ───────────────────────────────────────────────────────
const _kBg         = Color(0xFF04080F);
const _kAccent     = Color(0xFF8B7FFF);
const _kAccentDim  = Color(0xFF6C62E8);
const _kGlow       = Color(0xFF6D5DFC);
const _kGreen      = Color(0xFF10B981);
const _kRed        = Color(0xFFEF4444);
const _kPink       = Color(0xFFEC4899);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    return Scaffold(
      backgroundColor: const Color(0xFF5B48DD),
      body: Stack(children: [
        _MeshBackground(),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
            child: Row(children: [
              Container(width: 58, height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .16),
                  border: Border.all(color: Colors.white.withValues(alpha: .42))),
                child: const Icon(Icons.pets_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Text('Novyn', style: GoogleFonts.inter(color: Colors.white,
                fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
            ]),
          ),
          Expanded(child: Stack(children: [
            Positioned(left: 28, right: 28, top: 34,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_tabController.index == 0 ? 'Welcome\nback' : 'Join\nNovyn',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 42,
                    height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.4)),
                const SizedBox(height: 16),
                Text(_tabController.index == 0
                  ? 'Sign in to pick up your conversations.'
                  : 'Create an account and start connecting.',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: .82),
                    fontSize: 16, height: 1.4)),
              ])),
            Align(alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * .68,
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(38))),
                child: Column(children: [
                  const SizedBox(height: 24),
                  _buildTabBar(),
                  Expanded(child: TabBarView(controller: _tabController, children: [
                    _LoginTab(onSwitchToRegister: () => _tabController.animateTo(1)),
                    _RegisterTab(onSwitchToLogin: () => _tabController.animateTo(0)),
                  ])),
                ]))),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(height: 64,
        decoration: BoxDecoration(color: const Color(0xFFF1EEFC),
          borderRadius: BorderRadius.circular(28)),
        child: TabBar(controller: _tabController, onTap: (_) => setState(() {}),
          indicator: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _kGlow.withValues(alpha: .13),
              blurRadius: 14, offset: const Offset(0, 4))]),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(5),
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          labelColor: const Color(0xFF5140D5),
          unselectedLabelColor: const Color(0xFF686487),
          tabs: const [Tab(text: 'Sign in'), Tab(text: 'Create account')])));
  }

}

// ══════════════════════════════════════════════════════════════════════════════
//  Mesh gradient background
// ══════════════════════════════════════════════════════════════════════════════
class _MeshBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Top-left purple blob
          Positioned(
            top: -60,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kGlow.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-right pink blob
          Positioned(
            bottom: size.height * 0.1,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kPink.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Center soft glow
          Positioned(
            top: size.height * 0.25,
            left: size.width * 0.3,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kAccent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle horizontal scanline effect
          Positioned.fill(
            child: CustomPaint(painter: _ScanlinePainter()),
          ),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
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
    final err  = await auth.login(identifier: _emailCtrl.text, password: _passCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      _navigateToMain();
    }
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
    final err  = await auth.signInWithGoogle();
    if (!mounted) return;
    if (err != null && err != 'Sign-in cancelled.') {
      setState(() { _error = err; _loading = false; });
    } else if (err == null) {
      _navigateToMain();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SettingsService>().savedSessions;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved accounts
          if (sessions.isNotEmpty) ...[
            const _SectionLabel('Saved accounts'),
            const SizedBox(height: 10),
            ...sessions.map((s) => _SavedAccountTile(
                  session:  s,
                  onTap:    () => _fillFromSession(s),
                  onRemove: () => context.read<SettingsService>().removeSession(s.uid),
                )),
            const SizedBox(height: 20),
            const _OrDivider(),
            const SizedBox(height: 20),
          ],

          const _SectionLabel('EMAIL OR USERNAME'),
          const SizedBox(height: 8),
          _Field(
            controller:   _emailCtrl,
            hint:         'Email address or username',
            icon:         Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          const _SectionLabel('Password'),
          const SizedBox(height: 8),
          _Field(
            controller: _passCtrl,
            hint:       '••••••••',
            icon:       Icons.lock_outline_rounded,
            obscure:    _obscure,
            suffix: _EyeToggle(
              obscure:  _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _showForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _error!),
          ],

          const SizedBox(height: 28),

          _PrimaryButton(label: 'Sign in', loading: _loading, onTap: _submit),

          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),

          _GoogleButton(onTap: _googleSignIn),

          const SizedBox(height: 24),
          _SwitchLink(
            prefix: "New to Novyn? ",
            action: 'Create account',
            onTap:  widget.onSwitchToRegister,
          ),
        ],
      ),
    );
  }
}


class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({super.key});

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
      ScaffoldMessenger.of(context).showSnackBar(
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
  final _confirmCtrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
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
    _confirmCtrl.dispose();
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
    final confirm  = _confirmCtrl.text;

    if (name.isEmpty) { setState(() => _error = 'Please enter your name.'); return; }
    if (username.length < 3) { setState(() => _error = 'Username must be at least 3 characters.'); return; }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) { setState(() => _error = 'Username: letters, numbers & underscores only.'); return; }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) { setState(() => _error = 'Please enter a valid email address.'); return; }
    if (_checkingUsername) { setState(() => _error = 'Please wait while we check your username.'); return; }
    if (_usernameAvailable == false) { setState(() => _error = 'That username is already taken.'); return; }
    if (pass.length < 12) { setState(() => _error = 'Password must be at least 12 characters.'); return; }
    if (pass != confirm) { setState(() => _error = 'Passwords do not match.'); return; }

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

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF101827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE4DFF6)),
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
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to Novyn,\n@${_usernameCtrl.text.trim().toLowerCase()}',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white.withValues(alpha: 0.45), height: 1.5),
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Full Name'),
          const SizedBox(height: 8),
          _Field(controller: _nameCtrl, hint: 'Your full name', icon: Icons.person_outline_rounded),
          const SizedBox(height: 16),

          const _SectionLabel('Username'),
          const SizedBox(height: 8),
          _Field(
            controller: _usernameCtrl,
            hint:       'Choose a username',
            icon:       Icons.alternate_email_rounded,
            onChanged:  _checkUsername,
            suffix: _checkingUsername
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))
                : _usernameAvailable == null
                    ? null
                    : Icon(
                        _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: _usernameAvailable! ? _kGreen : _kRed,
                        size: 20,
                      ),
          ),
          if (_usernameAvailable == false) ...[
            const SizedBox(height: 5),
            const _StatusLine(text: 'This username is taken. Try another.', color: _kRed),
          ],
          if (_usernameAvailable == true) ...[
            const SizedBox(height: 5),
            const _StatusLine(text: '✓  Username is available', color: _kGreen),
          ],

          const SizedBox(height: 16),
          const _SectionLabel('Email'),
          const SizedBox(height: 8),
          _Field(
            controller:   _emailCtrl,
            hint:         'you@example.com',
            icon:         Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          const _SectionLabel('Password'),
          const SizedBox(height: 8),
          _Field(
            controller: _passCtrl,
            hint:       'Min. 12 characters',
            icon:       Icons.lock_outline_rounded,
            obscure:    _obscurePass,
            suffix: _EyeToggle(obscure: _obscurePass, onToggle: () => setState(() => _obscurePass = !_obscurePass)),
          ),
          const SizedBox(height: 16),

          const _SectionLabel('Confirm Password'),
          const SizedBox(height: 8),
          _Field(
            controller: _confirmCtrl,
            hint:       'Re-enter password',
            icon:       Icons.lock_outline_rounded,
            obscure:    _obscureConfirm,
            suffix: _EyeToggle(obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _error!),
          ],

          const SizedBox(height: 28),
          _PrimaryButton(label: 'Create account', loading: _loading, onTap: _submit),
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),
          _GoogleButton(
            onTap: () async {
              setState(() { _loading = true; _error = null; });
              final err = await context.read<AuthService>().signInWithGoogle();
              if (!mounted) return;
              if (err != null && err != 'Sign-in cancelled.') {
                setState(() { _error = err; _loading = false; });
              } else if (err == null) {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder:        (_, __, ___) => const MainScreen(),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (_) => false,
                );
              } else {
                setState(() => _loading = false);
              }
            },
          ),
          const SizedBox(height: 24),
          _SwitchLink(
            prefix: 'Already on Novyn? ',
            action: 'Login',
            onTap:  widget.onSwitchToLogin,
          ),
          const SizedBox(height: 16),
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
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.white.withValues(alpha: 0.45),
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
        color: _focused ? const Color(0xFFF1EEFC) : const Color(0xFFF7F5FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? _kAccent : const Color(0xFFE8E3F8),
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
            color:      const Color(0xFF211D42),
            height:     1.4,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                widget.icon,
                color: _focused ? _kAccent : const Color(0xFF777391),
                size: 20,
              ),
            ),
            suffixIcon: widget.suffix != null
                ? Padding(padding: const EdgeInsets.only(right: 4), child: widget.suffix)
                : null,
            hintText:  widget.hint,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color:      const Color(0xFF9691B4),
              fontSize:   15,
            ),
            border:         InputBorder.none,
            enabledBorder:  InputBorder.none,
            focusedBorder:  InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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
            borderRadius: BorderRadius.circular(16),
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
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color:      Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07))),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: const Color(0xFFE4DFF6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coloured Google G
              const Text(
                'G',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      Color(0xFF4285F4),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Continue with Google',
                style: GoogleFonts.inter(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      const Color(0xFF211D42),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withValues(alpha: 0.35)),
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: action,
                style: const TextStyle(
                  color:      _kAccent,
                  fontWeight: FontWeight.w700,
                ),
                recognizer: TapGestureRecognizer()..onTap = onTap,
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Saved account tile
// ══════════════════════════════════════════════════════════════════════════════
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: const Color(0xFFE8E3F8)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width:  46,
              height: 46,
              decoration: const BoxDecoration(
                shape:    BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_kAccent, _kPink],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  session.initial,
                  style: const TextStyle(
                    fontFamily:  'Inter',
                    fontWeight:  FontWeight.bold,
                    fontSize:    18,
                    color:       Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name.isNotEmpty ? session.name : session.email,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize:   14,
                      color:      Colors.white,
                    ),
                  ),
                  if (session.name.isNotEmpty)
                    Text(
                      session.email,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        _kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Fill',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      _kAccent.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.05),
                  shape:        BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}