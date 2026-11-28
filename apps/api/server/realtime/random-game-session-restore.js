"use strict";

function listActiveRandomGamesForPlayer(sessions, userKey, now = Date.now()) {
  const currentUser = String(userKey || "").trim().toLowerCase();
  if (!currentUser || !(sessions instanceof Map)) return [];

  const matches = [];
  for (const [sessionId, session] of sessions) {
    const expiresAt = Number(session?.expiresAt);
    if (!Number.isFinite(expiresAt) || expiresAt <= now) {
      if (session?.expiryTimer) clearTimeout(session.expiryTimer);
      sessions.delete(sessionId);
      continue;
    }

    if (!session || !Array.isArray(session.players) ||
        !session.players.some((player) => String(player || "").trim().toLowerCase() === currentUser)) {
      continue;
    }

    const opponentUsername = session.players
      .map((player) => String(player || "").trim().toLowerCase())
      .find((player) => player && player !== currentUser);
    if (!opponentUsername || !session.game ||
        typeof session.game !== "object" || Array.isArray(session.game)) {
      continue;
    }

    matches.push({
      sessionId: String(sessionId),
      game: session.game,
      opponentUsername,
    });
  }

  return matches;
}

module.exports = { listActiveRandomGamesForPlayer };
