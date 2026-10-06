import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/user_model.dart';
import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/audio_manager_service.dart';
import '../../widgets/user_avatar.dart';

enum CallState { calling, connected, ended }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final String callType;
  final bool isIncoming;
  final String? callerId;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming = false,
    this.callerId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  CallState _state = CallState.calling;
  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraOff = false;
  bool _frontCamera = true;
  // Use ValueNotifier so only the timer text widget rebuilds each second
  final ValueNotifier<int> _seconds = ValueNotifier(0);
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WebRTCService _webrtc;
  Timer? _callTimeoutTimer;

  // Draggable PiP position
  Offset _pipPosition = const Offset(0, 0); // Will be set in initState
  final double _pipWidth = 120;
  final double _pipHeight = 160;

  bool get _isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurveTween(curve: Curves.easeInOut).animate(_pulseCtrl),
    );

    _webrtc = WebRTCService();
    _initWebRTC();
    _playRingtone();
    _listenToCallEvents();

    if (!widget.isIncoming) {
      context.read<SocketService>().sendCallInvite(
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        isVideo: _isVideo,
      );
    }

    // Auto-cancel/reject after 45 seconds if no answer
    _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_state == CallState.calling && mounted) {
        widget.isIncoming ? _rejectCall() : _endCall();
      }
    });

    // Set initial PiP position (top-right) after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _pipPosition = Offset(
            size.width - _pipWidth - 16, // 16px from right
            80, // Below top bar
          );
        });
      }
    });
  }

  Future<void> _initWebRTC() async {
    await _webrtc.init();
    await _webrtc.startLocalStream(video: _isVideo);
    // Default to earpiece for calls
    await _webrtc.setEarpieceMode();
    if (mounted) setState(() {});
  }

  void _playRingtone() async {
    // Set MODE_IN_COMMUNICATION once — earpiece by default, no pause on later toggles
    await AudioManagerService.startCallMode();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    final sound = widget.isIncoming ? 'audio/ringtone.mp3' : 'audio/call_ring.mp3';
    await _audioPlayer.play(AssetSource(sound));
  }

  void _stopRingtone() async {
    await _audioPlayer.stop();
  }

  // ── Speaker toggle — works during ringing AND active call ────────────
  void _toggleSpeaker() async {
    HapticFeedback.selectionClick();
    final newVal = !_speakerOn;
    setState(() => _speakerOn = newVal);
    await AudioManagerService.setSpeakerphoneOn(newVal);
  }

  // ── Mute toggle — works during ringing AND active call ───────────────
  void _toggleMute() {
    HapticFeedback.selectionClick();
    final newVal = !_muted;
    setState(() => _muted = newVal);
    // Disable WebRTC audio track (works when connected)
    _webrtc.toggleMute(newVal);
    // Also mute the mic at AudioManager level (works during ringing too)
    AudioManagerService.setMicMute(newVal);
  }

  void _listenToCallEvents() {
    final socket = context.read<SocketService>();

    // Peer accepted → start WebRTC as caller
    socket.onCallAccepted((_) async {
      if (!mounted) return;
      _callTimeoutTimer?.cancel();
      _stopRingtone();
      setState(() => _state = CallState.connected);
      _pulseCtrl.stop();
      _startTimer();

      // Caller creates the offer
      if (!widget.isIncoming) {
        await _webrtc.createPeerConnection(socket, widget.peer.uid, true);
      }
    });

    // Incoming WebRTC offer → create peer connection as receiver
    socket.onWebRTCOffer = (data) async {
      if (!mounted) return;
      await _webrtc.createPeerConnection(socket, widget.peer.uid, false);
      await _webrtc.handleOffer(Map<String, dynamic>.from(data), socket, widget.peer.uid);
      if (mounted) setState(() {});
    };

    // Incoming answer → set remote description
    socket.onWebRTCAnswer = (data) async {
      await _webrtc.handleAnswer(Map<String, dynamic>.from(data));
      if (mounted) setState(() {});
    };

    // ICE candidates
    socket.onWebRTCIceCandidate = (data) async {
      await _webrtc.handleIceCandidate(Map<String, dynamic>.from(data));
    };

    socket.onCallRejected(() {
      _stopRingtone();
      _handleCallEnded(logStatus: 'missed');
    });

    socket.onCallEnded(() {
      _stopRingtone();
      _handleCallEnded(logStatus: 'incoming');
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds.value++;
    });
  }

  void _handleCallEnded({required String logStatus}) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _state = CallState.ended);
    // Reset audio mode back to normal
    AudioManagerService.resetMode();

    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username ?? '';
    ApiService.logCall(
      callerId:   widget.isIncoming ? (widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username) : myUsername,
      receiverId: widget.isIncoming ? myUsername : (widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username),
      type:       widget.callType,
      status:     logStatus,
      duration:   _seconds.value,
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  // Snap PiP to nearest edge (like WhatsApp)
  void _snapToEdge() {
    if (!mounted) return;
    
    final size = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    
    // Define safe boundaries
    final minX = 8.0;
    final maxX = size.width - _pipWidth - 8;
    final minY = safeArea.top + 60; // Below top bar
    final maxY = size.height - _pipHeight - 120; // Above bottom controls
    
    // Current center position
    final centerX = _pipPosition.dx + _pipWidth / 2;
    final centerY = _pipPosition.dy + _pipHeight / 2;
    
    // Determine which edge is closest
    final distanceToLeft = centerX;
    final distanceToRight = size.width - centerX;
    final distanceToTop = centerY;
    final distanceToBottom = size.height - centerY;
    
    // Find minimum distance
    final minDistance = [
      distanceToLeft,
      distanceToRight,
      distanceToTop,
      distanceToBottom,
    ].reduce((a, b) => a < b ? a : b);
    
    double targetX = _pipPosition.dx;
    double targetY = _pipPosition.dy;
    
    // Snap to nearest edge
    if (minDistance == distanceToLeft) {
      // Snap to left edge
      targetX = minX;
      targetY = _pipPosition.dy.clamp(minY, maxY);
    } else if (minDistance == distanceToRight) {
      // Snap to right edge
      targetX = maxX;
      targetY = _pipPosition.dy.clamp(minY, maxY);
    } else if (minDistance == distanceToTop) {
      // Snap to top edge
      targetX = _pipPosition.dx.clamp(minX, maxX);
      targetY = minY;
    } else {
      // Snap to bottom edge
      targetX = _pipPosition.dx.clamp(minX, maxX);
      targetY = maxY;
    }
    
    // Animate to target position
    setState(() {
      _pipPosition = Offset(targetX, targetY);
    });
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    _stopRingtone();
    context.read<SocketService>().endCall(widget.peer.uid);
    _handleCallEnded(
      logStatus: _state == CallState.connected ? 'outgoing' : 'missed',
    );
  }

  void _acceptCall() {
    HapticFeedback.mediumImpact();
    _stopRingtone();
    context.read<SocketService>().acceptCall(widget.callerId ?? widget.peer.uid);
    setState(() => _state = CallState.connected);
    _pulseCtrl.stop();
    _startTimer();
  }

  void _rejectCall() {
    HapticFeedback.mediumImpact();
    _stopRingtone();
    context.read<SocketService>().rejectCall(widget.callerId ?? widget.peer.uid);
    _handleCallEnded(logStatus: 'missed');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callTimeoutTimer?.cancel();
    _pulseCtrl.dispose();
    _audioPlayer.dispose();
    _webrtc.dispose();
    _seconds.dispose();
    // Clear WebRTC callbacks
    final socket = context.read<SocketService>();
    socket.onWebRTCOffer = null;
    socket.onWebRTCAnswer = null;
    socket.onWebRTCIceCandidate = null;
    // Clear call event callbacks so stale handlers don't fire next call
    socket.onCallAcceptedCallback = null;
    socket.onCallRejectedCallback = null;
    socket.onCallEndedCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isVideo && _state == CallState.connected
          ? _buildVideoCall()
          : _buildVoiceCall(),
    );
  }

  // ── Video call UI ──────────────────────────────────────────────────────
  Widget _buildVideoCall() {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: _webrtc.remoteStream != null
              ? RTCVideoView(
                  _webrtc.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  color: const Color(0xFF1A1D2E),
                  child: Center(
                    child: UserAvatar(
                      name: widget.peer.name,
                      photoUrl: widget.peer.photoUrl,
                      radius: 60,
                    ),
                  ),
                ),
        ),

        // Draggable local video (picture-in-picture)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: _pipPosition.dx,
          top: _pipPosition.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _pipPosition = Offset(
                  _pipPosition.dx + details.delta.dx,
                  _pipPosition.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (details) {
              // Snap to nearest edge (like WhatsApp)
              _snapToEdge();
            },
            onTap: () async {
              HapticFeedback.selectionClick();
              await _webrtc.switchCamera();
              setState(() => _frontCamera = !_frontCamera);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: _pipWidth,
                  height: _pipHeight,
                  child: _cameraOff
                      ? Container(
                          color: Colors.black87,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off_rounded,
                                  color: Colors.white54, size: 32),
                              SizedBox(height: 4),
                              Text(
                                'Camera off',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            RTCVideoView(
                              _webrtc.localRenderer,
                              mirror: _frontCamera,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                            // Flip camera hint
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.flip_camera_ios_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peer.name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: _seconds,
                              builder: (context, secs, _) => Text(
                                _formatDuration(secs),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Network quality indicator
                            _NetworkQualityBadge(webrtc: _webrtc),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VideoControlBtn(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: _muted,
                    onTap: _toggleMute,
                  ),
                  _VideoControlBtn(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    active: _speakerOn,
                    onTap: _toggleSpeaker,
                  ),
                  // End call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  _VideoControlBtn(
                    icon: _cameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    active: _cameraOff,
                    onTap: () {
                      setState(() => _cameraOff = !_cameraOff);
                      _webrtc.toggleCamera(_cameraOff);
                    },
                  ),
                  _VideoControlBtn(
                    icon: Icons.flip_camera_ios_rounded,
                    active: false,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await _webrtc.switchCamera();
                      setState(() => _frontCamera = !_frontCamera);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Voice call UI ──────────────────────────────────────────────────────
  Widget _buildVoiceCall() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2140), Color(0xFF0F1123)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isVideo ? 'Video Call' : 'Voice Call',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance the back button
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Avatar ───────────────────────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: _state == CallState.calling ? _pulse.value : 1.0,
                  child: child,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    if (_state == CallState.calling)
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7C6FF7).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    // Inner ring
                    Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 2,
                        ),
                      ),
                    ),
                    UserAvatar(
                      name: widget.peer.name,
                      photoUrl: widget.peer.photoUrl,
                      radius: 60,
                      fallbackColor: const Color(0xFF7C6FF7),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Name ─────────────────────────────────────────────────
            Text(
              widget.peer.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 10),

            // ── Status / timer ────────────────────────────────────────
            ValueListenableBuilder<int>(
              valueListenable: _seconds,
              builder: (context, secs, _) {
                final text = _statusText(secs);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _state == CallState.connected
                          ? const Color(0xFF10B981)
                          : Colors.white38,
                    ),
                  ),
                );
              },
            ),

            const Spacer(),

            // ── Controls ─────────────────────────────────────────────
            if (_state == CallState.calling && widget.isIncoming)
              _buildIncomingControls()
            else if (_state == CallState.calling && !widget.isIncoming)
              _buildCallingControls()
            else if (_state == CallState.connected)
              _buildConnectedControls()
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Call ended',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Text(
            'Incoming ${widget.callType} call',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToggleButton(
                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _muted ? 'Unmute' : 'Mute',
                active: _muted,
                onTap: _toggleMute,
              ),
              _ToggleButton(
                icon: _speakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Speaker',
                active: _speakerOn,
                onTap: _toggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CallButton(
                icon: Icons.call_end_rounded,
                label: 'Decline',
                color: const Color(0xFFEF4444),
                onTap: _rejectCall,
              ),
              _CallButton(
                icon: Icons.call_rounded,
                label: 'Accept',
                color: const Color(0xFF10B981),
                onTap: _acceptCall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToggleButton(
                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _muted ? 'Unmute' : 'Mute',
                active: _muted,
                onTap: _toggleMute,
              ),
              _ToggleButton(
                icon: _speakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Speaker',
                active: _speakerOn,
                onTap: _toggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 36),
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'Cancel',
            color: const Color(0xFFEF4444),
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // ── Toggle buttons row ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToggleButton(
                icon: _muted
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
                label: _muted ? 'Unmute' : 'Mute',
                active: _muted,
                onTap: _toggleMute,
              ),
              _ToggleButton(
                icon: _speakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Speaker',
                active: _speakerOn,
                onTap: _toggleSpeaker,
              ),
              if (_isVideo)
                _ToggleButton(
                  icon: _cameraOff
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                  label: _cameraOff ? 'Cam off' : 'Camera',
                  active: _cameraOff,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _cameraOff = !_cameraOff);
                    _webrtc.toggleCamera(_cameraOff);
                  },
                )
              else
                // Placeholder for "Add call" — coming later
                _ToggleButton(
                  icon: Icons.person_add_rounded,
                  label: 'Add call',
                  active: false,
                  onTap: () {},
                  disabled: true,
                ),
            ],
          ),

          const SizedBox(height: 36),

          // ── End call button ─────────────────────────────────────
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'End Call',
            color: const Color(0xFFEF4444),
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  String _statusText(int secs) {
    switch (_state) {
      case CallState.calling:
        return widget.isIncoming ? 'Incoming call...' : 'Calling...';
      case CallState.connected:
        return _formatDuration(secs);
      case CallState.ended:
        return 'Call ended';
    }
  }

  String _formatDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

// ── Video control button (small, for video call overlay) ──────────────────
class _VideoControlBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _VideoControlBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: active ? const Color(0xFF1A1D2E) : Colors.white, size: 24),
      ),
    );
  }
}

// ── Big call button ────────────────────────────────────────────────────────
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle button ──────────────────────────────────────────────────────────
class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool disabled;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: active ? const Color(0xFF1A1D2E) : Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Network quality indicator ──────────────────────────────────────────────
class _NetworkQualityBadge extends StatelessWidget {
  final WebRTCService webrtc;

  const _NetworkQualityBadge({required this.webrtc});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: webrtc,
      builder: (context, _) {
        final quality = webrtc.networkQuality;
        final color = quality == 'good'
            ? const Color(0xFF10B981)
            : quality == 'fair'
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);
        
        final icon = quality == 'good'
            ? Icons.signal_cellular_alt_rounded
            : quality == 'fair'
                ? Icons.signal_cellular_alt_2_bar_rounded
                : Icons.signal_cellular_alt_1_bar_rounded;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 3),
              Text(
                quality == 'good' ? 'HD' : quality == 'fair' ? 'SD' : 'Low',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
