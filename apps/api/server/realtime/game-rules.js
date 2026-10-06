"use strict";

const GAME_TYPES = new Set(["tictactoe", "rps", "connect4"]);
const RPS_MOVES = new Set(["rock", "paper", "scissors"]);

function sameUser(a, b) {
  return String(a || "").trim().toLowerCase() === String(b || "").trim().toLowerCase();
}

function cloneData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? { ...data } : {};
}

function finishTicTacToe(board, playerX, playerO) {
  const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  for (const line of lines) {
    const [a, b, c] = line;
    if (board[a] && board[a] === board[b] && board[a] === board[c]) {
      return {
        state: "finished",
        winner: board[a] === "X" ? playerX : playerO,
        winningLine: line,
      };
    }
  }

  return board.every((cell) => cell !== null)
    ? { state: "finished", winner: "draw", winningLine: [] }
    : { state: "in_progress", winner: undefined, winningLine: [] };
}

function applyTicTacToe(game, userKey, moveData) {
  const current = cloneData(game.data);
  const board = Array.isArray(current.board) ? [...current.board] : Array(9).fill(null);
  if (board.length !== 9 || !Array.isArray(moveData.board) || moveData.board.length !== 9) {
    return { ok: false, reason: "Invalid Tic-Tac-Toe board." };
  }

  const playerX = current.playerX || game.createdBy;
  let playerO = current.playerO || game.opponent || null;

  if (game.state === "finished" || !sameUser(game.turn, userKey)) {
    return { ok: false, reason: "It is not your turn." };
  }

  if (sameUser(userKey, playerX)) {
    if (!playerX) return { ok: false, reason: "Invalid game players." };
  } else if (playerO) {
    if (!sameUser(userKey, playerO)) return { ok: false, reason: "You are not a player in this game." };
  } else {
    playerO = userKey;
  }

  const symbol = sameUser(userKey, playerX) ? "X" : "O";
  const requestedBoard = moveData.board;
  const changed = [];

  for (let i = 0; i < 9; i++) {
    if (requestedBoard[i] !== board[i]) changed.push(i);
  }

  if (changed.length !== 1) {
    return { ok: false, reason: "Invalid move." };
  }

  const index = changed[0];
  if (board[index] !== null || requestedBoard[index] !== symbol) {
    return { ok: false, reason: "Invalid move." };
  }

  for (let i = 0; i < 9; i++) {
    if (i !== index && requestedBoard[i] !== board[i]) {
      return { ok: false, reason: "Invalid board mutation." };
    }
  }

  const nextBoard = [...board];
  nextBoard[index] = symbol;
  const result = finishTicTacToe(nextBoard, playerX, playerO);

  return {
    ok: true,
    game: {
      ...game,
      state: result.state,
      turn: result.state === "finished" ? "" : symbol === "X" ? playerO : playerX,
      winner: result.winner,
      data: {
        ...current,
        board: nextBoard,
        playerX,
        playerO,
        winningLine: result.winningLine,
        movesCount: nextBoard.filter(Boolean).length,
      },
      lastMoveBy: userKey,
      updatedAt: Date.now(),
    },
  };
}

function applyRps(game, userKey, moveData) {
  const current = cloneData(game.data);
  if (game.state === "finished") return { ok: false, reason: "Game is already finished." };

  const move = moveData.move;
  if (!RPS_MOVES.has(move)) return { ok: false, reason: "Invalid RPS move." };

  const player1 = current.player1 || game.createdBy;
  let player2 = current.player2 || game.opponent || null;

  if (userKey === player1) {
    if (current.p1Move) return { ok: false, reason: "Your move is already locked." };
  } else if (player2) {
    if (userKey !== player2) return { ok: false, reason: "You are not a player in this game." };
    if (current.p2Move) return { ok: false, reason: "Your move is already locked." };
  } else {
    player2 = userKey;
  }

  const p1Move = sameUser(userKey, player1) ? move : current.p1Move;
  const p2Move = sameUser(userKey, player2) ? move : current.p2Move;
  if (!p1Move || !p2Move) {
    return {
      ok: true,
      game: {
        ...game,
        state: "in_progress",
        turn: p1Move ? player2 : player1,
        data: { ...current, player1, player2, p1Move, p2Move },
        lastMoveBy: userKey,
        updatedAt: Date.now(),
      },
    };
  }

  let winner = "draw";
  if (p1Move !== p2Move) {
    const p1Wins =
      (p1Move === "rock" && p2Move === "scissors") ||
      (p1Move === "paper" && p2Move === "rock") ||
      (p1Move === "scissors" && p2Move === "paper");
    winner = p1Wins ? player1 : player2;
  }

  return {
    ok: true,
    game: {
      ...game,
      state: "finished",
      turn: "",
      winner,
      data: { ...current, player1, player2, p1Move, p2Move },
      lastMoveBy: userKey,
      updatedAt: Date.now(),
    },
  };
}

function hasConnect4Win(board, chip) {
  const lines = [];
  const check = (r, c, dr, dc) => {
    const line = [];
    for (let i = 0; i < 4; i++) {
      const nr = r + dr * i;
      const nc = c + dc * i;
      if (nr < 0 || nr >= 6 || nc < 0 || nc >= 7) return null;
      const idx = nr * 7 + nc;
      if (board[idx] !== chip) return null;
      line.push(idx);
    }
    return line;
  };

  for (let r = 0; r < 6; r++) {
    for (let c = 0; c < 7; c++) {
      for (const [dr, dc] of [[0, 1], [1, 0], [1, 1], [1, -1]]) {
        const line = check(r, c, dr, dc);
        if (line) lines.push(line);
      }
    }
  }
  return lines[0] || null;
}

function applyConnect4(game, userKey, moveData) {
  const current = cloneData(game.data);
  const board = Array.isArray(current.board) ? [...current.board] : Array(42).fill(null);
  const requestedBoard = moveData.board;
  if (board.length !== 42 || !Array.isArray(requestedBoard) || requestedBoard.length !== 42) {
    return { ok: false, reason: "Invalid Connect 4 board." };
  }
  if (game.state === "finished" || !sameUser(game.turn, userKey)) {
    return { ok: false, reason: "It is not your turn." };
  }

  const player1 = current.player1 || game.createdBy;
  let player2 = current.player2 || game.opponent || null;
  if (userKey === player1) {
    // creator is player 1
  } else if (player2) {
    if (userKey !== player2) return { ok: false, reason: "You are not a player in this game." };
  } else {
    player2 = userKey;
  }

  const chip = userKey === player1 ? "R" : "Y";
  const changed = [];
  for (let i = 0; i < 42; i++) {
    if (requestedBoard[i] !== board[i]) changed.push(i);
  }
  if (changed.length !== 1) return { ok: false, reason: "Invalid move." };

  const index = changed[0];
  if (board[index] !== null || requestedBoard[index] !== chip) {
    return { ok: false, reason: "Invalid move." };
  }

  const col = index % 7;
  const row = Math.floor(index / 7);
  if (row < 5 && board[index + 7] === null) {
    return { ok: false, reason: "Invalid move: chip must fall to the lowest open row." };
  }

  const nextBoard = [...board];
  nextBoard[index] = chip;
  const winningLine = hasConnect4Win(nextBoard, chip);
  const full = nextBoard.every((cell) => cell !== null);
  const finished = Boolean(winningLine) || full;

  return {
    ok: true,
    game: {
      ...game,
      state: finished ? "finished" : "in_progress",
      turn: finished ? "" : chip === "R" ? player2 : player1,
      winner: winningLine ? (chip === "R" ? player1 : player2) : full ? "draw" : undefined,
      data: {
        ...current,
        board: nextBoard,
        player1,
        player2,
        winningLine: winningLine || [],
      },
      lastMoveBy: userKey,
      updatedAt: Date.now(),
    },
  };
}

function applyGameMove(game, userKey, moveData) {
  if (!game || !GAME_TYPES.has(game.gameType)) return { ok: false, reason: "Unsupported game." };
  if (!moveData || typeof moveData !== "object" || Array.isArray(moveData)) {
    return { ok: false, reason: "Invalid move payload." };
  }

  switch (game.gameType) {
    case "tictactoe":
      return applyTicTacToe(game, userKey, moveData);
    case "rps":
      return applyRps(game, userKey, moveData);
    case "connect4":
      return applyConnect4(game, userKey, moveData);
    default:
      return { ok: false, reason: "Unsupported game." };
  }
}

function createGameChallenge(input = {}) {
  const userKey = String(input.userKey || "").trim().toLowerCase();
  const userName = String(input.userDisplayName || input.userKey || "").trim();
  const toType = input.toType === "group" ? "group" : "friend";
  const to = String(input.to || "").trim();
  const requested = input.game;

  if (!userKey || !userName || !requested || typeof requested !== "object" || Array.isArray(requested)) {
    return { ok: false, reason: "Invalid game challenge." };
  }

  const gameType = String(requested.gameType || "");
  if (!GAME_TYPES.has(gameType)) return { ok: false, reason: "Unsupported game." };

  const titles = {
    tictactoe: "Tic-Tac-Toe",
    rps: "Rock • Paper • Scissors",
    connect4: "Connect 4",
  };

  const board = gameType === "tictactoe" ? Array(9).fill(null) : gameType === "connect4" ? Array(42).fill(null) : undefined;
  const data = gameType === "tictactoe"
    ? { board, playerX: userName }
    : gameType === "connect4"
    ? { board, player1: userName }
    : { player1: userName };

  return {
    ok: true,
    game: {
      id: typeof requested.id === "string" && requested.id.length <= 128 ? requested.id : `game_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      gameType,
      title: titles[gameType],
      createdBy: userName,
      opponent: toType === "friend" ? to : undefined,
      state: "in_progress",
      turn: userName,
      data,
    },
  };
}

module.exports = { applyGameMove, createGameChallenge };
