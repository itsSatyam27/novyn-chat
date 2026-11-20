import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../theme/novyn_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});
  final ValueChanged<NovynAccount> onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: capitalization,
    validator: validator,
    obscureText: obscure,
    autocorrect: !obscure,
    enableSuggestions: !obscure,
    style: const TextStyle(color: NovynTheme.text, fontSize: 14),
    decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
  );

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      final NovynAccount account = _createAccount
        ? await AuthApi.signUp(name: _name.text, username: _username.text, email: _email.text, password: _password.text)
        : await AuthApi.signIn(identifier: _identifier.text, password: _password.text);
      if (mounted) widget.onAuthenticated(account);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AuthApiException
          ? error.message
          : 'Could not reach Novyn. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF151B31), NovynTheme.background, Color(0xFF0B1820)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, compact ? 12 : 26, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(colors: [NovynTheme.accent, NovynTheme.teal]),
                        ),
                        child: const Icon(Icons.forum_rounded, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      const Text('novyn', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -1.3)),
                      const Spacer(),
                      const Icon(Icons.shield_outlined, color: NovynTheme.teal, size: 18),
                      const SizedBox(width: 6),
                      const Text('YOUR SPACE', style: TextStyle(color: NovynTheme.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    ]),
                    SizedBox(height: compact ? 34 : 52),
                    const Text('A little closer.', style: TextStyle(color: NovynTheme.teal, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(
                      _createAccount ? 'Make it\nyours.' : 'Your people,\nyour space.',
                      style: const TextStyle(fontSize: 38, height: 1.06, fontWeight: FontWeight.w800, letterSpacing: -1.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _createAccount ? 'Create your Novyn account and start with a clean slate.' : 'Sign in and pick up where your people are.',
                      style: const TextStyle(color: NovynTheme.muted, fontSize: 14, height: 1.55),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: NovynTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: NovynTheme.line)),
                      child: Row(children: [_modeButton('Sign in', false), _modeButton('Create account', true)]),
                    ),
                    const SizedBox(height: 22),
                    Form(
                      key: _formKey,
                      child: Column(children: [
                        if (_createAccount) ...[
                          _field(label: 'Full name', hint: 'How should people know you?', controller: _name, capitalization: TextCapitalization.words, validator: (v) => _required(v, 'name')),
                          const SizedBox(height: 13),
                          _field(label: 'Username', hint: 'Choose a unique username', controller: _username, validator: (v) => _required(v, 'username')),
                          const SizedBox(height: 13),
                          _field(
                            label: 'Email address',
                            hint: 'you@example.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              final required = _required(v, 'email');
                              if (required != null) return required;
                              if (!v!.contains('@') || !v.contains('.')) return 'Enter a valid email address.';
                              return null;
                            },
                          ),
                        ] else
                          _field(label: 'Email or username', hint: 'Enter your email or username', controller: _identifier, keyboardType: TextInputType.emailAddress, validator: (v) => _required(v, 'email or username')),
                        const SizedBox(height: 13),
                        _field(
                          label: 'Password',
                          hint: 'Enter your password',
                          controller: _password,
                          obscure: _hidePassword,
                          validator: (v) {
                            final required = _required(v, 'password');
                            if (required != null) return required;
                            if (_createAccount && v!.length < 8) return 'Use at least 8 characters.';
                            return null;
                          },
                          suffix: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: NovynTheme.muted, size: 20),
                          ),
                        ),
                      ]),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: const Color(0x33FF7185), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66FF7185))),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB2BC), fontSize: 12, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: _busy
                          ? const SizedBox(key: ValueKey('loading'), width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              key: ValueKey(_createAccount),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_createAccount ? 'Create account' : 'Sign in'),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(child: Text('One account. Your people. Your space.', textAlign: TextAlign.center, style: TextStyle(color: NovynTheme.muted, fontSize: 11))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, bool createAccount) {
    final selected = _createAccount == createAccount;
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : () => setState(() { _createAccount = createAccount; _error = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: selected ? NovynTheme.raised : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? NovynTheme.text : NovynTheme.muted)),
        ),
      ),
    );
  }
}
