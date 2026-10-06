import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Contacts from the same Socket.IO backend used by Novyn web.
class BackendContacts extends ChangeNotifier {
  List<UserModel> friends = [];
  List<UserModel> discovered = [];
  List<String> requests = [];
  Set<String> sentRequests = {};

  static UserModel userFromMap(Map data) {
    final username = data['username']?.toString() ?? '';
    return UserModel(
      uid: username,
      username: username,
      name: data['displayName']?.toString() ?? username,
      email: '',
      bio: data['bio']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isOnline: data['online'] == true,
      status: data['presence']?.toString() ?? 'offline',
      lastSeen: DateTime.tryParse(data['lastSeenAt']?.toString() ?? ''),
      photoUrl: data['avatarId']?.toString() ?? '',
    );
  }

  void applyEvent(String event, dynamic payload) {
    final data = payload is Map ? payload : <String, dynamic>{};
    switch (event) {
      case 'register_success':
      case 'init':
        requests = _names(data['requests']);
        sentRequests = _names(data['sentRequests']).toSet();
        friends = _users(data['friends'], excludeGroups: true);
        break;
      case 'friend_list':
      case 'friend_list_updated':
        friends = _users(payload is List ? payload : data['friends'],
            excludeGroups: true);
        sentRequests.removeWhere((name) => friends.any(
            (user) => user.username.toLowerCase() == name.toLowerCase()));
        break;
      case 'requests_updated':
        requests = _names(data['requests']);
        break;
      case 'discover_online':
        discovered = _users(data['users']);
        break;
      case 'friend_request_sent':
        final name = data['to']?.toString();
        if (name != null) sentRequests.add(name);
        break;
      case 'friend_request_cancelled':
        final name = data['to']?.toString().toLowerCase();
        sentRequests.removeWhere((user) => user.toLowerCase() == name);
        break;
      case 'user_status':
        updateStatus(data['username']?.toString() ?? '', data['online'] == true);
        return;
      default:
        return;
    }
    notifyListeners();
  }

  void updateStatus(String username, bool online) {
    friends = friends.map((user) =>
        user.username.toLowerCase() == username.toLowerCase()
            ? user.copyWith(isOnline: online)
            : user).toList();
    notifyListeners();
  }

  UserModel? findUser(String username) {
    for (final user in [...friends, ...discovered]) {
      if (user.username.toLowerCase() == username.toLowerCase()) return user;
    }
    return null;
  }

  void clear() {
    friends = [];
    discovered = [];
    requests = [];
    sentRequests = {};
    notifyListeners();
  }

  static List<String> _names(dynamic values) => values is List
      ? values.map((value) => value.toString()).toList()
      : [];

  static List<UserModel> _users(dynamic values, {bool excludeGroups = false}) {
    if (values is! List) return [];
    return values.whereType<Map>()
        .where((data) => !excludeGroups ||
            (data['kind'] != 'group' && data['groupId'] == null))
        .map(userFromMap)
        .where((user) => user.username.isNotEmpty)
        .toList();
  }
}
