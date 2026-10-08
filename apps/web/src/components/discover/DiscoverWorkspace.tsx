import React, { useState } from 'react';
import { Check, RefreshCw, Send, Sparkles, X } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import './discoverWorkspace.css';

export const DiscoverWorkspace: React.FC = () => {
  const { friendRequests, sentRequests, acceptFriendRequest, rejectFriendRequest, cancelFriendRequest, sendFriendRequest } = useChat();
  const [friendInput, setFriendInput] = useState('');
  const [friendMessage, setFriendMessage] = useState('');
  const [isSending, setIsSending] = useState(false);

  const handleSendRequest = async () => {
    const username = friendInput.trim().replace(/^@/, '');
    if (!username || isSending) return;
    setIsSending(true);
    setFriendMessage('');
    const result = await sendFriendRequest(username);
    setIsSending(false);
    if (result.ok) {
      setFriendInput('');
      setFriendMessage('Friend request sent.');
    } else {
      setFriendMessage(result.message || 'Unable to send friend request.');
    }
  };

  return (
    <div className="discover-workspace">
      <div className="discover-hero-card">
        <div className="discover-radar" aria-hidden="true">
          <div className="radar-scan" />
          <div className="radar-orbit orbit-one" />
          <div className="radar-orbit orbit-two" />
          <div className="radar-dot dot-one" />
          <div className="radar-dot dot-two" />
          <div className="radar-dot dot-three" />
          <div className="radar-dot dot-four" />
          <div className="radar-center" />
        </div>

        <div className="discover-hero-copy">
          <p className="discover-eyebrow">Something new awaits</p>
          <h1>Find your next connection</h1>
          <p className="discover-subtitle">
          See who’s online, send a friend request, and let a new conversation unfold.
        </p>

          <button type="button" className="discover-refresh-btn">
            <RefreshCw size={17} />
            Refresh people
          </button>
        </div>
      </div>

      <div className="discover-lower-grid">
        <div className="discover-main-column">
          <section className="discover-card discover-requests-card">
            <header>
              <h2>Friend requests</h2>
              <span>{friendRequests.length}</span>
            </header>

            <div className="discover-request-list">
            {friendRequests.length === 0 ? (
              <p className="discover-empty-state">No pending friend requests.</p>
            ) : friendRequests.map((request) => (
              <div key={request.from} className="discover-request-row">
                <div className="request-meta">
                  <Avatar name={request.displayName || request.from} size="sm" />
                  <div>
                    <strong>{request.displayName || request.from}</strong>
                    <small>@{request.from}</small>
                  </div>
                </div>

                <div className="request-actions">
                  <button type="button" className="request-action accept" onClick={() => acceptFriendRequest(request.from)}>
                    <Check size={14} />
                    Accept
                  </button>
                  <button type="button" className="request-action reject" onClick={() => rejectFriendRequest(request.from)} aria-label={`Reject ${request.from}`}>
                    <X size={14} />
                  </button>
                </div>

              </div>
            ))}
            </div>
          </section>

          <section className="discover-card discover-sent-card">
            <header>
              <h2>Sent requests</h2>
              <span>{sentRequests.size}</span>
            </header>

            <div className="discover-request-list">
            {sentRequests.size === 0 ? (
              <p className="discover-empty-state">You haven’t sent any friend requests.</p>
            ) : [...sentRequests].map((username) => (
              <div key={username} className="discover-request-row sent-row">
                <div className="request-meta">
                  <Avatar name={username} size="sm" />
                  <div>
                    <strong>{username}</strong>
                    <small>Pending</small>
                  </div>
                </div>

                <button type="button" className="request-action muted" onClick={() => cancelFriendRequest(username)}>
                  Cancel
                </button>
              </div>
            ))}
            </div>
          </section>
        </div>

        <div className="discover-side-column">
          <section className="discover-card discover-add-card">
            <header>
              <h2>Add a friend</h2>
            </header>

            <div className="discover-input-row">
              <input type="text" placeholder="Username" value={friendInput} onChange={(event) => setFriendInput(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void handleSendRequest(); }} />
              <button type="button" className="discover-send-btn" onClick={() => void handleSendRequest()} disabled={isSending || !friendInput.trim()}>
                <Send size={15} />
                {isSending ? 'Sending…' : 'Send'}
              </button>
            </div>
            <p className="discover-inline-hint" role="status">{friendMessage || 'Connect using their exact username.'}</p>
          </section>

          <section className="discover-card discover-qr-card">
            <div className="qr-box" aria-label="QR code preview">
              <div className="qr-pattern" />
            </div>
            <div className="qr-copy">
              <h3>Share my QR</h3>
              <p>Friends can scan to add you</p>
            </div>
            <button type="button" className="discover-qr-button">
              <Sparkles size={16} />
              Scan a code
            </button>
          </section>
        </div>
      </div>
    </div>
  );
};
