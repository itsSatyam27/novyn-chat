import { useCallback, useEffect, useState, type CSSProperties } from 'react';
import { ArrowRight, Download, ShieldCheck, TriangleAlert } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { getMyPublicKeyJwk } from '../../services/e2ee';
import { MessageKeyTransferDialog } from '../chat/MessageKeyTransferDialog';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

const bytes = (value: number | undefined) => {
  if (value === undefined) return 'Unavailable';
  const unit = value >= 1024 ** 3 ? 3 : value >= 1024 ** 2 ? 2 : value >= 1024 ? 1 : 0;
  return `${(value / 1024 ** unit).toLocaleString(undefined, { maximumFractionDigits: 1 })} ${['B', 'KB', 'MB', 'GB'][unit]}`;
};

export function StorageDashboard() {
  const { user } = useAuth();
  const { conversations, messages } = useChat();
  const [estimate, setEstimate] = useState<StorageEstimate | null>(null);
  const [loading, setLoading] = useState(true);
  const [keysReady, setKeysReady] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [showKeys, setShowKeys] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);
  const refreshStorage = useCallback(async () => {
    try { setEstimate(await navigator.storage?.estimate?.() || null); }
    catch { setEstimate(null); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => {
    void refreshStorage();
    let cancelled = false;
    getMyPublicKeyJwk().then(key => { if (!cancelled) setKeysReady(Boolean(key)); })
      .catch(() => { if (!cancelled) setKeysReady(false); });
    return () => { cancelled = true; };
  }, [refreshStorage, user?.username]);

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
  const percent = usage !== undefined && quota ? Math.min(100, Math.max(0, usage / quota * 100)) : 0;
  const https = window.location.protocol === 'https:';

  return <section className="web-settings storage-dashboard" aria-label="Data and storage settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
    <div className="storage-grid">
      <article className="storage-card storage-usage-card">
        <span className="storage-eyebrow">Storage</span>
        <h3>Clear temporary web files</h3>
        <p>Refresh cached web assets. Your messages, encryption keys, saved notes, preferences and sign-in stay available.</p>
        <div className="storage-usage-summary">
          <div className="storage-donut" style={{ '--storage-used': `${percent}%` } as CSSProperties} role="img" aria-label={loading ? 'Checking browser storage' : usage === undefined ? 'Storage estimate unavailable' : `${bytes(usage)} of ${bytes(quota)} browser storage used`}>
            <div><strong>{loading ? '…' : usage === undefined ? '—' : bytes(usage)}</strong><span>{loading ? 'Checking storage' : 'Estimated usage'}</span></div>
          </div>
          <dl className="storage-legend"><div><dt><i />Used storage</dt><dd>{bytes(usage)}</dd></div><div><dt><i />Available space</dt><dd>{quota !== undefined && usage !== undefined ? bytes(Math.max(0, quota - usage)) : 'Unavailable'}</dd></div><div><dt>Browser allowance</dt><dd>{bytes(quota)}</dd></div></dl>
        </div>
        <button type="button" className="btn btn-primary" disabled={busy} onClick={() => void clearTemporary()}>{busy ? 'Clearing…' : 'Clear temporary files'}</button>
        <p className="storage-footnote">Estimates cover this site’s browser storage, including data kept when temporary files are cleared.</p>
      </article>
      <article className="storage-card storage-export-card">
        <span className="storage-eyebrow">Export</span><h3>Download your chat data</h3>
        <p>Profile, chat list and messages currently loaded in this browser. Not your full history or encryption keys.</p>
        <div className="storage-export-actions"><button type="button" className="btn btn-primary" onClick={exportData}><Download size={16} aria-hidden="true" />Download chat data</button><small>May contain readable messages. Keep the file private.</small></div>
      </article>
      <article className="storage-card storage-security-card">
        <span className="storage-security-symbol"><ShieldCheck size={28} aria-hidden="true" /></span>
        <div><span className="storage-eyebrow">Encryption status</span><h3>Your message keys stay in your browser</h3><p>Encrypted conversations use your browser’s encryption identity.</p>
          <div className="storage-badges"><span>{keysReady === null ? 'Browser keys · Checking' : keysReady ? 'Browser keys · Ready' : 'Browser keys · Not ready'}</span><span>{https ? 'HTTPS · Active' : 'HTTP · No TLS'}</span></div>
        </div>
      </article>
      <article className="storage-card storage-caution-card"><span className="storage-caution-symbol"><TriangleAlert size={23} aria-hidden="true" /></span><div><h3>Careful with site data</h3><p>Clearing Novyn’s temporary files preserves your keys. Clearing all site data through your browser can remove them.</p></div></article>
      <article className="storage-card storage-sync-card"><div><h3>Sync message keys</h3><p>Transfer conversation keys to Android.</p></div><button type="button" aria-haspopup="dialog" onClick={() => setShowKeys(true)}>Open<ArrowRight size={17} aria-hidden="true" /></button></article>
    </div>
    <MessageKeyTransferDialog isOpen={showKeys} onClose={() => setShowKeys(false)} />
  </section>;
}
