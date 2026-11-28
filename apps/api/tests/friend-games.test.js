"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { applyGameMove, createGameChallenge } = require("../server/realtime/game-rules");

function friendGame(randomValue = 0) {
  const result = createGameChallenge({
    userKey: "alice",
    userDisplayName: "alice",
    to: "bob",
    toType: "friend",
    game: { gameType: "tictactoe", id: "ttt-friend-test" },
  }, { randomInt: () => randomValue });
  assert.equal(result.ok, true);
  return result.game;
}

function boardWith(...moves) {
  const board = Array(9).fill(null);
  for (const [index, symbol] of moves) board[index] = symbol;
  return board;
}

test("friend Tic-Tac-Toe randomly assigns X/O and gives X the first turn", () => {
  for (const [randomValue, expectedX, expectedO] of [
    [0, "alice", "bob"],
    [1, "bob", "alice"],
  ]) {
    const game = friendGame(randomValue);

    assert.equal(game.gameType, "tictactoe");
    assert.equal(game.createdBy, "alice");
    assert.equal(game.opponent, "bob");
    assert.equal(game.state, "in_progress");
    assert.equal(game.turn, expectedX);
    assert.deepEqual(game.data.board, Array(9).fill(null));
    assert.equal(game.data.playerX, expectedX);
    assert.equal(game.data.playerO, expectedO);
  }
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

test("rematch controls reject chat members who are not assigned players", () => {
  const finished = {
    ...friendGame(),
    state: "finished",
    winner: "alice",
  };

  for (const action of ["rematch_request", "rematch_accept", "rematch_decline", "rematch_cancel", "rematch", "leave_room"]) {
    const result = applyGameMove(finished, "mallory", { action });
    assert.equal(result.ok, false, action + " must reject a non-player");
    assert.match(result.reason, /not a player/i);
  }
});

test("rematch requests require a finished game and accept only the other player's live request", () => {
  const active = friendGame();
  const earlyRequest = applyGameMove(active, "alice", { action: "rematch_request" });
  assert.equal(earlyRequest.ok, false);
  assert.match(earlyRequest.reason, /finish the current game/i);

  const finished = { ...active, state: "finished", winner: "alice" };
  const request = applyGameMove(finished, "alice", { action: "rematch_request" });
  assert.equal(request.ok, true);
  assert.equal(request.game.data.rematch.status, "pending");

  const duplicateRequest = applyGameMove(request.game, "alice", { action: "rematch_request" });
  assert.equal(duplicateRequest.ok, true);
  assert.equal(duplicateRequest.game.data.rematch.requestedBy, "alice");

  const selfAccept = applyGameMove(request.game, "alice", { action: "rematch_accept" });
  assert.equal(selfAccept.ok, false);

  const bypassRequest = applyGameMove(finished, "bob", { action: "rematch" });
  assert.equal(bypassRequest.ok, false);

  const accepted = applyGameMove(request.game, "bob", { action: "rematch_accept" });
  assert.equal(accepted.ok, true);
  assert.equal(accepted.game.state, "in_progress");
  assert.deepEqual(accepted.game.data.board, Array(9).fill(null));
  assert.equal(accepted.game.data.rematch, null);

  const duplicateAccept = applyGameMove(accepted.game, "bob", { action: "rematch_accept" });
  assert.equal(duplicateAccept.ok, false);
});

test("only the requester can cancel a pending rematch and cancellation prevents acceptance", () => {
  const finished = { ...friendGame(), state: "finished", winner: "alice" };
  const request = applyGameMove(finished, "alice", { action: "rematch_request" });
  assert.equal(request.ok, true);

  const opponentCancel = applyGameMove(request.game, "bob", { action: "rematch_cancel" });
  assert.equal(opponentCancel.ok, false);
  assert.match(opponentCancel.reason, /only the player who requested/i);

  const cancelled = applyGameMove(request.game, "alice", { action: "rematch_cancel" });
  assert.equal(cancelled.ok, true);
  assert.equal(cancelled.game.data.rematch.status, "cancelled");
  assert.equal(cancelled.game.data.rematch.cancelledBy, "alice");
  assert.equal(applyGameMove(cancelled.game, "bob", { action: "rematch_accept" }).ok, false);
});

test("expired rematch requests cannot be accepted or declined", () => {
  const finished = { ...friendGame(), state: "finished", winner: "alice" };
  const request = applyGameMove(finished, "alice", { action: "rematch_request" });
  assert.equal(request.ok, true);
  const expired = {
    ...request.game,
    data: {
      ...request.game.data,
      rematch: { ...request.game.data.rematch, expiresAt: Date.now() - 1 },
    },
  };

  assert.equal(applyGameMove(expired, "bob", { action: "rematch_accept" }).ok, false);
  assert.equal(applyGameMove(expired, "bob", { action: "rematch_decline" }).ok, false);
});
