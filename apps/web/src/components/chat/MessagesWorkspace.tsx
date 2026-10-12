import React, { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { ArrowUpRight, Check, HelpCircle, KeyRound, Lightbulb, LockKeyhole, MessageCircle, Phone, Pin, Plus, X } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import { CreateGroupModal } from './CreateGroupModal';
import type { Conversation } from '../../types';
import './messagesWorkspace.css';

const preview = (conversation: Conversation) => {
  const message = conversation.lastMessage;
  if (!message) return conversation.isSelf ? 'Tap to chat' : 'Start a conversation';
  if (message.attachment) return message.isVoice ? 'Sent a voice message' : 'Shared an attachment';
  return message.text || 'Message';
};

export const MessagesWorkspace: React.FC = () => {
  const { conversations, pinnedChats, manualUnreadChats, blockedUsers, setActiveChat, togglePinChat, reorderPinnedChats, startCall, sendRiddle } = useChat();
  const [recipientSearch, setRecipientSearch] = useState('');
  const [isGroupModalOpen, setIsGroupModalOpen] = useState(false);
  const [isPinPickerOpen, setIsPinPickerOpen] = useState(false);
  const [pinPickerPosition, setPinPickerPosition] = useState({ top: 0, left: 0 });
  const pinButtonRef = useRef<HTMLButtonElement>(null);
  const pinPickerRef = useRef<HTMLDivElement>(null);
  const [selectedRecipient, setSelectedRecipient] = useState('');
  const [draft, setDraft] = useState('');
  const [riddleQuestion, setRiddleQuestion] = useState('');
  const [riddleAnswer, setRiddleAnswer] = useState('');
  const [riddleHint, setRiddleHint] = useState('');
  const [riddleTries, setRiddleTries] = useState<3 | 5>(3);
  const [riddleBusy, setRiddleBusy] = useState(false);
  const [riddleNotice, setRiddleNotice] = useState('');
  const [editingPinned, setEditingPinned] = useState(false);
  const [draggedPinned, setDraggedPinned] = useState<string | null>(null);
  const [dragOverPinned, setDragOverPinned] = useState<string | null>(null);
  const allChats = useMemo(() => [...conversations].sort((a, b) => {
    const aTime = new Date(a.lastMessage?.timestamp || 0).getTime();
    const bTime = new Date(b.lastMessage?.timestamp || 0).getTime();
    return bTime - aTime;
  }), [conversations]);
  const pinnableContacts = allChats.filter(chat => !chat.isGroup && !chat.isSelf && chat.isFriend !== false && !blockedUsers.has(chat.username.toLowerCase()));
  const pinned = [...pinnedChats]
    .map(username => pinnableContacts.find(chat => chat.username.toLowerCase() === username))
    .filter((chat): chat is Conversation => Boolean(chat));
  const availableToPin = pinnableContacts.filter(chat => !pinnedChats.has(chat.username.toLowerCase()));
  const allUnread = allChats.filter(chat => chat.unreadCount > 0 || manualUnreadChats.has(chat.username.toLowerCase()));
  const unread = allUnread.slice(0, 5);
  const groups = allChats.filter(chat => chat.isGroup).slice(0, 4);
  const directChats = allChats.filter(chat => !chat.isGroup && !chat.isSelf);
  const recipientMatches = directChats.filter(chat => (chat.displayName + ' ' + chat.username).toLowerCase().includes(recipientSearch.trim().toLowerCase())).slice(0, 5);

  useEffect(() => {
    if (!selectedRecipient && directChats[0]) setSelectedRecipient(directChats[0].username);
  }, [selectedRecipient, directChats]);

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
      if (!pinPickerRef.current?.contains(target) && !pinButtonRef.current?.contains(target)) setIsPinPickerOpen(false);
    };
    const onKeyDown = (event: KeyboardEvent) => { if (event.key === 'Escape') setIsPinPickerOpen(false); };
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

  const openChat = (username: string) => setActiveChat(username);
  const handleCompose = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!selectedRecipient || !draft.trim() || !riddleQuestion.trim() || !riddleAnswer.trim() || riddleBusy) return;
    setRiddleBusy(true);
    setRiddleNotice('');
    const result = await sendRiddle({ to: selectedRecipient, secret: draft.trim(), question: riddleQuestion.trim(), answer: riddleAnswer.trim(), hint: riddleHint.trim(), maxTries: riddleTries });
    setRiddleBusy(false);
    if (!result.ok) { setRiddleNotice(result.message || 'Could not send riddle.'); return; }
    setDraft(''); setRiddleQuestion(''); setRiddleAnswer(''); setRiddleHint('');
    setRiddleNotice('Riddle sent.');
  };
  const renderChatTile = (chat: Conversation, kind: 'pinned' | 'unread' | 'group') => (
    <button type="button" key={chat.username} className={`messages-chat-tile messages-chat-tile-${kind}`} onClick={() => openChat(chat.username)}>
      <Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} online={chat.online} presence={chat.presence} isGroup={chat.isGroup} hidePresence={chat.isSelf} size="sm" />
      <span className="messages-chat-copy"><strong>{chat.isSelf ? 'Saved Messages' : chat.displayName || chat.username}</strong><small>{kind === 'group' ? `${chat.memberCount || chat.members?.length || 0} members` : preview(chat)}</small></span>
      {kind === 'unread' && <span className="messages-unread-count">{chat.unreadCount || '•'}</span>}
      {kind === 'group' && <ArrowUpRight size={14} />}
    </button>
  );

  return (
    <main className="messages-workspace">
      <section className="messages-overview-card messages-pinned-card">
        <header><h2><Pin size={16} />Pinned contacts <small>{pinned.length} / 5</small></h2><div className="messages-pinned-meta"><small>Drag to reorder</small><button type="button" onClick={() => setEditingPinned(value => !value)}>{editingPinned ? 'Done' : 'Edit'}</button></div></header>
        <div className={`messages-pinned-grid${editingPinned ? ' is-editing' : ''}`}>
          {pinned.map(chat => <article
            className={`messages-pinned-tile${dragOverPinned === chat.username ? ' is-drag-over' : ''}${draggedPinned === chat.username ? ' is-dragging' : ''}`}
            key={chat.username}
            draggable
            onDragStart={event => { setDraggedPinned(chat.username); event.dataTransfer.effectAllowed = 'move'; event.dataTransfer.setData('text/plain', chat.username); }}
            onDragOver={event => { event.preventDefault(); event.dataTransfer.dropEffect = 'move'; setDragOverPinned(chat.username); }}
            onDragLeave={() => setDragOverPinned(current => current === chat.username ? null : current)}
            onDrop={event => { event.preventDefault(); const source = event.dataTransfer.getData('text/plain') || draggedPinned; if (source) reorderPinnedChats(source, chat.username); setDraggedPinned(null); setDragOverPinned(null); }}
            onDragEnd={() => { setDraggedPinned(null); setDragOverPinned(null); }}
          >
            <button type="button" className="messages-pinned-open" onClick={() => openChat(chat.username)}>
              <Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} online={chat.online} presence={chat.presence} isGroup={chat.isGroup} hidePresence={chat.isSelf} size="md" />
              <span className="messages-pinned-copy">
                <strong>{chat.isSelf ? 'Saved Messages' : chat.displayName || chat.username}</strong>
                <small>{preview(chat)}</small>
              </span>
            </button>
            <button type="button" className="messages-pin-toggle" aria-label={`Unpin ${chat.displayName || chat.username}`} onClick={() => togglePinChat(chat.username)}><X size={13} /></button>
            <div className="messages-pinned-actions"><button type="button" aria-label={`Message ${chat.username}`} onClick={() => openChat(chat.username)}><MessageCircle size={16} /></button><button type="button" aria-label={`Call ${chat.username}`} onClick={() => void startCall(chat.username, false)}><Phone size={16} /></button></div>
          </article>)}
          {availableToPin.length > 0 && pinned.length < 5 && <div className="messages-pin-add-wrap">
            <button ref={pinButtonRef} type="button" className="messages-pin-add" aria-expanded={isPinPickerOpen} aria-haspopup="listbox" onClick={() => setIsPinPickerOpen(open => !open)}><Plus size={20} /><span>Pin a chat</span></button>
          </div>}
        </div>
        {isPinPickerOpen && createPortal(<div ref={pinPickerRef} className="messages-pin-picker" role="listbox" aria-label="Choose a chat to pin" style={{ top: pinPickerPosition.top, left: pinPickerPosition.left }}>
          {availableToPin.map(chat => <button type="button" role="option" aria-selected="false" key={chat.username} onClick={() => { togglePinChat(chat.username); setIsPinPickerOpen(false); }}>
            <Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} isGroup={chat.isGroup} size="sm" />
            <span>{chat.isSelf ? 'Saved Messages' : chat.displayName || chat.username}</span>
          </button>)}
        </div>, document.body)}
      </section>

      <div className="messages-summary-grid">
        <section className="messages-overview-card messages-unread-card">
          <header><h2>Unread <span>{allUnread.reduce((sum, chat) => sum + (chat.unreadCount || 1), 0)}</span></h2></header>
          <div className="messages-row-list">{unread.length ? unread.map(chat => renderChatTile(chat, 'unread')) : <div className="messages-caught-up"><span><Check size={18} /></span><div><small>Unread · 0</small><strong>You’re all caught up</strong><p>New unread chats will show up here.</p></div></div>}</div>
        </section>
        <section className="messages-overview-card messages-groups-card">
          <header><h2>Groups</h2><button type="button" onClick={() => setIsGroupModalOpen(true)}><Plus size={13} />New group</button></header>
          <div className="messages-row-list">{groups.length ? groups.map(chat => renderChatTile(chat, 'group')) : <p className="messages-empty">Your group conversations will appear here.</p>}</div>
        </section>
      </div>

      <section className="messages-overview-card messages-compose-card riddle-compose-card">
        <header><h2><LockKeyhole size={14} />Riddle lock <span>New</span></h2><small>Just for fun. For private info, send normally.</small></header>
        <form onSubmit={handleCompose}>
          <div className="riddle-compose-grid"><div className="riddle-compose-form"><div className="messages-recipient-line">
            <span className="messages-recipient-prefix">To:</span>
            {directChats.slice(0, 4).map(chat => {
              const isSelected = selectedRecipient.toLowerCase() === chat.username.toLowerCase();
              return <button type="button" key={chat.username} className={`messages-recipient-chip${isSelected ? ' is-selected' : ''}`} aria-pressed={isSelected} onClick={() => { setSelectedRecipient(chat.username); setRecipientSearch(''); }}>
                <Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} isGroup={chat.isGroup} hidePresence={chat.isSelf} size="sm" />
                <span>{chat.isSelf ? 'Saved' : chat.displayName || chat.username}</span>
              </button>;
            })}
            <input className="messages-recipient-search" value={recipientSearch} onChange={event => { setSelectedRecipient(''); setRecipientSearch(event.target.value); }} placeholder="Search a contact..." aria-label="Search recipient" />
          </div>
          {recipientSearch && !selectedRecipient && <div className="messages-recipient-results">{recipientMatches.map(chat => <button type="button" key={chat.username} onClick={() => { setSelectedRecipient(chat.username); setRecipientSearch(''); }}><Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} size="sm" /><span>{chat.displayName || chat.username}</span><small>@{chat.username}</small></button>)}{recipientMatches.length === 0 && <p>No matching contacts.</p>}</div>}
          <textarea className="messages-draft-input" aria-label="Secret message" value={draft} onChange={event => setDraft(event.target.value.slice(0, 250))} maxLength={250} placeholder="Write the secret message..." />
          <div className="riddle-input-row"><label><HelpCircle size={15} /><input value={riddleQuestion} maxLength={160} onChange={event => setRiddleQuestion(event.target.value)} placeholder="Ask a question (e.g. our first movie?)" aria-label="Riddle question" /></label><label><KeyRound size={15} /><input type="password" value={riddleAnswer} maxLength={80} onChange={event => setRiddleAnswer(event.target.value)} placeholder="Answer" aria-label="Riddle answer" /></label></div>
          <div className="riddle-options-row"><label><Lightbulb size={15} /><input value={riddleHint} maxLength={160} onChange={event => setRiddleHint(event.target.value)} placeholder="Hint (optional)" aria-label="Riddle hint" /></label><span>Tries</span><button type="button" className={riddleTries === 3 ? 'is-selected' : ''} onClick={() => setRiddleTries(3)}>3</button><button type="button" className={riddleTries === 5 ? 'is-selected' : ''} onClick={() => setRiddleTries(5)}>5</button></div>
          <div className="messages-compose-actions"><small>{draft.length} / 250</small><button type="submit" disabled={!selectedRecipient || !draft.trim() || !riddleQuestion.trim() || !riddleAnswer.trim() || riddleBusy}><LockKeyhole size={15} />{riddleBusy ? 'Sending…' : 'Lock & send'}</button></div>{riddleNotice && <p className="riddle-compose-notice">{riddleNotice}</p>}
          </div><aside className="riddle-preview"><small>What they’ll see</small><div className="riddle-preview-secret"><span><LockKeyhole size={16} /></span><i>{draft || 'Your secret message'}</i></div><strong>{riddleQuestion || 'Your question appears here'}</strong>{riddleHint && <em><Lightbulb size={12} />Hint: {riddleHint}</em>}<div><input disabled placeholder="Your answer" /><button type="button" disabled>Unlock</button></div><small>{riddleTries} tries left</small></aside></div>
        </form>
      </section>
      <CreateGroupModal isOpen={isGroupModalOpen} onClose={() => setIsGroupModalOpen(false)} />
    </main>
  );
};
