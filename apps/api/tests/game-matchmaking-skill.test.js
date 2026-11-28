"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  calculateMatchmakingSkill,
  normalizeGameType,
} = require("../server/realtime/game-matchmaking-skill");

test("normalizes supported matchmaking games", () => {
  assert.equal(normalizeGameType("Tic-Tac-Toe"), "tictactoe");
  assert.equal(normalizeGameType("RPS"), "rps");
  assert.equal(normalizeGameType("Raja Mantri"), "rajamantri");
});

test("derives skill score, level, and win streaks from verified human matches", () => {
  const matches = [
    { id: "m5", source: "server", gameType: "tictactoe", result: "win", playedAt: "2026-01-05T10:00:00Z" },
    { id: "m2", source: "server", gameType: "tictactoe", result: "win", playedAt: "2026-01-02T10:00:00Z" },
    { id: "m4", source: "server", gameType: "tictactoe", result: "loss", playedAt: "2026-01-04T10:00:00Z" },
    { id: "m1", source: "server", gameType: "tictactoe", result: "win", playedAt: "2026-01-01T10:00:00Z" },
    { id: "m3", source: "server", gameType: "tictactoe", result: "win", playedAt: "2026-01-03T10:00:00Z" },
    { id: "bot", source: "server", gameType: "tictactoe", result: "win", isBotMatch: true, playedAt: "2026-01-06T10:00:00Z" },
    { id: "client", source: "client", gameType: "tictactoe", result: "win", playedAt: "2026-01-07T10:00:00Z" },
    { id: "other-game", source: "server", gameType: "rps", result: "win", playedAt: "2026-01-08T10:00:00Z" },
    { id: "bad-date", source: "server", gameType: "tictactoe", result: "win", playedAt: "invalid" },
  ];

  const skill = calculateMatchmakingSkill({ matches, gameType: "tic-tac-toe" });
  assert.deepEqual(skill, {
    gameType: "tictactoe",
    level: 1,
    score: 165,
    matches: 5,
    wins: 4,
    currentStreak: 1,
    bestStreak: 3,
  });
});

test("advances matchmaking levels only from server-verified competitive score", () => {
  const matches = Array.from({ length: 14 }, (_, index) => ({
    id: `match-${index + 1}`,
    source: "server",
    gameType: "rps",
    result: "win",
    playedAt: new Date(Date.UTC(2026, 0, 1, 0, index)).toISOString(),
  }));

  const skill = calculateMatchmakingSkill({ matches, gameType: "rps" });
  assert.equal(skill.score, 550);
  assert.equal(skill.level, 2);
  assert.equal(skill.currentStreak, 14);
  assert.equal(skill.bestStreak, 14);
});

test("unknown game types safely receive the entry level", () => {
  const skill = calculateMatchmakingSkill({
    matches: [{ source: "server", gameType: "rps", result: "win", playedAt: "2026-01-01T00:00:00Z" }],
    gameType: "not-a-game",
  });
  assert.deepEqual(skill, {
    gameType: "notagame",
    level: 1,
    score: 0,
    matches: 0,
    wins: 0,
    currentStreak: 0,
    bestStreak: 0,
  });
});
