import React from 'react';
import { Activity, Camera, Mic, Phone, PhoneCall, Video, UserPlus, PhoneMissed } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import './callsWorkspace.css';

interface CallsWorkspaceProps { onOpenContacts: () => void; }

export const CallsWorkspace: React.FC<CallsWorkspaceProps> = ({ onOpenContacts }) => {
  const { conversations, callLogs, startCall, unreadMissedCallCount } = useChat();
  const friends = conversations.filter(person => !person.isGroup && !person.isSelf);
  const online = friends.filter(person => person.online && (!person.presence || person.presence === 'online'));
  const quickContacts = [...friends].sort((a, b) => Number(b.online) - Number(a.online)).slice(0, 4);
  const missed = callLogs.filter(log => log.type === 'missed').slice(0, 3);
  const call = (username: string, video = false) => { void startCall(username, video); };

  return (
    <main className="calls-workspace">
      <header className="calls-page-heading">
        <span className="calls-page-icon"><Phone size={20} /></span>
        <div><h1>Calls</h1><p>{callLogs.length} calls in your history{missed.length ? ` · ${missed.length} missed` : ''}</p></div>
      </header>

      <section className="calls-workspace-card calls-quick-card">
        <header><h2><PhoneCall size={17} />Quick call</h2><button type="button" onClick={onOpenContacts}>Edit</button></header>
        <div className="calls-quick-list">
          {quickContacts.map(person => (
            <article className="calls-quick-person" key={person.username}>
              <Avatar name={person.displayName || person.username} avatarUrl={person.avatarId} online={person.online} presence={person.presence} size="md" />
              <strong>{person.displayName || person.username}</strong>
              <div><button type="button" aria-label={`Audio call ${person.displayName || person.username}`} onClick={() => call(person.username)}><Phone size={14} /></button><button type="button" aria-label={`Video call ${person.displayName || person.username}`} onClick={() => call(person.username, true)}><Video size={14} /></button></div>
            </article>
          ))}
          <button type="button" className="calls-quick-add" onClick={onOpenContacts}><UserPlus size={20} /><span>Add</span></button>
          {!quickContacts.length && <p className="calls-workspace-empty">Start a conversation to add someone to Quick Call.</p>}
        </div>
      </section>

      <div className="calls-workspace-grid">
        <section className="calls-workspace-card calls-missed-card">
          <header><h2><PhoneMissed size={16} />Missed calls</h2>{unreadMissedCallCount > 0 && <span>{unreadMissedCallCount}</span>}</header>
          <div className="calls-workspace-list">
            {missed.length ? missed.map(log => <article className="calls-workspace-row" key={log.id}>
              <Avatar name={log.partnerDisplayName || log.partner} avatarUrl={log.partnerAvatarId} size="sm" />
              <div><strong>{log.partnerDisplayName || log.partner}</strong><small>{log.isVideo ? 'Video' : 'Audio'} · {new Date(log.timestamp).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</small></div>
              <button type="button" aria-label={`Call back ${log.partnerDisplayName || log.partner}`} onClick={() => call(log.partner, log.isVideo)}><Phone size={14} />Call back</button>
            </article>) : <p className="calls-workspace-empty">No missed calls. You’re all caught up.</p>}
          </div>
        </section>

        <section className="calls-workspace-card calls-online-card">
          <header><h2><span className="calls-online-dot" />Online &amp; free to talk</h2><span>{online.length}</span></header>
          <div className="calls-workspace-list">
            {online.length ? online.slice(0, 5).map(person => <article className="calls-workspace-row" key={person.username}>
              <Avatar name={person.displayName || person.username} avatarUrl={person.avatarId} online presence={person.presence} size="sm" />
              <div><strong>{person.displayName || person.username}</strong><small>Free to talk</small></div>
              <button type="button" aria-label={`Audio call ${person.displayName || person.username}`} onClick={() => call(person.username)}><Phone size={14} /></button>
              <button type="button" className="calls-video-action" aria-label={`Video call ${person.displayName || person.username}`} onClick={() => call(person.username, true)}><Video size={14} /></button>
            </article>) : <p className="calls-workspace-empty">Busy and invisible friends stay hidden here.</p>}
          </div>
          <button type="button" className="calls-search-contacts" onClick={onOpenContacts}><Activity size={14} />Search contacts to call</button>
        </section>

        <section className="calls-workspace-card calls-device-card">
          <header><h2>Check mic &amp; camera</h2><span className="calls-device-ready">Ready</span></header>
          <div className="calls-device-preview"><span><Mic size={17} /><i /><i /><i /><i /><i /><i /></span><div><strong>Audio and video calls</strong><p>Your browser will ask before enabling your microphone or camera.</p></div><Camera size={19} /></div>
        </section>
      </div>
    </main>
  );
};
