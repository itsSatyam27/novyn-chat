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
  const privacy = activeSubSection.startsWith('privacy-');
  const security = activeSubSection === 'security-dashboard';
  const storage = activeSubSection.startsWith('storage-');
  const available = webSettings[activeSubSection];
  const setting = available || mobileManagedSettings[activeSubSection];
  return (
    <div className={'settings-detail' + (privacy || security ? ' settings-detail--security' : activeSubSection.startsWith('feedback-') ? ' settings-detail--feedback' : activeSubSection === 'appear-accessibility' ? ' settings-detail--accessibility' : storage ? ' settings-detail--storage' : activeSubSection === 'appear-language' ? ' settings-detail--language' : activeSubSection === 'appear-theme' ? ' settings-detail--appearance' : ['notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection) ? ' settings-detail--sound' : '')}>
      <header className="settings-detail-header">
        {onBack && <button type="button" className="settings-back" style={{ width: 42, height: 42, borderRadius: 13, background: 'var(--chat-indigo-soft)', borderColor: 'var(--chat-indigo-border)', color: 'var(--chat-indigo)' }} aria-label="Back to Settings" onClick={() => { triggerHaptic('light'); onBack(); }}><ChevronLeft size={20} /></button>}
        <div className="settings-detail-title">
          <h2>{security ? 'Security' : privacy ? 'Privacy' : activeSubSection.startsWith('feedback-') ? 'Help & Support' : storage ? 'Data & Storage' : activeSubSection.startsWith('notif-') ? 'Sounds & Notifications' : setting.title}</h2>
          {security && <p>Protect your account and access to encrypted messages.</p>}
          {privacy && <p>Control who can reach you, what others see, and how your messages are kept.</p>}
          {available && !privacy && !security && !storage && !activeSubSection.startsWith('feedback-') && !['appear-accessibility', 'appear-language', 'appear-theme', 'notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection) && <p>{available.scope === 'account' ? 'Changes apply to your Novyn account across devices.' : available.scope === 'browser' ? 'These preferences are saved for this browser.' : 'Tools for your Novyn web session.'}</p>}
        </div>
      </header>
      <div className="conversations-scroll settings-detail-body" key={activeSubSection}>
        {security ? <SecurityDashboard /> : activeSubSection === 'privacy-controls' ? <PrivacyDashboard /> : privacy ? <MobileManagedSetting setting={mobileManagedSettings[activeSubSection]} /> : activeSubSection === 'appear-accessibility' ? <AccessibilityDashboard /> : storage ? <StorageDashboard /> : activeSubSection === 'appear-language' ? <LanguageDashboard /> : activeSubSection === 'appear-theme' ? <AppearanceDashboard /> : ['notif-sounds', 'notif-calls', 'notif-previews'].includes(activeSubSection) ? <SoundDashboard active={isVisible} /> : available ? <WebSettings key={activeSubSection} section={activeSubSection} /> : <MobileManagedSetting setting={mobileManagedSettings[activeSubSection]} />}
      </div>
    </div>
  );
};
