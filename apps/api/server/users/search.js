'use strict';

/**
 * Build a small, privacy-aware directory response for authenticated username
 * search. The response deliberately omits email, internal IDs and account data.
 */
function buildUserSearchResults({
  users,
  userKey,
  query,
  usersAreBlocked,
  privacyAllows,
  getEffectivePresence,
  getVisibleLastSeen,
  limit = 8,
}) {
  const needle = String(query || '').trim().toLowerCase().replace(/^@/, '');
  const me = users.get(userKey);
  if (!me || !needle) return [];

  const results = [];
  for (const [candidateKey, candidate] of users.entries()) {
    if (!candidate?.isRegistered || candidateKey === userKey) continue;

    const username = String(candidate.username || candidateKey);
    const normalizedUsername = username.toLowerCase();
    if (!normalizedUsername.includes(needle)) continue;
    if (usersAreBlocked(userKey, candidateKey)) continue;

    const isFriend = Boolean(me.friends?.has(candidateKey));
    // Outgoing requests are stored on the recipient; incoming requests are
    // stored on the current user's own requests set.
    const hasSentRequest = Boolean(candidate.requests?.has(userKey));
    const hasIncomingRequest = Boolean(me.requests?.has(candidateKey));
    const requestStatus = isFriend
      ? 'friend'
      : hasSentRequest
        ? 'sent'
        : hasIncomingRequest
          ? 'incoming'
          : 'none';

    const hasMutualFriend = Array.from(me.friends || []).some((friendKey) =>
      candidate.friends?.has(friendKey),
    );
    const requestPrivacy = candidate.friendRequestPrivacy || 'everyone';
    const canRequest =
      requestStatus === 'none' &&
      requestPrivacy !== 'nobody' &&
      (requestPrivacy !== 'mutuals' || hasMutualFriend);

    const canSeePresence = privacyAllows(candidate, userKey, 'presencePrivacy');
    const presence = canSeePresence
      ? getEffectivePresence(candidateKey)
      : 'offline';

    results.push({
      username,
      displayName: String(candidate.displayName || ''),
      avatarId: privacyAllows(candidate, userKey, 'profilePhotoPrivacy')
        ? String(candidate.avatarId || '')
        : '',
      bio: String(candidate.bio || '').slice(0, 160),
      online: canSeePresence && presence !== 'offline',
      presence,
      lastSeenAt: canSeePresence ? getVisibleLastSeen(candidate) : null,
      requestStatus,
      canRequest,
    });
  }

  results.sort((a, b) => {
    const rank = (name) =>
      name.toLowerCase() === needle
        ? 0
        : name.toLowerCase().startsWith(needle)
          ? 1
          : 2;
    return rank(a.username) - rank(b.username) ||
      a.username.localeCompare(b.username);
  });

  const safeLimit = Math.max(1, Math.min(20, Number(limit) || 8));
  return results.slice(0, safeLimit);
}

module.exports = { buildUserSearchResults };
