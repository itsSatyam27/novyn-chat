"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { applyGameMove, createGameChallenge } = require("../server/realtime/game-rules");

function groupGame(gameType) {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "alice",
    to: "group-123",
    toType: "group",
    game: { gameType },
  });
  assert.equal(result.ok, true);
  return result.game;
}

test("group Tic-Tac-Toe lets the first opponent join after the creator's opening move", () => {
  const created = groupGame("tictactoe");
  const first = applyGameMove(created, "alice", { board: ["X", null, null, null, null, null, null, null, null] });
  assert.equal(first.ok, true);
  assert.equal(first.game.turn, null);
  const second = applyGameMove(first.game, "bob", { board: ["X", "O", null, null, null, null, null, null, null] });
  assert.equal(second.ok, true);
  assert.equal(second.game.data.playerO, "bob");
  assert.equal(second.game.turn, "alice");
});

test("removed group game types are rejected", () => {
  for (const gameType of ["connect4", "doodle", "numberclash", "updown"]) {
    const result = createGameChallenge({
      userKey: "alice",
      userDisplayName: "alice",
      to: "group-123",
      toType: "group",
      game: { gameType },
    });
    assert.equal(result.ok, false);
    assert.match(result.reason, /unsupported/i);
  }
});

test("group Rock Paper Scissors assigns the first challenger and resolves best of three", () => {
  let game = groupGame("rps");
  for (let round = 0; round < 3; round++) {
    const expectedRound = (Number(game.data.round) || 1) + (game.data.roundResolved === true ? 1 : 0);
    const first = applyGameMove(game, "alice", { move: "rock", round: expectedRound });
    assert.equal(first.ok, true);
    const second = applyGameMove(first.game, "bob", { move: "scissors", round: expectedRound });
    assert.equal(second.ok, true);
    game = second.game;
    if (round < 2) assert.equal(game.state, "in_progress");
  }
  assert.equal(game.state, "finished");
  assert.equal(game.winner, "alice");
  assert.equal(game.data.player2, "bob");
});




