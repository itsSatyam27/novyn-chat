import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/audio_manager_service.dart';
import '../../services/auth_service.dart';
import '../../services/call_overlay_service.dart';
import '../../services/call_platform_service.dart';
import '../../services/friend_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/user_avatar.dart';
import 'group_call_layout.dart';
import '../main_screen.dart';

/// Four-person mesh call UI. One local media stream is shared by the
/// participant-specific WebRTC services; signaling stays peer-to-peer.
class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({
    super.key,
    required this.groupCallId,
    required this.callId,
    required this.isVideo,
    required this.participants,
    this.initialMediaStates = const <String, dynamic>{},
    this.initialPendingInvitations = const <Map<String, dynamic>>[],
    this.initialScreenSharer,
    this.initialScreenStreamId,
  });

  final String groupCallId;
  final String callId;
  final bool isVideo;
  final List<Map<String, dynamic>> participants;
  final Map<String, dynamic> initialMediaStates;
  final List<Map<String, dynamic>> initialPendingInvitations;
  final String? initialScreenSharer;
  final String? initialScreenStreamId;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  static const int _maxParticipants = 4;

  late final SocketService _socket;
  final Map<String, Map<String, dynamic>> _participants = {};
  final Map<String, WebRTCService> _peers = {};
  final Map<String, VoidCallback> _peerListeners = {};
  final Set<String> _creatingPeers = {};
  final Set<String> _connectedPeers = {};
  final Map<String, List<Map<String, dynamic>>> _pendingSignals = {};
  final Map<String, bool> _remoteAudioEnabled = {};
  final Map<String, bool> _remoteVideoEnabled = {};
  final Map<String, Map<String, dynamic>> _pendingInvites = {};

  WebRTCService? _mediaOwner;
  MediaStream? _localStream;
  MediaStream? _groupScreenStream;
  String _me = '';
  String? _screenSharer;
  bool _showScreenFirst = true;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _speakerRouteChanging = false;
  bool _sharingScreen = false;
  bool _initializing = true;
  bool _hasConnectedPeer = false;
  bool _leaving = false;
  bool _ended = false;
  bool _cleaned = false;
  bool _isMinimized = false;
  bool _inviting = false;
  bool _switchingCamera = false;
  bool _screenShareBusy = false;
  bool _controlsExpanded = false;
  bool _retrying = false;
  String? _error;
  Offset? _miniPosition;
  Route<dynamic>? _callRoute;
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);
  Timer? _timer;

  String get _meKey => _me.trim().toLowerCase();
  List<Map<String, dynamic>> get _participantList =>
      _participants.values.toList(growable: false);

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _me = context.read<AuthService>().user?.username ?? '';
    for (final participant in widget.participants) {
      _addParticipantRecord(participant);
    }
    _screenSharer = widget.initialScreenSharer;
    _showScreenFirst = widget.initialScreenSharer != null;
    for (final entry in widget.initialMediaStates.entries) {
      if (entry.value is! Map) continue;
      final key = entry.key.toLowerCase();
      final state = Map<String, dynamic>.from(entry.value as Map);
      _remoteAudioEnabled[key] = state['audioEnabled'] != false;
      _remoteVideoEnabled[key] = state['videoEnabled'] != false;
    }
    for (final invite in widget.initialPendingInvitations) {
      final username = invite['username']?.toString().trim() ?? '';
      if (username.isNotEmpty) {
        _pendingInvites[username.toLowerCase()] = Map<String, dynamic>.from(invite);
      }
    }
    _addParticipantRecord({
      'username': _me,
      'displayName': context.read<AuthService>().user?.name ?? _me,
    });
    _bindSocket();
    NotificationService.setActiveCallActionHandler(_handleNotificationCallAction);
    unawaited(CallPlatformService.setCallActive(true));
    unawaited(_initializeCall());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _callRoute ??= ModalRoute.of(context);
  }

  void _addParticipantRecord(Map value) {
    final username = (value['username'] ?? value['user'] ?? '').toString().trim();
    if (username.isEmpty) return;
    final key = username.toLowerCase();
    final previous = _participants[key] ?? <String, dynamic>{};
    final suppliedName = (value['displayName'] ?? value['name'] ?? '').toString().trim();
    _participants[key] = {
      ...previous,
      ...Map<String, dynamic>.from(value),
      'username': username,
      'displayName': suppliedName.isNotEmpty
          ? suppliedName
          : (previous['displayName'] ?? username),
    };
  }

  void _bindSocket() {
    _socket.onGroupCallSignalCallback = _handleSignal;
    _socket.onGroupCallParticipantJoinedCallback = (data) {
      if (!_matchesCall(data)) return;
      final joinedBy = data['joinedBy']?.toString().toLowerCase() ?? '';
      if (joinedBy.isNotEmpty) _pendingInvites.remove(joinedBy);
      _applyParticipantSnapshot(data['participants']);
      _publishActiveCallNotification();
      _refreshMiniOverlay();
    };
    _socket.onGroupCallParticipantLeftCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['participant']?.toString().trim() ?? '';
      if (username.isNotEmpty) unawaited(_removePeer(username));
      _applyParticipantSnapshot(data['participants']);
      _publishActiveCallNotification();
      _refreshMiniOverlay();
    };
    _socket.onGroupCallEndedCallback = (data) {
      if (!_matchesCall(data) || !mounted) return;
      unawaited(_finishFromServer(
        data['reason']?.toString() ?? 'The group call has ended.',
      ));
    };
    _socket.onGroupCallMediaStateCallback = (data) {
      if (!_matchesCall(data) || !mounted) return;
      final username = data['username']?.toString().toLowerCase() ?? '';
      if (username.isEmpty) return;
      setState(() {
        _remoteAudioEnabled[username] = data['audioEnabled'] != false;
        _remoteVideoEnabled[username] = data['videoEnabled'] != false;
      });
      _refreshMiniOverlay();
    };
    _socket.onGroupCallScreenShareStateCallback = (data) {
      if (!_matchesCall(data) || !mounted) return;
      final username = data['username']?.toString().trim() ?? '';
      final streamId = data['streamId']?.toString();
      setState(() {
        _screenSharer = streamId == null || streamId.isEmpty ? null : username;
        _showScreenFirst = streamId != null && streamId.isNotEmpty;
      });
      for (final peer in _peers.values) {
        peer.setRemoteScreenShare(
          streamId,
          replacesVideoTrack: streamId == null ? null : widget.isVideo,
        );
      }
      _refreshMiniOverlay();
    };
    _socket.onGroupCallInvitationDeclinedCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['username']?.toString() ?? 'Someone';
      final reason = data['reason']?.toString().trim() ?? '';
      _pendingInvites.remove(username.toLowerCase());
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason.isEmpty
              ? username + ' declined the invitation.'
              : username + ' couldn’t join: ' + reason)),
        );
      }
    };
    _socket.onGroupCallInvitationExpiredCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['username']?.toString() ?? 'Someone';
      _pendingInvites.remove(username.toLowerCase());
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(username + ' didn’t answer.')),
        );
      }
    };
    _socket.onGroupCallScreenShareDeniedCallback = (data) {
      if (!_matchesCall(data)) return;
      if (_sharingScreen) unawaited(_stopScreenShare());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['reason']?.toString() ??
                'Another participant is already sharing their screen.'),
          ),
        );
      }
    };
    _socket.onGroupCallPromotedCallback = null;
    for (final packet in _socket.takePendingGroupCallSignals(widget.groupCallId)) {
      unawaited(_handleSignal(packet));
    }
  }

  bool _matchesCall(Map data) =>
      data['groupCallId']?.toString() == widget.groupCallId;

  void _applyParticipantSnapshot(dynamic raw) {
    if (raw is! List) return;
    final next = <String, Map<String, dynamic>>{};
    for (final item in raw.whereType<Map>()) {
      final username = item['username']?.toString().trim() ?? '';
      if (username.isEmpty) continue;
      final name = item['displayName']?.toString().trim() ?? '';
      next[username.toLowerCase()] = {
        ...Map<String, dynamic>.from(item),
        'username': username,
        'displayName': name.isNotEmpty ? name : username,
      };
    }
    if (_meKey.isNotEmpty && !next.containsKey(_meKey)) {
      next[_meKey] = {'username': _me, 'displayName': _me};
    }
    if (!mounted) return;
    setState(() {
      _participants
        ..clear()
        ..addAll(next);
    });
    _publishMediaState();
    _publishActiveCallNotification();
    _refreshMiniOverlay();
    unawaited(_ensurePeerConnections());
  }

  Future<void> _initializeCall() async {
    try {
      // The outgoing 1:1 route is replaced during promotion. Give its camera
      // and microphone handles time to close before opening the mesh stream.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted || _ended || _leaving) return;
      final owner = WebRTCService();
      _mediaOwner = owner;
      await owner.init();
      if (!mounted || _ended || _leaving) {
        await owner.dispose();
        if (identical(_mediaOwner, owner)) _mediaOwner = null;
        return;
      }
      if (WebRTC.platformIsAndroid) await AudioManagerService.startCallMode();
      if (!mounted || _ended || _leaving) {
        await owner.dispose();
        if (identical(_mediaOwner, owner)) _mediaOwner = null;
        return;
      }
      await owner.startLocalStream(
        video: widget.isVideo,
        groupCall: true,
      );
      if (!mounted || _ended || _leaving) {
        await owner.dispose();
        if (identical(_mediaOwner, owner)) _mediaOwner = null;
        return;
      }
      _localStream = owner.localStream;
      if (_localStream == null) {
        throw StateError('Could not start the microphone or camera.');
      }
      final defaultRoute = widget.isVideo ? 'speaker' : 'earpiece';
      if (!WebRTC.platformIsAndroid) {
        await _mediaOwner!.toggleSpeaker(widget.isVideo);
      }
      if (WebRTC.platformIsAndroid) {
        await AudioManagerService.setAudioRoute(defaultRoute);
      }
      _speakerOn = widget.isVideo;
      _error = null;
      if (mounted) setState(() => _initializing = false);
      await _ensurePeerConnections();
      _publishMediaState();
      _publishActiveCallNotification();
    } catch (error) {
      if (!mounted || _ended || _leaving) return;
      setState(() {
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _ensurePeerConnections() async {
    if (_localStream == null || _meKey.isEmpty || _ended) return;
    final peers = _participantList
        .where((person) =>
            (person['username']?.toString().toLowerCase() ?? '') != _meKey)
        .toList()
      ..sort((a, b) => (a['username']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['username']?.toString() ?? '').toLowerCase()));
    for (final person in peers) {
      final username = person['username']?.toString().trim() ?? '';
      if (username.isNotEmpty) await _ensurePeerConnection(username);
    }
  }

  Future<void> _ensurePeerConnection(String username) async {
    final key = username.trim().toLowerCase();
    if (key.isEmpty ||
        key == _meKey ||
        _peers.containsKey(key) ||
        _localStream == null ||
        _ended ||
        !_creatingPeers.add(key)) {
      return;
    }

    final peer = WebRTCService();
    _peers[key] = peer;
    final listener = () => _handlePeerConnectionState(key, peer);
    _peerListeners[key] = listener;
    peer.addListener(listener);
    try {
      await peer.init();
      peer.attachSharedLocalStream(_localStream!);
      final shouldOffer = _meKey.compareTo(key) < 0;
      await peer.createPeerConnection(
        _socket,
        username,
        shouldOffer,
        callId: widget.groupCallId,
        groupCall: true,
      );
      _handlePeerConnectionState(key, peer);
      if (widget.initialScreenSharer != null &&
          widget.initialScreenSharer!.toLowerCase() == key &&
          widget.initialScreenStreamId != null) {
        peer.setRemoteScreenShare(
          widget.initialScreenStreamId,
          replacesVideoTrack: widget.isVideo,
        );
      }
      // Signals may arrive while the initial batch is being drained.
      // Continue until the peer has no queued offer/answer/ICE packets left.
      while (_pendingSignals.containsKey(key)) {
        final queued = _pendingSignals.remove(key) ?? const [];
        for (final signal in queued) {
          await _applySignal(peer, username, signal);
        }
      }
    } catch (error) {
      _peers.remove(key);
      final listener = _peerListeners.remove(key);
      if (listener != null) peer.removeListener(listener);
      await peer.dispose();
      if (mounted) {
        setState(() {
          _error = 'Could not connect to ' + username + '. Check the network and retry.';
        });
      }
    } finally {
      _creatingPeers.remove(key);
    }
  }

  void _handlePeerConnectionState(String key, WebRTCService peer) {
    if (!mounted || _ended) return;
    final connected = peer.connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    if (connected) {
      _connectedPeers.add(key);
      if (!_hasConnectedPeer) {
        setState(() {
          _hasConnectedPeer = true;
          _error = null;
        });
        _startTimer();
      } else if (_error != null) {
        setState(() => _error = null);
      }
    } else if (peer.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        peer.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        peer.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      _connectedPeers.remove(key);
      if (_connectedPeers.isEmpty && mounted) {
        setState(() => _error = _hasConnectedPeer
            ? 'Connection lost. Trying to reconnect…'
            : 'Could not connect to the group call. Check your network.');
      }
    }
  }

  Future<void> _handleSignal(Map data) async {
    if (!_matchesCall(data) || _ended) return;
    final from = data['from']?.toString().trim() ?? '';
    if (from.isEmpty || from.toLowerCase() == _meKey) return;
    final signalValue = data['signal'];
    if (signalValue is! Map) return;
    final signal = Map<String, dynamic>.from(signalValue);
    final key = from.toLowerCase();
    _addParticipantRecord({'username': from, 'displayName': from});
    if (mounted) setState(() {});
    final peer = _peers[key];
    if (peer == null || _creatingPeers.contains(key)) {
      _pendingSignals.putIfAbsent(key, () => []).add(signal);
      await _ensurePeerConnection(from);
      return;
    }
    await _applySignal(peer, from, signal);
  }

  Future<void> _applySignal(
    WebRTCService peer,
    String username,
    Map<String, dynamic> signal,
  ) async {
    switch (signal['type']?.toString()) {
      case 'offer':
        await peer.handleOffer(signal, _socket, username, widget.groupCallId);
        break;
      case 'answer':
        await peer.handleAnswer(signal);
        break;
      case 'candidate':
        await peer.handleIceCandidate(signal);
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _removePeer(String username) async {
    final key = username.trim().toLowerCase();
    final peer = _peers.remove(key);
    final listener = _peerListeners.remove(key);
    if (peer != null && listener != null) peer.removeListener(listener);
    _pendingSignals.remove(key);
    _creatingPeers.remove(key);
    _connectedPeers.remove(key);
    _remoteAudioEnabled.remove(key);
    _remoteVideoEnabled.remove(key);
    if (peer != null) await peer.dispose();
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _seconds.value++;
    });
  }

  Future<void> _retryConnection() async {
    if (_retrying ||
        _initializing ||
        _leaving ||
        _ended ||
        _creatingPeers.isNotEmpty ||
        !mounted) return;
    setState(() {
      _retrying = true;
      _error = 'Reconnecting to participants…';
    });
    try {
      if (_localStream == null) {
        setState(() {
          _initializing = true;
          _error = null;
        });
        final oldOwner = _mediaOwner;
        _mediaOwner = null;
        if (oldOwner != null) await oldOwner.dispose();
        if (WebRTC.platformIsAndroid) await AudioManagerService.resetMode();
        if (mounted && !_ended) await _initializeCall();
        return;
      }

      final oldPeers = _peers.entries.toList(growable: false);
      _peers.clear();
      _connectedPeers.clear();
      _pendingSignals.clear();
      for (final entry in oldPeers) {
        final listener = _peerListeners.remove(entry.key);
        if (listener != null) entry.value.removeListener(listener);
        await entry.value.dispose();
      }
      await _ensurePeerConnections();
      await Future<void>.delayed(const Duration(seconds: 8));
      if (mounted && !_ended && _connectedPeers.isEmpty) {
        setState(() =>
            _error = 'Still connecting. Check the network and try again.');
      }
    } catch (error) {
      if (mounted && !_ended) {
        setState(() => _error = 'Could not reconnect: ' + error.toString());
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _publishMediaState() {
    _socket.updateGroupCallMediaState(
      widget.groupCallId,
      audioEnabled: !_muted,
      videoEnabled: widget.isVideo && !_cameraOff,
    );
  }

  void _toggleMute() {
    if (_initializing || _leaving || _ended || _localStream == null) return;
    _muted = !_muted;
    _mediaOwner?.toggleMute(_muted);
    _publishMediaState();
    if (mounted) setState(() {});
    _publishActiveCallNotification();
    _refreshMiniOverlay();
  }

  void _toggleCamera() {
    if (!widget.isVideo || _initializing || _leaving || _ended || _localStream == null) return;
    _cameraOff = !_cameraOff;
    _mediaOwner?.toggleCamera(_cameraOff);
    _publishMediaState();
    if (mounted) setState(() {});
    _refreshMiniOverlay();
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera || _initializing || _leaving || _ended || _localStream == null) return;
    setState(() => _switchingCamera = true);
    try {
      await _mediaOwner?.switchCamera();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch camera: ' + error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_initializing || _leaving || _ended || _localStream == null ||
        _speakerRouteChanging) return;
    _speakerRouteChanging = true;
    final nextSpeakerOn = !_speakerOn;
    try {
      if (!WebRTC.platformIsAndroid) {
        await _mediaOwner?.toggleSpeaker(nextSpeakerOn);
      }
      final changed = WebRTC.platformIsAndroid
          ? await AudioManagerService.setAudioRoute(
              nextSpeakerOn ? 'speaker' : 'earpiece',
            )
          : true;
      if (!changed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not switch call audio device.')),
          );
        }
        return;
      }
      _speakerOn = nextSpeakerOn;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch call audio device: $error')),
        );
      }
      return;
    } finally {
      _speakerRouteChanging = false;
    }
    if (mounted) setState(() {});
    _publishActiveCallNotification();
    _refreshMiniOverlay();
  }

  void _handleNotificationCallAction(String actionId) {
    if (!mounted || _ended) return;
    switch (actionId) {
      case 'call_toggle_mute':
        _toggleMute();
        break;
      case 'call_toggle_speaker':
        unawaited(_toggleSpeaker());
        break;
      case 'call_end':
        unawaited(_leaveCall());
        break;
    }
  }

  void _publishActiveCallNotification() {
    if (_initializing || _ended || !mounted) return;
    unawaited(NotificationService.showActiveCallNotification(
      callId: widget.groupCallId,
      caller: 'Group (' + _participants.length.toString() + ')',
      isVideo: widget.isVideo,
      muted: _muted,
      speakerOn: _speakerOn,
    ));
  }

  Future<void> _toggleScreenShare() async {
    if (_screenShareBusy || _initializing || _leaving || _ended) return;
    if (_sharingScreen) {
      setState(() => _screenShareBusy = true);
      try {
        await _stopScreenShare();
      } finally {
        if (mounted) setState(() => _screenShareBusy = false);
      }
      return;
    }
    if (_screenSharer != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Someone is already sharing their screen.')),
      );
      return;
    }
    final owner = _mediaOwner;
    if (owner == null || _peers.isEmpty) return;
    setState(() => _screenShareBusy = true);
    try {
      final screen = await owner.captureScreenForGroup();
      _groupScreenStream = screen;
      for (final peer in _peers.values) {
        await peer.addSharedScreenStream(screen);
      }
      _sharingScreen = true;
      _screenSharer = _me;
      _showScreenFirst = true;
      _socket.updateGroupCallScreenShare(
        widget.groupCallId,
        widget.isVideo ? (_localStream?.id ?? screen.id) : screen.id,
        replacesVideoTrack: widget.isVideo,
      );
      screen.getVideoTracks().first.onEnded = () => unawaited(_stopScreenShare());
      if (mounted) setState(() {});
      _refreshMiniOverlay();
    } catch (error) {
      await _stopScreenShare();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share screen: ' + error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _screenShareBusy = false);
    }
  }

  Future<void> _stopScreenShare() async {
    if (!_sharingScreen && _groupScreenStream == null) return;
    final screen = _groupScreenStream;
    _groupScreenStream = null;
    _sharingScreen = false;
    for (final peer in _peers.values) {
      try {
        await peer.removeSharedScreenStream();
      } catch (_) {}
    }
    _socket.updateGroupCallScreenShare(widget.groupCallId, null);
    if (screen != null) {
      final owner = _mediaOwner;
      if (owner != null && identical(owner.localScreenStream, screen)) {
        await owner.releaseGroupScreenCapture();
      } else {
        for (final track in screen.getTracks()) {
          track.onEnded = null;
          try { await track.stop(); } catch (_) {}
        }
        try { await screen.dispose(); } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _screenSharer = null;
      });
    }
    _refreshMiniOverlay();
  }

  Future<void> _showInvitePicker() async {
    if (_inviting ||
        _participants.length + _pendingInvites.length >= _maxParticipants) return;
    if (_me.isEmpty) return;
    setState(() => _inviting = true);
    final friendService = context.read<FriendService>();
    final fallbackFriends = _socket.contacts.friends;
    List<UserModel> friends;
    try {
      friends = friendService.cachedFriends ?? fallbackFriends;
      if (friends.isEmpty) {
        friends = await friendService
            .friendsStream(_me)
            .first
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      friends = fallbackFriends;
    }
    if (!mounted) return;
    setState(() => _inviting = false);
    final existing = _participants.keys.toSet()
      ..add(_meKey)
      ..addAll(_pendingInvites.keys);
    final available = friends
        .where((person) => !existing.contains(person.username.toLowerCase()))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available contacts to add.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: Column(
            children: [
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add people',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      (_participants.length + _pendingInvites.length).toString() + '/' + _maxParticipants.toString(),
                      style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final friend = available[index];
                    return ListTile(
                      leading: UserAvatar(
                        name: friend.name,
                        photoUrl: friend.photoUrl,
                        radius: 22,
                      ),
                      title: Text(friend.name),
                      subtitle: Text('@' + friend.username),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final result = await _socket.inviteToGroupCall(
                          groupCallId: widget.groupCallId,
                          username: friend.username,
                        );
                        if (!mounted) return;
                        if (result['ok'] == true) {
                          setState(() {
                            _pendingInvites[friend.username.toLowerCase()] = {
                              'username': friend.username,
                              'displayName': friend.name,
                              'invitedBy': _me,
                              'expiresAt': result['expiresAt'],
                            };
                          });
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['ok'] == true
                                ? 'Ringing ' + friend.name + '…'
                                : (result['message']?.toString() ?? 'Could not send invitation.')),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveCall() async {
    if (_leaving || _ended) return;
    setState(() {
      _leaving = true;
      _ended = true;
    });
    _timer?.cancel();
    try {
      await _socket.leaveGroupCall(widget.groupCallId);
    } catch (_) {
      // Always release local media even when the network is already gone.
    }
    await _cleanup();
    CallOverlayService.hide();
    if (mounted) {
      final navigator = Navigator.of(context);
      final route = _callRoute;
      if (_isMinimized && route != null) {
        navigator.popUntil((candidate) => identical(candidate, route));
      }
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _finishFromServer(String reason) async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    CallOverlayService.hide();
    await _cleanup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason)),
    );
    final navigator = Navigator.of(context);
    final route = _callRoute;
    if (_isMinimized && route != null) {
      navigator.popUntil((candidate) => identical(candidate, route));
    }
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    _timer?.cancel();
    // Stop capture before closing peer connections so the microphone privacy
    // indicator does not linger while mesh connections are being torn down.
    await _mediaOwner?.stopLocalMediaCapture();
    NotificationService.setActiveCallActionHandler(null);
    unawaited(NotificationService.clearActiveCallNotification());
    final screen = _groupScreenStream;
    _groupScreenStream = null;
    if (screen != null) {
      for (final peer in _peers.values) {
        try { await peer.removeSharedScreenStream(); } catch (_) {}
      }
      final owner = _mediaOwner;
      if (owner != null && identical(owner.localScreenStream, screen)) {
        await owner.releaseGroupScreenCapture();
      } else {
        for (final track in screen.getTracks()) {
          track.onEnded = null;
          try { await track.stop(); } catch (_) {}
        }
        try { await screen.dispose(); } catch (_) {}
      }
    }
    final peers = _peers.values.toList();
    for (final entry in _peers.entries) {
      final listener = _peerListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
    }
    _peerListeners.clear();
    _connectedPeers.clear();
    _peers.clear();
    for (final peer in peers) {
      await peer.dispose();
    }
    await _mediaOwner?.dispose();
    _mediaOwner = null;
    _localStream = null;
    await CallPlatformService.setCallActive(false);
    if (WebRTC.platformIsAndroid) await AudioManagerService.resetMode();
  }

  WebRTCService? _firstRemoteVideoService() {
    for (final peer in _peers.values) {
      if (peer.hasRemoteVideo) return peer;
    }
    return null;
  }

  Widget _buildParticipantGrid() {
    final people = _participantList.take(_maxParticipants).toList(growable: false);
    final count = people.length.clamp(1, _maxParticipants).toInt();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = GroupCallGridSpec.columnsFor(
          participantCount: count,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        final aspectRatio = GroupCallGridSpec.aspectRatioFor(
          participantCount: count,
          columns: columns,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        if (count == 3 && columns == 2) {
          final tileWidth = ((constraints.maxWidth - 24 - 10) / 2)
              .clamp(1.0, double.infinity)
              .toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildParticipantTile(people[0])),
                      const SizedBox(width: 10),
                      Expanded(child: _buildParticipantTile(people[1])),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: tileWidth,
                      child: _buildParticipantTile(people[2]),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => _buildParticipantTile(people[index]),
        );
      },
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final username = participant['username']?.toString() ?? '';
    final key = username.toLowerCase();
    final isMe = key == _meKey;
    final service = _peers[key];
    final videoEnabled = widget.isVideo &&
        (isMe ? !_cameraOff : (_remoteVideoEnabled[key] != false));
    final audioMuted = isMe ? _muted : (_remoteAudioEnabled[key] == false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final avatarRadius = (shortestSide * .22).clamp(22.0, 46.0).toDouble();
        final compact = shortestSide < 150;
        Widget video;
        if (!videoEnabled) {
          video = _avatarFor(participant, radius: avatarRadius);
        } else if (isMe && _mediaOwner?.localStream != null) {
          video = RTCVideoView(
            _mediaOwner!.localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        } else if (!isMe &&
            key == _screenSharer?.toLowerCase() &&
            service != null &&
            service.remoteScreenRenderer.srcObject != null &&
            identical(
              service.remoteScreenRenderer.srcObject,
              service.remoteRenderer.srcObject,
            )) {
          // When the camera sender is replaced by the display track, don't
          // render the same shared screen again as the participant's camera.
          video = _avatarFor(participant, radius: avatarRadius);
        } else if (!isMe && service?.hasRemoteVideo == true) {
          video = RTCVideoView(
            service!.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        } else {
          video = _avatarFor(participant, radius: avatarRadius);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 16 : 22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF25283A), child: video),
              Positioned(
                left: compact ? 7 : 10,
                right: compact ? 7 : 10,
                bottom: compact ? 7 : 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMe ? 'You' : (participant['displayName']?.toString() ?? username),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (audioMuted)
                      Icon(Icons.mic_off_rounded, color: Colors.white, size: compact ? 13 : 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarFor(
    Map<String, dynamic> participant, {
    double radius = 38,
  }) =>
      Container(
        color: const Color(0xFF25283A),
        child: Center(
          child: UserAvatar(
            name: participant['displayName']?.toString() ??
                participant['username']?.toString() ?? '?',
            photoUrl: participant['photoUrl']?.toString() ?? '',
            radius: radius,
          ),
        ),
      );

  Widget _buildScreenShareArea() {
    // Never place the local capture renderer back into the captured screen.
    // Doing so creates an infinite hall-of-mirrors feedback loop for the
    // sharer and can flood the outgoing video track with repeated UI frames.
    if (_screenSharer?.toLowerCase() == _meKey) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildParticipantGrid(),
          Positioned(
            left: 12,
            top: 12,
            child: _GroupTag(
              icon: Icons.screen_share_rounded,
              text: 'You are sharing your screen',
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenRenderer =
            _peers[_screenSharer?.toLowerCase()]?.remoteScreenRenderer;
        final screenView = screenRenderer?.srcObject == null
            ? const Center(
                child: Text('Connecting shared screen…', style: TextStyle(color: Colors.white70)),
              )
            : RTCVideoView(
                screenRenderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              );
        final miniWidth = constraints.maxWidth < 240
            ? constraints.maxWidth * .30
            : (constraints.maxWidth * .30).clamp(88.0, 156.0).toDouble();
        final miniHeight = constraints.maxHeight < 200
            ? constraints.maxHeight * .38
            : (constraints.maxHeight * .38).clamp(104.0, 184.0).toDouble();

        if (!_showScreenFirst) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildParticipantGrid()),
              Positioned(
                right: 10,
                top: 10,
                width: miniWidth,
                height: miniHeight,
                child: GestureDetector(
                  onTap: () => setState(() => _showScreenFirst = true),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(color: const Color(0xFF171927), child: screenView),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _GroupTag(
                  icon: Icons.screen_share_rounded,
                  text: 'Screen shared',
                ),
              ),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF080A12), child: screenView),
            Positioned(
              top: 10,
              right: 10,
              width: miniWidth,
              height: miniHeight,
              child: GestureDetector(
                onTap: () => setState(() => _showScreenFirst = false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildParticipantTile({
                    'username': _me,
                    'displayName': 'You',
                  }),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GroupTag(
                    icon: Icons.screen_share_rounded,
                    text: _screenSharer?.toLowerCase() == _meKey
                        ? 'You are sharing'
                        : (_screenSharer ?? 'Participant') + ' is sharing',
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.black.withValues(alpha: .56),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _showScreenFirst = false),
                      icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                      tooltip: 'Show participants',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleControlsTray() {
    setState(() => _controlsExpanded = !_controlsExpanded);
  }

  Widget _buildControls() {
    final mediaReady = !_initializing && !_leaving && !_ended && _localStream != null;
    final canInvite = mediaReady &&
        _participants.length + _pendingInvites.length < _maxParticipants &&
        !_inviting;
    final canShare = mediaReady &&
        !_screenShareBusy &&
        (_sharingScreen || (_screenSharer == null && _peers.isNotEmpty));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -140 && !_controlsExpanded) {
          setState(() => _controlsExpanded = true);
        } else if (velocity > 140 && _controlsExpanded) {
          setState(() => _controlsExpanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 13),
        decoration: BoxDecoration(
          color: const Color(0xDD151525),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControlsTray,
              child: SizedBox(
                width: double.infinity,
                height: 18,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .48),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _controlsExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 9, bottom: 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GroupTrayActionTile(
                              icon: _switchingCamera
                                  ? Icons.hourglass_top_rounded
                                  : Icons.flip_camera_android_rounded,
                              label: 'Switch camera',
                              onTap: _switchCamera,
                              disabled: !widget.isVideo || !mediaReady || _switchingCamera,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _GroupTrayActionTile(
                              icon: _screenShareBusy
                                  ? Icons.hourglass_top_rounded
                                  : (_sharingScreen
                                      ? Icons.stop_screen_share_rounded
                                      : Icons.screen_share_rounded),
                              label: _sharingScreen ? 'Stop sharing' : 'Share screen',
                              onTap: _toggleScreenShare,
                              active: _sharingScreen,
                              disabled: !widget.isVideo || !canShare,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _GroupTrayActionTile(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Add people',
                              onTap: _showInvitePicker,
                              active: _inviting,
                              disabled: !canInvite,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _GroupDockButton(
                  icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _muted ? 'Unmute microphone' : 'Mute microphone',
                  onTap: _toggleMute,
                  active: _muted,
                  disabled: !mediaReady,
                ),
                _GroupDockButton(
                  icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: _cameraOff ? 'Turn camera on' : 'Turn camera off',
                  onTap: _toggleCamera,
                  active: _cameraOff,
                  disabled: !widget.isVideo || !mediaReady,
                ),
                _GroupDockButton(
                  icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: _speakerOn ? 'Speaker on' : 'Speaker off',
                  onTap: _toggleSpeaker,
                  active: _speakerOn,
                  disabled: !mediaReady || _speakerRouteChanging,
                ),
                _GroupDockButton(
                  icon: _leaving ? Icons.hourglass_top_rounded : Icons.call_end_rounded,
                  label: 'Leave group call',
                  onTap: _leaveCall,
                  danger: true,
                  disabled: _leaving || _ended,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _refreshMiniOverlay() {
    if (_isMinimized) CallOverlayService.show(_buildMiniOverlay());
  }

  void _minimizeCall() {
    if (_isMinimized || _ended || !mounted) return;
    setState(() => _isMinimized = true);
    CallOverlayService.show(_buildMiniOverlay());
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, __, ___) => MainScreen(
          managePresence: false,
          onCallHostExit: _onMinimizedHostDisposed,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
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
    CallOverlayService.hide();
    setState(() => _isMinimized = false);
  }

  void _expandCall() {
    if (!mounted) return;
    CallOverlayService.hide();
    setState(() => _isMinimized = false);
    final route = _callRoute;
    if (route != null) {
      Navigator.of(context).popUntil((candidate) => identical(candidate, route));
    }
  }

  Widget _buildMiniOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 300
            ? constraints.maxWidth * .44
            : (constraints.maxWidth * .44).clamp(132.0, 166.0).toDouble();
        final height = constraints.maxHeight < 200
            ? constraints.maxHeight * .74
            : (constraints.maxHeight * .74).clamp(148.0, 224.0).toDouble();
        final maxX = (constraints.maxWidth - width - 8)
            .clamp(0.0, double.infinity).toDouble();
        final maxY = (constraints.maxHeight - height - 8)
            .clamp(0.0, double.infinity).toDouble();
        final minX = maxX < 4 ? maxX : 4.0;
        final minY = maxY < 24 ? maxY : 24.0;
        _miniPosition ??= Offset(maxX, maxY * .45);
        final position = Offset(
          _miniPosition!.dx.clamp(minX, maxX).toDouble(),
          _miniPosition!.dy.clamp(minY, maxY).toDouble(),
        );
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              width: width,
              height: height,
              child: Material(
                color: const Color(0xFF171927),
                elevation: 18,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          _miniPosition = Offset(
                            (position.dx + details.delta.dx).clamp(minX, maxX).toDouble(),
                            (position.dy + details.delta.dy).clamp(minY, maxY).toDouble(),
                          );
                          CallOverlayService.show(_buildMiniOverlay());
                        },
                        child: InkWell(
                          onTap: _expandCall,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _miniVideo(),
                              Positioned(
                                left: 9,
                                top: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    child: Text(
                                      _participants.length.toString() + '/' + _maxParticipants.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 9,
                                top: 8,
                                child: Icon(Icons.open_in_full_rounded, color: Colors.white, size: 17),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MiniAction(
                            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            onTap: () {
                              _toggleMute();
                              _refreshMiniOverlay();
                            },
                          ),
                          _MiniAction(
                            icon: Icons.open_in_full_rounded,
                            onTap: _expandCall,
                          ),
                          _MiniAction(
                            icon: Icons.call_end_rounded,
                            color: const Color(0xFFE84B58),
                            onTap: _leaveCall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniVideo() {
    final screenSharerKey = _screenSharer?.toLowerCase();
    if (screenSharerKey != null && screenSharerKey != _meKey) {
      final screen = _peers[screenSharerKey]?.remoteScreenRenderer;
      if (screen?.srcObject != null) {
        return RTCVideoView(
          screen!,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        );
      }
    }
    final remote = _firstRemoteVideoService();
    if (remote != null && remote.hasRemoteVideo) {
      return RTCVideoView(
        remote.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    return Container(
      color: const Color(0xFF25283A),
      child: Center(child: UserAvatar(name: _me, photoUrl: '', radius: 36)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _participantList;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _minimizeCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0E18),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _minimizeCall,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isVideo ? 'Group video call' : 'Group voice call',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _initializing
                                ? 'Preparing call…'
                                : _connectedPeers.isEmpty
                                    ? 'Connecting audio…'
                                    : _connectedPeers.length.toString() + ' connected · ' +
                                        names.length.toString() + '/' + _maxParticipants.toString() + ' participants',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _seconds,
                      builder: (context, value, _) => Text(
                        _formatDuration(value),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFFFA5AA), fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _initializing ||
                                _leaving ||
                                _retrying ||
                                _creatingPeers.isNotEmpty
                            ? null
                            : _retryConnection,
                        child: Text(_retrying ? 'Retrying…' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              if (_pendingInvites.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: _pendingInvites.values.map((invite) {
                      final name = invite['displayName']?.toString().trim().isNotEmpty == true
                          ? invite['displayName'].toString()
                          : invite['username']?.toString() ?? 'Contact';
                      return Chip(
                        avatar: const Icon(Icons.ring_volume_rounded, size: 15),
                        label: Text('Ringing ' + name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(growable: false),
                  ),
                ),
              Expanded(
                child: _screenSharer != null
                    ? _buildScreenShareArea()
                    : _buildParticipantGrid(),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes.toString().padLeft(2, '0') + ':' +
        remainder.toString().padLeft(2, '0');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _seconds.dispose();
    CallOverlayService.hide();
    _socket.onGroupCallSignalCallback = null;
    _socket.onGroupCallParticipantJoinedCallback = null;
    _socket.onGroupCallParticipantLeftCallback = null;
    _socket.onGroupCallEndedCallback = null;
    _socket.onGroupCallMediaStateCallback = null;
    _socket.onGroupCallScreenShareStateCallback = null;
    _socket.onGroupCallInvitationDeclinedCallback = null;
    _socket.onGroupCallInvitationExpiredCallback = null;
    _socket.onGroupCallScreenShareDeniedCallback = null;
    if (!_ended && !_leaving) {
      unawaited(_socket.leaveGroupCall(widget.groupCallId));
    }
    unawaited(_cleanup());
    super.dispose();
  }
}

class _GroupTrayActionTile extends StatelessWidget {
  const _GroupTrayActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? .42 : 1,
      child: Material(
        color: active ? const Color(0xFF514A78) : const Color(0x3DFFFFFF),
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: disabled ? null : onTap,
          child: SizedBox(
            height: 86,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 25),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupDockButton extends StatelessWidget {
  const _GroupDockButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.active = false,
    this.danger = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? const Color(0xFFE53935)
        : active
            ? const Color(0xFF128C7E)
            : const Color(0xFF303238);
    const foreground = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: Tooltip(
          message: label,
          child: Semantics(
            button: true,
            enabled: !disabled,
            label: label,
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: disabled ? null : onTap,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Icon(icon, color: foreground, size: 23),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupTag extends StatelessWidget {
  const _GroupTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .56),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.onTap, this.color = Colors.white});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
      );
}
