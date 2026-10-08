import { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { exportMessageKeys } from '../../services/messageKeyTransfer';

export function MessageKeyTransfer({ embedded = false }: { embedded?: boolean }) {
  const { user } = useAuth();
  const { conversations } = useChat();
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState('');
  const download = async () => {
    if (!user || busy) return;
    setBusy(true);
    setResult('');
    try {
      const file = await exportMessageKeys(user.username, conversations, password);
      const url = URL.createObjectURL(new Blob([file], { type: 'application/json' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = 'novyn-message-keys.json';
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setPassword('');
      setResult('Downloaded. Transfer this file to Android, then tap Import message keys in the chat or Security & Privacy. Enter the same transfer password there.');
    } catch (error) {
      setResult(error instanceof Error ? error.message : 'Unable to export message keys.');
    } finally {
      setBusy(false);
    }
  };
  return <section style={{ padding: embedded ? 0 : 20, borderRadius: 20, border: embedded ? undefined : '1px solid var(--border-focus)', color: 'var(--text-main)' }}>
    {!embedded && <h3>Sync encrypted messages to Android</h3>}
    <p style={{ color: 'var(--text-muted)', lineHeight: 1.6 }}>Use the browser where your messages are readable. Download a password-protected key file and import it on your phone. This enables old messages and future messages in the included conversations. Repeat for new contacts or changed contact keys.</p>
    <label style={{ display: 'block', marginBottom: 8 }} htmlFor="message-key-password">Transfer password (at least 12 characters)</label>
    <input id="message-key-password" type="password" autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} className="form-input" disabled={busy} style={{ width: '100%', marginBottom: 12 }} />
    <button className="btn btn-primary" disabled={busy || password.length < 12} onClick={() => void download()}>{busy ? 'Preparing…' : 'Download message keys'}</button>
    {result && <p role="status" style={{ lineHeight: 1.6 }}>{result}</p>}
    <p style={{ fontSize: 12, color: 'var(--text-muted)' }}>Keep this file and password private; together they unlock these conversations. Remove the transfer file after importing it. Your browser private key stays in this browser.</p>
  </section>;
}
