import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'backend_contacts.dart';
import 'socket_service.dart';

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final UserModel? fromUser;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
    this.fromUser,
  });
}

class FriendSearchResult {
  final UserModel user;
  final String requestStatus;
  final bool canRequest;

  const FriendSearchResult({
    required this.user,
    required this.requestStatus,
    required this.canRequest,
  });
}

/// Contact operations backed by the same authenticated Novyn account as web.
class FriendService {
  final SocketService _socket;
  List<UserModel>? _cachedFriends;
  String? _cacheOwner;
  bool _cacheLoaded = false;

  FriendService(this._socket) {
    _socket.contacts.addListener(_handleContactsChanged);
  }

  List<UserModel>? get cachedFriends => _cachedFriends;

  /// Attach the durable cache to the signed-in account before the Contacts
  /// tab is opened. This ensures a friend-list snapshot received at login is
  /// persisted even when the user never visits Contacts while online.
  void activateAccount(String username) {
    final owner = username.trim().toLowerCase();
    if (owner.isEmpty) return;
    final ownerChanged = owner != _cacheOwner;
    _activateCacheOwner(owner);

    if (_hasLiveSnapshotFor(owner)) {
      _cachedFriends = List<UserModel>.from(_socket.contacts.friends);
      unawaited(_persistFriends(owner, _cachedFriends!));
    }
    if (ownerChanged || !_cacheLoaded) {
      unawaited(_loadCachedFriends(owner));
    }
  }

  static String _cacheKey(String username) =>
      'novyn_contacts_cache_v1_${username.trim().toLowerCase()}';

  void _activateCacheOwner(String username) {
    final owner = username.trim().toLowerCase();
    if (owner.isEmpty || owner == _cacheOwner) return;
    _cacheOwner = owner;
    _cachedFriends = null;
    _cacheLoaded = false;
  }

  Future<void> _loadCachedFriends(String owner) async {
    _activateCacheOwner(owner);
    if (_cacheLoaded || _cacheOwner != owner) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(owner));
      final decoded = raw == null ? const <dynamic>[] : jsonDecode(raw);
      final restored = decoded is List
          ? decoded.whereType<Map>().map(_userFromCache).whereType<UserModel>().toList()
          : <UserModel>[];
      if (_cacheOwner == owner && !_socket.contacts.hasAuthoritativeFriendSnapshot) {
        _cachedFriends = restored;
      }
    } catch (error) {
      debugPrint('[NovynContacts] Offline cache read failed: $error');
      if (_cacheOwner == owner && !_socket.contacts.hasAuthoritativeFriendSnapshot) {
        _cachedFriends ??= <UserModel>[];
      }
    } finally {
      if (_cacheOwner == owner) _cacheLoaded = true;
    }
  }

  UserModel? _userFromCache(Map value) {
    final username = value['username']?.toString().trim() ?? '';
    if (username.isEmpty) return null;
    final name = value['name']?.toString() ?? username;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return UserModel(
      uid: value['uid']?.toString().isNotEmpty == true
          ? value['uid'].toString()
          : username,
      username: username,
      name: name,
      email: '',
      bio: value['bio']?.toString() ?? '',
      age: value['age'] is num ? (value['age'] as num).toInt() : null,
      gender: value['gender']?.toString() ?? '',
      createdAt: createdAt,
      isOnline: false,
      status: 'offline',
      lastSeen: DateTime.tryParse(value['lastSeen']?.toString() ?? ''),
      photoUrl: value['photoUrl']?.toString() ?? '',
    );
  }

  bool _hasLiveSnapshotFor(String owner) =>
      _socket.myUsername?.trim().toLowerCase() == owner &&
      _socket.contacts.hasAuthoritativeFriendSnapshot;

  void _handleContactsChanged() {
    final owner = _cacheOwner;
    if (owner == null || !_hasLiveSnapshotFor(owner)) return;
    _cachedFriends = List<UserModel>.from(_socket.contacts.friends);
    unawaited(_persistFriends(owner, _cachedFriends!));
  }

  Future<void> _persistFriends(String owner, List<UserModel> friends) async {
    if (_cacheOwner != owner) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = friends.map((user) => <String, dynamic>{
        'uid': user.uid,
        'username': user.username,
        'name': user.name,
        'bio': user.bio,
        'age': user.age,
        'gender': user.gender,
        'createdAt': user.createdAt.toIso8601String(),
        'lastSeen': user.lastSeen?.toIso8601String(),
        'photoUrl': user.photoUrl,
      }).toList();
      await prefs.setString(_cacheKey(owner), jsonEncode(payload));
    } catch (error) {
      debugPrint('[NovynContacts] Offline cache write failed: $error');
    }
  }

  void dispose() {
    _socket.contacts.removeListener(_handleContactsChanged);
  }

  Stream<T> _watch<T>(T Function() read, {VoidCallback? onListen}) {
    return Stream<T>.multi((controller) {
      void emit() => controller.add(read());
      _socket.contacts.addListener(emit);
      controller.onCancel = () => _socket.contacts.removeListener(emit);
      emit();
      onListen?.call();
    });
  }

  Stream<List<UserModel>> friendsStream(String myUid) {
    final owner = myUid.trim().toLowerCase();
    _activateCacheOwner(owner);
    return Stream<List<UserModel>>.multi((controller) {
      void emit() {
        final hasLiveSnapshot = _hasLiveSnapshotFor(owner);
        if (hasLiveSnapshot) {
          _cachedFriends = List<UserModel>.from(_socket.contacts.friends);
          unawaited(_persistFriends(owner, _cachedFriends!));
        }
        final source = hasLiveSnapshot
            ? _socket.contacts.friends
            : (_cachedFriends ?? _socket.contacts.friends);
        controller.add(List<UserModel>.from(source));
      }

      _socket.contacts.addListener(emit);
      controller.onCancel = () => _socket.contacts.removeListener(emit);
      emit();
      unawaited(_loadCachedFriends(owner).then((_) => emit()));
    });
  }

  Stream<List<String>> friendUidsStream(String myUid) {
    return _watch(
        () => _socket.contacts.friends.map((user) => user.username).toList());
  }

  Stream<int> pendingRequestsCountStream(String myUid) {
    return _watch(() => _socket.contacts.requests.length);
  }

  Stream<List<FriendRequest>> pendingRequestsStream(String myUid) {
    return _watch(() => _socket.contacts.requests.map((username) {
          final user = _socket.contacts.findUser(username) ??
              BackendContacts.userFromMap({'username': username});
          return FriendRequest(
            id: username,
            fromUid: username,
            toUid: myUid,
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            fromUser: user,
          );
        }).toList());
  }

  Stream<List<UserModel>> discoverUsersStream(
    String myUid,
    List<String> friendUids,
  ) {
    return _watch(
      () => _socket.contacts.discovered
          .where((user) =>
              user.username.toLowerCase() != myUid.toLowerCase() &&
              !friendUids.any(
                (uid) => uid.toLowerCase() == user.username.toLowerCase(),
              ))
          .toList(),
      onListen: _socket.requestDiscover,
    );
  }

  Stream<Set<String>> sentPendingUidsStream(String myUid) {
    return _watch(() => Set<String>.from(_socket.contacts.sentRequests));
  }

  Future<void> sendRequest(String fromUid, String toUid) {
    return _socket.sendFriendRequest(toUid);
  }

  Future<void> cancelSentRequest(String username) {
    return _socket.cancelFriendRequest(username);
  }

  Future<void> acceptRequest(
      String requestId, String myUid, String otherUid) async {
    await _socket.acceptFriendRequest(otherUid);
  }

  Future<void> declineRequest(String requestId) async {
    await _socket.rejectFriendRequest(requestId);
  }

  Future<void> removeFriend(String myUid, String otherUid) async {
    _socket.removeFriend(otherUid);
    _cachedFriends?.removeWhere((user) => user.username == otherUid);
    final owner = _cacheOwner;
    if (owner != null && _cachedFriends != null) {
      unawaited(_persistFriends(owner, _cachedFriends!));
    }
  }

  void updateCachedStatus(String username, bool isOnline) {
    _socket.contacts.updateStatus(username, isOnline);
    final friends = _cachedFriends;
    if (friends == null) return;
    final index = friends.indexWhere(
      (user) => user.username.toLowerCase() == username.toLowerCase(),
    );
    if (index != -1) {
      friends[index] = friends[index].copyWith(isOnline: isOnline);
    }
  }

  Future<List<FriendSearchResult>> searchUsers(String query) async {
    final normalized = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (normalized.isEmpty) return [];

    final matches = await ApiService.searchUsers(normalized);
    return matches
        .map((result) => FriendSearchResult(
              user: BackendContacts.userFromMap(result),
              requestStatus: result['requestStatus']?.toString() ?? 'none',
              canRequest: result['canRequest'] == true,
            ))
        .where((result) => result.user.username.isNotEmpty)
        .toList();
  }

  Future<UserModel?> getUser(String username) async {
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '');
    final cached = _socket.contacts.findUser(normalized);
    if (cached != null) return cached;

    final matches = await searchUsers(normalized);
    for (final result in matches) {
      if (result.user.username.toLowerCase() == normalized.toLowerCase()) {
        return result.user;
      }
    }
    return null;
  }
}
