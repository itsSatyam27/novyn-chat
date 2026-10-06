import { getPreferredLocale } from '../../services/regionalPreferences';
import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Message } from '../../types';
import {
  Check,
  CheckCheck,
  FileText,
  CornerDownRight,
  MoreVertical,
  Edit2,
  Trash2,
  Reply,
  Smile,
  Copy,
  Forward,
  Pin,
  PinOff,
} from 'lucide-react';
import { VoicePlayer } from './VoicePlayer';
import { LinkPreviewCard, extractFirstUrl } from './LinkPreviewCard';
import { PollMessageBubble } from './PollMessageBubble';
import { GameMessageBubble } from './GameMessageBubble';
import { triggerHaptic } from '../../services/capacitor';

interface MessageBubbleProps {
  message: Message;
  isMe: boolean;
  onReply: (message: Message) => void;
  onReaction: (messageId: string, emoji: string) => void;
  onMediaClick: (url: string) => void;
  onForward?: (message: Message) => void;
  onPin?: (messageId: string) => void;
  onUnpin?: (messageId: string) => void;
  onUnsend?: (messageId: string) => void;
  onEdit?: (messageId: string, newText: string) => void;
  onVotePoll?: (messageId: string, optionId: string) => void;
  onMoveGame?: (messageId: string, moveData: any) => void;
  onRematchGame?: (messageId: string) => void;
  onJumpToMessage?: (messageId: string) => void;
  currentUsername?: string;
  searchQuery?: string;
  isGroup?: boolean;
  grouped?: boolean;
  onRetry?: (id: string) => void;
}

const HighlightText: React.FC<{ text: string; query?: string }> = ({ text, query }) => {
  if (!query || !query.trim()) return <>{text}</>;
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const parts = text.split(new RegExp(`(${escaped})`, 'gi'));
  return (
    <>
      {parts.map((part, i) =>
        part.toLowerCase() === query.toLowerCase() ? (
          <mark
            key={i}
            style={{
              background: '#fef08a',
              color: '#000000',
              borderRadius: '2px',
              padding: '0 2px',
              fontWeight: 700,
            }}
          >
            {part}
          </mark>
        ) : (
          part
        )
      )}
    </>
  );
};

const COMMON_REACTIONS = ['❤️', '👍', '😂', '😭', '🔥', '🎉', '😮'];

export const MessageBubble: React.FC<MessageBubbleProps> = ({
  message,
  isMe,
  onReply,
  onReaction,
  onMediaClick,
  onForward,
  onPin,
  onUnpin,
  onUnsend,
  onEdit,
  onVotePoll,
  onMoveGame,
  onRematchGame,
  onJumpToMessage,
  currentUsername,
  searchQuery,
  isGroup = false,
  grouped = false,
  onRetry,
}) => {
  const [showActionsMenu, setShowActionsMenu] = useState(false);
  const [showReactions, setShowReactions] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [copied, setCopied] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(message.text || '');
  const containerRef = useRef<HTMLDivElement>(null);
  const lastTapRef = useRef<number>(0);
  const touchStartRef = useRef<{ x: number; y: number } | null>(null);

  const toggleActionsMenu = (e: React.MouseEvent) => {
    e.stopPropagation();
    triggerHaptic('light');
    setShowActionsMenu((prev) => !prev);
    setShowReactions(false);
  };

  // Keep menu open stably: close only on outside clicks
  useEffect(() => {
    if (!showActionsMenu && !showReactions) return;

    const handleOutsideClick = (e: MouseEvent | TouchEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setShowActionsMenu(false);
        setShowReactions(false);
        setShowEmojiPicker(false);
      }
    };

    document.addEventListener('mousedown', handleOutsideClick);
    document.addEventListener('touchstart', handleOutsideClick);

    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
      document.removeEventListener('touchstart', handleOutsideClick);
    };
  }, [showActionsMenu, showReactions]);

  const handleCopy = async (e: React.MouseEvent) => {
    e.stopPropagation();
    const textToCopy =
      message.text ||
      (typeof message.attachment === 'string' ? message.attachment : message.attachment?.url) ||
      '';
    if (!textToCopy) return;

    let copiedOk = false;
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(textToCopy);
        copiedOk = true;
      }
    } catch (_) {}

    if (!copiedOk) {
      try {
        const textarea = document.createElement('textarea');
        textarea.value = textToCopy;
        textarea.style.position = 'fixed';
        textarea.style.left = '-9999px';
        textarea.style.top = '-9999px';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();
        copiedOk = document.execCommand('copy');
        document.body.removeChild(textarea);
      } catch (_) {}
    }

    if (copiedOk) {
      setCopied(true);
      triggerHaptic('light');
      setTimeout(() => {
        setCopied(false);
        setShowActionsMenu(false);
      }, 800);
    }
  };

  const formatTime = (ts: string | number) => {
    try {
      const d = new Date(ts);
      return d.toLocaleTimeString(getPreferredLocale(), { hour: '2-digit', minute: '2-digit' });
    } catch {
      return '';
    }
  };

  const renderStatus = () => {
    if (!isMe) return null;
    if (message.status === 'sending') return <span className="message-send-state" role="status">Sending…</span>;
    if (message.status === 'failed') return <button type="button" className="message-retry" title={message.sendError} onClick={() => onRetry?.(message.id)}>Couldn’t send · Retry</button>;
    if (message.status === 'seen') {
      return (
        <span title="Seen" style={{ display: 'inline-flex', alignItems: 'center', marginLeft: '2px' }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
            <line x1="5" y1="12" x2="19" y2="12"></line>
            <polyline points="12 5 19 12 12 19"></polyline>
          </svg>
        </span>
      );
    }
    if (message.status === 'delivered') {
      return (
        <span title="Delivered" style={{ display: 'inline-flex', alignItems: 'center', marginLeft: '2px' }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 8h14M14 4l4 4-4 4" />
            <path d="M20 16H6M10 12l-4 4 4 4" />
          </svg>
        </span>
      );
    }
    return (
      <span title="Sent" style={{ display: 'inline-flex', alignItems: 'center', marginLeft: '2px' }}>
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <line x1="5" y1="12" x2="19" y2="12"></line>
          <polyline points="12 5 19 12 12 19"></polyline>
        </svg>
      </span>
    );
  };

  const isAudioMessage = Boolean(
    message.isVoice ||
      message.attachment?.kind === 'audio' ||
      message.attachment?.mime?.startsWith('audio/') ||
      message.attachment?.name?.endsWith('.webm') ||
      message.attachment?.name?.endsWith('.mp3') ||
      message.attachment?.name?.endsWith('.ogg') ||
      message.attachment?.name?.endsWith('.wav') ||
      message.attachment?.name?.endsWith('.m4a')
  );

  const audioUrl = message.attachment?.url;

  const handleDoubleClick = (e?: React.MouseEvent | React.TouchEvent) => {
    if (e) e.stopPropagation();
    triggerHaptic('medium');
    setShowReactions((prev) => !prev);
    setShowActionsMenu(false);
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    const start = touchStartRef.current;
    const touch = e.changedTouches[0];
    if (start && touch) {
      const horizontalDistance = touch.clientX - start.x;
      const verticalDistance = Math.abs(touch.clientY - start.y);
      if (horizontalDistance > 68 && verticalDistance < 48) {
        triggerHaptic('medium');
        onReply(message);
        touchStartRef.current = null;
        return;
      }
    }
    touchStartRef.current = null;
    const now = Date.now();
    if (now - lastTapRef.current < 320) {
      handleDoubleClick(e);
    }
    lastTapRef.current = now;
  };

  const handleSaveEdit = () => {
    const trimmed = editText.trim();
    if (!trimmed || trimmed === message.text) {
      setIsEditing(false);
      return;
    }
    onEdit?.(message.id, trimmed);
    setIsEditing(false);
    triggerHaptic('light');
  };

  return (
    <div
      ref={containerRef}
      id={`msg-${message.id}`}
      className={`bubble-row ${isMe ? 'me' : 'other'} ${grouped ? 'is-grouped' : ''}`}
      style={{ position: 'relative', display: 'flex', alignItems: 'flex-end', gap: '6px' }}
    >
      {/* 3-Dots Action Trigger Button on Left of 'Me' */}
      {isMe && (
        <button
          type="button"
          onClick={toggleActionsMenu}
          className="msg-action-trigger"
          style={{
            background: 'none',
            border: 'none',
            color: 'rgba(20, 52, 63, 0.45)',
            cursor: 'pointer',
            padding: '4px',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginBottom: '16px',
          }}
          aria-label="Message actions"
          title="Message actions"
        >
          <MoreVertical style={{ width: '16px', height: '16px' }} />
        </button>
      )}

      {/* Main Message Column */}
      <div className="msg-wrapper">
        <motion.div
          initial={{ opacity: 0, y: 8, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.2 }}
          onDoubleClick={handleDoubleClick}
          onTouchStart={(e) => {
            const touch = e.touches[0];
            touchStartRef.current = touch ? { x: touch.clientX, y: touch.clientY } : null;
          }}
          onTouchEnd={handleTouchEnd}
          className={`bubble ${isMe ? 'me' : 'other'} ${message.game ? 'game-bubble' : ''}`}
          style={{ position: 'relative', cursor: 'default' }}
          title="Double-tap for emoji reactions"
        >
          {/* 1. Floating Double-Tap Emoji Reaction Bar */}
          <AnimatePresence>
            {showReactions && (
              <motion.div
                initial={{ opacity: 0, scale: 0.85, y: 6 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.85, y: 6 }}
                transition={{ duration: 0.15 }}
                onClick={(e) => e.stopPropagation()}
                style={{
                  position: 'absolute',
                  top: '-46px',
                  right: isMe ? '0' : 'auto',
                  left: isMe ? 'auto' : '0',
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border)',
                  borderRadius: '9999px',
                  padding: '5px 12px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  boxShadow: '0 12px 32px rgba(36, 76, 96, 0.1)',
                  zIndex: 50,
                }}
              >
                {COMMON_REACTIONS.map((emoji) => (
                  <button
                    key={emoji}
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      triggerHaptic('light');
                      onReaction(message.id, emoji);
                      setShowReactions(false);
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      fontSize: '1.2rem',
                      cursor: 'pointer',
                      padding: '2px 4px',
                      lineHeight: 1,
                      transition: 'transform 0.12s ease',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.3)')}
                    onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
                  >
                    {emoji}
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>

          {/* 2. Floating Vertical Action Dropdown Menu */}
          <AnimatePresence>
            {showActionsMenu && (
              <motion.div
                className={`message-actions-menu ${isMe ? 'opens-left' : 'opens-right'}`}
                initial={{ opacity: 0, scale: 0.94, x: isMe ? 8 : -8 }}
                animate={{ opacity: 1, scale: 1, x: 0 }}
                exit={{ opacity: 0, scale: 0.94, x: isMe ? 8 : -8 }}
                transition={{ duration: 0.15 }}
                onClick={(e) => e.stopPropagation()}
                style={{
                  position: 'absolute',
                  top: isMe ? 'auto' : '0',
                  bottom: isMe ? '0' : 'auto',
                  right: isMe ? 'calc(100% + 10px)' : 'auto',
                  left: isMe ? 'auto' : 'calc(100% + 10px)',
                  margin: 0,
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border)',
                  borderRadius: '14px',
                  padding: '6px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '2px',
                  minWidth: '160px',
                  boxShadow: '0 16px 36px rgba(36, 76, 96, 0.1), 0 0 0 1px rgba(255, 255, 255, 0.05)',
                  zIndex: 1000,
                  backdropFilter: 'blur(16px)',
                }}
              >
                {/* Quick Reactions Bar at Top */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '4px',
                    padding: '4px 6px 6px',
                    borderBottom: '1px solid var(--border)',
                    marginBottom: '4px',
                  }}
                >
                  {COMMON_REACTIONS.map((emoji) => (
                    <button
                      key={emoji}
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        triggerHaptic('light');
                        onReaction(message.id, emoji);
                        setShowActionsMenu(false);
                      }}
                      style={{
                        background: 'none',
                        border: 'none',
                        fontSize: '1.15rem',
                        cursor: 'pointer',
                        padding: '2px',
                        lineHeight: 1,
                        transition: 'transform 0.12s ease',
                      }}
                      onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.35)')}
                      onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
                    >
                      {emoji}
                    </button>
                  ))}
                </div>

                {/* Reply */}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    triggerHaptic('light');
                    onReply(message);
                    setShowActionsMenu(false);
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--text-main)',
                    cursor: 'pointer',
                    padding: '7px 10px',
                    borderRadius: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    width: '100%',
                    textAlign: 'left',
                    transition: 'background 0.15s ease',
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                >
                  <Reply style={{ width: '14px', height: '14px', color: '#0e9f8a' }} />
                  <span>Reply</span>
                </button>

                {/* Copy */}
                <button
                  type="button"
                  onClick={handleCopy}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: copied ? '#0e9f8a' : 'var(--text-main)',
                    cursor: 'pointer',
                    padding: '7px 10px',
                    borderRadius: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    width: '100%',
                    textAlign: 'left',
                    transition: 'background 0.15s ease',
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                >
                  {copied ? (
                    <>
                      <Check style={{ width: '14px', height: '14px', color: '#0e9f8a' }} />
                      <span>Copied!</span>
                    </>
                  ) : (
                    <>
                      <Copy style={{ width: '14px', height: '14px', color: 'var(--text-muted)' }} />
                      <span>Copy Text</span>
                    </>
                  )}
                </button>

                {/* Forward */}
                {onForward && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      triggerHaptic('light');
                      onForward(message);
                      setShowActionsMenu(false);
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--text-main)',
                      cursor: 'pointer',
                      padding: '7px 10px',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      width: '100%',
                      textAlign: 'left',
                      transition: 'background 0.15s ease',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                  >
                    <Forward style={{ width: '14px', height: '14px', color: '#2569b2' }} />
                    <span>Forward</span>
                  </button>
                )}

                {/* Pin / Unpin */}
                {(onPin || onUnpin) && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      triggerHaptic('light');
                      if (message.pinnedAt) {
                        onUnpin?.(message.id);
                      } else {
                        onPin?.(message.id);
                      }
                      setShowActionsMenu(false);
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--text-main)',
                      cursor: 'pointer',
                      padding: '7px 10px',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      width: '100%',
                      textAlign: 'left',
                      transition: 'background 0.15s ease',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                  >
                    {message.pinnedAt ? (
                      <>
                        <PinOff style={{ width: '14px', height: '14px', color: '#a86d0b' }} />
                        <span>Unpin</span>
                      </>
                    ) : (
                      <>
                        <Pin style={{ width: '14px', height: '14px', color: '#a86d0b' }} />
                        <span>Pin</span>
                      </>
                    )}
                  </button>
                )}

                {/* Edit (if sent by me and is text) */}
                {isMe && message.text && !isAudioMessage && !message.isEncrypted && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setIsEditing(true);
                      setShowActionsMenu(false);
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--text-main)',
                      cursor: 'pointer',
                      padding: '7px 10px',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      width: '100%',
                      textAlign: 'left',
                      transition: 'background 0.15s ease',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                  >
                    <Edit2 style={{ width: '14px', height: '14px', color: '#087fac' }} />
                    <span>Edit</span>
                  </button>
                )}

                {/* Unsend (if sent by me) */}
                {isMe && onUnsend && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      triggerHaptic('medium');
                      onUnsend(message.id);
                      setShowActionsMenu(false);
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: '#bd3750',
                      cursor: 'pointer',
                      padding: '7px 10px',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      width: '100%',
                      textAlign: 'left',
                      transition: 'background 0.15s ease',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.12)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'none')}
                  >
                    <Trash2 style={{ width: '14px', height: '14px', color: '#ef4444' }} />
                    <span>Unsend</span>
                  </button>
                )}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Group Sender Name */}
          {isGroup && !isMe && !grouped && (
            <div
              style={{
                fontSize: '0.74rem',
                fontWeight: 800,
                color: '#078779',
                marginBottom: '4px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
              }}
            >
              @{message.sender}
            </div>
          )}

          {/* Reply Context Header */}
          {message.replyTo && (
            <div
              onClick={(e) => {
                e.stopPropagation();
                triggerHaptic('light');
                const targetId = message.replyTo?.id;
                if (targetId) {
                  onJumpToMessage?.(targetId);
                }
              }}
              style={{
                padding: '6px 10px',
                borderRadius: '8px',
                borderLeft: isMe ? '3px solid rgba(0,0,0,0.4)' : '3px solid #10b981',
                background: isMe ? 'rgba(23, 66, 78, 0.03)' : 'rgba(23, 66, 78, 0.0625)',
                fontSize: '0.75rem',
                marginBottom: '8px',
                cursor: 'pointer',
                transition: 'background 0.15s ease',
              }}
              title="Click to jump to original message"
            >
              <div style={{ fontWeight: 700, display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '2px' }}>
                <CornerDownRight style={{ width: '12px', height: '12px' }} />
                {message.replyTo.sender?.toLowerCase() === currentUsername?.toLowerCase()
                  ? 'You'
                  : message.replyTo.sender || 'Original message'}
              </div>
              <div style={{ opacity: 0.85, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {message.replyTo.attachment?.kind === 'image'
                  ? '📷 [Image]'
                  : message.replyTo.attachment?.kind === 'audio'
                  ? '🎤 [Voice Message]'
                  : message.replyTo.text || '[Attachment]'}
              </div>
            </div>
          )}

          {/* 1. Image Attachment */}
          {message.attachment && (message.attachment.kind === 'image' || message.attachment.mime?.startsWith('image/')) && (
            <div
              style={{ marginBottom: '6px', borderRadius: '12px', overflow: 'hidden', cursor: 'pointer' }}
              onClick={() => onMediaClick(message.attachment!.url)}
            >
              <img
                src={message.attachment.url}
                alt={message.attachment.name}
                style={{ maxHeight: '240px', width: '100%', objectFit: 'cover', borderRadius: '12px' }}
              />
            </div>
          )}

          {/* 2. Built-in Voice Audio Player */}
          {isAudioMessage && audioUrl && (
            <VoicePlayer url={audioUrl} isMe={isMe} duration={message.voiceDuration} />
          )}

          {/* 3. Document / File Attachment */}
          {!isAudioMessage && message.attachment && (message.attachment.kind === 'file' || !message.attachment.mime?.startsWith('image/')) && (
            <a
              href={message.attachment.url}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '8px 12px',
                borderRadius: '10px',
                background: isMe ? 'rgba(23, 66, 78, 0.025)' : 'rgba(23, 66, 78, 0.05)',
                textDecoration: 'none',
                color: isMe ? '#022c22' : 'var(--text-main)',
                fontSize: '0.8rem',
                marginBottom: '6px',
                fontWeight: 600,
              }}
            >
              <FileText style={{ width: '20px', height: '20px', color: isMe ? '#022c22' : '#078779' }} />
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {message.attachment.name}
              </span>
            </a>
          )}

          {/* 4. Message Text / Inline Edit */}
          {isEditing ? (
            <div style={{ marginTop: '4px' }}>
              <input
                type="text"
                value={editText}
                onChange={(e) => setEditText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSaveEdit();
                  if (e.key === 'Escape') setIsEditing(false);
                }}
                autoFocus
                style={{
                  width: '100%',
                  background: isMe ? 'rgba(23, 66, 78, 0.0375)' : 'rgba(23, 66, 78, 0.0625)',
                  border: '1px solid var(--border)',
                  borderRadius: '8px',
                  padding: '6px 8px',
                  color: isMe ? '#022c22' : 'var(--text-main)',
                  fontSize: '0.85rem',
                  outline: 'none',
                  marginBottom: '6px',
                  fontWeight: 600,
                }}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '6px' }}>
                <button
                  type="button"
                  onClick={() => setIsEditing(false)}
                  style={{ background: 'none', border: 'none', color: isMe ? '#022c22' : 'var(--text-muted)', fontSize: '0.72rem', cursor: 'pointer' }}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleSaveEdit}
                  style={{ background: 'var(--primary)', border: 'none', color: 'var(--text-on-primary)', fontSize: '0.72rem', fontWeight: 700, padding: '2px 8px', borderRadius: '4px', cursor: 'pointer' }}
                >
                  Save
                </button>
              </div>
            </div>
          ) : message.poll ? (
            <PollMessageBubble
              poll={message.poll}
              messageId={message.id}
              isMe={isMe}
              currentUsername={currentUsername}
              onVote={onVotePoll || (() => {})}
            />
          ) : message.game ? (
            <GameMessageBubble
              game={message.game}
              messageId={message.id}
              isMe={isMe}
              currentUsername={currentUsername}
              onMove={onMoveGame || (() => {})}
              onRematch={onRematchGame}
            />
          ) : (
            message.text && (!isAudioMessage || message.text !== '[Voice Message]') && (
              <div>
                <div style={{ wordBreak: 'break-word', whiteSpace: 'pre-wrap' }}>
                  <HighlightText text={message.text} query={searchQuery} />
                </div>
                {extractFirstUrl(message.text) && (
                  <LinkPreviewCard url={extractFirstUrl(message.text)!} />
                )}
              </div>
            )
          )}

          {/* Reaction Badge Floating on Bottom Right Corner */}
          {message.reactions && Object.keys(message.reactions).length > 0 && (
            <div
              className="bubble-reaction-badge"
              onClick={(e) => {
                e.stopPropagation();
                triggerHaptic('light');
                setShowReactions((prev) => !prev);
              }}
            >
              {Object.entries(message.reactions).map(([emoji, users]) =>
                users.length > 0 ? (
                  <span key={emoji}>
                    {emoji} {users.length > 1 ? users.length : ''}
                  </span>
                ) : null
              )}
            </div>
          )}
        </motion.div>

        {/* Outer Timestamp & Status underneath the bubble */}
        <div className="bubble-meta-outside">
          {message.pinnedAt && (
            <span title="Pinned message" style={{ display: 'flex', alignItems: 'center' }}>
              <Pin style={{ width: '11px', height: '11px', color: '#a86d0b', marginRight: '2px' }} />
            </span>
          )}
          <span>{formatTime(message.timestamp)}</span>
          {renderStatus()}
        </div>
      </div>

      {/* 3-Dots Action Trigger on Right of 'Other' message */}
      {!isMe && (
        <button
          type="button"
          onClick={toggleActionsMenu}
          className="msg-action-trigger"
          style={{
            background: 'none',
            border: 'none',
            color: 'rgba(20, 52, 63, 0.45)',
            cursor: 'pointer',
            padding: '4px',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginBottom: '16px',
          }}
          aria-label="Message actions (Reply, React)"
          title="Message actions (Reply, React)"
        >
          <MoreVertical style={{ width: '16px', height: '16px' }} />
        </button>
      )}
    </div>
  );
};
