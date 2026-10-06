import React, { useState, useEffect } from 'react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import { Users, UserPlus, UserCheck, Search, MessageSquare, Phone, Video, Check, X, Plus } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { CreateGroupModal } from '../chat/CreateGroupModal';

interface ContactsPanelProps {
  isCompact?: boolean;
  onOpenChat: () => void;
  addRequest?: number;
}

export const ContactsPanel: React.FC<ContactsPanelProps> = ({ isCompact = false, onOpenChat, addRequest = 0 }) => {
  const {
    conversations,
    friendRequests,
    sendFriendRequest,
    acceptFriendRequest,
    rejectFriendRequest,
    setActiveChat,
    startCall,
  } = useChat();

  const [activeSubTab, setActiveSubTab] = useState<'all' | 'requests' | 'add'>('all');
  useEffect(() => { if (addRequest > 0) setActiveSubTab('add'); }, [addRequest]);
  const [searchQuery, setSearchQuery] = useState('');
  const [targetUsername, setTargetUsername] = useState('');
  const [statusMessage, setStatusMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [loading, setLoading] = useState(false);
  const [isGroupModalOpen, setIsGroupModalOpen] = useState(false);

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

  const handleSendRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    const target = targetUsername.trim();
    if (!target) return;

    setLoading(true);
    setStatusMessage(null);

    const res = await sendFriendRequest(target);
    setLoading(false);

    if (res.ok) {
      triggerHaptic('success');
      setStatusMessage({ text: 'Friend request sent successfully!' });
      setTargetUsername('');
    } else {
      triggerHaptic('error');
      setStatusMessage({ text: res.message || 'Could not send friend request', error: true });
    }
  };

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

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setIsGroupModalOpen(true);
            }}
            className="header-action-btn"
            aria-label="Create New Group"
            title="Create New Group"
          >
            <Plus style={{ width: '18px', height: '18px', color: 'var(--primary)' }} />
          </button>

          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setActiveSubTab(activeSubTab === 'add' ? 'all' : 'add');
              setStatusMessage(null);
            }}
            className="header-action-btn"
            style={activeSubTab === 'add' ? { background: 'var(--primary-glow)', color: 'var(--primary)', borderColor: 'var(--primary)' } : {}}
            aria-label={activeSubTab === 'add' ? 'View Friends' : 'Add Friend'}
            title={activeSubTab === 'add' ? 'View Friends' : 'Add Friend'}
          >
            <UserPlus style={{ width: '18px', height: '18px' }} />
          </button>
        </div>
      </div>

      {/* Sub-Tabs: All Friends | Requests (badge) | Add New */}
      <div className="chat-filters-viewport">
        <div className="chat-filters contacts-filters" role="group" aria-label="Filter contacts" style={{ '--filter-index': ['all', 'requests', 'add'].indexOf(activeSubTab) } as React.CSSProperties}>
          <span className="chat-filter-pill" aria-hidden="true" />
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setActiveSubTab('all');
            }}
            className={`tab-btn ${activeSubTab === 'all' ? 'active' : ''}`}
            aria-pressed={activeSubTab === 'all'}
            style={{ fontSize: '0.8rem', padding: '8px' }}
          >
            Friends ({friendsList.length})
          </button>

          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setActiveSubTab('requests');
            }}
            className={`tab-btn ${activeSubTab === 'requests' ? 'active' : ''}`}
            aria-pressed={activeSubTab === 'requests'}
            style={{ fontSize: '0.8rem', padding: '8px', position: 'relative' }}
          >
            Requests
            {friendRequests.length > 0 && (
              <span
                className="chat-filter-count"
                style={{
                  background: '#ef4444',
                  color: 'var(--text-on-primary)',
                  fontSize: '0.65rem',
                  fontWeight: 800,
                  padding: '1px 6px',
                  borderRadius: '9999px',
                  marginLeft: '6px',
                }}
              >
                {friendRequests.length > 99 ? '99+' : friendRequests.length}
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              setActiveSubTab('add');
              setStatusMessage(null);
            }}
            className={`tab-btn ${activeSubTab === 'add' ? 'active' : ''}`}
            aria-pressed={activeSubTab === 'add'}
            style={{ fontSize: '0.8rem', padding: '8px' }}
          >
            + Add
          </button>
        </div>
      </div>

      {/* 1. All Friends View */}
      {activeSubTab === 'all' && (
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
                <button
                  type="button"
                  onClick={() => searchQuery.trim() ? setSearchQuery('') : setActiveSubTab('add')}
                  style={{ background: 'none', border: 'none', color: 'var(--primary)', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer' }}
                >
                  {searchQuery.trim() ? 'Clear search' : '+ Add your first friend'}
                </button>
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
      )}

      {/* 2. Friend Requests View */}
      {activeSubTab === 'requests' && (
        <div className="conversations-scroll" style={{ padding: '0 16px 16px' }}>
          {friendRequests.length === 0 ? (
            <div style={{ padding: '48px 20px', textAlign: 'center', color: 'var(--text-dark)' }}>
              <UserCheck style={{ width: '36px', height: '36px', margin: '0 auto 12px', color: 'var(--primary)' }} />
              <p style={{ fontSize: '0.85rem' }}>No pending friend requests</p>
            </div>
          ) : (
            friendRequests.map((req) => (
              <div
                className="contact-request-card"
                key={req.from}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: '14px',
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border)',
                  marginBottom: '8px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Avatar name={req.displayName || req.from} size="sm" />
                  <div>
                    <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      {req.displayName || req.from}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>wants to connect</div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '6px' }}>
                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('success');
                      acceptFriendRequest(req.from);
                    }}
                    className="contact-request-accept"
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'var(--primary)',
                      border: 'none',
                      color: 'var(--text-on-primary)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
                    aria-label="Accept"
                    title="Accept"
                  >
                    <Check style={{ width: '16px', height: '16px' }} />
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('medium');
                      rejectFriendRequest(req.from);
                    }}
                    className="contact-request-decline"
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'var(--bg-surface)',
                      border: 'none',
                      color: '#ef4444',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
                    aria-label="Decline"
                    title="Decline"
                  >
                    <X style={{ width: '16px', height: '16px' }} />
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* 3. Add Friend Form View */}
      {activeSubTab === 'add' && (
        <div style={{ padding: '0 20px 20px', flex: 1, overflowY: 'auto' }}>
          <form onSubmit={handleSendRequest}>
            <div className="input-wrapper" style={{ marginBottom: '14px' }}>
              <label className="input-label" htmlFor="contact-identifier">Username or email</label>
              <input
                type="text"
                required
                id="contact-identifier"
                value={targetUsername}
                onChange={(e) => setTargetUsername(e.target.value)}
                placeholder="Username or email address"
                className="input-field"
                style={{ paddingLeft: '16px' }}
              />
            </div>

            {statusMessage && (
              <div
                className={statusMessage.error ? 'alert-error' : ''}
                style={
                  !statusMessage.error
                    ? {
                        background: 'var(--primary-glow)',
                        border: '1px solid var(--primary)',
                        color: 'var(--primary)',
                        padding: '10px 14px',
                        borderRadius: 'var(--radius-md)',
                        fontSize: '0.8rem',
                        textAlign: 'center',
                        marginBottom: '16px',
                      }
                    : { marginBottom: '16px' }
                }
              >
                {statusMessage.text}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ width: '100%', padding: '12px', borderRadius: '12px' }}
            >
              {loading ? (
                <span style={{ display: 'inline-block', width: '16px', height: '16px', border: '2px solid #ffffff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
              ) : (
                <>
                  <UserPlus style={{ width: '16px', height: '16px' }} /> Send Friend Request
                </>
              )}
            </button>
          </form>

          <p style={{ marginTop: '16px', fontSize: '0.75rem', color: 'var(--text-muted)', lineHeight: 1.6, textAlign: 'center' }}>
            Connect using their exact username or email.
          </p>
        </div>
      )}

      {/* Create Group Modal */}
      <CreateGroupModal
        isOpen={isGroupModalOpen}
        onClose={() => setIsGroupModalOpen(false)}
      />
    </div>
  );
};
