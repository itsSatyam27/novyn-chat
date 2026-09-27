const { normalizeName, toDisplayName } = require("../core/normalization");

function createAuthSessions({ refreshSessions, refreshByUser, authUserAliases, schedulePersist }) {
  const persist = typeof schedulePersist === "function" ? schedulePersist : () => {};

  function trackRefreshSession(userKey, jti, expiresAt, remember) {
    const key = normalizeName(userKey);
    const tokenId = toDisplayName(jti);
    if (!key || !tokenId) return;
    refreshSessions.set(tokenId, {
      userKey: key,
      expiresAt: Number(expiresAt) || 0,
      remember: Boolean(remember),
    });
    if (!refreshByUser.has(key)) refreshByUser.set(key, new Set());
    refreshByUser.get(key).add(tokenId);
    persist();
  }

  function revokeRefreshSession(rawTokenId) {
    const tokenId = toDisplayName(rawTokenId);
    if (!tokenId) return false;
    const existing = refreshSessions.get(tokenId);
    if (!existing) return false;
    refreshSessions.delete(tokenId);
    const ownerSet = refreshByUser.get(existing.userKey);
    if (ownerSet) {
      ownerSet.delete(tokenId);
      if (!ownerSet.size) refreshByUser.delete(existing.userKey);
    }
    persist();
    return true;
  }

  function moveRefreshSessionsToUser(oldUserKey, nextUserKey) {
    const oldKey = normalizeName(oldUserKey);
    const newKey = normalizeName(nextUserKey);
    if (!oldKey || !newKey || oldKey === newKey) return;
    const tokenSet = refreshByUser.get(oldKey);
    if (!tokenSet || !tokenSet.size) return;
    if (!refreshByUser.has(newKey)) refreshByUser.set(newKey, new Set());
    const nextSet = refreshByUser.get(newKey);
    for (const tokenId of tokenSet) {
      const entry = refreshSessions.get(tokenId);
      if (entry) entry.userKey = newKey;
      nextSet.add(tokenId);
    }
    refreshByUser.delete(oldKey);
    persist();
  }

  function pruneExpiredAuthState() {
    const now = Date.now();
    let touched = false;
    for (const [oldKey, alias] of authUserAliases.entries()) {
      if (!alias || Number(alias.expiresAt) <= now) {
        authUserAliases.delete(oldKey);
        touched = true;
      }
    }
    for (const [tokenId, entry] of refreshSessions.entries()) {
      if (!entry || Number(entry.expiresAt) <= now) {
        touched = revokeRefreshSession(tokenId) || touched;
      }
    }
    if (touched) persist();
  }

  return {
    trackRefreshSession,
    revokeRefreshSession,
    moveRefreshSessionsToUser,
    pruneExpiredAuthState,
  };
}

module.exports = { createAuthSessions };
