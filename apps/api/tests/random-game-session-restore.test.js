"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { listActiveRandomGamesForPlayer } = require("../server/realtime/random-game-session-restore");

test("restores only active random matches that belong to the authenticated player", () => {
  const gameOne = { gameType: "tictactoe", state: "in_progress", data: { board: Array(9).fill(null) } };
  const gameTwo = { gameType: "rps", state: "in_progress", data: { round: 2 } };
  const sessions = new Map([
    ["match-1", { expiresAt: 5000, players: ["alice", "bob"], game: gameOne }],
    ["match-2", { expiresAt: 5000, players: ["carol", "dave"], game: gameTwo }],
    ["match-3", { expiresAt: 5000, players: ["alice", "erin"], game: { gameType: "rps" } }],
  ]);

  const restored = listActiveRandomGamesForPlayer(sessions, " ALICE ", 1000);
  assert.deepEqual(restored.map((match) => match.sessionId), ["match-1", "match-3"]);
  assert.equal(restored[0].opponentUsername, "bob");
  assert.equal(restored[0].game, gameOne);
  assert.equal(listActiveRandomGamesForPlayer(sessions, "mallory", 1000).length, 0);
});

test("expired or malformed random sessions are pruned instead of restored", () => {
  const sessions = new Map([
    ["expired", { expiresAt: 999, players: ["alice", "bob"], game: { gameType: "rps" } }],
    ["invalid-expiry", { expiresAt: "not-a-time", players: ["alice", "bob"], game: { gameType: "rps" } }],
    ["bad-game", { expiresAt: 5000, players: ["alice", "bob"], game: [] }],
  ]);

  const restored = listActiveRandomGamesForPlayer(sessions, "alice", 1000);
  assert.equal(restored.length, 0);
  assert.equal(sessions.has("expired"), false);
  assert.equal(sessions.has("invalid-expiry"), false);
  assert.equal(sessions.has("bad-game"), true);
});

test("does not restore a session with no opponent", () => {
  const sessions = new Map([
    ["solo", { expiresAt: 5000, players: ["alice"], game: { gameType: "tictactoe" } }],
  ]);
  assert.deepEqual(listActiveRandomGamesForPlayer(sessions, "alice", 1000), []);
});
