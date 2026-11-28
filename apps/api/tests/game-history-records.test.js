"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildTwoPlayerGameHistoryRecords,
  buildRajaMantriHistoryRecords,
} = require("../server/realtime/game-history-records");

function accounts(...names) {
  return new Map(names.map((username) => [username, {
    username,
    isRegistered: true,
    isSuspended: false,
  }]));
}

test("two-player game history is derived from the authoritative winner and is symmetric", () => {
  const users = accounts("alice", "bob");
  const game = {
    id: "game-123",
    gameType: "tictactoe",
    state: "finished",
    winner: "ALICE",
    updatedAt: 1795831200123,
    data: { playerX: "Alice", playerO: "bob" },
  };
  const records = buildTwoPlayerGameHistoryRecords(game, users);
  assert.equal(records.length, 2);
  assert.deepEqual(records.map((record) => [record.userKey, record.result]), [
    ["alice", "win"],
    ["bob", "loss"],
  ]);
  assert.equal(records[0].id, "game-123-" + (1795831200123 * 1000));
  assert.equal(records[0].opponent, "bob");
  assert.equal(records[1].opponent, "alice");
  assert.equal(records[0]._id, "alice:" + records[0].id);
});

test("two-player game history records draws and rejects forged or non-human results", () => {
  const users = accounts("alice", "bob", "bot_123");
  const draw = buildTwoPlayerGameHistoryRecords({
    id: "draw-game",
    gameType: "rps",
    state: "finished",
    winner: "draw",
    updatedAt: 1795831200123,
    createdBy: "alice",
    opponent: "bob",
  }, users);
  assert.deepEqual(draw.map((record) => record.result), ["draw", "draw"]);

  assert.deepEqual(buildTwoPlayerGameHistoryRecords({
    id: "forged",
    gameType: "rps",
    state: "finished",
    winner: "mallory",
    updatedAt: 1795831200123,
    createdBy: "alice",
    opponent: "bob",
  }, users), []);

  assert.deepEqual(buildTwoPlayerGameHistoryRecords({
    id: "bot-game",
    gameType: "rps",
    state: "finished",
    winner: "alice",
    updatedAt: 1795831200123,
    createdBy: "alice",
    opponent: "bot_123",
  }, users), []);

  assert.deepEqual(buildTwoPlayerGameHistoryRecords({
    id: "still-running",
    gameType: "rps",
    state: "in_progress",
    winner: "alice",
    updatedAt: 1795831200123,
    createdBy: "alice",
    opponent: "bob",
  }, users), []);
});

test("Raja Mantri history uses completed server scores and never accepts bot sessions", () => {
  const users = accounts("alice", "bob", "carol");
  const session = {
    sessionId: "rm-123",
    phase: "finished",
    finishedAt: 1795831200123,
    players: [
      { username: "alice", score: 2400 },
      { username: "bob", score: 1900 },
      { username: "carol", score: 2400 },
    ],
  };
  const records = buildRajaMantriHistoryRecords(session, users);
  assert.equal(records.length, 3);
  assert.deepEqual(records.map((record) => record.result), ["draw", "loss", "draw"]);
  assert.equal(records[0].id, "rm-123");
  assert.equal(records[0].opponent, "bob, carol");

  assert.deepEqual(buildRajaMantriHistoryRecords({
    ...session,
    players: [...session.players, { username: "bot_1", score: 0, isBot: true }],
  }, users), []);
  assert.deepEqual(buildRajaMantriHistoryRecords({ ...session, phase: "result" }, users), []);
});
