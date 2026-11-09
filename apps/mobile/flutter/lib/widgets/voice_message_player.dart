import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final String label;
  final int? durationSeconds;

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.label = 'Voice message',
    this.durationSeconds,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      if (_state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play this voice message.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(Duration duration) {
    final minutes = duration.inMinutes.toString();
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: widget.durationSeconds ?? 0);
    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final value = _position.inMilliseconds.toDouble().clamp(0.0, max);
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            visualDensity: VisualDensity.compact,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_state == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700)),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: value,
                    max: max,
                    onChanged: duration.inMilliseconds == 0 ? null : (next) => _player.seek(Duration(milliseconds: next.round())),
                  ),
                ),
                Text(
                  '${_time(_position)} / ${duration.inMilliseconds == 0 ? '--:--' : _time(duration)}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
