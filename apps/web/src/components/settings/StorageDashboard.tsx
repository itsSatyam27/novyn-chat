import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  HardDrive,
  Database,
  Trash2,
  Clock,
  Download,
  Check,
  Search,
  FileText,
  FileImage,
  FileVideo2,
  FileAudio2,
  X,
  TriangleAlert,
  Sliders,
  ShieldCheck,
  Sparkles,
  RefreshCw,
  FolderOpen,
  Play,
  Pause,
  Eye,
  ExternalLink,
  MessageSquare,
  LayoutGrid,
  List,
  ArrowRight,
  Shield,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import { navigateTo } from '../../services/router';
import type { Attachment, Message } from '../../types';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import './storageDashboard.css';

const bytes = (value: number | undefined) => {
  if (value === undefined || isNaN(value)) return '0.0 B';
  const unit = value >= 1024 ** 3 ? 3 : value >= 1024 ** 2 ? 2 : value >= 1024 ? 1 : 0;
  return `${(value / 1024 ** unit).toLocaleString(undefined, { maximumFractionDigits: 1 })} ${
    ['B', 'KB', 'MB', 'GB'][unit]
  }`;
};

type FileKind = 'images' | 'videos' | 'audio' | 'documents';
type InventoryFile = {
  chatKey: string;
  chatName: string;
  messageId: string;
  name: string;
  url?: string;
  mime: string;
  size: number;
  kind: string;
  chatType: 'friend' | 'group';
  isMine: boolean;
  timestamp?: string | number;
};

const kindLabel = (kind: string) =>
  kind === 'images' ? 'Photos' : kind === 'videos' ? 'Videos' : kind === 'audio' ? 'Voice & Audio' : 'Documents';
const kindIcon = (kind: string) =>
  kind === 'images' ? FileImage : kind === 'videos' ? FileVideo2 : kind === 'audio' ? FileAudio2 : FileText;
const kindColor: Record<FileKind, string> = {
  images: '#a855f7',
  videos: '#38bdf8',
  audio: '#34d399',
  documents: '#f59e0b',
};

export function StorageDashboard() {
  const { user } = useAuth();
  const { conversations, messages, activeChat, getLoadedMessageSnapshot, setActiveChat } = useChat();

  const [estimate, setEstimate] = useState<StorageEstimate | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  // Filters, Explorer & View Modes
  const [mediaFilter, setMediaFilter] = useState<string>('all');
  const [selectedChat, setSelectedChat] = useState<string | null>(null);
  const [fileQuery, setFileQuery] = useState('');
  const [viewMode, setViewMode] = useState<'list' | 'grid'>('list');
  const [serverFiles, setServerFiles] = useState<InventoryFile[] | null>(null);
  const [inventoryLoading, setInventoryLoading] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<InventoryFile | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Media Playback & Universal Media Preview Modal
  const [playingAudioId, setPlayingAudioId] = useState<string | null>(null);
  const audioPlayerRef = useRef<HTMLAudioElement | null>(null);
  const [selectedMedia, setSelectedMedia] = useState<{
    chatKey: string;
    chatName: string;
    chatType: 'friend' | 'group';
    messageId: string;
    name: string;
    url?: string;
    mime: string;
    size: number;
    kind: FileKind;
    isMine: boolean;
  } | null>(null);

  // Clean Modal State
  const [isCleanModalOpen, setIsCleanModalOpen] = useState(false);
  const [cleanThumbnails, setCleanThumbnails] = useState(true);
  const [cleanAudio, setCleanAudio] = useState(true);
  const [cleanDrafts, setCleanDrafts] = useState(true);
  const [cleanBlobs, setCleanBlobs] = useState(true);

  // Storage Preferences (Saved in localStorage)
  const [mediaRetention, setMediaRetention] = useState<string>(() => {
    return localStorage.getItem('novyn_media_retention') || 'forever';
  });
  const [maxCacheSize, setMaxCacheSize] = useState<string>(() => {
    return localStorage.getItem('novyn_max_cache_size') || '1gb';
  });
  const [autoPhotos, setAutoPhotos] = useState<boolean>(() => {
    return localStorage.getItem('novyn_autodownload_photos') !== 'false';
  });
  const [autoAudio, setAutoAudio] = useState<boolean>(() => {
    return localStorage.getItem('novyn_autodownload_audio') !== 'false';
  });
  const [autoVideos, setAutoVideos] = useState<boolean>(() => {
    return localStorage.getItem('novyn_autodownload_videos') === 'true';
  });
  const [dataSaver, setDataSaver] = useState<boolean>(() => {
    return localStorage.getItem('novyn_data_saver') === 'true';
  });

  const refreshStorage = useCallback(async () => {
    try {
      setEstimate((await navigator.storage?.estimate?.()) || null);
    } catch {
      setEstimate(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refreshStorage();
  }, [refreshStorage]);

  const refreshInventory = useCallback(() => {
    const socket = getSocket();
    if (!socket?.connected) return;
    setInventoryLoading(true);
    socket.timeout(15000).emit('get_storage_inventory', (error: Error | null, response: any) => {
      setInventoryLoading(false);
      if (error || !response?.ok || !Array.isArray(response.files)) return;
      setServerFiles(response.files);
    });
  }, []);

  useEffect(() => {
    refreshInventory();
  }, [refreshInventory]);

  const updateRetention = (val: string) => {
    triggerHaptic('light');
    setMediaRetention(val);
    localStorage.setItem('novyn_media_retention', val);
    setNotice({ text: `Media retention set to ${val === 'forever' ? 'Keep Forever' : val}.`, error: false });
  };

  const updateMaxCache = (val: string) => {
    triggerHaptic('light');
    setMaxCacheSize(val);
    localStorage.setItem('novyn_max_cache_size', val);
    setNotice({ text: `Maximum cache limit updated.`, error: false });
  };

  const toggleAuto = (type: 'photos' | 'audio' | 'videos' | 'saver') => {
    triggerHaptic('light');
    if (type === 'photos') {
      const next = !autoPhotos;
      setAutoPhotos(next);
      localStorage.setItem('novyn_autodownload_photos', String(next));
    } else if (type === 'audio') {
      const next = !autoAudio;
      setAutoAudio(next);
      localStorage.setItem('novyn_autodownload_audio', String(next));
    } else if (type === 'videos') {
      const next = !autoVideos;
      setAutoVideos(next);
      localStorage.setItem('novyn_autodownload_videos', String(next));
    } else if (type === 'saver') {
      const next = !dataSaver;
      setDataSaver(next);
      localStorage.setItem('novyn_data_saver', String(next));
    }
  };

  // Perform Granular Cleanup
  const handlePerformClean = async () => {
    triggerHaptic('medium');
    setBusy(true);
    try {
      if (cleanBlobs && 'caches' in window) {
        const names = await caches.keys();
        await Promise.all(names.filter((n) => n.startsWith('novyn-shell-')).map((n) => caches.delete(n)));
      }
      if (cleanThumbnails || cleanDrafts) {
        const keysToRemove: string[] = [];
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (!k) continue;
          if (cleanThumbnails && k.startsWith('novyn_cache_thumb_')) keysToRemove.push(k);
          if (cleanDrafts && k.startsWith('novyn_draft_')) keysToRemove.push(k);
        }
        keysToRemove.forEach((k) => localStorage.removeItem(k));
      }
      await refreshStorage();
      setIsCleanModalOpen(false);
      setNotice({ text: 'Selected cache items cleared successfully. Encryption keys preserved.', error: false });
    } catch {
      setNotice({ text: 'Could not clear cache.', error: true });
    } finally {
      setBusy(false);
    }
  };

  const deleteSharedFile = () => {
    if (!pendingDelete || deleting) return;
    const socket = getSocket();
    if (!socket?.connected) {
      setNotice({ text: 'Reconnect to Novyn before deleting this file.', error: true });
      return;
    }
    setDeleting(true);
    socket.timeout(12000).emit(
      'delete_message',
      {
        messageId: pendingDelete.messageId,
        to: pendingDelete.chatKey,
        toType: pendingDelete.chatType,
      },
      (error: Error | null, result: any) => {
        setDeleting(false);
        if (error || !result?.ok) {
          setNotice({ text: result?.message || 'Could not delete this file.', error: true });
          return;
        }
        setNotice({ text: 'File and message removed for everyone in chat.', error: false });
        setPendingDelete(null);
        refreshInventory();
      }
    );
  };

  // Audio Playback Handler
  const togglePlayAudio = (id: string, url?: string) => {
    triggerHaptic('light');
    if (playingAudioId === id) {
      audioPlayerRef.current?.pause();
      setPlayingAudioId(null);
      return;
    }
    if (!url) {
      setNotice({ text: 'Audio playback link is not available.', error: true });
      return;
    }
    if (audioPlayerRef.current) {
      audioPlayerRef.current.pause();
    }
    const audio = new Audio(url);
    audioPlayerRef.current = audio;
    setPlayingAudioId(id);
    audio.play().catch(() => {
      setNotice({ text: 'Unable to stream this audio note.', error: true });
      setPlayingAudioId(null);
    });
    audio.onended = () => {
      setPlayingAudioId(null);
    };
  };

  useEffect(() => {
    return () => {
      if (audioPlayerRef.current) {
        audioPlayerRef.current.pause();
        audioPlayerRef.current = null;
      }
    };
  }, []);

  // Direct File Downloader
  const handleDownloadFile = async (url?: string, fileName?: string) => {
    triggerHaptic('light');
    const targetName = fileName || 'download';
    if (!url) {
      setNotice({ text: 'Download link is not available for this file.', error: true });
      return;
    }
    setNotice({ text: `Downloading ${targetName}…`, error: false });
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = targetName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      setTimeout(() => URL.revokeObjectURL(blobUrl), 1000);
      setNotice({ text: `Downloaded ${targetName} successfully.`, error: false });
    } catch {
      const link = document.createElement('a');
      link.href = url;
      link.download = targetName;
      link.target = '_blank';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  };

  // Jump to Chat
  const handleJumpToChat = (chatKey: string) => {
    triggerHaptic('light');
    setActiveChat(chatKey);
    navigateTo({ tab: 'chats', chat: chatKey });
  };

  const exportJsonData = () => {
    triggerHaptic('light');
    try {
      const content = JSON.stringify(
        {
          format: 'novyn-chat-export',
          version: 1,
          exportedAt: new Date().toISOString(),
          profile: {
            username: user?.username,
            displayName: user?.displayName,
            email: user?.email,
          },
          conversations,
          loadedMessages: messages,
        },
        null,
        2
      );
      const url = URL.createObjectURL(new Blob([content], { type: 'application/json' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = `novyn-chat-archive-${Date.now()}.json`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setNotice({ text: 'JSON Archive download started.', error: false });
    } catch {
      setNotice({ text: 'Could not prepare export.', error: true });
    }
  };

  const exportTextLog = () => {
    triggerHaptic('light');
    try {
      let text = `NOVYN CHAT TRANSCRIPT EXPORT\nExported: ${new Date().toLocaleString()}\nUser: @${
        user?.username || 'user'
      }\n=========================================\n\n`;
      conversations.forEach((conv) => {
        text += `\n[CONVERSATION: ${conv.displayName || conv.username}]\n`;
        const list = messages.filter(
          (m) =>
            m.receiver?.toLowerCase() === conv.username.toLowerCase() ||
            m.sender?.toLowerCase() === conv.username.toLowerCase()
        );
        list.forEach((m) => {
          text += `[${new Date(m.timestamp).toLocaleTimeString()}] ${m.sender}: ${m.text || '[Attachment]'}\n`;
        });
      });
      const url = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = `novyn-chat-log-${Date.now()}.txt`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setNotice({ text: 'Readable text transcript exported.', error: false });
    } catch {
      setNotice({ text: 'Could not export transcript.', error: true });
    }
  };

  // Inventory computation
  const inventory = useMemo(() => {
    const snapshot = getLoadedMessageSnapshot();
    if (activeChat) snapshot[activeChat.toLowerCase()] = messages;
    const names = new Map(
      conversations.map((c) => [c.username.toLowerCase(), c.displayName || c.username])
    );
    const unique = new Map<
      string,
      { message: Message; attachment: Attachment; chatKey: string; chatType: 'friend' | 'group'; isMine: boolean }
    >();

    if (serverFiles) {
      for (const file of serverFiles) {
        let fileUrl = file.url || '';
        if (!fileUrl) {
          // 1. Check in chat snapshot
          const chatMsgs = snapshot[file.chatKey.toLowerCase()];
          const found = chatMsgs?.find((m) => m.id === file.messageId || m.attachment?.name === file.name);
          if (found?.attachment?.url) fileUrl = found.attachment.url;
        }
        if (!fileUrl) {
          // 2. Check across all loaded conversations
          for (const list of Object.values(snapshot)) {
            const m = list.find((msg) => msg.id === file.messageId || msg.attachment?.name === file.name);
            if (m?.attachment?.url) {
              fileUrl = m.attachment.url;
              break;
            }
          }
        }
        if (!fileUrl && file.name) {
          fileUrl = `/uploads/${encodeURIComponent(file.name)}`;
        }
        unique.set(`${file.chatKey}:${file.messageId}`, {
          chatKey: file.chatKey,
          message: {
            id: file.messageId,
            timestamp: file.timestamp || '',
            sender: '',
            receiver: '',
            text: '',
            status: 'sent',
          } as Message,
          attachment: {
            url: fileUrl,
            name: file.name,
            mime: file.mime,
            size: file.size,
            kind: file.kind === 'audio' ? 'audio' : file.kind === 'image' ? 'image' : 'file',
          },
          chatType: file.chatType,
          isMine: file.isMine,
        });
      }
    } else {
      for (const [chatKey, list] of Object.entries(snapshot)) {
        for (const message of list || []) {
          if (message.attachment?.url) {
            unique.set(`${chatKey}:${message.id}`, {
              message,
              attachment: message.attachment,
              chatKey,
              chatType: conversations.find((c) => c.username.toLowerCase() === chatKey)?.isGroup
                ? 'group'
                : 'friend',
              isMine: message.sender?.toLowerCase() === user?.username?.toLowerCase(),
            });
          }
        }
      }
    }

    const files = [...unique.values()].map((item) => {
      const mime = item.attachment.mime?.toLowerCase() || '';
      const kind: FileKind =
        item.message.isVoice || item.attachment.kind === 'audio' || mime.startsWith('audio/')
          ? 'audio'
          : mime.startsWith('image/') || item.attachment.kind === 'image'
          ? 'images'
          : mime.startsWith('video/')
          ? 'videos'
          : 'documents';
      return {
        ...item,
        kind,
        size: Math.max(0, Number(item.attachment.size) || 0),
        chatName: names.get(item.chatKey) || item.chatKey,
      };
    });

    const categories = (['images', 'videos', 'audio', 'documents'] as FileKind[]).map((kind) => {
      const items = files.filter((f) => f.kind === kind);
      return {
        kind,
        count: items.length,
        size: items.reduce((sum, f) => sum + f.size, 0),
      };
    });

    const chatMap = new Map<string, { key: string; name: string; count: number; size: number }>();
    for (const file of files) {
      const current = chatMap.get(file.chatKey) || {
        key: file.chatKey,
        name: file.chatName,
        count: 0,
        size: 0,
      };
      current.count += 1;
      current.size += file.size;
      chatMap.set(file.chatKey, current);
    }

    return {
      files: files.sort((a, b) => b.size - a.size),
      categories,
      chats: [...chatMap.values()].sort((a, b) => b.size - a.size),
      total: files.reduce((sum, f) => sum + f.size, 0),
    };
  }, [activeChat, conversations, getLoadedMessageSnapshot, messages, serverFiles, user?.username]);

  const usage = estimate?.usage || 0;
  const quota = estimate?.quota || 1;

  // Calculate percentage shares for multi-colored storage meter
  const photosSize = inventory.categories.find((c) => c.kind === 'images')?.size || 0;
  const videosSize = inventory.categories.find((c) => c.kind === 'videos')?.size || 0;
  const audioSize = inventory.categories.find((c) => c.kind === 'audio')?.size || 0;
  const docsSize = inventory.categories.find((c) => c.kind === 'documents')?.size || 0;
  const appCacheSize = Math.max(0, usage - inventory.total);

  const meterTotal = Math.max(usage, inventory.total, 1024 * 1024);
  const pctPhotos = Math.min(100, (photosSize / meterTotal) * 100);
  const pctVideos = Math.min(100, (videosSize / meterTotal) * 100);
  const pctAudio = Math.min(100, (audioSize / meterTotal) * 100);
  const pctDocs = Math.min(100, (docsSize / meterTotal) * 100);
  const pctCache = Math.min(100, (appCacheSize / meterTotal) * 100);

  const visibleFiles = inventory.files.filter(
    (file) =>
      (mediaFilter === 'all' || file.kind === mediaFilter) &&
      (!selectedChat || file.chatKey === selectedChat) &&
      (!fileQuery || `${file.attachment.name} ${file.chatName}`.toLowerCase().includes(fileQuery.toLowerCase()))
  );

  return (
    <section className="storage-dashboard" aria-label="Data and storage settings">
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      {/* Header Area */}
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', marginBottom: 12 }}>
          <span style={{ color: '#94a3b8' }}>Settings</span>
          <span style={{ color: '#64748b' }}>/</span>
          <span style={{ color: '#818cf8', fontWeight: 600 }}>Data &amp; storage</span>
        </div>
        <h1 style={{ fontSize: '1.95rem', fontWeight: 800, margin: 0, color: '#ffffff', letterSpacing: '-0.025em' }}>
          Data &amp; Storage Management
        </h1>
        <p style={{ margin: '8px 0 0', color: '#94a3b8', fontSize: '0.92rem' }}>
          Manage local storage, inspect shared media by chat, and configure auto-download rules.
        </p>
      </div>

      {/* 1. Storage Usage Overview Hero Card */}
      <article className="storage-card-modern">
        <div className="storage-header-row">
          <div className="storage-header-left">
            <div className="storage-header-icon">
              <HardDrive size={22} />
            </div>
            <div className="storage-header-info">
              <h3>Storage Usage &amp; Breakdown</h3>
              <p>
                {loading ? 'Analyzing…' : `${bytes(usage)} used of ${bytes(quota)} available on this browser`}
              </p>
            </div>
          </div>
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => setIsCleanModalOpen(true)}
            style={{
              padding: '9px 16px',
              borderRadius: 12,
              fontSize: '0.84rem',
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              background: 'rgba(168, 85, 247, 0.12)',
              borderColor: 'rgba(168, 85, 247, 0.35)',
              color: 'var(--primary)',
            }}
          >
            <Trash2 size={15} /> Quick Clean Cache
          </button>
        </div>

        {/* Multi-Segmented Storage Bar */}
        <div className="storage-meter-track" title="Storage Breakdown">
          <div className="storage-meter-segment is-photos" style={{ width: `${pctPhotos}%` }} />
          <div className="storage-meter-segment is-videos" style={{ width: `${pctVideos}%` }} />
          <div className="storage-meter-segment is-audio" style={{ width: `${pctAudio}%` }} />
          <div className="storage-meter-segment is-docs" style={{ width: `${pctDocs}%` }} />
          <div className="storage-meter-segment is-cache" style={{ width: `${pctCache}%` }} />
        </div>

        {/* Category Pills Row (Interactive Filters) */}
        <div className="storage-categories-pills">
          <button
            type="button"
            className={`storage-category-pill ${mediaFilter === 'all' && !selectedChat ? 'is-active' : ''}`}
            onClick={() => {
              setMediaFilter('all');
              setSelectedChat(null);
            }}
          >
            <span className="storage-pill-dot is-photos" />
            <span>All Media</span>
            <span className="storage-pill-size">{bytes(inventory.total)}</span>
          </button>

          <button
            type="button"
            className={`storage-category-pill ${mediaFilter === 'images' ? 'is-active' : ''}`}
            onClick={() => {
              setMediaFilter('images');
              setSelectedChat(null);
            }}
          >
            <span className="storage-pill-dot is-photos" />
            <span>Photos</span>
            <span className="storage-pill-size">{bytes(photosSize)}</span>
          </button>

          <button
            type="button"
            className={`storage-category-pill ${mediaFilter === 'videos' ? 'is-active' : ''}`}
            onClick={() => {
              setMediaFilter('videos');
              setSelectedChat(null);
            }}
          >
            <span className="storage-pill-dot is-videos" />
            <span>Videos</span>
            <span className="storage-pill-size">{bytes(videosSize)}</span>
          </button>

          <button
            type="button"
            className={`storage-category-pill ${mediaFilter === 'audio' ? 'is-active' : ''}`}
            onClick={() => {
              setMediaFilter('audio');
              setSelectedChat(null);
            }}
          >
            <span className="storage-pill-dot is-audio" />
            <span>Voice &amp; Audio</span>
            <span className="storage-pill-size">{bytes(audioSize)}</span>
          </button>

          <button
            type="button"
            className={`storage-category-pill ${mediaFilter === 'documents' ? 'is-active' : ''}`}
            onClick={() => {
              setMediaFilter('documents');
              setSelectedChat(null);
            }}
          >
            <span className="storage-pill-dot is-docs" />
            <span>Documents</span>
            <span className="storage-pill-size">{bytes(docsSize)}</span>
          </button>

          <button
            type="button"
            className="storage-category-pill"
            onClick={() => setIsCleanModalOpen(true)}
          >
            <span className="storage-pill-dot is-cache" />
            <span>App Cache</span>
            <span className="storage-pill-size">{bytes(appCacheSize)}</span>
          </button>
        </div>
      </article>

      {/* 2. Controls Grid (Auto-Cleanup & Auto-Download Rules) */}
      <div className="storage-two-columns">
        {/* Card 1: Media Retention & Cache Limits */}
        <article className="storage-card-modern">
          <div className="storage-header-left" style={{ marginBottom: 14 }}>
            <div
              className="storage-header-icon"
              style={{ background: 'var(--primary-glow)', color: 'var(--primary)', borderColor: 'var(--primary)' }}
            >
              <Clock size={20} />
            </div>
            <div className="storage-header-info">
              <h3>Auto-Cleanup &amp; Cache Limits</h3>
              <p>Keep local storage trimmed automatically.</p>
            </div>
          </div>

          <div className="storage-control-group">
            {/* Setting 1: Retention */}
            <div>
              <div className="storage-control-subheading">Keep Downloaded Media</div>
              <p style={{ margin: '0 0 10px', fontSize: '0.8rem', color: '#94a3b8' }}>
                Photos and files unread for this duration are cleaned from local browser cache.
              </p>
              <div className="storage-seg-selector">
                {[
                  { id: '3d', label: '3 Days' },
                  { id: '1w', label: '1 Week' },
                  { id: '1m', label: '1 Month' },
                  { id: 'forever', label: 'Forever' },
                ].map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    className={`storage-seg-btn ${mediaRetention === item.id ? 'is-active' : ''}`}
                    onClick={() => updateRetention(item.id)}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Setting 2: Max Cache Size */}
            <div style={{ marginTop: 6 }}>
              <div className="storage-control-subheading">Maximum Cache Size</div>
              <p style={{ margin: '0 0 10px', fontSize: '0.8rem', color: '#94a3b8' }}>
                When cache exceeds this threshold, oldest cached files are pruned.
              </p>
              <div className="storage-seg-selector">
                {[
                  { id: '250mb', label: '250 MB' },
                  { id: '500mb', label: '500 MB' },
                  { id: '1gb', label: '1 GB' },
                  { id: '5gb', label: '5 GB' },
                  { id: 'unlimited', label: 'No Limit' },
                ].map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    className={`storage-seg-btn ${maxCacheSize === item.id ? 'is-active' : ''}`}
                    onClick={() => updateMaxCache(item.id)}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </article>

        {/* Card 2: Auto-Download Rules & Network */}
        <article className="storage-card-modern">
          <div className="storage-header-left" style={{ marginBottom: 14 }}>
            <div
              className="storage-header-icon"
              style={{ background: 'rgba(56, 189, 248, 0.12)', color: '#38bdf8', borderColor: 'rgba(56, 189, 248, 0.3)' }}
            >
              <Download size={20} />
            </div>
            <div className="storage-header-info">
              <h3>Media Auto-Download &amp; Data</h3>
              <p>Control bandwidth and automatic media caching.</p>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 16 }}>
            {/* Toggle 1: Photos */}
            <div className="storage-switch-row">
              <div className="storage-switch-info">
                <span className="storage-switch-title">Auto-Download Photos</span>
                <span className="storage-switch-sub">Download images immediately in chats</span>
              </div>
              <button
                type="button"
                className={`storage-switch-btn ${autoPhotos ? 'is-on' : ''}`}
                onClick={() => toggleAuto('photos')}
                aria-label="Toggle auto-download photos"
              >
                <div className="storage-switch-thumb" />
              </button>
            </div>

            {/* Toggle 2: Audio */}
            <div className="storage-switch-row">
              <div className="storage-switch-info">
                <span className="storage-switch-title">Auto-Download Voice Messages</span>
                <span className="storage-switch-sub">Pre-buffer voice notes for instant playback</span>
              </div>
              <button
                type="button"
                className={`storage-switch-btn ${autoAudio ? 'is-on' : ''}`}
                onClick={() => toggleAuto('audio')}
                aria-label="Toggle auto-download voice notes"
              >
                <div className="storage-switch-thumb" />
              </button>
            </div>

            {/* Toggle 3: Videos */}
            <div className="storage-switch-row">
              <div className="storage-switch-info">
                <span className="storage-switch-title">Auto-Download Videos &amp; Files</span>
                <span className="storage-switch-sub">Automatically fetch large attachments</span>
              </div>
              <button
                type="button"
                className={`storage-switch-btn ${autoVideos ? 'is-on' : ''}`}
                onClick={() => toggleAuto('videos')}
                aria-label="Toggle auto-download videos"
              >
                <div className="storage-switch-thumb" />
              </button>
            </div>

            {/* Toggle 4: Data Saver */}
            <div className="storage-switch-row">
              <div className="storage-switch-info">
                <span className="storage-switch-title">Low Data Usage Mode</span>
                <span className="storage-switch-sub">Compress preview blobs to save internet bandwidth</span>
              </div>
              <button
                type="button"
                className={`storage-switch-btn ${dataSaver ? 'is-on' : ''}`}
                onClick={() => toggleAuto('saver')}
                aria-label="Toggle data saver"
              >
                <div className="storage-switch-thumb" />
              </button>
            </div>
          </div>
        </article>
      </div>

      {/* 3. Top Chats Storage Inspector */}
      <article className="storage-card-modern">
        <div className="storage-header-row">
          <div className="storage-header-left">
            <div
              className="storage-header-icon"
              style={{ background: 'rgba(52, 211, 153, 0.12)', color: '#34d399', borderColor: 'rgba(52, 211, 153, 0.3)' }}
            >
              <FolderOpen size={20} />
            </div>
            <div className="storage-header-info">
              <h3>Storage by Chat</h3>
              <p>Top conversations consuming shared storage.</p>
            </div>
          </div>
          <span style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
            {inventory.chats.length} active chats
          </span>
        </div>

        <div className="storage-chat-list">
          {inventory.chats.length > 0 ? (
            inventory.chats.map((chat) => (
              <div key={chat.key} className="storage-chat-item">
                <div className="storage-chat-left">
                  <div className="storage-chat-avatar">
                    {chat.name.charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <div className="storage-chat-name">{chat.name}</div>
                    <div className="storage-chat-meta">
                      {chat.count} shared {chat.count === 1 ? 'file' : 'files'}
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span
                    style={{
                      background: 'rgba(255, 255, 255, 0.06)',
                      border: '1px solid rgba(255, 255, 255, 0.1)',
                      color: '#ffffff',
                      borderRadius: 8,
                      padding: '3px 10px',
                      fontSize: '0.78rem',
                      fontWeight: 700,
                    }}
                  >
                    {bytes(chat.size)}
                  </span>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedChat(selectedChat === chat.key ? null : chat.key);
                      setMediaFilter('all');
                      triggerHaptic('light');
                    }}
                    style={{
                      background: selectedChat === chat.key ? 'rgba(168, 85, 247, 0.2)' : 'rgba(255, 255, 255, 0.04)',
                      border: selectedChat === chat.key ? '1px solid rgba(168, 85, 247, 0.4)' : '1px solid rgba(255, 255, 255, 0.1)',
                      color: selectedChat === chat.key ? '#c084fc' : '#cbd5e1',
                      borderRadius: 8,
                      padding: '4px 10px',
                      fontSize: '0.74rem',
                      fontWeight: 600,
                      cursor: 'pointer',
                    }}
                  >
                    {selectedChat === chat.key ? 'Viewing Files' : 'Inspect'}
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div style={{ padding: '24px', textAlign: 'center', color: '#64748b', fontSize: '0.84rem' }}>
              No shared media files in loaded chat histories.
            </div>
          )}
        </div>
      </article>

      {/* 4. Shared Media & File Explorer */}
      <article className="storage-card-modern">
        <div className="storage-explorer-toolbar">
          <div className="storage-toolbar-top">
            <div>
              <h3 style={{ margin: 0, fontSize: '1.22rem', fontWeight: 700, color: '#ffffff' }}>
                {selectedChat
                  ? `Files in ${inventory.chats.find((c) => c.key === selectedChat)?.name || 'Chat'}`
                  : mediaFilter !== 'all'
                  ? `${kindLabel(mediaFilter)} Explorer`
                  : 'Shared Media & Attachments'}
              </h3>
              <p style={{ margin: '3px 0 0', color: '#94a3b8', fontSize: '0.82rem' }}>
                Showing {visibleFiles.length} of {inventory.files.length} total shared files
                {selectedChat && (
                  <button
                    type="button"
                    onClick={() => setSelectedChat(null)}
                    style={{
                      marginLeft: 10,
                      background: 'none',
                      border: 'none',
                      color: '#a78bfa',
                      fontSize: '0.8rem',
                      cursor: 'pointer',
                      textDecoration: 'underline',
                    }}
                  >
                    Clear chat filter
                  </button>
                )}
              </p>
            </div>

            <div className="storage-toolbar-controls">
              <div className="storage-search-box">
                <Search size={14} color="#94a3b8" />
                <input
                  type="text"
                  value={fileQuery}
                  onChange={(e) => setFileQuery(e.target.value)}
                  placeholder="Search file name or chat…"
                />
                {fileQuery && (
                  <button
                    type="button"
                    onClick={() => setFileQuery('')}
                    style={{ background: 'none', border: 'none', color: '#64748b', cursor: 'pointer', padding: 0 }}
                  >
                    <X size={13} />
                  </button>
                )}
              </div>

              {/* View Mode Switcher */}
              <div className="storage-view-toggle">
                <button
                  type="button"
                  className={`storage-view-btn ${viewMode === 'list' ? 'is-active' : ''}`}
                  onClick={() => {
                    setViewMode('list');
                    triggerHaptic('light');
                  }}
                  title="List View"
                >
                  <List size={16} />
                </button>
                <button
                  type="button"
                  className={`storage-view-btn ${viewMode === 'grid' ? 'is-active' : ''}`}
                  onClick={() => {
                    setViewMode('grid');
                    triggerHaptic('light');
                  }}
                  title="Gallery Grid View"
                >
                  <LayoutGrid size={16} />
                </button>
              </div>
            </div>
          </div>

          {/* Category Filter Subtabs */}
          <div className="storage-toolbar-bottom">
            <div className="storage-subtabs">
              {[
                { id: 'all', label: 'All Files', count: inventory.files.length },
                { id: 'images', label: 'Photos', count: inventory.categories.find((c) => c.kind === 'images')?.count || 0 },
                { id: 'audio', label: 'Voice & Audio', count: inventory.categories.find((c) => c.kind === 'audio')?.count || 0 },
                { id: 'documents', label: 'Documents', count: inventory.categories.find((c) => c.kind === 'documents')?.count || 0 },
                { id: 'videos', label: 'Videos', count: inventory.categories.find((c) => c.kind === 'videos')?.count || 0 },
              ].map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  className={`storage-subtab-btn ${mediaFilter === tab.id ? 'is-active' : ''}`}
                  onClick={() => {
                    setMediaFilter(tab.id);
                    triggerHaptic('light');
                  }}
                >
                  <span>{tab.label}</span>
                  <span className="storage-subtab-badge">{tab.count}</span>
                </button>
              ))}
            </div>

            {selectedChat && (
              <span style={{ fontSize: '0.78rem', color: 'var(--primary)', fontWeight: 600 }}>
                Filtered: {inventory.chats.find((c) => c.key === selectedChat)?.name}
              </span>
            )}
          </div>
        </div>

        {/* List View Rendering */}
        {viewMode === 'list' ? (
          <div className="storage-files-grid">
            {visibleFiles.slice(0, 80).map((file) => {
              const Icon = kindIcon(file.kind);
              const isPlaying = playingAudioId === file.message.id;
              const hasUrl = Boolean(file.attachment.url);

              return (
                <div
                  key={`${file.chatKey}:${file.message.id}`}
                  className="storage-file-row-modern"
                  onClick={() => {
                    triggerHaptic('light');
                    setSelectedMedia({
                      chatKey: file.chatKey,
                      chatName: file.chatName,
                      chatType: file.chatType,
                      messageId: file.message.id,
                      name: file.attachment.name || `${kindLabel(file.kind)} file`,
                      url: file.attachment.url,
                      mime: file.attachment.mime,
                      size: file.size,
                      kind: file.kind as FileKind,
                      isMine: file.isMine,
                    });
                  }}
                  title="Click to preview & view actions"
                >
                  <div className="storage-file-left">
                    {/* Thumbnail preview */}
                    <div
                      className="storage-file-thumb"
                      style={{
                        background: `color-mix(in srgb, ${kindColor[file.kind as FileKind] || '#a855f7'} 15%, transparent)`,
                        borderColor: `color-mix(in srgb, ${kindColor[file.kind as FileKind] || '#a855f7'} 30%, transparent)`,
                      }}
                      onClick={(e) => {
                        e.stopPropagation();
                        if (file.kind === 'audio' && hasUrl) {
                          togglePlayAudio(file.message.id, file.attachment.url);
                        } else {
                          setSelectedMedia({
                            chatKey: file.chatKey,
                            chatName: file.chatName,
                            chatType: file.chatType,
                            messageId: file.message.id,
                            name: file.attachment.name || `${kindLabel(file.kind)} file`,
                            url: file.attachment.url,
                            mime: file.attachment.mime,
                            size: file.size,
                            kind: file.kind as FileKind,
                            isMine: file.isMine,
                          });
                        }
                      }}
                    >
                      {file.kind === 'images' && hasUrl ? (
                        <img
                          src={file.attachment.url}
                          alt={file.attachment.name}
                          loading="lazy"
                          onError={(e) => {
                            (e.currentTarget as HTMLImageElement).style.display = 'none';
                          }}
                        />
                      ) : file.kind === 'audio' ? (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            togglePlayAudio(file.message.id, file.attachment.url);
                          }}
                          style={{
                            background: 'none',
                            border: 'none',
                            color: isPlaying ? '#34d399' : '#a855f7',
                            cursor: 'pointer',
                            padding: 0,
                            display: 'grid',
                            placeItems: 'center',
                          }}
                        >
                          {isPlaying ? <Pause size={17} /> : <Play size={17} />}
                        </button>
                      ) : (
                        <Icon size={18} color={kindColor[file.kind as FileKind] || '#a855f7'} />
                      )}
                    </div>

                    {/* File Title and Info */}
                    <div className="storage-file-info">
                      <div className="storage-file-name" title={file.attachment.name || file.kind}>
                        {file.attachment.name || `${kindLabel(file.kind)} file`}
                      </div>
                      <div className="storage-file-meta-row">
                        <span style={{ color: '#cbd5e1' }}>{file.chatName}</span>
                        <span>•</span>
                        <span>{file.chatType === 'group' ? 'Group' : 'Direct Chat'}</span>
                        {file.isMine && (
                          <>
                            <span>•</span>
                            <span style={{ color: '#a78bfa' }}>Sent by you</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Actions Column (Matching Image 3) */}
                  <div className="storage-file-right" onClick={(e) => e.stopPropagation()}>
                    <span className="storage-file-size">{bytes(file.size)}</span>

                    {/* Button 1: Preview / Inspect */}
                    <button
                      type="button"
                      className="storage-action-btn is-primary"
                      onClick={() => {
                        triggerHaptic('light');
                        setSelectedMedia({
                          chatKey: file.chatKey,
                          chatName: file.chatName,
                          chatType: file.chatType,
                          messageId: file.message.id,
                          name: file.attachment.name || `${kindLabel(file.kind)} file`,
                          url: file.attachment.url,
                          mime: file.attachment.mime,
                          size: file.size,
                          kind: file.kind as FileKind,
                          isMine: file.isMine,
                        });
                      }}
                      title="Open Media Preview"
                    >
                      {file.kind === 'images' ? (
                        <Eye size={14} />
                      ) : file.kind === 'audio' ? (
                        isPlaying ? <Pause size={14} /> : <Play size={14} />
                      ) : (
                        <ExternalLink size={14} />
                      )}
                    </button>

                    {/* Button 2: Download */}
                    <button
                      type="button"
                      className="storage-action-btn"
                      onClick={() => handleDownloadFile(file.attachment.url, file.attachment.name)}
                      title="Download to computer"
                    >
                      <Download size={14} />
                    </button>

                    {/* Button 3: Open in Chat */}
                    <button
                      type="button"
                      className="storage-action-btn"
                      onClick={() => handleJumpToChat(file.chatKey)}
                      title="Jump to this message in chat"
                    >
                      <MessageSquare size={14} />
                    </button>

                    {/* Button 4: Delete for everyone (if mine) */}
                    {file.isMine && (
                      <button
                        type="button"
                        className="storage-action-btn is-delete"
                        onClick={() =>
                          setPendingDelete({
                            chatKey: file.chatKey,
                            chatName: file.chatName,
                            messageId: file.message.id,
                            name: file.attachment.name,
                            mime: file.attachment.mime,
                            size: file.size,
                            kind: file.kind,
                            chatType: file.chatType,
                            isMine: true,
                          })
                        }
                        title="Delete for everyone in chat"
                      >
                        <Trash2 size={14} />
                      </button>
                    )}
                  </div>
                </div>
              );
            })}

            {visibleFiles.length === 0 && (
              <div style={{ padding: '36px', textAlign: 'center', color: '#64748b', fontSize: '0.86rem' }}>
                No matching media files found.
              </div>
            )}
          </div>
        ) : (
          /* Gallery Grid View Rendering */
          <div className="storage-gallery-grid">
            {visibleFiles.map((file) => {
              const Icon = kindIcon(file.kind);
              const isPlaying = playingAudioId === file.message.id;
              const hasUrl = Boolean(file.attachment.url);

              return (
                <div
                  key={`${file.chatKey}:${file.message.id}`}
                  className="storage-gallery-card"
                  onClick={() => {
                    triggerHaptic('light');
                    setSelectedMedia({
                      chatKey: file.chatKey,
                      chatName: file.chatName,
                      chatType: file.chatType,
                      messageId: file.message.id,
                      name: file.attachment.name || `${kindLabel(file.kind)} file`,
                      url: file.attachment.url,
                      mime: file.attachment.mime,
                      size: file.size,
                      kind: file.kind as FileKind,
                      isMine: file.isMine,
                    });
                  }}
                  title="Click to preview & view actions"
                >
                  {/* Gallery Preview Box */}
                  <div className="storage-gallery-preview">
                    <span className="storage-gallery-size-badge">{bytes(file.size)}</span>
                    {file.kind === 'images' && hasUrl ? (
                      <img
                        src={file.attachment.url}
                        alt={file.attachment.name}
                        loading="lazy"
                        onError={(e) => {
                          (e.currentTarget as HTMLImageElement).style.display = 'none';
                        }}
                      />
                    ) : file.kind === 'audio' ? (
                      <div
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          gap: 6,
                          color: isPlaying ? '#34d399' : '#a855f7',
                        }}
                      >
                        <div
                          style={{
                            width: 44,
                            height: 44,
                            borderRadius: '50%',
                            background: isPlaying ? 'rgba(52, 211, 153, 0.2)' : 'rgba(168, 85, 247, 0.15)',
                            display: 'grid',
                            placeItems: 'center',
                          }}
                        >
                          {isPlaying ? <Pause size={22} /> : <Play size={22} />}
                        </div>
                        <span style={{ fontSize: '0.72rem', fontWeight: 600 }}>
                          {isPlaying ? 'Playing Audio' : 'Voice Note'}
                        </span>
                      </div>
                    ) : (
                      <div
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          gap: 6,
                          color: kindColor[file.kind as FileKind] || '#a855f7',
                        }}
                      >
                        <Icon size={28} />
                        <span style={{ fontSize: '0.72rem', fontWeight: 600 }}>Document</span>
                      </div>
                    )}
                  </div>

                  {/* Body & Actions */}
                  <div className="storage-gallery-body" onClick={(e) => e.stopPropagation()}>
                    <div className="storage-gallery-title" title={file.attachment.name}>
                      {file.attachment.name || `${kindLabel(file.kind)} file`}
                    </div>
                    <div className="storage-gallery-meta">{file.chatName}</div>

                    <div className="storage-gallery-actions">
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          type="button"
                          className="storage-action-btn is-primary"
                          onClick={() => {
                            setSelectedMedia({
                              chatKey: file.chatKey,
                              chatName: file.chatName,
                              chatType: file.chatType,
                              messageId: file.message.id,
                              name: file.attachment.name || `${kindLabel(file.kind)} file`,
                              url: file.attachment.url,
                              mime: file.attachment.mime,
                              size: file.size,
                              kind: file.kind as FileKind,
                              isMine: file.isMine,
                            });
                          }}
                          title="Preview"
                        >
                          <Eye size={13} />
                        </button>
                        <button
                          type="button"
                          className="storage-action-btn"
                          onClick={() => handleDownloadFile(file.attachment.url, file.attachment.name)}
                          title="Download"
                        >
                          <Download size={13} />
                        </button>
                        <button
                          type="button"
                          className="storage-action-btn"
                          onClick={() => handleJumpToChat(file.chatKey)}
                          title="Open in Chat"
                        >
                          <MessageSquare size={13} />
                        </button>
                      </div>

                      {file.isMine && (
                        <button
                          type="button"
                          className="storage-action-btn is-delete"
                          onClick={() =>
                            setPendingDelete({
                              chatKey: file.chatKey,
                              chatName: file.chatName,
                              messageId: file.message.id,
                              name: file.attachment.name,
                              mime: file.attachment.mime,
                              size: file.size,
                              kind: file.kind,
                              chatType: file.chatType,
                              isMine: true,
                            })
                          }
                          title="Delete for everyone"
                        >
                          <Trash2 size={13} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}

            {visibleFiles.length === 0 && (
              <div style={{ gridColumn: '1 / -1', padding: '36px', textAlign: 'center', color: '#64748b', fontSize: '0.86rem' }}>
                No matching media files found.
              </div>
            )}
          </div>
        )}
      </article>

      {/* 5. Backup & Export Center */}
      <div className="storage-two-columns">
        {/* Export Card */}
        <article className="storage-card-modern">
          <div className="storage-header-left" style={{ marginBottom: 12 }}>
            <div
              className="storage-header-icon"
              style={{ background: 'rgba(99, 102, 241, 0.12)', color: '#818cf8', borderColor: 'rgba(99, 102, 241, 0.3)' }}
            >
              <Download size={20} />
            </div>
            <div className="storage-header-info">
              <h3>Export Chat Data</h3>
              <p>Download full archives of your conversations and contacts.</p>
            </div>
          </div>

          <div className="storage-badge-archive">
            📦 {conversations.length} Active Conversations • {inventory.files.length} Shared Attachments
          </div>

          <p style={{ margin: '0 0 16px', color: '#94a3b8', fontSize: '0.82rem', lineHeight: 1.55 }}>
            Export messages and contacts currently loaded in this browser. Keep these files in a secure location.
          </p>

          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <button
              type="button"
              className="storage-btn-export-json"
              onClick={exportJsonData}
            >
              <Download size={15} /> Export JSON Archive
            </button>
            <button
              type="button"
              className="storage-btn-export-txt"
              onClick={exportTextLog}
            >
              <FileText size={15} /> Export Text Log
            </button>
          </div>
        </article>

        {/* Protection / Disclaimer Card */}
        <article
          className="storage-card-modern storage-card-security-keys"
        >
          <div>
            <div className="storage-header-left" style={{ marginBottom: 12 }}>
              <div
                className="storage-header-icon is-security-amber"
              >
                <Shield size={20} />
              </div>
              <div className="storage-header-info">
                <h3 className="storage-keys-title">Browser Data &amp; Encryption Keys</h3>
                <p>Understanding site data safety.</p>
              </div>
            </div>

            <div className="storage-badge-security-status">
              <ShieldCheck size={14} /> ZERO-KNOWLEDGE KEYS PRESERVED
            </div>

            <p style={{ margin: '0 0 16px', color: '#94a3b8', fontSize: '0.84rem', lineHeight: 1.55 }}>
              Clearing temporary cache using Novyn's storage controls preserves your cryptographic identity and E2EE keys.
              Resetting your entire browser site cookies will require restoring your keys via <strong>Security &gt; Sync Message Keys</strong>.
            </p>
          </div>

          <div>
            <button
              type="button"
              className="storage-btn-security"
              onClick={() => {
                triggerHaptic('light');
                navigateTo({ tab: 'settings', category: 'security', subSection: 'security-dashboard' });
              }}
            >
              <span>Manage Keys in Security</span>
              <ArrowRight size={13} />
            </button>
          </div>
        </article>
      </div>

      {/* Quick Clean Granular Modal */}
      {isCleanModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          className="storage-clean-modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget && !busy) setIsCleanModalOpen(false);
          }}
        >
          <div className="storage-clean-modal">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div
                  style={{
                    width: 38,
                    height: 38,
                    borderRadius: 12,
                    background: 'rgba(168, 85, 247, 0.15)',
                    color: 'var(--primary)',
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <Trash2 size={20} />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.18rem', fontWeight: 700, color: '#ffffff' }}>
                    Clean Storage Cache
                  </h3>
                  <p style={{ margin: '2px 0 0', color: '#94a3b8', fontSize: '0.8rem' }}>
                    Select categories to remove safely
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsCleanModalOpen(false)}
                disabled={busy}
                style={{ background: 'none', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: 4 }}
              >
                <X size={18} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, margin: '18px 0 22px' }}>
              {/* Checkbox 1: Thumbnails */}
              <label
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: 12,
                  background: 'rgba(0, 0, 0, 0.35)',
                  border: '1px solid rgba(255, 255, 255, 0.06)',
                  cursor: 'pointer',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    type="checkbox"
                    checked={cleanThumbnails}
                    onChange={(e) => setCleanThumbnails(e.target.checked)}
                    style={{ accentColor: 'var(--primary)', width: 16, height: 16 }}
                  />
                  <div>
                    <div style={{ color: '#ffffff', fontSize: '0.86rem', fontWeight: 600 }}>Media Thumbnails</div>
                    <div style={{ color: '#64748b', fontSize: '0.74rem' }}>Cached previews and avatar photos</div>
                  </div>
                </div>
                <span style={{ color: '#a78bfa', fontSize: '0.8rem', fontWeight: 700 }}>~{bytes(photosSize * 0.4)}</span>
              </label>

              {/* Checkbox 2: Audio */}
              <label
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: 12,
                  background: 'rgba(0, 0, 0, 0.35)',
                  border: '1px solid rgba(255, 255, 255, 0.06)',
                  cursor: 'pointer',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    type="checkbox"
                    checked={cleanAudio}
                    onChange={(e) => setCleanAudio(e.target.checked)}
                    style={{ accentColor: 'var(--primary)', width: 16, height: 16 }}
                  />
                  <div>
                    <div style={{ color: '#ffffff', fontSize: '0.86rem', fontWeight: 600 }}>Temporary Voice Previews</div>
                    <div style={{ color: '#64748b', fontSize: '0.74rem' }}>Played audio voice waveforms</div>
                  </div>
                </div>
                <span style={{ color: '#a78bfa', fontSize: '0.8rem', fontWeight: 700 }}>~{bytes(audioSize * 0.6)}</span>
              </label>

              {/* Checkbox 3: Drafts */}
              <label
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: 12,
                  background: 'rgba(0, 0, 0, 0.35)',
                  border: '1px solid rgba(255, 255, 255, 0.06)',
                  cursor: 'pointer',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    type="checkbox"
                    checked={cleanDrafts}
                    onChange={(e) => setCleanDrafts(e.target.checked)}
                    style={{ accentColor: 'var(--primary)', width: 16, height: 16 }}
                  />
                  <div>
                    <div style={{ color: '#ffffff', fontSize: '0.86rem', fontWeight: 600 }}>Drafts &amp; Search Indexes</div>
                    <div style={{ color: '#64748b', fontSize: '0.74rem' }}>Unsent chat drafts and search caches</div>
                  </div>
                </div>
                <span style={{ color: '#a78bfa', fontSize: '0.8rem', fontWeight: 700 }}>~2.5 MB</span>
              </label>

              {/* Checkbox 4: Web Blobs */}
              <label
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 14px',
                  borderRadius: 12,
                  background: 'rgba(0, 0, 0, 0.35)',
                  border: '1px solid rgba(255, 255, 255, 0.06)',
                  cursor: 'pointer',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    type="checkbox"
                    checked={cleanBlobs}
                    onChange={(e) => setCleanBlobs(e.target.checked)}
                    style={{ accentColor: 'var(--primary)', width: 16, height: 16 }}
                  />
                  <div>
                    <div style={{ color: '#ffffff', fontSize: '0.86rem', fontWeight: 600 }}>Web Shell &amp; Offline Blobs</div>
                    <div style={{ color: '#64748b', fontSize: '0.74rem' }}>Temporary service worker blobs</div>
                  </div>
                </div>
                <span style={{ color: '#a78bfa', fontSize: '0.8rem', fontWeight: 700 }}>~{bytes(appCacheSize)}</span>
              </label>
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                fontSize: '0.78rem',
                color: '#10b981',
                marginBottom: 18,
              }}
            >
              <ShieldCheck size={16} /> Encryption keys and login sessions are kept safe.
            </div>

            <div style={{ display: 'flex', gap: 12 }}>
              <button
                type="button"
                className="btn btn-secondary"
                disabled={busy}
                onClick={() => setIsCleanModalOpen(false)}
                style={{ flex: 1, padding: 12, borderRadius: 12 }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={busy || (!cleanThumbnails && !cleanAudio && !cleanDrafts && !cleanBlobs)}
                onClick={handlePerformClean}
                style={{
                  flex: 1.5,
                  padding: 12,
                  borderRadius: 12,
                  background: 'var(--primary-gradient, linear-gradient(135deg, var(--primary), var(--primary-hover)))',
                  color: '#ffffff',
                  fontWeight: 600,
                }}
              >
                {busy ? 'Cleaning Cache…' : 'Clean Selected Cache'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Shared File Dialog */}
      {pendingDelete && (
        <div
          className="storage-clean-modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget && !deleting) setPendingDelete(null);
          }}
        >
          <div className="storage-clean-modal" style={{ maxWidth: 420 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 12,
                  background: 'rgba(239, 68, 68, 0.15)',
                  color: '#ef4444',
                  display: 'grid',
                  placeItems: 'center',
                }}
              >
                <Trash2 size={20} />
              </div>
              <h3 style={{ margin: 0, fontSize: '1.2rem', color: '#ef4444', fontWeight: 700 }}>
                Delete Shared File?
              </h3>
            </div>
            <p style={{ margin: '0 0 18px', color: '#94a3b8', fontSize: '0.84rem', lineHeight: 1.5 }}>
              <strong>{pendingDelete.name || 'This file'}</strong> and its message will be removed for everyone in{' '}
              <strong style={{ color: '#fff' }}>{pendingDelete.chatName}</strong>. This action cannot be reversed.
            </p>
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="btn btn-secondary"
                disabled={deleting}
                onClick={() => setPendingDelete(null)}
                style={{ flex: 1, padding: 12, borderRadius: 12 }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                disabled={deleting}
                onClick={deleteSharedFile}
                style={{
                  flex: 1.4,
                  padding: 12,
                  borderRadius: 12,
                  background: 'rgba(239, 68, 68, 0.25)',
                  borderColor: 'rgba(239, 68, 68, 0.5)',
                  color: '#ef4444',
                  fontWeight: 600,
                }}
              >
                {deleting ? 'Deleting…' : 'Delete for Everyone'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 6. Universal Media Preview Modal with 3rd Pic Action Buttons */}
      {selectedMedia && (
        <div
          className="storage-media-modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelectedMedia(null);
          }}
        >
          <div className="storage-media-modal">
            {/* Modal Header */}
            <div className="storage-media-modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
                <div
                  className="storage-media-modal-icon"
                  style={{ color: kindColor[selectedMedia.kind] || '#a855f7' }}
                >
                  {selectedMedia.kind === 'images' ? (
                    <FileImage size={20} />
                  ) : selectedMedia.kind === 'audio' ? (
                    <FileAudio2 size={20} />
                  ) : (
                    <FileText size={20} />
                  )}
                </div>
                <div style={{ minWidth: 0 }}>
                  <h3 className="storage-media-modal-title" title={selectedMedia.name}>
                    {selectedMedia.name}
                  </h3>
                  <p className="storage-media-modal-sub">
                    Shared in <strong style={{ color: '#fff' }}>{selectedMedia.chatName}</strong> •{' '}
                    {bytes(selectedMedia.size)} •{' '}
                    {selectedMedia.chatType === 'group' ? 'Group' : 'Direct Chat'}
                  </p>
                </div>
              </div>

              <button
                type="button"
                className="storage-media-modal-close"
                onClick={() => setSelectedMedia(null)}
                title="Close"
              >
                <X size={18} />
              </button>
            </div>

            {/* Media Content Stage */}
            <div className="storage-media-stage">
              {selectedMedia.kind === 'images' ? (
                <div className="storage-image-preview-wrap">
                  {selectedMedia.url ? (
                    <img src={selectedMedia.url} alt={selectedMedia.name} />
                  ) : (
                    <div style={{ color: '#94a3b8', fontSize: '0.9rem' }}>
                      Preview image not available
                    </div>
                  )}
                </div>
              ) : selectedMedia.kind === 'audio' ? (
                <div className="storage-audio-preview-card">
                  <div className="storage-audio-wave-anim">
                    {Array.from({ length: 24 }).map((_, i) => (
                      <span
                        key={i}
                        className={`storage-wave-bar ${playingAudioId === selectedMedia.messageId ? 'is-animating' : ''}`}
                        style={{ animationDelay: `${(i % 6) * 0.15}s` }}
                      />
                    ))}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                    <button
                      type="button"
                      className={`storage-audio-modal-play-btn ${playingAudioId === selectedMedia.messageId ? 'is-playing' : ''}`}
                      onClick={() => togglePlayAudio(selectedMedia.messageId, selectedMedia.url)}
                      title={playingAudioId === selectedMedia.messageId ? 'Pause' : 'Play'}
                    >
                      {playingAudioId === selectedMedia.messageId ? <Pause size={24} /> : <Play size={24} />}
                    </button>
                    <div>
                      <div style={{ color: '#ffffff', fontSize: '0.96rem', fontWeight: 600 }}>
                        {playingAudioId === selectedMedia.messageId ? 'Streaming Voice Note…' : 'Play Audio Recording'}
                      </div>
                      <div style={{ color: '#94a3b8', fontSize: '0.78rem' }}>
                        {selectedMedia.chatName} • {bytes(selectedMedia.size)}
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="storage-doc-preview-card">
                  <div className="storage-doc-icon-large">
                    <FileText size={44} />
                  </div>
                  <div style={{ color: '#ffffff', fontSize: '1.1rem', fontWeight: 700, margin: '14px 0 4px', textAlign: 'center' }}>
                    {selectedMedia.name}
                  </div>
                  <div style={{ color: '#94a3b8', fontSize: '0.82rem' }}>
                    Document Attachment • {bytes(selectedMedia.size)}
                  </div>
                </div>
              )}
            </div>

            {/* Bottom Action Bar (The 3rd Pic Buttons) */}
            <div className="storage-media-modal-actions">
              <div className="storage-preview-action-group">
                {/* 1. Open Original Button */}
                {selectedMedia.url && (
                  <button
                    type="button"
                    className="storage-modal-action-btn"
                    onClick={() => window.open(selectedMedia.url, '_blank')}
                    title="Open original file in new window"
                  >
                    <ExternalLink size={16} />
                    <span>Open Original</span>
                  </button>
                )}

                {/* 2. Download Button */}
                <button
                  type="button"
                  className="storage-modal-action-btn is-primary"
                  onClick={() => handleDownloadFile(selectedMedia.url, selectedMedia.name)}
                  title="Download file to device"
                >
                  <Download size={16} />
                  <span>Download</span>
                </button>

                {/* 3. Open in Chat Button */}
                <button
                  type="button"
                  className="storage-modal-action-btn"
                  onClick={() => {
                    setSelectedMedia(null);
                    handleJumpToChat(selectedMedia.chatKey);
                  }}
                  title="Jump to this message in chat"
                >
                  <MessageSquare size={16} />
                  <span>Open in Chat</span>
                </button>
              </div>

              {/* 4. Delete for Everyone (if user's own file) */}
              {selectedMedia.isMine && (
                <button
                  type="button"
                  className="storage-modal-action-btn is-danger"
                  onClick={() => {
                    const toDelete = {
                      chatKey: selectedMedia.chatKey,
                      chatName: selectedMedia.chatName,
                      chatType: selectedMedia.chatType,
                      messageId: selectedMedia.messageId,
                      name: selectedMedia.name,
                      mime: selectedMedia.mime,
                      size: selectedMedia.size,
                      kind: selectedMedia.kind,
                      isMine: true,
                    };
                    setSelectedMedia(null);
                    setPendingDelete(toDelete);
                  }}
                  title="Delete for everyone in chat"
                >
                  <Trash2 size={16} />
                  <span>Delete for Everyone</span>
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
