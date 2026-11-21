import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:novyn/widgets/novyn_alert.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final String label;
  final int? durationSeconds;
  final Future<String> Function()? resolveLocalSource;

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.label = 'Voice message',
    this.durationSeconds,
    this.resolveLocalSource,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _speakingAnimation;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _speakingAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state == PlayerState.playing) {
        _speakingAnimation.repeat();
      } else {
        _speakingAnimation
          ..stop()
          ..value = 0;
      }
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
    _speakingAnimation.dispose();
    _player.dispose();
    super.dispose();
  }

  Widget _buildSpeakingWaveform(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 40,
      height: 18,
      child: AnimatedBuilder(
        animation: _speakingAnimation,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(7, (index) {
            final phase = _state == PlayerState.playing
                ? _speakingAnimation.value * 2 * math.pi
                : 0.0;
            final level = (math.sin(phase + index * .85).abs() * .75) + .15;
            return Container(
              width: 3,
              height: 3 + (level * 13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .45 + (level * .5)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
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
      } else if (widget.resolveLocalSource != null) {
        final path = await widget.resolveLocalSource!();
        await _player.play(DeviceFileSource(path));
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted)
        context.showNovynAlert(
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
    final max =
        duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final value =
        _position.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _state == PlayerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSpeakingWaveform(context),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: value,
                    max: max,
                    onChanged: duration.inMilliseconds == 0
                        ? null
                        : (next) =>
                            _player.seek(Duration(milliseconds: next.round())),
                  ),
                ),
                Text(
                  '${_time(_position)} / ${duration.inMilliseconds == 0 ? '--:--' : _time(duration)}',
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 9,
                      color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
