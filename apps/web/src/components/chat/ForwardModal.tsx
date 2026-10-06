import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Message, Conversation } from '../../types';
import { Avatar } from '../ui/Avatar';
import { Search, X, Send, Check } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface ForwardModalProps {
  message: Message | null;
  conversations: Conversation[];
  onClose: () => void;
  onForward: (targetUsername: string, message: Message) => void;
}

export const ForwardModal: React.FC<ForwardModalProps> = ({
  message,
  conversations,
  onClose,
  onForward,
}) => {
  const [search, setSearch] = useState('');
  const [selectedContact, setSelectedContact] = useState<string | null>(null);
  const [isForwarded, setIsForwarded] = useState(false);

  if (!message) return null;

  const filtered = conversations.filter((c) =>
    (c.displayName || c.username).toLowerCase().includes(search.toLowerCase())
  );

  const handleSend = () => {
    if (!selectedContact || !message) return;
    triggerHaptic('success');
    setIsForwarded(true);
    onForward(selectedContact, message);
    setTimeout(() => {
      onClose();
    }, 600);
  };

  return (
    <AnimatePresence>
      <div
        className="forward-modal-overlay"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '16px',
        }}
        onClick={onClose}
      >
        <motion.div
          className="forward-modal"
          initial={{ opacity: 0, scale: 0.94, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.94, y: 12 }}
          transition={{ duration: 0.18 }}
          onClick={(e) => e.stopPropagation()}
          style={{
            width: '100%',
            maxWidth: '420px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '20px',
            boxShadow: '0 24px 60px rgba(36, 76, 96, 0.1)',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            maxHeight: '80vh',
          }}
        >
          {/* Header */}
          <div
            className="forward-modal-header"
            style={{
              padding: '16px 20px',
              borderBottom: '1px solid var(--border)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-main)' }}>Forward Message</div>
            <button
              type="button"
              onClick={onClose}
              style={{
                background: 'none',
                border: 'none',
                color: 'rgba(20, 52, 63, 0.5)',
                cursor: 'pointer',
                padding: '4px',
                borderRadius: '50%',
                display: 'flex',
              }}
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>

          {/* Message Preview Box */}
          <div
            className="forward-message-preview"
            style={{
              padding: '12px 20px',
              background: 'rgba(255, 255, 255, 0.55)',
              borderBottom: '1px solid var(--border)',
            }}
          >
            <div style={{ fontSize: '0.72rem', color: 'rgba(20, 52, 63, 0.45)', marginBottom: '4px' }}>
              Forwarding content:
            </div>
            <div
              style={{
                fontSize: '0.84rem',
                color: 'var(--text-muted)',
                maxHeight: '48px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {message.isVoice
                ? '🎤 Voice Message'
                : message.attachment
                ? '📎 Attachment'
                : message.text || '(empty message)'}
            </div>
          </div>

          {/* Search Contacts */}
          <div className="forward-search-area" style={{ padding: '12px 20px 8px' }}>
            <div
              className="forward-search"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                borderRadius: '12px',
                padding: '8px 12px',
              }}
            >
              <Search style={{ width: '16px', height: '16px', color: 'rgba(20, 52, 63, 0.45)' }} />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search friends..."
                style={{
                  background: 'none',
                  border: 'none',
                  outline: 'none',
                  color: 'var(--text-main)',
                  fontSize: '0.85rem',
                  width: '100%',
                }}
              />
            </div>
          </div>

          {/* Contacts List */}
          <div
            style={{
              flex: 1,
              overflowY: 'auto',
              padding: '8px 12px',
              display: 'flex',
              flexDirection: 'column',
              gap: '4px',
            }}
          >
            {filtered.length === 0 ? (
              <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-dark)', fontSize: '0.82rem' }}>
                No contacts found
              </div>
            ) : (
              filtered.map((conv) => {
                const isSelected = selectedContact === conv.username;
                return (
                  <div
                    className={`forward-contact-row ${isSelected ? 'is-selected' : ''}`}
                    key={conv.username}
                    onClick={() => {
                      triggerHaptic('light');
                      setSelectedContact(conv.username);
                    }}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px 12px',
                      borderRadius: '12px',
                      cursor: 'pointer',
                      background: isSelected ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                      border: isSelected ? '1px solid rgba(16, 185, 129, 0.4)' : '1px solid transparent',
                      transition: 'all 0.12s ease',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <Avatar
                        name={conv.displayName || conv.username}
                        avatarUrl={conv.avatarId}
                        online={conv.online}
                        presence={conv.presence}
                        isGroup={conv.isGroup}
                        size="sm"
                      />
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '0.88rem', color: 'var(--text-main)' }}>
                          {conv.displayName || conv.username}
                        </div>
                        <div style={{ fontSize: '0.74rem', color: 'rgba(20, 52, 63, 0.45)' }}>
                          @{conv.username}
                        </div>
                      </div>
                    </div>

                    <div
                      style={{
                        width: '20px',
                        height: '20px',
                        borderRadius: '50%',
                        border: isSelected ? '2px solid #10b981' : '2px solid var(--border)',
                        background: isSelected ? '#10b981' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      {isSelected && <Check style={{ width: '12px', height: '12px', color: 'var(--text-main)' }} />}
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Action Footer */}
          <div
            className="forward-modal-footer"
            style={{
              padding: '16px 20px',
              borderTop: '1px solid var(--border)',
              display: 'flex',
              justifyContent: 'flex-end',
              gap: '10px',
            }}
          >
            <button
              type="button"
              onClick={onClose}
              style={{
                background: 'rgba(255, 255, 255, 0.55)',
                border: 'none',
                color: 'rgba(20, 52, 63, 0.7)',
                padding: '9px 16px',
                borderRadius: '10px',
                fontWeight: 600,
                fontSize: '0.84rem',
                cursor: 'pointer',
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!selectedContact || isForwarded}
              onClick={handleSend}
              style={{
                background: selectedContact ? '#10b981' : 'rgba(255, 255, 255, 0.55)',
                border: 'none',
                color: selectedContact ? 'var(--text-main)' : 'rgba(20, 52, 63, 0.45)',
                padding: '9px 18px',
                borderRadius: '10px',
                fontWeight: 700,
                fontSize: '0.84rem',
                cursor: selectedContact ? 'pointer' : 'not-allowed',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                boxShadow: selectedContact ? '0 4px 14px rgba(16, 185, 129, 0.4)' : 'none',
                transition: 'all 0.15s ease',
              }}
            >
              {isForwarded ? (
                <>
                  <Check style={{ width: '14px', height: '14px' }} /> Sent
                </>
              ) : (
                <>
                  <Send style={{ width: '14px', height: '14px' }} /> Forward
                </>
              )}
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
