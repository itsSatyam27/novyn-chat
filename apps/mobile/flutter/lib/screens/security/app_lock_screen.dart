import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/local_auth_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/doodle_background.dart';
import 'dart:ui';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _inputPin = '';
  final int _pinLength = 4;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // We now let the user tap the "Use Biometrics" button manually
    // to avoid the system PIN from popping up automatically.
    // _triggerBiometrics();
  }

  Future<void> _triggerBiometrics() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    
    final success = await LocalAuthService.authenticate(
      reason: 'Unlock Novyn Secure Node',
    );
    
    if (success) {
      widget.onUnlocked();
    }
    _isAuthenticating = false;
  }

  void _onNumberPress(String num) {
    HapticFeedback.lightImpact();
    if (_inputPin.length < _pinLength) {
      setState(() {
        _inputPin += num;
      });
      
      if (_inputPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      });
    }
  }

  void _verifyPin() {
    final settings = context.read<SettingsService>();
    
    if (_inputPin == settings.appLockPin) {
      HapticFeedback.mediumImpact();
      settings.unlockWithDecoy(false);
    } else if (settings.panicPin != null && _inputPin == settings.panicPin) {
      HapticFeedback.mediumImpact();
      settings.unlockWithDecoy(true);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _inputPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DoodleBackground(isDark: isDark, seed: 101),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Lock Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF7C6FF7).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFF7C6FF7), size: 28),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter Secure PIN',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),
                // PIN indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final isActive = index < _inputPin.length;
                    return Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive 
                            ? const Color(0xFF7C6FF7) 
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: const Color(0xFF7C6FF7).withValues(alpha: 0.3),
                            blurRadius: 8,
                          )
                        ] : [],
                      ),
                    );
                  }),
                ),
                const Spacer(),
                // Numeric Pad
                _buildNumPad(),
                const SizedBox(height: 20),
                // Biometric Toggle (if available)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _triggerBiometrics,
                      icon: Icon(
                        Theme.of(context).platform == TargetPlatform.iOS 
                            ? Icons.face_rounded 
                            : Icons.fingerprint_rounded,
                        color: const Color(0xFF7C6FF7),
                      ),
                      label: const Text(
                        'Use Biometrics',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                    ),
                    if (context.read<SettingsService>().appLockPin == null) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: widget.onUnlocked,
                        child: const Text(
                          'Skip (No PIN set)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumPad() {
    return Column(
      children: [
        for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((num) => _buildNumButton(num)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80),
            _buildNumButton('0'),
            _buildNumButton('backspace', isIcon: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumButton(String val, {bool isIcon = false}) {
    return GestureDetector(
      onTap: () => isIcon ? _onBackspace() : _onNumberPress(val),
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
                  val,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
