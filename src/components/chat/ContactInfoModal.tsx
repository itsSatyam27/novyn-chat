import React, { useState } from 'react';
import { Modal } from '../ui/Modal';
import { Avatar } from '../ui/Avatar';
import { Conversation } from '../../types';
import { Phone, Video, Bell, BellOff, Ban, UserMinus, Trash2, ShieldCheck } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface ContactInfoModalProps {
  isOpen: boolean;
  onClose: () => void;
  contact: Conversation | null;
  onAudioCall: (username: string) => void;
  onVideoCall: (username: string) => void;
  onToggleMute: (username: string, isMuted: boolean) => void;
  onToggleBlock: (username: string, isBlocked: boolean) => void;
  onUnfriend: (username: string) => void;
  onClearChat: (username: string) => void;
  isMuted?: boolean;
  isBlocked?: boolean;
}

export const ContactInfoModal: React.FC<ContactInfoModalProps> = ({
  isOpen,
  onClose,
  contact,
  onAudioCall,
  onVideoCall,
  onToggleMute,
  onToggleBlock,
  onUnfriend,
  onClearChat,
  isMuted = false,
  isBlocked = false,
}) => {
  const [showConfirmUnfriend, setShowConfirmUnfriend] = useState(false);
  const [showConfirmClear, setShowConfirmClear] = useState(false);

  if (!contact) return null;

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Contact Info" maxWidth="420px">
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
        {/* Big Avatar */}
        <div style={{ marginBottom: '14px' }}>
          <Avatar
            name={contact.displayName || contact.username}
            avatarUrl={contact.avatarId}
            online={contact.online}
            isGroup={contact.isGroup}
            size="xl"
          />
        </div>

        {/* Name & Handle */}
        <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '2px' }}>
          {contact.displayName || contact.username}
        </h3>
        <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '4px' }}>
          @{contact.username}
        </p>

        <span
          style={{
            fontSize: '0.72rem',
            fontWeight: 700,
            color: contact.isGroup ? '#087fac' : contact.online ? '#078779' : 'var(--text-dark)',
            background: contact.isGroup ? 'rgba(56, 189, 248, 0.12)' : contact.online ? 'rgba(16, 185, 129, 0.12)' : 'rgba(255, 255, 255, 0.55)',
            padding: '2px 10px',
            borderRadius: '9999px',
            marginBottom: '20px',
          }}
        >
          {contact.isGroup ? `👥 ${contact.memberCount || 2} members` : contact.online ? '● Online' : 'Offline'}
        </span>

        {/* Quick Call Actions */}
        <div style={{ display: 'flex', gap: '12px', width: '100%', marginBottom: '20px' }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('medium');
              onClose();
              onAudioCall(contact.username);
            }}
            className="btn btn-secondary"
            style={{ flex: 1, padding: '10px', borderRadius: '12px', fontSize: '0.82rem' }}
          >
            <Phone style={{ width: '15px', height: '15px', color: '#078779' }} /> Audio Call
          </button>

          <button
            type="button"
            onClick={() => {
              triggerHaptic('medium');
              onClose();
              onVideoCall(contact.username);
            }}
            className="btn btn-secondary"
            style={{ flex: 1, padding: '10px', borderRadius: '12px', fontSize: '0.82rem' }}
          >
            <Video style={{ width: '15px', height: '15px', color: '#087fac' }} /> Video Call
          </button>
        </div>

        {/* Redesigned Settings & Danger Grouped Cards */}
        <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          {/* Card 1: Chat Preferences */}
          <div
            style={{
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
              borderRadius: '16px',
              overflow: 'hidden',
            }}
          >
            {/* Mute Notifications */}
            <div
              onClick={() => {
                triggerHaptic('light');
                onToggleMute(contact.username, !isMuted);
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '12px 14px',
                cursor: 'pointer',
                transition: 'background 0.15s ease',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div
                  style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: '8px',
                    background: isMuted ? 'rgba(245, 158, 11, 0.18)' : 'rgba(255, 255, 255, 0.55)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: isMuted ? '#a86d0b' : 'var(--text-muted)',
                  }}
                >
                  {isMuted ? <BellOff style={{ width: '16px', height: '16px' }} /> : <Bell style={{ width: '16px', height: '16px' }} />}
                </div>
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontSize: '0.86rem', fontWeight: 600, color: 'var(--text-main)' }}>Mute Notifications</div>
                  <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{isMuted ? 'Alerts are silenced' : 'Play sound on new messages'}</div>
                </div>
              </div>

              {/* iOS style switch */}
              <div
                style={{
                  width: '38px',
                  height: '22px',
                  borderRadius: '9999px',
                  background: isMuted ? '#f59e0b' : 'rgba(255, 255, 255, 0.55)',
                  position: 'relative',
                  transition: 'background 0.2s ease',
                  flexShrink: 0,
                }}
              >
                <div
                  style={{
                    width: '18px',
                    height: '18px',
                    borderRadius: '50%',
                    background: '#ffffff',
                    position: 'absolute',
                    top: '2px',
                    left: isMuted ? '18px' : '2px',
                    transition: 'left 0.2s ease',
                    boxShadow: '0 1px 3px rgba(36, 76, 96, 0.1)',
                  }}
                />
              </div>
            </div>
          </div>

          {/* Card 2: Danger Zone */}
          <div
            style={{
              background: 'rgba(239, 68, 68, 0.035)',
              border: '1px solid rgba(239, 68, 68, 0.18)',
              borderRadius: '16px',
              overflow: 'hidden',
            }}
          >
            {/* Clear Chat */}
            {showConfirmClear ? (
              <div
                style={{
                  padding: '14px',
                  background: 'rgba(239, 68, 68, 0.12)',
                  borderBottom: '1px solid rgba(239, 68, 68, 0.15)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                }}
              >
                <span style={{ fontSize: '0.78rem', color: '#bd3750', fontWeight: 600 }}>Clear all messages?</span>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <button
                    type="button"
                    onClick={() => setShowConfirmClear(false)}
                    style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '0.75rem', padding: '4px 8px', cursor: 'pointer' }}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('medium');
                      onClearChat(contact.username);
                      setShowConfirmClear(false);
                      onClose();
                    }}
                    style={{ background: '#ef4444', border: 'none', color: 'var(--text-on-primary)', fontSize: '0.75rem', fontWeight: 700, padding: '4px 10px', borderRadius: '6px', cursor: 'pointer' }}
                  >
                    Clear
                  </button>
                </div>
              </div>
            ) : (
              <div
                onClick={() => setShowConfirmClear(true)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  cursor: 'pointer',
                  borderBottom: '1px solid rgba(239, 68, 68, 0.12)',
                  transition: 'background 0.15s ease',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.08)')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'rgba(239, 68, 68, 0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#ef4444',
                    }}
                  >
                    <Trash2 style={{ width: '16px', height: '16px' }} />
                  </div>
                  <div style={{ textAlign: 'left' }}>
                    <div style={{ fontSize: '0.86rem', fontWeight: 600, color: '#bd3750' }}>Clear Chat History</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>Delete message stream locally</div>
                  </div>
                </div>
              </div>
            )}

            {/* Block / Unblock */}
            <div
              onClick={() => {
                triggerHaptic('medium');
                onToggleBlock(contact.username, !isBlocked);
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '12px 14px',
                cursor: 'pointer',
                borderBottom: '1px solid rgba(239, 68, 68, 0.12)',
                transition: 'background 0.15s ease',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.08)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div
                  style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: '8px',
                    background: 'rgba(239, 68, 68, 0.15)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#ef4444',
                  }}
                >
                  <Ban style={{ width: '16px', height: '16px' }} />
                </div>
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontSize: '0.86rem', fontWeight: 600, color: '#bd3750' }}>{isBlocked ? 'Unblock User' : 'Block User'}</div>
                  <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{isBlocked ? 'Allow messaging & calls' : 'Stop incoming messages & calls'}</div>
                </div>
              </div>
              {isBlocked && <span style={{ fontSize: '0.72rem', fontWeight: 800, color: '#ef4444', background: 'rgba(239, 68, 68, 0.15)', padding: '2px 8px', borderRadius: '6px' }}>Blocked</span>}
            </div>

            {/* Unfriend */}
            {showConfirmUnfriend ? (
              <div
                style={{
                  padding: '14px',
                  background: 'rgba(239, 68, 68, 0.12)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                }}
              >
                <span style={{ fontSize: '0.78rem', color: '#bd3750', fontWeight: 600 }}>Remove @{contact.username}?</span>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <button
                    type="button"
                    onClick={() => setShowConfirmUnfriend(false)}
                    style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '0.75rem', padding: '4px 8px', cursor: 'pointer' }}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('heavy');
                      onUnfriend(contact.username);
                      setShowConfirmUnfriend(false);
                      onClose();
                    }}
                    style={{ background: '#ef4444', border: 'none', color: 'var(--text-on-primary)', fontSize: '0.75rem', fontWeight: 700, padding: '4px 10px', borderRadius: '6px', cursor: 'pointer' }}
                  >
                    Unfriend
                  </button>
                </div>
              </div>
            ) : (
              <div
                onClick={() => setShowConfirmUnfriend(true)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  cursor: 'pointer',
                  transition: 'background 0.15s ease',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.08)')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'rgba(239, 68, 68, 0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#ef4444',
                    }}
                  >
                    <UserMinus style={{ width: '16px', height: '16px' }} />
                  </div>
                  <div style={{ textAlign: 'left' }}>
                    <div style={{ fontSize: '0.86rem', fontWeight: 600, color: '#bd3750' }}>Unfriend Contact</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>Remove from friends list</div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </Modal>
  );
};
