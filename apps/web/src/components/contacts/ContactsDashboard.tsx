import { useState } from 'react';
import { Pin, Plus, MessageCircle, Phone, Gamepad2, Activity, Lock, X, Grid3X3, Circle, Hand } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import type { Conversation } from '../../types';
import type { GameType } from '../../types';
import './contactsDashboard.css';

const available = (c: Conversation) => c.online && (!c.presence || c.presence === 'online');
const status = (c: Conversation) => !c.online || c.presence === 'invisible' || c.presence === 'offline' ? 'Offline' : c.presence === 'busy' || c.presence === 'dnd' ? 'Busy' : c.presence === 'away' ? 'Away' : 'Online';
const gameOptions: { type: GameType; label: string; icon: typeof Gamepad2 }[] = [
  { type: 'tictactoe', label: 'Tic-Tac-Toe', icon: Grid3X3 },
  { type: 'connect4', label: 'Connect 4', icon: Circle },
  { type: 'rps', label: 'Rock Paper Scissors', icon: Hand },
];
export function ContactsDashboard({ onOpenChat }: { onOpenChat: () => void }) {
  const { conversations, pinnedChats, togglePinChat, setActiveChat, startCall, typingUsers, blockedUsers, friendRequests, sendGameChallenge } = useChat();
  const [editing, setEditing] = useState(false);
  const [search, setSearch] = useState('');
  const [opponent, setOpponent] = useState('');
  const [gameType, setGameType] = useState<GameType>('tictactoe');
  const friends = conversations.filter(c => !c.isGroup && !blockedUsers.has(c.username));
  const pinned = friends.filter(c => pinnedChats.has(c.username));
  const online = friends.filter(c => !c.isSelf && available(c));
  const selected = online.find(c => c.username === opponent) || online[0];
  const live = friends.filter(c => !c.isSelf && !['busy', 'dnd', 'invisible', 'offline'].includes(c.presence || '') && (typingUsers.has(c.username) || c.unreadCount > 0));
  const open = (username: string) => { setActiveChat(username); onOpenChat(); };
  return <div className="contacts-dashboard">
    <section className="contacts-overview-card contacts-pinned">
      <header><h2><Pin size={19} />Pinned contacts <small>{pinned.length}</small></h2><button className="contacts-text-button" onClick={() => setEditing(!editing)}>{editing ? 'Done' : 'Edit'}</button></header>
      <div className="contacts-pinned-grid">{pinned.map(friend => <article className="contacts-pin-tile" key={friend.username}>
        <button className="contacts-person" onClick={() => open(friend.username)}><Avatar name={friend.displayName || friend.username} avatarUrl={friend.avatarId} online={friend.online} presence={friend.presence} size="lg" /><strong>{friend.isSelf ? 'Saved Messages' : friend.displayName || friend.username}</strong><small>{friend.isSelf ? 'Only you' : status(friend)}</small></button>
        <div className="contacts-pin-actions"><button aria-label={'Message ' + friend.username} onClick={() => open(friend.username)}><MessageCircle size={16} /></button><button disabled={friend.isSelf} aria-label={'Call ' + friend.username} onClick={() => void startCall(friend.username, false)}><Phone size={16} /></button>{editing && <button aria-label={'Unpin ' + friend.username} onClick={() => togglePinChat(friend.username)}><X size={16} /></button>}</div>
      </article>)}<button className="contacts-pin-add" onClick={() => setEditing(true)}><Plus size={24} /><span>Pin a friend</span></button></div>
      {editing && <div className="contacts-pin-picker"><label>Find a contact<input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search contacts" /></label><div>{friends.filter(c => !pinnedChats.has(c.username) && (c.displayName + c.username).toLowerCase().includes(search.toLowerCase())).map(c => <button key={c.username} aria-label={"Pin " + c.username} onClick={() => togglePinChat(c.username)}><Plus size={14} />{c.displayName || c.username}</button>)}</div>{friends.every(c => pinnedChats.has(c.username) || !(c.displayName + c.username).toLowerCase().includes(search.toLowerCase())) && <p>No more matching contacts to pin.</p>}</div>}
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
  </div>;
}
