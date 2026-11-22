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
    const first = applyGameMove(game, "alice", { move: "rock" });
    assert.equal(first.ok, true);
    const second = applyGameMove(first.game, "bob", { move: "scissors" });
    assert.equal(second.ok, true);
    game = second.game;
    if (round < 2) assert.equal(game.state, "in_progress");
  }
  assert.equal(game.state, "finished");
  assert.equal(game.winner, "alice");
  assert.equal(game.data.player2, "bob");
});

test("group Number Clash and Up or Down assign one real opponent, not the group id", () => {
  const numberStart = groupGame("numberclash");
  assert.equal(numberStart.data.player2, null);
  const numberFirst = applyGameMove(numberStart, "alice", { number: 40 });
  const numberSecond = applyGameMove(numberFirst.game, "bob", { number: 42 });
  assert.equal(numberSecond.ok, true);
  assert.equal(numberSecond.game.data.player2, "bob");

  const upDownStart = groupGame("updown");
  assert.equal(upDownStart.data.player2, null);
  const predictionFirst = applyGameMove(upDownStart, "alice", { prediction: "higher" });
  const predictionSecond = applyGameMove(predictionFirst.game, "bob", { prediction: "lower" });
  assert.equal(predictionSecond.ok, true);
  assert.equal(predictionSecond.game.data.player2, "bob");
});

test("group Doodle Duel allows one group member to claim the guessing role", () => {
  const start = groupGame("doodle");
  assert.equal(start.data.player2, null);
  const drawing = applyGameMove(start, "alice", {
    action: "draw",
    strokes: [{ x1: 0, y1: 0, x2: 0.5, y2: 0.5 }],
  });
  assert.equal(drawing.ok, true);
  const guess = applyGameMove(drawing.game, "bob", { action: "guess", guess: drawing.game.data.word });
  assert.equal(guess.ok, true);
  assert.equal(guess.game.state, "finished");
  assert.equal(guess.game.data.player2, "bob");
});
