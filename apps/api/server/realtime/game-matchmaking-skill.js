"use strict";

const VALID_GAME_TYPES = new Set(["tictactoe", "rps"]);
const VALID_RESULTS = new Set(["win", "loss", "draw"]);
const XP_PER_MATCH = 10;
const XP_PER_WIN = 25;
const XP_PER_THREE_WIN_STREAK = 15;
const XP_PER_LEVEL = 500;
const MAX_MATCH_HISTORY = 2_000;

function normalizeGameType(value) {
  return String(value || "").trim().toLowerCase().replace(/[^a-z0-9]/g, "");
}

/**
 * Derive a matchmaking level from server-recorded human match history.
 *
 * The caller should query only { source: "server" } records and keep the
 * returned history bounded. Client-submitted levels are deliberately ignored.
 */
function calculateMatchmakingSkill({ matches, gameType }) {
  const type = normalizeGameType(gameType);
  if (!VALID_GAME_TYPES.has(type)) {
    return {
      gameType: type,
      level: 1,
      score: 0,
      matches: 0,
      wins: 0,
      currentStreak: 0,
      bestStreak: 0,
    };
  }

  const eligible = (Array.isArray(matches) ? matches : [])
    .filter((match) =>
      match &&
      match.source === "server" &&
      match.isBotMatch !== true &&
      normalizeGameType(match.gameType) === type &&
      VALID_RESULTS.has(match.result) &&
      Number.isFinite(Date.parse(match.playedAt))
    )
    .map((match) => ({
      id: String(match.id || match._id || ""),
      result: match.result,
      playedAt: Date.parse(match.playedAt),
    }))
    .sort((a, b) => a.playedAt - b.playedAt || a.id.localeCompare(b.id))
    .slice(-MAX_MATCH_HISTORY);

  let score = 0;
  let wins = 0;
  let currentStreak = 0;
  let bestStreak = 0;

  for (const match of eligible) {
    score += XP_PER_MATCH;
    if (match.result === "win") {
      wins += 1;
      score += XP_PER_WIN;
      currentStreak += 1;
      bestStreak = Math.max(bestStreak, currentStreak);
      if (currentStreak % 3 === 0) {
        score += XP_PER_THREE_WIN_STREAK;
      }
    } else {
      currentStreak = 0;
    }
  }

  return {
    gameType: type,
    level: Math.floor(score / XP_PER_LEVEL) + 1,
    score,
    matches: eligible.length,
    wins,
    currentStreak,
    bestStreak,
  };
}

module.exports = {
  calculateMatchmakingSkill,
  normalizeGameType,
};
