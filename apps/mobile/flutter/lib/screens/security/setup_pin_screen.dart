import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/doodle_background.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

class SetupPinScreen extends StatefulWidget {
  final bool isPanic;
  const SetupPinScreen({super.key, this.isPanic = false});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  final int _pinLength = 4;

  void _onNumberPress(String num) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < _pinLength) _pin += num;
        if (_pin.length == _pinLength) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmPin.length < _pinLength) _confirmPin += num;
        if (_confirmPin.length == _pinLength) {
          _verifyAndSave();
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_isConfirming) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  void _verifyAndSave() {
    if (_pin == _confirmPin) {
      HapticFeedback.mediumImpact();
      final settings = context.read<SettingsService>();
      if (widget.isPanic) {
        settings.setPanicPin(_pin);
      } else {
        settings.setAppLockPin(_pin);
      }
      Navigator.pop(context, true);
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match. Try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
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
            child: DoodleBackground(isDark: isDark, seed: 99),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _isConfirming ? 'Confirm Your PIN' : (widget.isPanic ? 'Set Panic PIN' : 'Set Novyn PIN'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isConfirming ? 'Re-enter the 4-digit code' : (widget.isPanic ? 'This code opens a decoy version of Novyn' : 'Create a secure access node'),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 40),
                // PIN indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final currentText = _isConfirming ? _confirmPin : _pin;
                    final isActive = index < currentText.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive 
                            ? const Color(0xFF7C6FF7) 
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: const Color(0xFF7C6FF7).withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : [],
                      ),
                    );
                  }),
                ),
                const Spacer(),
                _buildNumPad(),
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
            const SizedBox(width: 80, height: 80), // Empty space
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
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: isIcon 
              ? const Icon(Icons.backspace_outlined, color: Colors.white70)
              : Text(
                  val,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
