import React, { useState, useEffect } from 'react';
import { useChat } from '../../context/ChatContext';
import { useAuth } from '../../context/AuthContext';
import { connectSocket, getSocket } from '../../services/socket';
import { Avatar } from '../ui/Avatar';
import { Compass, UserPlus, MessageSquare, Radio, Sparkles, UserCheck, X } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface DiscoverUser {
  username: string;
  displayName?: string;
  avatarId?: string;
  online?: boolean;
  bio?: string;
}

interface DiscoverPanelProps {
  isCompact?: boolean;
  onOpenChat?: () => void;
}

export const DiscoverPanel: React.FC<DiscoverPanelProps> = ({ isCompact = false, onOpenChat }) => {
  const { user } = useAuth();
  const { conversations, sentRequests, sendFriendRequest, cancelFriendRequest, setActiveChat } = useChat();
  const [onlineUsers, setOnlineUsers] = useState<DiscoverUser[]>([]);
  const [hoveredUser, setHoveredUser] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [pendingUser, setPendingUser] = useState<string | null>(null);

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
      if (!result.ok) setError(result.message || 'Unable to send request.');
    } finally {
      setPendingUser(null);
    }
  };

  const handleUnsend = async (username: string) => {
    triggerHaptic('light');
    const result = await cancelFriendRequest(username);
    if (!result.ok) setError(result.message || 'Unable to cancel request.');
  };

  const isFriend = (username: string) => {
    return conversations.some((c) => c.username.toLowerCase() === username.toLowerCase());
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
      {/* Header */}
      <div className="chat-list-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span className="sidebar-outline-icon" aria-hidden="true"><Compass size={18} /></span>
          <div>
            <h2 className="chat-list-title" style={{ fontSize: '1.2rem' }}>Discover</h2>
            <span style={{ fontSize: '0.72rem', color: '#0e9f8a', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '4px' }}>
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
                  background: 'rgba(255, 255, 255, 0.55)',
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
                  ) : requested ? (
                    <button
                      className="discover-person-action discover-person-action--requested"
                      type="button"
                      onMouseEnter={() => setHoveredUser(person.username)}
                      onMouseLeave={() => setHoveredUser(null)}
                      onClick={() => handleUnsend(person.username)}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '5px',
                        padding: '6px 14px',
                        borderRadius: '9999px',
                        background: isHovered ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.1)',
                        border: isHovered ? '1px solid rgba(239, 68, 68, 0.35)' : '1px solid rgba(16, 185, 129, 0.25)',
                        fontSize: '0.78rem',
                        color: isHovered ? '#bd3750' : '#078779',
                        fontWeight: 600,
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                      }}
                      aria-label="Click to unsend friend request"
                      title="Click to unsend friend request"
                    >
                      {isHovered ? (
                        <>
                          <X style={{ width: '13px', height: '13px' }} /> Unsend
                        </>
                      ) : (
                        <>
                          <UserCheck style={{ width: '13px', height: '13px' }} /> Requested
                        </>
                      )}
                    </button>
                  ) : (
                    <button
                      className="btn discover-person-action discover-person-action--add"
                      type="button"
                      onClick={() => handleAdd(person.username)}
                      disabled={pendingUser !== null}
                      style={{
                        background: 'rgba(16, 185, 129, 0.12)',
                        border: '1px solid rgba(16, 185, 129, 0.3)',
                        color: '#078779',
                        padding: '6px 14px',
                        fontSize: '0.78rem',
                        borderRadius: '9999px',
                        fontWeight: 700,
                        boxShadow: 'none',
                        cursor: 'pointer',
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#10b981';
                        e.currentTarget.style.color = 'var(--text-main)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'rgba(16, 185, 129, 0.12)';
                        e.currentTarget.style.color = '#078779';
                      }}
                    >
                      <UserPlus style={{ width: '14px', height: '14px' }} /> Add
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
