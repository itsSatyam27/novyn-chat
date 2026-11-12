import 'package:flutter/material.dart';
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
    final asset = switch (settings.notificationTone) {
      'Pulse' => 'audio/chime-pulse.wav',
      'Glass' => 'audio/chime-glass.wav',
      'Echo' => 'audio/chime-echo.wav',
      _ => 'audio/notification.mp3',
    };
    try {
      await _player.play(AssetSource(asset));
      if (mounted) setState(() => _playing = 'message');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                      ? const Icon(Icons.check_circle_rounded, color: NovynTheme.indigo)
                      : const Icon(Icons.circle_outlined),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = NovynTheme.textPrimary(context);
    final muted = NovynTheme.textSecondary(context);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sound & Vibration', style: TextStyle(
                    fontFamily: NovynTheme.fontFamily,
                    fontSize: 26, fontWeight: FontWeight.w800,
                    height: 1.15, letterSpacing: -.3, color: ink,
                  )),
                  const SizedBox(height: 4),
                  Text('Tones, previews and haptics', style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500, color: muted,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 10),

            const _SectionLabel('Messages'),
            _SoundCard(
              icon: Icons.notifications_active_outlined,
              tileBg: const Color(0xFFECE9FB),
              iconColor: NovynTheme.indigo,
              title: 'Message sounds',
              subtitle: 'Play sounds for incoming and sent messages',
              enabled: settings.inAppSounds,
              onToggle: (value) async {
                if (!value) {
                  await _player.stop();
                  if (mounted) setState(() => _playing = null);
                }
                settings.setInAppSounds(value);
              },
              toneSub: 'Sound for incoming texts',
              tones: const ['Drift', 'Pulse', 'Glass', 'Echo'],
              selectedTone: const ['Drift', 'Pulse', 'Glass', 'Echo'].contains(settings.notificationTone)
                  ? settings.notificationTone : 'Drift',
              onTone: (tone) async {
                await settings.setNotificationTone(tone);
                if (settings.inAppSounds) _playMessage(settings, restart: true);
              },
              volume: settings.messageVolume * 100,
              volumeLabel: 'Message volume',
              onVolume: (value) {
                settings.setMessageVolume(value / 100);
                if (_playing == 'message') _player.setVolume(value / 100);
              },
              playing: _playing == 'message',
              onPlay: () => _playMessage(settings),
              dark: dark,
            ),

            const _SectionLabel('Calls'),
            _SoundCard(
              icon: Icons.call_outlined,
              tileBg: const Color(0xFFE1F3EC),
              iconColor: const Color(0xFF1F8A63),
              title: 'Call sounds',
              subtitle: 'Incoming ringtone and outgoing ringback',
              enabled: settings.callRingtone != 'None',
              onToggle: (value) => _toggleCallSounds(settings, value),
              toneSub: _callPreview == 'Ringtone' ? 'Incoming ringtone' : 'Outgoing ringback',
              tones: const ['Ringtone', 'Ringback'],
              selectedTone: _callPreview,
              onTone: (tone) {
                setState(() => _callPreview = tone);
                if (settings.callRingtone != 'None') _playCall(settings, restart: true);
              },
              volume: settings.callVolume * 100,
              volumeLabel: 'Call volume',
              onVolume: (value) {
                settings.setCallVolume(value / 100);
                if (_playing == 'call') _player.setVolume(value / 100);
              },
              playing: _playing == 'call',
              onPlay: () => _playCall(settings),
              dark: dark,
            ),

            const _SectionLabel('Vibration'),
            _Group(
              children: [
                _NavRow(
                  icon: Icons.vibration_rounded,
                  tileBg: const Color(0xFFFBEFD9),
                  iconColor: const Color(0xFFB26A0B),
                  title: 'Vibration rhythm',
                  subtitle: 'Pattern for incoming alerts',
                  value: _rhythmLabel(settings.vibrationPattern),
                  onTap: () => _chooseRhythm(settings),
                ),
                _ToggleRow(
                  icon: Icons.touch_app_outlined,
                  tileBg: const Color(0xFFFCE7F1),
                  iconColor: const Color(0xFFC21F68),
                  title: 'Haptic feedback',
                  subtitle: 'Tactile response when you tap',
                  value: settings.inAppVibration,
                  onChanged: settings.setInAppVibration,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _HapticCategoryRow(title: 'Navigation haptics', subtitle: 'Dock, tabs and back navigation', value: settings.hapticNavigation, onChanged: (v) => settings.setHapticCategory('navigation', v)),
                _HapticCategoryRow(title: 'Typing haptics', subtitle: 'Novyn-controlled typing interactions; keyboard vibration is managed by your keyboard app', value: settings.hapticTyping, onChanged: (v) => settings.setHapticCategory('typing', v)),
                _HapticCategoryRow(title: 'Chat haptics', subtitle: 'Sending messages, reactions and chat actions', value: settings.hapticChat, onChanged: (v) => settings.setHapticCategory('chat', v)),
                _HapticCategoryRow(title: 'Button haptics', subtitle: 'Buttons, switches and selections', value: settings.hapticButtons, onChanged: (v) => settings.setHapticCategory('buttons', v)),
                _HapticCategoryRow(title: 'Notification haptics', subtitle: 'Incoming message and alert vibrations', value: settings.hapticNotifications, onChanged: (v) => settings.setHapticCategory('notifications', v)),
                _HapticCategoryRow(title: 'Call haptics', subtitle: 'Call controls and call events', value: settings.hapticCalls, onChanged: (v) => settings.setHapticCategory('calls', v)),
                Opacity(
                  opacity: settings.inAppVibration ? 1 : .48,
                  child: IgnorePointer(
                    ignoring: !settings.inAppVibration,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Column(
                        children: [
                          Row(children: [
                            const _IconTile(
                              icon: Icons.tune_rounded,
                              bg: Color(0xFFECE9FB),
                              color: NovynTheme.indigo,
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _RowText(
                              title: 'Haptic intensity',
                              subtitle: 'Strength of the vibration',
                            )),
                            Text('${(settings.hapticIntensity * 100).round()}%',
                              style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w800, color: NovynTheme.indigo)),
                          ]),
                          const SizedBox(height: 8),
                          _NvSlider(
                            value: settings.hapticIntensity * 100,
                            onChanged: (value) => settings.setHapticIntensity(value / 100),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Material(
                    color: const Color(0xFFECE9FB),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _testVibration(settings),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          _PlayCircle(size: 40, iconSize: 18),
                          SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Test vibration', style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: NovynTheme.indigoDeep,
                            )),
                            SizedBox(height: 2),
                            Text('Feel your current pattern', style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w500,
                              color: Color(0xFF77738F),
                            )),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _rhythmLabel(String value) => switch (value) {
    'staccato' => 'Staccato',
    'heartbeat' => 'Heartbeat',
    'none' => 'Off',
    _ => 'Standard',
  };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(text, style: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w800,
      color: NovynTheme.textPrimary(context),
    )),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _SoundCard extends StatelessWidget {
  final IconData icon;
  final Color tileBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final String toneSub;
  final List<String> tones;
  final String selectedTone;
  final ValueChanged<String> onTone;
  final double volume;
  final String volumeLabel;
  final ValueChanged<double> onVolume;
  final bool playing;
  final VoidCallback onPlay;
  final bool dark;

  const _SoundCard({
    required this.icon, required this.tileBg, required this.iconColor,
    required this.title, required this.subtitle, required this.enabled,
    required this.onToggle, required this.toneSub, required this.tones,
    required this.selectedTone, required this.onTone, required this.volume,
    required this.volumeLabel, required this.onVolume, required this.playing,
    required this.onPlay, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final card = NovynTheme.cardBg(context);
    final field = NovynTheme.inputBg(context);
    final ink = NovynTheme.textPrimary(context);
    final muted = NovynTheme.textSecondary(context);
    return Container(
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        _ToggleRow(
          icon: icon, tileBg: tileBg, iconColor: iconColor,
          title: title, subtitle: subtitle, value: enabled, onChanged: onToggle,
        ),
        Opacity(
          opacity: enabled ? 1 : .48,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: field, borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(children: [
                    GestureDetector(
                      onTap: onPlay,
                      child: Semantics(
                        button: true, label: 'Play $selectedTone',
                        child: _PlayCircle(size: 48, iconSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(selectedTone, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink))),
                          const SizedBox(width: 8),
                          Flexible(child: Text(toneSub, textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _Waveform(playing: playing),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF292457) : const Color(0xFFF1EEFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    for (final tone in tones)
                      Expanded(child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTone(tone),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 40, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tone == selectedTone ? card : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: tone == selectedTone ? [
                              BoxShadow(color: NovynTheme.indigo.withValues(alpha: .18),
                                blurRadius: 8, offset: const Offset(0, 2)),
                            ] : null,
                          ),
                          child: Text(tone, style: TextStyle(fontSize: 13,
                            fontWeight: tone == selectedTone ? FontWeight.w800 : FontWeight.w700,
                            color: tone == selectedTone ? NovynTheme.indigo : muted)),
                        ),
                      )),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.volume_up_rounded, size: 22, color: muted),
                  const SizedBox(width: 6),
                  Expanded(child: Semantics(
                    label: volumeLabel,
                    child: _NvSlider(value: volume, onChanged: onVolume),
                  )),
                  SizedBox(width: 44, child: Text('${volume.round()}%',
                    textAlign: TextAlign.right, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: NovynTheme.indigo))),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _HapticCategoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _HapticCategoryRow({required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 11, 12, 11),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NovynTheme.textPrimary(context))),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 11.5, color: NovynTheme.textSecondary(context))),
      ])),
      const SizedBox(width: 10),
      _NovynSwitch(value: value, onChanged: onChanged),
    ]),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color tileBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon, required this.tileBg, required this.iconColor,
    required this.title, required this.subtitle, required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
    child: Row(children: [
      _IconTile(icon: icon, bg: tileBg, color: iconColor),
      const SizedBox(width: 14),
      Expanded(child: _RowText(title: title, subtitle: subtitle)),
      _NovynSwitch(value: value, onChanged: onChanged),
    ]),
  );
}

class _NovynSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NovynSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final trackColor = value
        ? NovynTheme.indigo
        : (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF49465F)
            : const Color(0xFFD8D5E2));
    return Semantics(
      label: 'Setting',
      value: value ? 'On' : 'Off',
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          width: 54,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: value
                ? [BoxShadow(color: NovynTheme.indigo.withValues(alpha: .24),
                    blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: .16),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color tileBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon, required this.tileBg, required this.iconColor,
    required this.title, required this.subtitle, required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(children: [
        _IconTile(icon: icon, bg: tileBg, color: iconColor),
        const SizedBox(width: 14),
        Expanded(child: _RowText(title: title, subtitle: subtitle)),
        Text(value, style: const TextStyle(
          color: NovynTheme.indigo, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(width: 3),
        const Icon(Icons.chevron_right_rounded, color: NovynTheme.indigo),
      ]),
    ),
  );
}

class _RowText extends StatelessWidget {
  final String title;
  final String subtitle;
  const _RowText({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w800,
        color: NovynTheme.textPrimary(context))),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: NovynTheme.textSecondary(context))),
    ],
  );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  const _IconTile({required this.icon, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
    child: Icon(icon, color: color, size: 22),
  );
}

class _PlayCircle extends StatelessWidget {
  final double size;
  final double iconSize;
  const _PlayCircle({required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF8B7CF6), NovynTheme.indigo],
      ),
      boxShadow: [
        BoxShadow(color: NovynTheme.indigo.withValues(alpha: .30),
          blurRadius: 14, offset: const Offset(0, 6)),
      ],
    ),
    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: iconSize + 4),
  );
}

class _Waveform extends StatelessWidget {
  final bool playing;
  const _Waveform({required this.playing});

  static const _heights = <double>[
    10, 18, 26, 36, 24, 14, 30, 40, 22, 12, 28, 36,
    18, 10, 24, 34, 20, 12, 30, 38, 16, 26, 14, 20,
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < _heights.length; i++)
          Container(
            width: 3.5, height: playing ? _heights[i] : _heights[i] * .78,
            decoration: BoxDecoration(
              color: i % 3 == 1 ? const Color(0xFFA99CF5) : NovynTheme.indigo,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

class _NvSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _NvSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackHeight: 6,
      activeTrackColor: NovynTheme.indigo,
      inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF373451) : const Color(0xFFE5E1F7),
      thumbColor: NovynTheme.indigo,
      overlayColor: NovynTheme.indigo.withValues(alpha: .12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
    ),
    child: Slider(value: value.clamp(0, 100).toDouble(),
      min: 0, max: 100, onChanged: onChanged),
  );
}
