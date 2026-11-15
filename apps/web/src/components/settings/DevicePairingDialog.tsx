import React, { useEffect, useRef, useState } from 'react';
import { CheckCircle2, LoaderCircle, QrCode, ShieldCheck, X } from 'lucide-react';
import {
  cancelDevicePairing,
  createDevicePairingChallenge,
  pollAndCompleteDevicePairing,
  type DevicePairingChallenge,
} from '../../services/devicePairing';

export function DevicePairingDialog({
  isOpen,
  onClose,
  username,
}: {
  isOpen: boolean;
  onClose: () => void;
  username: string;
}) {
  const [challenge, setChallenge] = useState<DevicePairingChallenge | null>(null);
  const [status, setStatus] = useState<'starting' | 'waiting' | 'complete' | 'error'>('starting');
  const [message, setMessage] = useState('Creating a secure, one-time QR code…');
  const [secondsLeft, setSecondsLeft] = useState(120);
  const challengeRef = useRef<DevicePairingChallenge | null>(null);
  const completedRef = useRef(false);

  useEffect(() => {
    if (!isOpen || !username) return;
    let active = true;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let clock: ReturnType<typeof setInterval> | null = null;

    setChallenge(null);
    challengeRef.current = null;
    completedRef.current = false;
    setStatus('starting');
    setMessage('Creating a secure, one-time QR code…');
    setSecondsLeft(120);

    const start = async () => {
      try {
        const next = await createDevicePairingChallenge(username);
        if (!active) {
          void cancelDevicePairing(next.sessionId);
          return;
        }
        challengeRef.current = next;
        setChallenge(next);
        setStatus('waiting');
        setMessage('Open Novyn on Android → Settings → Security → Link a web device, then scan this QR.');
        clock = setInterval(() => {
          const left = Math.max(0, Math.ceil((next.expiresAt - Date.now()) / 1000));
          setSecondsLeft(left);
        }, 1000);

        const poll = async () => {
          if (!active || completedRef.current) return;
          if (Date.now() >= next.expiresAt) {
            setStatus('error');
            setMessage('This QR code expired. Close and open the dialog to create a new one.');
            return;
          }
          try {
            const completed = await pollAndCompleteDevicePairing(next);
            if (!active) return;
            if (completed) {
              completedRef.current = true;
              setStatus('complete');
              setMessage('Android identity verified and saved. Your previous browser key is archived for older chats.');
              if (clock) clearInterval(clock);
              return;
            }
          } catch (error) {
            if (!active) return;
            setStatus('error');
            setMessage(error instanceof Error ? error.message : 'Could not complete device pairing.');
            return;
          }
          if (active && !completedRef.current) timer = setTimeout(poll, 1800);
        };
        timer = setTimeout(poll, 1200);
      } catch (error) {
        if (!active) return;
        setStatus('error');
        setMessage(error instanceof Error ? error.message : 'Could not start device pairing.');
      }
    };

    void start();
    return () => {
      active = false;
      if (timer) clearTimeout(timer);
      if (clock) clearInterval(clock);
      const pending = challengeRef.current;
      challengeRef.current = null;
      if (pending && !completedRef.current) void cancelDevicePairing(pending.sessionId);
    };
  }, [isOpen, username]);

  if (!isOpen) return null;
  return (
    <div
      role="presentation"
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 250, background: 'rgba(5, 10, 25, .68)',
        backdropFilter: 'blur(12px)', display: 'grid', placeItems: 'center',
        padding: 18,
      }}
    >
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="device-pairing-title"
        onClick={(event) => event.stopPropagation()}
        style={{
          width: 'min(100%, 430px)', borderRadius: 24,
          background: 'var(--bg-surface, #fff)', border: '1px solid var(--border, #ddd)',
          boxShadow: '0 24px 80px rgba(0,0,0,.3)', padding: 24,
          color: 'var(--text-main, #171717)', display: 'flex',
          flexDirection: 'column', alignItems: 'center', gap: 14,
          position: 'relative',
        }}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close device pairing"
          style={{ position: 'absolute', right: 14, top: 14, border: 0, background: 'transparent', color: 'inherit', cursor: 'pointer' }}
        ><X size={19} /></button>
        <div style={{ width: 48, height: 48, borderRadius: 15, display: 'grid', placeItems: 'center', background: 'rgba(13,148,136,.12)', color: '#0d9488' }}>
          {status === 'complete' ? <CheckCircle2 size={25} /> : <QrCode size={25} />}
        </div>
        <div style={{ textAlign: 'center' }}>
          <h2 id="device-pairing-title" style={{ margin: 0, fontSize: '1.15rem', fontWeight: 800 }}>Link Android as primary</h2>
          <p style={{ margin: '6px 0 0', color: 'var(--text-muted, #777)', fontSize: '.85rem' }}>Account: @{username}</p>
        </div>

        {challenge?.qrDataUrl && status !== 'complete' ? (
          <div style={{ padding: 12, borderRadius: 18, background: '#fff', boxShadow: '0 8px 30px rgba(0,0,0,.1)' }}>
            <img src={challenge.qrDataUrl} alt="One-time Novyn device pairing QR code" width="250" height="250" style={{ display: 'block', width: 250, height: 250 }} />
          </div>
        ) : status === 'complete' ? (
          <div style={{ width: 274, height: 274, display: 'grid', placeItems: 'center', color: '#0d9488' }}>
            <CheckCircle2 size={76} />
          </div>
        ) : (
          <div style={{ width: 274, height: 274, display: 'grid', placeItems: 'center', color: 'var(--text-muted, #777)' }}>
            {status === 'error' ? <QrCode size={64} /> : <LoaderCircle size={34} />}
          </div>
        )}

        <p role="status" style={{ margin: 0, textAlign: 'center', lineHeight: 1.5, fontSize: '.88rem', color: status === 'error' ? '#dc5b5b' : 'var(--text-muted, #777)' }}>
          {message}
        </p>
        {status === 'waiting' && (
          <span style={{ fontSize: '.78rem', fontVariantNumeric: 'tabular-nums', color: 'var(--text-muted, #777)' }}>
            Expires in {Math.floor(secondsLeft / 60)}:{String(secondsLeft % 60).padStart(2, '0')}
          </span>
        )}
        <div style={{ width: '100%', borderRadius: 14, background: 'rgba(13,148,136,.08)', padding: 12, display: 'flex', gap: 9, alignItems: 'flex-start' }}>
          <ShieldCheck size={17} color="#0d9488" style={{ flexShrink: 0, marginTop: 2 }} />
          <span style={{ fontSize: '.77rem', lineHeight: 1.45, color: 'var(--text-muted, #777)' }}>
            The QR contains only a temporary public key. Android must approve the request; the primary private key is sent inside an encrypted, short-lived one-time envelope.
          </span>
        </div>
        {status === 'complete' ? (
          <button type="button" onClick={() => window.location.reload()} style={{ width: '100%', border: 0, borderRadius: 12, padding: '12px 16px', background: '#0d9488', color: '#fff', fontWeight: 800, cursor: 'pointer' }}>
            Reload Novyn Web
          </button>
        ) : (
          <button type="button" onClick={onClose} style={{ width: '100%', border: '1px solid var(--border, #ddd)', borderRadius: 12, padding: '11px 16px', background: 'transparent', color: 'inherit', fontWeight: 700, cursor: 'pointer' }}>
            Cancel
          </button>
        )}
      </section>
    </div>
  );
}
