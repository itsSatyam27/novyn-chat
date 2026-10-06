import React, { useState } from 'react';
import { useChat } from '../../context/ChatContext';
import { Modal } from '../ui/Modal';
import { Avatar } from '../ui/Avatar';
import { UserPlus, Check, X, Users, UserCheck } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface ContactsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ContactsModal: React.FC<ContactsModalProps> = ({ isOpen, onClose }) => {
  const {
    conversations,
    friendRequests,
    sendFriendRequest,
    acceptFriendRequest,
    rejectFriendRequest,
    setActiveChat,
  } = useChat();

  const [activeTab, setActiveTab] = useState<'add' | 'requests' | 'friends'>('add');
  const [targetUsername, setTargetUsername] = useState('');
  const [statusMessage, setStatusMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [loading, setLoading] = useState(false);

  const friendsList = conversations.filter((c) => !c.isGroup);

  const handleSendRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    const target = targetUsername.trim();
    if (!target) return;

    setLoading(true);
    setStatusMessage(null);

    const res = await sendFriendRequest(target);
    setLoading(false);

    if (res.ok) {
      setStatusMessage({ text: 'Friend request sent successfully!' });
      setTargetUsername('');
    } else {
      setStatusMessage({ text: res.message || 'Could not send friend request', error: true });
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Contacts & Friends">
      {/* Tabs */}
      <div className="chat-filters-viewport">
      <div className="chat-filters contacts-filters" role="group" aria-label="Filter contacts" style={{ '--filter-index': ['add', 'requests', 'friends'].indexOf(activeTab) } as React.CSSProperties}>
        <span className="chat-filter-pill" aria-hidden="true" />
        <button
          type="button"
          onClick={() => {
            triggerHaptic('light');
            setActiveTab('add');
            setStatusMessage(null);
          }}
          className={`tab-btn ${activeTab === 'add' ? 'active' : ''}`}
          aria-pressed={activeTab === 'add'}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
        >
          <UserPlus style={{ width: '15px', height: '15px' }} /> Add
        </button>

        <button
          type="button"
          onClick={() => {
            triggerHaptic('light');
            setActiveTab('requests');
            setStatusMessage(null);
          }}
          className={`tab-btn ${activeTab === 'requests' ? 'active' : ''}`}
          aria-pressed={activeTab === 'requests'}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', position: 'relative' }}
        >
          <UserCheck style={{ width: '15px', height: '15px' }} /> Requests
          {friendRequests.length > 0 && (
            <span
              style={{
                width: '7px',
                height: '7px',
                borderRadius: '50%',
                background: '#ef4444',
                position: 'absolute',
                top: '6px',
                right: '8px',
              }}
            />
          )}
        </button>

        <button
          type="button"
          onClick={() => {
            triggerHaptic('light');
            setActiveTab('friends');
            setStatusMessage(null);
          }}
          className={`tab-btn ${activeTab === 'friends' ? 'active' : ''}`}
          aria-pressed={activeTab === 'friends'}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
        >
          <Users style={{ width: '15px', height: '15px' }} /> Friends ({friendsList.length})
        </button>
      </div>
      </div>

      {/* 1. Add Friend Tab */}
      {activeTab === 'add' && (
        <form onSubmit={handleSendRequest}>
          <div className="input-wrapper">
            <label className="input-label">Enter Username or Email</label>
            <input
              type="text"
              required
              value={targetUsername}
              onChange={(e) => setTargetUsername(e.target.value)}
              placeholder="e.g. bob or bob@example.com"
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
                      background: 'rgba(16, 185, 129, 0.12)',
                      border: '1px solid rgba(16, 185, 129, 0.3)',
                      color: '#078779',
                      padding: '10px 14px',
                      borderRadius: 'var(--radius-md)',
                      fontSize: '0.8rem',
                      textAlign: 'center',
                      marginBottom: '16px',
                    }
                  : {}
              }
            >
              {statusMessage.text}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary"
            style={{ width: '100%', padding: '12px' }}
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
      )}

      {/* 2. Pending Requests Tab */}
      {activeTab === 'requests' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '280px', overflowY: 'auto' }}>
          {friendRequests.length === 0 ? (
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', textAlign: 'center', padding: '32px 0' }}>
              No pending friend requests.
            </p>
          ) : (
            friendRequests.map((req) => (
              <div
                key={req.from}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: 'var(--radius-md)',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Avatar name={req.displayName || req.from} size="sm" />
                  <div>
                    <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      {req.displayName || req.from}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-dark)' }}>wants to connect</div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '6px' }}>
                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('success');
                      acceptFriendRequest(req.from);
                    }}
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: '#10b981',
                      border: 'none',
                      color: 'var(--text-on-primary)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
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
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: 'none',
                      color: '#ef4444',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
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

      {/* 3. All Friends Tab */}
      {activeTab === 'friends' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', maxHeight: '280px', overflowY: 'auto' }}>
          {friendsList.length === 0 ? (
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', textAlign: 'center', padding: '32px 0' }}>
              No friends added yet.
            </p>
          ) : (
            friendsList.map((friend) => (
              <div
                key={friend.username}
                onClick={() => {
                  triggerHaptic('light');
                  setActiveChat(friend.username);
                  onClose();
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 12px',
                  borderRadius: 'var(--radius-md)',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  cursor: 'pointer',
                  transition: 'all 0.15s ease',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Avatar
                    name={friend.displayName || friend.username}
                    avatarUrl={friend.avatarId}
                    online={friend.online}
                    presence={friend.presence}
                    size="sm"
                  />
                  <div>
                    <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      {friend.displayName || friend.username}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: friend.online ? '#0e9f8a' : 'var(--text-dark)' }}>
                      {friend.online ? 'Online' : 'Offline'}
                    </div>
                  </div>
                </div>

                <span style={{ fontSize: '0.75rem', color: '#0e9f8a', fontWeight: 700 }}>Chat →</span>
              </div>
            ))
          )}
        </div>
      )}
    </Modal>
  );
};
