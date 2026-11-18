import React, { useEffect, useState } from 'react';
import { apiRequest } from '../../services/api';
import { acceptPairedIdentity, createWebPairingKey } from '../../services/e2ee';
import { useAuth } from '../../context/AuthContext';
import { NovynLogo } from '../ui/NovynLogo';
import './devicePairingPage.css';

type PairingState = 'loading' | 'waiting' | 'approved' | 'error';

export const DevicePairingPage: React.FC = () => {
  const { refreshSession } = useAuth();
  const [state, setState] = useState<PairingState>('loading');
  const [qr, setQr] = useState('');
  const [message, setMessage] = useState('Preparing a secure pairing request…');
  const [restart, setRestart] = useState(0);

  useEffect(() => {
    let cancelled = false;
    let timer = 0;
    let pairingId = '';
    let secret = '';
    const run = async () => {
      try {
        const temporary = await createWebPairingKey();
        const started = await apiRequest<{ ok?: boolean; id?: string; secret?: string; origin?: string; message?: string }>(
          '/api/device-pairing/start',
          { method: 'POST', body: JSON.stringify({ publicKey: temporary.publicKey }) },
        );
        if (!started.ok || !started.data.id || !started.data.secret) {
          throw new Error(started.data.message || 'Could not start device pairing.');
        }
        pairingId = started.data.id;
        secret = started.data.secret;
        const qrValue = JSON.stringify({
          type: 'novyn-device-pair-v1',
          id: pairingId,
          secret,
          publicKey: temporary.publicKey,
          origin: started.data.origin || window.location.origin,
        });
        const qrcode = await import('qrcode');
        const dataUrl = await qrcode.toDataURL(qrValue, {
          width: 280,
          margin: 2,
          color: { dark: '#17152c', light: '#ffffff' },
          errorCorrectionLevel: 'M',
        });
        if (cancelled) return;
        setQr(dataUrl);
        setState('waiting');
        setMessage('Open Security & Privacy → Pair a web device on your primary phone, then scan this code.');

        const poll = async () => {
          if (cancelled) return;
          const status = await apiRequest<{ status?: string; message?: string }>(
            `/api/device-pairing/status?id=${encodeURIComponent(pairingId)}&secret=${encodeURIComponent(secret)}`,
          );
          if (cancelled) return;
          if (!status.ok) throw new Error(status.data.message || 'Pairing request expired.');
          if (status.data.status === 'approved') {
            setState('approved');
            setMessage('Approved on your phone. Finishing secure setup…');
            const completed = await apiRequest<{
              username?: string;
              encryptedIdentity?: { senderPublicKey: string; iv: string; ciphertext: string };
              message?: string;
            }>('/api/device-pairing/complete', {
              method: 'POST',
              body: JSON.stringify({ id: pairingId, secret }),
            });
            if (!completed.ok || !completed.data.username || !completed.data.encryptedIdentity) {
              throw new Error(completed.data.message || 'Could not finish pairing.');
            }
            await acceptPairedIdentity(completed.data.username, temporary.keyPair, completed.data.encryptedIdentity);
            await refreshSession();
            return;
          }
          timer = window.setTimeout(() => { void poll().catch(fail); }, 1800);
        };
        const fail = (error: unknown) => {
          if (cancelled) return;
          setState('error');
          setMessage(error instanceof Error ? error.message : 'Device pairing failed.');
        };
        timer = window.setTimeout(() => { void poll().catch(fail); }, 1200);
      } catch (error) {
        if (cancelled) return;
        setState('error');
        setMessage(error instanceof Error ? error.message : 'Device pairing failed.');
      }
    };
    void run();
    return () => { cancelled = true; window.clearTimeout(timer); };
  }, [restart]);

  return (
    <main className="device-pair-page">
      <section className="device-pair-card">
        <div className="device-pair-brand"><NovynLogo size={42} variant="white" withBadge badgeSize={72} /></div>
        <div className="device-pair-copy">
          <span className="device-pair-eyebrow">NOVYN WEB · LINKED DEVICE</span>
          <h1>Link your browser</h1>
          <p>Your phone stays primary. Approve this browser from your Flutter app to sync your chats securely.</p>
        </div>
        <div className={`device-pair-qr ${state}`}>
          {qr ? <img src={qr} alt="Temporary Novyn device pairing QR code" /> : <div className="device-pair-spinner" />}
        </div>
        <p className={`device-pair-message ${state}`} role="status">{message}</p>
        <div className="device-pair-security"><span>●</span> Your message identity is encrypted for this browser during pairing.</div>
        {state === 'error' && <button className="device-pair-retry" onClick={() => { setQr(''); setState('loading'); setRestart(value => value + 1); }}>Try again</button>}
      </section>
    </main>
  );
};
