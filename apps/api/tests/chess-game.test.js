"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const chess = require("../server/realtime/chess-rules");
const { applyGameMove, createGameChallenge } = require("../server/realtime/game-rules");

function playLine(fen, moves) {
  let current = fen;
  for (const move of moves) {
    const result = chess.playUci(current, move);
    assert.equal(result.ok, true, move + " should be legal");
    current = result.fen;
  }
  return current;
}

test("standard Chess position exposes twenty legal opening moves", () => {
  const start = chess.parseFen(chess.START_FEN);
  assert.equal(chess.legalMoves(start).length, 20);
  assert.equal(chess.toFen(start), chess.START_FEN);
});

test("Chess engine validates turns and rejects illegal moves", () => {
  assert.equal(chess.playUci(chess.START_FEN, "e2e5").ok, false);
  const after = chess.playUci(chess.START_FEN, "e2e4");
  assert.equal(after.ok, true);
  assert.equal(chess.parseFen(after.fen).turn, -1);
});

test("Chess engine supports castling, en passant and promotion", () => {
  const castleFen = playLine(chess.START_FEN, [
    "e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "e1g1",
  ]);
  assert.equal(chess.parseFen(castleFen).board[118], "K");
  assert.equal(chess.parseFen(castleFen).board[117], "R");

  const enPassantFen = playLine(chess.START_FEN, [
    "e2e4", "a7a6", "e4e5", "d7d5", "e5d6",
  ]);
  assert.equal(chess.parseFen(enPassantFen).board[35], "P");
  assert.equal(chess.parseFen(enPassantFen).board[51], ".");

  const promotion = chess.playUci("4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7a8q");
  assert.equal(promotion.ok, true);
  assert.equal(chess.parseFen(promotion.fen).board[0], "Q");
});

test("Chess engine detects checkmate and stalemate", () => {
  const foolMate = playLine(chess.START_FEN, ["f2f3", "e7e5", "g2g4", "d8h4"]);
  assert.deepEqual(chess.evaluate(chess.parseFen(foolMate)), {
    done: true, result: "black", reason: "checkmate",
  });

  const stalemate = chess.parseFen("7k/5K2/6Q1/8/8/8/8/8 b - - 0 1");
  assert.deepEqual(chess.evaluate(stalemate), {
    done: true, result: "draw", reason: "stalemate",
  });
});

test("Chess challenge is a one-to-one match with server-generated legal moves", () => {
  const created = createGameChallenge({
    userKey: "alice",
    userDisplayName: "Alice",
    to: "bob",
    toType: "friend",
    game: { gameType: "chess" },
  });
  assert.equal(created.ok, true);
  assert.equal(created.game.gameType, "chess");
  assert.equal(created.game.turn, "alice");
  assert.equal(created.game.data.white, "alice");
  assert.equal(created.game.data.black, "bob");
  assert.equal(created.game.data.legalMoves.length, 20);

  const group = createGameChallenge({
    userKey: "alice",
    userDisplayName: "Alice",
    to: "club",
    toType: "group",
    game: { gameType: "chess" },
  });
  assert.equal(group.ok, false);
});

test("Chess clocks start when the room opens, not when an invite is created", () => {
  const created = createGameChallenge({
    userKey: "alice", userDisplayName: "alice", to: "bob", toType: "friend",
    game: { gameType: "chess" },
  }).game;
  assert.equal(created.data.lastMoveAt, 0);
  const started = applyGameMove(created, "alice", { action: "start_clock" });
  assert.equal(started.ok, true);
  assert.ok(started.game.data.lastMoveAt > 0);
  const startedAt = started.game.data.lastMoveAt;
  const repeated = applyGameMove(started.game, "bob", { action: "start_clock" });
  assert.equal(repeated.ok, true);
  assert.equal(repeated.game.data.lastMoveAt, startedAt);
});

test("Chess game accepts legal alternating moves and rejects out-of-turn or illegal moves", () => {
  const created = createGameChallenge({
    userKey: "alice", userDisplayName: "alice", to: "bob", toType: "friend",
    game: { gameType: "chess" },
  }).game;

  const wrongTurn = applyGameMove(created, "bob", { move: "e7e5" });
  assert.equal(wrongTurn.ok, false);
  assert.match(wrongTurn.reason, /turn/i);

  const illegal = applyGameMove(created, "alice", { move: "e2e5" });
  assert.equal(illegal.ok, false);

  const first = applyGameMove(created, "alice", { move: "e2e4" });
  assert.equal(first.ok, true);
  assert.equal(first.game.turn, "bob");
  assert.equal(first.game.data.fen.split(" ")[1], "b");
  assert.equal(first.game.data.moves[0], "e2e4");
  assert.equal(first.game.data.legalMoves.length, 20);

  const second = applyGameMove(first.game, "bob", { move: "e7e5" });
  assert.equal(second.ok, true);
  assert.equal(second.game.turn, "alice");
  assert.deepEqual(second.game.data.moves, ["e2e4", "e7e5"]);
});

test("Chess draw offer, resignation and rematch transitions are participant-only", () => {
  const created = createGameChallenge({
    userKey: "alice", userDisplayName: "alice", to: "bob", toType: "friend",
    game: { gameType: "chess" },
  }).game;
  assert.equal(applyGameMove(created, "mallory", { action: "resign" }).ok, false);
  const offer = applyGameMove(created, "alice", { action: "draw_offer" });
  assert.equal(offer.ok, true);
  const accepted = applyGameMove(offer.game, "bob", { action: "draw_accept" });
  assert.equal(accepted.ok, true);
  assert.equal(accepted.game.state, "finished");
  assert.equal(accepted.game.winner, "draw");

  const resigned = applyGameMove(created, "alice", { action: "resign" });
  assert.equal(resigned.game.state, "finished");
  assert.equal(resigned.game.winner, "bob");
  const requested = applyGameMove(resigned.game, "alice", { action: "rematch_request" });
  const rematch = applyGameMove(requested.game, "bob", { action: "rematch_accept" });
  assert.equal(rematch.ok, true);
  assert.equal(rematch.game.state, "in_progress");
  assert.equal(rematch.game.turn, "alice");
  assert.equal(rematch.game.data.moves.length, 0);
  assert.equal(rematch.game.data.legalMoves.length, 20);
});
