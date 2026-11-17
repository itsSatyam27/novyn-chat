import React, { useState } from 'react';
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
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import type { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { useAuth } from '../../context/AuthContext';
import { triggerHaptic } from '../../services/capacitor';
import './securityDashboard.css';

export function SecurityDashboard({ onSelectSection }: {
  onSelectSection?: (category: SettingsMainCategory, section: SettingsSubSection) => void;
} = {}) {
  const { user } = useAuth();
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

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
        <article className="security-card" style={{ marginBottom: 18 }}>
          <span className="security-section-tag">
            <span className={`security-tag-dot ${isHttps ? 'is-green' : ''}`} /> CONNECTION SECURITY
          </span>
          <div className="security-status-row">
            <div className="security-status-left">
              <div className={`security-status-icon ${isHttps ? 'is-success' : 'is-warning'}`}>
                {isHttps ? <Check size={15} strokeWidth={2.5} /> : <Laptop size={15} />}
              </div>
              <div className="security-status-info">
                <span className="security-status-title">{isHttps ? 'Secure HTTPS connection' : 'HTTPS is recommended'}</span>
                <span className="security-status-sub">{isHttps ? 'Transport security is active for this connection.' : 'Use HTTPS when accessing Novyn outside local development.'}</span>
              </div>
            </div>
            {!isHttps && <button type="button" className="security-action-btn" onClick={handleUseHttps}>Use HTTPS</button>}
          </div>
        </article>

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

      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}
    </section>
  );
}

export { PrivacyDashboard } from './PrivacyDashboard';
