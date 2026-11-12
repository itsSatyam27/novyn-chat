import 'dart:async';
import 'dart:ui';
import 'package:novyn/services/haptic_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/doodle_background.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const int _pinLength = 4;
  String _inputPin = '';
  String? _errorMessage;
  bool _isAuthenticating = false;
  bool _biometricAvailable = false;
  bool _recovering = false;
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await LocalAuthService.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _triggerBiometrics() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    final success = await LocalAuthService.authenticate(
      reason: 'Unlock Novyn Secure Node',
    );
    if (!mounted) return;
    if (success) {
      await context.read<SettingsService>().resetAppLockFailures();
      widget.onUnlocked();
    }
    if (mounted) setState(() => _isAuthenticating = false);
  }

  Future<void> _onNumberPress(String num) async {
    final settings = context.read<SettingsService>();
    if (_isAuthenticating || settings.isAppLockCoolingDown ||
        _inputPin.length >= _pinLength) {
      return;
    }
    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.buttons);
    setState(() {
      _errorMessage = null;
      _inputPin += num;
    });
    if (_inputPin.length == _pinLength) await _verifyPin();
  }

  void _onBackspace() {
    if (_isAuthenticating || context.read<SettingsService>().isAppLockCoolingDown) return;
    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_isAuthenticating) return;
    final settings = context.read<SettingsService>();
    if (settings.isAppLockCoolingDown) return;

    setState(() => _isAuthenticating = true);
    final enteredPin = _inputPin;
    if (enteredPin == settings.appLockPin) {
      HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.buttons);
      await settings.resetAppLockFailures();
      if (mounted) widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      await settings.recordFailedAppLockAttempt();
      if (!mounted) return;
      setState(() {
        _inputPin = '';
        _errorMessage = settings.isAppLockCoolingDown
            ? 'Too many incorrect attempts. Try again after the cooldown.'
            : 'Incorrect PIN. Please try again.';
      });
    }
    if (mounted) setState(() => _isAuthenticating = false);
  }

  String _formatRemaining(Duration remaining) {
    final seconds = remaining.inSeconds;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return minutes > 0
        ? '${minutes}m ${rest.toString().padLeft(2, '0')}s'
        : '${rest}s';
  }

  Future<void> _forgotPin() async {
    final shouldRecover = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot App Lock PIN?'),
        content: const Text(
          'To protect your chats, Novyn will sign you out and remove this '
          'local App Lock PIN. Sign in again with your Novyn account, then '
          'set a new PIN from Settings → Security & Privacy → App Lock. '
          'If you also forgot your account password, use Forgot Password '
          'on the login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out & recover'),
          ),
        ],
      ),
    );

    if (shouldRecover != true || !mounted || _recovering) return;
    setState(() => _recovering = true);
    try {
      final settings = context.read<SettingsService>();
      await settings.prepareAppLockAccountRecovery();
      await context.read<AuthService>().logout();
      // AuthService notifies the root router, which displays the sign-in page.
    } catch (_) {
      if (mounted) {
        setState(() {
          _recovering = false;
          _errorMessage = 'Could not start recovery. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final settings = context.watch<SettingsService>();
    final coolingDown = settings.isAppLockCoolingDown;
    final remaining = settings.appLockRemaining;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: DoodleBackground(isDark: isDark, seed: 101)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.1),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.lock_rounded, color: accent, size: 28),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter Secure PIN',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final active = index < _inputPin.length;
                    return Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? accent
                            : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        boxShadow: active
                            ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 8)]
                            : [],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                if (coolingDown)
                  Text(
                    'Try again in ${_formatRemaining(remaining)}',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                _buildNumPad(disabled: coolingDown || _isAuthenticating || _recovering),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _recovering ? null : _forgotPin,
                  child: _recovering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Forgot PIN?', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                ),
                if (_biometricAvailable)
                  TextButton.icon(
                    onPressed: _isAuthenticating || _recovering ? null : _triggerBiometrics,
                    icon: Icon(
                      Theme.of(context).platform == TargetPlatform.iOS
                          ? Icons.face_rounded
                          : Icons.fingerprint_rounded,
                      color: accent,
                    ),
                    label: Text(
                      'Use Biometrics',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumPad({required bool disabled}) {
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((number) => _buildNumButton(number, disabled: disabled)).toList(),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 92, height: 92),
              _buildNumButton('0', disabled: disabled),
              _buildNumButton('backspace', isIcon: true, disabled: disabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumButton(String value, {bool isIcon = false, required bool disabled}) {
    return GestureDetector(
      onTap: disabled ? null : () {
        if (isIcon) {
          _onBackspace();
        } else {
          _onNumberPress(value);
        }
      },
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: isIcon
              ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 20)
              : Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
