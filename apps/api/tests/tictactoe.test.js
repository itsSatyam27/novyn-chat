"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { applyGameMove, createGameChallenge } = require("../server/realtime/game-rules");

function createFriendGame() {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "Alice",
    to: "bob",
    toType: "friend",
    game: { gameType: "tictactoe" },
  });
  assert.equal(result.ok, true);
  return result.game;
}

function createGroupGame() {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "Alice",
    to: "group-123",
    toType: "group",
    game: { gameType: "tictactoe" },
  });
  assert.equal(result.ok, true);
  return result.game;
}

function move(game, username, index, symbol) {
  const board = [...game.data.board];
  board[index] = symbol;
  return applyGameMove(game, username, { board });
}

test("friend Tic-Tac-Toe assigns X and O and alternates turns", () => {
  const start = createFriendGame();
  assert.equal(start.turn, "Alice");
  assert.equal(start.data.playerX, "Alice");
  assert.equal(start.data.playerO, undefined);

  const first = move(start, "alice", 0, "X");
  assert.equal(first.ok, true);
  assert.equal(first.game.turn, "bob");
  assert.equal(first.game.data.playerO, "bob");

  const second = move(first.game, "bob", 4, "O");
  assert.equal(second.ok, true);
  assert.equal(second.game.turn, "Alice");
  assert.equal(second.game.data.movesCount, 2);
});

test("friend Tic-Tac-Toe detects every row, column, and diagonal win", () => {
  const winningLines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  for (const line of winningLines) {
    let game = createFriendGame();
    const fillers = Array.from({ length: 9 }, (_, index) => index)
      .filter((index) => !line.includes(index));
    const sequence = [
      [line[0], "X"],
      [fillers[0], "O"],
      [line[1], "X"],
      [fillers[1], "O"],
      [line[2], "X"],
    ];

    for (const [index, symbol] of sequence) {
      const player = symbol === "X" ? "alice" : "bob";
      const result = move(game, player, index, symbol);
      assert.equal(result.ok, true, `expected legal move for winning line ${line.join(",")}`);
      game = result.game;
    }

    assert.equal(game.state, "finished");
    assert.equal(game.winner, "Alice");
    assert.deepEqual(game.data.winningLine, line);
    assert.equal(game.turn, "");
  }
});

test("friend Tic-Tac-Toe detects a draw and locks the finished board", () => {
  let game = createFriendGame();
  const sequence = [
    [0, "alice", "X"],
    [1, "bob", "O"],
    [2, "alice", "X"],
    [4, "bob", "O"],
    [3, "alice", "X"],
    [5, "bob", "O"],
    [7, "alice", "X"],
    [6, "bob", "O"],
    [8, "alice", "X"],
  ];

  for (const [index, player, symbol] of sequence) {
    const result = move(game, player, index, symbol);
    assert.equal(result.ok, true);
    game = result.game;
  }

  assert.equal(game.state, "finished");
  assert.equal(game.winner, "draw");
  assert.deepEqual(game.data.winningLine, []);
  assert.equal(game.turn, "");

  const afterFinish = move(game, "bob", 0, "O");
  assert.equal(afterFinish.ok, false);
  assert.match(afterFinish.reason, /finished/i);
});

test("Tic-Tac-Toe rejects out-of-turn, non-player, occupied, and multi-cell moves", () => {
  const start = createFriendGame();
  assert.equal(move(start, "bob", 0, "O").ok, false);
  assert.equal(move(start, "charlie", 0, "X").ok, false);

  const first = move(start, "alice", 0, "X");
  assert.equal(first.ok, true);
  assert.equal(move(first.game, "bob", 0, "O").ok, false);
  assert.equal(applyGameMove(first.game, "bob", {
    board: ["X", "O", "O", null, null, null, null, null, null],
  }).ok, false);
});

test("Tic-Tac-Toe rejects malformed boards and impossible stored game states", () => {
  const start = createFriendGame();
  assert.equal(applyGameMove(start, "alice", { board: ["X"] }).ok, false);
  assert.equal(applyGameMove(start, "alice", {
    board: ["X", "Z", null, null, null, null, null, null, null],
  }).ok, false);
  assert.equal(applyGameMove(start, "alice", {
    board: ["X", "X", "X", "O", "O", "O", null, null, null],
  }).ok, false);

  const corrupted = {
    ...start,
    data: {
      ...start.data,
      board: ["X", "X", "X", "O", "O", null, null, null, null],
    },
  };
  const result = move(corrupted, "alice", 3, "X");
  assert.equal(result.ok, false);
  assert.match(result.reason, /finished/i);
});

test("group Tic-Tac-Toe only allows an opponent to join after the opening X", () => {
  const start = createGroupGame();
  assert.equal(move(start, "bob", 0, "O").ok, false);

  const opening = move(start, "alice", 0, "X");
  assert.equal(opening.ok, true);
  assert.equal(opening.game.turn, null);
  assert.equal(opening.game.data.playerO, null);

  const joined = move(opening.game, "bob", 4, "O");
  assert.equal(joined.ok, true);
  assert.equal(joined.game.data.playerO, "bob");
  assert.equal(joined.game.turn, "Alice");

  const thirdPlayer = move(joined.game, "charlie", 1, "O");
  assert.equal(thirdPlayer.ok, false);
  assert.match(thirdPlayer.reason, /not a player/i);
});


function createRpsGame() {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "Alice",
    to: "bob",
    toType: "friend",
    game: { gameType: "rps" },
  });
  assert.equal(result.ok, true);
  return result.game;
}

test("Rock Paper Scissors locks both player choices and resolves the best-of-three winner", () => {
  let game = createRpsGame();
  for (let round = 0; round < 3; round++) {
    const first = applyGameMove(game, "alice", { move: "rock" });
    assert.equal(first.ok, true);
    assert.equal(first.game.state, "in_progress");
    assert.equal(first.game.data.p1Move, "rock");
    const second = applyGameMove(first.game, "bob", { move: "scissors" });
    assert.equal(second.ok, true);
    game = second.game;
    if (round < 2) assert.equal(game.state, "in_progress");
  }
  assert.equal(game.state, "finished");
  assert.equal(game.winner, "Alice");
  assert.equal(game.data.p2Move, "scissors");
});


test("Rock Paper Scissors handles best-of-three draws and rejects invalid or repeated moves", () => {
  let game = createRpsGame();
  assert.equal(applyGameMove(game, "alice", { move: "lizard" }).ok, false);
  for (let round = 0; round < 3; round++) {
    const first = applyGameMove(game, "alice", { move: "paper" });
    assert.equal(first.ok, true);
    assert.equal(applyGameMove(first.game, "alice", { move: "rock" }).ok, false);
    const second = applyGameMove(first.game, "bob", { move: "paper" });
    assert.equal(second.ok, true);
    game = second.game;
    if (round < 2) assert.equal(game.state, "in_progress");
  }
  assert.equal(game.state, "finished");
  assert.equal(game.winner, "draw");
  assert.equal(applyGameMove(game, "bob", { move: "scissors" }).ok, false);
});

