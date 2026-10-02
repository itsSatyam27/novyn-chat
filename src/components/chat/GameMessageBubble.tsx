import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { GameData, GameType } from '../../types';
import { Swords, RotateCcw, Trophy, Sparkles, User, Users, Gamepad2 } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface GameMessageBubbleProps {
  game: GameData;
  messageId: string;
  isMe: boolean;
  currentUsername?: string;
  onMove: (messageId: string, moveData: any) => void;
  onRematch?: (messageId: string) => void;
}

export const GameMessageBubble: React.FC<GameMessageBubbleProps> = ({
  game,
  messageId,
  isMe,
  currentUsername = '',
  onMove,
  onRematch,
}) => {
  const { gameType, state, turn, winner, data, createdBy, opponent } = game;

  // Helpers
  const isMyTurn = state === 'in_progress' && turn === currentUsername;
  const isParticipant =
    currentUsername === createdBy ||
    (opponent && currentUsername === opponent) ||
    currentUsername === data.playerX ||
    currentUsername === data.playerO ||
    currentUsername === data.player1 ||
    currentUsername === data.player2;

  // ----------------------------------------------------
  // 1. TIC-TAC-TOE LOGIC & RENDER
  // ----------------------------------------------------
  const handleTicTacToeCellClick = (index: number) => {
    if (state === 'finished') return;
    const board = [...(data.board || Array(9).fill(null))];
    if (board[index]) return; // already occupied

    // Determine players
    let pX = data.playerX || createdBy;
    let pO = data.playerO || (currentUsername !== pX ? currentUsername : opponent || '');

    // Joining as player O if open
    if (!data.playerO && currentUsername !== pX) {
      pO = currentUsername;
    }

    const currentSymbol = currentUsername === pX ? 'X' : currentUsername === pO ? 'O' : null;
    if (!currentSymbol) return; // not allowed to move

    // Check turn
    if (turn && turn !== currentUsername) {
      triggerHaptic('light');
      return;
    }

    board[index] = currentSymbol;
    const movesCount = (data.movesCount || 0) + 1;

    // Check winning line
    const winLines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
      [0, 4, 8], [2, 4, 6],           // diags
    ];

    let winningLine: number[] | undefined;
    let gameWinner: string | 'draw' | undefined;
    let newState: 'in_progress' | 'finished' = 'in_progress';

    for (const line of winLines) {
      const [a, b, c] = line;
      if (board[a] && board[a] === board[b] && board[a] === board[c]) {
        winningLine = line;
        gameWinner = board[a] === 'X' ? pX : pO;
        newState = 'finished';
        break;
      }
    }

    if (!gameWinner && board.every((c) => c !== null)) {
      gameWinner = 'draw';
      newState = 'finished';
    }

    const nextTurn = currentSymbol === 'X' ? pO : pX;

    triggerHaptic('medium');
    onMove(messageId, {
      board,
      playerX: pX,
      playerO: pO,
      turn: nextTurn,
      state: newState,
      winner: gameWinner,
      winningLine,
      movesCount,
    });
  };

  const renderTicTacToe = () => {
    const board = data.board || Array(9).fill(null);
    const winningLine = data.winningLine || [];
    const pX = data.playerX || createdBy;
    const pO = data.playerO || opponent || 'Waiting...';

    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px', width: '100%' }}>
        {/* Player Matchup Header */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            width: '100%',
            background: 'rgba(23, 66, 78, 0.0875)',
            padding: '6px 10px',
            borderRadius: '10px',
            fontSize: '0.76rem',
            fontWeight: 700,
            border: '1px solid var(--border)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#0e9f8a' }}>
            <span style={{ background: 'rgba(16, 185, 129, 0.2)', padding: '2px 6px', borderRadius: '6px', fontSize: '0.8rem', fontWeight: 900 }}>✕</span>
            <span style={{ maxWidth: '75px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              @{pX === currentUsername ? 'You' : pX}
            </span>
          </div>

          <span style={{ color: 'rgba(20, 52, 63, 0.45)', fontSize: '0.68rem', fontWeight: 800 }}>VS</span>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#087fac' }}>
            <span style={{ maxWidth: '75px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              @{pO === currentUsername ? 'You' : pO}
            </span>
            <span style={{ background: 'rgba(56, 189, 248, 0.2)', padding: '2px 6px', borderRadius: '6px', fontSize: '0.8rem', fontWeight: 900 }}>◯</span>
          </div>
        </div>

        {/* 3x3 Grid */}
        <div className="tic-tac-toe-board"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
            gridTemplateRows: 'repeat(3, minmax(0, 1fr))',
            gap: '6px',
            background: 'var(--bg-surface)',
            padding: '8px',
            borderRadius: '14px',
            border: '1px solid var(--border)',
            width: '100%',
            maxWidth: '216px',
            aspectRatio: '1',
          }}
        >
          {board.map((cell, idx) => {
            const isWinningCell = winningLine.includes(idx);
            const isClickable = !cell && state !== 'finished' && (turn === currentUsername || !data.playerO);

            return (
              <motion.button
                key={idx}
                type="button"
                aria-label={`Row ${Math.floor(idx / 3) + 1}, column ${idx % 3 + 1}: ${cell || 'empty'}`}
                whileTap={isClickable ? { scale: 0.92 } : undefined}
                whileHover={isClickable ? { backgroundColor: 'rgba(255, 255, 255, 0.08)' } : undefined}
                onClick={() => handleTicTacToeCellClick(idx)}
                style={{
                  background: isWinningCell
                    ? cell === 'X'
                      ? 'rgba(16, 185, 129, 0.35)'
                      : 'rgba(56, 189, 248, 0.35)'
                    : cell
                    ? 'rgba(255, 255, 255, 0.55)'
                    : 'rgba(255, 255, 255, 0.55)',
                  border: isWinningCell
                    ? cell === 'X'
                      ? '2px solid #10b981'
                      : '2px solid #38bdf8'
                    : '1px solid var(--border)',
                  borderRadius: '10px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '1.6rem',
                  fontWeight: 900,
                  color: cell === 'X' ? '#0e9f8a' : cell === 'O' ? '#087fac' : 'transparent',
                  textShadow: cell === 'X' ? '0 0 10px rgba(16, 185, 129, 0.6)' : cell === 'O' ? '0 0 10px rgba(56, 189, 248, 0.6)' : 'none',
                  cursor: isClickable ? 'pointer' : 'default',
                  transition: 'background 0.15s ease',
                  padding: 0,
                  minWidth: 0,
                  minHeight: 0,
                  width: '100%',
                  height: '100%',
                  lineHeight: 1,
                  overflow: 'hidden',
                }}
              >
                {cell === 'X' ? '✕' : cell === 'O' ? '◯' : ''}
              </motion.button>
            );
          })}
        </div>
      </div>
    );
  };

  // ----------------------------------------------------
  // 2. ROCK • PAPER • SCISSORS LOGIC & RENDER
  // ----------------------------------------------------
  const handleRPSPick = (move: 'rock' | 'paper' | 'scissors') => {
    if (state === 'finished') return;

    let p1 = data.player1 || createdBy;
    let p2 = data.player2 || (currentUsername !== p1 ? currentUsername : opponent || '');

    // Assign second player if open
    if (!data.player2 && currentUsername !== p1) {
      p2 = currentUsername;
    }

    let p1Move = data.p1Move;
    let p2Move = data.p2Move;

    if (currentUsername === p1) {
      p1Move = move;
    } else if (currentUsername === p2) {
      p2Move = move;
    } else {
      p2 = currentUsername;
      p2Move = move;
    }

    let gameWinner: string | 'draw' | undefined;
    let newState: 'in_progress' | 'finished' = 'in_progress';

    if (p1Move && p2Move) {
      newState = 'finished';
      if (p1Move === p2Move) {
        gameWinner = 'draw';
      } else if (
        (p1Move === 'rock' && p2Move === 'scissors') ||
        (p1Move === 'paper' && p2Move === 'rock') ||
        (p1Move === 'scissors' && p2Move === 'paper')
      ) {
        gameWinner = p1;
      } else {
        gameWinner = p2;
      }
    }

    triggerHaptic('medium');
    onMove(messageId, {
      player1: p1,
      player2: p2,
      p1Move,
      p2Move,
      state: newState,
      winner: gameWinner,
    });
  };

  const renderRPS = () => {
    const p1 = data.player1 || createdBy;
    const p2 = data.player2 || opponent || 'Opponent';
    const isP1 = currentUsername === p1;
    const isP2 = currentUsername === p2;
    const myMove = isP1 ? data.p1Move : isP2 ? data.p2Move : undefined;
    const bothPicked = Boolean(data.p1Move && data.p2Move);

    const emojiMap: Record<string, string> = {
      rock: '🪨',
      paper: '📄',
      scissors: '✂️',
    };

    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', width: '100%' }}>
        {bothPicked ? (
          <motion.div className="rps-result"
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-around',
              width: '100%',
              padding: '16px 12px',
              borderRadius: '16px',
              background: 'var(--bg-surface)',
              border: '1px solid var(--border)',
            }}
          >
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px' }}>
              <span style={{ fontSize: '2.5rem' }}>{emojiMap[data.p1Move!]}</span>
              <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                @{p1 === currentUsername ? 'You' : p1}
              </span>
            </div>

            <span style={{ fontSize: '1.2rem', fontWeight: 900, color: '#a86d0b' }}>VS</span>

            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px' }}>
              <span style={{ fontSize: '2.5rem' }}>{emojiMap[data.p2Move!]}</span>
              <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                @{p2 === currentUsername ? 'You' : p2}
              </span>
            </div>
          </motion.div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px', width: '100%' }}>
            <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontWeight: 600, textAlign: 'center' }}>
              {myMove ? 'Choice locked! 🔒 Waiting for opponent...' : 'Secretly tap your choice:'}
            </span>

            <div className="rps-choices" style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
              {(['rock', 'paper', 'scissors'] as const).map((choice) => {
                const isSelected = myMove === choice;
                return (
                  <motion.button
                    key={choice}
                    type="button"
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.92 }}
                    onClick={() => handleRPSPick(choice)}
                    disabled={Boolean(myMove)}
                    style={{
                      background: isSelected ? 'rgba(245, 158, 11, 0.25)' : 'var(--bg-surface)',
                      border: isSelected ? '2px solid #f59e0b' : '1px solid var(--border)',
                      borderRadius: '14px',
                      padding: '12px 16px',
                      fontSize: '2rem',
                      cursor: myMove ? 'default' : 'pointer',
                      opacity: myMove && !isSelected ? 0.35 : 1,
                      transition: 'all 0.15s ease',
                    }}
                  >
                    {emojiMap[choice]}
                  </motion.button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    );
  };

  // ----------------------------------------------------
  // 3. CONNECT 4 LOGIC & RENDER
  // ----------------------------------------------------
  const handleConnect4ColClick = (col: number) => {
    if (state === 'finished') return;
    const board = [...(data.board || Array(42).fill(null))];
    let pR = data.player1 || createdBy;
    let pY = data.player2 || (currentUsername !== pR ? currentUsername : opponent || '');

    if (!data.player2 && currentUsername !== pR) {
      pY = currentUsername;
    }

    const currentChip = currentUsername === pR ? 'R' : currentUsername === pY ? 'Y' : null;
    if (!currentChip) return;
    if (turn && turn !== currentUsername) {
      triggerHaptic('light');
      return;
    }

    let targetRow = -1;
    for (let row = 5; row >= 0; row--) {
      const idx = row * 7 + col;
      if (!board[idx]) {
        targetRow = row;
        break;
      }
    }

    if (targetRow === -1) return;

    const placedIdx = targetRow * 7 + col;
    board[placedIdx] = currentChip;

    const checkLine = (r: number, c: number, dr: number, dc: number) => {
      const line: number[] = [];
      for (let i = 0; i < 4; i++) {
        const nr = r + dr * i;
        const nc = c + dc * i;
        if (nr < 0 || nr >= 6 || nc < 0 || nc >= 7) return null;
        const nIdx = nr * 7 + nc;
        if (board[nIdx] !== currentChip) return null;
        line.push(nIdx);
      }
      return line;
    };

    let winningLine: number[] | undefined;
    let gameWinner: string | 'draw' | undefined;
    let newState: 'in_progress' | 'finished' = 'in_progress';

    for (let r = 0; r < 6; r++) {
      for (let c = 0; c < 7; c++) {
        const h = checkLine(r, c, 0, 1);
        const v = checkLine(r, c, 1, 0);
        const d1 = checkLine(r, c, 1, 1);
        const d2 = checkLine(r, c, 1, -1);
        const win = h || v || d1 || d2;
        if (win) {
          winningLine = win;
          gameWinner = currentChip === 'R' ? pR : pY;
          newState = 'finished';
          break;
        }
      }
      if (winningLine) break;
    }

    if (!gameWinner && board.every((c) => c !== null)) {
      gameWinner = 'draw';
      newState = 'finished';
    }

    const nextTurn = currentChip === 'R' ? pY : pR;

    triggerHaptic('medium');
    onMove(messageId, {
      board,
      player1: pR,
      player2: pY,
      turn: nextTurn,
      state: newState,
      winner: gameWinner,
      winningLine,
    });
  };

  const renderConnect4 = () => {
    const board = data.board || Array(42).fill(null);
    const winningLine = data.winningLine || [];
    const pR = data.player1 || createdBy;
    const pY = data.player2 || opponent || 'Waiting...';

    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px', width: '100%' }}>
        {/* Matchup Header */}
        <div className="game-matchup"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            width: '100%',
            background: 'rgba(23, 66, 78, 0.0875)',
            padding: '6px 10px',
            borderRadius: '10px',
            fontSize: '0.76rem',
            fontWeight: 700,
            border: '1px solid var(--border)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#ef4444' }}>
            <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#ef4444' }} />
            <span style={{ maxWidth: '75px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              @{pR === currentUsername ? 'You' : pR}
            </span>
          </div>

          <span style={{ color: 'rgba(20, 52, 63, 0.45)', fontSize: '0.68rem', fontWeight: 800 }}>VS</span>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#facc15' }}>
            <span style={{ maxWidth: '75px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              @{pY === currentUsername ? 'You' : pY}
            </span>
            <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#facc15' }} />
          </div>
        </div>

        {/* 7x6 Drop Board */}
        <div className="connect-four-board"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(7, 1fr)',
            gap: '5px',
            background: 'var(--bg-surface)',
            padding: '8px',
            borderRadius: '12px',
            border: '2px solid rgba(56, 189, 248, 0.4)',
            boxShadow: '0 8px 24px rgba(36, 76, 96, 0.1)',
          }}
        >
          {board.map((chip, idx) => {
            const isWinning = winningLine.includes(idx);
            const col = idx % 7;

            return (
              <motion.button
                key={idx}
                type="button"
                whileTap={state !== 'finished' ? { scale: 0.88 } : undefined}
                onClick={() => handleConnect4ColClick(col)}
                style={{
                  width: '25px',
                  height: '25px',
                  borderRadius: '50%',
                  background:
                    chip === 'R'
                      ? '#ef4444'
                      : chip === 'Y'
                      ? '#facc15'
                      : 'rgba(255, 255, 255, 0.55)',
                  border: isWinning
                    ? '2px solid #ffffff'
                    : '1px solid var(--border)',
                  boxShadow: isWinning
                    ? '0 0 10px #ffffff'
                    : chip
                    ? 'inset 0 -2px 4px rgba(36, 76, 96, 0.1)'
                    : 'none',
                  cursor: state !== 'finished' ? 'pointer' : 'default',
                  padding: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              />
            );
          })}
        </div>
      </div>
    );
  };

  // ----------------------------------------------------
  // STATUS PILL BADGE
  // ----------------------------------------------------
  const renderBanner = () => {
    if (state === 'finished') {
      if (winner === 'draw') {
        return (
          <span
            style={{
              fontSize: '0.72rem',
              fontWeight: 800,
              color: '#a86d0b',
              background: 'rgba(245, 158, 11, 0.15)',
              border: '1px solid rgba(245, 158, 11, 0.3)',
              padding: '2px 8px',
              borderRadius: '9999px',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
            }}
          >
            🤝 Draw
          </span>
        );
      }
      const isWinnerMe = winner === currentUsername;
      return (
        <span
          style={{
            fontSize: '0.72rem',
            fontWeight: 800,
            color: isWinnerMe ? '#0e9f8a' : '#bd3750',
            background: isWinnerMe ? 'rgba(16, 185, 129, 0.15)' : 'rgba(248, 113, 113, 0.15)',
            border: isWinnerMe ? '1px solid rgba(16, 185, 129, 0.35)' : '1px solid rgba(248, 113, 113, 0.35)',
            padding: '2px 8px',
            borderRadius: '9999px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '4px',
          }}
        >
          <Trophy style={{ width: '12px', height: '12px' }} />
          <span>{isWinnerMe ? 'You Won! 🎉' : `@${winner} Won`}</span>
        </span>
      );
    }

    if (isMyTurn) {
      return (
        <span
          style={{
            fontSize: '0.72rem',
            fontWeight: 800,
            color: '#0e9f8a',
            background: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid rgba(16, 185, 129, 0.35)',
            padding: '2px 8px',
            borderRadius: '9999px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '4px',
          }}
        >
          <Sparkles style={{ width: '11px', height: '11px' }} />
          <span>Your turn!</span>
        </span>
      );
    }

    return (
      <span
        style={{
          fontSize: '0.72rem',
          color: 'var(--text-muted)',
          background: 'rgba(255, 255, 255, 0.55)',
          border: '1px solid var(--border)',
          padding: '2px 8px',
          borderRadius: '9999px',
          fontWeight: 600,
        }}
      >
        Waiting for @{turn === currentUsername ? 'you' : turn || 'opponent'}
      </span>
    );
  };

  return (
    <div
      className="game-message"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '10px',
        width: '230px',
        maxWidth: '100%',
        padding: '2px 0',
      }}
    >
      {/* Game Title & Status Bar */}
      <div
        className="game-message-header"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '6px',
          width: '100%',
          paddingBottom: '6px',
          borderBottom: '1px solid var(--border)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.84rem', fontWeight: 800, color: 'var(--text-main)' }}>
          <Gamepad2 style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
          <span>{game.title}</span>
        </div>
        <span className="game-status">{renderBanner()}</span>
      </div>

      {/* Main Game Board */}
      {gameType === 'tictactoe' && renderTicTacToe()}
      {gameType === 'rps' && renderRPS()}
      {gameType === 'connect4' && renderConnect4()}

      {/* Rematch button if finished */}
      {state === 'finished' && onRematch && (
        <motion.button
          type="button"
          whileHover={{ scale: 1.04 }}
          whileTap={{ scale: 0.96 }}
          onClick={() => {
            triggerHaptic('medium');
            onRematch(messageId);
          }}
          style={{
            marginTop: '4px',
            background: 'rgba(16, 185, 129, 0.18)',
            border: '1px solid #10b981',
            color: '#0e9f8a',
            borderRadius: '9999px',
            padding: '5px 14px',
            fontSize: '0.76rem',
            fontWeight: 700,
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            cursor: 'pointer',
          }}
        >
          <RotateCcw style={{ width: '12px', height: '12px' }} />
          <span>Play Again</span>
        </motion.button>
      )}
    </div>
  );
};
