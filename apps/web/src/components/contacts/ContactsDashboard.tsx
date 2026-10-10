import { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Pin, Plus, MessageCircle, Phone, Gamepad2, Activity, Lock, X, Grid3X3, Circle, Hand } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import type { Conversation, GameType } from '../../types';
import './contactsDashboard.css';

const available = (c: Conversation) => c.online && (!c.presence || c.presence === 'online');
const status = (c: Conversation) => !c.online || c.presence === 'invisible' || c.presence === 'offline' ? 'Offline' : c.presence === 'busy' || c.presence === 'dnd' ? 'Busy' : c.presence === 'away' ? 'Away' : 'Online';
const gameOptions: { type: GameType; label: string; icon: typeof Gamepad2 }[] = [
  { type: 'tictactoe', label: 'Tic-Tac-Toe', icon: Grid3X3 },
  { type: 'connect4', label: 'Connect 4', icon: Circle },
  { type: 'rps', label: 'Rock Paper Scissors', icon: Hand },
];

export function ContactsDashboard({ onOpenChat }: { onOpenChat: () => void }) {
  const { conversations, pinnedChats, togglePinChat, reorderPinnedChats, setActiveChat, startCall, typingUsers, blockedUsers, friendRequests, sendGameChallenge } = useChat();
  const [editing, setEditing] = useState(false);
  const [opponent, setOpponent] = useState('');
  const [gameType, setGameType] = useState<GameType>('tictactoe');
  const [draggedPinned, setDraggedPinned] = useState<string | null>(null);
  const [dragOverPinned, setDragOverPinned] = useState<string | null>(null);

  const [isPinPickerOpen, setIsPinPickerOpen] = useState(false);
  const pinButtonRef = useRef<HTMLButtonElement | null>(null);
  const pinPickerRef = useRef<HTMLDivElement | null>(null);
  const [pinPickerPosition, setPinPickerPosition] = useState({ top: 0, left: 0 });

  const friends = conversations.filter(c => !c.isGroup && !blockedUsers.has(c.username));
  const pinned = [...pinnedChats]
    .map(username => friends.find(c => c.username.toLowerCase() === username.toLowerCase()))
    .filter((c): c is Conversation => Boolean(c));
  const availableToPin = friends.filter(c => !pinnedChats.has(c.username.toLowerCase()));

  useEffect(() => {
    if (!isPinPickerOpen) return;
    const updatePosition = () => {
      const rect = pinButtonRef.current?.getBoundingClientRect();
      if (!rect) return;
      const width = Math.min(300, window.innerWidth - 24);
      const left = Math.max(12, Math.min(rect.left, window.innerWidth - width - 12));
      const estimatedHeight = Math.min(320, availableToPin.length * 48 + 48);
      const top = rect.bottom + estimatedHeight > window.innerHeight - 12
        ? Math.max(12, rect.top - estimatedHeight - 8)
        : rect.bottom + 8;
      setPinPickerPosition({ top, left });
    };
    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (!pinPickerRef.current?.contains(target) && !pinButtonRef.current?.contains(target)) {
        setIsPinPickerOpen(false);
      }
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setIsPinPickerOpen(false);
    };
    updatePosition();
    window.addEventListener('resize', updatePosition);
    window.addEventListener('scroll', updatePosition, true);
    document.addEventListener('pointerdown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      window.removeEventListener('resize', updatePosition);
      window.removeEventListener('scroll', updatePosition, true);
      document.removeEventListener('pointerdown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [isPinPickerOpen, availableToPin.length]);

  const online = friends.filter(c => !c.isSelf && available(c));
  const selected = online.find(c => c.username === opponent) || online[0];
  const live = friends.filter(c => !c.isSelf && !['busy', 'dnd', 'invisible', 'offline'].includes(c.presence || '') && (typingUsers.has(c.username) || c.unreadCount > 0));
  const open = (username: string) => { setActiveChat(username); onOpenChat(); };

  return (
    <div className="contacts-dashboard">
      <section className="contacts-overview-card contacts-pinned">
        <header>
          <h2><Pin size={19} />Pinned contacts <small>{pinned.length} / 5</small></h2>
          <button className="contacts-text-button" onClick={() => setEditing(!editing)}>
            {editing ? 'Done' : 'Edit'}
          </button>
        </header>

        <div className={`contacts-pinned-grid${editing ? ' is-editing' : ''}`}>
          {pinned.map(friend => (
            <article
              className={`contacts-pin-tile${dragOverPinned === friend.username ? ' is-drag-over' : ''}${draggedPinned === friend.username ? ' is-dragging' : ''}`}
              key={friend.username}
              draggable
              onDragStart={event => { setDraggedPinned(friend.username); event.dataTransfer.setData('text/plain', friend.username); }}
              onDragOver={event => { event.preventDefault(); setDragOverPinned(friend.username); }}
              onDragLeave={() => setDragOverPinned(curr => curr === friend.username ? null : curr)}
              onDrop={event => {
                event.preventDefault();
                const source = event.dataTransfer.getData('text/plain') || draggedPinned;
                if (source) reorderPinnedChats(source, friend.username);
                setDraggedPinned(null);
                setDragOverPinned(null);
              }}
              onDragEnd={() => { setDraggedPinned(null); setDragOverPinned(null); }}
            >
              <button
                type="button"
                className="contacts-pin-toggle"
                aria-label={`Unpin ${friend.displayName || friend.username}`}
                title={`Unpin ${friend.displayName || friend.username}`}
                onClick={(e) => {
                  e.stopPropagation();
                  togglePinChat(friend.username);
                }}
              >
                <X size={13} />
              </button>

              <button className="contacts-person" onClick={() => open(friend.username)}>
                <Avatar name={friend.displayName || friend.username} avatarUrl={friend.avatarId} online={friend.online} presence={friend.presence} size="lg" />
                <strong>{friend.isSelf ? 'Saved Messages' : friend.displayName || friend.username}</strong>
                <small>{friend.isSelf ? 'Only you' : status(friend)}</small>
              </button>

              <div className="contacts-pin-actions">
                <button aria-label={'Message ' + friend.username} onClick={() => open(friend.username)}>
                  <MessageCircle size={16} />
                </button>
                <button disabled={friend.isSelf} aria-label={'Call ' + friend.username} onClick={() => void startCall(friend.username, false)}>
                  <Phone size={16} />
                </button>
              </div>
            </article>
          ))}

          {availableToPin.length > 0 && pinned.length < 5 && (
            <button
              ref={pinButtonRef}
              type="button"
              className="contacts-pin-add"
              aria-label="Pin a friend"
              aria-expanded={isPinPickerOpen}
              aria-haspopup="listbox"
              onClick={() => setIsPinPickerOpen(open => !open)}
            >
              <Plus size={24} />
              <span>Pin a friend</span>
            </button>
          )}

          {pinned.length === 0 && (
            <div className="contacts-pinned-empty">
              <p>No contacts pinned yet.</p>
              {availableToPin.length > 0 && (
                <button
                  type="button"
                  className="contacts-pinned-empty-btn"
                  onClick={() => setIsPinPickerOpen(true)}
                >
                  <Plus size={14} /> Pin a friend
                </button>
              )}
            </div>
          )}
        </div>

        {/* Floating Portal Pin Picker matching Messages tab */}
        {isPinPickerOpen && createPortal(
          <div
            ref={pinPickerRef}
            className="messages-pin-picker"
            role="listbox"
            aria-label="Choose a friend to pin"
            style={{ top: pinPickerPosition.top, left: pinPickerPosition.left }}
          >
            {availableToPin.map(c => (
              <button
                type="button"
                role="option"
                aria-selected="false"
                key={c.username}
                onClick={() => {
                  togglePinChat(c.username);
                  setIsPinPickerOpen(false);
                }}
              >
                <Avatar name={c.displayName || c.username} avatarUrl={c.avatarId} isGroup={c.isGroup} size="sm" />
                <span>{c.isSelf ? 'Saved Messages' : c.displayName || c.username}</span>
              </button>
            ))}
          </div>,
          document.body
        )}
      </section>

      <div className="contacts-overview-bottom">
        <section className="contacts-overview-card contacts-game">
          <header><h2><Gamepad2 size={17} />Play a game</h2><small>{online.length} player{online.length === 1 ? '' : 's'}</small></header>
          <div className="contacts-game-step"><span>1</span><small>Choose a game</small></div>
          <div className="contacts-game-options">
            {gameOptions.map(({ type, label, icon: Icon }) => (
              <button key={type} type="button" className="contacts-game-option" aria-pressed={gameType === type} onClick={() => setGameType(type)}>
                <Icon size={19} aria-hidden="true" />
                <span>{label}</span>
              </button>
            ))}
          </div>
          <div className="contacts-game-step"><span>2</span><small>Pick an online friend</small></div>
          {online.length ? (
            <div className="contacts-opponents">
              {online.map(c => <button key={c.username} type="button" aria-label={'Select ' + (c.displayName || c.username)} aria-pressed={selected?.username === c.username} onClick={() => setOpponent(c.username)}><Avatar name={c.displayName || c.username} avatarUrl={c.avatarId} online presence={c.presence} size="sm" /></button>)}
            </div>
          ) : <p className="contacts-game-empty">Your online friends will appear here.</p>}
          <button className="contacts-game-challenge" disabled={!selected} onClick={() => { if (selected) { sendGameChallenge(gameType, selected.username); open(selected.username); } }}>
            {selected ? `Challenge ${selected.displayName || selected.username} · ${gameOptions.find(game => game.type === gameType)?.label}` : 'No friends online'}
          </button>
        </section>
        <section className="contacts-overview-card contacts-live"><header><h2><Activity size={19} />For you</h2><small>Live updates</small></header><div className="contacts-live-list">{live.map(c => <div className="contacts-live-row" key={c.username}><Avatar name={c.displayName || c.username} avatarUrl={c.avatarId} size="sm" /><div><strong>{c.displayName || c.username}</strong><small>{typingUsers.has(c.username) ? 'Typing to you...' : c.unreadCount + ' unread messages'}</small></div><button onClick={() => open(c.username)}>Open</button></div>)}{!live.length && <div className="contacts-live-empty"><MessageCircle size={28} /><h3>All caught up</h3><p>New messages and typing updates addressed to you appear here.</p></div>}{friendRequests.length > 0 && <p>{friendRequests.length} pending friend requests. Review them in the Requests tab on the left.</p>}</div><footer><Lock size={13} />Only updates addressed to you. Busy and Invisible contacts stay hidden here.</footer></section>
      </div>
    </div>
  );
}
