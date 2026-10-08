import React, { useEffect, useRef } from 'react';
import {
  User,
  Shield,
  Bell,
  Palette,
  HardDrive,
  Lock,
  Ban,
  CheckCircle2,
  Smartphone,
  Sparkles,
  Volume2,
  Eye,
  Sliders,
  AtSign,
  Mail,
  Download,
  AlertTriangle,
  MessageSquarePlus,
  Bug,
  Lightbulb,
  ChevronLeft,
  ChevronRight,
  type LucideIcon,
} from 'lucide-react';
import { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { triggerHaptic } from '../../services/capacitor';
import { mobileManagedSettings } from './MobileManagedSetting';
import { webSettings } from './settingsAvailability';

interface SettingsSubPanelProps {
  activeCategory: SettingsMainCategory;
  activeSubSection: SettingsSubSection;
  onSelectSubSection: (sub: SettingsSubSection) => void;
  blockedCount: number;
  onBack?: () => void;
}

export const SettingsSubPanel: React.FC<SettingsSubPanelProps> = ({
  activeCategory,
  activeSubSection,
  onSelectSubSection,
  blockedCount,
  onBack,
}) => {
  const tabsRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const selected = tabsRef.current?.querySelector<HTMLButtonElement>('[aria-pressed="true"]');
    if (selected?.getClientRects().length) selected.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }, [activeSubSection]);
  const metaByCategory: Record<SettingsMainCategory, { title: string; subtitle: string; icon: LucideIcon; color: string }> = {
    profile: {
      title: 'Profile Settings',
      subtitle: 'Identity & Presence',
      icon: User,
      color: '#10b981',
    },
    privacy: {
      title: 'Security & Privacy',
      subtitle: 'Your account, your control',
      icon: Shield,
      color: '#a855f7',
    },
    notifications: {
      title: 'Notification Alerts',
      subtitle: 'Sounds & Popups',
      icon: Bell,
      color: '#38bdf8',
    },
    appearance: {
      title: 'Appearance & UI',
      subtitle: 'Themes & Wallpapers',
      icon: Palette,
      color: '#f59e0b',
    },
    storage: {
      title: 'Data & Security',
      subtitle: 'Storage & Encryption',
      icon: HardDrive,
      color: '#ec4899',
    },
    feedback: {
      title: 'Feedback',
      subtitle: 'Help us improve Novyn',
      icon: MessageSquarePlus,
      color: '#06b6d4',
    },
  };

  const sectionsByCategory: Record<
    SettingsMainCategory,
    { id: SettingsSubSection; label: string; icon: LucideIcon; desc: string; badge?: string | number }[]
  > = {
    profile: [
      {
        id: 'profile-details',
        label: 'Profile Details & Bio',
        desc: 'Edit name, avatar & status',
        icon: User,
      },
      {
        id: 'profile-username',
        label: 'Change Username',
        desc: 'Update unique @handle',
        icon: AtSign,
      },
      {
        id: 'profile-email',
        label: 'Linked Email',
        desc: 'Account email & verification',
        icon: Mail,
      },
    ],
    privacy: [
      {
        id: 'privacy-message-keys',
        label: 'Sync Message Keys',
        desc: 'Read encrypted chats on Android',
        icon: Smartphone,
      },
      {
        id: 'privacy-blocked',
        label: 'Blocked Contacts',
        desc: 'Manage blocked user list',
        icon: Ban,
        badge: blockedCount > 0 ? blockedCount : undefined,
      },
      {
        id: 'privacy-password',
        label: 'Change Password',
        desc: 'Update your account password',
        icon: Lock,
        badge: 'Mobile app',
      },
      {
        id: 'privacy-app-lock',
        label: 'App Lock',
        desc: 'Protect access to the mobile app',
        icon: Lock,
        badge: 'Mobile app',
      },
      {
        id: 'privacy-visibility',
        label: 'Last Seen & Profile Photo',
        desc: 'Choose who can see your details',
        icon: Eye,
        badge: 'Mobile app',
      },
      {
        id: 'privacy-stealth',
        label: 'Stealth Mode',
        desc: 'Privacy protections on your phone',
        icon: Shield,
        badge: 'Mobile app',
      },
      {
        id: 'privacy-two-factor',
        label: 'Two-Factor Authentication',
        desc: 'Mobile account protection — coming soon',
        icon: Shield,
        badge: 'Coming Soon',
      },
      {
        id: 'privacy-receipts',
        label: 'Read Receipts & Activity',
        desc: 'Control read and activity indicators',
        icon: CheckCircle2,
        badge: 'Mobile app',
      },
      {
        id: 'privacy-retention',
        label: 'Message Retention',
        desc: 'Keep chat history for 7, 15, or 30 days',
        icon: Sparkles,
      },
      {
        id: 'privacy-sessions',
        label: 'Active Sessions',
        desc: 'Session management — coming soon',
        icon: Smartphone,
        badge: 'Coming Soon',
      },
      {
        id: 'privacy-linked-devices',
        label: 'Linked Devices',
        desc: 'QR code multi-device sync',
        icon: Smartphone,
        badge: 'Coming Soon',
      },
      {
        id: 'privacy-danger',
        label: 'Account Actions',
        desc: 'Account deletion — coming soon',
        icon: AlertTriangle,
        badge: 'Coming Soon',
      },
    ],
    notifications: [
      {
        id: 'notif-sounds',
        label: 'Message Chimes',
        desc: 'Sound for incoming texts',
        icon: Volume2,
      },
      {
        id: 'notif-calls',
        label: 'Call Sounds',
        desc: 'Incoming ringtone and outgoing ringback',
        icon: Smartphone,
      },
      {
        id: 'notif-previews',
        label: 'Browser Notifications',
        desc: 'Desktop alerts and message previews',
        icon: Eye,
      },
    ],
    appearance: [
      { id: 'appear-language', label: 'Language & Region', desc: 'Language and regional preferences', icon: Sliders },
      { id: 'appear-accessibility', label: 'Accessibility', desc: 'Accessibility preferences', icon: Sliders },
      {
        id: 'appear-theme',
        label: 'Appearance',
        desc: 'Color mode and navigation dock',
        icon: Palette,
      },
      {
        id: 'appear-wallpaper',
        label: 'Chat Wallpapers',
        desc: 'Background patterns & mesh tints',
        icon: Sparkles,
      },
      {
        id: 'appear-font',
        label: 'Typography & Size',
        desc: 'Adjust chat bubble text sizing',
        icon: Sliders,
      },
    ],
    storage: [
      {
        id: 'storage-cache',
        label: 'Cache & Media Storage',
        desc: 'Voice notes & temporary files',
        icon: HardDrive,
      },
      {
        id: 'storage-export',
        label: 'Export Chat Data',
        desc: 'Download profile and currently loaded chat data',
        icon: Download,
      },
      {
        id: 'storage-security',
        label: 'Encryption Status',
        desc: 'WebRTC P2P & TLS security',
        icon: Shield,
      },
    ],
    feedback: [
      {
        id: 'feedback-send',
        label: 'General Feedback',
        desc: 'Share thoughts or suggestions',
        icon: MessageSquarePlus,
      },
      {
        id: 'feedback-bug',
        label: 'Report a Bug',
        desc: 'Tell us what broke',
        icon: Bug,
      },
      {
        id: 'feedback-feature',
        label: 'Request a Feature',
        desc: 'What should we build next?',
        icon: Lightbulb,
      },
    ],
  };

  const currentMeta = metaByCategory[activeCategory];
  const HeaderIcon = currentMeta.icon;
  const list = sectionsByCategory[activeCategory] || [];
  const groups = [
    { label: 'Available here', items: list.filter(item => webSettings[item.id]) },
    { label: 'Mobile app', items: list.filter(item => !webSettings[item.id] && !mobileManagedSettings[item.id].pending) },
    { label: 'Coming soon', items: list.filter(item => !webSettings[item.id] && mobileManagedSettings[item.id].pending) },
  ].filter(group => group.items.length > 0);
  const selectSection = (section: SettingsSubSection) => { triggerHaptic('light'); onSelectSubSection(section); };

  return (
    <section className={`settings-section-nav settings-section-nav--${activeCategory}`} aria-label={currentMeta.title}>
      <header className="settings-section-heading">
        {onBack && <button type="button" className="settings-back" style={{ width: 42, height: 42, borderRadius: 13, background: 'var(--chat-indigo-soft)', borderColor: 'var(--chat-indigo-border)', color: 'var(--chat-indigo)' }} onClick={onBack} aria-label="Back to Settings"><ChevronLeft size={20} /></button>}
        <div className="settings-section-symbol"><HeaderIcon size={20} aria-hidden="true" /></div>
        <div><p className="settings-eyebrow">SETTINGS</p><h1>{currentMeta.title}</h1><p>{currentMeta.subtitle}</p></div>
      </header>
      <label className="settings-section-picker">
        <span>Choose a setting</span>
        <select aria-label="Settings section" value={activeSubSection}
          onChange={event => selectSection(event.target.value as SettingsSubSection)}>
          {groups.map(group => <optgroup key={group.label} label={group.label}>
            {group.items.map(item => <option key={item.id} value={item.id}>{item.label}</option>)}
          </optgroup>)}
        </select>
      </label>
      <div ref={tabsRef} className="settings-section-tabs" role="group" aria-label="Settings sections">
        {groups.map(group => <div key={group.label} className="settings-nav-group">
          <h2>{group.label}</h2>
          {group.items.map(item => {
            const Icon = item.icon;
            return <button key={item.id} type="button" aria-pressed={activeSubSection === item.id}
              title={item.desc} onClick={() => selectSection(item.id)}>
              <Icon size={18} aria-hidden="true" />
              <span className="settings-nav-item-copy"><span>{item.label}</span><small>{item.desc}</small></span>
              {typeof item.badge === 'number' && <span className="settings-nav-count">{item.badge}</span>}
              {activeSubSection === item.id && <ChevronRight className="settings-nav-active-arrow" size={15} aria-hidden="true" />}
            </button>;
          })}
        </div>)}
      </div>
    </section>
  );
};
