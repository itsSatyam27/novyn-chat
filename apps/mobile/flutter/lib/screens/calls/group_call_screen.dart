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
import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/user_avatar.dart';
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
  });

  final String groupCallId;
  final String callId;
  final bool isVideo;
  final List<Map<String, dynamic>> participants;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  static const int _maxParticipants = 4;

  late final SocketService _socket;
  final Map<String, Map<String, dynamic>> _participants = {};
  final Map<String, WebRTCService> _peers = {};
  final Set<String> _creatingPeers = {};
  final Map<String, List<Map<String, dynamic>>> _pendingSignals = {};
  final Map<String, bool> _remoteAudioEnabled = {};
  final Map<String, bool> _remoteVideoEnabled = {};

  WebRTCService? _mediaOwner;
  MediaStream? _localStream;
  MediaStream? _groupScreenStream;
  String _me = '';
  String? _screenSharer;
  String? _screenStreamId;
  bool _showScreenFirst = true;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _sharingScreen = false;
  bool _initializing = true;
  bool _leaving = false;
  bool _ended = false;
  bool _cleaned = false;
  bool _isMinimized = false;
  bool _inviting = false;
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
    _addParticipantRecord({
      'username': _me,
      'displayName': context.read<AuthService>().user?.name ?? _me,
    });
    _bindSocket();
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
      _applyParticipantSnapshot(data['participants']);
    };
    _socket.onGroupCallParticipantLeftCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['participant']?.toString().trim() ?? '';
      if (username.isNotEmpty) unawaited(_removePeer(username));
      _applyParticipantSnapshot(data['participants']);
    };
    _socket.onGroupCallEndedCallback = (data) {
      if (!_matchesCall(data)) return;
      unawaited(_finishFromServer(
        data['reason']?.toString() ?? 'The group call has ended.',
      ));
    };
    _socket.onGroupCallMediaStateCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['username']?.toString().toLowerCase() ?? '';
      if (username.isEmpty) return;
      setState(() {
        _remoteAudioEnabled[username] = data['audioEnabled'] != false;
        _remoteVideoEnabled[username] = data['videoEnabled'] != false;
      });
    };
    _socket.onGroupCallScreenShareStateCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['username']?.toString().trim() ?? '';
      final streamId = data['streamId']?.toString();
      setState(() {
        _screenSharer = streamId == null || streamId.isEmpty ? null : username;
        _screenStreamId = streamId;
        _showScreenFirst = true;
      });
      for (final peer in _peers.values) {
        peer.setRemoteScreenShare(streamId);
      }
    };
    _socket.onGroupCallInvitationDeclinedCallback = (data) {
      if (!_matchesCall(data)) return;
      final username = data['username']?.toString() ?? 'Someone';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(username + ' declined the invitation.')),
        );
      }
    };
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
    unawaited(_ensurePeerConnections());
  }

  Future<void> _initializeCall() async {
    try {
      // The outgoing 1:1 route is replaced during promotion. Give its camera
      // and microphone handles time to close before opening the mesh stream.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted || _ended) return;
      final owner = WebRTCService();
      _mediaOwner = owner;
      await owner.init();
      await owner.setEarpieceMode();
      await owner.startLocalStream(video: widget.isVideo);
      _localStream = owner.localStream;
      if (_localStream == null) {
        throw StateError('Could not start the microphone or camera.');
      }
      await Helper.setSpeakerphoneOn(widget.isVideo);
      _speakerOn = widget.isVideo;
      if (mounted) setState(() => _initializing = false);
      _startTimer();
      await _ensurePeerConnections();
      _publishMediaState();
    } catch (error) {
      if (!mounted) return;
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
        !_creatingPeers.add(key) ||
        _localStream == null ||
        _ended) {
      return;
    }

    final peer = WebRTCService();
    _peers[key] = peer;
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
      final queued = _pendingSignals.remove(key) ?? const [];
      for (final signal in queued) {
        await _applySignal(peer, username, signal);
      }
    } catch (error) {
      _peers.remove(key);
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
    _pendingSignals.remove(key);
    _creatingPeers.remove(key);
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

  void _publishMediaState() {
    _socket.updateGroupCallMediaState(
      widget.groupCallId,
      audioEnabled: !_muted,
      videoEnabled: widget.isVideo && !_cameraOff,
    );
  }

  void _toggleMute() {
    _muted = !_muted;
    _mediaOwner?.toggleMute(_muted);
    _publishMediaState();
    if (mounted) setState(() {});
  }

  void _toggleCamera() {
    if (!widget.isVideo) return;
    _cameraOff = !_cameraOff;
    _mediaOwner?.toggleCamera(_cameraOff);
    _publishMediaState();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    try {
      await _mediaOwner?.switchCamera();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch camera: ' + error.toString())),
        );
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await Helper.setSpeakerphoneOn(_speakerOn);
    if (mounted) setState(() {});
  }

  Future<void> _toggleScreenShare() async {
    if (_sharingScreen) {
      await _stopScreenShare();
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
    try {
      final screen = await owner.captureScreenForGroup();
      _groupScreenStream = screen;
      for (final peer in _peers.values) {
        await peer.addSharedScreenStream(screen);
      }
      _sharingScreen = true;
      _screenSharer = _me;
      _screenStreamId = screen.id;
      _showScreenFirst = true;
      _socket.updateGroupCallScreenShare(widget.groupCallId, screen.id);
      screen.getVideoTracks().first.onEnded = () => unawaited(_stopScreenShare());
      if (mounted) setState(() {});
    } catch (error) {
      await _stopScreenShare();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share screen: ' + error.toString())),
        );
      }
    }
  }

  Future<void> _stopScreenShare() async {
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
        _screenStreamId = null;
      });
    }
  }

  Future<void> _showInvitePicker() async {
    if (_inviting || _participants.length >= _maxParticipants) return;
    if (_me.isEmpty) return;
    setState(() => _inviting = true);
    List<UserModel> friends;
    try {
      final service = context.read<FriendService>();
      friends = service.cachedFriends ?? _socket.contacts.friends;
      if (friends.isEmpty) {
        friends = await service
            .friendsStream(_me)
            .first
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      friends = _socket.contacts.friends;
    }
    if (!mounted) return;
    setState(() => _inviting = false);
    final existing = _participants.keys.toSet()..add(_meKey);
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
                      _participants.length.toString() + '/' + _maxParticipants.toString(),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['ok'] == true
                                ? 'Invitation sent to ' + friend.name + '.'
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
    setState(() => _leaving = true);
    await _socket.leaveGroupCall(widget.groupCallId);
    await _cleanup();
    _ended = true;
    _timer?.cancel();
    CallOverlayService.hide();
    if (mounted) Navigator.of(context).pop();
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
    final screen = _groupScreenStream;
    _groupScreenStream = null;
    if (screen != null) {
      for (final peer in _peers.values) {
        try { await peer.removeSharedScreenStream(); } catch (_) {}
      }
      for (final track in screen.getTracks()) {
        track.onEnded = null;
        try { await track.stop(); } catch (_) {}
      }
      try { await screen.dispose(); } catch (_) {}
    }
    final peers = _peers.values.toList();
    _peers.clear();
    for (final peer in peers) {
      await peer.dispose();
    }
    await _mediaOwner?.dispose();
    _mediaOwner = null;
    _localStream = null;
    await CallPlatformService.setCallActive(false);
    await AudioManagerService.resetMode();
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
        const width = 166.0;
        const height = 224.0;
        final maxX = (constraints.maxWidth - width - 8).clamp(0.0, double.infinity).toDouble();
        final maxY = (constraints.maxHeight - height - 32).clamp(0.0, double.infinity).toDouble();
        _miniPosition ??= Offset(maxX, maxY * .45);
        final position = Offset(
          _miniPosition!.dx.clamp(4.0, maxX).toDouble(),
          _miniPosition!.dy.clamp(24.0, maxY).toDouble(),
        );
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              width: width,
              height: height,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _miniPosition = Offset(
                      (position.dx + details.delta.dx).clamp(4.0, maxX).toDouble(),
                      (position.dy + details.delta.dy).clamp(24.0, maxY).toDouble(),
                    );
                    CallOverlayService.show(_buildMiniOverlay());
                  });
                },
                child: Material(
                  color: const Color(0xFF171927),
                  elevation: 18,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
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
                              Positioned(
                                right: 9,
                                top: 8,
                                child: Icon(Icons.open_in_full_rounded, color: Colors.white.withValues(alpha: .85), size: 17),
                              ),
                            ],
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
                              onTap: _toggleMute,
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
            ),
          ],
        );
      },
    );
  }

  Widget _miniVideo() {
    if (_screenSharer?.toLowerCase() == _meKey &&
        _mediaOwner?.localScreenRenderer.srcObject != null) {
      return RTCVideoView(
        _mediaOwner!.localScreenRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    }
    final remote = _firstRemoteVideoService();
    if (remote != null && remote.remoteStream != null) {
      return RTCVideoView(
        remote.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    return Container(
      color: const Color(0xFF25283A),
      child: Center(
        child: UserAvatar(name: _me, photoUrl: '', radius: 36),
      ),
    );
  }

  WebRTCService? _firstRemoteVideoService() {
    for (final peer in _peers.values) {
      if (peer.remoteStream != null) return peer;
    }
    return null;
  }

  Widget _buildParticipantGrid() {
    final people = _participantList;
    final count = people.length.clamp(1, _maxParticipants);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: count == 1 ? 1.1 : .82,
      ),
      itemBuilder: (context, index) => _buildParticipantTile(people[index]),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final username = participant['username']?.toString() ?? '';
    final key = username.toLowerCase();
    final isMe = key == _meKey;
    final service = _peers[key];
    final videoEnabled = isMe ? !_cameraOff : (_remoteVideoEnabled[key] != false);
    Widget video;
    if (!videoEnabled) {
      video = _avatarFor(participant);
    } else if (isMe && _mediaOwner?.localStream != null) {
      video = RTCVideoView(
        _mediaOwner!.localRenderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else if (!isMe && service?.remoteStream != null) {
      video = RTCVideoView(
        service!.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      video = _avatarFor(participant);
    }

    final audioMuted = isMe ? _muted : (_remoteAudioEnabled[key] == false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF25283A), child: video),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isMe ? 'You' : (participant['displayName']?.toString() ?? username),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (audioMuted)
                  const Icon(Icons.mic_off_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFor(Map<String, dynamic> participant) => Container(
        color: const Color(0xFF25283A),
        child: Center(
          child: UserAvatar(
            name: participant['displayName']?.toString() ??
                participant['username']?.toString() ?? '?',
            photoUrl: participant['photoUrl']?.toString() ?? '',
            radius: 38,
          ),
        ),
      );

  Widget _buildScreenShareArea() {
    RTCVideoRenderer? screenRenderer;
    if (_screenSharer?.toLowerCase() == _meKey) {
      screenRenderer = _mediaOwner?.localScreenRenderer;
    } else {
      screenRenderer = _peers[_screenSharer?.toLowerCase()]?.remoteScreenRenderer;
    }
    final screenView = screenRenderer?.srcObject == null
        ? const Center(
            child: Text('Connecting shared screen…', style: TextStyle(color: Colors.white70)),
          )
        : RTCVideoView(
            screenRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          );

    if (!_showScreenFirst) {
      return Stack(
        children: [
          Positioned.fill(child: _buildParticipantGrid()),
          Positioned(
            right: 12,
            top: 12,
            width: 112,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(color: const Color(0xFF171927), child: screenView),
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
          top: 12,
          right: 12,
          width: 106,
          height: 154,
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
          left: 12,
          top: 12,
          child: _GroupTag(
            icon: Icons.screen_share_rounded,
            text: _screenSharer?.toLowerCase() == _meKey
                ? 'You are sharing'
                : (_screenSharer ?? 'Participant') + ' is sharing',
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE8171928),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _GroupControl(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Add',
            onTap: _showInvitePicker,
            disabled: _participants.length >= _maxParticipants || _inviting,
          ),
          _GroupControl(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: 'Mute',
            active: _muted,
            onTap: _toggleMute,
          ),
          if (widget.isVideo) ...[
            _GroupControl(
              icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: 'Camera',
              active: _cameraOff,
              onTap: _toggleCamera,
            ),
            _GroupControl(
              icon: Icons.flip_camera_android_rounded,
              label: 'Flip',
              onTap: _switchCamera,
            ),
          ],
          _GroupControl(
            icon: _sharingScreen ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
            label: _sharingScreen ? 'Stop' : 'Share',
            active: _sharingScreen,
            disabled: !_sharingScreen && _screenSharer != null,
            onTap: _toggleScreenShare,
          ),
          _GroupControl(
            icon: _speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: 'Speaker',
            active: _speakerOn,
            onTap: _toggleSpeaker,
          ),
          _GroupControl(
            icon: Icons.call_end_rounded,
            label: 'Leave',
            danger: true,
            onTap: _leaveCall,
          ),
        ],
      ),
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
                                ? 'Connecting…'
                                : names.length.toString() + '/' + _maxParticipants.toString() + ' participants',
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
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFFA5AA), fontSize: 12)),
                ),
              Expanded(
                child: _initializing
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : (_screenSharer != null
                        ? _buildScreenShareArea()
                        : _buildParticipantGrid()),
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
    if (!_ended && !_leaving) {
      unawaited(_socket.leaveGroupCall(widget.groupCallId));
    }
    unawaited(_cleanup());
    super.dispose();
  }
}

class _GroupControl extends StatelessWidget {
  const _GroupControl({
    required this.icon,
    required this.label,
    required this.onTap,
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
        ? const Color(0xFFE63C4B)
        : active
            ? Colors.white
            : Colors.white.withValues(alpha: .10);
    final foreground = danger
        ? Colors.white
        : active
            ? const Color(0xFF151722)
            : Colors.white;
    return Opacity(
      opacity: disabled ? .35 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: SizedBox(
            width: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                  child: Icon(icon, color: foreground, size: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
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
