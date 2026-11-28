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

    const players = Array.isArray(session?.players)
      ? session.players.map((player) => String(player || "").trim().toLowerCase())
      : [];
    const game = session?.game;
    const validPlayers = players.length === 2 &&
      players.every(Boolean) &&
      new Set(players).size === 2;
    const validGame = Boolean(
      game &&
      typeof game === "object" &&
      !Array.isArray(game) &&
      ["tictactoe", "rps"].includes(game.gameType) &&
      ["in_progress", "finished"].includes(game.state)
    );

    if (!validPlayers || !validGame) {
      if (session?.expiryTimer) clearTimeout(session.expiryTimer);
      sessions.delete(sessionId);
      continue;
    }
    if (!players.includes(currentUser)) continue;

    const opponentUsername = players.find((player) => player !== currentUser);
    matches.push({
      sessionId: String(sessionId),
      game,
      opponentUsername,
    });
  }

  return matches;
}

module.exports = { listActiveRandomGamesForPlayer };
