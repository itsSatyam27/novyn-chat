import { PrivacyDashboard, SecurityDashboard } from './SecurityDashboard';
import React from 'react';
import { ChevronLeft } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import type { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { MobileManagedSetting, mobileManagedSettings } from './MobileManagedSetting';
import { webSettings } from './settingsAvailability';
import { WebSettings } from './WebSettings';
import { ProfileDashboard } from './ProfileDashboard';
import { AppearanceDashboard } from './AppearanceDashboard';
import { SoundDashboard } from './SoundDashboard';
import { AccessibilityDashboard } from './AccessibilityDashboard';
import { LanguageDashboard } from './LanguageDashboard';
import { StorageDashboard } from './StorageDashboard';
import { PasswordSettings } from './PasswordSettings';
import { AppLockSettings } from './AppLockSettings';
import { ActiveSessionsSettings } from './ActiveSessionsSettings';
import { UsernameSettings } from './UsernameSettings';
import { TwoFactorSettings } from './TwoFactorSettings';
import { AccountActionsSettings } from './AccountActionsSettings';

interface SettingsDetailViewProps {
  activeSubSection: SettingsSubSection;
  onBack?: () => void;
  isVisible?: boolean;
  onSelectSection?: (category: SettingsMainCategory, section: SettingsSubSection) => void;
}

export const SettingsDetailView: React.FC<SettingsDetailViewProps> = ({ activeSubSection, onBack, onSelectSection, isVisible = true }) => {
  if (activeSubSection === 'profile-details') return <div className="settings-detail settings-detail--profile">
    <div className="conversations-scroll settings-detail-body"><ProfileDashboard onBack={onBack} onSelectSection={onSelectSection} /></div>
  </div>;
  if (activeSubSection === 'privacy-danger') return <div className="settings-detail settings-detail--security">
    <div className="conversations-scroll settings-detail-body" style={{ padding: '24px 36px 96px', width: '100%', maxWidth: 'none' }}><AccountActionsSettings onBack={onBack} onSelectSection={onSelectSection} /></div>
  </div>;
  const privacy = activeSubSection.startsWith('privacy-');
  const security = activeSubSection === 'security-dashboard';
  const storage = activeSubSection.startsWith('storage-');
  const available = webSettings[activeSubSection];
  const setting = available || mobileManagedSettings[activeSubSection];
  const isFunctionalDetail = [
    'privacy-password',
    'privacy-two-factor',
    'privacy-app-lock',
    'privacy-sessions',
    'profile-username',
  ].includes(activeSubSection);

  const isSecuritySubSection = [
    'privacy-password',
    'privacy-two-factor',
    'privacy-app-lock',
    'privacy-sessions',
    'privacy-linked-devices',
    'privacy-message-keys',
  ].includes(activeSubSection);

  const detailSubtitle = (() => {
    if (security) return 'Protect your account and access to encrypted messages.';
    if (activeSubSection === 'privacy-password') return 'Choose a strong password or manage your Novyn master password.';
    if (activeSubSection === 'privacy-two-factor') return 'Set up TOTP authenticator protection and emergency backup codes.';
    if (activeSubSection === 'privacy-app-lock') return 'Protect your screen with a 4-digit PIN code when inactive.';
    if (activeSubSection === 'privacy-sessions') return 'Review browsers and devices where your account is currently signed in.';
    if (activeSubSection === 'profile-username') return 'Change your unique @handle on Novyn.';
    if (privacy) return 'Control who can reach you, what others see, and how your messages are kept.';
    if (available && !privacy && !security && !storage && !activeSubSection.startsWith('feedback-') && !['appear-accessibility', 'appear-language', 'appear-theme', 'appear-wallpaper', 'notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection)) {
      return available.scope === 'account' ? 'Changes apply to your Novyn account across devices.' : available.scope === 'browser' ? 'These preferences are saved for this browser.' : 'Tools for your Novyn web session.';
    }
    return null;
  })();

  return (
    <div className={'settings-detail' + (privacy || security ? ' settings-detail--security' : activeSubSection.startsWith('feedback-') ? ' settings-detail--feedback' : activeSubSection === 'appear-accessibility' ? ' settings-detail--accessibility' : storage ? ' settings-detail--storage' : activeSubSection === 'appear-language' ? ' settings-detail--language' : (activeSubSection === 'appear-theme' || activeSubSection === 'appear-wallpaper') ? ' settings-detail--appearance' : ['notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection) ? ' settings-detail--sound' : '')}>
      <header className="settings-detail-header">
        {(onBack || (isSecuritySubSection && onSelectSection)) && (
          <button
            type="button"
            className="settings-back"
            style={{ width: 42, height: 42, borderRadius: 13, background: 'var(--chat-indigo-soft)', borderColor: 'var(--chat-indigo-border)', color: 'var(--chat-indigo)' }}
            aria-label="Back to Security"
            onClick={() => {
              triggerHaptic('light');
              if (onBack) onBack();
              else if (onSelectSection) onSelectSection('security', 'security-dashboard');
            }}
          >
            <ChevronLeft size={20} />
          </button>
        )}
        <div className="settings-detail-title">
          <h2>{isFunctionalDetail ? (setting?.title || 'Settings') : security ? 'Security' : privacy ? 'Privacy' : activeSubSection.startsWith('feedback-') ? 'Help & Support' : storage ? 'Data & Storage' : activeSubSection.startsWith('notif-') ? 'Sounds & Notifications' : setting.title}</h2>
          {detailSubtitle && <p>{detailSubtitle}</p>}
        </div>
      </header>
      <div className="conversations-scroll settings-detail-body" key={activeSubSection}>
        {security ? <SecurityDashboard onSelectSection={onSelectSection} /> : activeSubSection === 'profile-username' ? <UsernameSettings /> : activeSubSection === 'privacy-password' ? <PasswordSettings /> : activeSubSection === 'privacy-two-factor' ? <TwoFactorSettings /> : activeSubSection === 'privacy-app-lock' ? <AppLockSettings /> : activeSubSection === 'privacy-sessions' ? <ActiveSessionsSettings /> : activeSubSection === 'privacy-linked-devices' ? <WebSettings section="privacy-message-keys" /> : activeSubSection === 'privacy-controls' ? <PrivacyDashboard /> : privacy ? <MobileManagedSetting setting={mobileManagedSettings[activeSubSection]} /> : activeSubSection === 'appear-accessibility' ? <AccessibilityDashboard /> : storage ? <StorageDashboard /> : activeSubSection === 'appear-language' ? <LanguageDashboard /> : (activeSubSection === 'appear-theme' || activeSubSection === 'appear-wallpaper') ? <AppearanceDashboard /> : ['notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection) ? <SoundDashboard active={isVisible} /> : available ? <WebSettings key={activeSubSection} section={activeSubSection} /> : <MobileManagedSetting setting={mobileManagedSettings[activeSubSection]} />}
      </div>
    </div>
  );
};
