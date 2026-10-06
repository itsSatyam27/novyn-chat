import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;
  UserModel? fromUser; // populated after fetch

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
    this.fromUser,
  });

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUid: d['fromUid'] ?? '',
      toUid: d['toUid'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == (d['status'] ?? 'pending'),
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache so the UI never shows a loading flash on revisit
  List<UserModel>? _cachedFriends;
  List<UserModel>? get cachedFriends => _cachedFriends;

  // ── Send a friend request ─────────────────────────────────────────────────
  Future<void> sendRequest(String fromUid, String toUid) async {
    // Prevent duplicates
    final existing = await _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _db.collection('friendRequests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Accept a request ──────────────────────────────────────────────────────
  Future<void> acceptRequest(String requestId, String myUid, String otherUid) async {
    final batch = _db.batch();

    // Update request status
    batch.update(_db.collection('friendRequests').doc(requestId), {
      'status': 'accepted',
    });

    // Add to both users' friend lists
    batch.set(
      _db.collection('friends').doc(myUid).collection('friendList').doc(otherUid),
      {'uid': otherUid, 'since': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('friends').doc(otherUid).collection('friendList').doc(myUid),
      {'uid': myUid, 'since': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  // ── Decline a request ─────────────────────────────────────────────────────
  Future<void> declineRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // ── Remove a friend ───────────────────────────────────────────────────────
  Future<void> removeFriend(String myUid, String otherUid) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection('friends').doc(myUid).collection('friendList').doc(otherUid),
    );
    batch.delete(
      _db.collection('friends').doc(otherUid).collection('friendList').doc(myUid),
    );
    await batch.commit();
  }

  // ── Update cached friend status (from socket presence events) ───────────
  void updateCachedStatus(String uid, bool isOnline) {
    if (_cachedFriends == null) return;
    final idx = _cachedFriends!.indexWhere((u) => u.uid == uid);
    if (idx != -1) {
      _cachedFriends![idx] = _cachedFriends![idx].copyWith(isOnline: isOnline);
    }
  }

  // ── Stream friend UIDs ────────────────────────────────────────────────────
  Stream<List<String>> friendUidsStream(String myUid) {
    return _db
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  // ── Stream friends as UserModels ──────────────────────────────────────────
  Stream<List<UserModel>> friendsStream(String myUid) {
    return friendUidsStream(myUid).asyncMap((uids) async {
      if (uids.isEmpty) {
        _cachedFriends = [];
        return <UserModel>[];
      }
      final futures = uids.map((uid) => _db.collection('users').doc(uid).get());
      final docs = await Future.wait(futures);
      final result = docs
          .where((d) => d.exists)
          .map((d) => UserModel.fromDoc(d))
          .toList();
      _cachedFriends = result;
      return result;
    });
  }

  // ── Stream incoming pending requests count ────────────────────────────────
  Stream<int> pendingRequestsCountStream(String myUid) {
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Stream incoming pending requests (with sender info) ───────────────────
  Stream<List<FriendRequest>> pendingRequestsStream(String myUid) {
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = snapshot.docs
          .map((d) => FriendRequest.fromDoc(d))
          .toList();

      // Fetch sender profiles
      for (final req in requests) {
        final doc = await _db.collection('users').doc(req.fromUid).get();
        if (doc.exists) req.fromUser = UserModel.fromDoc(doc);
      }
      return requests;
    });
  }

  // ── Stream all users except me + my friends (for Discover) ───────────────
  Stream<List<UserModel>> discoverUsersStream(
      String myUid, List<String> friendUids) {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => UserModel.fromDoc(d))
            .where((u) => u.uid != myUid && !friendUids.contains(u.uid))
            .toList());
  }

  // ── Check if a pending request already exists (sent by me) ───────────────
  Future<bool> hasPendingRequest(String fromUid, String toUid) async {
    final q = await _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  // ── Stream sent pending request UIDs (so Discover can show "Pending") ─────
  Stream<Set<String>> sentPendingUidsStream(String myUid) {
    return _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => d['toUid'] as String).toSet());
  }

  // ── Fetch a single user by UID (for QR scanning) ──────────────────────────
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return UserModel.fromDoc(doc);
    return null;
  }
}
