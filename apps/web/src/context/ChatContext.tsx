import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import { Message, MessageStatus, Conversation, FriendRequest, CallState, CallLog, GameType, GameData } from '../types';
import { connectSocket, getSocket } from '../services/socket';
import { useAuth } from './AuthContext';
import { WebRTCManager, playRingtone, playCallRing, stopRingtone, playCallEndSound } from '../services/webrtc';
import { playMessageNotification, playMessageSentSound, getSoundVolume } from '../services/audioManager';
import { triggerHaptic } from '../services/capacitor';
import { browserAlertsEnabled, messagePreviewsEnabled, callSoundEnabled } from '../services/browserPreferences';
import { setBlockedContact } from '../services/accountSettings';
import { ENCRYPTED_MESSAGE_PLACEHOLDER, readLastMessage, needsDecryption, withDecryptedText } from '../services/messagePresentation';
import {
  initE2EEIdentity,
  encryptMessageContent,
  decryptMessageContent,
  generateSafetyNumber,
  getMyPublicKeyJwk,
} from '../services/e2ee';

interface ChatContextType {
  conversations: Conversation[];
  activeChat: string | null;
  setActiveChat: (username: string | null) => void;
  messages: Message[];
  friendRequests: FriendRequest[];
  sentRequests: Set<string>;
  typingUsers: Set<string>;
  mutedUsers: Set<string>;
  blockedUsers: Set<string>;
  callState: CallState;
  callLogs: CallLog[];
  unreadMissedCallCount: number;
  markMissedCallsRead: () => void;
  clearCallLogs: () => void;
  sendMessage: (text: string, options?: { attachment?: any; replyTo?: any; isVoice?: boolean; to?: string }) => void;
  retryMessage: (id: string) => void;
  sendTyping: (isTyping: boolean) => void;
  sendFriendRequest: (username: string) => Promise<{ ok: boolean; message?: string }>;
  cancelFriendRequest: (username: string) => Promise<{ ok: boolean; message?: string }>;
  acceptFriendRequest: (from: string) => void;
  rejectFriendRequest: (from: string) => void;
  updateProfile: (payload: { displayName?: string; bio?: string; status?: string; avatarId?: string }) => void;
  unsendMessage: (messageId: string) => void;
  editMessage: (messageId: string, newText: string) => void;
  muteUser: (username: string, muted: boolean) => void;
  blockUser: (username: string, blocked: boolean) => void;
  unfriendUser: (username: string) => void;
  clearChat: (username: string) => void;
  addReaction: (messageId: string, emoji: string) => void;
  pinMessage: (messageId: string) => void;
  unpinMessage: (messageId: string) => void;
  createPoll: (question: string, options: string[]) => void;
  votePoll: (messageId: string, optionId: string) => void;
  sendGameChallenge: (gameType: GameType, recipient?: string) => void;
  makeGameMove: (messageId: string, moveData: any) => void;
  createGroup: (name: string, members: string[]) => void;
  addGroupMembers: (groupId: string, members: string[]) => void;
  removeGroupMember: (groupId: string, username: string) => void;
  leaveGroup: (groupId: string) => void;
  chatWallpaper: string;
  setChatWallpaper: (to: string, wallpaper: string) => void;
  pinnedChats: Set<string>;
  archivedChats: Set<string>;
  favouriteChats: Set<string>;
  manualUnreadChats: Set<string>;
  togglePinChat: (username: string) => void;
  reorderPinnedChats: (username: string, beforeUsername: string) => void;
  toggleArchiveChat: (username: string) => void;
  toggleFavouriteChat: (username: string) => void;
  markChatUnread: (username: string, unread?: boolean) => void;
  startCall: (remoteUser: string, isVideo?: boolean) => Promise<void>;
  answerCall: () => Promise<void>;
  endCall: (reason?: string) => void;
  toggleMute: () => void;
  toggleCamera: () => void;
  toggleScreenShare: () => Promise<void>;
  myPublicKey: string;
  getSafetyNumber: (peerUsername: string) => Promise<string>;
}

const ChatContext = createContext<ChatContextType | null>(null);

export const ChatProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, setUser } = useAuth();
  const presenceModeRef = useRef(user?.presenceMode || 'online');
  presenceModeRef.current = user?.presenceMode || 'online';
  useEffect(() => { if (user?.presenceMode === 'busy') stopRingtone(); }, [user?.presenceMode]);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeChat, setActiveChat] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatWallpaper, setChatWallpaperState] = useState<string>('var(--bg-canvas)');
  const [friendRequests, setFriendRequests] = useState<FriendRequest[]>([]);
  const [sentRequests, setSentRequests] = useState<Set<string>>(new Set());
  const [typingUsers, setTypingUsers] = useState<Set<string>>(new Set());
  const [mutedUsers, setMutedUsers] = useState<Set<string>>(new Set());
  const [blockedUsers, setBlockedUsers] = useState<Set<string>>(new Set());
  const [callLogs, setCallLogs] = useState<CallLog[]>([]);
  const [readMissedCallIds, setReadMissedCallIds] = useState<Set<string>>(new Set());
  const callLogsRef = useRef(callLogs);
  callLogsRef.current = callLogs;

  const [pinnedChats, setPinnedChats] = useState<Set<string>>(new Set());
  const [archivedChats, setArchivedChats] = useState<Set<string>>(new Set());
  const [favouriteChats, setFavouriteChats] = useState<Set<string>>(new Set());
  const [manualUnreadChats, setManualUnreadChats] = useState<Set<string>>(new Set());

  // Load chat preferences from localStorage
  useEffect(() => {
    if (!user?.username) return;
    try {
      const p = localStorage.getItem(`novyn_pinned_${user.username}`);
      if (p) setPinnedChats(new Set(JSON.parse(p)));
      const a = localStorage.getItem(`novyn_archived_${user.username}`);
      if (a) setArchivedChats(new Set(JSON.parse(a)));
      const f = localStorage.getItem(`novyn_fav_${user.username}`);
      if (f) setFavouriteChats(new Set(JSON.parse(f)));
      const u = localStorage.getItem(`novyn_unread_${user.username}`);
      if (u) setManualUnreadChats(new Set(JSON.parse(u)));
      const missedRead = localStorage.getItem(`novyn_missed_read_${user.username}`);
      setReadMissedCallIds(new Set(missedRead ? JSON.parse(missedRead) : []));
    } catch {}
  }, [user?.username]);

  const unreadMissedCallCount = callLogs.filter(log => log.type === 'missed' && !readMissedCallIds.has(log.id)).length;
  const markMissedCallsRead = useCallback(() => {
    const missedIds = callLogsRef.current.filter(log => log.type === 'missed').map(log => log.id);
    if (!missedIds.length) return;
    setReadMissedCallIds(previous => {
      const next = new Set(previous);
      missedIds.forEach(id => next.add(id));
      if (user?.username) localStorage.setItem(`novyn_missed_read_${user.username}`, JSON.stringify([...next]));
      return next;
    });
  }, [user?.username]);

  const togglePinChat = useCallback((username: string) => {
    setPinnedChats((prev) => {
      const next = new Set(prev);
      const key = username.toLowerCase();
      if (next.has(key)) next.delete(key);
      else next.add(key);
      if (user?.username) {
        localStorage.setItem(`novyn_pinned_${user.username}`, JSON.stringify(Array.from(next)));
      }
      return next;
    });
    triggerHaptic('light');
  }, [user?.username]);

  const reorderPinnedChats = useCallback((username: string, beforeUsername: string) => {
    setPinnedChats((prev) => {
      const ordered = Array.from(prev);
      const fromIndex = ordered.indexOf(username.toLowerCase());
      const toIndex = ordered.indexOf(beforeUsername.toLowerCase());
      if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return prev;
      const [moved] = ordered.splice(fromIndex, 1);
      ordered.splice(toIndex > fromIndex ? toIndex - 1 : toIndex, 0, moved);
      const next = new Set(ordered);
      if (user?.username) localStorage.setItem(`novyn_pinned_${user.username}`, JSON.stringify(ordered));
      return next;
    });
    triggerHaptic('light');
  }, [user?.username]);

  const toggleArchiveChat = useCallback((username: string) => {
    setArchivedChats((prev) => {
      const next = new Set(prev);
      const key = username.toLowerCase();
      if (next.has(key)) next.delete(key);
      else next.add(key);
      if (user?.username) {
        localStorage.setItem(`novyn_archived_${user.username}`, JSON.stringify(Array.from(next)));
      }
      return next;
    });
    triggerHaptic('medium');
  }, [user?.username]);

  const toggleFavouriteChat = useCallback((username: string) => {
    setFavouriteChats((prev) => {
      const next = new Set(prev);
      const key = username.toLowerCase();
      if (next.has(key)) next.delete(key);
      else next.add(key);
      if (user?.username) {
        localStorage.setItem(`novyn_fav_${user.username}`, JSON.stringify(Array.from(next)));
      }
      return next;
    });
    triggerHaptic('light');
  }, [user?.username]);

  const markChatUnread = useCallback((username: string, unread?: boolean) => {
    setManualUnreadChats((prev) => {
      const next = new Set(prev);
      const key = username.toLowerCase();
      const shouldUnread = unread !== undefined ? unread : !next.has(key);
      if (shouldUnread) next.add(key);
      else next.delete(key);
      if (user?.username) {
        localStorage.setItem(`novyn_unread_${user.username}`, JSON.stringify(Array.from(next)));
      }
      return next;
    });
    triggerHaptic('light');
  }, [user?.username]);

  const [callState, setCallState] = useState<CallState>({
    callId: '',
    isActive: false,
    status: 'idle',
    remoteUser: '',
    isVideo: false,
    isMuted: false,
    isCameraOff: false,
    isScreenSharing: false,
    remoteIsScreenSharing: false,
    isIncoming: false,
    localStream: null,
    remoteStream: null,
  });

  const activeChatRef = useRef<string | null>(null);
  activeChatRef.current = activeChat;

  const messagesCacheRef = useRef<Record<string, Message[]>>({});
  const pendingSendsRef = useRef(new Map<string, { text: string; options: any; to: string; sender: string }>());
  useEffect(() => { pendingSendsRef.current.clear(); }, [user?.username]);

  const conversationsRef = useRef<Conversation[]>(conversations);
  conversationsRef.current = conversations;

  const webrtcManagerRef = useRef<WebRTCManager | null>(null);
  const callStateRef = useRef<CallState>(callState);
  callStateRef.current = callState;

  const callTimeoutTimerRef = useRef<any>(null);
  const callStartTimeRef = useRef<number | null>(null);

  const [myPublicKey, setMyPublicKey] = useState<string>('');
  const myPublicKeyRef = useRef<string>('');
  myPublicKeyRef.current = myPublicKey;

  // Initialize E2EE Identity Key on client device
  useEffect(() => {
    if (!user?.username) return;
    initE2EEIdentity(user.username).then((pubKey) => {
      if (pubKey) {
        setMyPublicKey(pubKey);
        myPublicKeyRef.current = pubKey;
        const socket = getSocket();
        if (socket) {
          socket.emit('register_public_key', { publicKey: pubKey });
        }
      }
    });
  }, [user?.username]);

  // Decrypt both open-chat messages and unopened conversation previews. Waiting
  // for identity/key readiness also handles history arriving before local keys.
  useEffect(() => {
    if (!user || !myPublicKey) return;
    let cancelled = false;
    const jobs = new Map<string, { partner: string; message: Message; publicKey: string }>();
    const queue = (conversation: Conversation, message?: Message) => {
      if (conversation.isGroup || !conversation.publicKey || !needsDecryption(message)) return;
      const partner = conversation.username.toLowerCase();
      jobs.set(JSON.stringify([partner, message.id, message.ciphertext, message.iv]), {
        partner, message, publicKey: conversation.publicKey,
      });
    };
    conversations.forEach((conversation) => queue(conversation, conversation.lastMessage));
    const active = conversations.find((c) => c.username.toLowerCase() === activeChat?.toLowerCase());
    if (active) messages.forEach((message) => queue(active, message));
    if (!jobs.size) return;

    void Promise.all([...jobs.values()].map(async (job) => {
      const text = await decryptMessageContent(job.message.ciphertext!, job.message.iv!, job.partner, job.publicKey);
      return text === null ? null : { partner: job.partner, message: { ...job.message, text } };
    })).then((results) => {
      if (cancelled) return;
      const decrypted = results.filter((result) => result !== null);
      if (!decrypted.length) return;
      const update = (message: Message, partner: string) => decrypted.reduce(
        (current, result) => result.partner === partner ? withDecryptedText(current, result.message) : current,
        message
      );
      const updateList = (list: Message[], partner: string) => {
        const next = list.map((message) => update(message, partner));
        return next.some((message, index) => message !== list[index]) ? next : list;
      };
      for (const partner of new Set(decrypted.map((result) => result.partner))) {
        const cached = messagesCacheRef.current[partner];
        if (cached) messagesCacheRef.current[partner] = updateList(cached, partner);
      }
      if (activeChat) setMessages((previous) => updateList(previous, activeChat.toLowerCase()));
      setConversations((previous) => {
        const next = previous.map((conversation) => {
          if (!conversation.lastMessage) return conversation;
          const lastMessage = update(conversation.lastMessage, conversation.username.toLowerCase());
          return lastMessage === conversation.lastMessage ? conversation : { ...conversation, lastMessage };
        });
        return next.some((conversation, index) => conversation !== previous[index]) ? next : previous;
      });
    });
    return () => { cancelled = true; };
  }, [conversations, messages, activeChat, myPublicKey, user?.username]);

  const getSafetyNumber = useCallback(async (peerUsername: string): Promise<string> => {
    const peerConv = conversationsRef.current.find(
      (c) => c.username.toLowerCase() === peerUsername.toLowerCase()
    );
    const myPub = myPublicKeyRef.current;
    const peerPub = peerConv?.publicKey || '';
    if (!myPub || !peerPub) {
      return '01948 29384 10293 84726 19283 74625 10293 84726 19283 74625 10293 84726';
    }
    return generateSafetyNumber(myPub, peerPub);
  }, []);

  // Load call logs from localStorage
  useEffect(() => {
    if (!user?.username) return;
    try {
      const saved = localStorage.getItem(`novyn_call_logs_${user.username}`);
      if (saved) {
        setCallLogs(JSON.parse(saved));
      }
    } catch {}
  }, [user?.username]);

  // Save call logs to localStorage
  const saveCallLog = useCallback(
    (log: CallLog) => {
      setCallLogs((prev) => {
        const next = [log, ...prev].slice(0, 100);
        if (user?.username) {
          localStorage.setItem(`novyn_call_logs_${user.username}`, JSON.stringify(next));
        }
        return next;
      });
    },
    [user?.username]
  );

  const clearCallLogs = useCallback(() => {
    setCallLogs([]);
    if (user?.username) {
      localStorage.removeItem(`novyn_call_logs_${user.username}`);
    }
  }, [user?.username]);

  // Initialize WebRTC Manager
  useEffect(() => {
    const handleRemoteStream = (stream: MediaStream) => {
      setCallState((prev) => ({ ...prev, remoteStream: stream, status: 'connected' }));
      stopRingtone();
      if (callTimeoutTimerRef.current) {
        clearTimeout(callTimeoutTimerRef.current);
        callTimeoutTimerRef.current = null;
      }
      callStartTimeRef.current = Date.now();
    };

    const handleLocalStream = (stream: MediaStream) => {
      setCallState((prev) => ({ ...prev, localStream: stream }));
    };

    const handleScreenShareEnded = () => {
      setCallState((prev) => ({ ...prev, isScreenSharing: false }));
      const socket = getSocket();
      const current = callStateRef.current;
      if (socket && current.remoteUser && current.callId) {
        socket.emit('webrtc_signal', {
          to: current.remoteUser,
          callId: current.callId,
          signal: { type: 'screen_share_state', isSharing: false },
        });
      }
    };

    const handleSignal = (signal: any) => {
      const socket = getSocket();
      const current = callStateRef.current;
      if (socket && current.remoteUser && current.callId) {
        socket.emit('webrtc_signal', { to: current.remoteUser, callId: current.callId, signal });
      }
    };

    const manager = new WebRTCManager(
      handleRemoteStream,
      handleSignal,
      handleLocalStream,
      handleScreenShareEnded
    );
    webrtcManagerRef.current = manager;
    // Fetch TURN credentials as soon as an authenticated chat session is available.
    void manager.ensureIceServers();

    return () => {
      webrtcManagerRef.current?.cleanup();
      stopRingtone();
      if (callTimeoutTimerRef.current) clearTimeout(callTimeoutTimerRef.current);
    };
  }, []);

  // Sync active chat history & mark read (Instant 0ms cached display + background sync)
  useEffect(() => {
    if (!activeChat || !user) {
      setMessages([]);
      return;
    }

    const key = activeChat.toLowerCase();
    const activeConversation = conversationsRef.current.find((conversation) => conversation.username.toLowerCase() === key);

    // Saved Messages is a private, device-local notebook. It deliberately avoids
    // friend authorization, networking and peer encryption requirements.
    if (activeConversation?.isSelf) {
      try {
        const stored = JSON.parse(localStorage.getItem(`novyn_saved_messages_${user.username.toLowerCase()}`) || '[]');
        const savedMessages = Array.isArray(stored) ? stored : [];
        messagesCacheRef.current[key] = savedMessages;
        setMessages(savedMessages);
        setConversations((prev) => prev.map((conversation) =>
          conversation.isSelf ? { ...conversation, lastMessage: savedMessages[savedMessages.length - 1] } : conversation
        ));
      } catch {
        messagesCacheRef.current[key] = [];
        setMessages([]);
      }
      return;
    }

    // 1. Instant 0ms cache display
    const cached = messagesCacheRef.current[key];
    if (cached) {
      setMessages(cached);
    } else {
      setMessages([]);
    }

    const socket = getSocket();
    if (!socket) return;

    // 2. Fetch latest history in background
    socket.emit('set_active_chat', { to: activeChat, kind: 'friend' });
    socket.emit('get_history', { to: activeChat, kind: 'friend' });

    setConversations((prev) =>
      prev.map((c) => (c.username.toLowerCase() === key ? { ...c, unreadCount: 0 } : c))
    );
  }, [activeChat, user]);

  // Auto-Away & Background Tab Visibility Presence Sync
  useEffect(() => {
    if (!user) return;
    const socket = connectSocket();
    if (!socket) return;

    let awayTimer: any = null;
    let isAway = false;

    const setAway = () => {
      if (!isAway) {
        isAway = true;
        socket.emit('set_presence_mode', { mode: 'away' });
      }
    };

    const setOnline = () => {
      if (awayTimer) clearTimeout(awayTimer);
      if (isAway) {
        isAway = false;
        socket.emit('set_presence_mode', { mode: 'online' });
      }
      // Trigger away after 3 minutes of inactivity
      awayTimer = setTimeout(setAway, 180000);
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        // Tab went to background: mark away after 45s
        if (awayTimer) clearTimeout(awayTimer);
        awayTimer = setTimeout(setAway, 45000);
      } else {
        // Tab returned to active foreground: immediately restore online and sync active chat
        setOnline();
        if (activeChatRef.current) {
          socket.emit('set_active_chat', { to: activeChatRef.current, kind: 'friend' });
          socket.emit('get_history', { to: activeChatRef.current, kind: 'friend' });
        }
      }
    };

    const handleWindowFocus = () => {
      setOnline();
      if (activeChatRef.current) {
        socket.emit('set_active_chat', { to: activeChatRef.current, kind: 'friend' });
        socket.emit('get_history', { to: activeChatRef.current, kind: 'friend' });
      }
    };

    const handleUserActivity = () => {
      if (document.visibilityState === 'visible') {
        setOnline();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('focus', handleWindowFocus);
    window.addEventListener('mousemove', handleUserActivity);
    window.addEventListener('keydown', handleUserActivity);
    window.addEventListener('touchstart', handleUserActivity);

    // Initial activity timer
    awayTimer = setTimeout(setAway, 180000);

    return () => {
      if (awayTimer) clearTimeout(awayTimer);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('focus', handleWindowFocus);
      window.removeEventListener('mousemove', handleUserActivity);
      window.removeEventListener('keydown', handleUserActivity);
      window.removeEventListener('touchstart', handleUserActivity);
    };
  }, [user]);

  // End Call Helper
  const endCall = useCallback(
    (reason?: string, notifyPeer = true) => {
      const socket = getSocket();
      stopRingtone();
      playCallEndSound();

      if (callTimeoutTimerRef.current) {
        clearTimeout(callTimeoutTimerRef.current);
        callTimeoutTimerRef.current = null;
      }

      const current = callStateRef.current;
      if (notifyPeer && socket && current.remoteUser && current.callId) {
        socket.emit('call_end', { to: current.remoteUser, callId: current.callId, reason });
      }

      webrtcManagerRef.current?.cleanup();

      // Log Call History Record
      if (current.remoteUser) {
        const duration = callStartTimeRef.current ? Math.round((Date.now() - callStartTimeRef.current) / 1000) : 0;
        const type =
          current.status === 'connected'
            ? current.isIncoming
              ? 'incoming'
              : 'outgoing'
            : current.isIncoming
            ? 'missed'
            : 'outgoing';

        saveCallLog({
          id: `call_${Date.now()}`,
          partner: current.remoteUser,
          partnerDisplayName: current.remoteDisplayName || current.remoteUser,
          type,
          isVideo: current.isVideo,
          timestamp: new Date().toISOString(),
          duration: current.status === 'connected' ? duration : undefined,
        });
      }

      callStartTimeRef.current = null;

      setCallState({
        callId: '',
        isActive: false,
        status: 'ended',
        remoteUser: '',
        isVideo: false,
        isMuted: false,
        isCameraOff: false,
        isScreenSharing: false,
        remoteIsScreenSharing: false,
        isIncoming: false,
        localStream: null,
        remoteStream: null,
      });
      triggerHaptic('medium');
    },
    [saveCallLog]
  );

  // Main Socket Listener Setup
  useEffect(() => {
    if (!user) return;
    const socket = getSocket();
    if (!socket) return;

    // Friend & Group list sync
    const handleFriendList = (data: any) => {
      const list = Array.isArray(data) ? data : data?.friends || [];
      const formatted: Conversation[] = list.map((item: any) => ({
        username: item.username || item.groupId || item.key,
        displayName: item.displayName || item.name || item.username || item.key,
        avatarId: item.avatarId,
        online: Boolean(item.online && item.presence !== 'offline'),
        presence: item.presence || (item.online ? 'online' : 'offline'),
        lastSeenAt: item.lastSeenAt,
        publicKey: item.publicKey || undefined,
        unreadCount: item.unreadCount || 0,
        isGroup: item.kind === 'group' || Boolean(item.groupId) || Boolean(item.memberCount && item.memberCount > 2),
        groupId: item.groupId || (item.kind === 'group' ? item.username : undefined),
        memberCount: item.memberCount || 2,
        owner: item.owner,
        members: item.members,
        lastMessage: readLastMessage(item, user.username),
      }));
      const savedMessages: Conversation = {
        username: user.username,
        displayName: 'Saved Messages',
        avatarId: user.avatarId,
        online: true,
        presence: 'online',
        unreadCount: 0,
        isSelf: true,
      };
      try {
        const stored = JSON.parse(localStorage.getItem(`novyn_saved_messages_${user.username.toLowerCase()}`) || '[]');
        if (Array.isArray(stored) && stored.length) savedMessages.lastMessage = stored[stored.length - 1];
      } catch {
        // An invalid local note cache should never prevent the chat list loading.
      }
      const withSavedMessages = [
        savedMessages,
        ...formatted.filter((conversation) => conversation.username.toLowerCase() !== user.username.toLowerCase()),
      ];
      setConversations((previous) => withSavedMessages.map((conversation) => {
        const cached = previous.find((c) => c.username.toLowerCase() === conversation.username.toLowerCase())?.lastMessage;
        if (conversation.isSelf) {
          return cached ? { ...conversation, lastMessage: cached } : conversation;
        }
        return conversation.lastMessage && cached
          ? { ...conversation, lastMessage: withDecryptedText(conversation.lastMessage, cached) }
          : conversation;
      }));
    };

    socket.on('peer_public_key_updated', ({ username, publicKey }: { username: string; publicKey: string }) => {
      setConversations((prev) =>
        prev.map((c) => (c.username.toLowerCase() === username.toLowerCase() ? { ...c, publicKey } : c))
      );
    });

    socket.on('group_created', ({ group }: any) => {
      triggerHaptic('success');
      if (group?.id) {
        setActiveChat(group.id);
      }
    });

    const handleRequests = (data: any) => {
      const list = Array.isArray(data) ? data : data?.requests || [];
      const formatted: FriendRequest[] = list.map((req: any) => ({
        from: typeof req === 'string' ? req : req.from || req.username,
        timestamp: req.timestamp || new Date().toISOString(),
        displayName: typeof req === 'object' ? req.displayName : req,
      }));
      setFriendRequests(formatted);
    };

    const handleSession = (data: any) => {
      if (data?.friends) handleFriendList(data.friends);
      if (data?.requests) handleRequests(data.requests);
      if (Array.isArray(data?.sentRequests)) setSentRequests(new Set(data.sentRequests.map((name: string) => name.toLowerCase())));
      if (Array.isArray(data?.safety?.blocked)) setBlockedUsers(new Set(data.safety.blocked.map((name: string) => name.toLowerCase())));
      if (Array.isArray(data?.safety?.muted)) setMutedUsers(new Set(data.safety.muted.map((name: string) => name.toLowerCase())));
    };
    socket.on('safety_state_updated', (safety: any) => {
      if (Array.isArray(safety?.blocked)) setBlockedUsers(new Set(safety.blocked.map((name: string) => name.toLowerCase())));
      if (Array.isArray(safety?.muted)) setMutedUsers(new Set(safety.muted.map((name: string) => name.toLowerCase())));
    });
    const resumeSession = () => socket.emit('resume_session');
    socket.on('init', handleSession);
    socket.on('register_success', handleSession);
    socket.on('connect', resumeSession);
    if (socket.connected) resumeSession();

    socket.on('friend_list', handleFriendList);
    socket.on('friend_list_updated', handleFriendList);
    socket.on('requests_updated', handleRequests);

    // Profile updates
    socket.on('user_profile_updated', (profile: any) => {
      setConversations((prev) =>
        prev.map((c) =>
          c.username.toLowerCase() === profile.username?.toLowerCase()
            ? {
                ...c,
                displayName: profile.displayName || c.displayName,
                avatarId: profile.avatarId || c.avatarId,
                online: profile.presenceMode ? !['offline', 'invisible'].includes(profile.presenceMode) : c.online,
                presence: profile.presenceMode || c.presence,
              }
            : c
        )
      );
    });

    socket.on('profile_updated', (profile: any) => {
      if (setUser) {
        setUser((prev: any) => (prev ? { ...prev, ...profile } : prev));
      }
    });

    socket.on('message_unsent', ({ messageId }: { messageId: string }) => {
      setMessages((prev) => prev.filter((m) => m.id !== messageId));
      triggerHaptic('light');
    });

    socket.on('message_edited', ({ messageId, text }: { messageId: string; text: string }) => {
      setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text } : m)));
      triggerHaptic('light');
    });

    socket.on('reaction_updated', ({ messageId, reactions }: { messageId: string; reactions: any }) => {
      setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, reactions } : m)));
    });

    socket.on('message_pinned', ({ messageId, pinnedAt, pinnedBy }: any) => {
      setMessages((prev) =>
        prev.map((m) => (m.id === messageId ? { ...m, pinnedAt, pinnedBy } : m))
      );
      triggerHaptic('light');
    });

    socket.on('message_unpinned', ({ messageId }: any) => {
      setMessages((prev) =>
        prev.map((m) => (m.id === messageId ? { ...m, pinnedAt: null, pinnedBy: '' } : m))
      );
      triggerHaptic('light');
    });

    socket.on('poll_updated', ({ messageId, poll }: any) => {
      setMessages((prev) =>
        prev.map((m) => (m.id === messageId || m.poll?.id === poll.id ? { ...m, poll } : m))
      );
      triggerHaptic('light');
    });

    socket.on('game_move_updated', ({ messageId, moveData, updatedBy }: any) => {
      setMessages((prev) =>
        prev.map((m) => {
          if (m.id === messageId && m.game) {
            const updatedGame: GameData = {
              ...m.game,
              state: moveData.state || m.game.state,
              turn: moveData.turn !== undefined ? moveData.turn : m.game.turn,
              winner: moveData.winner !== undefined ? moveData.winner : m.game.winner,
              data: {
                ...m.game.data,
                ...moveData,
              },
              lastMoveBy: updatedBy,
              updatedAt: Date.now(),
            };
            return { ...m, game: updatedGame };
          }
          return m;
        })
      );
      if (updatedBy?.toLowerCase() !== user?.username.toLowerCase() && presenceModeRef.current !== 'busy') {
        playMessageNotification();
        triggerHaptic('light');
      }
    });

    socket.on('chat_wallpaper_updated', ({ to, from, wallpaper }: any) => {
      const currentActive = activeChatRef.current?.toLowerCase();
      const fromUser = (from || '').toLowerCase();
      const toUser = (to || '').toLowerCase();
      const wp = wallpaper || 'var(--bg-canvas)';

      if (wallpaper && wallpaper.trim() !== '') {
        if (fromUser) localStorage.setItem(`novyn_chat_wallpaper_${fromUser}`, wp);
        if (toUser) localStorage.setItem(`novyn_chat_wallpaper_${toUser}`, wp);
      }

      if (currentActive && (currentActive === fromUser || currentActive === toUser)) {
        if (wallpaper && wallpaper.trim() !== '') {
          setChatWallpaperState(wp);
        }
      }
    });

    socket.on('friend_request_received', ({ from }: { from: string }) => {
      triggerHaptic('success');
      setFriendRequests((prev) => {
        if (prev.some((r) => r.from.toLowerCase() === from.toLowerCase())) return prev;
        return [{ from, timestamp: new Date().toISOString(), displayName: from }, ...prev];
      });
    });

    socket.on('friend_request_sent', ({ to }: { to: string }) => {
      setSentRequests((prev) => new Set(prev).add(to.toLowerCase()));
    });

    socket.on('friend_request_cancelled', ({ to }: { to: string }) => {
      setSentRequests((prev) => {
        const next = new Set(prev);
        next.delete(to.toLowerCase());
        return next;
      });
    });

    socket.on('friend_request_accepted', ({ by }: { by: string }) => {
      setSentRequests((prev) => {
        const next = new Set(prev);
        next.delete(by.toLowerCase());
        return next;
      });
      socket.emit('resume_session');
    });

    socket.on('profile_updated', (updated: any) => {
      if (setUser && updated) {
        setUser((prev) => (prev ? {
          ...prev,
          username: updated.username || prev.username,
          displayName: updated.displayName || prev.displayName,
          bio: updated.bio !== undefined ? updated.bio : prev.bio,
          avatarId: updated.avatarId !== undefined ? updated.avatarId : prev.avatarId,
          presenceMode: updated.presenceMode || prev.presenceMode,
        } : prev));
      }
      if (activeChatRef.current) {
        socket.emit('get_history', { to: activeChatRef.current, kind: 'friend' });
      }
    });

    socket.on('friend_removed', ({ username }: { username: string }) => {
      setConversations((prev) => prev.filter((c) => c.username.toLowerCase() !== username.toLowerCase()));
      if (activeChatRef.current?.toLowerCase() === username.toLowerCase()) {
        setActiveChat(null);
      }
    });

    socket.on('chat_cleared', ({ with: target }: { with: string }) => {
      if (activeChatRef.current?.toLowerCase() === target.toLowerCase()) {
        setMessages([]);
      }
    });

    socket.on('mute_updated', ({ username, muted }: { username: string; muted: boolean }) => {
      setMutedUsers((prev) => {
        const next = new Set(prev);
        if (muted) next.add(username.toLowerCase());
        else next.delete(username.toLowerCase());
        return next;
      });
    });

    socket.on('block_updated', ({ username, blocked }: { username: string; blocked: boolean }) => {
      setBlockedUsers((prev) => {
        const next = new Set(prev);
        if (blocked) next.add(username.toLowerCase());
        else next.delete(username.toLowerCase());
        return next;
      });
    });

    // Chat History Sync
    const handleHistory = (data: any) => {
      const target = data?.with || data?.withUser || data?.to;
      const historyList = data?.messages || [];
      if (activeChatRef.current && target && activeChatRef.current.toLowerCase() === target.toLowerCase()) {
        if (data?.wallpaper && data.wallpaper.trim() !== '') {
          setChatWallpaperState(data.wallpaper);
          localStorage.setItem(`novyn_chat_wallpaper_${target.toLowerCase()}`, data.wallpaper);
        } else {
          const localCached = localStorage.getItem(`novyn_chat_wallpaper_${target.toLowerCase()}`);
          if (localCached && localCached !== 'var(--bg-canvas)') {
            setChatWallpaperState(localCached);
            const socket = getSocket();
            if (socket) {
              socket.emit('set_chat_wallpaper', { to: target, wallpaper: localCached });
            }
          } else {
            setChatWallpaperState('var(--bg-canvas)');
          }
        }
        const formattedList: Message[] = historyList.map((m: any) => ({
          id: m.id || m.messageId || String(m.timestamp),
          sender: m.from || m.sender || m.fromKey,
          receiver: m.to || m.receiver || m.toKey,
          text: m.isEncrypted && !m.deletedAt ? ENCRYPTED_MESSAGE_PLACEHOLDER : m.text || '',
          timestamp: m.timestamp,
          status: (m.seenAt ? 'seen' : m.deliveredAt ? 'delivered' : m.status || 'sent') as MessageStatus,
          attachment: m.attachment,
          replyTo: m.replyTo,
          reactions: m.reactions || {},
          isVoice: Boolean(m.isVoice || m.attachment?.kind === 'audio'),
          pinnedAt: m.pinnedAt || null,
          pinnedBy: m.pinnedBy || '',
          poll: m.poll || null,
          game: m.game || null,
          ciphertext: !m.deletedAt ? m.ciphertext : undefined,
          iv: !m.deletedAt ? m.iv : undefined,
          isEncrypted: Boolean(m.isEncrypted && !m.deletedAt),
        }));

        const confirmedIds = new Set(historyList.map((message: any) => message.clientTempId).filter(Boolean));
        for (const id of confirmedIds) pendingSendsRef.current.delete(String(id));
        const pendingMessages = (messagesCacheRef.current[target.toLowerCase()] || []).filter((message) => pendingSendsRef.current.has(message.id));
        formattedList.push(...pendingMessages);
        messagesCacheRef.current[target.toLowerCase()] = formattedList;
        setMessages(formattedList);

      }
    };

    socket.on('history', handleHistory);

    // Message delivery & seen status updates
    socket.on('message_status', (data: any) => {
      const msgId = data?.id;
      if (!msgId) return;
      const newStatus: MessageStatus = data.seenAt ? 'seen' : data.deliveredAt ? 'delivered' : 'sent';
      setMessages((prev) => {
        const next = prev.map((m) => (m.id === msgId ? { ...m, status: newStatus } : m));
        if (activeChatRef.current) {
          messagesCacheRef.current[activeChatRef.current.toLowerCase()] = next;
        }
        return next;
      });
    });

    // Private Message Incoming
    socket.on('private_message', (rawMsg: any) => {
      const sender = rawMsg.from || rawMsg.sender || rawMsg.fromKey;
      const receiver = rawMsg.to || rawMsg.receiver || rawMsg.toKey;
      const clientTempId = rawMsg.clientTempId;
      if (sender?.toLowerCase() === user.username.toLowerCase() && clientTempId) pendingSendsRef.current.delete(clientTempId);
      const msgId = rawMsg.id || rawMsg.messageId || clientTempId || String(Date.now());
      const status: MessageStatus = rawMsg.seenAt ? 'seen' : rawMsg.deliveredAt ? 'delivered' : rawMsg.status || 'sent';

      const msg: Message = {
        id: msgId,
        sender,
        receiver,
        text: rawMsg.isEncrypted ? ENCRYPTED_MESSAGE_PLACEHOLDER : rawMsg.text || '',
        timestamp: rawMsg.timestamp || new Date().toISOString(),
        status,
        attachment: rawMsg.attachment,
        replyTo: rawMsg.replyTo,
        reactions: rawMsg.reactions || {},
        isVoice: Boolean(rawMsg.isVoice || rawMsg.attachment?.kind === 'audio'),
        pinnedAt: rawMsg.pinnedAt || null,
        pinnedBy: rawMsg.pinnedBy || '',
        poll: rawMsg.poll || null,
        game: rawMsg.game || null,
        ciphertext: rawMsg.ciphertext,
        iv: rawMsg.iv,
        isEncrypted: Boolean(rawMsg.isEncrypted),
      };

      const current = activeChatRef.current?.toLowerCase();
      const isCurrentConversation =
        current && (current === sender?.toLowerCase() || current === receiver?.toLowerCase());

      if (isCurrentConversation) {
        setMessages((prev) => {
          const existingIndex = prev.findIndex(
            (m) => (clientTempId && m.id === clientTempId) || m.id === msgId
          );
          let next: Message[];
          if (existingIndex !== -1) {
            next = [...prev];
            next[existingIndex] = msg;
          } else {
            next = [...prev, msg];
          }
          if (current) {
            messagesCacheRef.current[current] = next;
          }
          return next;
        });

      }

      setConversations((prev) => {
        const partner = sender?.toLowerCase() === user.username.toLowerCase() ? receiver : sender;
        const exists = prev.some((c) => c.username.toLowerCase() === partner?.toLowerCase());

        if (!exists && partner) {
          return [
            {
              username: partner,
              displayName: partner,
              online: true,
              unreadCount: isCurrentConversation ? 0 : 1,
              lastMessage: msg,
            },
            ...prev,
          ];
        }

        return prev.map((c) => {
          if (c.username.toLowerCase() === partner?.toLowerCase()) {
            return {
              ...c,
              lastMessage: msg,
              unreadCount: isCurrentConversation ? 0 : c.unreadCount + 1,
            };
          }
          return c;
        });
      });

      if (sender?.toLowerCase() !== user.username.toLowerCase()) {
        if (presenceModeRef.current !== 'busy') playMessageNotification();

        // Show visual desktop notification when tab is in background or another chat is active
        if (
          typeof Notification !== 'undefined' &&
          browserAlertsEnabled() &&
          Notification.permission === 'granted' &&
          (document.hidden || activeChatRef.current?.toLowerCase() !== sender?.toLowerCase())
        ) {
          try {
            const partnerConv = conversationsRef.current.find(
              (c) => c.username.toLowerCase() === sender.toLowerCase()
            );
            const senderName = partnerConv?.displayName || sender;
            const notifBody = messagePreviewsEnabled() ? msg.text || (msg.isVoice ? '🎤 Voice message' : '📎 Attachment') : 'New message';
            const notif = new Notification(senderName, {
              silent: presenceModeRef.current === 'busy' || localStorage.getItem('novyn_sound') === 'false' || getSoundVolume('message') === 0,
              body: notifBody,
              icon: '/favicon.ico',
              badge: '/favicon.ico',
              tag: `novyn-${sender}`,
            });
            notif.onclick = () => {
              window.focus();
              setActiveChat(sender);
              notif.close();
            };
          } catch (e) {
            console.warn('[Notification] Failed to show desktop notification:', e);
          }
        }
      }
      if (presenceModeRef.current !== 'busy') triggerHaptic('light');
    });

    // Typing Indicators
    socket.on('typing', ({ from, isTyping }: { from: string; isTyping: boolean }) => {
      setTypingUsers((prev) => {
        const next = new Set(prev);
        if (isTyping) next.add(from);
        else next.delete(from);
        return next;
      });
    });

    // User presence
    socket.on('user_status', ({ username, online, presence, lastSeenAt }: any) => {
      if (!online || presence === 'offline' || presence === 'invisible') {
        setTypingUsers(prev => { const next = new Set(prev); next.delete(username); return next; });
      }
      setConversations((prev) =>
        prev.map((c) =>
          c.username.toLowerCase() === username?.toLowerCase()
            ? {
                ...c,
                online: Boolean(online && presence !== 'offline' && presence !== 'invisible'),
                presence: presence || (online ? 'online' : 'offline'),
                lastSeenAt: lastSeenAt || c.lastSeenAt,
              }
            : c
        )
      );
    });

    // WebRTC Calling Signaling Listeners
    socket.on('call_incoming', ({ from, fromDisplayName, isVideo, callId }: { from: string; fromDisplayName: string; isVideo: boolean; callId?: string }) => {
      if (!callId) return;
      if (callStateRef.current.isActive) {
        socket.emit('call_end', { to: from, callId, reason: 'User is busy' });
        return;
      }
      setCallState({
        callId,
        isActive: true,
        status: 'ringing',
        remoteUser: from,
        remoteDisplayName: fromDisplayName || from,
        isVideo,
        isMuted: false,
        isCameraOff: false,
        isScreenSharing: false,
        remoteIsScreenSharing: false,
        isIncoming: true,
        localStream: null,
        remoteStream: null,
      });

      if (presenceModeRef.current !== 'busy' && callSoundEnabled()) {
        playRingtone();
        triggerHaptic('heavy');
      }

      // Auto-cut after 30 seconds if not answered
      if (callTimeoutTimerRef.current) clearTimeout(callTimeoutTimerRef.current);
      callTimeoutTimerRef.current = setTimeout(() => {
        endCall('No answer (Timed out)');
      }, 30000);
    });

    socket.on('call_accepted', async ({ callId }: { callId?: string }) => {
      if (!callId || callStateRef.current.callId !== callId) return;
      stopRingtone();
      if (callTimeoutTimerRef.current) {
        clearTimeout(callTimeoutTimerRef.current);
        callTimeoutTimerRef.current = null;
      }
      callStartTimeRef.current = Date.now();

      setCallState((prev) => ({ ...prev, status: 'connected' }));
      triggerHaptic('success');

      if (webrtcManagerRef.current) {
        try {
          const offer = await webrtcManagerRef.current.createOffer();
          socket.emit('webrtc_signal', {
            to: callStateRef.current.remoteUser,
            callId,
            signal: { type: 'offer', sdp: offer },
          });
        } catch (err) {
          console.error('Error creating WebRTC offer:', err);
        }
      }
    });

    socket.on('webrtc_signal', async ({ from, callId, signal }: { from: string; callId?: string; signal: any }) => {
      if (!webrtcManagerRef.current || !signal) return;
      if (!callId || callStateRef.current.callId !== callId) return;

      const targetUser = callStateRef.current.remoteUser || from;
      try {
        if (signal.type === 'screen_share_state') {
          setCallState((prev) => ({ ...prev, remoteIsScreenSharing: Boolean(signal.isSharing) }));
        } else if (signal.type === 'offer') {
          const answer = await webrtcManagerRef.current.handleOffer(signal.sdp);
          socket.emit('webrtc_signal', {
            to: targetUser,
            callId,
            signal: { type: 'answer', sdp: answer },
          });
        } else if (signal.type === 'answer') {
          await webrtcManagerRef.current.handleAnswer(signal.sdp);
        } else if (signal.type === 'candidate') {
          await webrtcManagerRef.current.handleCandidate(signal.candidate);
        }
      } catch (err) {
        console.error('WebRTC signal error:', err);
      }
    });

    socket.on('call_ended', ({ reason, callId }: { reason?: string; callId?: string }) => {
      if (!callId || callStateRef.current.callId !== callId) return;
      endCall(reason || 'Call ended', false);
    });

    return () => {
      socket.off('init');
      socket.off('register_success', handleSession);
      socket.off('connect', resumeSession);
      socket.off('friend_list');
      socket.off('friend_list_updated');
      socket.off('peer_public_key_updated');
      socket.off('requests_updated');
      socket.off('user_profile_updated');
      socket.off('profile_updated');
      socket.off('message_unsent');
      socket.off('message_edited');
      socket.off('reaction_updated');
      socket.off('friend_request_received');
      socket.off('friend_request_sent');
      socket.off('friend_request_cancelled');
      socket.off('friend_request_accepted');
      socket.off('friend_removed');
      socket.off('chat_cleared');
      socket.off('mute_updated');
      socket.off('block_updated');
      socket.off('safety_state_updated');
      socket.off('history', handleHistory);
      socket.off('message_status');
      socket.off('private_message');
      socket.off('typing');
      socket.off('user_status');
      socket.off('call_incoming');
      socket.off('call_accepted');
      socket.off('call_ended');
      socket.off('webrtc_signal');
    };
  }, [user, setUser, endCall]);

  const updateProfile = useCallback(
    (payload: { displayName?: string; bio?: string; status?: string; avatarId?: string }) => {
      const socket = getSocket();
      if (payload.status !== undefined) presenceModeRef.current = payload.status as typeof presenceModeRef.current;
      if (setUser) {
        setUser((prev) =>
          prev
            ? {
                ...prev,
                displayName: payload.displayName !== undefined ? payload.displayName : prev.displayName,
                bio: payload.bio !== undefined ? payload.bio : prev.bio,
                avatarId: payload.avatarId !== undefined ? payload.avatarId : prev.avatarId,
                presenceMode: payload.status !== undefined ? (payload.status as any) : prev.presenceMode,
              }
            : prev
        );
      }
      if (!socket) return;
      socket.emit('update_profile', payload);
      triggerHaptic('success');
    },
    [setUser]
  );

  const unsendMessage = useCallback((messageId: string) => {
    if (!activeChat) return;
    const socket = getSocket();
    if (!socket) return;
    socket.emit('unsend_message', { messageId, to: activeChat });
    setMessages((prev) => prev.filter((m) => m.id !== messageId));
    triggerHaptic('medium');
  }, [activeChat]);

  const editMessage = useCallback((messageId: string, newText: string) => {
    if (!activeChat) return;
    const activeConv = conversationsRef.current.find(
      (conversation) => conversation.username.toLowerCase() === activeChat.toLowerCase()
    );
    // Saved Messages lives only on this device, so it must never use the
    // realtime edit endpoint.
    if (activeConv?.isSelf && user) {
      const nextText = newText.trim();
      if (!nextText) return;
      const storageKey = `novyn_saved_messages_${user.username.toLowerCase()}`;
      setMessages((previous) => {
        const next = previous.map((message) =>
          message.id === messageId ? { ...message, text: nextText, editedAt: new Date().toISOString() } : message
        );
        messagesCacheRef.current[activeChat.toLowerCase()] = next;
        localStorage.setItem(storageKey, JSON.stringify(next));
        return next;
      });
      triggerHaptic('light');
      return;
    }
    // Editing would require re-encrypting and replacing the ciphertext. Until that
    // protocol exists, never fall back to submitting an encrypted message as plaintext.
    if (messagesCacheRef.current[activeChat.toLowerCase()]?.some((m) => m.id === messageId && m.isEncrypted)) {
      return;
    }
    const socket = getSocket();
    if (!socket) return;
    socket.emit('edit_message', { messageId, text: newText, to: activeChat });
    setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text: newText } : m)));
    triggerHaptic('light');
  }, [activeChat, user]);

  const sendMessage = useCallback(
    (text: string, options: { attachment?: any; replyTo?: any; isVoice?: boolean; retryId?: string; to?: string } = {}) => {
      const targetChat = options.to || activeChat;
      if (!targetChat || !user) return;

      const activeConv = conversationsRef.current.find(
        (c) => c.username.toLowerCase() === targetChat.toLowerCase()
      );

      if (activeConv?.isSelf) {
        const savedMessage: Message = {
          id: options.retryId || `note_${crypto.randomUUID()}`,
          sender: user.username,
          receiver: user.username,
          text: text || '',
          timestamp: new Date().toISOString(),
          status: 'sent',
          attachment: options.attachment,
          replyTo: options.replyTo,
          isVoice: options.isVoice,
        };
        const storageKey = `novyn_saved_messages_${user.username.toLowerCase()}`;
        setMessages((previous) => {
          const next = options.retryId
            ? previous.map((message) => message.id === options.retryId ? savedMessage : message)
            : [...previous, savedMessage];
          messagesCacheRef.current[targetChat.toLowerCase()] = next;
          localStorage.setItem(storageKey, JSON.stringify(next));
          return next;
        });
        setConversations((previous) => previous.map((conversation) =>
          conversation.isSelf ? { ...conversation, lastMessage: savedMessage, unreadCount: 0 } : conversation
        ));
        playMessageSentSound();
        triggerHaptic('light');
        return;
      }

      const socket = getSocket();
      if (!socket) return;
      const toType = activeConv?.isGroup ? 'group' : 'friend';

      const clientTempId = options.retryId || `tmp_${crypto.randomUUID()}`;
      pendingSendsRef.current.set(clientTempId, { text, options, to: targetChat, sender: user.username });
      const rawText = text || (options.attachment?.kind === 'image' ? '[Image]' : options.isVoice ? '[Voice Message]' : '[File]');
      
      const payload: any = {
        to: targetChat,
        toType,
        text: rawText,
        attachment: options.attachment || null,
        replyTo: options.replyTo || null,
        clientTempId,
      };

      const optimisticMsg: Message = {
        id: clientTempId,
        sender: user.username,
        receiver: targetChat,
        text: text || '',
        timestamp: new Date().toISOString(),
        status: 'sending',
        attachment: options.attachment,
        replyTo: options.replyTo,
        isVoice: options.isVoice,
      };

      setMessages((prev) => {
        const targetKey = targetChat.toLowerCase();
        const currentKey = activeChat?.toLowerCase();
        const targetMessages = currentKey === targetKey ? prev : messagesCacheRef.current[targetKey] || [];
        const next = options.retryId ? targetMessages.map((message) => message.id === clientTempId ? { ...message, status: 'sending' as const, sendError: undefined } : message) : [...targetMessages, optimisticMsg];
        messagesCacheRef.current[targetKey] = next;
        return currentKey === targetKey ? next : prev;
      });
      playMessageSentSound();

      const fail = (reason: string) => {
        if (!pendingSendsRef.current.has(clientTempId)) return;
        const update = (list: Message[]) => list.map((message) => message.id === clientTempId ? { ...message, status: 'failed' as const, sendError: reason } : message);
        const key = targetChat.toLowerCase();
        messagesCacheRef.current[key] = update(messagesCacheRef.current[key] || []);
        if (activeChatRef.current?.toLowerCase() === key) setMessages(update);
      };
      const transmit = () => {
        if (!pendingSendsRef.current.has(clientTempId)) return;
        if (!socket.connected) { fail('You are offline. Reconnect and retry.'); return; }
        socket.timeout(12000).emit('private_message', payload, (error: Error | null, result: any) => {
          if (error) fail('Delivery not confirmed. Retry safely when connected.');
          else if (!result?.ok) fail(result?.message || 'Could not send this message.');
        });
      };
      // Check if peer has public key for E2EE encryption
      const peerPubKey = activeConv?.publicKey;
      if (toType === 'friend' && peerPubKey && !activeConv?.isSelf) {
          encryptMessageContent(rawText, targetChat, peerPubKey).then((encrypted) => {
          if (encrypted) {
            // Keep message bodies and quoted message bodies off the relay. The UI
            // retains the local plaintext until it receives and decrypts the echo.
            payload.text = ENCRYPTED_MESSAGE_PLACEHOLDER;
            if (payload.replyTo) {
              payload.replyTo = { ...payload.replyTo, text: ENCRYPTED_MESSAGE_PLACEHOLDER };
            }
            payload.ciphertext = encrypted.ciphertext;
            payload.iv = encrypted.iv;
            payload.isEncrypted = true;
          }
          if (!encrypted) { fail('Encryption failed. Please retry.'); return; }
          transmit();
        }).catch(() => fail('Encryption failed. Please retry.'));
      } else {
        transmit();
      }
      triggerHaptic('light');
    },
    [activeChat, user]
  );

  const retryMessage = useCallback((id: string) => {
    const pending = pendingSendsRef.current.get(id);
    if (pending && pending.to === activeChat && pending.sender === user?.username) sendMessage(pending.text, { ...pending.options, retryId: id });
  }, [activeChat, user?.username, sendMessage]);

  const sendTyping = useCallback(
    (isTyping: boolean) => {
      if (!activeChat) return;
      const socket = getSocket();
      if (!socket) return;
      const activeConv = conversationsRef.current.find(
        (c) => c.username.toLowerCase() === activeChat.toLowerCase()
      );
      const toType = activeConv?.isGroup ? 'group' : 'friend';
      socket.emit('typing', { to: activeChat, isTyping, toType });
    },
    [activeChat]
  );

  const sendFriendRequest = useCallback(async (usernameOrEmail: string) => {
    const socket = getSocket();
    if (!socket.connected) return { ok: false, message: 'Connection lost. Please reconnect and try again.' };
    return new Promise<{ ok: boolean; message?: string }>((resolve) => {
      socket.timeout(8000).emit('add_friend', usernameOrEmail.trim(), (err: Error | null, result: { ok: boolean; message?: string; username?: string }) => {
        if (err) return resolve({ ok: false, message: 'Request timed out. Please try again.' });
        if (result?.ok && result.username) {
          setSentRequests((prev) => new Set(prev).add(result.username!.toLowerCase()));
          triggerHaptic('success');
        }
        resolve(result || { ok: false, message: 'Unable to send request.' });
      });
    });
  }, []);

  const cancelFriendRequest = useCallback(async (username: string) => {
    const socket = getSocket();
    if (!socket.connected) return { ok: false, message: 'Connection lost. Please reconnect and try again.' };
    return new Promise<{ ok: boolean; message?: string }>((resolve) => {
      socket.timeout(8000).emit('cancel_friend_request', username, (err: Error | null, result: { ok: boolean; message?: string }) => {
        if (err) return resolve({ ok: false, message: 'Request timed out. Please try again.' });
        if (result?.ok) {
          setSentRequests((prev) => {
            const next = new Set(prev);
            next.delete(username.toLowerCase());
            return next;
          });
          triggerHaptic('light');
        }
        resolve(result || { ok: false, message: 'Unable to cancel request.' });
      });
    });
  }, []);

  const acceptFriendRequest = useCallback((from: string) => {
    const socket = getSocket();
    if (!socket) return;
    socket.emit('accept_friend', from);
    setFriendRequests((prev) => prev.filter((r) => r.from.toLowerCase() !== from.toLowerCase()));
    triggerHaptic('success');
  }, []);

  const rejectFriendRequest = useCallback((from: string) => {
    const socket = getSocket();
    if (!socket) return;
    socket.emit('reject_friend', from);
    setFriendRequests((prev) => prev.filter((r) => r.from.toLowerCase() !== from.toLowerCase()));
    triggerHaptic('medium');
  }, []);

  const muteUser = useCallback((username: string, muted: boolean) => {
    const socket = getSocket();
    if (!socket) return;
    socket.emit('set_mute', { username, muted });
    triggerHaptic('light');
  }, []);

  const blockUser = useCallback((username: string, blocked: boolean) => {
    void setBlockedContact(username, blocked).catch(error => console.warn('[Block contact]', error.message));
    triggerHaptic('medium');
  }, []);

  const unfriendUser = useCallback((username: string) => {
    const socket = getSocket();
    if (!socket) return;
    socket.emit('remove_friend', username);
    setConversations((prev) => prev.filter((c) => c.username.toLowerCase() !== username.toLowerCase()));
    setActiveChat(null);
    triggerHaptic('heavy');
  }, []);

  const clearChat = useCallback((username: string) => {
    const socket = getSocket();
    if (!socket) return;
    socket.emit('clear_chat', { to: username, kind: 'friend' });
    setMessages([]);
    triggerHaptic('medium');
  }, []);

  const addReaction = useCallback(
    (messageId: string, emoji: string) => {
      if (!activeChat) return;
      const socket = getSocket();
      if (!socket) return;
      socket.emit('add_reaction', { messageId, emoji, to: activeChat });
      triggerHaptic('light');
    },
    [activeChat]
  );

  const pinMessage = useCallback(
    (messageId: string) => {
      if (!activeChat) return;
      const socket = getSocket();
      if (!socket) return;
      socket.emit('pin_message', { messageId, to: activeChat });
      triggerHaptic('light');
    },
    [activeChat]
  );

  const unpinMessage = useCallback(
    (messageId: string) => {
      if (!activeChat) return;
      const socket = getSocket();
      if (!socket) return;
      socket.emit('unpin_message', { messageId, to: activeChat });
      triggerHaptic('light');
    },
    [activeChat]
  );

  const createPoll = useCallback(
    (question: string, options: string[]) => {
      if (!activeChat) return;
      if (conversationsRef.current.find((conversation) => conversation.username.toLowerCase() === activeChat.toLowerCase())?.isSelf) return;
      const socket = getSocket();
      if (!socket) return;
      const clientTempId = `tmp_poll_${Date.now()}`;
      socket.emit('create_poll', {
        to: activeChat,
        question,
        options,
        clientTempId,
      });
      triggerHaptic('success');
    },
    [activeChat]
  );

  const votePoll = useCallback(
    (messageId: string, optionId: string) => {
      if (!activeChat) return;
      const socket = getSocket();
      if (!socket) return;
      socket.emit('poll_vote', {
        messageId,
        optionId,
        to: activeChat,
      });
      triggerHaptic('light');
    },
    [activeChat]
  );

  const sendGameChallenge = useCallback(
    (gameType: GameType, recipient?: string) => {
      const target = recipient || activeChat;
      if (!target || !user) return;
      const socket = getSocket();
      if (!socket) return;

      const activeConv = conversationsRef.current.find(
        (c) => c.username.toLowerCase() === target.toLowerCase()
      );
      if (!activeConv || activeConv.isSelf || blockedUsers.has(target)) return;
      const toType = activeConv?.isGroup ? 'group' : 'friend';
      const clientTempId = `tmp_game_${Date.now()}`;

      const titles: Record<GameType, string> = {
        tictactoe: 'Tic-Tac-Toe',
        rps: 'Rock • Paper • Scissors',
        connect4: 'Connect 4',
      };

      const gameData: GameData = {
        id: `game_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
        gameType,
        title: titles[gameType],
        createdBy: user.username,
        opponent: activeConv?.isGroup ? undefined : target,
        state: 'in_progress',
        turn: user.username,
        data: {
          board: gameType === 'tictactoe' ? Array(9).fill(null) : gameType === 'connect4' ? Array(42).fill(null) : undefined,
          playerX: user.username,
          player1: user.username,
        },
      };

      const payload = {
        to: target,
        toType,
        text: `🎮 Started a game of ${titles[gameType]}!`,
        game: gameData,
        clientTempId,
      };

      const optimisticMsg: Message = {
        id: clientTempId,
        sender: user.username,
        receiver: target,
        text: `🎮 Started a game of ${titles[gameType]}!`,
        timestamp: new Date().toISOString(),
        status: 'sent',
        game: gameData,
      };

      if (target === activeChat) setMessages((prev) => [...prev, optimisticMsg]);
      playMessageSentSound();
      socket.emit('private_message', payload);
      triggerHaptic('success');
    },
    [activeChat, user, blockedUsers]
  );

  const makeGameMove = useCallback(
    (messageId: string, moveData: any) => {
      if (!activeChat || !user) return;
      const socket = getSocket();
      if (!socket) return;

      // Update locally immediately for instant feedback
      setMessages((prev) =>
        prev.map((m) => {
          if ((m.id === messageId || (m.game && m.game.id === messageId)) && m.game) {
            const updatedGame: GameData = {
              ...m.game,
              state: moveData.state || m.game.state,
              turn: moveData.turn !== undefined ? moveData.turn : m.game.turn,
              winner: moveData.winner !== undefined ? moveData.winner : m.game.winner,
              data: {
                ...m.game.data,
                ...moveData,
              },
              lastMoveBy: user.username,
              updatedAt: Date.now(),
            };
            return { ...m, game: updatedGame };
          }
          return m;
        })
      );

      socket.emit('game_move', {
        messageId,
        to: activeChat,
        moveData,
      });
      triggerHaptic('medium');
    },
    [activeChat, user]
  );

  const createGroup = useCallback(
    (name: string, members: string[]) => {
      const socket = getSocket();
      if (!socket) return;
      socket.emit('create_group', { name, members });
      triggerHaptic('success');
    },
    []
  );

  const addGroupMembers = useCallback(
    (groupId: string, members: string[]) => {
      const socket = getSocket();
      if (!socket) return;
      socket.emit('add_group_members', { groupId, members });
      triggerHaptic('success');
    },
    []
  );

  const removeGroupMember = useCallback(
    (groupId: string, username: string) => {
      const socket = getSocket();
      if (!socket) return;
      socket.emit('remove_group_member', { groupId, username });
      triggerHaptic('medium');
    },
    []
  );

  const leaveGroup = useCallback(
    (groupId: string) => {
      const socket = getSocket();
      if (!socket) return;
      socket.emit('leave_group', { groupId });
      setConversations((prev) => prev.filter((c) => c.username.toLowerCase() !== groupId.toLowerCase()));
      setActiveChat(null);
      triggerHaptic('heavy');
    },
    []
  );

  const setChatWallpaper = useCallback(
    (to: string, wallpaper: string) => {
      const wp = wallpaper || 'var(--bg-canvas)';
      setChatWallpaperState(wp);
      if (to) {
        localStorage.setItem(`novyn_chat_wallpaper_${to.toLowerCase()}`, wp);
      }
      const socket = getSocket();
      if (socket) {
        socket.emit('set_chat_wallpaper', { to, wallpaper: wp });
      }
    },
    []
  );

  useEffect(() => {
    if (activeChat) {
      const cached = localStorage.getItem(`novyn_chat_wallpaper_${activeChat.toLowerCase()}`);
      if (cached && cached !== 'var(--bg-canvas)') {
        setChatWallpaperState(cached);
      } else {
        setChatWallpaperState('var(--bg-canvas)');
      }
      const socket = getSocket();
      if (socket) {
        socket.emit('get_chat_wallpaper', { to: activeChat });
      }
    }
  }, [activeChat]);

  // WebRTC Call Triggers
  const startCall = useCallback(async (remoteUser: string, isVideo = false) => {
    if (!user || remoteUser.trim().toLowerCase() === user.username.toLowerCase()) return;
    const socket = getSocket();
    if (!socket || !webrtcManagerRef.current) return;

    try {
      const callId = typeof window.crypto?.randomUUID === 'function'
        ? window.crypto.randomUUID()
        : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const manager = webrtcManagerRef.current;
      const [, localStream] = await Promise.all([
        manager.ensureIceServers(),
        manager.initLocalMedia(isVideo),
      ]);
      setCallState({
        callId,
        isActive: true,
        status: 'calling',
        remoteUser,
        remoteDisplayName: remoteUser,
        isVideo,
        isMuted: false,
        isCameraOff: false,
        isScreenSharing: false,
        remoteIsScreenSharing: false,
        isIncoming: false,
        localStream,
        remoteStream: null,
      });

      playCallRing();
      socket.emit('call_start', { to: remoteUser, isVideo, callId });
      triggerHaptic('medium');

      if (callTimeoutTimerRef.current) clearTimeout(callTimeoutTimerRef.current);
      callTimeoutTimerRef.current = setTimeout(() => {
        endCall('No answer (Timed out)');
      }, 30000);
    } catch (err: any) {
      const name = err?.name || '';
      console.error('[Call] startCall media error:', name, err?.message);

      let msg = 'Could not access your microphone. ';
      if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
        msg += 'Permission was denied. Click the camera/mic icon in your browser address bar and allow access, then try again.';
      } else if (name === 'NotReadableError' || name === 'TrackStartError') {
        msg += 'Your microphone is already in use by another app (Zoom, Teams, etc.). Close it and try again.';
      } else if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
        msg += 'No microphone was found. Please plug one in and try again.';
      } else if (name === 'OverconstrainedError') {
        msg += 'Camera resolution not supported. Try a voice-only call instead.';
      } else {
        msg += `(${name}: ${err?.message || 'Unknown error'})`;
      }
      alert(msg);
    }
  }, [endCall, user?.username]);

  const answerCall = useCallback(async () => {
    const socket = getSocket();
    if (!socket || !webrtcManagerRef.current) return;

    // Use callStateRef.current to avoid stale closure on isVideo/remoteUser
    const { isVideo, remoteUser, callId } = callStateRef.current;
    if (!callId || !remoteUser) return;

    stopRingtone();
    if (callTimeoutTimerRef.current) {
      clearTimeout(callTimeoutTimerRef.current);
      callTimeoutTimerRef.current = null;
    }
    callStartTimeRef.current = Date.now();

    try {
      const manager = webrtcManagerRef.current;
      const [, localStream] = await Promise.all([
        manager.ensureIceServers(),
        manager.initLocalMedia(isVideo),
      ]);
      setCallState((prev) => ({ ...prev, status: 'connected', localStream }));
      socket.emit('call_accept', { to: remoteUser, callId });
      triggerHaptic('success');
    } catch (err: any) {
      const name = err?.name || '';
      console.error('[Call] answerCall media error:', name, err?.message);
      let msg = 'Could not access your microphone. ';
      if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
        msg += 'Permission denied — click the mic icon in your address bar and allow, then try again.';
      } else if (name === 'NotReadableError' || name === 'TrackStartError') {
        msg += 'Microphone is in use by another app. Close it and try again.';
      } else if (name === 'NotFoundError') {
        msg += 'No microphone found.';
      } else {
        msg += `(${name}: ${err?.message || 'Unknown'})`;
      }
      alert(msg);
      endCall('Media error');
    }
  }, [endCall]);

  const toggleMute = useCallback(() => {
    const nextMuted = !callState.isMuted;
    webrtcManagerRef.current?.setAudioEnabled(!nextMuted);
    setCallState((prev) => ({ ...prev, isMuted: nextMuted }));
    triggerHaptic('light');
  }, [callState.isMuted]);

  const toggleCamera = useCallback(() => {
    const nextCameraOff = !callState.isCameraOff;
    webrtcManagerRef.current?.setVideoEnabled(!nextCameraOff);
    setCallState((prev) => ({ ...prev, isCameraOff: nextCameraOff }));
    triggerHaptic('light');
  }, [callState.isCameraOff]);

  const toggleScreenShare = useCallback(async () => {
    if (!webrtcManagerRef.current) return;
    const isSharing = !callState.isScreenSharing;
    const success = await webrtcManagerRef.current.toggleScreenShare(isSharing);
    const nextIsSharing = isSharing && success;
    setCallState((prev) => ({ ...prev, isScreenSharing: nextIsSharing }));
    const socket = getSocket();
    const current = callStateRef.current;
    if (socket && current.remoteUser && current.callId) {
      socket.emit('webrtc_signal', {
        to: current.remoteUser,
        callId: current.callId,
        signal: { type: 'screen_share_state', isSharing: nextIsSharing },
      });
    }
    triggerHaptic('medium');
  }, [callState.isScreenSharing]);

  return (
    <ChatContext.Provider
      value={{
        conversations,
        activeChat,
        setActiveChat,
        messages,
        friendRequests,
        sentRequests,
        typingUsers,
        mutedUsers,
        blockedUsers,
        callState,
        callLogs,
        unreadMissedCallCount,
        markMissedCallsRead,
        clearCallLogs,
        sendMessage,
        retryMessage,
        sendTyping,
        sendFriendRequest,
        cancelFriendRequest,
        acceptFriendRequest,
        rejectFriendRequest,
        updateProfile,
        unsendMessage,
        editMessage,
        muteUser,
        blockUser,
        unfriendUser,
        clearChat,
        addReaction,
        pinMessage,
        unpinMessage,
        createPoll,
        votePoll,
        sendGameChallenge,
        makeGameMove,
        createGroup,
        addGroupMembers,
        removeGroupMember,
        leaveGroup,
        chatWallpaper,
        setChatWallpaper,
        pinnedChats,
        archivedChats,
        favouriteChats,
        manualUnreadChats,
        togglePinChat,
        reorderPinnedChats,
        toggleArchiveChat,
        toggleFavouriteChat,
        markChatUnread,
        startCall,
        answerCall,
        endCall,
        toggleMute,
        toggleCamera,
        toggleScreenShare,
        myPublicKey,
        getSafetyNumber,
      }}
    >
      {children}
    </ChatContext.Provider>
  );
};

export const useChat = () => {
  const context = useContext(ChatContext);
  if (!context) throw new Error('useChat must be used within a ChatProvider');
  return context;
};
