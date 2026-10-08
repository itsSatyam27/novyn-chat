import React, { useState } from 'react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import { Users, Search, MessageSquare, Phone, Video } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface ContactsPanelProps {
  isCompact?: boolean;
  onOpenChat: () => void;
}

export const ContactsPanel: React.FC<ContactsPanelProps> = ({ isCompact = false, onOpenChat }) => {
  const {
    conversations,
    setActiveChat,
    startCall,
  } = useChat();

  const [searchQuery, setSearchQuery] = useState('');

  const friendsList = conversations.filter((c) => !c.isGroup);

  const openChat = (username: string) => {
    triggerHaptic('light');
    setActiveChat(username);
    onOpenChat();
  };

  const filteredFriends = friendsList.filter((c) => {
    const q = searchQuery.toLowerCase();
    return (
      (c.displayName && c.displayName.toLowerCase().includes(q)) ||
      c.username.toLowerCase().includes(q)
    );
  });

  if (isCompact) {
    return (
      <div className="chat-list-panel" style={{ width: '100%', alignItems: 'center', padding: '14px 0' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'var(--primary-glow)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary)', marginBottom: '16px' }}>
          <Users style={{ width: '18px', height: '18px' }} />
        </div>

        <div className="conversations-scroll" style={{ width: '100%', alignItems: 'center', gap: '12px', padding: '0 8px' }}>
          {friendsList.map((friend) => (
            <div
              key={friend.username}
              onClick={() => openChat(friend.username)}
              style={{ position: 'relative', cursor: 'pointer', padding: '4px' }}
              title={`Chat with ${friend.displayName || friend.username}`}
            >
              <Avatar
                name={friend.displayName || friend.username}
                avatarUrl={friend.avatarId}
                online={friend.online}
                presence={friend.presence}
                size="md"
              />
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="chat-list-panel contacts-panel" style={{ width: '100%' }}>
      {/* Header */}
      <div className="chat-list-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span className="sidebar-outline-icon" aria-hidden="true"><Users size={18} /></span>
          <div>
            <h2 className="chat-list-title" style={{ fontSize: '1.2rem' }}>Contacts</h2>
            <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
              {friendsList.length} {friendsList.length === 1 ? 'Friend' : 'Friends'}
            </span>
          </div>
        </div>

      </div>

      {/* Friends view */}
      <div className="chat-filters-viewport">
        <div className="chat-filters contacts-filters" role="group" aria-label="Contacts" style={{ '--filter-index': 0 } as React.CSSProperties}>
          <span className="chat-filter-pill" aria-hidden="true" />
          <button
            type="button"
            className="tab-btn active"
            aria-pressed="true"
            style={{ fontSize: '0.8rem', padding: '8px', cursor: 'default' }}
          >
            Friends ({friendsList.length})
          </button>
        </div>
      </div>

      {/* 1. All Friends View */}
      <>
          <div className="chat-search-box">
            <div className="search-input-wrapper">
              <Search className="search-icon" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search friends..."
                className="search-input-field"
              />
            </div>
          </div>

          <div className="conversations-scroll" style={{ padding: '0 16px 16px' }}>
            {filteredFriends.length === 0 ? (
              <div style={{ padding: '48px 20px', textAlign: 'center', color: 'var(--text-dark)' }}>
            <span className="sidebar-outline-icon is-empty" aria-hidden="true"><Users size={32} /></span>
                <p style={{ fontSize: '0.85rem', marginBottom: '8px' }}>{searchQuery.trim() ? 'No friends match your search' : 'Your people will appear here'}</p>
                {searchQuery.trim() && <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  style={{ background: 'none', border: 'none', color: 'var(--primary)', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer' }}
                >Clear search</button>}
              </div>
            ) : (
              filteredFriends.map((friend) => (
                <div
                  key={friend.username}
                  className="contact-card"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    borderRadius: '14px',
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border)',
                    marginBottom: '8px',
                    transition: 'all 0.15s ease',
                  }}
                >
                  <div
                    onClick={() => openChat(friend.username)}
                    style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer', flex: 1, minWidth: 0 }}
                  >
                    <Avatar
                      name={friend.displayName || friend.username}
                      avatarUrl={friend.avatarId}
                      online={friend.online}
                      presence={friend.presence}
                      size="md"
                    />
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {friend.displayName || friend.username}
                      </div>
                      <div style={{ fontSize: '0.72rem', color: friend.online ? 'var(--primary)' : 'var(--text-dark)', fontWeight: friend.online ? 600 : 400 }}>
                        {friend.online ? '● Online' : 'Offline'}
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <button
                      type="button"
                      onClick={() => {
                        triggerHaptic('medium');
                        startCall(friend.username, false);
                      }}
                      className="header-action-btn"
                      disabled={Boolean(friend.isSelf)}
                      style={{ width: '32px', height: '32px', opacity: friend.isSelf ? 0.35 : 1 }}
                      aria-label={friend.isSelf ? 'Calls unavailable for Saved Messages' : 'Audio Call'}
                      title={friend.isSelf ? 'You cannot call yourself' : 'Audio Call'}
                    >
                      <Phone style={{ width: '15px', height: '15px' }} />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
      </>

    </div>
  );
};
