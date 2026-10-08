import React, { useState, useRef, useEffect, useLayoutEffect, useMemo } from 'react';
import { useChat } from '../../context/ChatContext';
import { useAuth } from '../../context/AuthContext';
import { MessageBubble } from './MessageBubble';
import { MessageInput } from './MessageInput';
import { MediaViewerModal } from './MediaViewerModal';
import { ContactDetailsSidebar } from './ContactDetailsSidebar';
import { ForwardModal } from './ForwardModal';
import { PinnedMessageBanner } from './PinnedMessageBanner';
import { InChatSearch } from './InChatSearch';
import { DropZoneOverlay } from './DropZoneOverlay';
import { WallpaperPickerModal } from './WallpaperPickerModal';
import { GameLauncherModal } from './GameLauncherModal';
import { CommandPaletteModal } from '../layout/CommandPaletteModal';
import { Avatar } from '../ui/Avatar';
import { Message } from '../../types';
import { Phone, Video, ChevronLeft, PanelLeftOpen, Info, Search, Command, Lock, ArrowDown, X } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { getSocket } from '../../services/socket';
import { uploadMediaFile } from '../../services/api';
import { groupsWithPrevious } from '../../services/messageGrouping';
import { resolveReplyPreviews } from '../../services/messagePresentation';
import { TabWelcome } from '../layout/TabWelcome';
import { getPreferredDayKey, getPreferredLocale, getPreferredTimeZone } from '../../services/regionalPreferences';

const messageDayKey = (timestamp: string | number) => {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return '';
  return getPreferredDayKey(date);
};

const messageDayLabel = (timestamp: string | number) => {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return '';

  const today = getPreferredDayKey(new Date());
  const yesterday = new Date(today + 'T12:00:00Z');
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const day = getPreferredDayKey(date);

  if (day === today) return 'Today';
  if (day === yesterday.toISOString().slice(0, 10)) return 'Yesterday';

  return new Intl.DateTimeFormat(getPreferredLocale(), {
    timeZone: getPreferredTimeZone(),
    day: 'numeric',
    month: 'long',
    year: day.slice(0, 4) === today.slice(0, 4) ? undefined : 'numeric',
  }).format(date);
};

interface ChatWindowProps {
  isListCollapsed?: boolean;
  onToggleList?: () => void;
  onStartChat?: () => void;
}

export const ChatWindow: React.FC<ChatWindowProps> = ({
  isListCollapsed,
  onToggleList,
  onStartChat,
}) => {
  const { user } = useAuth();
  const {
    activeChat,
    setActiveChat,
    conversations,
    messages,
    sendMessage,
    retryMessage,
    sendTyping,
    addReaction,
    pinMessage,
    unpinMessage,
    createPoll,
    votePoll,
    sendGameChallenge,
    makeGameMove,
    chatWallpaper,
    setChatWallpaper,
    typingUsers,
    mutedUsers,
    blockedUsers,
    startCall,
    muteUser,
    blockUser,
    unfriendUser,
    clearChat,
    unsendMessage,
    editMessage,
  } = useChat();

  const [replyMessage, setReplyMessage] = useState<Message | null>(null);
  const [forwardMessage, setForwardMessage] = useState<Message | null>(null);
  const [selectedMedia, setSelectedMedia] = useState<string | null>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isWallpaperModalOpen, setIsWallpaperModalOpen] = useState(false);
  const [isGameLauncherOpen, setIsGameLauncherOpen] = useState(false);
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [currentMatchIndex, setCurrentMatchIndex] = useState(0);
  const [chatRetentionDays, setChatRetentionDays] = useState<number | null>(null);
  const [isAwayFromLatest, setIsAwayFromLatest] = useState(false);
  const chatBackground = chatWallpaper && chatWallpaper !== 'var(--bg-canvas)'
    ? chatWallpaper
    : 'var(--chat-default-wallpaper)';
  const [firstUnreadMessageId, setFirstUnreadMessageId] = useState<string | null>(null);
  const [stickyDay, setStickyDay] = useState('');

  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const isChatReadyRef = useRef<boolean>(false);
  const prevChatIdRef = useRef<string | null>(null);
  const prevMessagesCountRef = useRef<number>(0);
  const forceLatestUntilRef = useRef(0);

  const activeContact = conversations.find((c) => c.username.toLowerCase() === activeChat?.toLowerCase()) || null;
  const retentionDays = user?.retentionDays || 30;
  const effectiveRetentionDays = chatRetentionDays ?? retentionDays;
  useEffect(() => {
    if (!activeChat || !user?.username) {
      setChatRetentionDays(null);
      return;
    }
    const saved = Number(localStorage.getItem(`novyn_chat_retention_${user.username.toLowerCase()}_${activeChat.toLowerCase()}`));
    setChatRetentionDays([1, 7, 15].includes(saved) ? saved : null);
  }, [activeChat, user?.username]);
  const visibleMessages = useMemo(() => resolveReplyPreviews(messages.filter((message) => {
    const timestamp = Date.parse(String(message.timestamp || ''));
    return Number.isNaN(timestamp) || timestamp >= Date.now() - effectiveRetentionDays * 24 * 60 * 60 * 1000;
  })), [messages, effectiveRetentionDays]);
  const isTyping = activeChat ? typingUsers.has(activeChat) : false;
  const isMuted = activeChat ? mutedUsers.has(activeChat.toLowerCase()) : false;
  const isBlocked = activeChat ? blockedUsers.has(activeChat.toLowerCase()) : false;

  // Instant scroll on initial load / chat switch, smooth scroll ONLY for single new live messages
  useLayoutEffect(() => {
    if (!messagesContainerRef.current) return;
    const container = messagesContainerRef.current;

    // Detect chat conversation switch synchronously
    if (prevChatIdRef.current !== activeChat) {
      prevChatIdRef.current = activeChat;
      isChatReadyRef.current = false;
      prevMessagesCountRef.current = 0;
      // History arrives asynchronously; keep the view on the newest message
      // through the initial render and the following history reconciliation.
      forceLatestUntilRef.current = Date.now() + 1600;
      setIsAwayFromLatest(false);
      setFirstUnreadMessageId(null);
      setStickyDay('');
    }

    const shouldForceLatest = !isChatReadyRef.current || Date.now() < forceLatestUntilRef.current;
    if (shouldForceLatest) {
      // Instant snap to bottom - multi-stage to account for image/bubble layout updates
      container.scrollTop = container.scrollHeight;
      
      const rafId = requestAnimationFrame(() => {
        if (container) container.scrollTop = container.scrollHeight;
      });

      const timer1 = setTimeout(() => {
        if (container) container.scrollTop = container.scrollHeight;
      }, 50);

      const timer2 = setTimeout(() => {
        if (container) {
          container.scrollTop = container.scrollHeight;
          if (visibleMessages.length > 0) {
            isChatReadyRef.current = true;
          }
        }
      }, 150);

      return () => {
        cancelAnimationFrame(rafId);
        clearTimeout(timer1);
        clearTimeout(timer2);
      };
    } else {
      const isNewLiveMessage = visibleMessages.length > prevMessagesCountRef.current;
      if (isNewLiveMessage) {
        const lastMsg = visibleMessages[visibleMessages.length - 1];
        const isSentByMe = lastMsg?.sender?.toLowerCase() === user?.username?.toLowerCase();
        const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 240;
        if (isSentByMe || isNearBottom) {
          messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
        } else if (!isSentByMe) {
          setFirstUnreadMessageId((current) => current || lastMsg?.id || null);
        }
      }
    }

    prevMessagesCountRef.current = visibleMessages.length;
  }, [visibleMessages, activeChat, user?.username]);

  const handleMessagesScroll = () => {
    const container = messagesContainerRef.current;
    if (!container) return;
    const nearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 160;
    setIsAwayFromLatest(!nearBottom);
    if (nearBottom) setFirstUnreadMessageId(null);

    const dateChips = Array.from(container.querySelectorAll<HTMLElement>('.chat-day-chip[data-day-key]'));
    const matchingChips = dateChips.filter((chip) => chip.offsetTop <= container.scrollTop + 30);
    const currentChip = matchingChips[matchingChips.length - 1];
    setStickyDay(currentChip?.dataset.dayLabel || '');
  };

  const scrollToLatest = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
    setFirstUnreadMessageId(null);
  };

  // Keep scroll pinned to bottom as media or fonts load when first entering a chat
  useEffect(() => {
    if (!messagesContainerRef.current) return;
    const container = messagesContainerRef.current;
    
    const resizeObserver = new ResizeObserver(() => {
      if (!isChatReadyRef.current && container) {
        container.scrollTop = container.scrollHeight;
      }
    });

    resizeObserver.observe(container);
    return () => resizeObserver.disconnect();
  }, [activeChat]);

  // Keep bottom in view when typing indicator toggles
  useEffect(() => {
    if (isTyping && messagesContainerRef.current) {
      const container = messagesContainerRef.current;
      const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 180;
      if (isNearBottom) {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
      }
    }
  }, [isTyping]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setIsCommandPaletteOpen((prev) => !prev);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleWallpaperChange = (newBg: string) => {
    if (activeChat) {
      setChatWallpaper(activeChat, newBg);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (!file) return;

    triggerHaptic('medium');
    try {
      const uploadRes = await uploadMediaFile(file);
      if (uploadRes?.url) {
        sendMessage('', {
          attachment: {
            url: uploadRes.url,
            name: file.name,
            size: file.size,
            mime: file.type,
            kind: file.type.startsWith('image/')
              ? 'image'
              : file.type.startsWith('video/')
              ? 'video'
              : file.type.startsWith('audio/')
              ? 'audio'
              : 'file',
          },
        });
      }
    } catch (err) {
      console.error('[Chat] Drag-drop upload error:', err);
    }
  };

  const pinnedMessages = visibleMessages.filter((m) => Boolean(m.pinnedAt));
  const matchedMessages = searchQuery.trim()
    ? visibleMessages.filter((m) => m.text?.toLowerCase().includes(searchQuery.toLowerCase()))
    : [];

  const handleJumpToMessage = (msgId: string) => {
    const el = document.getElementById(`msg-${msgId}`);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.style.transition = 'all 0.3s ease';
      el.style.filter = 'drop-shadow(0 0 12px rgba(16, 185, 129, 0.8))';
      setTimeout(() => {
        el.style.filter = 'none';
      }, 1500);
    }
  };

  const handleNextMatch = () => {
    if (matchedMessages.length === 0) return;
    const nextIdx = (currentMatchIndex + 1) % matchedMessages.length;
    setCurrentMatchIndex(nextIdx);
    handleJumpToMessage(matchedMessages[nextIdx].id);
  };

  const handlePrevMatch = () => {
    if (matchedMessages.length === 0) return;
    const prevIdx = (currentMatchIndex - 1 + matchedMessages.length) % matchedMessages.length;
    setCurrentMatchIndex(prevIdx);
    handleJumpToMessage(matchedMessages[prevIdx].id);
  };

  const handleForward = (targetUsername: string, msg: Message) => {
    if (!targetUsername || !user) return;

    if (activeChat && activeChat.toLowerCase() === targetUsername.toLowerCase()) {
      sendMessage(msg.text || '', {
        attachment: msg.attachment,
        isVoice: msg.isVoice,
      });
      triggerHaptic('success');
      return;
    }

    const socket = getSocket();
    if (!socket) return;

    const targetConv = conversations.find(
      (c) => c.username.toLowerCase() === targetUsername.toLowerCase()
    );
    const toType = targetConv?.isGroup ? 'group' : 'friend';

    const clientTempId = `tmp_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
    const payload = {
      to: targetUsername,
      toType,
      text: msg.text || (msg.attachment?.kind === 'image' ? '[Image]' : msg.isVoice ? '[Voice Message]' : '[File]'),
      attachment: msg.attachment || null,
      replyTo: null,
      clientTempId,
    };

    socket.emit('private_message', payload);
    triggerHaptic('success');
  };

  if (!activeChat) return <TabWelcome tab="chats" onAction={onStartChat} />;

  return (
    <div style={{ display: 'flex', width: '100%', height: '100%', overflow: 'hidden' }}>
      {/* Central Conversation Column */}
      <div className="chat-window" style={{ flex: 1, minWidth: 0, height: '100%', display: 'flex', flexDirection: 'column' }}>
        {/* Header */}
        <div className="chat-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <button
              type="button"
              className="header-action-btn mobile-only-btn"
              onClick={() => {
                triggerHaptic('light');
                setActiveChat(null);
              }}
              aria-label="Back to chats"
              title="Back to chats"
            >
              <ChevronLeft style={{ width: '20px', height: '20px' }} />
            </button>

            {onToggleList && (
              <button
                type="button"
                className="header-action-btn desktop-only-btn"
                onClick={() => {
                  triggerHaptic('light');
                  onToggleList();
                }}
                aria-label={isListCollapsed ? 'Expand chat list' : 'Collapse chat list'}
                title={isListCollapsed ? 'Expand chat list' : 'Collapse chat list'}
              >
                <PanelLeftOpen style={{ width: '18px', height: '18px', transform: isListCollapsed ? 'scaleX(-1)' : 'none' }} />
              </button>
            )}

            <div
              onClick={() => {
                triggerHaptic('light');
                setIsDetailsOpen((prev) => !prev);
              }}
              style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }}
              title="Click to toggle contact details sidebar"
            >
              <Avatar
                name={activeContact?.displayName || activeChat}
                avatarUrl={activeContact?.avatarId}
                online={activeContact?.online}
                presence={activeContact?.presence}
                isGroup={Boolean(activeContact?.isGroup)}
                size="md"
              />

              <div>
                <div className="chat-header-name">
                  {activeContact?.displayName || activeChat}
                </div>
                <div className={`chat-header-status ${activeContact?.online && !activeContact?.isGroup ? 'online' : ''}`}>
                  {activeContact?.isSelf ? (
                    <span style={{ color: '#5b7c72', fontWeight: 600 }}>Personal notes, links, and reminders</span>
                  ) : isTyping ? (
                    <span style={{ color: '#0e9f8a', fontWeight: 700 }}>typing...</span>
                  ) : activeContact?.isGroup ? (
                    <span style={{ color: '#087fac', fontWeight: 600 }}>{activeContact.memberCount || 2} members</span>
                  ) : activeContact?.presence === 'away' ? (
                    <span style={{ color: '#a86d0b', fontWeight: 600 }}>Away</span>
                  ) : activeContact?.presence === 'busy' ? (
                    <span style={{ color: '#ec4899', fontWeight: 600 }}>Busy</span>
                  ) : activeContact?.online && activeContact?.presence !== 'invisible' ? (
                    <span style={{ color: '#0e9f8a', fontWeight: 600 }}>Online</span>
                  ) : (
                    'Offline'
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Header Action Buttons (Search, Audio, Video, and Contact Info) */}
          <div className="chat-header-actions">
            <button
              type="button"
              className="header-action-btn"
              style={isSearchOpen ? { background: 'rgba(16, 185, 129, 0.2)', color: '#0e9f8a', borderColor: 'rgba(16, 185, 129, 0.4)' } : {}}
              onClick={() => {
                triggerHaptic('light');
                setIsSearchOpen((prev) => !prev);
                if (isSearchOpen) setSearchQuery('');
              }}
              aria-label="Search in conversation"
              title="Search in conversation"
            >
              <Search style={{ width: '16px', height: '16px' }} />
            </button>

            {!activeContact?.isGroup && !activeContact?.isSelf && (
              <>
                <button
                  type="button"
                  className="header-action-btn"
                  onClick={() => {
                    triggerHaptic('medium');
                    startCall(activeChat, false);
                  }}
                  aria-label="Start Audio Call"
                  title="Start Audio Call"
                >
                  <Phone style={{ width: '16px', height: '16px' }} />
                </button>

                <button
                  type="button"
                  className="header-action-btn"
                  onClick={() => {
                    triggerHaptic('medium');
                    startCall(activeChat, true);
                  }}
                  aria-label="Start Video Call"
                  title="Start Video Call"
                >
                  <Video style={{ width: '16px', height: '16px' }} />
                </button>
              </>
            )}

            <button
              type="button"
              className="header-action-btn"
              onClick={() => {
                triggerHaptic('light');
                setIsCommandPaletteOpen(true);
              }}
              aria-label="Quick Actions (Ctrl+K)"
              title="Quick Actions (Ctrl+K)"
            >
              <Command style={{ width: '16px', height: '16px', color: '#087fac' }} />
            </button>

            <button
              type="button"
              className="header-action-btn"
              style={isDetailsOpen ? { background: 'rgba(16, 185, 129, 0.2)', color: '#0e9f8a', borderColor: 'rgba(16, 185, 129, 0.4)' } : {}}
              onClick={() => {
                triggerHaptic('light');
                setIsDetailsOpen((prev) => !prev);
              }}
              aria-label="Contact Info & Media"
              title="Contact Info & Media"
            >
              <Info style={{ width: '16px', height: '16px' }} />
            </button>

            <button
              type="button"
              className="header-action-btn"
              onClick={() => {
                triggerHaptic('light');
                setActiveChat(null);
              }}
              aria-label="Close chat"
              title="Close chat"
            >
              <X style={{ width: '16px', height: '16px' }} />
            </button>
          </div>
        </div>

        {/* In-Chat Message Search Bar */}
        <InChatSearch
          isOpen={isSearchOpen}
          query={searchQuery}
          onQueryChange={(q) => {
            setSearchQuery(q);
            setCurrentMatchIndex(0);
          }}
          matchesCount={matchedMessages.length}
          currentMatchIndex={currentMatchIndex}
          onPrevMatch={handlePrevMatch}
          onNextMatch={handleNextMatch}
          onClose={() => {
            setIsSearchOpen(false);
            setSearchQuery('');
          }}
        />

        {/* Top Pinned Message Banner */}
        <PinnedMessageBanner
          pinnedMessages={pinnedMessages}
          onJumpToMessage={handleJumpToMessage}
          onUnpin={(msgId) => unpinMessage(msgId)}
        />

        {/* Drag & Drop File Upload Overlay */}
        <DropZoneOverlay isDragging={isDragging} onFileSelect={() => {}} />

        {/* Message Stream with Synced Background Wallpaper */}
        <div
          ref={messagesContainerRef}
          className="messages-container"
          style={{ background: chatBackground, position: 'relative' }}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onScroll={handleMessagesScroll}
        >
          {isAwayFromLatest && stickyDay && (
            <div className="chat-sticky-day-chip" aria-hidden="true">{stickyDay}</div>
          )}
          {/* Encryption scope banner — Saved Messages has no remote peer to negotiate with. */}
          {!activeContact?.isSelf && <div
            className="encryption-scope-banner"
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              padding: '7px 14px',
              margin: '10px auto 14px',
              maxWidth: '460px',
              borderRadius: '10px',
              background: 'rgba(251, 191, 36, 0.07)',
              border: '1px solid rgba(251, 191, 36, 0.18)',
              boxShadow: '0 4px 12px rgba(36, 76, 96, 0.1)',
              textAlign: 'center',
              flexShrink: 0,
            }}
          >
            <Lock style={{ width: '13px', height: '13px', color: '#a0690b', flexShrink: 0 }} />
            <span style={{ fontSize: '0.73rem', color: '#a0690b', lineHeight: 1.35, fontWeight: 500 }}>
              {activeContact?.isGroup
                ? 'Group messages are not end-to-end encrypted yet.'
                : activeContact?.publicKey
                  ? 'End-to-end encrypted · Only chat members can read this.'
                  : 'Encryption is unavailable until both contacts have registered device keys.'}
            </span>
          </div>}

          {visibleMessages.length === 0 ? (
            <div style={{ margin: 'auto', textAlign: 'center', color: 'var(--text-dark)', fontSize: '0.85rem' }}>
              No messages yet. Send a message to start! 👋
            </div>
          ) : (
            visibleMessages.map((msg, index) => {
              const showDayChip = index === 0 || messageDayKey(visibleMessages[index - 1].timestamp) !== messageDayKey(msg.timestamp);

              return (
              <React.Fragment key={msg.id}>
                {showDayChip && (
                  <div className="chat-day-chip" data-day-key={messageDayKey(msg.timestamp)} data-day-label={messageDayLabel(msg.timestamp)} role="separator" aria-label={messageDayLabel(msg.timestamp)}>
                    {messageDayLabel(msg.timestamp)}
                  </div>
                )}
                {firstUnreadMessageId === msg.id && (
                  <div className="chat-unread-divider"><span>Unread messages</span></div>
                )}
              <MessageBubble
                message={msg}
                grouped={groupsWithPrevious(visibleMessages[index - 1], msg, getPreferredTimeZone())}
                onRetry={retryMessage}
                isMe={msg.sender?.toLowerCase() === user?.username.toLowerCase()}
                onReply={(m) => setReplyMessage(m)}
                onReaction={(id, emoji) => addReaction(id, emoji)}
                onMediaClick={(url) => setSelectedMedia(url)}
                onForward={(m) => setForwardMessage(m)}
                onPin={(id) => pinMessage(id)}
                onUnpin={(id) => unpinMessage(id)}
                onUnsend={(id) => unsendMessage(id)}
                onEdit={(id, text) => editMessage(id, text)}
                onVotePoll={votePoll}
                onMoveGame={makeGameMove}
                onRematchGame={(id) => {
                  const target = visibleMessages.find((m) => m.id === id || m.game?.id === id);
                  if (target?.game) {
                    sendGameChallenge(target.game.gameType);
                  }
                }}
                onJumpToMessage={handleJumpToMessage}
                currentUsername={user?.username}
                searchQuery={searchQuery}
                isGroup={Boolean(activeContact?.isGroup)}
              />
              </React.Fragment>
              );
            })
          )}

          {/* Animated typing indicator wave */}
          {isTyping && (
            <div className="bubble-row other">
              <div className="bubble other" style={{ padding: '10px 16px', display: 'flex', gap: '5px', alignItems: 'center', minHeight: '34px' }}>
                <span className="typing-dot" />
                <span className="typing-dot" />
                <span className="typing-dot" />
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
          {isAwayFromLatest && (
            <button type="button" className="scroll-latest-button" onClick={scrollToLatest} aria-label="Scroll to latest messages">
              <ArrowDown size={17} />
              {firstUnreadMessageId && <span>New</span>}
            </button>
          )}
        </div>

        {/* Input Bar */}
        <div className="chat-input-bar">
          <MessageInput
            onSendMessage={sendMessage}
            onTyping={sendTyping}
            replyMessage={replyMessage}
            onCancelReply={() => setReplyMessage(null)}
            onCreatePoll={activeContact?.isSelf ? undefined : createPoll}
            onOpenGames={activeContact?.isSelf ? undefined : () => setIsGameLauncherOpen(true)}
            activeChatId={activeChat}
            mentionMembers={activeContact?.isGroup ? activeContact.members || [] : []}
          />
        </div>
      </div>

      {/* Right Side Contact & Media Details Sidebar */}
      <ContactDetailsSidebar
        isOpen={isDetailsOpen}
        onClose={() => setIsDetailsOpen(false)}
        contact={activeContact || { username: activeChat, displayName: activeChat, unreadCount: 0, online: false }}
        messages={visibleMessages}
        onAudioCall={(u) => startCall(u, false)}
        onVideoCall={(u) => startCall(u, true)}
        onToggleMute={(u, m) => muteUser(u, m)}
        onToggleBlock={(u, b) => blockUser(u, b)}
        onUnfriend={(u) => unfriendUser(u)}
        onClearChat={(u) => clearChat(u)}
        onMediaClick={(url) => setSelectedMedia(url)}
        isMuted={isMuted}
        isBlocked={isBlocked}
        retentionDays={chatRetentionDays}
        accountRetentionDays={retentionDays}
        onRetentionChange={(days) => {
          if (!activeChat || !user?.username) return;
          const key = `novyn_chat_retention_${user.username.toLowerCase()}_${activeChat.toLowerCase()}`;
          if (days === null) localStorage.removeItem(key);
          else localStorage.setItem(key, String(days));
          setChatRetentionDays(days);
          triggerHaptic('light');
        }}
      />

      {/* In-Chat Mini Games Launcher */}
      <GameLauncherModal
        isOpen={isGameLauncherOpen}
        onClose={() => setIsGameLauncherOpen(false)}
        onLaunchGame={(type) => sendGameChallenge(type)}
        opponentName={activeContact?.displayName || activeChat || ''}
        isGroup={Boolean(activeContact?.isGroup)}
      />

      {/* Media Lightbox */}
      <MediaViewerModal
        mediaUrl={selectedMedia}
        onClose={() => setSelectedMedia(null)}
      />

      {/* Forward Message Modal */}
      <ForwardModal
        message={forwardMessage}
        conversations={conversations}
        onClose={() => setForwardMessage(null)}
        onForward={handleForward}
      />

      {/* Wallpaper Picker Modal */}
      <WallpaperPickerModal
        isOpen={isWallpaperModalOpen}
        onClose={() => setIsWallpaperModalOpen(false)}
        currentWallpaper={chatWallpaper}
        onSelectWallpaper={handleWallpaperChange}
      />

      {/* Command Palette Modal (Ctrl+K) */}
      <CommandPaletteModal
        isOpen={isCommandPaletteOpen}
        onClose={() => setIsCommandPaletteOpen(false)}
        conversations={conversations}
        activeChat={activeChat}
        onSelectChat={(u) => setActiveChat(u)}
        onAudioCall={(u) => startCall(u, false)}
        onVideoCall={(u) => startCall(u, true)}
        onOpenPollModal={() => {
          const el = document.querySelector('.input-actions') as HTMLElement;
          if (el) el.scrollIntoView();
        }}
        onOpenWallpaperModal={() => setIsWallpaperModalOpen(true)}
        onOpenQRModal={() => setIsDetailsOpen(true)}
        onOpenExportModal={() => setIsDetailsOpen(true)}
        onOpenSearch={() => setIsSearchOpen(true)}
      />
    </div>
  );
};
