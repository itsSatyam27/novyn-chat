import React, { useCallback, useEffect, useRef, useState, type CSSProperties, type PointerEvent as ReactPointerEvent } from 'react';
import { Check, Clock3, QrCode, RefreshCw, ScanLine, Send, UserPlus, Users, X } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { useAuth } from '../../context/AuthContext';
import { Avatar } from '../ui/Avatar';
import { QRScannerModal } from './QRScannerModal';
import { QRCodeModal } from '../profile/QRCodeModal';
import { connectSocket } from '../../services/socket';
import './discoverWorkspace.css';

const RADAR_BLIPS = [
  { angle: 300, radius: .62, height: 70 },
  { angle: 70, radius: .5, height: 48 },
  { angle: 135, radius: .42, height: 90 },
  { angle: 200, radius: .8, height: 36 },
  { angle: 25, radius: .85, height: 60 },
];

const DiscoverRadar: React.FC = () => {
  const stageRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const angles = useRef({ x: 58, z: -20, offsetX: 0, offsetZ: 0 });
  const drag = useRef({ active: false, lastX: 0, lastY: 0 });

  const applyTransform = useCallback(() => {
    const scene = sceneRef.current;
    if (!scene) return;
    const value = angles.current;
    scene.style.setProperty('--radar-rx', `${Math.max(25, Math.min(78, value.x + value.offsetX))}deg`);
    scene.style.setProperty('--radar-rz', `${value.z + value.offsetZ}deg`);
  }, []);

  const handlePointerMove = (event: ReactPointerEvent<HTMLDivElement>) => {
    const bounds = stageRef.current?.getBoundingClientRect();
    if (!bounds) return;
    const value = angles.current;
    const state = drag.current;
    if (state.active) {
      value.z += (event.clientX - state.lastX) * .45;
      value.x = Math.max(25, Math.min(78, value.x - (event.clientY - state.lastY) * .35));
      state.lastX = event.clientX;
      state.lastY = event.clientY;
    } else {
      value.offsetZ = ((event.clientX - bounds.left) / bounds.width - .5) * 18;
      value.offsetX = -((event.clientY - bounds.top) / bounds.height - .5) * 12;
    }
    applyTransform();
  };

  return (
    <div ref={stageRef} className="discover-radar-stage" role="application" tabIndex={0} aria-label="Interactive 3D radar showing nearby people. Drag it or use arrow keys to change the angle."
      onPointerDown={(event) => { drag.current = { active: true, lastX: event.clientX, lastY: event.clientY }; event.currentTarget.setPointerCapture(event.pointerId); }}
      onPointerUp={(event) => { drag.current.active = false; event.currentTarget.releasePointerCapture(event.pointerId); }}
      onPointerMove={handlePointerMove}
      onPointerLeave={() => { drag.current.active = false; angles.current.offsetX = 0; angles.current.offsetZ = 0; applyTransform(); }}
      onKeyDown={(event) => {
        if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
        event.preventDefault();
        if (event.key === 'ArrowLeft') angles.current.z -= 6;
        if (event.key === 'ArrowRight') angles.current.z += 6;
        if (event.key === 'ArrowUp') angles.current.x = Math.min(78, angles.current.x + 4);
        if (event.key === 'ArrowDown') angles.current.x = Math.max(25, angles.current.x - 4);
        applyTransform();
      }}
    >
      <div ref={sceneRef} className="discover-radar-scene" style={{ '--radar-rx': '58deg', '--radar-rz': '-20deg' } as CSSProperties}>
        <div className="discover-radar-layer discover-radar-shadow" />
        <div className="discover-radar-layer discover-radar-slab discover-radar-slab-back" />
        <div className="discover-radar-layer discover-radar-slab discover-radar-slab-mid" />
        <div className="discover-radar-layer discover-radar-face">
          {[100, 78, 52, 26].map(size => <span key={size} className="discover-radar-ring" style={{ width: `${size}%`, height: `${size}%` }} />)}
          <span className="discover-radar-cross" />
        </div>
        <div className="discover-radar-layer discover-radar-sweep" />
        <div className="discover-radar-hub">
          {RADAR_BLIPS.map((blip, index) => (
            <span className="discover-radar-pin" key={`${blip.angle}-${blip.radius}`} style={{
              transform: `rotateZ(${blip.angle}deg) translateY(${-blip.radius * 150}px) rotateZ(${-blip.angle}deg)`,
              '--pin-height': `${blip.height}px`, '--pin-delay': `${((blip.angle / 360) * 6).toFixed(2)}s`,
            } as CSSProperties}>
              <span className="discover-radar-pin-base" />
              <span className="discover-radar-pin-stem" />
              <span className="discover-radar-pin-dot" aria-label={`Nearby person ${index + 1}`} />
            </span>
          ))}
          <span className="discover-radar-you" />
        </div>
      </div>
      <span className="discover-radar-drag-hint">Drag to explore</span>
    </div>
  );
};

export const DiscoverWorkspace: React.FC = () => {
  const { friendRequests, sentRequests, acceptFriendRequest, rejectFriendRequest, cancelFriendRequest, sendFriendRequest } = useChat();
  const { user } = useAuth();
  const [friendInput, setFriendInput] = useState('');
  const [friendMessage, setFriendMessage] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [isMyQrOpen, setIsMyQrOpen] = useState(false);
  const [profileQr, setProfileQr] = useState('');

  useEffect(() => {
    if (!user?.username) {
      setProfileQr('');
      return;
    }
    let cancelled = false;
    const profileUrl = `${window.location.origin}/user/${encodeURIComponent(user.username)}`;
    import('qrcode')
      .then(module => module.toDataURL(profileUrl, {
        width: 180,
        margin: 1,
        errorCorrectionLevel: 'M',
        color: { dark: '#17243a', light: '#ffffff' },
      }))
      .then(value => { if (!cancelled) setProfileQr(value); })
      .catch(() => { if (!cancelled) setProfileQr(''); });
    return () => { cancelled = true; };
  }, [user?.username]);

  const refreshPeople = () => {
    const socket = connectSocket();
    if (socket.connected) socket.emit('discover_online');
  };

  const handleSendRequest = async (value = friendInput) => {
    const username = value.trim().replace(/^@/, '');
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

  const handleScannedUsername = (username: string) => {
    setIsScannerOpen(false);
    setFriendInput(username);
    void handleSendRequest(username);
  };

  return (
    <div className="discover-workspace">
      <div className="discover-hero-card">
        <DiscoverRadar />

        <div className="discover-hero-copy">
          <p className="discover-eyebrow">Something new awaits</p>
          <h1>Find your next connection</h1>
          <p className="discover-subtitle">
          See who’s online, send a friend request, and let a new conversation unfold.
        </p>

          <button type="button" className="discover-refresh-btn" onClick={refreshPeople}>
            <RefreshCw size={17} />
            Refresh people
          </button>
        </div>
      </div>

      <div className="discover-lower-grid">
        <div className="discover-main-column">
          <section className="discover-card discover-requests-card">
            <header>
              <span className="discover-card-icon"><Users size={17} /></span>
              <div><h2>Friend requests</h2><p>People waiting to connect</p></div>
              <span className="discover-count">{friendRequests.length}</span>
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
              <span className="discover-card-icon is-warm"><Clock3 size={17} /></span>
              <div><h2>Sent requests</h2><p>Track pending invitations</p></div>
              <span className="discover-count">{sentRequests.size}</span>
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
              <span className="discover-card-icon is-blue"><UserPlus size={17} /></span>
              <div><h2>Add a friend</h2><p>Connect with an exact username</p></div>
            </header>

            <div className="discover-input-row">
              <input type="text" placeholder="Username" value={friendInput} onChange={(event) => setFriendInput(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void handleSendRequest(); }} />
              <button type="button" className="discover-send-btn" onClick={() => void handleSendRequest()} disabled={isSending || !friendInput.trim()}>
                <Send size={15} />
                {isSending ? 'Sending…' : 'Send'}
              </button>
            </div>
            <p className="discover-inline-hint" role="status">{friendMessage || 'Usernames are not case-sensitive.'}</p>
          </section>

          <section className="discover-card discover-qr-card">
            <button type="button" className="qr-box" aria-label="Show my profile QR code" onClick={() => setIsMyQrOpen(true)}>
              {profileQr ? <img src={profileQr} alt={`Profile QR code for @${user?.username}`} /> : <QrCode size={34} />}
            </button>
            <div className="qr-copy">
              <h3>Share my QR</h3>
              <p>{user?.username ? `@${user.username}` : 'Friends can scan to add you'}</p>
            </div>
            <button type="button" className="discover-qr-button" onClick={() => setIsScannerOpen(true)}>
              <ScanLine size={16} />
              Scan a code
            </button>
          </section>
        </div>
      </div>
      <QRScannerModal isOpen={isScannerOpen} onClose={() => setIsScannerOpen(false)} onFoundUsername={handleScannedUsername} />
      {user?.username && <QRCodeModal isOpen={isMyQrOpen} onClose={() => setIsMyQrOpen(false)} username={user.username} displayName={user.displayName} avatarUrl={user.avatarId} />}
    </div>
  );
};
