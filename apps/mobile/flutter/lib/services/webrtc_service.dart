import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class WebRTCService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer  = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteScreenRenderer = RTCVideoRenderer();
  final RTCVideoRenderer localScreenRenderer = RTCVideoRenderer();
  MediaStream? _screenStream;
  RTCRtpSender? _screenSender;
  String? _remoteScreenStreamId;
  bool get isScreenSharing => _screenStream != null;
  void Function(String? streamId)? onRemoteScreenShareChanged;

  bool _isInitialized = false;
  bool _remoteDescriptionSet = false;
  bool _isOfferer = false;
  Timer? _iceRestartTimer;
  Timer? _qualityTimer;
  bool _qualitySampleInFlight = false;
  int _poorQualitySamples = 0;
  int _healthyQualitySamples = 0;
  bool _autoAudioOnly = false;
  RTCRtpSender? _videoSender;
  MediaStreamTrack? _videoTrack;
  int _iceRestartAttempts = 0;
  SocketService? _activeSocket;
  String? _activePeerId;
  String? _activeCallId;
  VoidCallback? onNetworkRecovered;
  ValueChanged<bool>? onAutomaticVideoFallback;
  bool get isAutoAudioOnly => _autoAudioOnly;
  bool get hasPeerConnection => _peerConnection != null;
  final List<RTCIceCandidate> _pendingIceCandidates = <RTCIceCandidate>[];
  bool get isInitialized => _isInitialized;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Connection state tracking
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  RTCPeerConnectionState get connectionState => _connectionState;

  // Network quality indicator
  String _networkQuality = 'good'; // excellent, good, poor
  String get networkQuality => _networkQuality;

  // ICE servers — STUN + free TURN servers for better connectivity
  static const _iceServers = {
    'iceServers': [
      // Google STUN servers
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Free TURN servers (relay for restrictive networks)
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  // ── Initialize renderers ─────────────────────────────────────────────────
  Future<void> init() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    await remoteScreenRenderer.initialize();
    await localScreenRenderer.initialize();
    _isInitialized = true;
    notifyListeners();
  }

  // ── Start local media stream ─────────────────────────────────────────────
  Future<void> startLocalStream({bool video = true}) async {
    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280, 'max': 1920},
              'height': {'ideal': 720, 'max': 1080},
              'frameRate': {'ideal': 30, 'max': 30},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
    notifyListeners();
  }

  // ── Create peer connection ───────────────────────────────────────────────
  Future<void> createPeerConnection(
    SocketService socket,
    String peerId,
    bool isOffer, {
    required String callId,
  }) async {
    // Peer connection configuration with optimized settings
    final config = {
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all', // Use both STUN and TURN
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    _remoteDescriptionSet = false;
    _isOfferer = isOffer;
    _activeSocket = socket;
    _activePeerId = peerId;
    _activeCallId = callId;
    _peerConnection = await createPeerConnectionWithConfig(
      _iceServers,
      config,
    );

    // Add local tracks to connection and retain the video sender for adaptive fallback.
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      final sender = await _peerConnection!.addTrack(track, _localStream!);
      if (track.kind == 'video') {
        _videoSender = sender;
        _videoTrack = track;
      }
    }

    // Handle remote stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        if (stream.id == _remoteScreenStreamId) {
          remoteScreenRenderer.srcObject = stream;
        } else {
          _remoteStream = stream;
          remoteRenderer.srcObject = stream;
        }
        notifyListeners();
      }
    };

    // Send ICE candidates to peer via socket
    _peerConnection!.onIceCandidate = (candidate) {
      socket.sendIceCandidate(peerId, callId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (state) {
      _connectionState = state;
      notifyListeners();
    };

    _peerConnection!.onIceConnectionState = (state) {
      // Monitor connection quality
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        final wasRecovering = _networkQuality == 'poor' || _iceRestartAttempts > 0;
        _networkQuality = 'good';
        _startNetworkQualitySampling();
        _iceRestartAttempts = 0;
        _iceRestartTimer?.cancel();
        if (wasRecovering) onNetworkRecovered?.call();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
        _networkQuality = 'good';
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
                 state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _qualityTimer?.cancel();
        _networkQuality = 'poor';
        _scheduleIceRestart();
      }
      notifyListeners();
    };

    if (isOffer) {
      await _createAndSendOffer(socket, peerId, callId);
    }
  }

  void _startNetworkQualitySampling() {
    _qualityTimer?.cancel();
    _sampleNetworkQuality();
    _qualityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sampleNetworkQuality(),
    );
  }

  double? _statsNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _sampleNetworkQuality() async {
    final connection = _peerConnection;
    if (connection == null || _qualitySampleInFlight) return;
    _qualitySampleInFlight = true;
    try {
      final reports = await connection.getStats();
      Map<dynamic, dynamic>? selectedPair;
      double? remotePacketLoss;
      for (final report in reports) {
        final values = report.values;
        if (report.type == 'candidate-pair' && values['state'] == 'succeeded') {
          final selected = values['selected'] == true || values['nominated'] == true;
          if (selected || selectedPair == null) selectedPair = values;
        }
        if (report.type == 'remote-inbound-rtp' && values['kind'] == 'video') {
          final lost = _statsNumber(values['packetsLost']);
          final received = _statsNumber(values['packetsReceived']);
          if (lost != null && received != null && lost + received > 0) {
            remotePacketLoss = (lost / (lost + received)).clamp(0.0, 1.0);
          }
        }
      }

      final rtt = _statsNumber(selectedPair?['currentRoundTripTime']);
      final bitrate = _statsNumber(selectedPair?['availableOutgoingBitrate']);
      final hasMeasurements = rtt != null || remotePacketLoss != null || bitrate != null;
      final severe = (rtt != null && rtt >= 0.65) ||
          (remotePacketLoss != null && remotePacketLoss >= 0.12) ||
          (bitrate != null && bitrate < 120000);
      final poor = (rtt != null && rtt >= 0.40) ||
          (remotePacketLoss != null && remotePacketLoss >= 0.06) ||
          (bitrate != null && bitrate < 300000);
      final healthy = hasMeasurements &&
          (rtt == null || rtt < 0.22) &&
          (remotePacketLoss == null || remotePacketLoss < 0.025) &&
          (bitrate == null || bitrate >= 700000);

      if (severe) {
        _poorQualitySamples++;
        _healthyQualitySamples = 0;
        _networkQuality = 'poor';
        await _applyAdaptiveVideoConstraints('poor');
        if (_poorQualitySamples >= 2) await _setAutomaticAudioOnly(true);
      } else if (poor) {
        _poorQualitySamples++;
        _healthyQualitySamples = 0;
        _networkQuality = 'poor';
        await _applyAdaptiveVideoConstraints('poor');
      } else if (healthy) {
        _healthyQualitySamples++;
        _poorQualitySamples = 0;
        _networkQuality = 'excellent';
        await _applyAdaptiveVideoConstraints('excellent');
        if (_autoAudioOnly && _healthyQualitySamples >= 3) {
          await _setAutomaticAudioOnly(false);
        }
      } else {
        _poorQualitySamples = 0;
        _healthyQualitySamples = 0;
        _networkQuality = 'good';
        await _applyAdaptiveVideoConstraints('good');
      }
      notifyListeners();
    } catch (error) {
      debugPrint('[NovynWebRTC] Adaptive quality sample failed: $error');
    } finally {
      _qualitySampleInFlight = false;
    }
  }

  Future<void> _applyAdaptiveVideoConstraints(String quality) async {
    final track = _videoTrack;
    if (track == null || _autoAudioOnly) return;
    final constraints = quality == 'excellent'
        ? <String, dynamic>{
            'width': {'ideal': 960, 'max': 960},
            'height': {'ideal': 540, 'max': 540},
            'frameRate': {'ideal': 24, 'max': 24},
          }
        : quality == 'poor'
            ? <String, dynamic>{
                'width': {'ideal': 320, 'max': 320},
                'height': {'ideal': 240, 'max': 240},
                'frameRate': {'ideal': 12, 'max': 12},
              }
            : <String, dynamic>{
                'width': {'ideal': 640, 'max': 640},
                'height': {'ideal': 360, 'max': 360},
                'frameRate': {'ideal': 20, 'max': 20},
              };
    try {
      await track.applyConstraints(constraints);
    } catch (error) {
      debugPrint('[NovynWebRTC] Could not apply $quality video constraints: $error');
    }
  }

  Future<void> _setAutomaticAudioOnly(bool enabled) async {
    if (_autoAudioOnly == enabled) return;
    final sender = _videoSender;
    final track = _videoTrack;
    if (sender == null || track == null) return;
    try {
      await sender.replaceTrack(enabled ? null : track);
      _autoAudioOnly = enabled;
      if (enabled) {
        _healthyQualitySamples = 0;
        await track.applyConstraints({
          'width': {'ideal': 160, 'max': 160},
          'height': {'ideal': 120, 'max': 120},
          'frameRate': {'ideal': 5, 'max': 5},
        });
      } else {
        await _applyAdaptiveVideoConstraints('good');
      }
      onAutomaticVideoFallback?.call(enabled);
      notifyListeners();
    } catch (error) {
      debugPrint('[NovynWebRTC] Automatic audio-only transition failed: $error');
    }
  }

  void _scheduleIceRestart() {
    if (!_isOfferer || _iceRestartAttempts >= 3 || _iceRestartTimer?.isActive == true) return;
    final delaySeconds = 2 << _iceRestartAttempts;
    _iceRestartTimer = Timer(Duration(seconds: delaySeconds), () async {
      final connection = _peerConnection;
      final socket = _activeSocket;
      final peerId = _activePeerId;
      final callId = _activeCallId;
      if (connection == null || socket == null || peerId == null || callId == null) return;
      _iceRestartAttempts++;
      try {
        final offer = await connection.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
          'iceRestart': true,
        });
        await connection.setLocalDescription(offer);
        socket.sendOffer(peerId, callId, {'sdp': offer.sdp, 'type': offer.type});
        if (_networkQuality == 'poor') _scheduleIceRestart();
      } catch (error) {
        debugPrint('[NovynWebRTC] ICE restart attempt $_iceRestartAttempts failed: $error');
        _scheduleIceRestart();
      }
    });
  }

  Future<void> addLocalVideoTrack() async {
    final connection = _peerConnection;
    final stream = _localStream;
    if (connection == null || stream == null) {
      throw StateError('The voice call is not ready for video upgrade.');
    }
    if (stream.getVideoTracks().isNotEmpty) return;
    final cameraStream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640, 'max': 960},
        'height': {'ideal': 480, 'max': 540},
        'frameRate': {'ideal': 20, 'max': 24},
      },
    });
    final tracks = cameraStream.getVideoTracks();
    if (tracks.isEmpty) throw StateError('Camera did not provide a video track.');
    await stream.addTrack(tracks.first);
    _videoTrack = tracks.first;
    _videoSender = await connection.addTrack(tracks.first, stream);
    localRenderer.srcObject = stream;
    notifyListeners();
  }

  Future<void> addVideoTrackAndRenegotiate(
    SocketService socket, String peerId, String callId,
  ) async {
    final connection = _peerConnection;
    final stream = _localStream;
    if (connection == null || stream == null) {
      throw StateError('The voice call is not ready for video upgrade.');
    }
    if (stream.getVideoTracks().isEmpty) {
      final cameraStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 960},
          'height': {'ideal': 480, 'max': 540},
          'frameRate': {'ideal': 20, 'max': 24},
        },
      });
      final tracks = cameraStream.getVideoTracks();
      if (tracks.isEmpty) throw StateError('Camera did not provide a video track.');
      await stream.addTrack(tracks.first);
      _videoTrack = tracks.first;
      _videoSender = await connection.addTrack(tracks.first, stream);
      localRenderer.srcObject = stream;
    }
    final offer = await connection.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await connection.setLocalDescription(offer);
    socket.sendOffer(peerId, callId, {'sdp': offer.sdp, 'type': offer.type});
    notifyListeners();
  }

  Future<void> startScreenShare(SocketService socket, String peerId, String callId) async {
    final connection = _peerConnection;
    if (connection == null) throw StateError('Call connection is not ready.');
    if (_screenStream != null) return;
    final screen = await navigator.mediaDevices.getDisplayMedia({
      'audio': false,
      'video': {
        'frameRate': {'ideal': 12, 'max': 15},
        'width': {'ideal': 1280, 'max': 1600},
        'height': {'ideal': 720, 'max': 900},
      },
    });
    final track = screen.getVideoTracks().firstOrNull;
    if (track == null) {
      await screen.dispose();
      throw StateError('Screen capture did not return a video track.');
    }
    _screenStream = screen;
    localScreenRenderer.srcObject = screen;
    _screenSender = await connection.addTrack(track, screen);
    _remoteScreenStreamId = screen.id;
    socket.updateCallScreenShare(peerId, callId, screen.id);
    track.onEnded = () {
      stopScreenShare(socket, peerId, callId, renegotiate: true);
    };
    final offer = await connection.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await connection.setLocalDescription(offer);
    socket.sendOffer(peerId, callId, {'sdp': offer.sdp, 'type': offer.type});
    notifyListeners();
  }

  Future<void> stopScreenShare(
    SocketService socket, String peerId, String callId, {bool renegotiate = true}
  ) async {
    final screen = _screenStream;
    final sender = _screenSender;
    _screenStream = null;
    localScreenRenderer.srcObject = null;
    _screenSender = null;
    _remoteScreenStreamId = null;
    socket.updateCallScreenShare(peerId, callId, null);
    if (sender != null && _peerConnection != null) {
      try { await _peerConnection!.removeTrack(sender); } catch (_) {}
    }
    for (final track in screen?.getTracks() ?? <MediaStreamTrack>[]) {
      track.onEnded = null;
      await track.stop();
    }
    await screen?.dispose();
    if (renegotiate && _peerConnection != null) {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);
      socket.sendOffer(peerId, callId, {'sdp': offer.sdp, 'type': offer.type});
    }
    notifyListeners();
  }

  void setRemoteScreenShare(String? streamId) {
    _remoteScreenStreamId = streamId;
    onRemoteScreenShareChanged?.call(streamId);
    if (streamId == null) remoteScreenRenderer.srcObject = null;
  }

  // ── Create and send offer (caller) ───────────────────────────────────────
  Future<void> _createAndSendOffer(SocketService socket, String peerId, String callId) async {
    // Offer options for better video quality
    final offerOptions = {
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    };
    
    final offer = await _peerConnection!.createOffer(offerOptions);
    await _peerConnection!.setLocalDescription(offer);
    socket.sendOffer(peerId, callId, {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  // ── Handle incoming offer (receiver) ────────────────────────────────────
  Future<void> handleOffer(
    Map<String, dynamic> offerData,
    SocketService socket,
    String peerId,
    String callId,
  ) async {
    final offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    await _flushPendingIceCandidates();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    socket.sendAnswer(peerId, callId, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  // ── Handle incoming answer (caller) ─────────────────────────────────────
  Future<void> handleAnswer(Map<String, dynamic> answerData) async {
    final answer = RTCSessionDescription(
      answerData['sdp'],
      answerData['type'],
    );
    await _peerConnection!.setRemoteDescription(answer);
    _remoteDescriptionSet = true;
    await _flushPendingIceCandidates();
  }

  // ── Handle ICE candidate ─────────────────────────────────────────────────
  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate']?.toString(),
      data['sdpMid']?.toString(),
      (data['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (_peerConnection == null || !_remoteDescriptionSet) {
      _pendingIceCandidates.add(candidate);
      return;
    }
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _flushPendingIceCandidates() async {
    final connection = _peerConnection;
    if (connection == null || !_remoteDescriptionSet || _pendingIceCandidates.isEmpty) return;
    final pending = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in pending) {
      await connection.addCandidate(candidate);
    }
  }

  // ── Toggle mute ──────────────────────────────────────────────────────────
  void toggleMute(bool muted) {
    // Disable the mic track — works during ringing and connected
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  // ── Toggle camera ────────────────────────────────────────────────────────
  void toggleCamera(bool off) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !off;
    });
  }

  // ── Switch camera (front/back) ───────────────────────────────────────────
  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  // ── Toggle speaker (earpiece ↔ loudspeaker) ─────────────────────────────
  Future<void> toggleSpeaker(bool on) async {
    // flutter_webrtc routes WebRTC audio output
    await Helper.setSpeakerphoneOn(on);
  }

  // ── Force earpiece mode on call start (default to earpiece) ─────────────
  Future<void> setEarpieceMode() async {
    await Helper.setSpeakerphoneOn(false);
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────
  @override
  Future<void> dispose() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    await remoteScreenRenderer.dispose();
    await localScreenRenderer.dispose();
    await _screenStream?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _videoSender = null;
    _videoTrack = null;
    _autoAudioOnly = false;
    _iceRestartTimer?.cancel();
    _qualityTimer?.cancel();
    _pendingIceCandidates.clear();
    _remoteDescriptionSet = false;
    _activeSocket = null;
    _activePeerId = null;
    _activeCallId = null;
    _remoteDescriptionSet = false;
    _isInitialized = false;
    super.dispose();
  }
}

// Helper to create peer connection with config
Future<RTCPeerConnection> createPeerConnectionWithConfig(
  Map<String, dynamic> iceServers,
  Map<String, dynamic> constraints,
) async {
  return await createPeerConnection(iceServers, constraints);
}
