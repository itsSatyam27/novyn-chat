import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../services/settings_service.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/novyn_theme.dart';

class SoundVibrationScreen extends StatefulWidget {
  const SoundVibrationScreen({super.key});

  @override
  State<SoundVibrationScreen> createState() => _SoundVibrationScreenState();
}

class _SoundVibrationScreenState extends State<SoundVibrationScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playing;
  String _callPreview = 'Ringtone';

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playMessage(SettingsService settings, {bool restart = false}) async {
    if (!settings.inAppSounds) return;
    if (_playing == 'message' && !restart) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await _player.stop();
    await _player.setVolume(settings.messageVolume);
    final asset = SettingsService.messageToneAsset(settings.notificationTone);
    try {
      await _player.play(AssetSource(asset));
      if (mounted) setState(() => _playing = 'message');
    } catch (_) {
      if (mounted) {
        context.showNovynAlert(
          const SnackBar(content: Text('Sound preview is unavailable right now.')),
        );
      }
    }
  }

  Future<void> _playCall(SettingsService settings, {bool restart = false}) async {
    if (settings.callRingtone == 'None') return;
    if (_playing == 'call' && !restart) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await _player.stop();
    await _player.setVolume(settings.callVolume);
    final asset = _callPreview == 'Ringback'
        ? 'audio/ringtone.mp3'
        : 'audio/call_ring.mp3';
    try {
      await _player.play(AssetSource(asset));
      if (mounted) setState(() => _playing = 'call');
    } catch (_) {
      if (mounted) {
        context.showNovynAlert(
          const SnackBar(content: Text('Call sound preview is unavailable right now.')),
        );
      }
    }
  }

  Future<void> _toggleCallSounds(SettingsService settings, bool enabled) async {
    if (!enabled) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      await settings.setCallRingtone('None');
    } else {
      await settings.setCallRingtone('Binary');
    }
  }

  Future<void> _testVibration(SettingsService settings) async {
    if (!settings.inAppVibration || settings.vibrationPattern == 'none') return;
    await HapticService.vibrateNotification();
  }

  Future<void> _chooseRhythm(SettingsService settings) async {
    const values = ['standard', 'staccato', 'heartbeat', 'none'];
    const labels = ['Standard', 'Staccato', 'Heartbeat', 'Off'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NovynTheme.cardBg(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vibration rhythm', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800,
                color: NovynTheme.textPrimary(sheetContext),
              )),
              const SizedBox(height: 6),
              Text('Choose how incoming alerts vibrate',
                style: TextStyle(color: NovynTheme.textSecondary(sheetContext))),
              const SizedBox(height: 14),
              for (var i = 0; i < values.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[i]),
                  trailing: settings.vibrationPattern == values[i]
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      : Icon(Icons.circle_outlined),
                  onTap: () => Navigator.pop(sheetContext, values[i]),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await settings.setVibrationPattern(selected);
    if (selected != 'none' && settings.inAppVibration) {
      HapticService.vibrateNotification();
    }
  }

  String _rhythmLabel(String value) => switch (value) {
    'staccato' => 'Staccato',
    'heartbeat' => 'Heartbeat',
    'none' => 'Off',
    _ => 'Standard',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          physics: const BouncingScrollPhysics(),
          children: [
            _ScreenHeader(
              title: 'Sound & Vibration',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // MESSAGES Section
            _sectionHeader('MESSAGES'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.notifications_none_rounded,
                    const Color(0xFF6366F1),
                    isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                  ),
                  title: 'Message sounds',
                  trailing: _purpleSwitch(
                    value: settings.inAppSounds,
                    onChanged: (value) async {
                      if (!value) {
                        await _player.stop();
                        if (mounted) setState(() => _playing = null);
                      }
                      settings.setInAppSounds(value);
                    },
                    context: context,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      _PlayCircle(
                        playing: _playing == 'message',
                        onTap: () => _playMessage(settings),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SegmentedTones(
                          tones: const ['Drift', 'Pulse', 'Glass', 'Echo'],
                          selectedTone: const ['Drift', 'Pulse', 'Glass', 'Echo']
                                  .contains(settings.notificationTone)
                              ? settings.notificationTone
                              : 'Drift',
                          onTone: (tone) async {
                            await settings.setNotificationTone(tone);
                            if (settings.inAppSounds) _playMessage(settings, restart: true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_down_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _NvSlider(
                          value: settings.messageVolume * 100,
                          onChanged: (val) {
                            settings.setMessageVolume(val / 100);
                            if (_playing == 'message') _player.setVolume(val / 100);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(settings.messageVolume * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CALLS Section
            _sectionHeader('CALLS'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.phone_outlined,
                    const Color(0xFF10B981),
                    isDark ? const Color(0xFF1A3327) : const Color(0xFFE2F7ED),
                  ),
                  title: 'Call sounds',
                  trailing: _purpleSwitch(
                    value: settings.callRingtone != 'None',
                    onChanged: (value) => _toggleCallSounds(settings, value),
                    context: context,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      _PlayCircle(
                        playing: _playing == 'call',
                        onTap: () => _playCall(settings),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SegmentedTones(
                          tones: const ['Ringtone', 'Ringback'],
                          selectedTone: _callPreview,
                          onTone: (tone) {
                            setState(() => _callPreview = tone);
                            if (settings.callRingtone != 'None') _playCall(settings, restart: true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_down_rounded,
                        color: Color(0xFF8F8BA0),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _NvSlider(
                          value: settings.callVolume * 100,
                          onChanged: (val) {
                            settings.setCallVolume(val / 100);
                            if (_playing == 'call') _player.setVolume(val / 100);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(settings.callVolume * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // VIBRATION Section
            _sectionHeader('VIBRATION'),
            _groupedCard(
              context,
              children: [
                _SettingsRow(
                  leading: _iconBox(
                    Icons.vibration_rounded,
                    const Color(0xFFD97706),
                    isDark ? const Color(0xFF382A1B) : const Color(0xFFFEF3E2),
                  ),
                  title: 'Vibration rhythm',
                  trailing: _trailingValueWithChevron(context, _rhythmLabel(settings.vibrationPattern)),
                  onTap: () => _chooseRhythm(settings),
                ),
                _SettingsRow(
                  leading: _iconBox(
                    Icons.touch_app_outlined,
                    const Color(0xFFEC4899),
                    isDark ? const Color(0xFF381F2E) : const Color(0xFFFDE8F1),
                  ),
                  title: 'Haptic feedback',
                  trailing: _purpleSwitch(
                    value: settings.inAppVibration,
                    onChanged: settings.setInAppVibration,
                    context: context,
                  ),
                ),
                // Sub-haptic toggles — animate in/out smoothly when Haptic feedback is toggled
                AnimatedCrossFade(
                  crossFadeState: settings.inAppVibration
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                  sizeCurve: Curves.easeInOutCubic,
                  firstCurve: Curves.easeInOut,
                  secondCurve: Curves.easeInOut,
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Column(
                    children: [
                      _IndentedToggleRow(
                        title: 'Navigation haptics',
                        value: settings.hapticNavigation,
                        onChanged: (v) => settings.setHapticCategory('navigation', v),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
                      ),
                      _IndentedToggleRow(
                        title: 'Chat haptics',
                        value: settings.hapticChat,
                        onChanged: (v) => settings.setHapticCategory('chat', v),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
                      ),
                      _IndentedToggleRow(
                        title: 'Button haptics',
                        value: settings.hapticButtons,
                        onChanged: (v) => settings.setHapticCategory('buttons', v),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
                      ),
                      _IndentedToggleRow(
                        title: 'Notification haptics',
                        value: settings.hapticNotifications,
                        onChanged: (v) => settings.setHapticCategory('notifications', v),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
                      ),
                      _IndentedToggleRow(
                        title: 'Call haptics',
                        value: settings.hapticCalls,
                        onChanged: (v) => settings.setHapticCategory('calls', v),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
                      ),
                      _SettingsRow(
                        leading: _iconBox(
                          Icons.tune_rounded,
                          const Color(0xFF6366F1),
                          isDark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                        ),
                        title: 'Haptic intensity',
                        trailing: GestureDetector(
                          onTap: () => _testVibration(settings),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2844) : const Color(0xFFECE9FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Test',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _NvSlider(
                                value: settings.hapticIntensity * 100,
                                onChanged: (val) => settings.setHapticIntensity(val / 100),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(settings.hapticIntensity * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF6246EA),
        ),
      ),
    );
  }

  static Widget _iconBox(IconData icon, Color color, Color bg) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  static Widget _trailingValueWithChevron(BuildContext context, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF8F8BA0),
          size: 20,
        ),
      ],
    );
  }

  static Widget _purpleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    required BuildContext context,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Switch.adaptive(
      value: value,
      activeColor: Colors.white,
      activeTrackColor: Theme.of(context).colorScheme.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: dark ? const Color(0xFF3B394E) : const Color(0xFFE2E0EC),
      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      onChanged: (next) {
        HapticService.vibrate(NovynHapticType.selection);
        onChanged(next);
      },
    );
  }

  static Widget _groupedCard(
    BuildContext context, {
    required List<Widget> children,
    bool suppressDividerBeforeLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: border != null ? Border.all(color: border) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1 && !(suppressDividerBeforeLast && i == children.length - 2))
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: 16,
                color: isDark ? const Color(0xFF28253E) : const Color(0xFFF3F0F8),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ScreenHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              HapticService.vibrate(NovynHapticType.light);
              onBack();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ink,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticService.vibrate(NovynHapticType.selection);
                onTap!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _IndentedToggleRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _IndentedToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);

    return Padding(
      padding: const EdgeInsets.fromLTRB(68, 11, 16, 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: dark ? const Color(0xFF3B394E) : const Color(0xFFE2E0EC),
            trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
            onChanged: (next) {
              HapticService.vibrate(NovynHapticType.selection);
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _PlayCircle extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;

  const _PlayCircle({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _SegmentedTones extends StatelessWidget {
  final List<String> tones;
  final String selectedTone;
  final ValueChanged<String> onTone;

  const _SegmentedTones({
    required this.tones,
    required this.selectedTone,
    required this.onTone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242042) : const Color(0xFFECE9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final tone in tones)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticService.vibrate(NovynHapticType.selection);
                  onTone(tone);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone == selectedTone
                        ? (isDark ? const Color(0xFF332B5C) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: tone == selectedTone && !isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: tone == selectedTone ? FontWeight.w700 : FontWeight.w500,
                      color: tone == selectedTone
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? const Color(0xFF8F8BA0) : const Color(0xFF5A5670)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NvSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _NvSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: isDark ? const Color(0xFF2C2844) : const Color(0xFFECE9FB),
        thumbColor: Theme.of(context).colorScheme.primary,
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      ),
      child: Slider(
        value: value.clamp(0, 100),
        min: 0,
        max: 100,
        onChanged: (val) {
          onChanged(val);
        },
      ),
    );
  }
}
