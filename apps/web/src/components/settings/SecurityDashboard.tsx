import React, { useEffect, useState } from 'react';
import {
  ShieldCheck,
  Check,
  Smartphone,
  KeyRound,
  ArrowRight,
  Lock,
  EyeOff,
  Clock,
  Laptop,
  Sliders,
  ChevronRight,
  Fingerprint,
  Trash2,
  QrCode,
} from 'lucide-react';
import { MessageKeyTransferDialog } from '../chat/MessageKeyTransferDialog';
import { getMyPublicKeyJwk } from '../../services/e2ee';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import type { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { useAuth } from '../../context/AuthContext';
import { triggerHaptic } from '../../services/capacitor';
import './securityDashboard.css';

export function SecurityDashboard({ onSelectSection }: {
  onSelectSection?: (category: SettingsMainCategory, section: SettingsSubSection) => void;
} = {}) {
  const { user } = useAuth();
  const [keysOpen, setKeysOpen] = useState(false);
  const [keysReady, setKeysReady] = useState<boolean | null>(null);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  useEffect(() => {
    let cancelled = false;
    getMyPublicKeyJwk()
      .then((key) => {
        if (!cancelled) setKeysReady(Boolean(key));
      })
      .catch(() => {
        if (!cancelled) setKeysReady(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const isHttps = typeof window !== 'undefined' && window.location.protocol === 'https:';
  const isLocalhost = typeof window !== 'undefined' && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

  // Real live states for functional features
  const hasPassword = Boolean(user?.hasPassword);
  const isGoogleUser = Boolean(user?.isGoogleUser);
  const is2faActive = Boolean(user?.twoFactorEnabled);
  const isPinActive = typeof window !== 'undefined' && Boolean(localStorage.getItem('novyn_app_lock_pin_hash'));
  const pinTimeout = typeof window !== 'undefined' ? localStorage.getItem('novyn_app_lock_timeout') || '5' : '5';

  const handleUseHttps = () => {
    if (isLocalhost) {
      setNotice({
        text: 'HTTPS is enforced in production. Local development runs on HTTP.',
        error: false,
      });
      return;
    }
    if (!isHttps && typeof window !== 'undefined') {
      window.location.href = window.location.href.replace('http:', 'https:');
    }
  };

  const handleNavigate = (section: SettingsSubSection) => {
    triggerHaptic('light');
    if (onSelectSection) {
      onSelectSection('security', section);
    }
  };

  const handleMobileOnlyClick = (feature: string) => {
    triggerHaptic('light');
    setNotice({
      text: `${feature}: Available in the Novyn Android & iOS mobile app.`,
      error: false,
    });
  };

  return (
    <section className="security-dashboard" aria-label="Security settings">
      <div className="security-layout">
        {/* Row 1: Encryption Status & Sync Keys */}
        <div className="security-top-columns">
          {/* Left Column: Encryption Status */}
          <article className="security-card security-card-encryption">
            <span className="security-section-tag">
              <span className="security-tag-dot is-green" /> ENCRYPTION STATUS
            </span>

            <div className="security-hero-banner">
              <div className="security-hero-icon-box">
                <ShieldCheck size={32} />
              </div>
              <div className="security-hero-text">
                <h3>End-to-End Encryption Active</h3>
                <p>Private conversations are encrypted on this device before dispatch.</p>
              </div>
            </div>

            <div className="security-status-list">
              {/* Row 1: Browser Keys */}
              <div className="security-status-row">
                <div className="security-status-left">
                  <div className="security-status-icon is-success">
                    <Check size={15} strokeWidth={2.5} />
                  </div>
                  <div className="security-status-info">
                    <span className="security-status-title">Browser identity keys</span>
                    <span className="security-status-sub">
                      {keysReady ? 'Cryptographic keys active' : 'Generating E2EE identity…'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Row 2: Connection TLS */}
              <div className="security-status-row">
                <div className="security-status-left">
                  <div className={`security-status-icon ${isHttps ? 'is-success' : 'is-warning'}`}>
                    {isHttps ? <Check size={15} strokeWidth={2.5} /> : <Laptop size={15} />}
                  </div>
                  <div className="security-status-info">
                    <span className="security-status-title">
                      {isHttps ? 'Connection encrypted' : 'Connection is unencrypted'}
                    </span>
                    <span className="security-status-sub">
                      {isHttps ? 'HTTPS TLS active' : 'HTTP, no TLS encryption'}
                    </span>
                  </div>
                </div>
                {!isHttps && (
                  <button type="button" className="security-action-btn" onClick={handleUseHttps}>
                    Use HTTPS
                  </button>
                )}
              </div>

              {/* Row 3: Keys on Android */}
              <div className="security-status-row">
                <div className="security-status-left">
                  <div className="security-status-icon is-neutral">
                    <Smartphone size={15} />
                  </div>
                  <div className="security-status-info">
                    <span className="security-status-title">Keys on Android</span>
                    <span className="security-status-sub">Sync to read chats on phone</span>
                  </div>
                </div>
                <button type="button" className="security-action-btn" onClick={() => setKeysOpen(true)}>
                  Sync
                </button>
              </div>
            </div>

            <p className="security-encryption-disclaimer">
              Clearing Novyn’s temporary cache preserves your keys. Clearing all browser cookies and site storage resets them.
            </p>
          </article>

          {/* Right Column: Sync Message Keys */}
          <article className="security-card security-card-sync">
            <span className="security-section-tag">
              <span className="security-tag-dot" style={{ background: '#c084fc', boxShadow: '0 0 8px #c084fc' }} /> KEY TRANSFER &amp; SYNC
            </span>

            <div className="security-hero-banner">
              <div
                className="security-hero-icon-box"
                style={{
                  background: 'rgba(192, 132, 252, 0.15)',
                  borderColor: 'rgba(192, 132, 252, 0.3)',
                  color: '#c084fc',
                }}
              >
                <KeyRound size={28} />
              </div>
              <div className="security-hero-text">
                <h3>Sync Message Keys</h3>
                <p>Transfer E2EE keys across devices to decrypt past chat history on mobile or other browsers.</p>
              </div>
            </div>

            {/* Visual P2P Transfer Bridge */}
            <div className="security-sync-bridge-card">
              <div className="security-sync-node">
                <div className="security-sync-node-icon is-browser">
                  <Laptop size={18} />
                </div>
                <div className="security-sync-node-meta">
                  <span className="security-sync-node-name">This Browser</span>
                  <span className="security-sync-node-status">
                    <span className="sync-status-dot" /> Keys Ready
                  </span>
                </div>
              </div>

              <div className="security-sync-connector">
                <div className="security-connector-line" />
                <div className="security-connector-pill">
                  <ShieldCheck size={11} />
                  <span>P2P E2EE</span>
                </div>
              </div>

              <div className="security-sync-node">
                <div className="security-sync-node-icon is-phone">
                  <Smartphone size={18} />
                </div>
                <div className="security-sync-node-meta">
                  <span className="security-sync-node-name">Android Device</span>
                  <span className="security-sync-node-status is-pending">Pair via QR</span>
                </div>
              </div>
            </div>

            {/* Benefit pills */}
            <div className="security-sync-benefits">
              <div className="security-sync-benefit-item">
                <Check size={12} className="benefit-check" />
                <span>Zero-knowledge transfer</span>
              </div>
              <div className="security-sync-benefit-item">
                <QrCode size={12} className="benefit-qr" />
                <span>Instant QR pairing</span>
              </div>
              <div className="security-sync-benefit-item">
                <Check size={12} className="benefit-check" />
                <span>Restores past chat messages</span>
              </div>
            </div>

            {/* Bottom Action Footer */}
            <div className="security-sync-footer">
              <button
                type="button"
                className="security-btn-glow"
                onClick={() => setKeysOpen(true)}
                aria-haspopup="dialog"
                style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}
              >
                <KeyRound size={15} /> Open Key Transfer
              </button>
              <span className="security-sync-footer-note">
                Scan QR from your Android phone to sync
              </span>
            </div>
          </article>
        </div>

        {/* Row 2: Core Security Suite (100% Functional Web Features) */}
        <article className="security-card security-suite-card">
          <div className="security-suite-header">
            <div className="security-suite-header-left">
              <span className="security-section-tag">
                <span className="security-tag-dot is-green" /> AUTHENTICATION & ACCESS CONTROLS
              </span>
              <p className="security-suite-subtitle">
                Manage your credentials, inactivity screen lock, multi-factor verification, and logged-in devices.
              </p>
            </div>
          </div>

          <div className="security-suite-grid">
            {/* 1. Account Password */}
            <button
              type="button"
              className="security-feature-card"
              onClick={() => handleNavigate('privacy-password')}
            >
              <div className="security-feature-left">
                <div className="security-feature-icon">
                  <KeyRound size={20} />
                </div>
                <div className="security-feature-info">
                  <span className="security-feature-title">Account Password</span>
                  <span className="security-feature-desc">
                    {hasPassword
                      ? 'Master password configured'
                      : isGoogleUser
                      ? 'Connected via Google account'
                      : 'Create a password for direct sign-in'}
                  </span>
                </div>
              </div>
              <div className="security-feature-right">
                <span className={`security-feature-badge ${hasPassword ? 'is-active' : 'is-setup'}`}>
                  {hasPassword ? 'Active' : isGoogleUser ? 'Google ID' : 'Set Up'}
                </span>
                <ChevronRight size={16} className="security-feature-arrow" />
              </div>
            </button>

            {/* 2. Screen Lock & PIN */}
            <button
              type="button"
              className="security-feature-card"
              onClick={() => handleNavigate('privacy-app-lock')}
            >
              <div className="security-feature-left">
                <div className="security-feature-icon is-indigo">
                  <Lock size={20} />
                </div>
                <div className="security-feature-info">
                  <span className="security-feature-title">Screen Lock & PIN</span>
                  <span className="security-feature-desc">
                    {isPinActive
                      ? `Auto-locks after ${pinTimeout === '0' ? 'immediate' : pinTimeout + ' min'}`
                      : 'Lock screen with a 4-digit PIN'}
                  </span>
                </div>
              </div>
              <div className="security-feature-right">
                <span className={`security-feature-badge ${isPinActive ? 'is-active' : 'is-neutral'}`}>
                  {isPinActive ? 'PIN Active' : 'Disabled'}
                </span>
                <ChevronRight size={16} className="security-feature-arrow" />
              </div>
            </button>

            {/* 3. Two-Factor Authentication */}
            <button
              type="button"
              className="security-feature-card"
              onClick={() => handleNavigate('privacy-two-factor')}
            >
              <div className="security-feature-left">
                <div className="security-feature-icon is-green">
                  <ShieldCheck size={20} />
                </div>
                <div className="security-feature-info">
                  <span className="security-feature-title">Two-Factor Authentication</span>
                  <span className="security-feature-desc">
                    {is2faActive
                      ? 'TOTP code required on new sign-ins'
                      : 'Authenticator app (Google / Authy) & backup codes'}
                  </span>
                </div>
              </div>
              <div className="security-feature-right">
                <span className={`security-feature-badge ${is2faActive ? 'is-active' : 'is-setup'}`}>
                  {is2faActive ? 'Active' : 'Configure'}
                </span>
                <ChevronRight size={16} className="security-feature-arrow" />
              </div>
            </button>

            {/* 4. Active Sessions */}
            <button
              type="button"
              className="security-feature-card"
              onClick={() => handleNavigate('privacy-sessions')}
            >
              <div className="security-feature-left">
                <div className="security-feature-icon is-cyan">
                  <Clock size={20} />
                </div>
                <div className="security-feature-info">
                  <span className="security-feature-title">Active Sessions</span>
                  <span className="security-feature-desc">
                    Review signed-in browsers and revoke other devices
                  </span>
                </div>
              </div>
              <div className="security-feature-right">
                <span className="security-feature-badge is-active">
                  Manage
                </span>
                <ChevronRight size={16} className="security-feature-arrow" />
              </div>
            </button>
          </div>
        </article>

        {/* Row 3: Account Actions & Mobile Companion */}
        <div className="security-bottom-split">
          {/* Left: Account Actions & Data Controls */}
          <article className="security-card security-danger-summary-card">
            <div>
              <div className="security-card-header">
                <div className="security-card-header-icon is-red">
                  <Sliders size={18} />
                </div>
                <h3>Account Actions & Danger Zone</h3>
              </div>
              <p className="security-card-desc">
                Clear local cached media files, sign out of all devices, or permanently erase your Novyn identity.
              </p>
            </div>

            <button
              type="button"
              className="security-danger-action-btn"
              onClick={() => handleNavigate('privacy-danger')}
            >
              <Sliders size={15} /> Manage Account Data & Safety
            </button>
          </article>

          {/* Right: Mobile App Companion Exclusives */}
          <article className="security-card security-card-mobile">
            <div className="security-card-header">
              <div className="security-card-header-icon">
                <Smartphone size={18} />
              </div>
              <h3>Mobile App Exclusives</h3>
            </div>
            <p className="security-card-desc">
              Hardware-dependent privacy features available in the Novyn mobile app.
            </p>

            <div className="security-mobile-tiles-grid">
              <button
                type="button"
                className="security-mobile-tile"
                onClick={() => handleMobileOnlyClick('Stealth Mode')}
              >
                <div className="security-mobile-tile-icon">
                  <EyeOff size={18} />
                </div>
                <span className="security-mobile-tile-name">Stealth Mode</span>
                <span className="security-mobile-badge">Mobile App</span>
              </button>

              <button
                type="button"
                className="security-mobile-tile"
                onClick={() => handleMobileOnlyClick('Biometrics')}
              >
                <div className="security-mobile-tile-icon">
                  <Fingerprint size={18} />
                </div>
                <span className="security-mobile-tile-name">Biometrics</span>
                <span className="security-mobile-badge">Mobile App</span>
              </button>
            </div>
          </article>
        </div>
      </div>

      <MessageKeyTransferDialog isOpen={keysOpen} onClose={() => setKeysOpen(false)} />
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}
    </section>
  );
}

export { PrivacyDashboard } from './PrivacyDashboard';
