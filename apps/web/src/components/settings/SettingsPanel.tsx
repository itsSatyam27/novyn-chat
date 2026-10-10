import React, { useEffect, useId, useRef, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { ShieldCheck, Eye, Palette, Volume2, Globe, MessageSquarePlus,
  LogOut, UserRound, X, HardDrive, Accessibility } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { useBrowserPreference } from '../../services/browserPreferences';
import './androidSettings.css';

export type SettingsMainCategory = 'profile' | 'security' | 'privacy' | 'notifications' | 'appearance' | 'storage' | 'feedback';
export type SettingsSubSection =
  // Profile
  | 'profile-details'
  | 'profile-username'
  | 'profile-email'
  | 'profile-presence'
  | 'profile-qr'
  | 'security-dashboard'
  // Privacy
  | 'privacy-blocked'
  | 'privacy-password'
  | 'privacy-app-lock'
  | 'privacy-visibility'
  | 'privacy-controls'
  | 'privacy-stealth'
  | 'privacy-two-factor'
  | 'privacy-message-keys'
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
  | 'appear-language'
  | 'appear-accessibility'
  // Storage
  | 'storage-cache'
  | 'storage-export'
  | 'storage-security'
  // Feedback
  | 'feedback-send'
  | 'feedback-bug'
  | 'feedback-feature';


interface SettingsPanelProps {
  activeSubSection: SettingsSubSection;
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
  'Sounds & Notifications': 'ध्वनियाँ और सूचनाएँ', 'Language & Region': 'भाषा और क्षेत्र',
  'Help & Support': 'मदद और सहायता', 'Log Out': 'लॉग आउट', 'Data & Storage': 'डेटा और स्टोरेज',
  Accessibility: 'सुलभता',
  Profile: 'प्रोफ़ाइल', 'Presence & Status': 'उपस्थिति और स्थिति',
  Online: 'ऑनलाइन', Away: 'दूर', Busy: 'व्यस्त', Invisible: 'अदृश्य',
};

export const SettingsPanel: React.FC<SettingsPanelProps> = ({ activeSubSection, onSelectCategory, isCompact = false }) => {
  const { user, logout } = useAuth();
  const [signOutOpen, setSignOutOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);
  const [error, setError] = useState('');
  const dialog = useRef<HTMLDialogElement>(null);
  const orbitGradient = useId();
  const language = useBrowserPreference('novyn_settings_language', 'en');
  const t = (text: string) => language === 'hi' ? hindi[text] || text : text;
  const name = user?.displayName || user?.username || 'You';
  const status = user?.presenceMode === 'dnd' ? 'busy' : user?.presenceMode === 'offline' ? 'invisible' : user?.presenceMode || 'online';
  const selectedPresence = presence.find(item => item.value === status) || presence[0];
  const statusColor = selectedPresence.color;
  const avatar = user?.avatarId || (user?.username ? localStorage.getItem('novyn_avatar_' + user.username) : '');
  const activeMenuSection = activeSubSection.startsWith('privacy-') ? 'privacy-controls'
    : activeSubSection.startsWith('storage-') ? 'storage-cache'
    : activeSubSection.startsWith('feedback-') ? 'feedback-send'
    : activeSubSection.startsWith('profile-') ? 'profile-details'
    : ['appear-wallpaper', 'appear-font'].includes(activeSubSection) ? 'appear-theme'
    : activeSubSection.startsWith('notif-') ? 'notif-sounds' : activeSubSection;
  useEffect(() => {
    if (signOutOpen) dialog.current?.showModal();
    else dialog.current?.close();
  }, [signOutOpen]);
  const select = (category: SettingsMainCategory, section: SettingsSubSection) => {
    triggerHaptic('light'); onSelectCategory(category, section);
  };
  const row = (label: string, Icon: typeof Palette, color: string, category: SettingsMainCategory, section: SettingsSubSection) => (
    <button type="button" className="android-settings-row" onClick={() => select(category, section)}
      title={label} style={{ '--row-accent': color } as React.CSSProperties}
      data-selected={section === activeMenuSection ? 'true' : undefined}>
      <Icon size={18} strokeWidth={1.8} aria-hidden="true" />
      <span className="settings-menu-label">{t(label)}</span>
    </button>
  );
  const heading = (label: string) => <h3 className="android-settings-section">{t(label)}</h3>;
  return (
    <section className={'android-settings settings-sidebar ' + (isCompact ? 'is-compact' : '')} aria-label="Settings">
      <h1>{t('Settings')}</h1>
      <button className="android-profile-card android-profile-edit" type="button" aria-label="Edit your profile"
        onClick={() => select('profile', 'profile-details')}>
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
            <path d="M106 54 A52 52 0 0 1 70.07 103.45" fill="none" stroke={'url(#' + orbitGradient + ')'} strokeWidth="2.5" strokeLinecap="round" />
            <circle cx="70.07" cy="103.45" r="4.5" fill="var(--presence-color)" />
            <circle cx="70.07" cy="103.45" r="2.5" fill="white" />
          </svg>
        </div>
        <span className="settings-sidebar-user-copy"><h2>{name}</h2>
          <span className="settings-sidebar-user-status" style={{ color: statusColor }}><i style={{ background: statusColor }} aria-hidden="true" />{t(selectedPresence.label)}</span>
        </span>
      </button>
      <nav className="settings-menu-scroll" aria-label="Settings navigation">
      {row('Profile', UserRound, '#7c6ff7', 'profile', 'profile-details')}
      {heading('PREFERENCES')}
      {row('Appearance', Palette, '#7c6ff7', 'appearance', 'appear-theme')}
      {row('Sounds & Notifications', Volume2, '#00cdbb', 'notifications', 'notif-sounds')}
      {row('Language & Region', Globe, '#8b5cf6', 'appearance', 'appear-language')}
      {row('Accessibility', Accessibility, '#7c6ff7', 'appearance', 'appear-accessibility')}
      {heading('ACCOUNT')}
      {row('Data & Storage', HardDrive, '#6386bb', 'storage', 'storage-cache')}
      {row('Security', ShieldCheck, '#10b981', 'security', 'security-dashboard')}
      {row('Privacy', Eye, '#8b5cf6', 'privacy', 'privacy-controls')}
      {heading('SUPPORT')}
      {row('Help & Support', MessageSquarePlus, '#f59e0b', 'feedback', 'feedback-send')}
      </nav>
      <footer className="settings-sidebar-footer">
      <button type="button" className="android-settings-row android-settings-logout" title="Log Out"
        style={{ '--row-accent': '#ef4444' } as React.CSSProperties}
        onClick={() => { triggerHaptic('light'); setError(''); setSignOutOpen(true); }}>
        <LogOut size={18} strokeWidth={1.8} aria-hidden="true" />
        <span className="settings-menu-label">{t('Log Out')}</span>
      </button>
      </footer>
      <dialog ref={dialog} className="android-settings-dialog" onClose={() => setSignOutOpen(false)}
        aria-labelledby="android-settings-dialog-title"
        onClick={(event) => { if (event.target === event.currentTarget && !loggingOut) setSignOutOpen(false); }}>
        <header><h2 id="android-settings-dialog-title">Sign out of this browser</h2>
          <button type="button" aria-label="Close" disabled={loggingOut} onClick={() => setSignOutOpen(false)}><X size={20} /></button></header>
        <div className="android-region-form">
          <p>Log out of Novyn on this browser?</p>
          <div className="android-dialog-actions">
            <button type="button" disabled={loggingOut} onClick={() => setSignOutOpen(false)}>Cancel</button>
            <button type="button" className="android-settings-primary is-danger" disabled={loggingOut} onClick={async () => {
              setLoggingOut(true);
              try { await logout(); setSignOutOpen(false); }
              catch { setError('Could not log out. Please try again.'); }
              finally { setLoggingOut(false); }
            }}>{loggingOut ? 'Logging out…' : 'Sign out'}</button>
          </div>
        </div>
        {error && <p role="alert" className="android-settings-error">{error}</p>}
      </dialog>
    </section>
  );
};
