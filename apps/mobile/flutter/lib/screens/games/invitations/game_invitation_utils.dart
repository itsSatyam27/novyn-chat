int? gameInvitationExpiryTimestamp(Map<String, dynamic> invitation) {
  final raw = invitation['expiresAt'];
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

bool isGameInvitationExpired(
  Map<String, dynamic> invitation, {
  int? nowMilliseconds,
}) {
  final expiresAt = gameInvitationExpiryTimestamp(invitation);
  if (expiresAt == null) return false;
  return expiresAt <=
      (nowMilliseconds ?? DateTime.now().millisecondsSinceEpoch);
}
