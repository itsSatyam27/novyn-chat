import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, Paperclip, Mic, X, Smile, Sparkles, BarChart3, Image as ImageIcon, FileText, Gamepad2 } from 'lucide-react';
import { Message } from '../../types';
import { VoiceRecorder } from './VoiceRecorder';
import { GifPickerModal } from './GifPickerModal';
import { CreatePollModal } from './CreatePollModal';
import { uploadMediaFile } from '../../services/api';
import { triggerHaptic } from '../../services/capacitor';

interface MessageInputProps {
  onSendMessage: (text: string, options?: { attachment?: any; replyTo?: any; isVoice?: boolean }) => void;
  onTyping: (isTyping: boolean) => void;
  replyMessage: Message | null;
  onCancelReply: () => void;
  onCreatePoll?: (question: string, options: string[]) => void;
  onOpenGames?: () => void;
  activeChatId?: string | null;
  mentionMembers?: string[];
}

const EMOJI_LIST = ['😀', '😂', '😍', '🔥', '👍', '🎉', '❤️', '🙌', '✨', '🚀'];

const PICKER_EMOJIS = [
  ...EMOJI_LIST,
  '😄', '😁', '😅', '🤣', '😊', '😇', '🙂', '🙃', '😉', '🥰', '😘', '😋',
  '🤔', '🤭', '🤫', '🥳', '😴', '😭', '😤', '😡', '🤯', '🥺', '🙌', '👌',
  '✌️', '🤞', '💪', '🎯', '💡', '✅', '❗', '💬', '🌟', '🎈', '🍀', '👋',
];

const MESSAGE_CHARACTER_LIMIT = 250;

export const MessageInput: React.FC<MessageInputProps> = ({
  onSendMessage,
  onTyping,
  replyMessage,
  onCancelReply,
  onCreatePoll,
  onOpenGames,
  activeChatId,
  mentionMembers = [],
}) => {
  const [text, setText] = useState(() => {
    if (activeChatId) {
      return localStorage.getItem(`novyn_draft_${activeChatId.toLowerCase()}`) || '';
    }
    return '';
  });
  const [isRecording, setIsRecording] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [showAttachMenu, setShowAttachMenu] = useState(false);
  const [showGifModal, setShowGifModal] = useState(false);
  const [showPollModal, setShowPollModal] = useState(false);
  const [mentionQuery, setMentionQuery] = useState<string | null>(null);
  const [mentionIndex, setMentionIndex] = useState(0);
  const typingTimerRef = useRef<any>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const emojiPickerRef = useRef<HTMLDivElement>(null);
  const emojiBtnRef = useRef<HTMLButtonElement>(null);
  const attachMenuRef = useRef<HTMLDivElement>(null);
  const attachBtnRef = useRef<HTMLButtonElement>(null);

  // Restore draft when activeChatId switches
  useEffect(() => {
    setUploadError('');
    setShowAttachMenu(false);
    setShowEmojiPicker(false);
    if (activeChatId) {
      const saved = localStorage.getItem(`novyn_draft_${activeChatId.toLowerCase()}`) || '';
      setText(saved);
    } else {
      setText('');
    }
  }, [activeChatId]);

  // Close emoji picker and attach menu on click outside
  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent | TouchEvent) => {
      const target = e.target as Node;
      if (
        showEmojiPicker &&
        emojiPickerRef.current &&
        !emojiPickerRef.current.contains(target) &&
        emojiBtnRef.current &&
        !emojiBtnRef.current.contains(target)
      ) {
        setShowEmojiPicker(false);
      }

      if (
        showAttachMenu &&
        attachMenuRef.current &&
        !attachMenuRef.current.contains(target) &&
        attachBtnRef.current &&
        !attachBtnRef.current.contains(target)
      ) {
        setShowAttachMenu(false);
      }
    };

    document.addEventListener('mousedown', handleOutsideClick);
    document.addEventListener('touchstart', handleOutsideClick);

    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
      document.removeEventListener('touchstart', handleOutsideClick);
    };
  }, [showEmojiPicker, showAttachMenu]);

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 100)}px`;
    }
  }, [text]);

  // Auto-focus input when a message is selected for reply
  useEffect(() => {
    if (replyMessage && textareaRef.current) {
      textareaRef.current.focus();
      textareaRef.current.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }, [replyMessage]);

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const val = e.target.value;
    setText(val);
    const cursorText = val.slice(0, e.target.selectionStart ?? val.length);
    const mentionMatch = cursorText.match(/(?:^|\s)@([\w-]*)$/);
    setMentionQuery(mentionMatch ? mentionMatch[1].toLowerCase() : null);
    setMentionIndex(0);

    // Save draft per active conversation
    if (activeChatId) {
      if (val.trim()) {
        localStorage.setItem(`novyn_draft_${activeChatId.toLowerCase()}`, val);
      } else {
        localStorage.removeItem(`novyn_draft_${activeChatId.toLowerCase()}`);
      }
    }

    onTyping(true);

    if (typingTimerRef.current) clearTimeout(typingTimerRef.current);
    typingTimerRef.current = setTimeout(() => {
      onTyping(false);
    }, 1500);
  };

  const mentionCandidates = mentionQuery === null ? [] : mentionMembers
    .filter((member) => member.toLowerCase().includes(mentionQuery))
    .slice(0, 5);

  const insertMention = (member: string) => {
    const cursor = textareaRef.current?.selectionStart ?? text.length;
    const before = text.slice(0, cursor).replace(/@([\w-]*)$/, `@${member}`);
    const next = `${before}${text.slice(cursor)} `;
    setText(next);
    setMentionQuery(null);
    requestAnimationFrame(() => {
      textareaRef.current?.focus();
      const nextCursor = before.length + 1;
      textareaRef.current?.setSelectionRange(nextCursor, nextCursor);
    });
  };

  const handleSend = () => {
    const trimmed = text.trim();
    if (!trimmed) return;
    if (trimmed.length > MESSAGE_CHARACTER_LIMIT) {
      setUploadError(`Messages can be up to ${MESSAGE_CHARACTER_LIMIT} characters.`);
      return;
    }

    onSendMessage(trimmed, {
      replyTo: replyMessage
        ? {
            id: replyMessage.id,
            sender: replyMessage.sender,
            text: replyMessage.text,
            attachment: replyMessage.attachment,
          }
        : undefined,
    });

    setText('');
    if (activeChatId) {
      localStorage.removeItem(`novyn_draft_${activeChatId.toLowerCase()}`);
    }
    onTyping(false);
    onCancelReply();
    setShowEmojiPicker(false);
    triggerHaptic('light');

    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (mentionCandidates.length) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setMentionIndex((current) => (current + 1) % mentionCandidates.length);
        return;
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setMentionIndex((current) => (current - 1 + mentionCandidates.length) % mentionCandidates.length);
        return;
      }
      if (e.key === 'Escape') {
        setMentionQuery(null);
        return;
      }
      if (e.key === 'Enter' || e.key === 'Tab') {
        e.preventDefault();
        insertMention(mentionCandidates[mentionIndex]);
        return;
      }
    }
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    e.target.value = '';

    setIsUploading(true);
    setUploadError('');
    triggerHaptic('medium');

    const res = await uploadMediaFile(file).catch(() => ({ ok: false, url: undefined, error: 'Upload interrupted. Choose the file again to retry.' }));
    setIsUploading(false);

    if (res.ok && res.url) {
      const isImage = file.type.startsWith('image/');
      onSendMessage('', {
        attachment: {
          url: res.url,
          name: file.name,
          mime: file.type,
          size: file.size,
          kind: isImage ? 'image' : 'file',
        },
        replyTo: replyMessage ? { id: replyMessage.id, sender: replyMessage.sender, text: replyMessage.text } : undefined,
      });
      onCancelReply();
    } else {
      setUploadError(res.error || 'Could not upload the file. Choose it again to retry.');
    }
  };

  const handleSendVoice = (voiceUrl: string) => {
    onSendMessage('', {
      attachment: {
        url: voiceUrl,
        name: 'voice.webm',
        mime: 'audio/webm',
        size: 1024 * 50,
        kind: 'audio',
      },
      isVoice: true,
    });
    setIsRecording(false);
  };

  if (isRecording) {
    return <VoiceRecorder onSendVoice={handleSendVoice} onCancel={() => setIsRecording(false)} />;
  }

  return (
    <div style={{ position: 'relative', width: '100%' }}>
      {isUploading && <div className="composer-notice" role="status">Uploading attachment…</div>}
      {uploadError && <div className="composer-notice is-error" role="alert">{uploadError}<button type="button" onClick={() => setUploadError('')} aria-label="Dismiss upload error">×</button></div>}
      {/* Reply Banner */}
      {replyMessage && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderBottom: 'none',
            borderRadius: '16px 16px 0 0',
            padding: '8px 16px',
            fontSize: '0.78rem',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', overflow: 'hidden' }}>
            <span style={{ fontWeight: 700, color: '#0e9f8a' }}>Replying to {replyMessage.sender}:</span>
            <span style={{ color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {replyMessage.text || 'Attachment'}
            </span>
          </div>
          <button
            type="button"
            onClick={onCancelReply}
            style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '2px' }}
          >
            <X style={{ width: '14px', height: '14px' }} />
          </button>
        </div>
      )}

      {/* Emoji Picker Popup with smooth fade & outside click dismiss */}
      <AnimatePresence>
        {showEmojiPicker && (
          <motion.div
            ref={emojiPickerRef}
            initial={{ opacity: 0, y: 5 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 3 }}
            transition={{ duration: 0.1 }}
            className="emoji-picker"
            style={{ position: 'absolute', bottom: '100%', marginBottom: '10px', left: '0', zIndex: 30 }}
          >
            <div className="emoji-picker-title"><span>Quick reactions</span><span>Tap to add</span></div>
            <div className="emoji-picker-grid">
              {PICKER_EMOJIS.map((emoji) => (
                <button key={emoji} type="button" onClick={() => {
                  setText((prev) => prev + emoji);
                  requestAnimationFrame(() => textareaRef.current?.focus());
                }} aria-label={`Add ${emoji}`}>
                  {emoji}
                </button>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Attach Popup Menu */}
      <AnimatePresence>
        {showAttachMenu && (
          <motion.div
            ref={attachMenuRef}
            className="attachment-menu"
            initial={{ opacity: 0, scale: 0.92, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.92, y: 10 }}
            transition={{ duration: 0.15 }}
            style={{
              position: 'absolute',
              bottom: '100%',
              marginBottom: '10px',
              left: '8px',
              background: 'var(--bg-surface)',
              border: '1px solid var(--border)',
              borderRadius: '16px',
              padding: '6px',
              display: 'flex',
              flexDirection: 'column',
              gap: '2px',
              boxShadow: '0 20px 45px rgba(36, 76, 96, 0.1), 0 0 0 1px rgba(255, 255, 255, 0.08)',
              zIndex: 1000,
              backdropFilter: 'blur(16px)',
              minWidth: '220px',
            }}
          >
            <div className="attachment-menu-title"><span>Share something</span><span>Choose a format</span></div>
            {/* Photos & Videos */}
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                setShowAttachMenu(false);
                imageInputRef.current?.click();
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '9px 12px',
                borderRadius: '10px',
                background: 'transparent',
                border: 'none',
                color: 'var(--text-main)',
                fontSize: '0.84rem',
                fontWeight: 600,
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'background 0.12s ease',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#0e9f8a' }}>
                <ImageIcon style={{ width: '15px', height: '15px' }} />
              </div>
              <span>Photos & Videos</span>
            </button>

            {/* Document / File */}
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                setShowAttachMenu(false);
                fileInputRef.current?.click();
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '9px 12px',
                borderRadius: '10px',
                background: 'transparent',
                border: 'none',
                color: 'var(--text-main)',
                fontSize: '0.84rem',
                fontWeight: 600,
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'background 0.12s ease',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'rgba(96, 165, 250, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#2569b2' }}>
                <FileText style={{ width: '15px', height: '15px' }} />
              </div>
              <span>Document / File</span>
            </button>

            {/* Create Poll */}
            {onCreatePoll && (
              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setShowAttachMenu(false);
                  setShowPollModal(true);
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '9px 12px',
                  borderRadius: '10px',
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--text-main)',
                  fontSize: '0.84rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                  textAlign: 'left',
                  transition: 'background 0.12s ease',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'rgba(245, 158, 11, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#a86d0b' }}>
                  <BarChart3 style={{ width: '15px', height: '15px' }} />
                </div>
                <span>Create Poll</span>
              </button>
            )}

            {/* In-Chat Mini Games */}
            {onOpenGames && (
              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setShowAttachMenu(false);
                  onOpenGames();
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '9px 12px',
                  borderRadius: '10px',
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--text-main)',
                  fontSize: '0.84rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                  textAlign: 'left',
                  transition: 'background 0.12s ease',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'rgba(168, 85, 247, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#a855f7' }}>
                  <Gamepad2 style={{ width: '15px', height: '15px' }} />
                </div>
                <span>Mini Games (Tic-Tac-Toe, RPS)</span>
              </button>
            )}

            {/* GIFs & Stickers */}
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                setShowAttachMenu(false);
                setShowGifModal(true);
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '9px 12px',
                borderRadius: '10px',
                background: 'transparent',
                border: 'none',
                color: 'var(--text-main)',
                fontSize: '0.84rem',
                fontWeight: 600,
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'background 0.12s ease',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.55)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'rgba(236, 72, 153, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ec4899' }}>
                <Sparkles style={{ width: '15px', height: '15px' }} />
              </div>
              <span>GIFs & Stickers</span>
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Input Bar */}
      {mentionCandidates.length > 0 && (
        <div className="mention-suggestions" role="listbox" aria-label="Mention suggestions">
          {mentionCandidates.map((member, index) => (
            <button
              key={member}
              type="button"
              role="option"
              aria-selected={index === mentionIndex}
              className={index === mentionIndex ? 'is-selected' : ''}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => insertMention(member)}
            >
              <span className="mention-avatar">@</span>
              <span>@{member}</span>
            </button>
          ))}
        </div>
      )}
      <div
        className="input-bar-container"
        style={{ borderRadius: replyMessage ? '0 0 18px 18px' : '18px' }}
      >
        <input
          ref={fileInputRef}
          type="file"
          style={{ display: 'none' }}
          onChange={handleFileSelect}
        />
        <input
          ref={imageInputRef}
          type="file"
          accept="image/*,video/*"
          style={{ display: 'none' }}
          onChange={handleFileSelect}
        />

        <div className="input-actions">
          <button
            ref={attachBtnRef}
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setShowAttachMenu((prev) => !prev);
            }}
            disabled={isUploading}
            className="input-action-btn"
            style={showAttachMenu ? { color: '#0e9f8a', background: 'rgba(16, 185, 129, 0.15)' } : {}}
            aria-label="Attach..."
            title="Attach..."
          >
            <Paperclip style={{ width: '18px', height: '18px' }} />
          </button>

          <button
            ref={emojiBtnRef}
            type="button"
            onClick={() => setShowEmojiPicker(!showEmojiPicker)}
            className="input-action-btn"
            style={showEmojiPicker ? { color: '#0e9f8a', background: 'rgba(16, 185, 129, 0.15)' } : {}}
            aria-label="Emoji"
            title="Emoji"
          >
            <Smile style={{ width: '18px', height: '18px' }} />
          </button>
        </div>

        <textarea
          aria-label="Message"
          ref={textareaRef}
          value={text}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          placeholder="Message..."
          maxLength={MESSAGE_CHARACTER_LIMIT}
          rows={1}
          className="message-textarea"
        />

        <span className={`message-character-count ${text.length >= MESSAGE_CHARACTER_LIMIT * 0.9 ? 'is-near-limit' : ''}`} aria-live="polite">
          {text.length}/{MESSAGE_CHARACTER_LIMIT}
        </span>

        <div>
          {text.trim() ? (
            <button
              type="button"
              onClick={handleSend}
              className="send-btn"
              aria-label="Send message"
            >
              <Send style={{ width: '16px', height: '16px' }} />
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setIsRecording(true)}
              disabled={isUploading}
              className="input-action-btn"
              style={{ color: '#0e9f8a' }}
              aria-label="Voice Message"
              title="Voice Message"
            >
              <Mic style={{ width: '20px', height: '20px' }} />
            </button>
          )}
        </div>
      </div>

      <GifPickerModal
        isOpen={showGifModal}
        onClose={() => setShowGifModal(false)}
        onSelectGif={(url) => {
          onSendMessage('', {
            attachment: {
              url,
              name: 'GIF',
              kind: 'image',
              mime: 'image/gif',
            },
            replyTo: replyMessage
              ? {
                  id: replyMessage.id,
                  sender: replyMessage.sender,
                  text: replyMessage.text,
                  attachment: replyMessage.attachment,
                }
              : undefined,
          });
          onCancelReply();
        }}
      />

      {onCreatePoll && (
        <CreatePollModal
          isOpen={showPollModal}
          onClose={() => setShowPollModal(false)}
          onCreatePoll={(question, options) => {
            onCreatePoll(question, options);
          }}
        />
      )}
    </div>
  );
};
