import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// A compact chat attachment player. Incoming voice notes are downloaded
/// before playback; outgoing notes can stream immediately.
class ChatAudioMessageBubble extends StatefulWidget {
  const ChatAudioMessageBubble({
    super.key,
    required this.url,
    required this.isOutgoing,
    required this.prepareLocalSource,
    this.requiresLocalSource = false,
    this.durationSeconds,
    this.sizeBytes,
  });

  final String url;
  final bool isOutgoing;
  final Future<String> Function() prepareLocalSource;
  final bool requiresLocalSource;
  final int? durationSeconds;
  final int? sizeBytes;

  @override
  State<ChatAudioMessageBubble> createState() => _ChatAudioMessageBubbleState();
}

class _ChatAudioMessageBubbleState extends State<ChatAudioMessageBubble> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _localPath;
  bool _downloading = false;
  bool _loadingPlayback = false;

  bool get _isPlaying => _playerState == PlayerState.playing;
  bool get _hasLocalCopy => _localPath != null;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
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

  Future<void> _download() async {
    if (_downloading || _hasLocalCopy) return;
    setState(() => _downloading = true);
    try {
      final path = await widget.prepareLocalSource();
      if (!mounted) return;
      setState(() => _localPath = path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio download failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_loadingPlayback || _downloading) return;
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    if (_playerState == PlayerState.paused) {
      await _player.resume();
      return;
    }

    setState(() => _loadingPlayback = true);
    try {
      if (widget.requiresLocalSource || _localPath != null) {
        _localPath ??= await widget.prepareLocalSource();
        await _player.play(DeviceFileSource(_localPath!));
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play this voice message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlayback = false);
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final outgoing = widget.isOutgoing;
    final duration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: widget.durationSeconds ?? 0);
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final progress = (_position.inMilliseconds / maxMs).clamp(0.0, 1.0).toDouble();
    final durationLabel = _formatDuration(duration);
    final sizeLabel = _formatSize(widget.sizeBytes);
    final canStream = outgoing && !widget.requiresLocalSource;
    final ready = widget.isOutgoing ? (canStream || widget.requiresLocalSource) : _hasLocalCopy;

    final shellColor = outgoing ? accent : scheme.surface;
    final panelColor = outgoing
        ? Colors.white.withValues(alpha: .17)
        : scheme.surfaceContainerLow;
    final mainColor = outgoing ? Colors.white : scheme.onSurface;
    final mutedColor = outgoing
        ? Colors.white.withValues(alpha: .72)
        : scheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(276.0, MediaQuery.sizeOf(context).width * .78).toDouble(),
      ),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: shellColor,
          borderRadius: BorderRadius.circular(23).copyWith(
            bottomRight: outgoing ? const Radius.circular(8) : const Radius.circular(23),
            bottomLeft: outgoing ? const Radius.circular(23) : const Radius.circular(8),
          ),
        ),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Material(
                color: outgoing ? Colors.white : accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: ready ? _togglePlayback : _download,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: _downloading || _loadingPlayback
                          ? SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: outgoing ? accent : Colors.white,
                              ),
                            )
                          : Icon(
                              ready
                                  ? (_isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded)
                                  : Icons.download_rounded,
                              size: 23,
                              color: outgoing ? accent : Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: CustomPaint(
                  size: const Size(1, 34),
                  painter: _ChatAudioWaveformPainter(
                    progress: progress,
                    playedColor: outgoing ? Colors.white : accent,
                    remainingColor: outgoing
                        ? Colors.white.withValues(alpha: .38)
                        : accent.withValues(alpha: .25),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                _downloading
                    ? 'Downloading'
                    : sizeLabel.isNotEmpty && !ready
                        ? '$durationLabel · $sizeLabel'
                        : durationLabel,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatAudioWaveformPainter extends CustomPainter {
  const _ChatAudioWaveformPainter({
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
  });

  final double progress;
  final Color playedColor;
  final Color remainingColor;

  static const List<double> _bars = [
    8, 15, 23, 13, 19, 10, 27, 17, 12, 24,
    31, 16, 21, 10, 26, 18, 13, 23, 15, 29,
    18, 12, 25, 16, 21, 11, 19, 14,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final gap = 3.0;
    final barWidth = math.max(2.0, (size.width - gap * (_bars.length - 1)) / _bars.length);
    final totalWidth = barWidth * _bars.length + gap * (_bars.length - 1);
    final startX = math.max(0.0, (size.width - totalWidth) / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < _bars.length; index++) {
      final barHeight = _bars[index].clamp(5.0, size.height - 2).toDouble();
      final x = startX + index * (barWidth + gap);
      final top = (size.height - barHeight) / 2;
      final midpoint = (x + barWidth / 2) / size.width;
      paint.color = midpoint <= progress ? playedColor : remainingColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatAudioWaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.remainingColor != remainingColor;
}
