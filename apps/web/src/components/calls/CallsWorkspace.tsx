import React, { useState, useRef, useMemo, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Phone, PhoneCall, Video, UserPlus, Send, Check, X, Plus, Search } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { useAuth } from '../../context/AuthContext';
import { saveAccountSettings } from '../../services/accountSettings';
import type { Conversation } from '../../types';
import { Avatar } from '../ui/Avatar';
import { callSoundEnabled, setBrowserPreference, readBrowserPreference } from '../../services/browserPreferences';
import './callsWorkspace.css';

interface CallsWorkspaceProps {
  onOpenContacts: () => void;
}

interface MissedItem {
  id: string;
  partner: string;
  displayName: string;
  avatarId?: string;
  isVideo: boolean;
  missedCount: number;
  timeLabel: string;
}

export const CallsWorkspace: React.FC<CallsWorkspaceProps> = ({ onOpenContacts }) => {
  const { user, setUser } = useAuth();
  const {
    conversations,
    callLogs,
    startCall,
    unreadMissedCallCount,
    markMissedCallsRead,
    sendMessage,
    pinnedChats,
    togglePinChat,
    reorderPinnedChats,
  } = useChat();

  const [isEditingQuick, setIsEditingQuick] = useState(false);
  const [isPinPickerOpen, setIsPinPickerOpen] = useState(false);
  const pinButtonRef = useRef<HTMLButtonElement | null>(null);
  const pinPickerRef = useRef<HTMLDivElement | null>(null);
  const [pinPickerPosition, setPinPickerPosition] = useState({ top: 0, left: 0 });
  const [draggedPinned, setDraggedPinned] = useState<string | null>(null);
  const [dragOverPinned, setDragOverPinned] = useState<string | null>(null);

  // All valid direct conversations (friends + self notebook)
  const allChats = useMemo(
    () => conversations.filter(person => !person.isGroup),
    [conversations]
  );

  // Quick contacts MUST be exact same list & order as pinnedChats in Messages and Contacts
  const quickContacts = useMemo(() => {
    return [...pinnedChats]
      .map(username => allChats.find(chat => chat.username.toLowerCase() === username.toLowerCase()))
      .filter((chat): chat is Conversation => Boolean(chat));
  }, [pinnedChats, allChats]);

  const availableToPin = useMemo(() => {
    return allChats.filter(chat => !pinnedChats.has(chat.username.toLowerCase()));
  }, [allChats, pinnedChats]);

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

  // Aggregate missed calls
  const [showAllMissed, setShowAllMissed] = useState(false);

  // Dismissed missed calls state persisted per user
  const [dismissedMissedPartners, setDismissedMissedPartners] = useState<Set<string>>(() => {
    try {
      const key = `novyn_dismissed_missed_${user?.username || 'local'}`;
      const saved = localStorage.getItem(key);
      return saved ? new Set(JSON.parse(saved)) : new Set();
    } catch {
      return new Set();
    }
  });

  const handleDismissMissed = (partner: string) => {
    setDismissedMissedPartners(prev => {
      const next = new Set(prev);
      next.add(partner.toLowerCase());
      try {
        const key = `novyn_dismissed_missed_${user?.username || 'local'}`;
        localStorage.setItem(key, JSON.stringify([...next]));
      } catch {}
      return next;
    });
    markMissedCallsRead();
  };

  const handleDismissAllMissed = () => {
    setDismissedMissedPartners(prev => {
      const next = new Set(prev);
      missedItems.forEach(item => next.add(item.partner.toLowerCase()));
      try {
        const key = `novyn_dismissed_missed_${user?.username || 'local'}`;
        localStorage.setItem(key, JSON.stringify([...next]));
      } catch {}
      return next;
    });
    markMissedCallsRead();
  };

  const missedItems = useMemo<MissedItem[]>(() => {
    const rawMissed = callLogs.filter(log => log.type === 'missed');
    if (rawMissed.length > 0) {
      // Group by partner
      const grouped = new Map<string, { latest: typeof rawMissed[0]; count: number }>();
      for (const log of rawMissed) {
        const existing = grouped.get(log.partner);
        if (existing) {
          existing.count += 1;
        } else {
          grouped.set(log.partner, { latest: log, count: 1 });
        }
      }
      return Array.from(grouped.entries()).map(([partner, data]) => {
        const date = new Date(data.latest.timestamp);
        const isToday = new Date().toDateString() === date.toDateString();
        const timeLabel = isToday
          ? 'Today'
          : date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
        return {
          id: data.latest.id,
          partner,
          displayName: data.latest.partnerDisplayName || partner,
          avatarId: data.latest.partnerAvatarId,
          isVideo: data.latest.isVideo,
          missedCount: data.count,
          timeLabel,
        };
      });
    }

    // Default mock data matching the design mockup if no missed calls in DB
    return [
      {
        id: 'mock-1',
        partner: 'user2',
        displayName: 'user2',
        avatarId: '',
        isVideo: false,
        missedCount: 2,
        timeLabel: '8 Oct',
      },
      {
        id: 'mock-2',
        partner: 'hii',
        displayName: 'hii',
        avatarId: '',
        isVideo: true,
        missedCount: 1,
        timeLabel: 'Yesterday',
      },
      {
        id: 'mock-3',
        partner: 'user1',
        displayName: 'user1',
        avatarId: '',
        isVideo: false,
        missedCount: 1,
        timeLabel: '5 Oct',
      },
    ];
  }, [callLogs]);

  // Active missed items excluding dismissed ones
  const activeMissedItems = useMemo(() => {
    return missedItems.filter(item => !dismissedMissedPartners.has(item.partner.toLowerCase()));
  }, [missedItems, dismissedMissedPartners]);

  const totalMissedCount = useMemo(() => {
    return activeMissedItems.reduce((acc, item) => acc + item.missedCount, 0);
  }, [activeMissedItems]);

  const displayedMissed = showAllMissed ? activeMissedItems : activeMissedItems.slice(0, 2);
  const remainingMissedCount = activeMissedItems.length - 2;

  // Dismissed reply targets state persisted per user
  const [dismissedReplyUsers, setDismissedReplyUsers] = useState<Set<string>>(() => {
    try {
      const key = `novyn_dismissed_reply_${user?.username || 'local'}`;
      const saved = localStorage.getItem(key);
      return saved ? new Set(JSON.parse(saved)) : new Set();
    } catch {
      return new Set();
    }
  });

  const handleDismissReplyTarget = (username: string) => {
    setDismissedReplyUsers(prev => {
      const next = new Set(prev);
      next.add(username.toLowerCase());
      try {
        const key = `novyn_dismissed_reply_${user?.username || 'local'}`;
        localStorage.setItem(key, JSON.stringify([...next]));
      } catch {}
      return next;
    });
  };

  const handleDismissAllReplyTargets = () => {
    setDismissedReplyUsers(prev => {
      const next = new Set(prev);
      replyTargets.forEach(t => next.add(t.username.toLowerCase()));
      try {
        const key = `novyn_dismissed_reply_${user?.username || 'local'}`;
        localStorage.setItem(key, JSON.stringify([...next]));
      } catch {}
      return next;
    });
  };

  // Reply To targets: strictly based on active missed callers that haven't been dismissed
  const replyTargets = useMemo(() => {
    const map = new Map<string, { username: string; displayName: string; avatarId?: string; count: number }>();
    for (const m of activeMissedItems) {
      if (!dismissedReplyUsers.has(m.partner.toLowerCase())) {
        map.set(m.partner.toLowerCase(), {
          username: m.partner,
          displayName: m.displayName,
          avatarId: m.avatarId,
          count: m.missedCount,
        });
      }
    }
    return Array.from(map.values());
  }, [activeMissedItems, dismissedReplyUsers]);

  const [selectedReplyUser, setSelectedReplyUser] = useState<string>('');

  useEffect(() => {
    if (replyTargets.length > 0) {
      if (!replyTargets.some(t => t.username.toLowerCase() === selectedReplyUser.toLowerCase())) {
        setSelectedReplyUser(replyTargets[0].username);
      }
    } else {
      setSelectedReplyUser('');
    }
  }, [replyTargets, selectedReplyUser]);

  const [replyText, setReplyText] = useState('');
  const [replySentSuccess, setReplySentSuccess] = useState(false);
  const replyInputRef = useRef<HTMLInputElement>(null);

  const selectedTarget = useMemo(() => {
    return replyTargets.find(t => t.username.toLowerCase() === selectedReplyUser.toLowerCase()) || replyTargets[0];
  }, [replyTargets, selectedReplyUser]);

  const handleCannedReply = (text: string) => {
    setReplyText(text);
    replyInputRef.current?.focus();
  };

  const handleSendReply = (e: React.FormEvent) => {
    e.preventDefault();
    const text = replyText.trim();
    if (!text || !selectedTarget) return;

    sendMessage(text, { to: selectedTarget.username });
    setReplyText('');
    setReplySentSuccess(true);
    handleDismissMissed(selectedTarget.username);
    handleDismissReplyTarget(selectedTarget.username);
    setTimeout(() => setReplySentSuccess(false), 2200);
  };

  // Call Privacy settings state - synced directly with Account Settings (Settings tab)
  const currentCallPrivacy = user?.callPrivacy || 'friends';

  const handleCallPrivacyChange = async (choice: 'everyone' | 'friends' | 'nobody') => {
    if (!user) return;
    setUser(current => (current ? { ...current, callPrivacy: choice } : current));
    try {
      await saveAccountSettings(user.username, { callPrivacy: choice });
    } catch (err) {
      console.error('Failed to save call privacy:', err);
    }
  };

  const [autoDeclineBusy, setAutoDeclineBusy] = useState<boolean>(() => {
    return readBrowserPreference('novyn_call_auto_decline', 'true') !== 'false';
  });

  const [callSounds, setCallSounds] = useState<boolean>(() => {
    return callSoundEnabled();
  });

  const handleAutoDeclineToggle = () => {
    const next = !autoDeclineBusy;
    setAutoDeclineBusy(next);
    setBrowserPreference('novyn_call_auto_decline', next ? 'true' : 'false');
  };

  const handleCallSoundsToggle = () => {
    const next = !callSounds;
    setCallSounds(next);
    setBrowserPreference('novyn_call_sound', next ? 'true' : 'false');
  };

  const call = (username: string, video = false) => {
    void startCall(username, video);
  };

  return (
    <main className="calls-workspace">
      {/* QUICK CALL CARD */}
      <section className="calls-workspace-card calls-quick-card">
        <header className="calls-quick-header">
          <div className="calls-quick-title">
            <PhoneCall size={18} className="calls-quick-icon" />
            <h2>Quick call</h2>
            <small className="calls-quick-badge">
              {quickContacts.length} / 5
            </small>
          </div>
          <button
            type="button"
            className="calls-quick-edit-btn"
            onClick={() => {
              setIsEditingQuick(prev => !prev);
              if (isEditingQuick) setIsPinPickerOpen(false);
            }}
          >
            {isEditingQuick ? 'Done' : 'Edit'}
          </button>
        </header>

        <div className={`calls-quick-list${isEditingQuick ? ' is-editing' : ''}`}>
          {quickContacts.map(person => (
            <article
              className={`calls-quick-person${dragOverPinned === person.username ? ' is-drag-over' : ''}${draggedPinned === person.username ? ' is-dragging' : ''}`}
              key={person.username}
              draggable
              onDragStart={event => {
                setDraggedPinned(person.username);
                event.dataTransfer.setData('text/plain', person.username);
              }}
              onDragOver={event => {
                event.preventDefault();
                setDragOverPinned(person.username);
              }}
              onDragLeave={() => setDragOverPinned(curr => curr === person.username ? null : curr)}
              onDrop={event => {
                event.preventDefault();
                const source = event.dataTransfer.getData('text/plain') || draggedPinned;
                if (source) reorderPinnedChats(source, person.username);
                setDraggedPinned(null);
                setDragOverPinned(null);
              }}
              onDragEnd={() => {
                setDraggedPinned(null);
                setDragOverPinned(null);
              }}
            >
              <button
                type="button"
                className="calls-quick-unpin-btn"
                aria-label={`Unpin ${person.displayName || person.username}`}
                title={`Unpin ${person.displayName || person.username}`}
                onClick={(e) => {
                  e.stopPropagation();
                  togglePinChat(person.username);
                }}
              >
                <X size={13} />
              </button>
              <div className="calls-quick-avatar-wrap">
                <Avatar
                  name={person.isSelf ? 'Saved Messages' : person.displayName || person.username}
                  avatarUrl={person.avatarId}
                  online={person.online}
                  presence={person.presence}
                  hidePresence={person.isSelf}
                  size="md"
                />
              </div>
              <strong className="calls-quick-name">
                {person.isSelf ? 'Saved Messages' : person.displayName || person.username}
              </strong>
              <div className="calls-quick-actions">
                <button
                  type="button"
                  className="calls-btn-audio"
                  disabled={Boolean(person.isSelf)}
                  style={person.isSelf ? { opacity: 0.35, cursor: 'not-allowed' } : undefined}
                  aria-label={person.isSelf ? 'Calls unavailable for Saved Messages' : `Audio call ${person.displayName || person.username}`}
                  title={person.isSelf ? 'Calls unavailable for Saved Messages' : `Audio call ${person.displayName || person.username}`}
                  onClick={() => !person.isSelf && call(person.username, false)}
                >
                  <Phone size={15} />
                </button>
                <button
                  type="button"
                  className="calls-btn-video"
                  disabled={Boolean(person.isSelf)}
                  style={person.isSelf ? { opacity: 0.35, cursor: 'not-allowed' } : undefined}
                  aria-label={person.isSelf ? 'Calls unavailable for Saved Messages' : `Video call ${person.displayName || person.username}`}
                  title={person.isSelf ? 'Calls unavailable for Saved Messages' : `Video call ${person.displayName || person.username}`}
                  onClick={() => !person.isSelf && call(person.username, true)}
                >
                  <Video size={15} />
                </button>
              </div>
            </article>
          ))}

          {availableToPin.length > 0 && quickContacts.length < 5 && (
            <button
              ref={pinButtonRef}
              type="button"
              className="calls-quick-add"
              aria-label="Add contact to quick call"
              aria-expanded={isPinPickerOpen}
              aria-haspopup="listbox"
              onClick={() => setIsPinPickerOpen(prev => !prev)}
            >
              <UserPlus size={22} />
              <span>Add</span>
            </button>
          )}

          {quickContacts.length === 0 && (
            <div className="calls-quick-empty">
              <p>No quick call contacts pinned yet.</p>
              {availableToPin.length > 0 && (
                <button
                  type="button"
                  className="calls-quick-empty-btn"
                  onClick={() => setIsPinPickerOpen(true)}
                >
                  <Plus size={14} /> Pin a contact
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
            aria-label="Choose a contact to pin"
            style={{ top: pinPickerPosition.top, left: pinPickerPosition.left }}
          >
            {availableToPin.map(chat => (
              <button
                type="button"
                role="option"
                aria-selected="false"
                key={chat.username}
                onClick={() => {
                  togglePinChat(chat.username);
                  setIsPinPickerOpen(false);
                }}
              >
                <Avatar name={chat.displayName || chat.username} avatarUrl={chat.avatarId} isGroup={chat.isGroup} size="sm" />
                <span>{chat.isSelf ? 'Saved Messages' : chat.displayName || chat.username}</span>
              </button>
            ))}
          </div>,
          document.body
        )}
      </section>

      {/* LOWER 2-COLUMN GRID */}
      <div className="calls-workspace-grid">
        {/* LEFT COLUMN: MISSED CALLS + REPLY TO */}
        <div className="calls-workspace-column calls-left-column">
          {/* MISSED CALLS CARD */}
          <section className="calls-workspace-card calls-missed-card">
            <header className="calls-missed-header">
              <h2 className="calls-missed-title">MISSED CALLS</h2>
              <div className="calls-missed-header-right">
                {activeMissedItems.length > 0 && (
                  <button
                    type="button"
                    className="calls-missed-clear-btn"
                    onClick={handleDismissAllMissed}
                  >
                    Clear all
                  </button>
                )}
                {totalMissedCount > 0 && (
                  <span className="calls-missed-badge">{totalMissedCount}</span>
                )}
              </div>
            </header>

            {activeMissedItems.length > 0 ? (
              <>
                <div className="calls-missed-list">
                  {displayedMissed.map(item => (
                    <article className="calls-missed-row" key={item.id}>
                      <div className="calls-missed-avatar">
                        <Avatar
                          name={item.displayName || item.partner}
                          avatarUrl={item.avatarId}
                          size="sm"
                          hidePresence
                        />
                      </div>
                      <div className="calls-missed-info">
                        <strong>{item.displayName || item.partner}</strong>
                        <small>
                          {item.missedCount > 1 ? `${item.missedCount} missed · ` : ''}
                          {item.isVideo ? 'Video' : 'Audio'} · {item.timeLabel}
                        </small>
                      </div>
                      <div className="calls-missed-actions">
                        <button
                          type="button"
                          className="calls-btn-callback"
                          aria-label={`Call back ${item.displayName || item.partner}`}
                          onClick={() => call(item.partner, item.isVideo)}
                        >
                          <Phone size={13} />
                          <span>Call back</span>
                        </button>
                        <button
                          type="button"
                          className="calls-btn-dismiss"
                          aria-label={`Dismiss missed call from ${item.displayName || item.partner}`}
                          title="Dismiss"
                          onClick={() => handleDismissMissed(item.partner)}
                        >
                          <X size={14} />
                        </button>
                      </div>
                    </article>
                  ))}
                </div>

                {activeMissedItems.length > 2 && (
                  <button
                    type="button"
                    className="calls-missed-expand-btn"
                    onClick={() => setShowAllMissed(prev => !prev)}
                  >
                    {showAllMissed
                      ? 'Show fewer missed calls'
                      : `+ ${remainingMissedCount} more · See all missed calls`}
                  </button>
                )}
              </>
            ) : (
              <div className="calls-missed-empty">
                <div className="calls-missed-empty-icon">
                  <Check size={18} />
                </div>
                <div className="calls-missed-empty-text">
                  <strong>All caught up</strong>
                  <small>No unread missed calls</small>
                </div>
              </div>
            )}
          </section>

          {/* REPLY TO CARD */}
          <section className="calls-workspace-card calls-reply-card">
            <header className="calls-reply-header">
              <h2 className="calls-reply-title">REPLY TO</h2>
              {replyTargets.length > 0 && (
                <div className="calls-reply-header-right">
                  <button
                    type="button"
                    className="calls-reply-clear-btn"
                    onClick={handleDismissAllReplyTargets}
                  >
                    Clear all
                  </button>
                  <span className="calls-reply-badge">{replyTargets.length}</span>
                </div>
              )}
            </header>

            {replyTargets.length > 0 ? (
              <>
                <div className="calls-reply-chips-wrap">
                  <div className="calls-reply-chips">
                    {replyTargets.map(target => {
                      const isActive = target.username.toLowerCase() === selectedTarget?.username.toLowerCase();
                      return (
                        <div
                          key={target.username}
                          className={`calls-reply-chip ${isActive ? 'is-active' : ''}`}
                        >
                          <button
                            type="button"
                            className="calls-reply-chip-btn"
                            onClick={() => setSelectedReplyUser(target.username)}
                          >
                            <Avatar
                              name={target.displayName || target.username}
                              avatarUrl={target.avatarId}
                              size="sm"
                              hidePresence
                            />
                            <span className="calls-reply-chip-name">{target.displayName || target.username}</span>
                            {target.count > 0 && (
                              <span className="calls-reply-count-badge">{target.count}</span>
                            )}
                          </button>
                          <button
                            type="button"
                            className="calls-reply-chip-dismiss"
                            aria-label={`Dismiss ${target.displayName || target.username}`}
                            title="Dismiss"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleDismissReplyTarget(target.username);
                            }}
                          >
                            <X size={12} />
                          </button>
                        </div>
                      );
                    })}
                  </div>
                </div>

                <div className="calls-canned-replies">
                  {['Missed your call', 'Call you back', 'Text me'].map(text => (
                    <button
                      type="button"
                      key={text}
                      className="calls-canned-btn"
                      onClick={() => handleCannedReply(text)}
                    >
                      {text}
                    </button>
                  ))}
                </div>

                <form className="calls-reply-form" onSubmit={handleSendReply}>
                  <div className="calls-reply-input-wrap">
                    <input
                      ref={replyInputRef}
                      type="text"
                      className="calls-reply-input"
                      placeholder={`Write a reply to ${selectedTarget?.displayName || selectedTarget?.username || 'contact'}...`}
                      value={replyText}
                      onChange={e => setReplyText(e.target.value)}
                    />
                    <button
                      type="submit"
                      className="calls-reply-send-btn"
                      aria-label="Send reply"
                      disabled={!replyText.trim()}
                    >
                      {replySentSuccess ? <Check size={18} /> : <Send size={18} />}
                    </button>
                  </div>
                </form>
              </>
            ) : (
              <div className="calls-reply-empty">
                <div className="calls-reply-empty-icon">
                  <Check size={18} />
                </div>
                <div className="calls-reply-empty-text">
                  <strong>All caught up</strong>
                  <small>No pending replies to send</small>
                </div>
              </div>
            )}
          </section>
        </div>

        {/* RIGHT COLUMN: CALL PRIVACY */}
        <div className="calls-workspace-column calls-right-column">
          <section className="calls-workspace-card calls-privacy-card">
            <header className="calls-privacy-header">
              <h2 className="calls-privacy-title">CALL PRIVACY</h2>
            </header>

            {/* WHO CAN CALL ME */}
            <div className="calls-privacy-section">
              <h3 className="calls-privacy-subtitle">Who can call me</h3>
              <div className="calls-privacy-segmented" role="tablist">
                <button
                  type="button"
                  role="tab"
                  aria-selected={currentCallPrivacy === 'everyone'}
                  className={`calls-segmented-btn ${currentCallPrivacy === 'everyone' ? 'is-active' : ''}`}
                  onClick={() => void handleCallPrivacyChange('everyone')}
                >
                  Everyone
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={currentCallPrivacy === 'friends'}
                  className={`calls-segmented-btn ${currentCallPrivacy === 'friends' ? 'is-active' : ''}`}
                  onClick={() => void handleCallPrivacyChange('friends')}
                >
                  Friends
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={currentCallPrivacy === 'nobody'}
                  className={`calls-segmented-btn ${currentCallPrivacy === 'nobody' ? 'is-active' : ''}`}
                  onClick={() => void handleCallPrivacyChange('nobody')}
                >
                  No one
                </button>
              </div>
              <p className="calls-privacy-desc">
                {currentCallPrivacy === 'everyone' && 'Anyone can call you directly, including non-contacts.'}
                {currentCallPrivacy === 'friends' && 'Only friends can call you. Calls from non-friends are declined.'}
                {currentCallPrivacy === 'nobody' && 'All incoming calls are silently declined without ringing.'}
              </p>
            </div>

            {/* AUTO-DECLINE WHEN BUSY */}
            <div className="calls-privacy-row">
              <div className="calls-privacy-row-text">
                <strong>Auto-decline when Busy</strong>
                <small>Calls are silently declined</small>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={autoDeclineBusy}
                className={`calls-toggle-switch ${autoDeclineBusy ? 'is-checked' : ''}`}
                onClick={handleAutoDeclineToggle}
              >
                <span className="calls-toggle-thumb" />
              </button>
            </div>

            {/* CALL SOUNDS */}
            <div className="calls-privacy-row">
              <div className="calls-privacy-row-text">
                <strong>Call sounds</strong>
                <small>Ringtone and outgoing ringback</small>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={callSounds}
                className={`calls-toggle-switch ${callSounds ? 'is-checked' : ''}`}
                onClick={handleCallSoundsToggle}
              >
                <span className="calls-toggle-thumb" />
              </button>
            </div>

            {/* BOTTOM CALLOUT NOTICE */}
            <div className="calls-privacy-note">
              Calls still appear on screen when sounds are off. Busy status also silences incoming calls.
            </div>
          </section>
        </div>
      </div>
    </main>
  );
};
