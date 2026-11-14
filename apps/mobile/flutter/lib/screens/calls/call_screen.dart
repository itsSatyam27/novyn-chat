import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main_screen.dart';
import '../../services/call_platform_service.dart';
import '../../services/call_overlay_service.dart';
import '../../models/user_model.dart';
import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/audio_manager_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/user_avatar.dart';
import 'package:novyn/services/haptic_service.dart';

enum CallState { calling, connected, ended }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final String callType;
  final bool isIncoming;
  final String? callerId;
  final String? callId;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming = false,
    this.callerId,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  CallState _state = CallState.calling;
  bool _muted = false;
  bool _speakerOn = false;
  List<Map<String, dynamic>> _audioRoutes = const [];
  String _activeAudioRoute = 'earpiece';
  bool _autoBluetoothRouteAttempted = false;
  StreamSubscription<List<Map<String, dynamic>>>? _audioRouteSubscription;
  bool _cameraOff = false;
  bool _frontCamera = true;
  // Use ValueNotifier so only the timer text widget rebuilds each second
  final ValueNotifier<int> _seconds = ValueNotifier(0);
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WebRTCService _webrtc;
  late Future<void> _webrtcInit;
  Timer? _callTimeoutTimer;
  late String _callId;
  bool _hasLoggedCall = false;
  bool _isMinimized = false;
  bool _isSystemPip = false;
  Route<dynamic>? _callRoute;
  bool _mediaStarted = false;
  bool _mediaInitializing = false;
  String? _mediaError;
  String? _endReason;

  // Backend call routing is keyed by Novyn username, not a Firebase UID.
  String get _peerId => widget.peer.username.isNotEmpty ? widget.peer.username : widget.peer.uid;

  // Draggable PiP position
  Offset _pipPosition = const Offset(0, 0); // Will be set in initState
  final double _pipWidth = 120;
  final double _pipHeight = 160;

  bool _isVideo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _callRoute ??= ModalRoute.of(context);
  }

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
    _isVideo = widget.callType == 'video';
    _webrtc.onNetworkRecovered = () {
      if (mounted) {
        SystemSound.play(SystemSoundType.alert);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call reconnected'), duration: Duration(seconds: 2)),
        );
      }
    };
    CallPlatformService.setPipListener((inPip) {
      if (!mounted) return;
      setState(() => _isSystemPip = inPip);
      _refreshMiniOverlay();
    });
    unawaited(CallPlatformService.setCallActive(true));
    _callId = widget.callId ?? '';
    _webrtcInit = _initWebRTC();
    _listenToAudioRoutes();
    _playRingtone();
    _listenToCallEvents();

    if (!widget.isIncoming) {
      _callId = context.read<SocketService>().sendCallInvite(
        _peerId,
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

  Future<void> _applyVideoSpeakerDefault() async {
    if (!_isVideo) return;
    try {
      // Video calls start on loudspeaker; voice calls keep the earpiece default.
      await _setPlayerAudioRoute('speaker');
      await _webrtc.toggleSpeaker(true);
      await AudioManagerService.setAudioRoute('speaker');
      if (mounted) await _refreshAudioRoutes();
    } catch (error) {
      debugPrint('[NovynCalls] Could not apply default video speaker route: $error');
    }
  }

  Future<void> _initWebRTC() async {
    try {
      await _webrtc.init();
      await _webrtc.setEarpieceMode();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _mediaError = 'Call audio/video could not be initialized. Check device permissions.');
    }
  }

  Future<void> _ensureLocalMedia() async {
    await _webrtcInit;
    if (_mediaStarted) return;
    if (_mediaInitializing) {
      while (_mediaInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_mediaStarted) return;
    }
    _mediaInitializing = true;
    try {
      await _webrtc.startLocalStream(video: _isVideo);
      if (_muted) _webrtc.toggleMute(true);
      if (_cameraOff) _webrtc.toggleCamera(true);
      _mediaStarted = true;
      _mediaError = null;
    } finally {
      _mediaInitializing = false;
    }
  }

  Future<void> _playRingtone() async {
    // WebRTC's initial earpiece selection must finish before ringtone routing,
    // otherwise it can race with the user's speaker selection.
    try { await _webrtcInit; } catch (_) {}
    await AudioManagerService.startCallMode();
    await _setPlayerAudioRoute('earpiece');
    await AudioManagerService.setAudioRoute('earpiece');
    if (!mounted || context.read<AuthService>().user?.presenceMode == 'busy') return;
    final preferences = context.read<SettingsService>();
    if (preferences.callRingtone == 'None') return;
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(preferences.callVolume.clamp(0.0, 1.0).toDouble());
    final sound = widget.isIncoming ? 'audio/ringtone.mp3' : 'audio/call_ring.mp3';
    await _audioPlayer.play(AssetSource(sound));
  }

  Future<void> _setPlayerAudioRoute(String routeId) async {
    // audioplayers defaults to a media stream, which can ignore Android's
    // communication-device route. Use a voice-communication audio context so
    // ringtone/ringback follows the same speaker/earpiece choice as WebRTC.
    final route = routeId == 'speaker'
        ? AudioContextConfigRoute.speaker
        : routeId == 'earpiece'
            ? AudioContextConfigRoute.earpiece
            : AudioContextConfigRoute.system;
    try {
      await _audioPlayer.setAudioContext(AudioContextConfig(route: route).build());
    } catch (_) {
      // WebRTC/native route selection remains available if a platform rejects
      // the optional player-specific audio context.
    }
  }

  void _stopRingtone() async {
    await _audioPlayer.stop();
  }

  Future<void> _listenToAudioRoutes() async {
    _audioRouteSubscription = AudioManagerService.routeChanges.listen(
      (routes) {
        if (!mounted) return;
        _applyAudioRoutes(routes);
      },
      onError: (_) {},
    );

    // Android 12+ requires runtime BLUETOOTH_CONNECT permission to enumerate
    // communication devices. Keep calls usable if permission is declined.
    try {
      await Permission.bluetoothConnect.request();
    } catch (_) {}
    await _refreshAudioRoutes();
  }

  Future<void> _refreshAudioRoutes() async {
    final routes = await AudioManagerService.getAvailableRoutes();
    if (!mounted) return;
    _applyAudioRoutes(routes);
  }

  void _applyAudioRoutes(List<Map<String, dynamic>> routes) {
    final bluetooth = routes.where((route) => route['kind'] == 'bluetooth').toList();
    final active = routes.where((route) => route['selected'] == true);
    setState(() {
      _audioRoutes = routes;
      if (active.isNotEmpty) {
        _activeAudioRoute = active.first['id']?.toString() ?? 'earpiece';
      }
      _speakerOn = _activeAudioRoute == 'speaker';
      if (bluetooth.isEmpty) _autoBluetoothRouteAttempted = false;
    });

    // Prefer a connected headset for calls, just like native dialers.
    if (bluetooth.isNotEmpty &&
        !_activeAudioRoute.startsWith('bluetooth:') &&
        !_autoBluetoothRouteAttempted) {
      _autoBluetoothRouteAttempted = true;
      _selectAudioRoute(bluetooth.first['id'].toString());
    }
  }

  Future<void> _selectAudioRoute(String routeId) async {
    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.calls);
    // Route the ringtone player and WebRTC media together; Android's native
    // communication device remains the final authority (including Bluetooth).
    await _setPlayerAudioRoute(routeId);
    if (routeId == 'speaker' || routeId == 'earpiece') {
      try { await _webrtc.toggleSpeaker(routeId == 'speaker'); } catch (_) {}
    }
    final changed = await AudioManagerService.setAudioRoute(routeId);
    if (changed) {
      await _refreshAudioRoutes();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not switch call audio device.')),
      );
    }
  }

  Future<void> _toggleSpeaker() async {
    final target = _speakerOn ? 'earpiece' : 'speaker';
    await _selectAudioRoute(target);
    _refreshMiniOverlay();
  }

  void _toggleMute() {
    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.calls);
    final newVal = !_muted;
    _webrtc.toggleMute(newVal);
    setState(() => _muted = newVal);
    _refreshMiniOverlay();
  }

  void _listenToCallEvents() {
    final socket = context.read<SocketService>();

    // Peer accepted → start WebRTC as caller
    socket.onCallAccepted((_) async {
      if (!mounted) return;
      _callTimeoutTimer?.cancel();
      _stopRingtone();
      await _applyVideoSpeakerDefault();
      if (!mounted) return;
      setState(() => _state = CallState.connected);
      _refreshMiniOverlay();
      _pulseCtrl.stop();
      _startTimer();

      // Caller creates the offer
      if (!widget.isIncoming) {
        try {
          await _ensureLocalMedia();
          if (!mounted) return;
          await _webrtc.createPeerConnection(socket, _peerId, true, callId: _callId);
        } catch (_) {
          socket.endCall(_peerId, callId: _callId, reason: 'Microphone or camera permission was denied.');
          _handleCallEnded(logStatus: 'missed');
        }
      }
    });

    // Incoming WebRTC offer → create peer connection as receiver
    socket.onWebRTCOffer = (data) async {
      if (!mounted) return;
      if (_isVideo) await _applyVideoSpeakerDefault();
      if (!_webrtc.hasPeerConnection) {
        await _webrtc.createPeerConnection(socket, _peerId, false, callId: _callId);
      }
      await _webrtc.handleOffer(Map<String, dynamic>.from(data), socket, _peerId, _callId);
      if (mounted) {
        setState(() {
          if (data['sdp']?.toString().contains('m=video') == true) _isVideo = true;
        });
      }
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

    socket.onCallMediaUpgradeRequestCallback = (data) async {
      if (!mounted || data['callId']?.toString() != _callId || _isVideo) return;
      final accept = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Switch to video?'),
          content: Text('${widget.peer.name} wants to upgrade this voice call to video.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Accept')),
          ],
        ),
      );
      if (!mounted) return;
      socket.respondCallMediaUpgrade(_peerId, _callId, accepted: accept == true);
    };

    socket.onCallMediaUpgradeResponseCallback = (data) async {
      if (!mounted || data['callId']?.toString() != _callId || data['accepted'] != true || _isVideo) return;
      try {
        await _webrtc.addVideoTrackAndRenegotiate(socket, _peerId, _callId);
        if (mounted) setState(() => _isVideo = true);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start video: $error')),
          );
        }
      }
    };

    socket.onCallEnded((data) {
      _stopRingtone();
      final reason = data['reason']?.toString();
      final status = _state == CallState.connected
          ? (widget.isIncoming ? 'incoming' : 'outgoing')
          : (widget.isIncoming ? 'missed' : 'outgoing');
      _handleCallEnded(logStatus: status, reason: reason);
    });
  }

  Widget _buildMiniCallWindow() => _CallMiniWindow(
        peer: widget.peer,
        isVideo: _isVideo,
        webrtc: _webrtc,
        seconds: _seconds,
        state: _state,
        muted: _muted,
        speakerOn: _speakerOn,
        cameraOff: _cameraOff,
        onExpand: _expandCall,
        onEnd: _endCall,
        onToggleMute: _toggleMute,
        onToggleSpeaker: _toggleSpeaker,
        onToggleCamera: () {
          setState(() => _cameraOff = !_cameraOff);
          _webrtc.toggleCamera(_cameraOff);
          _refreshMiniOverlay();
        },
      );

  void _refreshMiniOverlay() {
    if (_isMinimized) {
      CallOverlayService.show(
        _isSystemPip ? _buildSystemPipContent() : _buildMiniCallWindow(),
      );
    }
  }

  void _removeMiniOverlay() {
    CallOverlayService.hide();
  }

  void _minimizeCall() {
    if (_isMinimized || _state == CallState.ended || !mounted) return;
    setState(() => _isMinimized = true);
    _refreshMiniOverlay();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, animation, secondaryAnimation) => MainScreen(
          managePresence: false,
          onCallHostExit: _onMinimizedHostDisposed,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .025),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onMinimizedHostDisposed() {
    if (!mounted || !_isMinimized) return;
    _removeMiniOverlay();
    setState(() => _isMinimized = false);
  }

  void _expandCall() {
    if (!mounted) return;
    _removeMiniOverlay();
    setState(() => _isMinimized = false);
    final navigator = Navigator.of(context);
    final route = _callRoute;
    if (route != null) {
      navigator.popUntil((candidate) => identical(candidate, route));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds.value++;
    });
  }

  void _handleCallEnded({required String logStatus, String? reason}) {
    _timer?.cancel();
    _audioRouteSubscription?.cancel();
    _callTimeoutTimer?.cancel();
    if (!mounted || _hasLoggedCall) return;
    _hasLoggedCall = true;
    setState(() {
      _state = CallState.ended;
      _endReason = reason;
    });
    _refreshMiniOverlay();
    if (reason != null && reason.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
      );
    }
    // Reset audio mode back to normal
    AudioManagerService.resetMode();
    unawaited(CallPlatformService.setCallActive(false));

    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username ?? '';
    ApiService.logCall(
      callerId:   widget.isIncoming ? _peerId : myUsername,
      receiverId: widget.isIncoming ? myUsername : _peerId,
      type:       widget.callType,
      status:     logStatus,
      duration:   _seconds.value,
      callId:     _callId,
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (_isMinimized) {
        _removeMiniOverlay();
        final route = _callRoute;
        if (route != null) {
          navigator.popUntil((candidate) => identical(candidate, route));
        }
      }
      if (navigator.canPop()) navigator.pop();
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

  void _requestVideoUpgrade() {
    if (_isVideo || _state != CallState.connected) return;
    context.read<SocketService>().requestCallMediaUpgrade(_peerId, _callId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video request sent')),
    );
  }

  void _endCall() {
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.calls);
    _stopRingtone();
    context.read<SocketService>().endCall(_peerId, callId: _callId);
    _handleCallEnded(
      logStatus: _state == CallState.connected ? 'outgoing' : 'missed',
    );
  }

  Future<void> _acceptCall() async {
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.calls);
    try {
      await _ensureLocalMedia();
      if (!mounted) return;
      _stopRingtone();
      context.read<SocketService>().acceptCall(widget.callerId ?? _peerId, _callId);
      setState(() => _state = CallState.connected);
      _refreshMiniOverlay();
      _pulseCtrl.stop();
      _startTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _mediaError = 'Microphone/camera permission is required to answer this call.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mediaError!)));
    }
  }

  void _rejectCall() {
    HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.calls);
    _stopRingtone();
    context.read<SocketService>().rejectCall(widget.callerId ?? _peerId, _callId);
    _handleCallEnded(logStatus: 'missed');
  }

  @override
  void dispose() {
    _removeMiniOverlay();
    CallPlatformService.setPipListener(null);
    unawaited(CallPlatformService.setCallActive(false));
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
    socket.onCallMediaUpgradeRequestCallback = null;
    socket.onCallMediaUpgradeResponseCallback = null;
    _webrtc.onNetworkRecovered = null;
    // Clear call event callbacks so stale handlers don't fire next call
    socket.onCallAcceptedCallback = null;
    socket.onCallRejectedCallback = null;
    socket.onCallEndedCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // Back is a minimize action, never a hang-up. Keep the call route and
      // WebRTC session alive underneath the app's main screen.
      canPop: _state == CallState.ended,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _state != CallState.ended) _minimizeCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isSystemPip
            ? _buildSystemPipContent()
            : (_isVideo && _state == CallState.connected
                ? _buildVideoCall()
                : _buildVoiceCall()),
      ),
    );
  }

  Widget _buildSystemPipContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo && _webrtc.remoteStream != null)
            RTCVideoView(
              _webrtc.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF272B4B), Color(0xFF101225)],
                ),
              ),
              child: Center(
                child: UserAvatar(
                  name: widget.peer.name,
                  photoUrl: widget.peer.photoUrl,
                  radius: 42,
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _seconds,
                      builder: (_, value, __) => Text(
                        _state == CallState.connected
                            ? _formatDuration(value)
                            : _statusText(value),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PipAction(
                  icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  onTap: _toggleMute,
                ),
                _PipAction(
                  icon: Icons.call_end_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: _endCall,
                ),
                if (_isVideo)
                  _PipAction(
                    icon: _cameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    onTap: () {
                      setState(() => _cameraOff = !_cameraOff);
                      _webrtc.toggleCamera(_cameraOff);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Video call UI ──────────────────────────────────────────────────────
  Widget _buildVideoCall() {
    final connected = _state == CallState.connected;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _webrtc.remoteStream != null
              ? RTCVideoView(
                  _webrtc.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.35, -0.55),
                      radius: 1.25,
                      colors: [Color(0xFF5967B8), Color(0xFF25294D), Color(0xFF0B0D1B)],
                      stops: [0, .52, 1],
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(
                      right: -100, bottom: 60,
                      child: Container(
                        width: 360, height: 360,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [Color(0x886D4C91), Color(0x006D4C91)]),
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, child) => Transform.scale(
                          scale: _state == CallState.calling ? _pulse.value : 1,
                          child: child,
                        ),
                        child: UserAvatar(
                          name: widget.peer.name,
                          photoUrl: widget.peer.photoUrl,
                          radius: 112,
                          fallbackColor: const Color(0xFF6D5DFC),
                        ),
                      ),
                    ),
                  ]),
                ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .34), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: .72)],
                  stops: const [0, .25, .58, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 18, 0),
                child: Row(
                  children: [
                    _CallGlassButton(icon: Icons.keyboard_arrow_down_rounded, onTap: _minimizeCall),
                    const Spacer(),
                    Column(
                      children: [
                        Text(widget.peer.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        ValueListenableBuilder<int>(
                          valueListenable: _seconds,
                          builder: (_, secs, __) => Text(
                            connected ? '${_formatDuration(secs)} · HD' : _statusText(secs),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 22),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 22, right: 18),
                  child: GestureDetector(
                    onTap: () async {
                      HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.calls);
                      await _webrtc.switchCamera();
                      if (mounted) setState(() => _frontCamera = !_frontCamera);
                    },
                    onPanUpdate: (details) => setState(() {
                      _pipPosition = Offset(
                        (_pipPosition.dx + details.delta.dx).clamp(8, MediaQuery.sizeOf(context).width - _pipWidth - 8),
                        (_pipPosition.dy + details.delta.dy).clamp(MediaQuery.paddingOf(context).top + 70, MediaQuery.sizeOf(context).height - _pipHeight - 180),
                      );
                    }),
                    child: Container(
                      width: _pipWidth, height: _pipHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17192B),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: .75), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _cameraOff
                          ? const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 28))
                          : _webrtc.localStream != null
                              ? RTCVideoView(_webrtc.localRenderer, mirror: _frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                              : Center(child: UserAvatar(name: 'You', photoUrl: '', radius: 34)),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_audioRoutes.any((route) => route['kind'] == 'bluetooth'))
                Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildAudioRouteSelector()),
              if (_state == CallState.calling && widget.isIncoming)
                _buildIncomingControls()
              else if (_state == CallState.calling)
                _buildCallingControls()
              else
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xCC151525),
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(color: Colors.white.withValues(alpha: .12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallDockButton(icon: Icons.flip_camera_android_rounded, onTap: () async { await _webrtc.switchCamera(); if (mounted) setState(() => _frontCamera = !_frontCamera); }),
                      _CallDockButton(icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, onTap: () { setState(() => _cameraOff = !_cameraOff); _webrtc.toggleCamera(_cameraOff); }),
                      _CallDockButton(icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded, onTap: _toggleMute, active: _muted),
                      _CallDockButton(icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded, onTap: _toggleSpeaker, active: _speakerOn),
                      _CallDockButton(icon: Icons.call_end_rounded, onTap: _endCall, danger: true),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCall() {
    final connected = _state == CallState.connected;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-.42, -.68), radius: 1.35,
          colors: [Color(0xFF414B91), Color(0xFF20233F), Color(0xFF0B0D19)],
          stops: [0, .5, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120, bottom: 120,
            child: Container(width: 420, height: 420, decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x776D4B91), Color(0x006D4B91)]),
            )),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 18, 0),
                  child: Row(children: [
                    _CallGlassButton(icon: Icons.keyboard_arrow_down_rounded, onTap: _minimizeCall),
                    const Spacer(),
                    Column(children: [
                      Text(widget.peer.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: _seconds,
                        builder: (_, secs, __) => Text(
                          connected ? '${_formatDuration(secs)} · HD' : _statusText(secs),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    const Spacer(),
                    const Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 22),
                  ]),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: _state == CallState.calling ? _pulse.value : 1,
                    child: child,
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Container(width: 210, height: 210, decoration: BoxDecoration(
                      shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .10), width: 1.5),
                    )),
                    Container(width: 178, height: 178, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF7564FF).withValues(alpha: .30), blurRadius: 42, spreadRadius: 8)],
                    ), child: UserAvatar(name: widget.peer.name, photoUrl: widget.peer.photoUrl, radius: 88, fallbackColor: const Color(0xFF6D5DFC))),
                  ]),
                ),
                const SizedBox(height: 28),
                Text(widget.peer.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -.6)),
                const SizedBox(height: 9),
                ValueListenableBuilder<int>(
                  valueListenable: _seconds,
                  builder: (_, secs, __) => Text(
                    connected ? _formatDuration(secs) : _statusText(secs),
                    style: TextStyle(color: connected ? const Color(0xFF9BE8C5) : Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if (connected) ...[const SizedBox(height: 12), _NetworkQualityBadge(webrtc: _webrtc)],
                const Spacer(flex: 3),
                if (_audioRoutes.any((route) => route['kind'] == 'bluetooth')) Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildAudioRouteSelector()),
                if (_state == CallState.calling && widget.isIncoming)
                  _buildIncomingControls()
                else if (_state == CallState.calling)
                  _buildCallingControls()
                else if (connected)
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xCC151525),
                      borderRadius: BorderRadius.circular(38),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _CallDockButton(icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded, onTap: _toggleMute, active: _muted),
                      _CallDockButton(icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded, onTap: _toggleSpeaker, active: _speakerOn),
                      _CallDockButton(icon: Icons.call_end_rounded, onTap: _endCall, danger: true),
                    ]),
                  )
                else
                  Padding(padding: const EdgeInsets.only(bottom: 28), child: Text(_endReason ?? 'Call ended', style: const TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ],
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
              fontFamily: 'PlusJakartaSans',
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
          if (_audioRoutes.any((route) => route['kind'] == 'bluetooth')) ...[
            _buildAudioRouteSelector(),
            const SizedBox(height: 20),
          ],
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
                    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.calls);
                    setState(() => _cameraOff = !_cameraOff);
                    _webrtc.toggleCamera(_cameraOff);
                  },
                )
              else
                _ToggleButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  active: false,
                  onTap: _requestVideoUpgrade,
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

  Widget _buildAudioRouteSelector() {
    final routes = _audioRoutes
        .where((route) => route['kind'] == 'bluetooth')
        .toList();
    if (routes.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: routes.map((route) {
          final id = route['id']?.toString() ?? '';
          final name = route['name']?.toString() ?? 'Audio';
          final selected = route['selected'] == true || id == _activeAudioRoute;
          final bluetooth = route['kind'] == 'bluetooth';
          final icon = bluetooth
              ? Icons.bluetooth_audio_rounded
              : id == 'speaker'
                  ? Icons.volume_up_rounded
                  : Icons.phone_in_talk_rounded;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: selected ? null : () => _selectAudioRoute(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 17),
                    const SizedBox(width: 6),
                    Text(name, style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
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
    final background = active
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.1);
    final foreground = active ? const Color(0xFF1A1D2E) : Colors.white;
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: !disabled,
          label: label,
          child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: foreground, size: 26),
            ),
          ),
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
                  fontFamily: 'PlusJakartaSans',
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


class _PipAction extends StatelessWidget {
  const _PipAction({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.size = 34,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.58),
        shape: const CircleBorder(),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tightFor(width: size, height: size),
          icon: Icon(icon, color: color, size: size * 0.56),
          onPressed: onTap,
        ),
      );
}

class _CallMiniWindow extends StatefulWidget {
  const _CallMiniWindow({
    required this.peer,
    required this.isVideo,
    required this.webrtc,
    required this.seconds,
    required this.state,
    required this.muted,
    required this.speakerOn,
    required this.cameraOff,
    required this.onExpand,
    required this.onEnd,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleCamera,
  });

  final UserModel peer;
  final bool isVideo;
  final WebRTCService webrtc;
  final ValueListenable<int> seconds;
  final CallState state;
  final bool muted;
  final bool speakerOn;
  final bool cameraOff;
  final VoidCallback onExpand;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCamera;

  @override
  State<_CallMiniWindow> createState() => _CallMiniWindowState();
}

class _CallMiniWindowState extends State<_CallMiniWindow> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            (constraints.maxWidth - 16).clamp(1.0, double.infinity).toDouble();
        final width = (widget.isVideo ? 204.0 : 300.0)
            .clamp(1.0, availableWidth)
            .toDouble();
        final height = widget.isVideo
            ? (width * 1.36).clamp(150.0, 278.0).toDouble()
            : 112.0;
        final maxX = (constraints.maxWidth - width - 10)
            .clamp(0.0, double.infinity)
            .toDouble();
        final maxY = (constraints.maxHeight - height - 20)
            .clamp(0.0, double.infinity)
            .toDouble();
        final minX = maxX >= 8 ? 8.0 : 0.0;
        final minY = maxY >= 8 ? 8.0 : 0.0;
        _position ??= Offset(maxX, maxY);
        final position = Offset(
          _position!.dx.clamp(minX, maxX).toDouble(),
          _position!.dy.clamp(minY, maxY).toDouble(),
        );
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                onTap: widget.onExpand,
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      (position.dx + details.delta.dx).clamp(minX, maxX).toDouble(),
                      (position.dy + details.delta.dy).clamp(minY, maxY).toDouble(),
                    );
                  });
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 18,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: width,
                    height: height,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF15182B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ListenableBuilder(
                      listenable: widget.webrtc,
                      builder: (context, _) => widget.isVideo
                          ? _buildVideoMini()
                          : _buildVoiceMini(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoMini() {
    final actionSize = MediaQuery.of(context).size.width < 260 ? 24.0 : 34.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.webrtc.remoteStream != null)
          RTCVideoView(
            widget.webrtc.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        else
          Container(
            color: const Color(0xFF20243D),
            child: Center(
              child: UserAvatar(
                name: widget.peer.name,
                photoUrl: widget.peer.photoUrl,
                radius: 38,
              ),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.peer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: widget.seconds,
                builder: (_, secs, __) => Text(
                  widget.state == CallState.connected ? _format(secs) : 'Calling',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 40,
          right: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 62,
              height: 84,
              child: widget.cameraOff
                  ? const ColoredBox(
                      color: Colors.black87,
                      child: Icon(Icons.videocam_off_rounded, color: Colors.white70),
                    )
                  : RTCVideoView(
                      widget.webrtc.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PipAction(
                icon: widget.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                onTap: widget.onToggleMute,
                size: actionSize,
              ),
              _PipAction(
                icon: widget.speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                onTap: widget.onToggleSpeaker,
                size: actionSize,
              ),
              _PipAction(
                icon: Icons.call_end_rounded,
                color: const Color(0xFFEF4444),
                onTap: widget.onEnd,
                size: actionSize,
              ),
              _PipAction(
                icon: widget.cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                onTap: widget.onToggleCamera,
                size: actionSize,
              ),
              _PipAction(
                icon: Icons.open_in_full_rounded,
                onTap: widget.onExpand,
                size: actionSize,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceMini() {
    final actionSize = MediaQuery.sizeOf(context).width < 360 ? 28.0 : 30.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            name: widget.peer.name,
            photoUrl: widget.peer.photoUrl,
            radius: 21,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peer.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: widget.seconds,
                  builder: (_, secs, __) => Text(
                    widget.state == CallState.connected ? _format(secs) : 'Calling…',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PipAction(icon: widget.muted ? Icons.mic_off_rounded : Icons.mic_rounded, onTap: widget.onToggleMute, size: actionSize),
          const SizedBox(width: 3),
          _PipAction(icon: widget.speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, onTap: widget.onToggleSpeaker, size: actionSize),
          const SizedBox(width: 3),
          _PipAction(icon: Icons.call_end_rounded, color: const Color(0xFFEF4444), onTap: widget.onEnd, size: actionSize),
        ],
      ),
    );
  }

  String _format(int seconds) {
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final h = seconds ~/ 3600;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}



class _CallGlassButton extends StatelessWidget {
  const _CallGlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .12),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 46, height: 46, child: Icon(icon, color: Colors.white, size: 27)),
    ),
  );
}

class _CallDockButton extends StatelessWidget {
  const _CallDockButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? const Color(0xFFE72F3D)
        : active
            ? Colors.white
            : Colors.white.withValues(alpha: .13);
    final foreground = danger
        ? Colors.white
        : active
            ? const Color(0xFF24243A)
            : Colors.white;
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: foreground, size: 24),
        ),
      ),
    );
  }
}
