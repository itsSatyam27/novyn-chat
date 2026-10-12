import React, { useEffect, useState } from 'react';
import { ArrowRight, Grid3X3, Swords, Disc, Gamepad2, Palette, Binary, TrendingUp, Shuffle } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { GameType } from '../../types';
import { triggerHaptic } from '../../services/capacitor';

interface GameLauncherModalProps { isOpen: boolean; onClose: () => void; onLaunchGame: (gameType: GameType) => void; opponentName?: string; isGroup?: boolean; }
const games = [
  { type: 'tictactoe', title: 'Tic-Tac-Toe', description: 'Three in a row. Make every move count.', tag: 'Quick match', icon: Grid3X3, accent: '#7457f5' },
  { type: 'rps', title: 'Rock, Paper, Scissors', description: "Pick in secret. Reveal when you're both ready.", tag: 'Instant showdown', icon: Swords, accent: '#7952e8' },
  { type: 'connect4', title: 'Connect 4', description: 'Drop a chip. Be the first to line up four.', tag: 'Strategy', icon: Disc, accent: '#9b4bd0' },
  { type: 'doodle', title: 'Doodle Duel', description: 'Draw a secret word while your friend guesses before time runs out.', tag: 'Draw & guess', icon: Palette, accent: '#bc4fc0' },
  { type: 'numberclash', title: 'Number Clash', description: 'Pick a number and get closest to the secret target.', tag: 'Number battle', icon: Binary, accent: '#6242d7' },
  { type: 'updown', title: 'Up or Down', description: 'Predict if the next card is higher or lower. Build a streak.', tag: 'Higher or lower', icon: TrendingUp, accent: '#5141b8' },
] satisfies { type: GameType; title: string; description: string; tag: string; icon: typeof Grid3X3; accent: string }[];

export const GameLauncherModal: React.FC<GameLauncherModalProps> = ({ isOpen, onClose, onLaunchGame, opponentName, isGroup }) => {
  const [selected, setSelected] = useState<GameType>('connect4');
  useEffect(() => { if (isOpen) setSelected('connect4'); }, [isOpen]);
  const launch = (type: GameType) => { triggerHaptic('medium'); onLaunchGame(type); onClose(); };
  return <Modal isOpen={isOpen} onClose={onClose} title="Play together" className="game-launcher-modal" maxWidth="720px">
    <div className="game-picker">
      <div className="game-picker-intro"><p>Pick a game and make the first move.</p></div>
      <div className="game-picker-opponent"><span className="game-picker-avatar">{(opponentName || 'F').charAt(0).toUpperCase()}</span><span><small>Challenging</small><strong>{isGroup ? 'Your group' : `@${opponentName || 'friend'}`}</strong></span><i/><em>{isGroup ? 'Group match' : 'Online'}</em></div>
      <div className="game-picker-grid">
        {games.map(({ type, title, description, tag, icon: Icon, accent }) => <div key={type} role="button" tabIndex={0} className={'game-picker-card' + (selected === type ? ' is-selected' : '')} aria-pressed={selected === type} style={{ '--game-accent': accent } as React.CSSProperties} onClick={() => setSelected(type)} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); setSelected(type); } }}>
          <span className="game-picker-art" aria-hidden="true"><span className="game-picker-meta"><b>{tag}</b><i>2 players</i></span><Icon size={44}/><strong>{type === 'numberclash' ? '42  VS  17' : type === 'updown' ? '↑  ?  ↓' : type === 'doodle' ? '〰 〰 ✦' : ''}</strong></span>
          <span className="game-picker-copy"><span className="game-picker-title">{title}</span><span className="game-picker-description">{description}</span></span>
          <button
            type="button"
            className="game-picker-action"
            aria-label={`Challenge to ${title}`}
            onClick={(event) => { event.stopPropagation(); launch(type); }}
          ><ArrowRight size={17}/></button>
        </div>)}
      </div>
      <div className="game-picker-footer"><p><Gamepad2 size={16}/>Play right here. Your moves stay in the chat.</p><button type="button" onClick={() => launch(games[Math.floor(Math.random()*games.length)].type)}><Shuffle size={14}/>Surprise me</button></div>
      <button className="game-picker-primary" type="button" onClick={() => launch(selected)}>Challenge to {games.find(game => game.type === selected)?.title}<ArrowRight size={16}/></button>
    </div>
  </Modal>;
};

