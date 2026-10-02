import React, { useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { Search, ChevronUp, ChevronDown, X } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface InChatSearchProps {
  isOpen: boolean;
  query: string;
  onQueryChange: (q: string) => void;
  matchesCount: number;
  currentMatchIndex: number;
  onPrevMatch: () => void;
  onNextMatch: () => void;
  onClose: () => void;
}

export const InChatSearch: React.FC<InChatSearchProps> = ({
  isOpen,
  query,
  onQueryChange,
  matchesCount,
  currentMatchIndex,
  onPrevMatch,
  onNextMatch,
  onClose,
}) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (e.shiftKey) {
        onPrevMatch();
      } else {
        onNextMatch();
      }
    } else if (e.key === 'Escape') {
      e.preventDefault();
      onClose();
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      transition={{ duration: 0.15 }}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '8px 16px',
        background: 'rgba(247, 254, 253, 0.95)',
        backdropFilter: 'blur(16px)',
        borderBottom: '1px solid var(--border)',
        zIndex: 10,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          background: 'rgba(255, 255, 255, 0.55)',
          border: '1px solid var(--border)',
          borderRadius: '10px',
          padding: '6px 12px',
          flex: 1,
        }}
      >
        <Search style={{ width: '15px', height: '15px', color: 'var(--text-muted)', flexShrink: 0 }} />
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={(e) => onQueryChange(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Search in conversation..."
          style={{
            background: 'none',
            border: 'none',
            outline: 'none',
            color: 'var(--text-main)',
            fontSize: '0.85rem',
            width: '100%',
          }}
        />
        {query && (
          <button
            type="button"
            onClick={() => onQueryChange('')}
            style={{
              background: 'none',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              padding: '2px',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <X style={{ width: '13px', height: '13px' }} />
          </button>
        )}
      </div>

      {query && (
        <span style={{ fontSize: '0.78rem', color: matchesCount > 0 ? '#0e9f8a' : 'var(--text-muted)', whiteSpace: 'nowrap', fontWeight: 600 }}>
          {matchesCount > 0 ? `${currentMatchIndex + 1} of ${matchesCount}` : 'No matches'}
        </span>
      )}

      {matchesCount > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '2px' }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              onPrevMatch();
            }}
            style={{
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
              borderRadius: '6px',
              color: 'var(--text-main)',
              cursor: 'pointer',
              padding: '4px 6px',
              display: 'flex',
              alignItems: 'center',
            }}
            title="Previous match (Shift+Enter)"
          >
            <ChevronUp style={{ width: '14px', height: '14px' }} />
          </button>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              onNextMatch();
            }}
            style={{
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
              borderRadius: '6px',
              color: 'var(--text-main)',
              cursor: 'pointer',
              padding: '4px 6px',
              display: 'flex',
              alignItems: 'center',
            }}
            title="Next match (Enter)"
          >
            <ChevronDown style={{ width: '14px', height: '14px' }} />
          </button>
        </div>
      )}

      <button
        type="button"
        onClick={() => {
          triggerHaptic('light');
          onClose();
        }}
        style={{
          background: 'none',
          border: 'none',
          color: 'var(--text-muted)',
          cursor: 'pointer',
          padding: '6px',
          borderRadius: '8px',
          display: 'flex',
          alignItems: 'center',
        }}
        title="Close search (Esc)"
      >
        <X style={{ width: '16px', height: '16px' }} />
      </button>
    </motion.div>
  );
};
