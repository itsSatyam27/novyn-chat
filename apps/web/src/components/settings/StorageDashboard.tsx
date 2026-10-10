import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react';
import { Download, FileAudio2, FileImage, FileText, FileVideo2, Search, Trash2, TriangleAlert, X } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { getSocket } from '../../services/socket';
import type { Attachment, Message } from '../../types';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

const bytes = (value: number | undefined) => {
  if (value === undefined) return 'Unavailable';
  const unit = value >= 1024 ** 3 ? 3 : value >= 1024 ** 2 ? 2 : value >= 1024 ? 1 : 0;
  return `${(value / 1024 ** unit).toLocaleString(undefined, { maximumFractionDigits: 1 })} ${['B', 'KB', 'MB', 'GB'][unit]}`;
};

type FileKind = 'images' | 'videos' | 'audio' | 'documents';
type InventoryFile = { chatKey: string; chatName: string; messageId: string; name: string; mime: string; size: number; kind: string; chatType: 'friend' | 'group'; isMine: boolean; timestamp?: string | number };
const kindLabel = (kind: string) => kind === 'images' ? 'Photos' : kind === 'videos' ? 'Videos' : kind === 'audio' ? 'Voice & audio' : 'Documents';
const kindIcon = (kind: string) => kind === 'images' ? FileImage : kind === 'videos' ? FileVideo2 : kind === 'audio' ? FileAudio2 : FileText;
const kindColor: Record<FileKind, string> = { images: '#a855f7', videos: '#38bdf8', audio: '#34d399', documents: '#f59e0b' };

export function StorageDashboard() {
  const { user } = useAuth();
  const { conversations, messages, activeChat, getLoadedMessageSnapshot } = useChat();
  const [estimate, setEstimate] = useState<StorageEstimate | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const [mediaFilter, setMediaFilter] = useState('all');
  const [selectedChat, setSelectedChat] = useState<string | null>(null);
  const [fileQuery, setFileQuery] = useState('');
  const [serverFiles, setServerFiles] = useState<InventoryFile[] | null>(null);
  const [inventoryLoading, setInventoryLoading] = useState(false);
  const [inventoryError, setInventoryError] = useState('');
  const [pendingDelete, setPendingDelete] = useState<InventoryFile | null>(null);
  const [deleting, setDeleting] = useState(false);
  const dismissNotice = useCallback(() => setNotice(null), []);
  const refreshStorage = useCallback(async () => {
    try { setEstimate(await navigator.storage?.estimate?.() || null); }
    catch { setEstimate(null); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void refreshStorage(); }, [refreshStorage]);
  const refreshInventory = useCallback(() => {
    const socket = getSocket();
    if (!socket?.connected) { setInventoryError('Connect to Novyn to load all chat files.'); return; }
    setInventoryLoading(true); setInventoryError('');
    socket.timeout(15000).emit('get_storage_inventory', (error: Error | null, response: any) => {
      setInventoryLoading(false);
      if (error || !response?.ok || !Array.isArray(response.files)) {
        setInventoryError(response?.message || 'Could not load all chat storage. Try refreshing.');
        return;
      }
      setServerFiles(response.files);
    });
  }, []);
  useEffect(() => { refreshInventory(); }, [refreshInventory]);
  const deleteSharedFile = () => {
    if (!pendingDelete || deleting) return;
    const socket = getSocket();
    if (!socket?.connected) { setNotice({ text: 'Reconnect to Novyn before deleting this file.', error: true }); return; }
    setDeleting(true);
    socket.timeout(12000).emit('delete_message', { messageId: pendingDelete.messageId, to: pendingDelete.chatKey, toType: pendingDelete.chatType }, (error: Error | null, result: any) => {
      setDeleting(false);
      if (error || !result?.ok) {
        setNotice({ text: result?.message || 'Could not delete this file. Please try again.', error: true });
        return;
      }
      setNotice({ text: 'File and its message were removed for everyone in the chat.', error: false });
      setPendingDelete(null);
      refreshInventory();
    });
  };

  const clearTemporary = async () => {
    if (busy) return;
    setBusy(true); setNotice(null);
    try {
      if ('caches' in window) {
        const names = await caches.keys();
        await Promise.all(names.filter(name => name.startsWith('novyn-shell-')).map(name => caches.delete(name)));
      }
      Object.keys(localStorage).filter(key => key.startsWith('novyn_cache_')).forEach(key => localStorage.removeItem(key));
      await refreshStorage();
      setNotice({ text: 'Temporary web files cleared.', error: false });
    } catch { setNotice({ text: 'Could not clear all temporary files. Please try again.', error: true }); }
    finally { setBusy(false); }
  };
  const exportData = () => {
    try {
      const content = JSON.stringify({ format: 'novyn-chat-export', version: 1, exportedAt: new Date().toISOString(),
        profile: { username: user?.username, displayName: user?.displayName, email: user?.email, bio: user?.bio },
        conversations, loadedMessages: messages }, null, 2);
      const url = URL.createObjectURL(new Blob([content], { type: 'application/json' }));
      const link = document.createElement('a'); link.href = url; link.download = 'novyn-chat-data.json'; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setNotice({ text: 'Chat data download started.', error: false });
    } catch { setNotice({ text: 'Could not prepare your chat data. Please try again.', error: true }); }
  };
  const usage = estimate?.usage;
  const quota = estimate?.quota;

  // This inventory uses attachment size metadata from histories loaded in this session.
  // It is intentionally separate from navigator.storage, which reports origin-wide local usage.
  const inventory = useMemo(() => {
    const snapshot = getLoadedMessageSnapshot();
    if (activeChat) snapshot[activeChat.toLowerCase()] = messages;
    if (user?.username) {
      try {
        const saved = JSON.parse(localStorage.getItem(`novyn_saved_messages_${user.username.toLowerCase()}`) || '[]');
        if (Array.isArray(saved)) snapshot[user.username.toLowerCase()] = saved;
      } catch { /* Ignore malformed local notes. */ }
    }
    const names = new Map(conversations.map(conversation => [conversation.username.toLowerCase(), conversation.displayName || conversation.username]));
    const unique = new Map<string, { message: Message; attachment: Attachment; chatKey: string; chatType: 'friend' | 'group'; isMine: boolean }>();
    if (serverFiles) {
      for (const file of serverFiles) unique.set(`${file.chatKey}:${file.messageId}`, {
        chatKey: file.chatKey,
        message: { id: file.messageId, timestamp: file.timestamp || '', sender: '', receiver: '', text: '', status: 'sent' } as Message,
        attachment: { url: '', name: file.name, mime: file.mime, size: file.size, kind: file.kind === 'audio' ? 'audio' : file.kind === 'image' ? 'image' : 'file' },
        chatType: file.chatType,
        isMine: file.isMine,
      });
    } else {
      for (const [chatKey, list] of Object.entries(snapshot)) {
        for (const message of list || []) if (message.attachment?.url) unique.set(`${chatKey}:${message.id}`, { message, attachment: message.attachment, chatKey, chatType: conversations.find(conversation => conversation.username.toLowerCase() === chatKey)?.isGroup ? 'group' : 'friend', isMine: message.sender?.toLowerCase() === user?.username?.toLowerCase() });
      }
    }
    const files = [...unique.values()].map(item => {
      const mime = item.attachment.mime?.toLowerCase() || '';
      const kind: FileKind = item.message.isVoice || item.attachment.kind === 'audio' || mime.startsWith('audio/') ? 'audio'
        : mime.startsWith('image/') || item.attachment.kind === 'image' ? 'images'
        : mime.startsWith('video/') ? 'videos' : 'documents';
      const selfKey = user?.username?.toLowerCase();
      return { ...item, kind, size: Math.max(0, Number(item.attachment.size) || 0), chatName: names.get(item.chatKey) || (item.chatKey === selfKey ? 'Saved Messages' : item.chatKey) };
    });
    const categories = (['images', 'videos', 'audio', 'documents'] as FileKind[]).map(kind => {
      const items = files.filter(file => file.kind === kind);
      return { kind, count: items.length, size: items.reduce((sum, file) => sum + file.size, 0) };
    });
    const chatMap = new Map<string, { key: string; name: string; count: number; size: number }>();
    for (const file of files) {
      const current = chatMap.get(file.chatKey) || { key: file.chatKey, name: file.chatName, count: 0, size: 0 };
      current.count += 1; current.size += file.size; chatMap.set(file.chatKey, current);
    }
    const chats = [...chatMap.values()].sort((a, b) => b.size - a.size);
    return { files: files.sort((a, b) => b.size - a.size), categories, chats, total: files.reduce((sum, file) => sum + file.size, 0) };
  }, [activeChat, conversations, getLoadedMessageSnapshot, messages, serverFiles, user?.username]);
  const selectedCategory = inventory.categories.find(category => category.kind === mediaFilter);
  const selectedChatData = inventory.chats.find(chat => chat.key === selectedChat);
  const selectedUsage = selectedChatData || selectedCategory;
  const selectedLabel = selectedChatData?.name || (selectedCategory ? kindLabel(selectedCategory.kind) : 'All shared files');
  const selectedSize = selectedUsage?.size ?? inventory.total;
  const selectedShare = inventory.total ? Math.min(100, selectedSize / inventory.total * 100) : 0;
  const graphFiles = selectedChat ? inventory.files.filter(file => file.chatKey === selectedChat)
    : mediaFilter === 'all' ? inventory.files : inventory.files.filter(file => file.kind === mediaFilter);
  const graphTotal = graphFiles.reduce((sum, file) => sum + file.size, 0);
  let graphOffset = 0;
  const graphStops = (['images', 'videos', 'audio', 'documents'] as FileKind[]).map(kind => {
    const size = graphFiles.filter(file => file.kind === kind).reduce((sum, file) => sum + file.size, 0);
    const start = graphOffset;
    graphOffset += graphTotal ? size / graphTotal * 100 : 0;
    return size > 0 ? `${kindColor[kind]} ${start}% ${graphOffset}%` : '';
  }).filter(Boolean);
  const graphBackground = graphStops.length ? `conic-gradient(${graphStops.join(', ')})` : 'conic-gradient(var(--border) 0% 100%)';
  const visibleFiles = inventory.files.filter(file => (mediaFilter === 'all' || file.kind === mediaFilter)
    && (!selectedChat || file.chatKey === selectedChat)
    && (!fileQuery || `${file.attachment.name} ${file.chatName}`.toLowerCase().includes(fileQuery.toLowerCase())));

  const selectAllFiles = () => { setMediaFilter('all'); setSelectedChat(null); };
  const selectFileType = (kind: string) => { setMediaFilter(kind); setSelectedChat(null); };
  const selectChat = (key: string) => { setMediaFilter('all'); setSelectedChat(key); };

  return <section className="web-settings storage-dashboard" aria-label="Data and storage settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
    <div className="storage-grid">
      <article className="storage-card storage-usage-card">
        <div className="storage-primary-graph">
          <span className="storage-eyebrow">Storage breakdown</span><h3>{selectedLabel}</h3>
          <p>Choose a file type or chat to inspect its shared file usage.</p>
          <div className="storage-donut storage-donut-interactive" style={{ background: graphBackground } as CSSProperties} role="img" aria-label={`${bytes(selectedSize)} ${selectedLabel}, ${selectedShare.toFixed(1)} percent of known shared files. Photos purple, videos blue, audio green, documents orange.`}>
            <div><strong>{bytes(selectedSize)}</strong><span>{selectedShare.toFixed(1)}% of known total</span></div>
          </div>
          <span className="storage-selected-count">{selectedUsage ? `${selectedUsage.count} ${selectedUsage.count === 1 ? 'file' : 'files'}` : `${inventory.files.length} files across loaded chats`}</span>
          <div className="storage-browser-meta"><span>Browser storage: <b>{loading ? 'Checking…' : `${bytes(usage)} / ${bytes(quota)}`}</b></span><button type="button" disabled={busy} onClick={() => void clearTemporary()}>{busy ? 'Clearing…' : 'Clear temporary files'}</button></div>
          <small className="storage-footnote">Browser storage is measured separately from shared attachment sizes.</small>
        </div>
        <div className="storage-insight-data">
          <section className="storage-breakdown-list"><h4>By file type</h4><button type="button" className="storage-breakdown-row" aria-pressed={mediaFilter === 'all' && !selectedChat} onClick={selectAllFiles}><span><strong>All files</strong><small>{inventory.files.length} files</small></span><b>{bytes(inventory.total)}</b></button>{inventory.categories.map(category => { const Icon = kindIcon(category.kind); return <button type="button" className="storage-breakdown-row" key={category.kind} aria-pressed={mediaFilter === category.kind && !selectedChat} onClick={() => selectFileType(category.kind)}><span className="storage-breakdown-name"><i style={{ '--file-kind-color': kindColor[category.kind] } as CSSProperties}><Icon size={15} /></i><span><strong>{kindLabel(category.kind)}</strong><small>{category.count} {category.count === 1 ? 'file' : 'files'}</small></span></span><b>{bytes(category.size)}</b></button>; })}</section>
          <section className="storage-breakdown-list"><h4>By chat <small>{inventory.chats.length} chats</small></h4>{inventory.chats.length ? inventory.chats.map(chat => <button type="button" className="storage-breakdown-row" key={chat.key} aria-pressed={selectedChat === chat.key} onClick={() => selectChat(chat.key)}><span><strong>{chat.name}</strong><small>{chat.count} {chat.count === 1 ? 'file' : 'files'}</small></span><b>{bytes(chat.size)}</b></button>) : <p className="storage-inventory-empty">Usage appears as chat histories load.</p>}</section>
        </div>
      </article>
    </div>
    <section className="storage-inventory" aria-labelledby="storage-inventory-title">
      <header className="storage-inventory-heading"><div><span className="storage-eyebrow">Shared files</span><h3 id="storage-inventory-title">Storage by file type and chat</h3><p>Shows shared file sizes from your chats. This is separate from local browser downloads.</p></div><strong>{inventoryLoading ? 'Loading…' : `${bytes(inventory.total)} known`}</strong></header>
      {inventoryError && <div className="storage-inventory-error" role="status"><span>{inventoryError}</span><button type="button" onClick={refreshInventory}>Retry</button></div>}
      <div className="storage-file-browser">
        <div className="storage-file-toolbar"><h4>{selectedChatData || selectedCategory ? `Files · ${selectedLabel}` : 'File list'}</h4><label><Search size={15} /><input value={fileQuery} onChange={event => setFileQuery(event.target.value)} placeholder="Search files or chats" aria-label="Search files or chats" /></label></div>
        <div className="storage-file-list">{visibleFiles.slice(0, 60).map(file => {
          const Icon = kindIcon(file.kind);
          return <div className="storage-file-row" key={`${file.chatKey}:${file.message.id}`}><span className="storage-type-icon"><Icon size={16} /></span><span><strong>{file.attachment.name || file.kind}</strong><small>{file.chatName}</small></span><b>{bytes(file.size)}</b>{file.isMine && file.chatKey !== user?.username?.toLowerCase() && <button type="button" className="storage-file-delete" aria-label={`Delete ${file.attachment.name || 'file'} for everyone in ${file.chatName}`} title="Delete message and file for everyone" onClick={() => setPendingDelete({ chatKey: file.chatKey, chatName: file.chatName, messageId: file.message.id, name: file.attachment.name, mime: file.attachment.mime, size: file.size, kind: file.kind, chatType: file.chatType, isMine: true })}><Trash2 size={15} /></button>}</div>;
        })}{visibleFiles.length === 0 && <p className="storage-inventory-empty">No matching files in the loaded chat history.</p>}</div>
        {visibleFiles.length > 60 && <p className="storage-inventory-footnote">Showing 60 of {visibleFiles.length} files. Refine your search to find a file.</p>}
      </div>
    </section>
    <div className="storage-utility-grid">
      <article className="storage-card storage-caution-card"><span className="storage-caution-symbol"><TriangleAlert size={23} aria-hidden="true" /></span><div><h3>Careful with site data</h3><p>Clearing Novyn’s temporary files preserves your keys. Clearing all site data through your browser can remove them.</p></div></article>
      <article className="storage-card storage-export-card">
        <span className="storage-eyebrow">Export</span><h3>Download your chat data</h3>
        <p>Profile, chat list and messages currently loaded in this browser. Not your full history or encryption keys.</p>
        <div className="storage-export-actions"><button type="button" className="btn btn-primary" onClick={exportData}><Download size={16} aria-hidden="true" />Download chat data</button><small>May contain readable messages. Keep the file private.</small></div>
      </article>
    </div>
    {pendingDelete && <div className="storage-delete-backdrop" onMouseDown={event => { if (event.target === event.currentTarget && !deleting) setPendingDelete(null); }}><section className="storage-delete-dialog" role="alertdialog" aria-modal="true" aria-labelledby="storage-delete-title" aria-describedby="storage-delete-description"><header><span className="storage-delete-icon"><Trash2 size={19} /></span><button type="button" aria-label="Close confirmation" disabled={deleting} onClick={() => setPendingDelete(null)}><X size={18} /></button></header><h3 id="storage-delete-title">Delete this shared file?</h3><p id="storage-delete-description"><strong>{pendingDelete.name || 'This file'}</strong> and its message will be removed for everyone in <strong>{pendingDelete.chatName}</strong>. This can’t be undone.</p><footer><button type="button" disabled={deleting} onClick={() => setPendingDelete(null)}>Cancel</button><button type="button" className="storage-delete-confirm" disabled={deleting} onClick={deleteSharedFile}>{deleting ? 'Deleting…' : 'Delete for everyone'}</button></footer></section></div>}
  </section>;
}
