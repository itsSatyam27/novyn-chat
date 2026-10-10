import { getPreferredLocale, getPreferredTimeZone, getPreferredDayKey } from '../../services/regionalPreferences';
import React, { useState } from 'react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import {
  Phone,
  Video,
  PhoneIncoming,
  PhoneOutgoing,
  PhoneMissed,
  Trash2,
  Search,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import './callsPanel.css';

interface CallsPanelProps {
  isCompact?: boolean;
  onOpenContacts?: () => void;
}

export const CallsPanel: React.FC<CallsPanelProps> = ({ isCompact = false, onOpenContacts }) => {
  const { startCall, callLogs, clearCallLogs, unreadMissedCallCount } = useChat();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<'all' | 'missed' | 'audio' | 'video'>('all');
  const filteredLogs = callLogs.filter(log => {
    const matchesQuery = (log.partnerDisplayName || log.partner).toLowerCase().includes(query.trim().toLowerCase());
    const matchesFilter = filter === 'all' || (filter === 'missed' ? log.type === 'missed' : filter === 'video' ? log.isVideo : !log.isVideo);
    return matchesQuery && matchesFilter;
  });

  const formatTimestamp = (ts: string | number) => {
    try {
      const d = new Date(ts);
      const now = new Date();
      const isToday = getPreferredDayKey(d) === getPreferredDayKey(now);
      const time = d.toLocaleTimeString(getPreferredLocale(), { timeZone: getPreferredTimeZone(), hour: '2-digit', minute: '2-digit' });
      return isToday ? time : `${d.toLocaleDateString(getPreferredLocale(), { timeZone: getPreferredTimeZone(), month: 'short', day: 'numeric' })}, ${time}`;
    } catch {
      return '';
    }
  };

  const formatDuration = (secs?: number) => {
    if (!secs) return '';
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  if (isCompact) {
    return (
      <div className="chat-list-panel" style={{ width: '100%', alignItems: 'center', padding: '14px 0' }}>
        <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'var(--primary-glow)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary)', marginBottom: '16px' }}>
          <Phone style={{ width: '18px', height: '18px' }} />
        </div>

        <div className="conversations-scroll" style={{ width: '100%', alignItems: 'center', gap: '10px', padding: '0 8px' }}>
          {callLogs.slice(0, 10).map((log) => (
            <div
              key={log.id}
              onClick={() => {
                triggerHaptic('medium');
                startCall(log.partner, log.isVideo);
              }}
              style={{ position: 'relative', cursor: 'pointer', padding: '4px' }}
              title={`Call ${log.partnerDisplayName || log.partner}`}
            >
              <Avatar
                name={log.partnerDisplayName || log.partner}
                avatarUrl={log.partnerAvatarId}
                size="md"
              />
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="chat-list-panel calls-panel" style={{ width: '100%' }}>
      {/* Top Header */}
      <div className="chat-list-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span className="sidebar-outline-icon" aria-hidden="true"><Phone size={18} /></span>
          <div>
            <h2 className="chat-list-title" style={{ fontSize: '1.15rem' }}>Calls</h2>
          </div>
        </div>

        {callLogs.length > 0 && (
          <button
            type="button"
            onClick={() => {
              triggerHaptic('medium');
              clearCallLogs();
            }}
            className="header-action-btn"
            aria-label="Clear Call History"
            title="Clear Call History"
          >
            <Trash2 style={{ width: '16px', height: '16px' }} />
          </button>
        )}
      </div>

      {/* Main Scroll Stream - Recent Calls Only */}
      <div className="calls-history-tools">
        <label className="calls-history-search"><Search size={15} /><input value={query} onChange={event => setQuery(event.target.value)} placeholder="Search calls..." /></label>
        <div className="calls-history-filters">
          {(['all', 'missed', 'audio', 'video'] as const).map(value => <button key={value} type="button" aria-pressed={filter === value} onClick={() => setFilter(value)}>{value === 'missed' ? `Missed${unreadMissedCallCount > 0 ? ` ${unreadMissedCallCount}` : ''}` : value.charAt(0).toUpperCase() + value.slice(1)}</button>)}
        </div>
      </div>

      <div className="conversations-scroll" style={{ padding: '4px 14px 10px' }}>
        {callLogs.length === 0 ? (
          <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-dark)' }}>
            <span className="sidebar-outline-icon is-empty" aria-hidden="true"><Phone size={32} /></span>
            <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-main)', marginBottom: '4px' }}>
              No Recent Calls
            </h3>
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', margin: 0 }}>
              Audio and video calls made or received will appear here.
            </p>
            {onOpenContacts && <button type="button" className="empty-state-action" style={{ marginTop: 16 }} onClick={onOpenContacts}>Choose someone to call</button>}
          </div>
        ) : filteredLogs.length === 0 ? <p style={{ padding: '28px 14px', color: 'var(--text-muted)', fontSize: '0.8rem', textAlign: 'center' }}>No calls match your search.</p> : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {filteredLogs.map((log) => {
              const isMissed = log.type === 'missed';
              const isIncoming = log.type === 'incoming';

              return (
                <div
                  key={log.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    borderRadius: '14px',
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border)',
                    gap: '10px',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0, flex: 1 }}>
                    <Avatar
                      name={log.partnerDisplayName || log.partner}
                      avatarUrl={log.partnerAvatarId}
                      size="md"
                    />

                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div
                        style={{
                          fontSize: '0.9rem',
                          fontWeight: 700,
                          color: isMissed ? '#bd3750' : 'var(--text-main)',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {log.partnerDisplayName || log.partner}
                      </div>

                      <div
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '5px',
                          fontSize: '0.72rem',
                          color: 'var(--text-muted)',
                          marginTop: '3px',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {isMissed ? (
                          <PhoneMissed style={{ width: '13px', height: '13px', color: '#ef4444', flexShrink: 0 }} />
                        ) : isIncoming ? (
                          <PhoneIncoming style={{ width: '13px', height: '13px', color: 'var(--primary)', flexShrink: 0 }} />
                        ) : (
                          <PhoneOutgoing style={{ width: '13px', height: '13px', color: 'var(--primary)', flexShrink: 0 }} />
                        )}

                        <span style={{ color: isMissed ? '#ef4444' : 'var(--text-muted)' }}>
                          {isMissed ? 'Missed' : `${log.isVideo ? 'Video' : 'Audio'}${log.duration ? ` • ${formatDuration(log.duration)}` : ''}`}
                        </span>
                        <span>•</span>
                        <span>{formatTimestamp(log.timestamp)}</span>
                      </div>
                    </div>
                  </div>

                  {/* Redial Action */}
                  <button
                    type="button"
                    onClick={() => {
                      triggerHaptic('medium');
                      startCall(log.partner, log.isVideo);
                    }}
                    className="header-action-btn"
                    style={{ flexShrink: 0 }}
                    aria-label={log.isVideo ? 'Redial Video Call' : 'Redial Audio Call'}
                    title={log.isVideo ? 'Redial Video Call' : 'Redial Audio Call'}
                  >
                    {log.isVideo ? (
                      <Video style={{ width: '16px', height: '16px', color: 'var(--primary)' }} />
                    ) : (
                      <Phone style={{ width: '16px', height: '16px', color: 'var(--primary)' }} />
                    )}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};
