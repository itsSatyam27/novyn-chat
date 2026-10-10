import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { QrCode, X, Copy, Check, Share2 } from 'lucide-react';
import { Avatar } from '../ui/Avatar';
import { triggerHaptic } from '../../services/capacitor';

interface QRCodeModalProps {
  isOpen: boolean;
  onClose: () => void;
  username: string;
  displayName?: string;
  avatarUrl?: string;
}

export const QRCodeModal: React.FC<QRCodeModalProps> = ({
  isOpen,
  onClose,
  username,
  displayName,
  avatarUrl,
}) => {
  const [copied, setCopied] = useState(false);
  const [qr, setQr] = useState('');
  const [qrFailed, setQrFailed] = useState(false);

  useEffect(() => {
    if (!isOpen || !username) return;
    let cancelled = false;
    setQr('');
    setQrFailed(false);
    const profileUrl = `${window.location.origin}/user/${encodeURIComponent(username)}`;
    import('qrcode').then((module) => module.toDataURL(profileUrl, {
      width: 240,
      margin: 2,
      errorCorrectionLevel: 'M',
      color: { dark: '#18152d', light: '#ffffff' },
    })).then((value) => {
      if (!cancelled) setQr(value);
    }).catch(() => {
      if (!cancelled) setQrFailed(true);
    });
    return () => { cancelled = true; };
  }, [isOpen, username]);

  if (!isOpen) return null;

  const profileUrl = `${window.location.origin}/user/${encodeURIComponent(username)}`;

  const handleCopyLink = async () => {
    try {
      await navigator.clipboard.writeText(profileUrl);
      setCopied(true);
      triggerHaptic('light');
      setTimeout(() => setCopied(false), 1500);
    } catch (_) {}
  };

  return (
    <AnimatePresence>
      <div
        className="chat-option-overlay qr-code-overlay"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(10px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 100,
          padding: '16px',
        }}
        onClick={onClose}
      >
        <motion.div
          className="chat-option-modal qr-code-modal"
          initial={{ opacity: 0, scale: 0.92, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.92, y: 12 }}
          transition={{ duration: 0.18 }}
          style={{
            width: '100%',
            maxWidth: '380px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '24px',
            boxShadow: '0 25px 50px -12px rgba(36, 76, 96, 0.1)',
            padding: '28px 24px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '16px',
            position: 'relative',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            className="chat-option-close"
            type="button"
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              background: 'none',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              padding: '4px',
            }}
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>

          {/* User Profile Banner */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
            <Avatar name={displayName || username} avatarUrl={avatarUrl} size="lg" />
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)' }}>
                {displayName || username}
              </div>
              <div style={{ fontSize: '0.82rem', color: '#0e9f8a', fontWeight: 600 }}>
                @{username}
              </div>
            </div>
          </div>

          {/* Procedural QR Code Card */}
          <div
            className="qr-code-card"
            style={{
              background: '#ffffff',
              padding: '16px',
              borderRadius: '18px',
              boxShadow: '0 10px 30px rgba(36, 76, 96, 0.1)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {qr ? <img src={qr} alt={`Scannable profile QR code for @${username}`} style={{ width: '180px', height: '180px', display: 'block' }} />
              : <span role={qrFailed ? 'alert' : 'status'} style={{ width: '180px', height: '180px', display: 'grid', placeItems: 'center', color: '#625a80', fontSize: '.8rem', textAlign: 'center' }}>{qrFailed ? 'Could not create QR code.' : 'Creating QR code…'}</span>}
          </div>

          <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', textAlign: 'center', maxWidth: '260px' }}>
            Scan with any camera to add @{username} on Novyn Chat
          </span>

          {/* Action Buttons */}
          <div style={{ display: 'flex', gap: '10px', width: '100%', marginTop: '4px' }}>
            <button
              className="chat-option-secondary"
              type="button"
              onClick={handleCopyLink}
              style={{
                flex: 1,
                padding: '10px 14px',
                borderRadius: '12px',
                background: copied ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.55)',
                border: `1px solid ${copied ? '#10b981' : 'var(--border)'}`,
                color: copied ? '#0e9f8a' : 'var(--text-main)',
                fontSize: '0.84rem',
                fontWeight: 700,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '6px',
                transition: 'all 0.15s ease',
              }}
            >
              {copied ? (
                <>
                  <Check style={{ width: '14px', height: '14px' }} /> Copied Link!
                </>
              ) : (
                <>
                  <Copy style={{ width: '14px', height: '14px' }} /> Copy Link
                </>
              )}
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
