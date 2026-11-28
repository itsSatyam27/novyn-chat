"use strict";

function normalizeKey(value) {
  return String(value || "").trim().toLowerCase();
}

function getRegisteredHumanAccounts(playerValues, users) {
  const keys = Array.from(new Set(playerValues.map(normalizeKey).filter(Boolean)));
  if (keys.length < 2) return null;
  const accounts = new Map();
  for (const key of keys) {
    const account = users?.get(key);
    if (!account?.isRegistered || account.isSuspended === true) return null;
    accounts.set(key, account);
  }
  return accounts;
}

function buildTwoPlayerGameHistoryRecords(game, users) {
  if (!game || game.state !== "finished" || !["tictactoe", "rps"].includes(game.gameType)) return [];
  const data = game.data && typeof game.data === "object" && !Array.isArray(game.data) ? game.data : {};
  const playerValues = game.gameType === "tictactoe"
    ? [data.playerX || game.createdBy, data.playerO || game.opponent]
    : [data.player1 || game.createdBy, data.player2 || game.opponent];
  const playerKeys = Array.from(new Set(playerValues.map(normalizeKey).filter(Boolean)));
  const accounts = getRegisteredHumanAccounts(playerKeys, users);
  if (!accounts || playerKeys.length !== 2 ||
      playerKeys.some((key) => /^(ai|bot)(\\b|[_ -])/i.test(key))) return [];

  const winnerKey = normalizeKey(game.winner);
  if (winnerKey !== "draw" && !playerKeys.includes(winnerKey)) return [];

  const updatedAt = Number(game.updatedAt);
  if (!Number.isFinite(updatedAt) || updatedAt <= 0) return [];
  const playedAt = new Date(Math.trunc(updatedAt));
  const baseId = String(game.id || "").trim();
  if (!baseId) return [];
  // The Flutter history client uses DateTime.fromMillisecondsSinceEpoch(...).microsecondsSinceEpoch.
  const matchId = baseId + "-" + String(Math.trunc(updatedAt) * 1000);

  return playerKeys.map((userKey) => {
    const opponents = playerKeys
      .filter((key) => key !== userKey)
      .map((key) => String(accounts.get(key)?.username || key));
    return {
      _id: userKey + ":" + matchId,
      userKey,
      id: matchId,
      gameType: game.gameType,
      opponent: opponents.join(", "),
      result: winnerKeys.size > 1
      ? winnerKeys.has(userKey) ? "draw" : "loss"
      : winnerKeys.has(userKey) ? "win" : "loss",
      playedAt: playedAt.toISOString(),
      isBotMatch: false,
    };
  });
}

function buildRajaMantriHistoryRecords(session, users) {
  if (!session || session.phase !== "finished" || !Array.isArray(session.players)) return [];
  const players = session.players;
  if (players.length < 3 || players.some((player) => player.isBot === true)) return [];
  const playerKeys = players.map((player) => normalizeKey(player.username));
  if (playerKeys.some((key) => !key) || new Set(playerKeys).size !== playerKeys.length) return [];
  const accounts = getRegisteredHumanAccounts(playerKeys, users);
  if (!accounts) return [];

  const scores = players.map((player) => Math.max(0, Number(player.score) || 0));
  const topScore = Math.max(...scores);
  const winnerIndexes = scores.map((score, index) => score === topScore ? index : -1).filter((index) => index >= 0);
  const winnerKeys = new Set(winnerIndexes.map((index) => playerKeys[index]));
  const playedAtMs = Number(session.finishedAt) > 0 ? Number(session.finishedAt) : Date.now();
  const playedAt = new Date(playedAtMs);
  const matchId = String(session.sessionId || "").trim();
  if (!matchId) return [];

  return playerKeys.map((userKey) => ({
    _id: userKey + ":" + matchId,
    userKey,
    id: matchId,
    gameType: "rajamantri",
    opponent: playerKeys
      .filter((key) => key !== userKey)
      .map((key) => String(accounts.get(key)?.username || key))
      .join(", "),
    result: winnerKey === "draw" ? "draw" : winnerKey === userKey ? "win" : "loss",
    playedAt: playedAt.toISOString(),
    isBotMatch: false,
  }));
}

module.exports = {
  buildTwoPlayerGameHistoryRecords,
  buildRajaMantriHistoryRecords,
};
