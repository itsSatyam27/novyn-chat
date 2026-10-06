import 'package:flutter/foundation.dart';
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

/// Contact operations backed by the same authenticated Novyn account as web.
class FriendService {
  final SocketService _socket;
  List<UserModel>? _cachedFriends;

  FriendService(this._socket);

  List<UserModel>? get cachedFriends => _cachedFriends;

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
    return _watch(() {
      _cachedFriends = List<UserModel>.from(_socket.contacts.friends);
      return List<UserModel>.from(_cachedFriends!);
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

  Future<void> acceptRequest(
      String requestId, String myUid, String otherUid) async {
    _socket.acceptFriendRequest(otherUid);
  }

  Future<void> declineRequest(String requestId) async {
    _socket.rejectFriendRequest(requestId);
  }

  Future<void> removeFriend(String myUid, String otherUid) async {
    _socket.removeFriend(otherUid);
    _cachedFriends?.removeWhere((user) => user.username == otherUid);
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

  Future<UserModel?> getUser(String username) async {
    final cached = _socket.contacts.findUser(username);
    if (cached != null) return cached;

    final matches = await ApiService.searchUsers(username);
    for (final result in matches) {
      if (result['username']?.toString().toLowerCase() ==
          username.toLowerCase()) {
        return BackendContacts.userFromMap(result);
      }
    }
    return null;
  }
}
