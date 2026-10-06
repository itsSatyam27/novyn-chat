import React from 'react';
import { ArrowRight, Grid3X3, Swords, Disc, Users, Gamepad2 } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { GameType } from '../../types';
import { triggerHaptic } from '../../services/capacitor';

interface GameLauncherModalProps {
  isOpen: boolean;
  onClose: () => void;
  onLaunchGame: (gameType: GameType) => void;
  opponentName?: string;
  isGroup?: boolean;
}

const games = [
  { type: 'tictactoe', title: 'Tic-Tac-Toe', description: 'Three in a row. Make every move count.', tag: 'Quick match', icon: Grid3X3, accent: '#087f70', tint: 'rgba(16, 185, 129, 0.1)' },
  { type: 'rps', title: 'Rock, Paper, Scissors', description: 'Pick in secret. Reveal when you’re both ready.', tag: 'Instant showdown', icon: Swords, accent: '#9e650d', tint: 'rgba(245, 158, 11, 0.1)' },
  { type: 'connect4', title: 'Connect 4', description: 'Drop a chip. Be the first to line up four.', tag: 'Strategy', icon: Disc, accent: '#087fac', tint: 'rgba(56, 189, 248, 0.1)' },
] satisfies { type: GameType; title: string; description: string; tag: string; icon: typeof Grid3X3; accent: string; tint: string }[];

export const GameLauncherModal: React.FC<GameLauncherModalProps> = ({
  isOpen, onClose, onLaunchGame, opponentName, isGroup,
}) => (
  <Modal isOpen={isOpen} onClose={onClose} title="Play together" className="game-launcher-modal">
    <div className="game-launcher">
      <div className="game-launcher-intro">
        <span className="game-launcher-context"><Users size={14} aria-hidden="true" />
          {isGroup ? 'Challenge your group' : `Challenge @${opponentName || 'friend'}`}
        </span>
        <p>Pick a game and make the first move.</p>
      </div>
      <div className="game-launcher-options">
        {games.map(({ type, title, description, tag, icon: Icon, accent, tint }) => (
          <button
            key={type}
            type="button"
            className="game-launcher-option"
            aria-label={`Play ${title}`}
            style={{ '--game-accent': accent, '--game-tint': tint } as React.CSSProperties}
            onClick={() => {
              triggerHaptic('medium');
              onLaunchGame(type);
              onClose();
            }}
          >
            <span className="game-launcher-icon" aria-hidden="true"><Icon size={25} /></span>
            <span className="game-launcher-copy">
              <span className="game-launcher-meta">2 players <span aria-hidden="true">·</span> {tag}</span>
              <span className="game-launcher-title">{title}</span>
              <span className="game-launcher-description">{description}</span>
            </span>
            <span className="game-launcher-play" aria-hidden="true"><ArrowRight size={18} /></span>
          </button>
        ))}
      </div>
      <p className="game-launcher-footer"><Gamepad2 size={16} aria-hidden="true" /> Play right here. Your moves stay in the chat.</p>
    </div>
  </Modal>
);
