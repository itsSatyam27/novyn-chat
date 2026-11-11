import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/novyn_alert.dart';

class SetupPinScreen extends StatefulWidget {
  final bool isPanic;
  final bool isChanging;

  const SetupPinScreen({
    super.key,
    this.isPanic = false,
    this.isChanging = false,
  }) : assert(!(isPanic && isChanging));

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  String _currentPin = '';
  String _pin = '';
  String _confirmPin = '';
  int _step = 0;
  bool _saving = false;

  String get _activePin {
    if (widget.isChanging && _step == 0) return _currentPin;
    if ((widget.isChanging && _step == 1) ||
        (!widget.isChanging && _step == 0)) {
      return _pin;
    }
    return _confirmPin;
  }

  String get _title {
    if (widget.isPanic) {
      return _step == 0 ? 'Create Panic PIN' : 'Confirm Panic PIN';
    }
    if (widget.isChanging) {
      return ['Verify current PIN', 'Create new PIN', 'Confirm new PIN'][_step];
    }
    return _step == 0 ? 'Create your PIN' : 'Confirm your PIN';
  }

  String get _subtitle {
    if (widget.isPanic) {
      return _step == 0
          ? 'This PIN opens your decoy Novyn space'
          : 'Enter the same 4 digits once more';
    }
    if (widget.isChanging) {
      return [
        'Verify your existing PIN to continue',
        'Choose a new 4-digit security PIN',
        'Re-enter your new PIN to confirm',
      ][_step];
    }
    return _step == 0
        ? 'Choose a 4-digit PIN to protect Novyn'
        : 'Re-enter the PIN to make sure it is correct';
  }

  void _onNumberPress(String digit) {
    if (_saving || _activePin.length >= 4) return;
    HapticFeedback.lightImpact();
    final next = _activePin + digit;
    setState(() {
      if (widget.isChanging && _step == 0) {
        _currentPin = next;
      } else if ((widget.isChanging && _step == 1) ||
          (!widget.isChanging && _step == 0)) {
        _pin = next;
      } else {
        _confirmPin = next;
      }
    });
    if (next.length == 4) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _advance();
      });
    }
  }

  Future<void> _advance() async {
    if (_saving || _activePin.length != 4) return;
    final settings = context.read<SettingsService>();

    if (widget.isChanging && _step == 0) {
      if (_currentPin != settings.appLockPin) {
        HapticFeedback.vibrate();
        setState(() => _currentPin = '');
        NovynAlert.show(context, 'Current PIN is incorrect. Try again.',
            isError: true);
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _step = 1);
      return;
    }

    final isNewPinStep = (widget.isChanging && _step == 1) ||
        (!widget.isChanging && _step == 0);
    if (isNewPinStep) {
      HapticFeedback.selectionClick();
      setState(() => _step = widget.isChanging ? 2 : 1);
      return;
    }

    await _verifyAndSave(settings);
  }

  Future<void> _verifyAndSave(SettingsService settings) async {
    if (_pin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() => _confirmPin = '');
      NovynAlert.show(context, 'PINs do not match. Please try again.',
          isError: true);
      return;
    }
    if (widget.isChanging && _pin == _currentPin) {
      HapticFeedback.vibrate();
      setState(() => _confirmPin = '');
      NovynAlert.show(context, 'Choose a PIN different from your current PIN.', isError: true);
      return;
    }
    if (widget.isPanic && _pin == settings.appLockPin) {
      HapticFeedback.vibrate();
      setState(() {
        _pin = '';
        _confirmPin = '';
        _step = 0;
      });
      NovynAlert.show(
        context,
        'Panic PIN must be different from your App Lock PIN.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isPanic) {
        await settings.setPanicPin(_pin);
      } else {
        await settings.setAppLockPin(_pin);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      NovynAlert.show(
        context,
        widget.isPanic
            ? 'Panic PIN saved successfully.'
            : widget.isChanging
                ? 'App Lock PIN updated successfully.'
                : 'App Lock PIN enabled successfully.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmPin = '';
      });
      NovynAlert.show(
        context,
        'Could not save PIN securely: ${error.toString().replaceFirst('Bad state: ', '')}',
        isError: true,
      );
    }
  }

  void _onBackspace() {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_activePin.isNotEmpty) {
        final next = _activePin.substring(0, _activePin.length - 1);
        if (widget.isChanging && _step == 0) {
          _currentPin = next;
        } else if ((widget.isChanging && _step == 1) ||
            (!widget.isChanging && _step == 0)) {
          _pin = next;
        } else {
          _confirmPin = next;
        }
      } else if (_step > 0) {
        _step--;
        if (widget.isChanging && _step == 0) _currentPin = '';
        if (widget.isChanging && _step == 1) _confirmPin = '';
        if (!widget.isChanging && _step == 0) _confirmPin = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final totalSteps = widget.isChanging ? 3 : 2;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _saving ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(widget.isChanging ? 'Change PIN' : 'App Lock PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: accent.withValues(alpha: .18)),
                        ),
                        child: Icon(
                          widget.isPanic
                              ? Icons.visibility_off_rounded
                              : widget.isChanging
                                  ? Icons.password_rounded
                                  : Icons.lock_rounded,
                          color: accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalSteps, (index) {
                          final active = index <= _step;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _step ? 26 : 7,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: active
                                  ? accent
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final filled = index < _activePin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 15,
                            height: 15,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? accent : Colors.transparent,
                              border: Border.all(
                                color: filled
                                    ? accent
                                    : colors.outline.withValues(alpha: .55),
                                width: 1.7,
                              ),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: .22),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Column(
                    children: [
                      _buildKeypad(colors),
                      const SizedBox(height: 16),
                      if (_saving)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: accent,
                          ),
                        )
                      else
                        Text(
                          'Your PIN is stored securely on this device',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme colors) {
    final rows = const [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((digit) => _key(digit, colors)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 84, height: 72),
            _key('0', colors),
            SizedBox(
              width: 84,
              height: 72,
              child: IconButton(
                onPressed: _saving ? null : _onBackspace,
                tooltip: 'Delete last digit',
                icon: Icon(Icons.backspace_outlined,
                    color: colors.onSurfaceVariant, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String digit, ColorScheme colors) {
    return SizedBox(
      width: 84,
      height: 72,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: colors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _saving ? null : () => _onNumberPress(digit),
            child: Center(
              child: Text(
                digit,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
