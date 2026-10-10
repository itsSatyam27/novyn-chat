import { useEffect, useState } from 'react';
import {
  ShieldCheck,
  Check,
  AlertTriangle,
  Smartphone,
  KeyRound,
  ArrowRight,
  User,
  Lock,
  EyeOff,
  FileText,
  Clock,
  Laptop,
  Sliders,
} from 'lucide-react';
import { MessageKeyTransferDialog } from '../chat/MessageKeyTransferDialog';
import { getMyPublicKeyJwk } from '../../services/e2ee';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import './securityDashboard.css';

export function SecurityDashboard() {
  const [keysOpen, setKeysOpen] = useState(false);
  const [keysReady, setKeysReady] = useState<boolean | null>(null);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  useEffect(() => {
    let cancelled = false;
    getMyPublicKeyJwk()
      .then(key => {
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

  const handleUseHttps = () => {
    if (!isHttps && typeof window !== 'undefined') {
      window.location.href = window.location.href.replace('http:', 'https:');
    }
  };

  const handleMobileFeatureClick = (title: string, path: string) => {
    setNotice({
      text: `${title}: Manage this in the Novyn mobile app (${path}).`,
      error: false,
    });
  };

  const handleComingSoonClick = (title: string) => {
    setNotice({
      text: `${title}: This feature is currently in development.`,
      error: false,
    });
  };

  return (
    <section className="security-dashboard" aria-label="Security settings">
      <div className="security-layout">
        {/* Top 2 Columns */}
        <div className="security-top-columns">
          {/* Left Column: Encryption Status */}
          <article className="security-card security-card-encryption">
            <span className="security-section-tag">ENCRYPTION STATUS</span>

            <div className="security-hero-banner">
              <div className="security-hero-icon-box">
                <ShieldCheck size={32} />
              </div>
              <div className="security-hero-text">
                <h3>Your message keys stay in this browser</h3>
                <p>Encrypted conversations use this browser’s encryption identity.</p>
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
                    <span className="security-status-title">Browser keys</span>
                    <span className="security-status-sub">
                      {keysReady === null
                        ? 'Checking encryption keys...'
                        : keysReady
                        ? 'Ready on this browser'
                        : 'Keys not generated yet'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Row 2: Connection Security */}
              <div className="security-status-row">
                <div className="security-status-left">
                  <div className={`security-status-icon ${isHttps ? 'is-success' : 'is-warning'}`}>
                    {isHttps ? <Check size={15} strokeWidth={2.5} /> : <AlertTriangle size={15} />}
                  </div>
                  <div className="security-status-info">
                    <span className="security-status-title">
                      {isHttps ? 'Connection is secure' : 'Connection is not secure'}
                    </span>
                    <span className="security-status-sub">
                      {isHttps ? 'HTTPS TLS active' : 'HTTP, no TLS'}
                    </span>
                  </div>
                </div>
                {!isHttps && (
                  <button
                    type="button"
                    className="security-action-btn"
                    onClick={handleUseHttps}
                  >
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
                    <span className="security-status-sub">Not synced yet</span>
                  </div>
                </div>
                <button
                  type="button"
                  className="security-action-btn"
                  onClick={() => setKeysOpen(true)}
                >
                  Sync
                </button>
              </div>
            </div>

            <p className="security-encryption-disclaimer">
              Clearing Novyn’s temporary files keeps your keys. Clearing all site data in your browser can remove them.
            </p>
          </article>

          {/* Right Column: Stack of 2 Cards */}
          <div className="security-right-col">
            {/* Card 1: Sync message keys */}
            <article className="security-card security-card-sync">
              <div className="security-card-header">
                <div className="security-card-header-icon">
                  <KeyRound size={18} />
                </div>
                <h3>Sync message keys</h3>
              </div>
              <p className="security-card-desc">
                Transfer conversation keys from this browser to Android to read encrypted messages.
              </p>

              <div className="security-sync-action-row">
                <button
                  type="button"
                  className="security-btn-glow"
                  onClick={() => setKeysOpen(true)}
                  aria-haspopup="dialog"
                >
                  Open key transfer
                </button>

                <div className="security-device-transfer">
                  <div className="security-device-item">
                    <div className="security-device-box browser-box">
                      <div className="browser-tab-indicator" />
                    </div>
                    <span className="device-label">This browser</span>
                  </div>

                  <div className="security-device-arrow">
                    <div className="security-arrow-line" />
                    <ArrowRight size={16} />
                  </div>

                  <div className="security-device-item">
                    <div className="security-device-box phone-box">
                      <Smartphone size={16} />
                    </div>
                    <span className="device-label">Android</span>
                  </div>
                </div>
              </div>
            </article>

            {/* Card 2: Manage in the mobile app */}
            <article className="security-card security-card-mobile">
              <div className="security-card-header">
                <div className="security-card-header-icon">
                  <Smartphone size={18} />
                </div>
                <h3>Manage in the mobile app</h3>
              </div>
              <p className="security-card-desc">
                Open Novyn on your phone with the same account.
              </p>

              <div className="security-mobile-tiles-grid">
                <button
                  type="button"
                  className="security-mobile-tile"
                  onClick={() => handleMobileFeatureClick('Change Password', 'Settings > Security & Privacy > Change Password')}
                >
                  <div className="security-mobile-tile-icon">
                    <User size={18} />
                  </div>
                  <span className="security-mobile-tile-name">Change Password</span>
                  <span className="security-mobile-badge">On phone</span>
                </button>

                <button
                  type="button"
                  className="security-mobile-tile"
                  onClick={() => handleMobileFeatureClick('App Lock', 'Settings > Security & Privacy > App Lock')}
                >
                  <div className="security-mobile-tile-icon">
                    <Lock size={18} />
                  </div>
                  <span className="security-mobile-tile-name">App Lock</span>
                  <span className="security-mobile-badge">On phone</span>
                </button>

                <button
                  type="button"
                  className="security-mobile-tile"
                  onClick={() => handleMobileFeatureClick('Stealth Mode', 'Settings > Security & Privacy > Stealth Mode')}
                >
                  <div className="security-mobile-tile-icon">
                    <EyeOff size={18} />
                  </div>
                  <span className="security-mobile-tile-name">Stealth Mode</span>
                  <span className="security-mobile-badge">On phone</span>
                </button>
              </div>
            </article>
          </div>
        </div>

        {/* Bottom Section: Coming Soon */}
        <article className="security-card security-coming-soon-card">
          <div className="security-coming-soon-header">
            <span className="security-section-tag">COMING SOON</span>
            <span className="security-coming-soon-subtitle">These features are still in development.</span>
          </div>

          <div className="security-soon-grid">
            <button
              type="button"
              className="security-soon-item"
              onClick={() => handleComingSoonClick('Two-Factor Authentication')}
            >
              <div className="security-soon-item-left">
                <FileText size={16} />
                <span>Two-Factor Authentication</span>
              </div>
              <span className="security-soon-badge">Soon</span>
            </button>

            <button
              type="button"
              className="security-soon-item"
              onClick={() => handleComingSoonClick('Active Sessions')}
            >
              <div className="security-soon-item-left">
                <Clock size={16} />
                <span>Active Sessions</span>
              </div>
              <span className="security-soon-badge">Soon</span>
            </button>

            <button
              type="button"
              className="security-soon-item"
              onClick={() => handleComingSoonClick('Linked Devices')}
            >
              <div className="security-soon-item-left">
                <Laptop size={16} />
                <span>Linked Devices</span>
              </div>
              <span className="security-soon-badge">Soon</span>
            </button>

            <button
              type="button"
              className="security-soon-item"
              onClick={() => handleComingSoonClick('Account Actions')}
            >
              <div className="security-soon-item-left">
                <Sliders size={16} />
                <span>Account Actions</span>
              </div>
              <span className="security-soon-badge">Soon</span>
            </button>
          </div>
        </article>
      </div>

      <MessageKeyTransferDialog isOpen={keysOpen} onClose={() => setKeysOpen(false)} />
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}
    </section>
  );
}

export { PrivacyDashboard } from './PrivacyDashboard';
