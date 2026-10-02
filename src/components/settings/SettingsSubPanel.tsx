import React from 'react';
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
} from 'lucide-react';
import { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { triggerHaptic } from '../../services/capacitor';

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
  const metaByCategory: Record<SettingsMainCategory, { title: string; subtitle: string; icon: any; color: string }> = {
    profile: {
      title: 'Profile Settings',
      subtitle: 'Identity & Presence',
      icon: User,
      color: '#10b981',
    },
    privacy: {
      title: 'Security Options',
      subtitle: 'Safety & Credentials',
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
    { id: SettingsSubSection; label: string; icon: any; desc: string; badge?: string | number }[]
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
      {
        id: 'profile-presence',
        label: 'Presence & Status',
        desc: 'Active, Away, or DND mode',
        icon: Sparkles,
      },
    ],
    privacy: [
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
      },
      {
        id: 'privacy-receipts',
        label: 'Read Receipts & Activity',
        desc: 'Seen indicators and typing status',
        icon: CheckCircle2,
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
        desc: 'Connected devices & status',
        icon: Smartphone,
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
        desc: 'Log out all sessions & safety',
        icon: AlertTriangle,
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
        label: 'Call Ringtones',
        desc: 'Melody during audio/video calls',
        icon: Smartphone,
      },
      {
        id: 'notif-previews',
        label: 'Message Previews',
        desc: 'Show text snippets in toasts',
        icon: Eye,
      },
    ],
    appearance: [
      {
        id: 'appear-theme',
        label: 'Theme Accent Colors',
        desc: 'Emerald, Cyan, Purple, Rose, Amber',
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
        label: 'Backup & Restore',
        desc: 'Export & import JSON archives',
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

  return (
    <section className={`settings-section-nav settings-section-nav--${activeCategory}`} aria-label={currentMeta.title}>
      <header className="settings-section-heading">
        {onBack && <button type="button" className="settings-back" onClick={onBack} aria-label="Back to Settings">←</button>}
        <div className="settings-section-symbol"><HeaderIcon size={23} /></div>
        <div><p className="settings-eyebrow">SETTINGS / {activeCategory}</p><h1>{currentMeta.title}</h1><p>{currentMeta.subtitle}</p></div>
      </header>
      <div className="settings-section-tabs" role="group" aria-label="Settings sections">
        {list.map((item) => (
          <button key={item.id} type="button" aria-pressed={activeSubSection === item.id}
            title={item.desc}
            onClick={() => { triggerHaptic('light'); onSelectSubSection(item.id); }}>
            {item.label}
            {item.badge !== undefined && <span className="settings-section-badge">{item.badge}</span>}
          </button>
        ))}
      </div>
    </section>
  );
};
