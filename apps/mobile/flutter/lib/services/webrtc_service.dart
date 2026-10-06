import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class WebRTCService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer  = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Connection state tracking
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  RTCPeerConnectionState get connectionState => _connectionState;

  // Network quality indicator
  String _networkQuality = 'good'; // good, fair, poor
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
    bool isOffer,
  ) async {
    // Peer connection configuration with optimized settings
    final config = {
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all', // Use both STUN and TURN
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    _peerConnection = await createPeerConnectionWithConfig(
      _iceServers,
      config,
    );

    // Add local tracks to connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle remote stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };

    // Send ICE candidates to peer via socket
    _peerConnection!.onIceCandidate = (candidate) {
      socket.sendIceCandidate(peerId, {
        'candidate':     candidate.candidate,
        'sdpMid':        candidate.sdpMid,
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
        _networkQuality = 'good';
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
        _networkQuality = 'fair';
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
                 state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _networkQuality = 'poor';
      }
      notifyListeners();
    };

    if (isOffer) {
      await _createAndSendOffer(socket, peerId);
    }
  }

  // ── Create and send offer (caller) ───────────────────────────────────────
  Future<void> _createAndSendOffer(SocketService socket, String peerId) async {
    // Offer options for better video quality
    final offerOptions = {
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    };
    
    final offer = await _peerConnection!.createOffer(offerOptions);
    await _peerConnection!.setLocalDescription(offer);
    socket.sendOffer(peerId, {
      'sdp':  offer.sdp,
      'type': offer.type,
    });
  }

  // ── Handle incoming offer (receiver) ────────────────────────────────────
  Future<void> handleOffer(
    Map<String, dynamic> offerData,
    SocketService socket,
    String peerId,
  ) async {
    final offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    socket.sendAnswer(peerId, {
      'sdp':  answer.sdp,
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
  }

  // ── Handle ICE candidate ─────────────────────────────────────────────────
  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
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
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
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
