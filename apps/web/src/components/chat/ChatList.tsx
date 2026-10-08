import { getPreferredLocale, getPreferredTimeZone, getPreferredDayKey } from '../../services/regionalPreferences';
import React, { useState, useEffect, useRef } from 'react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import {
  Search,
  UserPlus,
  Users,
  MessageSquare,
  Pin,
  PinOff,
  Bell,
  BellOff,
  Star,
  Archive,
  ArchiveRestore,
  Mail,
  MailCheck,
  Ban,
  Trash2,
  LogOut,
  ChevronDown,
  ArrowLeft,
  X,
  Check,
  SquarePen,
  KeyRound,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { CreateGroupModal } from './CreateGroupModal';
import { Conversation } from '../../types';
import { MessageKeyTransferDialog } from './MessageKeyTransferDialog';

interface ChatListProps {
  onOpenContacts: () => void;
  isCompact?: boolean;
}

type FilterTab = 'all' | 'unread' | 'favourites' | 'groups';

export const ChatList: React.FC<ChatListProps> = ({
  onOpenContacts,
  isCompact = false,
}) => {
  const {
    conversations,
    activeChat,
    setActiveChat,
    pinnedChats,
    archivedChats,
    favouriteChats,
    manualUnreadChats,
    mutedUsers,
    blockedUsers,
    togglePinChat,
    toggleArchiveChat,
    toggleFavouriteChat,
    markChatUnread,
    muteUser,
    blockUser,
    clearChat,
    unfriendUser,
    leaveGroup,
  } = useChat();

  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<FilterTab>('all');
  const [isViewingArchived, setIsViewingArchived] = useState(false);
  const [isGroupModalOpen, setIsGroupModalOpen] = useState(false);
  const [isComposeOpen, setIsComposeOpen] = useState(false);
  const [isKeyTransferOpen, setIsKeyTransferOpen] = useState(false);
  const composeRef = useRef<HTMLDivElement>(null);

  // Context Menu State
  const [menuOpenFor, setMenuOpenFor] = useState<string | null>(null);
  const [menuPosition, setMenuPosition] = useState<{ x: number; y: number } | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  // Action Confirmation Modal
  const [confirmAction, setConfirmAction] = useState<{
    type: 'clear' | 'delete' | 'leave' | 'block';
    target: Conversation;
  } | null>(null);

  // Close context menu on outside click
  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (composeRef.current && !composeRef.current.contains(e.target as Node)) setIsComposeOpen(false);
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpenFor(null);
        setMenuPosition(null);
      }
    };
    window.addEventListener('mousedown', handleOutsideClick);
    return () => window.removeEventListener('mousedown', handleOutsideClick);
  }, []);

  const formatLastSeen = (ts?: string | number) => {
    if (!ts) return '';
    try {
      const d = new Date(ts);
      const now = new Date();
      const isToday = getPreferredDayKey(d) === getPreferredDayKey(now);
      return isToday
        ? d.toLocaleTimeString(getPreferredLocale(), { timeZone: getPreferredTimeZone(), hour: '2-digit', minute: '2-digit' })
        : d.toLocaleDateString(getPreferredLocale(), { timeZone: getPreferredTimeZone(), month: 'short', day: 'numeric' });
    } catch {
      return '';
    }
  };

  // Filter conversations
  const filteredConversations = conversations
    .filter((c) => {
      const key = c.username.toLowerCase();
      const isArchived = archivedChats.has(key);

      // Separate Archived View vs Main View
      if (isViewingArchived) {
        if (!isArchived) return false;
      } else {
        if (isArchived) return false;
      }

      // Filter Tabs
      if (activeFilter === 'unread') {
        const isUnread = c.unreadCount > 0 || manualUnreadChats.has(key);
        if (!isUnread) return false;
      } else if (activeFilter === 'favourites') {
        if (!favouriteChats.has(key)) return false;
      } else if (activeFilter === 'groups') {
        if (!c.isGroup) return false;
      }

      // Search Query
      const query = searchQuery.toLowerCase();
      return (
        (c.displayName && c.displayName.toLowerCase().includes(query)) ||
        c.username.toLowerCase().includes(query)
      );
    })
    .sort((a, b) => {
      const keyA = a.username.toLowerCase();
      const keyB = b.username.toLowerCase();
      const isPinnedA = pinnedChats.has(keyA);
      const isPinnedB = pinnedChats.has(keyB);

      // Pinned chats stay on top
      if (isPinnedA && !isPinnedB) return -1;
      if (!isPinnedA && isPinnedB) return 1;

      // Sort by recent message time or last seen
      const timeA = new Date(a.lastMessage?.timestamp || a.lastSeenAt || 0).getTime();
      const timeB = new Date(b.lastMessage?.timestamp || b.lastSeenAt || 0).getTime();
      return timeB - timeA;
    });

  const archivedCount = conversations.filter((c) =>
    archivedChats.has(c.username.toLowerCase())
  ).length;

  const unreadCountTotal = conversations.filter(
    (c) =>
      !archivedChats.has(c.username.toLowerCase()) &&
      (c.unreadCount > 0 || manualUnreadChats.has(c.username.toLowerCase()))
  ).length;

  const handleOpenMenu = (
    e: React.MouseEvent,
    convUsername: string,
    isRightClick = false
  ) => {
    e.preventDefault();
    e.stopPropagation();
    triggerHaptic('light');

    if (isRightClick) {
      setMenuPosition({ x: Math.min(e.clientX, window.innerWidth - 220), y: Math.min(e.clientY, window.innerHeight - 300) });
    } else {
      const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
      setMenuPosition({ x: Math.min(rect.right - 200, window.innerWidth - 220), y: Math.min(rect.bottom + 4, window.innerHeight - 300) });
    }
    setMenuOpenFor(convUsername);
  };

  const handleExecuteConfirmedAction = () => {
    if (!confirmAction) return;
    const { type, target } = confirmAction;

    if (type === 'clear') {
      clearChat(target.username);
    } else if (type === 'delete') {
      unfriendUser(target.username);
      if (activeChat?.toLowerCase() === target.username.toLowerCase()) {
        setActiveChat(null);
      }
    } else if (type === 'leave') {
      leaveGroup(target.username);
      if (activeChat?.toLowerCase() === target.username.toLowerCase()) {
        setActiveChat(null);
      }
    } else if (type === 'block') {
      blockUser(target.username, !blockedUsers.has(target.username.toLowerCase()));
    }

    setConfirmAction(null);
  };

  if (isCompact) {
    return (
      <div
        className="chat-list-panel"
        style={{
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          padding: '16px 0',
          gap: '10px',
          boxSizing: 'border-box',
        }}
      >
        <button
          type="button"
          onClick={() => {
            triggerHaptic('light');
            onOpenContacts();
          }}
          style={{
            width: '42px',
            height: '42px',
            borderRadius: '12px',
            background: 'rgba(16, 185, 129, 0.12)',
            border: '1px solid rgba(16, 185, 129, 0.25)',
            color: '#0e9f8a',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            flexShrink: 0,
            marginBottom: '8px',
          }}
          title="Add Friend"
        >
          <UserPlus style={{ width: '18px', height: '18px' }} />
        </button>

        <div
          className="conversations-scroll"
          style={{
            width: '100%',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '8px',
            padding: '0',
          }}
        >
          {filteredConversations.map((conv) => {
            const isSelected = activeChat?.toLowerCase() === conv.username.toLowerCase();
            const isPinned = pinnedChats.has(conv.username.toLowerCase());
            const isUnread = conv.unreadCount > 0 || manualUnreadChats.has(conv.username.toLowerCase());

            return (
              <div
                key={conv.username}
                onClick={() => {
                  triggerHaptic('light');
                  setActiveChat(conv.username);
                  if (manualUnreadChats.has(conv.username.toLowerCase())) {
                    markChatUnread(conv.username, false);
                  }
                }}
                style={{
                  position: 'relative',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: '56px',
                  height: '52px',
                  borderRadius: '14px',
                  background: isSelected ? 'rgba(16, 185, 129, 0.12)' : 'transparent',
                  transition: 'all 0.15s ease',
                  flexShrink: 0,
                }}
                title={`${conv.displayName || conv.username} ${isUnread ? '(Unread)' : ''}`}
              >
                {/* Left Active Pill Indicator */}
                {isSelected && (
                  <span
                    style={{
                      position: 'absolute',
                      left: '0',
                      width: '4px',
                      height: '24px',
                      borderRadius: '0 4px 4px 0',
                      background: '#10b981',
                      boxShadow: '0 0 8px rgba(16, 185, 129, 0.7)',
                    }}
                  />
                )}

                <Avatar
                  name={conv.displayName || conv.username}
                  avatarUrl={conv.avatarId}
                  online={conv.online}
                  presence={conv.presence}
                  isGroup={conv.isGroup}
                  hidePresence={conv.isSelf}
                  size="md"
                />

                {/* Pinned Dot Indicator */}
                {isPinned && (
                  <span
                    style={{
                      position: 'absolute',
                      top: '4px',
                      left: '8px',
                      width: '6px',
                      height: '6px',
                      borderRadius: '50%',
                      background: '#10b981',
                    }}
                  />
                )}

                {isUnread && (
                  <span
                    style={{
                      position: 'absolute',
                      top: '2px',
                      right: '4px',
                      background: '#10b981',
                      color: 'var(--text-on-primary)',
                      fontSize: '0.62rem',
                      fontWeight: 800,
                      padding: '1px 5px',
                      borderRadius: '9999px',
                      border: '2px solid #e4f0f0',
                    }}
                  >
                    {conv.unreadCount > 0 ? conv.unreadCount : ''}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  const selectedMenuConv = conversations.find(
    (c) => c.username.toLowerCase() === menuOpenFor?.toLowerCase()
  );

  return (
    <div className="chat-list-panel" style={{ width: '100%', position: 'relative' }}>
      {/* Top Header */}
      <div className="chat-list-header">
        {isViewingArchived ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <button
              type="button"
              onClick={() => setIsViewingArchived(false)}
              className="header-action-btn"
              style={{ width: '32px', height: '32px' }}
              title="Back to all chats"
            >
              <ArrowLeft style={{ width: '16px', height: '16px' }} />
            </button>
            <h2 className="chat-list-title">Archived</h2>
          </div>
        ) : (
          <h2 className="chat-list-title">Messages</h2>
        )}

        <button type="button" className="header-action-btn" title="Transfer message keys"
          aria-label="Transfer message keys" onClick={() => setIsKeyTransferOpen(true)}>
          <KeyRound size={19} />
        </button>
        <div className="inbox-compose" ref={composeRef} onKeyDown={(event) => {
          if (event.key === 'Escape') {
            setIsComposeOpen(false);
            composeRef.current?.querySelector<HTMLButtonElement>('.inbox-compose-trigger')?.focus();
          }
        }} onBlur={(event) => { if (!event.currentTarget.contains(event.relatedTarget)) setIsComposeOpen(false); }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setIsComposeOpen((open) => !open);
            }}
            className="header-action-btn inbox-compose-trigger"
            title="Compose"
            aria-label="Compose a message"
            aria-expanded={isComposeOpen}
          >
            <SquarePen size={19} />
          </button>
          {isComposeOpen && <div className="inbox-compose-options" role="group" aria-label="New conversation">
            <button type="button" onClick={() => { setIsComposeOpen(false); onOpenContacts(); }}><SquarePen size={17} /> New message</button>
            <button type="button" onClick={() => { setIsComposeOpen(false); setIsGroupModalOpen(true); }}><Users size={17} /> New group</button>
          </div>}
        </div>
      </div>

      {/* Search Bar */}
      <div className="chat-search-box">
        <div className="search-input-wrapper">
          <Search className="search-icon" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={isViewingArchived ? 'Search archived chats...' : 'Search conversations...'}
            className="search-input-field"
            aria-label="Search conversations"
          />
        </div>
      </div>

      {/* Always-visible filters with a shared sliding selection pill. */}
      {!isViewingArchived && (
        <div className="chat-filters-viewport">
        <div
          className="chat-filters"
          role="group"
          aria-label="Filter conversations"
          style={{
            '--filter-index': ['all', 'unread', 'favourites', 'groups'].indexOf(activeFilter),
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '0 16px 12px',
            overflowX: 'auto',
            scrollbarWidth: 'none',
          } as React.CSSProperties}
        >
          <span className="chat-filter-pill" aria-hidden="true" />
          <button
            type="button"
            aria-pressed={activeFilter === 'all'}
            onClick={() => {
              triggerHaptic('light');
              setActiveFilter('all');
            }}
            style={{
              padding: '5px 12px',
              borderRadius: '9999px',
              border: 'none',
              background: activeFilter === 'all' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.55)',
              color: activeFilter === 'all' ? '#0e9f8a' : 'var(--text-muted)',
              fontWeight: 700,
              fontSize: '0.76rem',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              transition: 'all 0.15s ease',
            }}
          >
            All
          </button>

          <button
            type="button"
            aria-pressed={activeFilter === 'unread'}
            onClick={() => {
              triggerHaptic('light');
              setActiveFilter('unread');
            }}
            style={{
              padding: '5px 12px',
              borderRadius: '9999px',
              border: 'none',
              background: activeFilter === 'unread' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.55)',
              color: activeFilter === 'unread' ? '#0e9f8a' : 'var(--text-muted)',
              fontWeight: 700,
              fontSize: '0.76rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '5px',
              whiteSpace: 'nowrap',
              transition: 'all 0.15s ease',
            }}
          >
            Unread
            {unreadCountTotal > 0 && (
              <span
                className="chat-filter-count"
                style={{
                  background: activeFilter === 'unread' ? '#10b981' : 'rgba(255, 255, 255, 0.55)',
                  color: 'var(--text-main)',
                  fontSize: '0.62rem',
                  padding: '1px 5px',
                  borderRadius: '9999px',
                  fontWeight: 800,
                }}
              >
                {unreadCountTotal > 99 ? '99+' : unreadCountTotal}
              </span>
            )}
          </button>

          <button
            type="button"
            aria-pressed={activeFilter === 'favourites'}
            onClick={() => {
              triggerHaptic('light');
              setActiveFilter('favourites');
            }}
            style={{
              padding: '5px 12px',
              borderRadius: '9999px',
              border: 'none',
              background: activeFilter === 'favourites' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.55)',
              color: activeFilter === 'favourites' ? '#0e9f8a' : 'var(--text-muted)',
              fontWeight: 700,
              fontSize: '0.76rem',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              transition: 'all 0.15s ease',
            }}
          >
            Favourites
          </button>

          <button
            type="button"
            aria-pressed={activeFilter === 'groups'}
            onClick={() => {
              triggerHaptic('light');
              setActiveFilter('groups');
            }}
            style={{
              padding: '5px 12px',
              borderRadius: '9999px',
              border: 'none',
              background: activeFilter === 'groups' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.55)',
              color: activeFilter === 'groups' ? '#0e9f8a' : 'var(--text-muted)',
              fontWeight: 700,
              fontSize: '0.76rem',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              transition: 'all 0.15s ease',
            }}
          >
            Groups
          </button>
        </div>
        </div>
      )}

      {/* Archived Row Banner (when not in archived view and archived chats exist) */}
      {!isViewingArchived && archivedCount > 0 && (
        <div
          onClick={() => {
            triggerHaptic('light');
            setIsViewingArchived(true);
          }}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '10px 20px',
            cursor: 'pointer',
            borderBottom: '1px solid var(--border)',
            background: 'rgba(255, 255, 255, 0.55)',
            transition: 'background 0.15s ease',
          }}
          onMouseEnter={(e) => ((e.currentTarget as HTMLElement).style.background = 'rgba(255, 255, 255, 0.55)')}
          onMouseLeave={(e) => ((e.currentTarget as HTMLElement).style.background = 'rgba(255, 255, 255, 0.55)')}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Archive style={{ width: '18px', height: '18px', color: '#0e9f8a' }} />
            <span style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>Archived</span>
          </div>
          <span
            style={{
              fontSize: '0.72rem',
              fontWeight: 800,
              color: '#0e9f8a',
              background: 'rgba(16, 185, 129, 0.15)',
              padding: '2px 8px',
              borderRadius: '9999px',
            }}
          >
            {archivedCount}
          </span>
        </div>
      )}

      {/* Conversations Stream */}
      <div className="conversations-scroll">
        {filteredConversations.length === 0 ? (
          <div style={{ padding: '40px 20px', textAlign: 'center', color: 'var(--text-dark)' }}>
            <MessageSquare style={{ width: '36px', height: '36px', margin: '0 auto 12px', color: 'var(--primary)' }} />
            <p style={{ fontSize: '0.85rem', marginBottom: '8px' }}>
              {searchQuery.trim() ? 'No conversations match your search' : isViewingArchived
                ? 'No archived conversations'
                : activeFilter === 'unread'
                ? 'No unread conversations'
                : activeFilter === 'favourites'
                ? 'No favourite conversations'
                : activeFilter === 'groups'
                ? 'No group conversations'
                : 'No conversations yet'}
            </p>
            {searchQuery.trim() ? <button type="button" className="empty-state-action" onClick={() => setSearchQuery('')}>Clear search</button> : !isViewingArchived && activeFilter === 'all' && (
              <button
                type="button"
                onClick={onOpenContacts}
                style={{ background: 'none', border: 'none', color: '#0e9f8a', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer' }}
              >
                + Add a friend to start
              </button>
            )}
          </div>
        ) : (
          filteredConversations.map((conv) => {
            const isSelected = activeChat?.toLowerCase() === conv.username.toLowerCase();
            const key = conv.username.toLowerCase();
            const isPinned = pinnedChats.has(key);
            const isMuted = mutedUsers.has(key);
            const isFav = favouriteChats.has(key);
            const isUnread = conv.unreadCount > 0 || manualUnreadChats.has(key);

            return (
              <div
                key={conv.username}
                onClick={() => {
                  triggerHaptic('light');
                  setActiveChat(conv.username);
                  if (manualUnreadChats.has(key)) {
                    markChatUnread(conv.username, false);
                  }
                }}
                onContextMenu={(e) => handleOpenMenu(e, conv.username, true)}
                className={`chat-list-item ${isSelected ? 'selected' : ''}`}
                tabIndex={0}
                role="link"
                aria-label={`Open conversation with ${conv.displayName || conv.username}`}
                onKeyDown={(event) => {
                  if (event.target === event.currentTarget && (event.key === 'Enter' || event.key === ' ')) { event.preventDefault(); event.currentTarget.click(); }
                }}
                style={{ position: 'relative', overflow: 'visible' }}
              >
                <Avatar
                  name={conv.displayName || conv.username}
                  avatarUrl={conv.avatarId}
                  online={conv.online}
                  presence={conv.presence}
                  isGroup={conv.isGroup}
                  hidePresence={conv.isSelf}
                  size="md"
                />

                <div className="chat-item-info">
                  <div className="chat-item-top">
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', minWidth: 0, flex: 1 }}>
                      <span className="chat-item-name">{conv.displayName || conv.username}</span>
                      {isFav && <Star style={{ width: '12px', height: '12px', color: '#a86d0b', fill: '#a86d0b', flexShrink: 0 }} />}
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexShrink: 0 }}>
                      <span className="chat-item-time" style={isUnread ? { color: '#0e9f8a', fontWeight: 700 } : {}}>
                        {formatLastSeen(conv.lastMessage?.timestamp || conv.lastSeenAt)}
                      </span>
                    </div>
                  </div>

                  <div className="chat-item-bottom">
                    <span className="chat-item-preview" style={isUnread ? { color: 'var(--text-main)', fontWeight: 600 } : {}}>
                      {conv.lastMessage ? (
                        conv.lastMessage.isVoice ? (
                          '🎤 Voice message'
                        ) : conv.lastMessage.attachment ? (
                          '📎 Attachment'
                        ) : (
                          conv.lastMessage.text
                        )
                      ) : (
                        'Tap to chat'
                      )}
                    </span>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexShrink: 0 }}>
                      {isMuted && (
                        <BellOff style={{ width: '13px', height: '13px', color: 'rgba(20, 52, 63, 0.45)' }} />
                      )}

                      {isPinned && (
                        <Pin style={{ width: '13px', height: '13px', color: '#0e9f8a', transform: 'rotate(45deg)' }} />
                      )}

                      {isUnread && (
                        <span className="unread-badge">
                          {conv.unreadCount > 0 ? conv.unreadCount : ''}
                        </span>
                      )}

                      {/* Dropdown Chevron Options Button (WhatsApp style) */}
                      <button
                        type="button"
                        onClick={(e) => handleOpenMenu(e, conv.username, false)}
                        className="chat-item-options-btn"
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: 'var(--text-muted)',
                          padding: '2px',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          opacity: 0,
                          transition: 'opacity 0.15s ease',
                        }}
                        title="Chat options"
                      >
                        <ChevronDown style={{ width: '16px', height: '16px' }} />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Floating WhatsApp-Style Chat Options Context Menu */}
      {menuOpenFor && menuPosition && selectedMenuConv && (
        <div
          ref={menuRef}
          style={{
            position: 'fixed',
            left: `${menuPosition.x}px`,
            top: `${menuPosition.y}px`,
            width: '210px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '14px',
            boxShadow: '0 12px 36px rgba(36, 76, 96, 0.1)',
            zIndex: 9999,
            padding: '6px',
            display: 'flex',
            flexDirection: 'column',
            gap: '2px',
            animation: 'dropdownFadeIn 0.15s ease',
          }}
        >
          {/* 1. Pin / Unpin */}
          <button
            type="button"
            onClick={() => {
              togglePinChat(selectedMenuConv.username);
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            {pinnedChats.has(selectedMenuConv.username.toLowerCase()) ? (
              <>
                <PinOff style={{ width: '15px', height: '15px', color: 'var(--text-muted)' }} />
                <span>Unpin chat</span>
              </>
            ) : (
              <>
                <Pin style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
                <span>Pin chat</span>
              </>
            )}
          </button>

          {/* 2. Mute / Unmute */}
          <button
            type="button"
            onClick={() => {
              const isMuted = mutedUsers.has(selectedMenuConv.username.toLowerCase());
              muteUser(selectedMenuConv.username, !isMuted);
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            {mutedUsers.has(selectedMenuConv.username.toLowerCase()) ? (
              <>
                <Bell style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
                <span>Unmute notifications</span>
              </>
            ) : (
              <>
                <BellOff style={{ width: '15px', height: '15px', color: '#a86d0b' }} />
                <span>Mute notifications</span>
              </>
            )}
          </button>

          {/* 3. Star / Favourite */}
          <button
            type="button"
            onClick={() => {
              toggleFavouriteChat(selectedMenuConv.username);
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            <Star
              style={{
                width: '15px',
                height: '15px',
                color: favouriteChats.has(selectedMenuConv.username.toLowerCase()) ? '#a86d0b' : 'var(--text-muted)',
                fill: favouriteChats.has(selectedMenuConv.username.toLowerCase()) ? '#a86d0b' : 'none',
              }}
            />
            <span>
              {favouriteChats.has(selectedMenuConv.username.toLowerCase())
                ? 'Remove from favourites'
                : 'Add to favourites'}
            </span>
          </button>

          {/* 4. Mark as Unread / Read */}
          <button
            type="button"
            onClick={() => {
              const isUnread =
                selectedMenuConv.unreadCount > 0 ||
                manualUnreadChats.has(selectedMenuConv.username.toLowerCase());
              markChatUnread(selectedMenuConv.username, !isUnread);
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            {selectedMenuConv.unreadCount > 0 ||
            manualUnreadChats.has(selectedMenuConv.username.toLowerCase()) ? (
              <>
                <MailCheck style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
                <span>Mark as read</span>
              </>
            ) : (
              <>
                <Mail style={{ width: '15px', height: '15px', color: '#087fac' }} />
                <span>Mark as unread</span>
              </>
            )}
          </button>

          {/* 5. Archive / Unarchive */}
          <button
            type="button"
            onClick={() => {
              toggleArchiveChat(selectedMenuConv.username);
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            {archivedChats.has(selectedMenuConv.username.toLowerCase()) ? (
              <>
                <ArchiveRestore style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
                <span>Unarchive chat</span>
              </>
            ) : (
              <>
                <Archive style={{ width: '15px', height: '15px', color: 'var(--text-muted)' }} />
                <span>Archive chat</span>
              </>
            )}
          </button>

          <div style={{ height: '1px', background: 'rgba(255, 255, 255, 0.55)', margin: '4px 0' }} />

          {/* 6. Block (1-on-1 chats only) */}
          {!selectedMenuConv.isGroup && (
            <button
              type="button"
              onClick={() => {
                setConfirmAction({ type: 'block', target: selectedMenuConv });
                setMenuOpenFor(null);
              }}
              className="context-menu-item"
            >
              <Ban style={{ width: '15px', height: '15px', color: '#ef4444' }} />
              <span style={{ color: '#ef4444' }}>
                {blockedUsers.has(selectedMenuConv.username.toLowerCase())
                  ? 'Unblock user'
                  : 'Block user'}
              </span>
            </button>
          )}

          {/* 7. Clear Chat */}
          <button
            type="button"
            onClick={() => {
              setConfirmAction({ type: 'clear', target: selectedMenuConv });
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            <Trash2 style={{ width: '15px', height: '15px', color: '#ef4444' }} />
            <span style={{ color: '#ef4444' }}>Clear chat</span>
          </button>

          {/* 8. Delete Chat / Leave Group */}
          <button
            type="button"
            onClick={() => {
              setConfirmAction({
                type: selectedMenuConv.isGroup ? 'leave' : 'delete',
                target: selectedMenuConv,
              });
              setMenuOpenFor(null);
            }}
            className="context-menu-item"
          >
            {selectedMenuConv.isGroup ? (
              <>
                <LogOut style={{ width: '15px', height: '15px', color: '#ef4444' }} />
                <span style={{ color: '#ef4444' }}>Exit group</span>
              </>
            ) : (
              <>
                <Trash2 style={{ width: '15px', height: '15px', color: '#ef4444' }} />
                <span style={{ color: '#ef4444' }}>Delete chat</span>
              </>
            )}
          </button>
        </div>
      )}

      {/* Confirmation Modal for Destructive Options */}
      {confirmAction && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(23, 66, 78, 0.12)',
            backdropFilter: 'blur(6px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10000,
            padding: '20px',
          }}
          onClick={() => setConfirmAction(null)}
        >
          <div
            style={{
              width: '100%',
              maxWidth: '380px',
              background: 'var(--bg-surface)',
              border: '1px solid var(--border)',
              borderRadius: '16px',
              padding: '22px',
              boxShadow: '0 20px 40px rgba(36, 76, 96, 0.1)',
              animation: 'scaleUp 0.15s ease',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              {confirmAction.type === 'clear'
                ? 'Clear this chat?'
                : confirmAction.type === 'delete'
                ? 'Delete chat and contact?'
                : confirmAction.type === 'leave'
                ? 'Exit group?'
                : 'Block user?'}
            </h3>
            <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', lineHeight: 1.5, marginBottom: '20px' }}>
              {confirmAction.type === 'clear'
                ? `Messages with ${confirmAction.target.displayName || confirmAction.target.username} will be deleted from your device.`
                : confirmAction.type === 'delete'
                ? `Are you sure you want to remove @${confirmAction.target.username} from your contacts?`
                : confirmAction.type === 'leave'
                ? `You will leave "${confirmAction.target.displayName || confirmAction.target.username}". You won't receive future messages unless re-added.`
                : `Blocked users will not be able to message or call you.`}
            </p>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={() => setConfirmAction(null)}
                style={{
                  padding: '9px 16px',
                  borderRadius: '10px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: 'none',
                  color: 'var(--text-main)',
                  fontSize: '0.84rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                Cancel
              </button>

              <button
                type="button"
                onClick={handleExecuteConfirmedAction}
                style={{
                  padding: '9px 16px',
                  borderRadius: '10px',
                  background: '#ef4444',
                  border: 'none',
                  color: 'var(--text-on-primary)',
                  fontSize: '0.84rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                }}
              >
                {confirmAction.type === 'clear'
                  ? 'Clear Chat'
                  : confirmAction.type === 'delete'
                  ? 'Delete'
                  : confirmAction.type === 'leave'
                  ? 'Exit Group'
                  : 'Block User'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create Group Modal */}
      <MessageKeyTransferDialog isOpen={isKeyTransferOpen} onClose={() => setIsKeyTransferOpen(false)} />
      <CreateGroupModal
        isOpen={isGroupModalOpen}
        onClose={() => setIsGroupModalOpen(false)}
      />
    </div>
  );
};
