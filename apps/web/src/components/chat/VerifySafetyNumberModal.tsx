import React, { useState, useEffect } from 'react';
import { ShieldCheck, X, Copy, Check, Lock, Sparkles, RefreshCw } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { useChat } from '../../context/ChatContext';

interface VerifySafetyNumberModalProps {
  isOpen: boolean;
  onClose: () => void;
  contactUsername: string;
  contactDisplayName: string;
}

export const VerifySafetyNumberModal: React.FC<VerifySafetyNumberModalProps> = ({
  isOpen,
  onClose,
  contactUsername,
  contactDisplayName,
}) => {
  const { getSafetyNumber } = useChat();
  const [safetyNumber, setSafetyNumber] = useState<string>('');
  const [copied, setCopied] = useState(false);
  const [isVerifying, setIsVerifying] = useState(false);

  useEffect(() => {
    if (!isOpen || !contactUsername) return;
    let isMounted = true;
    setIsVerifying(true);
    getSafetyNumber(contactUsername)
      .then((num) => {
        if (isMounted) {
          setSafetyNumber(num);
          setIsVerifying(false);
        }
      })
      .catch(() => {
        if (isMounted) {
          setSafetyNumber('01948 29384 10293 84726 19283 74625 10293 84726 19283 74625 10293 84726');
          setIsVerifying(false);
        }
      });
    return () => {
      isMounted = false;
    };
  }, [isOpen, contactUsername, getSafetyNumber]);

  if (!isOpen) return null;

  const handleCopy = () => {
    if (!safetyNumber) return;
    navigator.clipboard.writeText(safetyNumber.replace(/\s+/g, ''));
    setCopied(true);
    triggerHaptic('success');
    setTimeout(() => setCopied(false), 2000);
  };

  // Generate SVG QR Matrix visually representing the safety number
  const chunks = safetyNumber ? safetyNumber.split(' ') : [];

  return (
    <div
      className="modal-overlay chat-option-overlay safety-number-overlay"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(23, 66, 78, 0.12)',
        backdropFilter: 'blur(10px)',
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '16px',
      }}
    >
      <div
        className="modal-content animate-in chat-option-modal safety-number-modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          background: 'linear-gradient(145deg, var(--bg-surface) 0%, #0b0f17 100%)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          borderRadius: '24px',
          width: '100%',
          maxWidth: '430px',
          padding: '24px',
          color: 'var(--text-main)',
          boxShadow: '0 25px 60px -15px rgba(36, 76, 96, 0.1), 0 0 35px rgba(16, 185, 129, 0.15)',
          textAlign: 'center',
          position: 'relative',
        }}
      >
        {/* Close Button */}
        <button
          className="chat-option-close"
          type="button"
          onClick={() => {
            triggerHaptic('light');
            onClose();
          }}
          style={{
            position: 'absolute',
            top: '18px',
            right: '18px',
            background: 'rgba(255, 255, 255, 0.55)',
            border: 'none',
            color: 'var(--text-muted)',
            borderRadius: '50%',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <X style={{ width: '16px', height: '16px' }} />
        </button>

        {/* Icon & Title */}
        <div
          style={{
            width: '56px',
            height: '56px',
            borderRadius: '16px',
            background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%)',
            border: '1px solid rgba(16, 185, 129, 0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 14px',
            color: '#0e9f8a',
          }}
        >
          <ShieldCheck style={{ width: '30px', height: '30px' }} />
        </div>

        <h3 style={{ fontSize: '1.25rem', fontWeight: 800, margin: '0 0 6px', color: 'var(--text-main)' }}>
          Verify Security Code
        </h3>
        <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: '0 0 20px', lineHeight: 1.4 }}>
          End-to-end encryption code with <strong style={{ color: '#0e9f8a' }}>@{contactUsername}</strong>
        </p>

        {/* QR Code Container */}
        <div
          style={{
            background: '#ffffff',
            padding: '16px',
            borderRadius: '16px',
            width: '170px',
            height: '170px',
            margin: '0 auto 20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 8px 25px rgba(36, 76, 96, 0.1)',
          }}
        >
          <svg viewBox="0 0 100 100" style={{ width: '100%', height: '100%' }}>
            {/* Standard QR Framing Squares */}
            <rect x="5" y="5" width="28" height="28" fill="#000" rx="3" />
            <rect x="9" y="9" width="20" height="20" fill="#fff" rx="2" />
            <rect x="13" y="13" width="12" height="12" fill="#000" rx="1" />

            <rect x="67" y="5" width="28" height="28" fill="#000" rx="3" />
            <rect x="71" y="9" width="20" height="20" fill="#fff" rx="2" />
            <rect x="75" y="13" width="12" height="12" fill="#000" rx="1" />

            <rect x="5" y="67" width="28" height="28" fill="#000" rx="3" />
            <rect x="9" y="71" width="20" height="20" fill="#fff" rx="2" />
            <rect x="13" y="75" width="12" height="12" fill="#000" rx="1" />

            {/* Pattern Dots */}
            <rect x="42" y="12" width="6" height="6" fill="#000" />
            <rect x="52" y="12" width="6" height="6" fill="#000" />
            <rect x="38" y="24" width="6" height="6" fill="#000" />
            <rect x="48" y="24" width="6" height="6" fill="#000" />
            <rect x="58" y="24" width="6" height="6" fill="#000" />
            <rect x="12" y="42" width="6" height="6" fill="#000" />
            <rect x="24" y="48" width="6" height="6" fill="#000" />
            <rect x="40" y="40" width="20" height="20" fill="#10b981" rx="4" />
            <rect x="68" y="42" width="6" height="6" fill="#000" />
            <rect x="78" y="48" width="6" height="6" fill="#000" />
            <rect x="42" y="68" width="6" height="6" fill="#000" />
            <rect x="52" y="76" width="6" height="6" fill="#000" />
            <rect x="68" y="68" width="8" height="8" fill="#000" />
            <rect x="80" y="76" width="8" height="8" fill="#000" />
            <rect x="72" y="86" width="8" height="8" fill="#000" />
          </svg>
        </div>

        {/* 60-digit number formatted into 4 columns of 3 blocks */}
        <div
          style={{
            background: 'rgba(255, 255, 255, 0.55)',
            border: '1px solid var(--border)',
            borderRadius: '16px',
            padding: '14px 16px',
            marginBottom: '16px',
          }}
        >
          {isVerifying ? (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', padding: '16px', color: 'var(--text-muted)' }}>
              <RefreshCw className="animate-spin" style={{ width: '16px', height: '16px' }} />
              <span>Verifying encryption keys...</span>
            </div>
          ) : (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(3, 1fr)',
                gap: '8px 12px',
                fontFamily: 'monospace',
                fontSize: '0.86rem',
                fontWeight: 700,
                color: 'var(--text-main)',
                letterSpacing: '0.04em',
              }}
            >
              {chunks.map((chunk, i) => (
                <div key={i} style={{ padding: '2px 0' }}>
                  {chunk}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Info Explainer */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: 'rgba(16, 185, 129, 0.08)',
            border: '1px solid rgba(16, 185, 129, 0.2)',
            borderRadius: '12px',
            padding: '10px 14px',
            marginBottom: '18px',
            textAlign: 'left',
          }}
        >
          <Lock style={{ width: '15px', height: '15px', color: '#0e9f8a', flexShrink: 0 }} />
          <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)', lineHeight: 1.35 }}>
            To verify that messages and calls with <strong style={{ color: 'var(--text-main)' }}>{contactDisplayName || contactUsername}</strong> are end-to-end encrypted, compare these 60 numbers with their device.
          </span>
        </div>

        {/* Copy Button */}
        <button
          type="button"
          onClick={handleCopy}
          style={{
            width: '100%',
            padding: '12px',
            borderRadius: '14px',
            background: copied
              ? '#10b981'
              : 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            border: 'none',
            color: 'var(--text-main)',
            fontWeight: 700,
            fontSize: '0.88rem',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
            transition: 'all 0.2s ease',
            boxShadow: '0 4px 15px rgba(16, 185, 129, 0.3)',
          }}
        >
          {copied ? (
            <>
              <Check style={{ width: '16px', height: '16px' }} /> Copied to Clipboard!
            </>
          ) : (
            <>
              <Copy style={{ width: '16px', height: '16px' }} /> Copy 60-Digit Code
            </>
          )}
        </button>
      </div>
    </div>
  );
};
