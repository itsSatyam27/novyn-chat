import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { Avatar } from '../ui/Avatar';
import {
  User,
  Shield,
  Bell,
  Palette,
  HardDrive,
  LogOut,
  ChevronRight,
  Settings,
  MessageSquarePlus,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

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

export const SettingsPanel: React.FC<SettingsPanelProps> = ({
  activeCategory,
  onSelectCategory,
  isCompact = false,
}) => {
  const { user, logout } = useAuth();

  const categories = [
    {
      id: 'profile' as const,
      defaultSub: 'profile-details' as const,
      label: 'Profile & Account',
      description: 'Display name, username & bio',
      icon: User,
      color: '#10b981',
    },
    {
      id: 'privacy' as const,
      defaultSub: 'privacy-blocked' as const,
      label: 'Privacy & Security',
      description: 'Blocked list, password & danger zone',
      icon: Shield,
      color: '#a855f7',
    },
    {
      id: 'notifications' as const,
      defaultSub: 'notif-sounds' as const,
      label: 'Notifications',
      description: 'Sounds, ringtones & previews',
      icon: Bell,
      color: '#38bdf8',
    },
    {
      id: 'appearance' as const,
      defaultSub: 'appear-theme' as const,
      label: 'Appearance',
      description: 'Themes, wallpapers & font sizes',
      icon: Palette,
      color: '#f59e0b',
    },
    {
      id: 'storage' as const,
      defaultSub: 'storage-cache' as const,
      label: 'Storage & Data',
      description: 'Cache, export & encryption info',
      icon: HardDrive,
      color: '#ec4899',
    },
    {
      id: 'feedback' as const,
      defaultSub: 'feedback-send' as const,
      label: 'Feedback',
      description: 'Suggestions, bugs & feature requests',
      icon: MessageSquarePlus,
      color: '#06b6d4',
    },
  ];

  return (
    <section className={`settings-nav ${isCompact ? 'is-compact' : ''}`} aria-label="Settings">
      <header className="settings-nav-heading">
        {isCompact ? <Settings size={20} /> : <><h2>Settings</h2><p>Make Novyn yours.</p></>}
      </header>
      <button type="button" className="settings-account" title="Edit your profile"
        onClick={() => onSelectCategory('profile', 'profile-details')}>
        <Avatar name={user?.displayName || user?.username || 'You'}
          avatarUrl={user?.avatarId || (user?.username ? localStorage.getItem(`novyn_avatar_${user.username}`) || undefined : undefined)}
          size={isCompact ? 'sm' : 'md'} />
        {!isCompact && <span><strong>{user?.displayName || user?.username}</strong><small>@{user?.username}</small></span>}
        {!isCompact && <ChevronRight size={16} />}
      </button>
      <nav className="settings-categories" aria-label="Settings categories">
        {!isCompact && <p className="settings-eyebrow">PREFERENCES</p>}
        {categories.map(({ id, defaultSub, label, icon: Icon }) => (
          <button key={id} type="button" title={label} aria-label={label}
            aria-current={activeCategory === id ? 'page' : undefined}
            onClick={() => { triggerHaptic('light'); onSelectCategory(id, defaultSub); }}>
            <Icon size={19} />
            {!isCompact && <><span>{label}</span><ChevronRight className="settings-category-arrow" size={15} /></>}
          </button>
        ))}
      </nav>
      <footer className="settings-nav-footer">
        <button type="button" title="Sign Out" aria-label="Sign Out"
          onClick={() => { triggerHaptic('heavy'); logout(); }}>
          <LogOut size={18} />{!isCompact && 'Sign Out'}
        </button>
        {!isCompact && <small>Your space. Your preferences.</small>}
      </footer>
    </section>
  );
};
