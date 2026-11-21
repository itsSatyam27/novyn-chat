import 'dart:math';

import '../models/user_model.dart';

/// Presence-aware helpers for the lightweight friend matchmaking flow.
class GameMatchmaking {
  const GameMatchmaking._();

  /// Mirrors Novyn's online-friend availability rule: Busy, Away, Invisible,
  /// and Offline contacts are not eligible for an instant quick match.
  static List<UserModel> availableOnlineFriends(Iterable<UserModel> friends) {
    final available = friends.where((friend) {
      final presence = friend.status.trim().toLowerCase();
      return friend.isOnline && (presence.isEmpty || presence == 'online');
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return available;
  }

  /// Picks one eligible online friend, or null when nobody is available.
  static UserModel? pickRandomOnlineFriend(
    Iterable<UserModel> friends, {
    Random? random,
  }) {
    final available = availableOnlineFriends(friends);
    if (available.isEmpty) return null;
    return available[(random ?? Random()).nextInt(available.length)];
  }
}
