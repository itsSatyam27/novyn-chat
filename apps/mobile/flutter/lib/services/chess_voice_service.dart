import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'rtc_ice_configuration.dart';
import 'socket_service.dart';

/// Audio-only WebRTC peer used by an active 1v1 Chess match.
/// Signaling is restricted by the backend to the two players in that match.
class ChessVoiceService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  SocketService? _socket;
  String? _roomId;
  bool _disposed = false;
  bool _remoteDescriptionSet = false;
  bool _muted = false;
  bool _speakerEnabled = true;
  bool _isOfferer = false;
  String _status = 'connecting';
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  bool get isMuted => _muted;
  bool get isSpeakerEnabled => _speakerEnabled;
  String get status => _status;
  bool get isConnected => _status == 'live';

  static const List<Map<String, dynamic>> _fallbackIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
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
  ];

  Future<void> start({
    required SocketService socket,
    required String roomId,
    required bool isOfferer,
  }) async {
    if (_disposed) throw StateError('Chess voice has already ended.');
    if (_peerConnection != null) return;
    _socket = socket;
    _roomId = roomId;
    _isOfferer = isOfferer;
    _setStatus('connecting');

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw StateError(permission.isPermanentlyDenied
          ? 'Allow microphone access in Android Settings to use Chess voice.'
          : 'Microphone permission is required for Chess voice.');
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    if (_disposed) {
      for (final track in stream.getTracks()) {
        track.enabled = false;
        await track.stop();
      }
      await stream.dispose();
      throw StateError('Chess voice was closed while opening the microphone.');
    }
    _localStream = stream;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !_muted;
    }

    dynamic icePayload;
    try {
      icePayload = await ApiService.getRtcIceConfiguration();
    } catch (_) {
      icePayload = null;
    }
    final configuration = RtcIceConfiguration.resolve(
      icePayload,
      fallbackServers: _fallbackIceServers,
    );
    final connection = await createPeerConnection(configuration, {
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });
    if (_disposed) {
      await connection.close();
      return;
    }
    _peerConnection = connection;

    for (final track in stream.getAudioTracks()) {
      await connection.addTrack(track, stream);
    }

    connection.onTrack = (event) {
      if (_disposed || event.track.kind != 'audio') return;
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      }
      event.track.enabled = true;
    };

    connection.onIceCandidate = (candidate) {
      final candidateText = candidate.candidate;
      if (_disposed || candidateText == null || candidateText.isEmpty) return;
      _socket?.sendChessVoiceSignal(_roomId!, {
        'type': 'candidate',
        'candidate': candidateText,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    connection.onConnectionState = (state) {
      if (_disposed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setStatus('live');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setStatus('reconnecting');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
        _setStatus('connecting');
      }
    };

    connection.onIceConnectionState = (state) {
      if (_disposed) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _setStatus('live');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _setStatus('reconnecting');
        if (_isOfferer && state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          unawaited(_restartIce());
        }
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
        _setStatus('connecting');
      }
    };

    await Helper.setSpeakerphoneOn(_speakerEnabled);
    if (_isOfferer) {
      final offer = await connection.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await connection.setLocalDescription(offer);
      socket.sendChessVoiceSignal(roomId, {
        'type': 'offer',
        'sdp': offer.sdp,
      });
    }
  }

  void _setStatus(String value) {
    if (_status == value || _disposed) return;
    _status = value;
    notifyListeners();
  }

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    final connection = _peerConnection;
    if (_disposed || connection == null) return;
    final type = signal['type']?.toString();
    if (type == 'offer') {
      final description = RTCSessionDescription(
        signal['sdp']?.toString(),
        'offer',
      );
      await connection.setRemoteDescription(description);
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
      final answer = await connection.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await connection.setLocalDescription(answer);
      _socket?.sendChessVoiceSignal(_roomId!, {
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } else if (type == 'answer') {
      await connection.setRemoteDescription(RTCSessionDescription(
        signal['sdp']?.toString(),
        'answer',
      ));
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
    } else if (type == 'candidate') {
      final candidateText = signal['candidate']?.toString();
      if (candidateText == null || candidateText.isEmpty) return;
      final candidate = RTCIceCandidate(
        candidateText,
        signal['sdpMid']?.toString(),
        (signal['sdpMLineIndex'] as num?)?.toInt(),
      );
      if (!_remoteDescriptionSet) {
        _pendingCandidates.add(candidate);
      } else {
        await connection.addCandidate(candidate);
      }
    }
  }

  Future<void> _flushPendingCandidates() async {
    final connection = _peerConnection;
    if (connection == null || !_remoteDescriptionSet || _pendingCandidates.isEmpty) {
      return;
    }
    final candidates = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      await connection.addCandidate(candidate);
    }
  }

  Future<void> _restartIce() async {
    final connection = _peerConnection;
    final roomId = _roomId;
    if (_disposed || !_isOfferer || connection == null || roomId == null) return;
    try {
      final offer = await connection.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
        'iceRestart': true,
      });
      await connection.setLocalDescription(offer);
      _socket?.sendChessVoiceSignal(roomId, {
        'type': 'offer',
        'sdp': offer.sdp,
      });
    } catch (error) {
      debugPrint('[NovynChessVoice] ICE restart failed: $error');
    }
  }

  void setMuted(bool muted) {
    if (_disposed || _muted == muted) return;
    _muted = muted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    if (_disposed || _speakerEnabled == enabled) return;
    _speakerEnabled = enabled;
    await Helper.setSpeakerphoneOn(enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _status = 'off';
    final stream = _localStream;
    _localStream = null;
    _remoteStream = null;
    final connection = _peerConnection;
    _peerConnection = null;
    for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = false;
      unawaited(track.stop());
    }
    unawaited(stream?.dispose() ?? Future<void>.value());
    unawaited(connection?.close() ?? Future<void>.value());
    _pendingCandidates.clear();
    unawaited(Helper.setSpeakerphoneOn(false));
    super.dispose();
  }
}
