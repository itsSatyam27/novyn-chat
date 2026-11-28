List<Map<String, dynamic>> mergePendingGameInvitations({
  required Iterable<Map<String, dynamic>> serverSnapshot,
  required Iterable<Map<String, dynamic>> liveInvitations,
  required Set<String> preservedLiveIds,
  required Set<String> resolvedIds,
  int? nowMs,
}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final merged = <String, Map<String, dynamic>>{};

  bool isActive(Map<String, dynamic> invite) {
    final id = invite['messageId']?.toString().trim() ?? '';
    if (id.isEmpty || resolvedIds.contains(id)) return false;
    final expiresAt = int.tryParse(invite['expiresAt']?.toString() ?? '');
    return expiresAt == null || expiresAt > now;
  }

  // Keep realtime invitations which arrived while the server snapshot was
  // being requested. They are inserted first so the newest live invite stays
  // above the older server snapshot.
  for (final invite in liveInvitations) {
    final id = invite['messageId']?.toString().trim() ?? '';
    if (!preservedLiveIds.contains(id) || !isActive(invite)) continue;
    merged[id] = Map<String, dynamic>.from(invite);
  }

  for (final invite in serverSnapshot) {
    final id = invite['messageId']?.toString().trim() ?? '';
    if (!isActive(invite)) continue;
    merged.putIfAbsent(id, () => Map<String, dynamic>.from(invite));
  }

  return List<Map<String, dynamic>>.unmodifiable(merged.values);
}

bool shouldShowForegroundGameInvitationSystemNotification({
  required bool appResumed,
  required bool socketConnected,
  required bool socketAuthenticated,
}) {
  // When the foreground socket is live, the global invitation overlay owns
  // the prompt. Avoid showing a second system notification for the same invite.
  return !appResumed || !socketConnected || !socketAuthenticated;
}
