import React from 'react';
import { motion } from 'framer-motion';
import { Message } from '../../types';
import { Pin, X, ChevronRight } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface PinnedMessageBannerProps {
  pinnedMessages: Message[];
  onJumpToMessage: (messageId: string) => void;
  onUnpin: (messageId: string) => void;
}

export const PinnedMessageBanner: React.FC<PinnedMessageBannerProps> = ({
  pinnedMessages,
  onJumpToMessage,
  onUnpin,
}) => {
  const [currentIndex, setCurrentIndex] = React.useState(0);

  if (!pinnedMessages || pinnedMessages.length === 0) return null;

  const safeIndex = Math.min(currentIndex, pinnedMessages.length - 1);
  const current = pinnedMessages[safeIndex];

  const handleNext = (e: React.MouseEvent) => {
    e.stopPropagation();
    triggerHaptic('light');
    setCurrentIndex((prev) => (prev + 1) % pinnedMessages.length);
  };

  const previewText = current.isVoice
    ? '🎤 Voice message'
    : current.attachment
    ? '📎 Attachment'
    : current.text || '(Message)';

  return (
    <motion.div
      className="pinned-message-banner"
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -8 }}
      transition={{ duration: 0.15 }}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '8px 16px',
        background: 'rgba(247, 254, 253, 0.92)',
        backdropFilter: 'blur(12px)',
        borderBottom: '1px solid var(--border)',
        zIndex: 9,
        cursor: 'pointer',
      }}
      onClick={() => onJumpToMessage(current.id)}
      title="Click to jump to message"
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0, flex: 1 }}>
        <div
          className="pinned-message-icon"
          style={{
            width: '28px',
            height: '28px',
            borderRadius: '8px',
            background: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid rgba(16, 185, 129, 0.3)',
            color: '#0e9f8a',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Pin style={{ width: '14px', height: '14px' }} />
        </div>

        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ fontSize: '0.74rem', fontWeight: 700, color: '#0e9f8a' }}>
              Pinned Message {pinnedMessages.length > 1 && `(${safeIndex + 1}/${pinnedMessages.length})`}
            </span>
            <span style={{ fontSize: '0.7rem', color: 'rgba(20, 52, 63, 0.45)' }}>
              • {current.sender}
            </span>
          </div>
          <div
            style={{
              fontSize: '0.82rem',
              color: 'rgba(20, 52, 63, 0.85)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {previewText}
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexShrink: 0 }}>
        {pinnedMessages.length > 1 && (
          <button
            type="button"
            onClick={handleNext}
            style={{
              background: 'none',
              border: 'none',
              color: 'rgba(20, 52, 63, 0.6)',
              cursor: 'pointer',
              padding: '4px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
            }}
            title="Next pinned message"
          >
            <ChevronRight style={{ width: '16px', height: '16px' }} />
          </button>
        )}

        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            triggerHaptic('light');
            onUnpin(current.id);
          }}
          style={{
            background: 'none',
            border: 'none',
            color: 'rgba(20, 52, 63, 0.45)',
            cursor: 'pointer',
            padding: '4px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
          }}
          title="Unpin message"
        >
          <X style={{ width: '15px', height: '15px' }} />
        </button>
      </div>
    </motion.div>
  );
};
