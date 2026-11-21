import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/models/user_model.dart';
import 'package:novyn/utils/game_matchmaking.dart';

UserModel friend({
  required String username,
  String? name,
  bool online = true,
  String status = 'online',
}) {
  return UserModel(
    uid: username,
    username: username,
    name: name ?? username,
    email: '',
    bio: '',
    createdAt: DateTime(2026),
    isOnline: online,
    status: status,
  );
}

void main() {
  group('GameMatchmaking', () {
    test('only online-presence friends are eligible for quick match', () {
      final available = GameMatchmaking.availableOnlineFriends([
        friend(username: 'zoe', name: 'Zoe'),
        friend(username: 'away', online: true, status: 'away'),
        friend(username: 'busy', online: true, status: 'busy'),
        friend(username: 'invisible', online: false, status: 'invisible'),
        friend(username: 'offline', online: false, status: 'offline'),
        friend(username: 'alice', name: 'Alice'),
      ]);

      expect(
        available.map((user) => user.username).toList(),
        ['alice', 'zoe'],
      );
    });

    test('quick match chooses from eligible friends only', () {
      final selected = GameMatchmaking.pickRandomOnlineFriend(
        [
          friend(username: 'offline', online: false, status: 'offline'),
          friend(username: 'alice'),
          friend(username: 'bob'),
        ],
        random: Random(0),
      );

      expect(selected, isNotNull);
      expect({'alice', 'bob'}, contains(selected!.username));
    });

    test('quick match returns null when nobody is online', () {
      final selected = GameMatchmaking.pickRandomOnlineFriend([
        friend(username: 'away', online: true, status: 'away'),
        friend(username: 'offline', online: false, status: 'offline'),
      ]);

      expect(selected, isNull);
    });
  });
}
