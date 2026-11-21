"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { applyGameMove, createGameChallenge } = require("../server/realtime/game-rules");

function friendGame() {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "alice",
    to: "bob",
    toType: "friend",
    game: { gameType: "tictactoe", id: "ttt-friend-test" },
  });
  assert.equal(result.ok, true);
  return result.game;
}

function boardWith(...moves) {
  const board = Array(9).fill(null);
  for (const [index, symbol] of moves) board[index] = symbol;
  return board;
}

test("friend Tic-Tac-Toe challenge starts with the creator and targets the selected friend", () => {
  const game = friendGame();

  assert.equal(game.gameType, "tictactoe");
  assert.equal(game.createdBy, "alice");
  assert.equal(game.opponent, "bob");
  assert.equal(game.state, "in_progress");
  assert.equal(game.turn, "alice");
  assert.deepEqual(game.data.board, Array(9).fill(null));
  assert.equal(game.data.playerX, "alice");
});

test("friend Tic-Tac-Toe rejects the wrong turn and accepts alternating legal moves", () => {
  const start = friendGame();

  const earlyOpponentMove = applyGameMove(
    start,
    "bob",
    { board: boardWith([0, "O"]) },
  );
  assert.equal(earlyOpponentMove.ok, false);

  const first = applyGameMove(
    start,
    "alice",
    { board: boardWith([0, "X"]) },
  );
  assert.equal(first.ok, true);
  assert.equal(first.game.turn, "bob");

  const second = applyGameMove(
    first.game,
    "bob",
    { board: boardWith([0, "X"], [3, "O"]) },
  );
  assert.equal(second.ok, true);
  assert.equal(second.game.turn, "alice");

  const third = applyGameMove(
    second.game,
    "alice",
    { board: boardWith([0, "X"], [1, "X"], [3, "O"]) },
  );
  assert.equal(third.ok, true);
  assert.equal(third.game.turn, "bob");
});

test("friend Tic-Tac-Toe completes a winning line and rejects further moves", () => {
  let game = friendGame();
  const sequence = [
    ["alice", [[0, "X"]]],
    ["bob", [[0, "X"], [3, "O"]]],
    ["alice", [[0, "X"], [1, "X"], [3, "O"]]],
    ["bob", [[0, "X"], [1, "X"], [3, "O"], [4, "O"]]],
    ["alice", [[0, "X"], [1, "X"], [2, "X"], [3, "O"], [4, "O"]]],
  ];

  for (const [username, moves] of sequence) {
    const result = applyGameMove(game, username, {
      board: boardWith(...moves),
    });
    assert.equal(result.ok, true);
    game = result.game;
  }

  assert.equal(game.state, "finished");
  assert.equal(game.winner, "alice");
  assert.deepEqual(game.data.winningLine, [0, 1, 2]);

  const afterFinish = applyGameMove(
    game,
    "bob",
    { board: boardWith([0, "X"], [1, "X"], [2, "X"], [3, "O"], [4, "O"], [5, "O"]) },
  );
  assert.equal(afterFinish.ok, false);
});
