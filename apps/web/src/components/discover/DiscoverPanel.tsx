import React, { useState, useEffect, useCallback } from 'react';
import { useChat } from '../../context/ChatContext';
import { useAuth } from '../../context/AuthContext';
import { connectSocket, getSocket } from '../../services/socket';
import { Avatar } from '../ui/Avatar';
import { Compass, UserPlus, MessageSquare, Radio, Sparkles, UserCheck, X, Check, Send } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { SettingsToast, type SettingsNotice } from '../settings/SettingsToast';

interface DiscoverUser {
  username: string;
  displayName?: string;
  avatarId?: string;
  online?: boolean;
  bio?: string;
  canMessage?: boolean;
}

interface DiscoverPanelProps {
  isCompact?: boolean;
  onOpenChat?: () => void;
}

export const DiscoverPanel: React.FC<DiscoverPanelProps> = ({ isCompact = false, onOpenChat }) => {
  const { user } = useAuth();
  const { conversations, friendRequests, sentRequests, sendFriendRequest, cancelFriendRequest, acceptFriendRequest, rejectFriendRequest, setActiveChat } = useChat();
  const [onlineUsers, setOnlineUsers] = useState<DiscoverUser[]>([]);
  const [hoveredUser, setHoveredUser] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionNotice, setActionNotice] = useState<SettingsNotice | null>(null);
  const dismissActionNotice = useCallback(() => setActionNotice(null), []);
  const [pendingUser, setPendingUser] = useState<string | null>(null);
  const [friendInput, setFriendInput] = useState('');
  const [isSendingFriend, setIsSendingFriend] = useState(false);

  const fetchOnlineUsers = () => {
    setLoading(true);
    setError('');
    const socket = connectSocket();
    if (socket && socket.connected) {
      socket.emit('discover_online');
    }
  };

  useEffect(() => {
    const socket = getSocket();
    if (!socket) return;
    if (!socket.connected) connectSocket();

    const handleDiscoverOnline = (data: { users?: any[] }) => {
      const list = (data?.users || [])
        .filter((u: any) => u && u.username && u.username !== user?.username)
        .map((u: any) => ({
          username: u.username,
          displayName: u.displayName || u.username,
          avatarId: u.avatarId,
          online: true,
          bio: u.bio || 'Active on Novyn',
          canMessage: Boolean(u.canMessage),
        }));
      setOnlineUsers(list);
      setLoading(false);
      setError('');
    };

    const requestOnlineUsers = () => {
      if (socket.connected) socket.emit('discover_online');
    };
    const handleConnectionError = () => {
      setLoading(false);
      setError('Unable to connect. Check that the chat server is running, then refresh.');
    };

    socket.on('discover_online', handleDiscoverOnline);
    socket.on('connect', requestOnlineUsers);
    socket.on('connect_error', handleConnectionError);
    socket.on('disconnect', handleConnectionError);
    socket.on('register_success', requestOnlineUsers);
    socket.on('auth_failed', handleConnectionError);
    requestOnlineUsers();

    const interval = setInterval(requestOnlineUsers, 10000);
    // A missing server response should never leave the panel in a permanent
    // loading state. Later socket responses still replace this empty state.
    const initialResponseTimeout = window.setTimeout(() => setLoading(false), 5000);

    return () => {
      socket.off('discover_online', handleDiscoverOnline);
      socket.off('connect', requestOnlineUsers);
      socket.off('connect_error', handleConnectionError);
      socket.off('disconnect', handleConnectionError);
      socket.off('register_success', requestOnlineUsers);
      socket.off('auth_failed', handleConnectionError);
      clearInterval(interval);
      clearTimeout(initialResponseTimeout);
    };
  }, [user]);

  const handleAdd = async (username: string) => {
    if (pendingUser) return;
    setPendingUser(username);
    setError('');
    triggerHaptic('medium');
    try {
      const result = await sendFriendRequest(username);
      if (!result.ok) setActionNotice({ text: result.message || 'Unable to send request.', error: true });
    } finally {
      setPendingUser(null);
    }
  };

  const handleUnsend = async (username: string) => {
    triggerHaptic('light');
    const result = await cancelFriendRequest(username);
    if (!result.ok) setActionNotice({ text: result.message || 'Unable to cancel request.', error: true });
  };

  const handleManualFriendRequest = async (event: React.FormEvent) => {
    event.preventDefault();
    const username = friendInput.trim().replace(/^@/, '');
    if (!username || isSendingFriend) return;
    setIsSendingFriend(true);
    const result = await sendFriendRequest(username);
    setIsSendingFriend(false);
    if (result.ok) {
      setFriendInput('');
      setActionNotice({ text: 'Friend request sent.', error: false });
    } else {
      setActionNotice({ text: result.message || 'Unable to send friend request.', error: true });
    }
  };

  const isFriend = (username: string) => {
    return conversations.some((c) => c.username.toLowerCase() === username.toLowerCase() && c.isFriend !== false && !c.isGroup);
  };

  const isRequested = (username: string) => {
    return sentRequests.has(username.toLowerCase());
  };

  if (isCompact) {
    return (
      <div className="chat-list-panel" style={{ width: '100%', alignItems: 'center', padding: '14px 0' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(16, 185, 129, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#0e9f8a', marginBottom: '16px' }}>
          <Compass style={{ width: '18px', height: '18px' }} />
        </div>

        <div className="conversations-scroll" style={{ width: '100%', alignItems: 'center', gap: '12px', padding: '0 8px' }}>
          {onlineUsers.map((person) => (
            <div
              key={person.username}
              onClick={() => {
                if (isFriend(person.username)) {
                  setActiveChat(person.username);
                  onOpenChat?.();
                } else if (person.canMessage) {
                  setActiveChat(person.username);
                  onOpenChat?.();
                } else if (!isRequested(person.username)) {
                  handleAdd(person.username);
                }
              }}
              style={{ position: 'relative', cursor: 'pointer', padding: '4px' }}
              title={`@${person.username} (Online)`}
            >
              <Avatar
                name={person.displayName || person.username}
                avatarUrl={person.avatarId}
                online={true}
                size="md"
              />
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="chat-list-panel discover-panel" style={{ width: '100%' }}>
      {actionNotice && <SettingsToast notice={actionNotice} onDismiss={dismissActionNotice} />}
      {/* Header */}
      <div className="chat-list-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span className="sidebar-outline-icon" aria-hidden="true"><Compass size={18} /></span>
          <div>
            <h2 className="chat-list-title" style={{ fontSize: '1.2rem' }}>Discover</h2>
              <span style={{ fontSize: '0.72rem', color: 'var(--primary)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Radio style={{ width: '12px', height: '12px' }} /> Live Online Radar
            </span>
          </div>
        </div>

        <button
          type="button"
          onClick={fetchOnlineUsers}
          className="header-action-btn"
          aria-label="Refresh Radar"
          title="Refresh Radar"
        >
          <Sparkles style={{ width: '16px', height: '16px' }} />
        </button>
      </div>

      {/* Users List */}
      {error && <p role="alert" style={{ padding: '12px 16px', color: '#bd3750' }}>{error}</p>}
      <div className="conversations-scroll" style={{ padding: '4px 16px 16px' }}>
        <div className="discover-mobile-tools" aria-label="Friend management">
          <details>
            <summary>Friend requests <span>{friendRequests.length}</span></summary>
            <div className="discover-mobile-tools-content">
              {friendRequests.length === 0 ? <p>No pending friend requests.</p> : friendRequests.map(request => (
                <div className="discover-mobile-request" key={request.from}>
                  <Avatar name={request.displayName || request.from} size="sm" />
                  <span>@{request.from}</span>
                  <button type="button" aria-label={`Accept ${request.from}`} onClick={() => acceptFriendRequest(request.from)}><Check size={15} /></button>
                  <button type="button" aria-label={`Reject ${request.from}`} onClick={() => rejectFriendRequest(request.from)}><X size={15} /></button>
                </div>
              ))}
            </div>
          </details>
          <details>
            <summary>Sent requests <span>{sentRequests.size}</span></summary>
            <div className="discover-mobile-tools-content">
              {sentRequests.size === 0 ? <p>You haven’t sent any friend requests.</p> : [...sentRequests].map(username => (
                <div className="discover-mobile-request" key={username}>
                  <Avatar name={username} size="sm" />
                  <span>@{username}</span>
                  <button type="button" onClick={() => void handleUnsend(username)}>Cancel</button>
                </div>
              ))}
            </div>
          </details>
          <details>
            <summary>Add a friend</summary>
            <form className="discover-mobile-add-form" onSubmit={handleManualFriendRequest}>
              <input aria-label="Friend username" placeholder="Enter username" value={friendInput} onChange={event => setFriendInput(event.target.value)} />
              <button type="submit" disabled={isSendingFriend || !friendInput.trim()}><Send size={14} />{isSendingFriend ? 'Sending' : 'Add'}</button>
            </form>
          </details>
        </div>
        {loading ? (
          <div style={{ padding: '48px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <div style={{ width: '28px', height: '28px', border: '3px solid #10b981', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 12px' }} />
            <p style={{ fontSize: '0.85rem' }}>Scanning for people online...</p>
          </div>
        ) : onlineUsers.length === 0 ? (
          <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-dark)' }}>
            <span className="sidebar-outline-icon is-empty" aria-hidden="true"><Compass size={32} /></span>
            <h4 style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '6px' }}>{error ? 'Could not load people' : 'No one online yet'}</h4>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              {error ? 'Check your connection and retry.' : 'Check back in a moment.'}
            </p>
            <button type="button" className="empty-state-action" style={{ marginTop: '34px' }} onClick={fetchOnlineUsers}>Refresh people</button>
          </div>
        ) : (
          onlineUsers.map((person) => {
            const alreadyFriend = isFriend(person.username);
            const requested = isRequested(person.username);
            const isHovered = hoveredUser === person.username;

            return (
              <div
                className="discover-person-card"
                key={person.username}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '12px',
                  padding: '12px 14px',
                  borderRadius: '16px',
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border)',
                  marginBottom: '10px',
                  transition: 'all 0.2s ease',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0, flex: 1 }}>
                  <Avatar
                    name={person.displayName || person.username}
                    avatarUrl={person.avatarId}
                    online={true}
                    size="md"
                  />
                  <div style={{ minWidth: 0, flex: 1 }}>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {person.displayName || person.username}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      @{person.username}
                    </div>
                  </div>
                </div>

                <div style={{ flexShrink: 0 }}>
                  {alreadyFriend ? (
                    <button
                      className="btn btn-secondary discover-person-action discover-person-action--chat"
                      type="button"
                      onClick={() => {
                        triggerHaptic('light');
                        setActiveChat(person.username);
                        onOpenChat?.();
                      }}
                      style={{ padding: '6px 14px', fontSize: '0.78rem', borderRadius: '9999px' }}
                    >
                      <MessageSquare style={{ width: '13px', height: '13px' }} /> Chat
                    </button>
                  ) : (
                    <div style={{ display: 'flex', gap: 7, alignItems: 'center' }}>
                      <button
                        className="btn btn-secondary discover-person-action discover-person-action--chat"
                        type="button"
                        disabled={!person.canMessage}
                        title={person.canMessage ? 'Message' : 'This user only accepts messages from friends'}
                        aria-label={person.canMessage ? `Message ${person.username}` : `${person.username} only accepts messages from friends`}
                        onClick={() => {
                          if (!person.canMessage) return;
                          triggerHaptic('light');
                          setActiveChat(person.username);
                          onOpenChat?.();
                        }}
                        style={{
                          padding: '6px 9px',
                          minWidth: '34px',
                          fontSize: '0.78rem',
                          borderRadius: '9999px',
                          opacity: person.canMessage ? 1 : 0.55,
                          cursor: person.canMessage ? 'pointer' : 'not-allowed',
                        }}
                      >
                        <MessageSquare style={{ width: '15px', height: '15px' }} aria-hidden="true" />
                      </button>
                      {requested ? (
                        <button
                          className="discover-person-action discover-person-action--requested"
                          type="button"
                          onMouseEnter={() => setHoveredUser(person.username)}
                          onMouseLeave={() => setHoveredUser(null)}
                          onClick={() => handleUnsend(person.username)}
                          style={{
                            display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '6px 10px',
                            borderRadius: '9999px',
                            background: isHovered ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.1)',
                            border: isHovered ? '1px solid rgba(239, 68, 68, 0.35)' : '1px solid rgba(16, 185, 129, 0.25)',
                            fontSize: '0.78rem', color: isHovered ? '#bd3750' : '#078779', fontWeight: 600,
                            cursor: 'pointer', transition: 'all 0.2s ease',
                          }}
                          aria-label="Click to unsend friend request"
                          title="Click to unsend friend request"
                        >
                          {isHovered ? <><X style={{ width: '13px', height: '13px' }} /> Unsend</> : <><UserCheck style={{ width: '13px', height: '13px' }} /> Requested</>}
                        </button>
                      ) : (
                        <button
                          className="btn discover-person-action discover-person-action--add"
                          type="button"
                          onClick={() => handleAdd(person.username)}
                          disabled={pendingUser !== null}
                          style={{
                            background: 'rgba(16, 185, 129, 0.12)', border: '1px solid rgba(16, 185, 129, 0.3)',
                            color: '#078779', padding: '6px 10px', fontSize: '0.78rem', borderRadius: '9999px',
                            fontWeight: 700, boxShadow: 'none', cursor: 'pointer',
                          }}
                          onMouseEnter={(e) => { e.currentTarget.style.background = '#10b981'; e.currentTarget.style.color = 'var(--text-main)'; }}
                          onMouseLeave={(e) => { e.currentTarget.style.background = 'rgba(16, 185, 129, 0.12)'; e.currentTarget.style.color = '#078779'; }}
                        >
                          <UserPlus style={{ width: '14px', height: '14px' }} /> Add
                        </button>
                      )}
                    </div>
                  )}
                  {}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
