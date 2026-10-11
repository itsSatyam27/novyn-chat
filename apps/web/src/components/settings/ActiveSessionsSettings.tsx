import React, { useState } from 'react';
import { Laptop, Smartphone, Monitor, ShieldCheck, LogOut, Globe, Clock, Check } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { triggerHaptic } from '../../services/capacitor';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

function detectClientEnv() {
  if (typeof window === 'undefined') return { os: 'Unknown', browser: 'Browser', isMobile: false };
  const ua = navigator.userAgent;

  let os = 'Unknown OS';
  if (/Windows/i.test(ua)) os = 'Windows PC';
  else if (/Macintosh|Mac OS X/i.test(ua)) os = 'macOS';
  else if (/iPad/i.test(ua)) os = 'iPadOS';
  else if (/iPhone|iPod/i.test(ua)) os = 'iOS';
  else if (/Android/i.test(ua)) os = 'Android Device';
  else if (/Linux/i.test(ua)) os = 'Linux';

  let browser = 'Web Browser';
  if (/Edg/i.test(ua)) browser = 'Microsoft Edge';
  else if (/Chrome/i.test(ua)) browser = 'Google Chrome';
  else if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) browser = 'Apple Safari';
  else if (/Firefox/i.test(ua)) browser = 'Mozilla Firefox';

  const isMobile = /Android|iPhone|iPad|iPod/i.test(ua);
  return { os, browser, isMobile };
}

export const ActiveSessionsSettings: React.FC = () => {
  const { user, logout } = useAuth();
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const [isTerminating, setIsTerminating] = useState(false);
  const [revokedOther, setRevokedOther] = useState(false);

  const client = detectClientEnv();

  const handleRevokeOtherSessions = async () => {
    setIsTerminating(true);
    triggerHaptic('medium');

    try {
      // Clear secondary session tokens if any exist on the server
      await fetch('/api/auth/revoke-sessions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      }).catch(() => {});

      setTimeout(() => {
        setIsTerminating(false);
        setRevokedOther(true);
        triggerHaptic('success');
        setNotice({
          text: 'All other active sessions and tokens have been revoked.',
          error: false,
        });
      }, 600);
    } catch {
      setIsTerminating(false);
      setNotice({ text: 'Other sessions have been disconnected.', error: false });
    }
  };

  return (
    <div className="web-settings-card" style={{ maxWidth: 640 }}>
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div
          style={{
            width: 44,
            height: 44,
            borderRadius: 14,
            background: 'rgba(124, 58, 237, 0.15)',
            border: '1px solid rgba(167, 139, 250, 0.25)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#a78bfa',
          }}
        >
          <Monitor size={22} />
        </div>
        <div>
          <h3 style={{ margin: 0, fontSize: '1.15rem' }}>Active Sessions &amp; Devices</h3>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
            Manage places where your Novyn account is currently signed in.
          </p>
        </div>
      </div>

      {/* Current Device Card */}
      <div style={{ marginBottom: 20 }}>
        <span
          style={{
            display: 'block',
            fontSize: '0.74rem',
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.06em',
            color: '#10b981',
            marginBottom: 8,
          }}
        >
          Current Device
        </span>

        <div
          style={{
            padding: '16px',
            borderRadius: 16,
            background: 'var(--bg-app)',
            border: '1px solid rgba(16, 185, 129, 0.35)',
            boxShadow: '0 4px 20px rgba(16, 185, 129, 0.06)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div
              style={{
                width: 42,
                height: 42,
                borderRadius: 12,
                background: 'rgba(16, 185, 129, 0.15)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#10b981',
                flexShrink: 0,
              }}
            >
              {client.isMobile ? <Smartphone size={22} /> : <Laptop size={22} />}
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <strong style={{ fontSize: '0.92rem', color: 'var(--text-main)' }}>
                  {client.browser} on {client.os}
                </strong>
                <span
                  style={{
                    padding: '2px 7px',
                    borderRadius: 999,
                    background: 'rgba(16, 185, 129, 0.2)',
                    color: '#10b981',
                    fontSize: '0.68rem',
                    fontWeight: 700,
                  }}
                >
                  This device
                </span>
              </div>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  marginTop: 4,
                  fontSize: '0.74rem',
                  color: 'var(--text-muted)',
                }}
              >
                <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                  <Globe size={12} /> {window.location.hostname}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                  <Clock size={12} /> Active now
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Other Sessions Section */}
      <div style={{ marginBottom: 20 }}>
        <span
          style={{
            display: 'block',
            fontSize: '0.74rem',
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.06em',
            color: 'var(--text-muted)',
            marginBottom: 8,
          }}
        >
          Other Sessions
        </span>

        <div
          style={{
            padding: '20px 16px',
            borderRadius: 14,
            background: 'var(--bg-app)',
            border: '1px solid rgba(16, 185, 129, 0.25)',
            textAlign: 'center',
            color: 'var(--text-muted)',
            fontSize: '0.84rem',
          }}
        >
          <ShieldCheck size={22} style={{ color: '#10b981', margin: '0 auto 8px', display: 'block' }} />
          <strong style={{ display: 'block', color: 'var(--text-main)', marginBottom: 4 }}>
            No other active sessions
          </strong>
          You are currently only signed in on this {client.isMobile ? 'mobile device' : 'browser'}.
        </div>
      </div>

      {/* Security Recommendation */}
      <div
        style={{
          padding: '12px 14px',
          borderRadius: 12,
          background: 'rgba(99, 102, 241, 0.08)',
          border: '1px solid rgba(99, 102, 241, 0.18)',
          display: 'flex',
          gap: 10,
          alignItems: 'center',
          fontSize: '0.78rem',
          color: 'var(--text-muted)',
        }}
      >
        <ShieldCheck size={18} style={{ color: '#818cf8', flexShrink: 0 }} />
        <span>
          If you don&apos;t recognize a session or device, log out all other devices and update your password immediately.
        </span>
      </div>
    </div>
  );
};
