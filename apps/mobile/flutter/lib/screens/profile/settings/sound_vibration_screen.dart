import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../services/settings_service.dart';
import '../../../services/haptic_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/novyn_theme.dart';

class SoundVibrationScreen extends StatefulWidget {
  const SoundVibrationScreen({super.key});
  @override
  State<SoundVibrationScreen> createState() => _SoundVibrationScreenState();
}

class _SoundVibrationScreenState extends State<SoundVibrationScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playing;
  String _callPreview = 'ringtone';

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _play(String kind, SettingsService settings) async {
    if (_playing == kind) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await _player.stop();
    final volume = kind == 'message' ? settings.messageVolume : settings.callVolume;
    await _player.setVolume(volume);
    final asset = kind == 'message'
        ? switch (settings.notificationTone) {
            'Pulse' => 'audio/message_sent.mp3',
            'Glass' => 'audio/ringtone.mp3',
            'Echo' => 'audio/call_ring.mp3',
            _ => 'audio/notification.mp3',
          }
        : (_callPreview == 'ringback' ? 'audio/ringtone.mp3' : 'audio/call_ring.mp3');
    try {
      await _player.play(AssetSource(asset));
      if (mounted) setState(() => _playing = kind);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sound preview is unavailable right now.')));
    }
  }

  void _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(title.toUpperCase(), style: const TextStyle(
      fontFamily: 'PlusJakartaSans', fontSize: 12, letterSpacing: 1.2,
      fontWeight: FontWeight.w800, color: Color(0xFF6554F5))),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final busy = context.watch<AuthService>().user?.presenceMode == 'busy';
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(children: [
            _backButton(context),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sound & Vibration', style: TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.6, color: ink)),
              Text('Tones, previews and haptics', style: TextStyle(fontSize: 13, color: muted)),
            ])),
          ]),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          physics: const BouncingScrollPhysics(),
          children: [
            _section('Messages'),
            _toggleCard(icon: Icons.notifications_active_outlined, title: 'Message sounds',
              subtitle: 'Play sounds for incoming and sent messages',
              value: s.inAppSounds, onChanged: s.setInAppSounds),
            const SizedBox(height: 14),
            _soundCard(title: 'Message chime', subtitle: 'Sound for incoming texts',
              playing: _playing == 'message', enabled: s.inAppSounds,
              volume: s.messageVolume, onPlay: () => _play('message', s),
              onVolume: (v) { s.setMessageVolume(v); _player.setVolume(v); },
              selected: const ['Drift', 'Pulse', 'Glass', 'Echo'].contains(s.notificationTone) ? s.notificationTone : 'Drift',
              choices: const ['Drift', 'Pulse', 'Glass', 'Echo'],
              onChoice: (v) { s.setNotificationTone(v); if (s.inAppSounds) _play('message', s); }),
            _section('Calls'),
            _toggleCard(icon: Icons.call_outlined, title: 'Call sounds',
              subtitle: 'Incoming ringtone and outgoing ringback',
              value: s.callRingtone != 'None',
              onChanged: (v) => s.setCallRingtone(v ? 'Binary' : 'None')),
            const SizedBox(height: 14),
            _soundCard(title: 'Call preview',
              subtitle: _callPreview == 'ringtone' ? 'Incoming ringtone' : 'Outgoing ringback',
              playing: _playing == 'call', enabled: s.callRingtone != 'None',
              volume: s.callVolume, onPlay: () => _play('call', s),
              onVolume: (v) { s.setCallVolume(v); _player.setVolume(v); },
              selected: _callPreview,
              choices: const ['ringtone', 'ringback'],
              labels: const ['Ringtone', 'Ringback'],
              onChoice: (v) { setState(() => _callPreview = v); if (s.callRingtone != 'None') _play('call', s); }),
            _section('Vibration'),
            _choiceCard(icon: Icons.vibration_rounded, title: 'Vibration rhythm',
              subtitle: 'Pattern for incoming alerts', value: s.vibrationPattern,
              choices: const ['standard', 'staccato', 'heartbeat', 'none'],
              labels: const ['Standard', 'Staccato', 'Heartbeat', 'Off'],
              onChanged: (v) { s.setVibrationPattern(v); _previewVibration(v); }),
            _toggleCard(icon: Icons.touch_app_outlined, title: 'Haptic feedback',
              subtitle: 'Tactile response when you tap', value: s.inAppVibration,
              onChanged: s.setInAppVibration),
            const SizedBox(height: 14),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const _IconTile(icon: Icons.tune_rounded),
                const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Haptic intensity', style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 15)),
                  Text('Strength of the vibration', style: TextStyle(color: muted, fontSize: 12)),
                ])), Text('${(s.hapticIntensity * 100).round()}%', style: const TextStyle(color: Color(0xFF6554F5), fontWeight: FontWeight.w800))]),
              Slider(value: s.hapticIntensity, onChanged: s.setHapticIntensity,
                activeColor: const Color(0xFF6554F5), inactiveColor: const Color(0xFFE0DDF8)),
            ])),
            const SizedBox(height: 14),
            _panel(child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => HapticService.vibrate(NovynHapticType.heavy),
              child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [
                _IconTile(icon: Icons.play_arrow_rounded), SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Test vibration', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6554F5))),
                  Text('Feel your current pattern', style: TextStyle(fontSize: 12, color: Color(0xFF77738F))),
                ])),
              ])),
            )),
            _section('Focus'),
            _panel(child: Row(children: [
              const _IconTile(icon: Icons.notifications_off_outlined),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Busy mode', style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 15)),
                Text('When your status is Busy, message and call alerts are silenced.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF6554F5).withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                child: Text(busy ? 'Active' : 'Off', style: const TextStyle(color: Color(0xFF6554F5), fontWeight: FontWeight.w700))),
            ])),
          ],
        )),
      ])),
    );
  }

  void _previewVibration(String pattern) {
    switch (pattern) {
      case 'standard': HapticService.vibrate(NovynHapticType.medium); break;
      case 'staccato': HapticService.vibrate(NovynHapticType.heavy); break;
      case 'heartbeat': HapticService.vibrate(NovynHapticType.warning); break;
    }
  }

  Widget _backButton(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface, shape: const CircleBorder(),
    child: InkWell(onTap: () => Navigator.maybePop(context), customBorder: const CircleBorder(),
      child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left_rounded, size: 25))),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(
      color: NovynTheme.cardBg(context), borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)));

  Widget _toggleCard({required IconData icon, required String title, required String subtitle,
    required bool value, required ValueChanged<bool> onChanged}) => _panel(child: Row(children: [
      _IconTile(icon: icon), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      Switch.adaptive(value: value, activeColor: const Color(0xFF6554F5), onChanged: onChanged),
    ]));

  Widget _choiceCard({required IconData icon, required String title, required String subtitle,
    required String value, required List<String> choices, required List<String> labels,
    required ValueChanged<String> onChanged}) => _panel(child: Row(children: [
      _IconTile(icon: icon), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      PopupMenuButton<String>(initialValue: value, onSelected: onChanged,
        itemBuilder: (_) => choices.asMap().entries.map((e) => PopupMenuItem(value: e.value, child: Text(labels[e.key]))).toList(),
        child: Row(children: [Text(labels[choices.indexOf(value).clamp(0, labels.length - 1)], style: const TextStyle(color: Color(0xFF6554F5), fontWeight: FontWeight.w700)), const Icon(Icons.chevron_right_rounded, color: Color(0xFF6554F5))])),
    ]));

  Widget _soundCard({required String title, required String subtitle, required bool playing,
    required bool enabled, required double volume, required VoidCallback onPlay,
    required ValueChanged<double> onVolume, required String selected,
    required List<String> choices, List<String>? labels, required ValueChanged<String> onChoice}) {
    final names = labels ?? choices;
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]),
      const SizedBox(height: 20),
      _Waveform(playing: playing),
      const SizedBox(height: 18),
      Row(children: [
        Material(color: enabled ? const Color(0xFF6554F5) : const Color(0xFFBDB8D8),
          shape: const CircleBorder(), child: InkWell(onTap: enabled ? onPlay : null, customBorder: const CircleBorder(),
            child: SizedBox(width: 54, height: 54, child: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 25)))),
        const SizedBox(width: 14),
        Expanded(child: Column(children: [
          Row(children: [Expanded(child: Text(title.startsWith('Message') ? 'Message volume' : 'Call volume',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
            Text('${(volume * 100).round()}%', style: const TextStyle(color: Color(0xFF6554F5), fontWeight: FontWeight.w800))]),
          Slider(value: volume, onChanged: enabled ? onVolume : null, activeColor: const Color(0xFF6554F5), inactiveColor: const Color(0xFFE0DDF8)),
        ])),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: choices.asMap().entries.map((e) {
        final active = selected == e.value;
        return ChoiceChip(label: Text(names[e.key]), selected: active,
          onSelected: (_) => onChoice(e.value),
          selectedColor: const Color(0xFFECE9FF),
          labelStyle: TextStyle(color: active ? const Color(0xFF6554F5) : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700),
          side: BorderSide(color: active ? const Color(0xFF6554F5) : Theme.of(context).colorScheme.outlineVariant));
      }).toList()),
    ]));
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  const _IconTile({required this.icon});
  @override Widget build(BuildContext context) => Container(width: 42, height: 42,
    decoration: BoxDecoration(color: const Color(0xFF6554F5).withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
    child: Icon(icon, color: const Color(0xFF6554F5), size: 21));
}

class _Waveform extends StatelessWidget {
  final bool playing;
  const _Waveform({required this.playing});
  static const bars = [18,32,48,29,60,39,72,45,31,56,80,42,26,62,38,69,52,28,57,41,64,33,46,24];
  @override Widget build(BuildContext context) => SizedBox(height: 56, child: Row(
    crossAxisAlignment: CrossAxisAlignment.center, children: bars.map((h) => Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2), child: AnimatedContainer(
        duration: const Duration(milliseconds: 220), height: playing ? h.toDouble() : h * .78,
        decoration: BoxDecoration(color: const Color(0xFF6554F5).withValues(alpha: playing ? .95 : (.35 + (h / 100)).clamp(.35, 1.0).toDouble()),
          borderRadius: BorderRadius.circular(5))))).toList()));
}
