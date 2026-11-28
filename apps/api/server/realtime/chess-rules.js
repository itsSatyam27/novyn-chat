"use strict";

const START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
const KNIGHT = [-33, -31, -18, -14, 14, 18, 31, 33];
const BISHOP = [-17, -15, 15, 17];
const ROOK = [-16, -1, 1, 16];
const KING = [-17, -16, -15, -1, 1, 15, 16, 17];
const on = (square) => square >= 0 && square < 128 && (square & 0x88) === 0;
const color = (piece) => !piece || piece === "." ? 0 : piece === piece.toUpperCase() ? 1 : -1;
const squareIndex = (square) => {
  if (!/^[a-h][1-8]$/.test(square)) return -1;
  return (8 - Number(square[1])) * 16 + square.charCodeAt(0) - 97;
};
const squareName = (index) => String.fromCharCode(97 + (index & 7)) + (8 - (index >> 4));

function parseFen(fen = START_FEN) {
  const fields = String(fen).trim().split(/\s+/);
  if (fields.length < 4 || fields.length > 6 || !/^[wb]$/.test(fields[1]) ||
      !/^(?:-|K?Q?k?q?)$/.test(fields[2]) || !/^(?:-|[a-h][36])$/.test(fields[3])) {
    throw new Error("Invalid chess position.");
  }
  const board = Array(128).fill(".");
  const ranks = fields[0].split("/");
  if (ranks.length !== 8) throw new Error("Invalid chess position.");
  let whiteKings = 0, blackKings = 0;
  ranks.forEach((rank, row) => {
    let file = 0;
    for (const token of rank) {
      if (/^[1-8]$/.test(token)) file += Number(token);
      else if (/^[prnbqkPRNBQK]$/.test(token) && file < 8) {
        board[row * 16 + file] = token;
        if (token === "K") whiteKings += 1;
        if (token === "k") blackKings += 1;
        file += 1;
      } else throw new Error("Invalid chess position.");
    }
    if (file !== 8) throw new Error("Invalid chess position.");
  });
  if (whiteKings !== 1 || blackKings !== 1) throw new Error("Invalid chess position.");
  const halfmove = Number(fields[4] || 0);
  const fullmove = Number(fields[5] || 1);
  if (!Number.isInteger(halfmove) || halfmove < 0 || !Number.isInteger(fullmove) || fullmove < 1) {
    throw new Error("Invalid chess position.");
  }
  return {
    board,
    turn: fields[1] === "w" ? 1 : -1,
    castling: fields[2] === "-" ? "" : fields[2],
    ep: fields[3] === "-" ? -1 : squareIndex(fields[3]),
    halfmove,
    fullmove,
  };
}

function attacked(state, target, byColor) {
  const { board } = state;
  for (let from = 0; from < 128; from += 1) {
    if (!on(from) || color(board[from]) !== byColor) continue;
    const piece = board[from].toLowerCase();
    if (piece === "p") {
      if (target === from - 16 * byColor - 1 || target === from - 16 * byColor + 1) return true;
      continue;
    }
    const directions = piece === "n" ? KNIGHT : piece === "b" ? BISHOP :
      piece === "r" ? ROOK : piece === "q" ? [...BISHOP, ...ROOK] : KING;
    for (const direction of directions) {
      for (let to = from + direction; on(to); to += direction) {
        if (to === target) return true;
        if (board[to] !== "." || piece === "n" || piece === "k") break;
      }
    }
  }
  return false;
}

function inCheck(state, side = state.turn) {
  const king = state.board.findIndex((piece) => piece === (side === 1 ? "K" : "k"));
  return king < 0 || attacked(state, king, -side);
}

function applyUnchecked(state, move) {
  const [from, to, promotion = "", flags = ""] = move;
  const board = state.board.slice();
  const piece = board[from];
  const captured = flags === "ep" ? (state.turn === 1 ? board[to + 16] : board[to - 16]) : board[to];
  board[from] = ".";
  board[to] = promotion ? (state.turn === 1 ? promotion.toUpperCase() : promotion) : piece;
  if (flags === "ep") board[to + (state.turn === 1 ? 16 : -16)] = ".";
  if (flags === "castle") {
    const rookFrom = to > from ? from + 3 : from - 4;
    const rookTo = to > from ? from + 1 : from - 1;
    board[rookTo] = board[rookFrom];
    board[rookFrom] = ".";
  }
  let castling = state.castling;
  const remove = (rights) => { for (const right of rights) castling = castling.replace(right, ""); };
  if (piece === "K") remove("KQ");
  if (piece === "k") remove("kq");
  const rookRights = { 112: "Q", 119: "K", 0: "q", 7: "k" };
  if (piece.toLowerCase() === "r" && rookRights[from]) remove(rookRights[from]);
  if (captured && captured.toLowerCase() === "r" && rookRights[to]) remove(rookRights[to]);
  const next = {
    board,
    turn: -state.turn,
    castling: castling || "",
    ep: piece.toLowerCase() === "p" && Math.abs(to - from) === 32 ? (from + to) / 2 : -1,
    halfmove: piece.toLowerCase() === "p" || captured !== "." || flags === "ep" ? 0 : state.halfmove + 1,
    fullmove: state.fullmove + (state.turn === -1 ? 1 : 0),
  };
  return next;
}

function pseudoMoves(state) {
  const moves = [];
  const add = (from, to, flags = "") => {
    if (!on(to) || color(state.board[to]) === state.turn || state.board[to].toLowerCase() === "k") return;
    if (state.board[from].toLowerCase() === "p" && (to >> 4 === 0 || to >> 4 === 7)) {
      for (const promotion of ["q", "r", "b", "n"]) moves.push([from, to, promotion, flags]);
    } else moves.push([from, to, "", flags]);
  };
  for (let from = 0; from < 128; from += 1) {
    if (!on(from) || color(state.board[from]) !== state.turn) continue;
    const piece = state.board[from].toLowerCase();
    if (piece === "p") {
      const step = -16 * state.turn;
      const one = from + step;
      if (on(one) && state.board[one] === ".") {
        add(from, one);
        const homeRow = state.turn === 1 ? 6 : 1;
        const two = one + step;
        if ((from >> 4) === homeRow && state.board[two] === ".") add(from, two);
      }
      for (const fileStep of [-1, 1]) {
        const to = one + fileStep;
        if (!on(to)) continue;
        if (color(state.board[to]) === -state.turn) add(from, to);
        else if (to === state.ep && state.board[to] === ".") add(from, to, "ep");
      }
      continue;
    }
    const directions = piece === "n" ? KNIGHT : piece === "b" ? BISHOP :
      piece === "r" ? ROOK : piece === "q" ? [...BISHOP, ...ROOK] : KING;
    for (const direction of directions) {
      for (let to = from + direction; on(to); to += direction) {
        if (color(state.board[to]) === state.turn) break;
        add(from, to);
        if (state.board[to] !== "." || piece === "n" || piece === "k") break;
      }
    }
    if (piece === "k" && !inCheck(state)) {
      const home = state.turn === 1 ? 116 : 4;
      const rook = state.turn === 1 ? "R" : "r";
      const kingRight = state.turn === 1 ? "K" : "k";
      const queenRight = state.turn === 1 ? "Q" : "q";
      if (from === home && state.castling.includes(kingRight) &&
          state.board[home + 3] === rook && state.board[home + 1] === "." &&
          state.board[home + 2] === "." &&
          !attacked(state, home + 1, -state.turn) && !attacked(state, home + 2, -state.turn)) {
        add(from, home + 2, "castle");
      }
      if (from === home && state.castling.includes(queenRight) &&
          state.board[home - 4] === rook && state.board[home - 1] === "." &&
          state.board[home - 2] === "." && state.board[home - 3] === "." &&
          !attacked(state, home - 1, -state.turn) && !attacked(state, home - 2, -state.turn)) {
        add(from, home - 2, "castle");
      }
    }
  }
  return moves;
}

function legalMoves(state) {
  return pseudoMoves(state).filter((move) => !inCheck(applyUnchecked(state, move), state.turn));
}

function toUci(move) {
  return squareName(move[0]) + squareName(move[1]) + (move[2] || "");
}

function toFen(state) {
  const ranks = [];
  for (let row = 0; row < 8; row += 1) {
    let rank = "", empty = 0;
    for (let file = 0; file < 8; file += 1) {
      const piece = state.board[row * 16 + file];
      if (piece === ".") empty += 1;
      else { if (empty) rank += String(empty); empty = 0; rank += piece; }
    }
    if (empty) rank += String(empty);
    ranks.push(rank);
  }
  return ranks.join("/") + " " + (state.turn === 1 ? "w" : "b") + " " +
    (state.castling || "-") + " " + (state.ep < 0 ? "-" : squareName(state.ep)) +
    " " + state.halfmove + " " + state.fullmove;
}

function positionKey(state) {
  return toFen({ ...state, halfmove: 0, fullmove: 1 }).split(" ").slice(0, 4).join(" ");
}

function insufficientMaterial(state) {
  const remaining = [];
  for (let i = 0; i < 128; i += 1) {
    if (!on(i) || state.board[i] === "." || state.board[i].toLowerCase() === "k") continue;
    remaining.push({ type: state.board[i].toLowerCase(), color: ((i >> 4) + (i & 7)) % 2 });
  }
  return remaining.length === 0 ||
    (remaining.length === 1 && ["b", "n"].includes(remaining[0].type)) ||
    (remaining.every((piece) => piece.type === "b") &&
      new Set(remaining.map((piece) => piece.color)).size === 1);
}

function evaluate(state, history = []) {
  const moves = legalMoves(state);
  const check = inCheck(state);
  if (!moves.length) return check
    ? { done: true, result: state.turn === 1 ? "black" : "white", reason: "checkmate" }
    : { done: true, result: "draw", reason: "stalemate" };
  if (insufficientMaterial(state)) return { done: true, result: "draw", reason: "insufficient_material" };
  const key = positionKey(state);
  const repetitions = history.filter((item) => item === key).length;
  if (state.halfmove >= 150 || repetitions >= 5) {
    return { done: true, result: "draw", reason: state.halfmove >= 150 ? "seventy_five_move_rule" : "fivefold_repetition" };
  }
  return { done: false, result: null, reason: check ? "check" : "playing" };
}

function playUci(fen, uci) {
  const state = parseFen(fen);
  if (typeof uci !== "string" || !/^[a-h][1-8][a-h][1-8][qrbn]?$/.test(uci)) {
    return { ok: false, reason: "Invalid chess move." };
  }
  const legal = legalMoves(state);
  const move = legal.find((candidate) => toUci(candidate) === uci);
  if (!move) return { ok: false, reason: "Illegal chess move." };
  const next = applyUnchecked(state, move);
  return { ok: true, fen: toFen(next), move: uci, check: inCheck(next) };
}

module.exports = {
  START_FEN,
  parseFen,
  toFen,
  legalMoves,
  toUci,
  playUci,
  evaluate,
  positionKey,
  inCheck,
};
