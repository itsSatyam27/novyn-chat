"use strict";

const crypto = require("crypto");
const chessRules = require("./chess-rules");
const GAME_TYPES = new Set(["tictactoe", "rps", "rajamantri", "chess"]);
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
  if (!playerX || (playerO && sameUser(playerX, playerO))) {
    return { ok: false, reason: "Invalid game players." };
  }

  if (!board.every((cell) => cell === null || cell === "X" || cell === "O")) {
    return { ok: false, reason: "Invalid Tic-Tac-Toe board." };
  }
  const xCount = board.filter((cell) => cell === "X").length;
  const oCount = board.filter((cell) => cell === "O").length;
  if (xCount !== oCount && xCount !== oCount + 1) {
    return { ok: false, reason: "Invalid Tic-Tac-Toe board state." };
  }

  // Do not accept moves against a board that has already won or drawn, even
  // if a stale/corrupt message still says the game is in progress.
  if (finishTicTacToe(board, playerX, playerO).state === "finished") {
    return { ok: false, reason: "Game is already finished." };
  }

  // A group game has no player O until the creator makes the opening X move.
  // Only the next turn (one X, zero O, null turn) may claim that slot.
  const isPlayerX = sameUser(userKey, playerX);
  const isPlayerO = Boolean(playerO && sameUser(userKey, playerO));
  if (!isPlayerX && playerO && !isPlayerO) {
    return { ok: false, reason: "You are not a player in this game." };
  }

  const waitingForGroupPlayer =
    !playerO &&
    !isPlayerX &&
    xCount === 1 &&
    oCount === 0 &&
    game.turn == null;
  if (game.state === "finished" || (!sameUser(game.turn, userKey) && !waitingForGroupPlayer)) {
    return { ok: false, reason: "It is not your turn." };
  }

  if (isPlayerX) {
    // The creator is always X.
  } else if (playerO) {
    if (!isPlayerO) {
      return { ok: false, reason: "You are not a player in this game." };
    }
  } else {
    playerO = userKey;
  }

  const symbol = sameUser(userKey, playerX) ? "X" : "O";
  const expectedSymbol = xCount === oCount ? "X" : "O";
  if (symbol !== expectedSymbol) {
    return { ok: false, reason: "It is not your turn." };
  }

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
  const isPlayer1 = sameUser(userKey, player1);
  if (!isPlayer1 && player2 && !sameUser(userKey, player2)) {
    return { ok: false, reason: "You are not a player in this game." };
  }
  if (!isPlayer1 && !player2) player2 = userKey;

  const target = Math.max(1, Math.min(10, Number(current.target) || 3));
  const p1Score = Math.max(0, Number(current.p1Score) || 0);
  const p2Score = Math.max(0, Number(current.p2Score) || 0);
  const round = Math.max(1, Number(current.round) || 1);
  const currentRoundResolved = current.roundResolved === true;
  const expectedRound = round + (currentRoundResolved ? 1 : 0);
  if (!Number.isInteger(moveData.round) || moveData.round !== expectedRound) {
    return { ok: false, reason: "This move belongs to an old or invalid round. Refresh the game and try again." };
  }

  // The first move after a revealed round opens the next round. The explicit
  // round number makes a delayed retry from the previous round harmless.
  const base = currentRoundResolved
    ? {
        ...current,
        round: round + 1,
        p1Move: null,
        p2Move: null,
        roundResolved: false,
        roundWinner: null,
        roundResolvedAt: null,
        roundMessage: null,
      }
    : current;
  const ownMove = isPlayer1 ? base.p1Move : base.p2Move;
  if (ownMove) return { ok: false, reason: "Your move is already locked." };

  const p1Move = isPlayer1 ? move : base.p1Move;
  const p2Move = isPlayer1 ? base.p2Move : move;
  const data = { ...base, player1, player2, target, p1Score, p2Score, p1Move, p2Move };
  if (!p1Move || !p2Move) {
    return {
      ok: true,
      game: {
        ...game,
        state: "in_progress",
        turn: "",
        winner: undefined,
        data,
        lastMoveBy: userKey,
        updatedAt: Date.now(),
      },
    };
  }

  let roundWinner = "draw";
  if (p1Move !== p2Move) {
    const p1Wins =
      (p1Move === "rock" && p2Move === "scissors") ||
      (p1Move === "paper" && p2Move === "rock") ||
      (p1Move === "scissors" && p2Move === "paper");
    roundWinner = p1Wins ? player1 : player2;
  }

  const nextP1Score = p1Score + (sameUser(roundWinner, player1) ? 1 : 0);
  const nextP2Score = p2Score + (sameUser(roundWinner, player2) ? 1 : 0);
  const matchWinner = nextP1Score >= target ? player1 : nextP2Score >= target ? player2 : undefined;
  const now = Date.now();

  return {
    ok: true,
    game: {
      ...game,
      state: matchWinner ? "finished" : "in_progress",
      turn: "",
      winner: matchWinner,
      data: {
        ...data,
        p1Score: nextP1Score,
        p2Score: nextP2Score,
        roundResolved: true,
        roundWinner,
        roundResolvedAt: now,
        roundMessage: roundWinner === "draw"
          ? "It's a tie"
          : `${roundWinner === player1 ? p1Move : p2Move} wins the round`,
      },
      lastMoveBy: userKey,
      updatedAt: now,
    },
  };
}

function handleRematchAction(game, userKey, moveData) {
  const current = cloneData(game.data);
  const player1 = current.player1 || current.playerX || game.createdBy;
  const player2 = current.player2 || current.playerO || game.opponent;
  const isPlayer1 = sameUser(userKey, player1);
  const isPlayer2 = Boolean(player2) && sameUser(userKey, player2);
  const now = Date.now();

  // A group-chat member is not automatically a game participant. Rematch
  // controls must be limited to the two players assigned to this game.
  if (!isPlayer1 && !isPlayer2) {
    return { ok: false, reason: "You are not a player in this game." };
  }

  if (moveData.action === "leave_room") {
    if (game.state === "finished") {
      return { ok: true, game };
    }
    const winner = isPlayer1 ? player2 : player1;
    // A group Tic-Tac-Toe creator may leave before anyone has claimed O.
    // Close that empty room as cancelled instead of trapping the creator.
    const forfeitWinner = winner || "draw";
    return {
      ok: true,
      game: {
        ...game,
        state: "finished",
        winner: forfeitWinner,
        turn: "",
        data: {
          ...current,
          playerLeft: userKey,
          forfeitedBy: userKey,
          rematch: {
            status: "opponent_left",
            leftBy: userKey,
            winner: forfeitWinner,
            outcome: winner ? "forfeit" : "cancelled_before_join",
          },
        },
        lastMoveBy: userKey,
        updatedAt: now,
      },
    };
  }

  if (moveData.action === "rematch_request") {
    if (game.state !== "finished") {
      return { ok: false, reason: "Finish the current game before requesting a rematch." };
    }
    if (!player1 || !player2 || sameUser(player1, player2) || current.playerLeft) {
      return { ok: false, reason: "A rematch is unavailable for this game." };
    }

    const existing = current.rematch;
    const existingExpiry = Number(existing?.expiresAt);
    if (existing?.status === "pending" && Number.isFinite(existingExpiry) && existingExpiry > now) {
      if (sameUser(existing.requestedBy, userKey)) {
        // A retried request from the same player is idempotent.
        return { ok: true, game };
      }
      return { ok: false, reason: "Your opponent has already requested a rematch." };
    }

    return {
      ok: true,
      game: {
        ...game,
        data: {
          ...current,
          rematch: {
            requestedBy: String(userKey || "").trim().toLowerCase(),
            requestedAt: now,
            expiresAt: now + 15000,
            status: "pending",
          },
        },
        updatedAt: now,
      },
    };
  }

  if (moveData.action === "rematch_cancel") {
    const pending = current.rematch;
    const expiresAt = Number(pending?.expiresAt);
    if (pending?.status !== "pending" || !Number.isFinite(expiresAt) || expiresAt <= now) {
      return { ok: false, reason: "The rematch request has expired or is no longer available." };
    }
    if (!sameUser(pending.requestedBy, userKey)) {
      return { ok: false, reason: "Only the player who requested the rematch can cancel it." };
    }
    return {
      ok: true,
      game: {
        ...game,
        data: {
          ...current,
          rematch: {
            ...pending,
            status: "cancelled",
            cancelledBy: String(userKey || "").trim().toLowerCase(),
            cancelledAt: now,
          },
        },
        updatedAt: now,
      },
    };
  }

  if (moveData.action === "rematch_decline" || moveData.action === "rematch_accept" || moveData.action === "rematch") {
    const pending = current.rematch;
    const expiresAt = Number(pending?.expiresAt);
    if (pending?.status !== "pending" || !Number.isFinite(expiresAt) || expiresAt <= now) {
      return { ok: false, reason: "The rematch request has expired or is no longer available." };
    }
    if (sameUser(pending.requestedBy, userKey)) {
      return { ok: false, reason: "You cannot respond to your own rematch request." };
    }

    if (moveData.action === "rematch_decline") {
      return {
        ok: true,
        game: {
          ...game,
          data: {
            ...current,
            rematch: {
              ...pending,
              status: "declined",
              declinedBy: String(userKey || "").trim().toLowerCase(),
            },
          },
          updatedAt: now,
        },
      };
    }
  }

  if (moveData.action === "rematch_accept" || moveData.action === "rematch") {
    if (game.state !== "finished" || current.playerLeft) {
      return { ok: false, reason: "This game is not ready for a rematch." };
    }
    if (moveData.action === "rematch_accept") {
      const pending = current.rematch;
      const expiresAt = Number(pending?.expiresAt);
      if (pending?.status !== "pending" || !Number.isFinite(expiresAt) || expiresAt <= now ||
          sameUser(pending.requestedBy, userKey)) {
        return { ok: false, reason: "The rematch request has expired or is no longer available." };
      }
    }

    if (game.gameType === "tictactoe") {
      return {
        ok: true,
        game: {
          ...game,
          state: "in_progress",
          winner: undefined,
          turn: player1,
          data: {
            ...current,
            board: Array(9).fill(null),
            p1Score: 0,
            p2Score: 0,
            winningLine: [],
            rematch: null,
          },
          lastMoveBy: userKey,
          updatedAt: now,
        },
      };
    }

    if (game.gameType === "chess") {
      const white = current.white || current.player1 || player1;
      const black = current.black || current.player2 || player2;
      const now = Date.now();
      return {
        ok: true,
        game: {
          ...game,
          state: "in_progress",
          winner: undefined,
          turn: white,
          data: {
            ...current,
            white,
            black,
            player1: white,
            player2: black,
            fen: chessRules.START_FEN,
            moves: [],
            legalMoves: chessRules.legalMoves(chessRules.parseFen(chessRules.START_FEN)).map(chessRules.toUci),
            canClaimDraw: false,
            positionHistory: [chessRules.positionKey(chessRules.parseFen(chessRules.START_FEN))],
            whiteTimeMs: current.clockMs || 300000,
            blackTimeMs: current.clockMs || 300000,
            lastMoveAt: now,
            drawOfferBy: null,
            endReason: null,
            rematch: null,
          },
          lastMoveBy: userKey,
          updatedAt: now,
        },
      };
    }

    if (game.gameType === "rps") {
      return {
        ok: true,
        game: {
          ...game,
          state: "in_progress",
          winner: undefined,
          turn: "",
          data: {
            ...current,
            round: 1,
            p1Score: 0,
            p2Score: 0,
            p1Move: null,
            p2Move: null,
            roundResolved: false,
            roundWinner: null,
            roundResolvedAt: null,
            roundMessage: null,
            rematch: null,
          },
          lastMoveBy: userKey,
          updatedAt: now,
        },
      };
    }
  }

  return { ok: false, reason: "Invalid rematch action." };
}


function applyChess(game, userKey, moveData) {
  const current = cloneData(game.data);
  const white = String(current.white || current.player1 || game.createdBy || "").trim().toLowerCase();
  const black = String(current.black || current.player2 || game.opponent || "").trim().toLowerCase();
  const actor = String(userKey || "").trim().toLowerCase();
  if (!white || !black || white === black || (actor !== white && actor !== black)) {
    return { ok: false, reason: "You are not a player in this game." };
  }
  if (game.state === "finished") return { ok: false, reason: "Game is already finished." };

  const now = Date.now();
  const finish = (winner, reason, data = current) => ({
    ok: true,
    game: {
      ...game,
      state: "finished",
      winner,
      turn: "",
      data: { ...data, endReason: reason, finishedAt: now },
      lastMoveBy: actor,
      updatedAt: now,
    },
  });

  if (moveData.action === "start_clock") {
    const startedAt = Number(current.lastMoveAt) || 0;
    if (startedAt > 0) return { ok: true, game };
    return {
      ok: true,
      game: {
        ...game,
        data: { ...current, lastMoveAt: now },
        updatedAt: now,
      },
    };
  }

  if (moveData.action === "resign") {
    return finish(actor === white ? black : white, "resignation");
  }
  if (moveData.action === "draw_offer") {
    if (current.drawOfferBy && current.drawOfferBy !== actor) {
      return { ok: false, reason: "Your opponent has already offered a draw." };
    }
    return {
      ok: true,
      game: { ...game, data: { ...current, drawOfferBy: actor }, updatedAt: now },
    };
  }
  if (moveData.action === "draw_decline") {
    if (!current.drawOfferBy || current.drawOfferBy === actor) {
      return { ok: false, reason: "There is no draw offer to decline." };
    }
    return {
      ok: true,
      game: { ...game, data: { ...current, drawOfferBy: null }, updatedAt: now },
    };
  }
  if (moveData.action === "draw_accept") {
    if (!current.drawOfferBy || current.drawOfferBy === actor) {
      return { ok: false, reason: "There is no opponent draw offer to accept." };
    }
    return finish("draw", "agreement", { ...current, drawOfferBy: null });
  }
  if (moveData.action === "claim_draw") {
    if (String(game.turn || "").trim().toLowerCase() !== actor) {
      return { ok: false, reason: "It is not your turn." };
    }
    const position = chessRules.parseFen(current.fen || chessRules.START_FEN);
    const history = Array.isArray(current.positionHistory) ? current.positionHistory : [];
    const repetitions = history.filter((entry) => entry === chessRules.positionKey(position)).length;
    if (position.halfmove < 100 && repetitions < 3) {
      return { ok: false, reason: "A draw cannot be claimed yet." };
    }
    return finish("draw", position.halfmove >= 100 ? "fifty_move_rule" : "threefold_repetition");
  }

  if (moveData.action === "claim_timeout") {
    const position = chessRules.parseFen(current.fen || chessRules.START_FEN);
    const clockMs = Math.max(0, Number(current.clockMs) || 300000);
    const whiteTimeMs = Math.max(0, Number(current.whiteTimeMs ?? clockMs) || 0);
    const blackTimeMs = Math.max(0, Number(current.blackTimeMs ?? clockMs) || 0);
    const elapsed = Math.max(0, now - Math.max(0, Number(current.lastMoveAt) || now));
    const remaining = (position.turn === 1 ? whiteTimeMs : blackTimeMs) - elapsed;
    if (remaining > 0) return { ok: false, reason: "The active player's clock has not expired." };
    return finish(position.turn === 1 ? black : white, "timeout", {
      ...current,
      whiteTimeMs: position.turn === 1 ? 0 : whiteTimeMs,
      blackTimeMs: position.turn === -1 ? 0 : blackTimeMs,
    });
  }

  if (!game.turn || String(game.turn).trim().toLowerCase() !== actor) {
    return { ok: false, reason: "It is not your turn." };
  }

  const fen = current.fen || chessRules.START_FEN;
  let position;
  try {
    position = chessRules.parseFen(fen);
  } catch (_) {
    return { ok: false, reason: "The saved chess position is invalid. Reopen the match." };
  }

  const clockMs = Math.max(0, Number(current.clockMs) || 300000);
  const whiteTimeMs = Math.max(0, Number(current.whiteTimeMs ?? clockMs) || 0);
  const blackTimeMs = Math.max(0, Number(current.blackTimeMs ?? clockMs) || 0);
  const elapsed = Math.max(0, now - Math.max(0, Number(current.lastMoveAt) || now));
  const remaining = (position.turn === 1 ? whiteTimeMs : blackTimeMs) - elapsed;
  if (remaining <= 0) {
    return finish(position.turn === 1 ? black : white, "timeout", {
      ...current,
      whiteTimeMs: position.turn === 1 ? 0 : whiteTimeMs,
      blackTimeMs: position.turn === -1 ? 0 : blackTimeMs,
    });
  }

  const played = chessRules.playUci(fen, moveData.move);
  if (!played.ok) return played;
  const nextPosition = chessRules.parseFen(played.fen);
  const history = Array.isArray(current.positionHistory) ? current.positionHistory.slice() : [];
  if (!history.length) {
    const start = chessRules.parseFen(fen);
    history.push(chessRules.positionKey(start));
  }
  history.push(chessRules.positionKey(nextPosition));
  const outcome = chessRules.evaluate(nextPosition, history);
  const nextWhiteTime = position.turn === 1 ? remaining : whiteTimeMs;
  const nextBlackTime = position.turn === -1 ? remaining : blackTimeMs;
  const nextPositionKey = chessRules.positionKey(nextPosition);
  const nextRepetitions = history.filter((entry) => entry === nextPositionKey).length;
  const nextData = {
    ...current,
    white,
    black,
    player1: white,
    player2: black,
    fen: played.fen,
    moves: [...(Array.isArray(current.moves) ? current.moves : []), played.move].slice(-500),
    legalMoves: outcome.done ? [] : chessRules.legalMoves(nextPosition).map(chessRules.toUci),
    canClaimDraw: !outcome.done && (nextPosition.halfmove >= 100 || nextRepetitions >= 3),
    positionHistory: history.slice(-500),
    whiteTimeMs: nextWhiteTime,
    blackTimeMs: nextBlackTime,
    lastMoveAt: now,
    drawOfferBy: null,
    lastMove: played.move,
    lastMoveAtClient: now,
    check: played.check,
    endReason: outcome.done ? outcome.reason : null,
  };
  const winner = outcome.result === "white" ? white : outcome.result === "black" ? black : outcome.result === "draw" ? "draw" : undefined;
  return {
    ok: true,
    game: {
      ...game,
      state: outcome.done ? "finished" : "in_progress",
      winner,
      turn: outcome.done ? "" : nextPosition.turn === 1 ? white : black,
      data: nextData,
      lastMoveBy: actor,
      updatedAt: now,
    },
  };
}

function applyGameMove(game, userKey, moveData) {
  if (!game || !GAME_TYPES.has(game.gameType)) return { ok: false, reason: "Unsupported game." };
  if (!moveData || typeof moveData !== "object" || Array.isArray(moveData)) {
    return { ok: false, reason: "Invalid move payload." };
  }

  if (
    moveData.action === "rematch" ||
    moveData.action === "rematch_request" ||
    moveData.action === "rematch_accept" ||
    moveData.action === "rematch_decline" ||
    moveData.action === "rematch_cancel" ||
    moveData.action === "leave_room"
  ) {
    return handleRematchAction(game, userKey, moveData);
  }

  if (game.gameType === "chess") return applyChess(game, userKey, moveData);

  switch (game.gameType) {
    case "tictactoe":
      return applyTicTacToe(game, userKey, moveData);
    case "rps":
      return applyRps(game, userKey, moveData);
    default:
      return { ok: false, reason: "Unsupported game." };
  }
}

function createGameChallenge(input = {}, { randomInt = crypto.randomInt } = {}) {
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
  if (gameType === "chess" && toType !== "friend") {
    return { ok: false, reason: "Chess is currently available for one-to-one matches only." };
  }

  const titles = { tictactoe: "Tic-Tac-Toe", rps: "Rock Paper Scissors", rajamantri: "Raja Mantri Chor Sipahi", chess: "Chess" };
  const board = gameType === "tictactoe" ? Array(9).fill(null) : undefined;
  const initialOpponent = toType === "friend" ? to : null;
  const randomizeTicTacToePlayers = gameType === "tictactoe" && Boolean(initialOpponent);
  const creatorIsX = !randomizeTicTacToePlayers || randomInt(2) === 0;
  const playerX = creatorIsX ? userName : initialOpponent;
  const playerO = creatorIsX ? initialOpponent : userName;
  const data = gameType === "tictactoe"
    ? { board, playerX, ...(playerO ? { playerO } : {}) }
    : gameType === "rps"
    ? { player1: userName, player2: initialOpponent, round: 1, p1Score: 0, p2Score: 0, target: 3 }
    : gameType === "chess"
    ? {
        white: userKey,
        black: String(to || "").trim().toLowerCase(),
        player1: userKey,
        player2: String(to || "").trim().toLowerCase(),
        whiteName: userName,
        blackName: initialOpponent || String(to || ""),
        fen: chessRules.START_FEN,
        moves: [],
        legalMoves: chessRules.legalMoves(chessRules.parseFen(chessRules.START_FEN)).map(chessRules.toUci),
        canClaimDraw: false,
        positionHistory: [chessRules.positionKey(chessRules.parseFen(chessRules.START_FEN))],
        clockMs: 300000,
        whiteTimeMs: 300000,
        blackTimeMs: 300000,
        lastMoveAt: 0,
        drawOfferBy: null,
      }
    : { host: userName, players: [userName], round: 1, target: 5 };

  return {
    ok: true,
    game: {
      id: typeof requested.id === "string" && requested.id.length <= 128 ? requested.id : `game_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      gameType,
      title: titles[gameType],
      createdBy: gameType === "chess" ? userKey : userName,
      opponent: toType === "friend" ? to : undefined,
      state: "in_progress",
      turn: gameType === "tictactoe" ? playerX : gameType === "chess" ? userKey : userName,
      data,
    },
  };
}

module.exports = { applyGameMove, createGameChallenge };
