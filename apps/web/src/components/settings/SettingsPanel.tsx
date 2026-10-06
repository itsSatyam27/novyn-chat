import React, { useEffect, useId, useRef, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { ShieldCheck, QrCode, Palette, Volume2, Bell, Globe, CircleHelp,
  LogOut, ChevronRight, Pencil, X, Download, HardDrive, Check } from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import './androidSettings.css';

export type SettingsMainCategory = 'profile' | 'privacy' | 'notifications' | 'appearance' | 'storage' | 'feedback';
export type SettingsSubSection =
  // Profile
  | 'profile-details'
  | 'profile-username'
  | 'profile-email'
  | 'profile-presence'
  // Privacy
  | 'privacy-blocked'
  | 'privacy-password'
  | 'privacy-receipts'
  | 'privacy-retention'
  | 'privacy-sessions'
  | 'privacy-linked-devices'
  | 'privacy-danger'
  // Notifications
  | 'notif-sounds'
  | 'notif-calls'
  | 'notif-previews'
  // Appearance
  | 'appear-theme'
  | 'appear-wallpaper'
  | 'appear-font'
  // Storage
  | 'storage-cache'
  | 'storage-export'
  | 'storage-security'
  // Feedback
  | 'feedback-send'
  | 'feedback-bug'
  | 'feedback-feature';


interface SettingsPanelProps {
  activeCategory: SettingsMainCategory;
  onSelectCategory: (category: SettingsMainCategory, defaultSub: SettingsSubSection) => void;
  isCompact?: boolean;
}

const presence = [
  { value: 'online', label: 'Online', color: '#00c69a' },
  { value: 'away', label: 'Away', color: '#ff9d00' },
  { value: 'busy', label: 'Busy', color: '#ec4899' },
  { value: 'invisible', label: 'Invisible', color: '#64748b' },
];
const hindi: Record<string, string> = {
  Settings: 'सेटिंग्स', ACCOUNT: 'खाता', PREFERENCES: 'पसंद', SUPPORT: 'सहायता', DANGER: 'खाता कार्रवाई',
  'Security & Privacy': 'सुरक्षा और गोपनीयता', 'QR Code': 'QR कोड', Appearance: 'दिखावट',
  'Sound & Vibration': 'ध्वनि और कंपन', Notifications: 'सूचनाएं', 'Language & Region': 'भाषा और क्षेत्र',
  'Help & Support': 'मदद और सहायता', 'Log Out': 'लॉग आउट', 'Data & Storage': 'डेटा और स्टोरेज',
  Online: 'ऑनलाइन', Away: 'दूर', Busy: 'व्यस्त', Invisible: 'अदृश्य',
};

export const SettingsPanel: React.FC<SettingsPanelProps> = ({
  activeCategory, onSelectCategory, isCompact = false,
}) => {
  const { user, logout } = useAuth();
  const { updateProfile } = useChat();
  const [modal, setModal] = useState<'qr' | 'language' | 'logout' | null>(null);
  const [language, setLanguage] = useState(() => localStorage.getItem('novyn_settings_language') || 'en');
  const [region, setRegion] = useState(() => localStorage.getItem('novyn_region') || 'IN');
  const [qr, setQr] = useState('');
  const [error, setError] = useState('');
  const [loggingOut, setLoggingOut] = useState(false);
  const dialog = useRef<HTMLDialogElement>(null);
  const orbitGradient = useId();
  const [presenceExpanded, setPresenceExpanded] = useState(false);
  const presenceDock = useRef<HTMLDivElement>(null);
  const presenceOptionsId = useId();
  const presenceTrigger = useRef<HTMLButtonElement>(null);
  const t = (text: string) => language === 'hi' ? hindi[text] || text : text;
  const name = user?.displayName || user?.username || 'You';
  const status = user?.presenceMode === 'dnd' ? 'busy' :
    user?.presenceMode === 'offline' ? 'invisible' : user?.presenceMode || 'online';
  const statusColor = presence.find((item) => item.value === status)?.color || '#00c69a';
  const profileUrl = `https://novyn.app/user/${encodeURIComponent(user?.username || '')}`;
  const avatar = user?.avatarId || (user?.username ? localStorage.getItem(`novyn_avatar_${user.username}`) : '');

  useEffect(() => {
    document.documentElement.lang = language;
  }, [language]);

  useEffect(() => {
    if (!presenceExpanded) return;
    const dismiss = (event: PointerEvent) => {
      if (!presenceDock.current?.contains(event.target as Node)) setPresenceExpanded(false);
    };
    document.addEventListener('pointerdown', dismiss);
    requestAnimationFrame(() => presenceDock.current?.querySelector<HTMLButtonElement>('[role="menuitemradio"][aria-checked="true"]')?.focus());
    return () => document.removeEventListener('pointerdown', dismiss);
  }, [presenceExpanded]);

  useEffect(() => {
    if (modal) dialog.current?.showModal();
    else dialog.current?.close();
  }, [modal]);

  useEffect(() => {
    if (modal !== 'qr') return;
    let cancelled = false;
    setQr('');
    import('qrcode').then((module) => module.toDataURL(profileUrl, {
      width: 280, margin: 3, errorCorrectionLevel: 'M',
      color: { dark: '#18152d', light: '#ffffff' },
    })).then((data) => { if (!cancelled) setQr(data); })
      .catch(() => { if (!cancelled) setError('Could not generate your QR code. Please try again.'); });
    return () => { cancelled = true; };
  }, [modal, profileUrl]);

  const open = (value: typeof modal) => { setError(''); setModal(value); };
  const select = (category: SettingsMainCategory, section: SettingsSubSection) => {
    triggerHaptic('light'); onSelectCategory(category, section);
  };
  const row = (label: string, Icon: typeof Palette, color: string, action: () => void,
    category?: SettingsMainCategory) => (
    <button type="button" className="android-settings-row" onClick={action}
      title={label} style={{ '--row-accent': color } as React.CSSProperties}
      data-selected={category === activeCategory ? 'true' : undefined}>
      <span className="android-settings-icon"><Icon size={20} aria-hidden="true" /></span>
      <strong>{t(label)}</strong><ChevronRight size={19} aria-hidden="true" />
    </button>
  );
  const heading = (label: string) => <h3 className="android-settings-section">{t(label)}</h3>;

  return (
    <section className={`android-settings ${isCompact ? 'is-compact' : ''}`} aria-label="Settings">
      <h1>{t('Settings')}</h1>
      <div className="android-profile-card">
        <button className="android-profile-edit" type="button" aria-label="Edit your profile"
          onClick={() => select('profile', 'profile-details')}><Pencil size={18} /></button>
        <div className="android-profile-orbit" style={{ '--presence-color': statusColor } as React.CSSProperties}>
          <div className="android-profile-avatar">
            <span>{name.charAt(0).toUpperCase()}</span>
            {avatar && <img key={avatar} src={avatar} alt="" onError={(event) => { event.currentTarget.style.display = 'none'; }} />}
          </div>
          <svg className="android-profile-comet" viewBox="0 0 108 108" aria-hidden="true">
            <defs><linearGradient id={orbitGradient} x1="106" y1="54" x2="70" y2="103" gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor="var(--presence-color)" stopOpacity="0" />
              <stop offset="1" stopColor="var(--presence-color)" />
            </linearGradient></defs>
            <path d="M106 54 A52 52 0 0 1 70.07 103.45" fill="none" stroke={`url(#${orbitGradient})`} strokeWidth="2.5" strokeLinecap="round" />
            <circle cx="70.07" cy="103.45" r="4.5" fill="var(--presence-color)" />
            <circle cx="70.07" cy="103.45" r="2.5" fill="white" />
          </svg>
        </div>
        <h2>{name}</h2><span className="android-profile-handle">@{user?.username}</span>
        <div ref={presenceDock} className="android-presence" style={{ '--presence-color': statusColor } as React.CSSProperties}
          onKeyDown={(event) => {
            if (event.key === 'Escape') { setPresenceExpanded(false); presenceTrigger.current?.focus(); }
            if (presenceExpanded && ['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
              event.preventDefault();
              const items = Array.from(presenceDock.current?.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]') || []);
              const index = items.indexOf(document.activeElement as HTMLButtonElement);
              const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 :
                (index + (event.key === 'ArrowUp' ? -1 : 1) + items.length) % items.length;
              items[next]?.focus();
            }
          }}>
          <button ref={presenceTrigger} type="button" className="android-presence-badge"
            aria-haspopup="menu" aria-expanded={presenceExpanded} aria-controls={presenceOptionsId}
            onClick={() => setPresenceExpanded(!presenceExpanded)}>
            <i aria-hidden="true" /><span>{t(presence.find(item => item.value === status)?.label || 'Online')}</span>
            <ChevronRight className="android-presence-chevron" size={16} aria-hidden="true" />
          </button>
          {presenceExpanded && <div className="android-presence-menu" id={presenceOptionsId} role="menu" aria-label="Presence status">
            {presence.map(item => <button type="button" key={item.value} role="menuitemradio" aria-checked={status === item.value}
              style={{ '--presence-color': item.color } as React.CSSProperties}
              onClick={() => {
                if (!getSocket()?.connected) { setError('Reconnect to change your status.'); return; }
                setError(''); updateProfile({ status: item.value });
                setPresenceExpanded(false); presenceTrigger.current?.focus();
              }}>
              <i aria-hidden="true" /><span>{t(item.label)}</span>
              {status === item.value && <Check size={16} aria-hidden="true" />}
            </button>)}
          </div>}
        </div>
      </div>
      {error && !modal && <p className="android-settings-error" role="alert">{error}</p>}
      {heading('PREFERENCES')}
      {row('Appearance', Palette, '#7c6ff7', () => select('appearance', 'appear-theme'), 'appearance')}
      {row('Sound & Vibration', Volume2, '#00cdbb', () => select('notifications', 'notif-sounds'))}
      {row('Notifications', Bell, '#ec4899', () => select('notifications', 'notif-previews'))}
      {row('Language & Region', Globe, '#8b5cf6', () => open('language'))}
      {row('Data & Storage', HardDrive, '#6386bb', () => select('storage', 'storage-cache'), 'storage')}
      {heading('ACCOUNT')}
      {row('Security & Privacy', ShieldCheck, '#10b981', () => select('privacy', 'privacy-blocked'), 'privacy')}
      {row('QR Code', QrCode, '#7c6ff7', () => open('qr'))}
      {heading('SUPPORT')}
      {row('Help & Support', CircleHelp, '#f59e0b', () => select('feedback', 'feedback-send'), 'feedback')}
      {heading('DANGER')}
      {row('Log Out', LogOut, '#ef4444', () => open('logout'))}

      <dialog ref={dialog} className="android-settings-dialog" onClose={() => setModal(null)}
        aria-labelledby="android-settings-dialog-title"
        onClick={(event) => { if (event.target === event.currentTarget) setModal(null); }}>
        <header><h2 id="android-settings-dialog-title">{t(modal === 'qr' ? 'QR Code' :
          modal === 'language' ? 'Language & Region' : 'Log Out')}</h2>
          <button type="button" aria-label="Close" onClick={() => setModal(null)}><X size={20} /></button></header>
        {modal === 'qr' && <div className="android-qr">
          <p>Scan to find @{user?.username} in Novyn.</p>
          {qr ? <img src={qr} alt={`Profile QR code for @${user?.username}`} width="240" height="240" /> : <p role="status">Generating QR code…</p>}
          {qr && <a className="android-settings-primary" download={`novyn-${user?.username}-qr.png`} href={qr}><Download size={17} />Download QR code</a>}
          <p className="android-settings-caption">Profile sharing code, not a device login code.</p>
        </div>}
        {modal === 'language' && <div className="android-region-form">
          <label>Settings language<select value={language} onChange={(event) => {
            setLanguage(event.target.value); localStorage.setItem('novyn_settings_language', event.target.value);
          }}><option value="en">English</option><option value="hi">हिन्दी</option></select></label>
          <label>Region<select value={region} onChange={(event) => {
            setRegion(event.target.value); localStorage.setItem('novyn_region', event.target.value);
            window.dispatchEvent(new Event('novyn-region-change'));
          }}><option value="IN">India</option><option value="US">United States</option><option value="GB">United Kingdom</option></select></label>
          <p>Saved for this browser. Dates in settings use your selected region.</p>
          <output>{new Intl.DateTimeFormat(`${language}-${region}`, { dateStyle: 'long' }).format(new Date())}</output>
        </div>}
        {modal === 'logout' && <div className="android-region-form">
          <p>Log out of Novyn on this browser?</p>
          <div className="android-dialog-actions"><button type="button" onClick={() => setModal(null)}>Cancel</button>
            <button type="button" className="android-settings-primary is-danger" disabled={loggingOut} onClick={async () => {
              setLoggingOut(true);
              try { await logout(); setModal(null); }
              catch { setError('Could not log out. Please try again.'); }
              finally { setLoggingOut(false); }
            }}>{loggingOut ? 'Logging out…' : 'Log Out'}</button></div>
        </div>}
        {error && modal && <p role="alert" className="android-settings-error">{error}</p>}
      </dialog>
    </section>
  );
};
