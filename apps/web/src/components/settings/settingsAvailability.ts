import type { SettingsSubSection } from './SettingsPanel';

// Browser preferences stay local; account preferences use the shared backend.
export const webSettings: Partial<Record<SettingsSubSection, { title: string; scope: 'browser' | 'account' | 'tool' }>> = {
  'profile-details': { title: 'Profile Details & Bio', scope: 'account' },
  'profile-presence': { title: 'Presence & Status', scope: 'account' },
  'profile-qr': { title: 'QR Code', scope: 'tool' },
  'privacy-blocked': { title: 'Blocked Contacts', scope: 'account' },
  'privacy-retention': { title: 'Message Retention', scope: 'account' },
  'privacy-message-keys': { title: 'Sync Message Keys', scope: 'tool' },
  'appear-theme': { title: 'Appearance', scope: 'browser' },
  'appear-wallpaper': { title: 'Chat Wallpapers', scope: 'browser' },
  'appear-font': { title: 'Typography & Size', scope: 'browser' },
  'appear-language': { title: 'Language & Region', scope: 'browser' },
  'appear-accessibility': { title: 'Accessibility', scope: 'browser' },
  'notif-sounds': { title: 'Sounds & Notifications', scope: 'browser' },
  'notif-calls': { title: 'Call Sounds', scope: 'browser' },
  'notif-previews': { title: 'Browser Notifications', scope: 'browser' },
  'storage-cache': { title: 'Data & Storage', scope: 'browser' },
  'storage-export': { title: 'Export Chat Data', scope: 'tool' },
  'storage-security': { title: 'Encryption & Security', scope: 'tool' },
  'feedback-send': { title: 'Help & Support', scope: 'tool' },
  'feedback-bug': { title: 'Report a Bug', scope: 'tool' },
  'feedback-feature': { title: 'Request a Feature', scope: 'tool' },
};
export function settingsBadge(section: SettingsSubSection): string {
  return webSettings[section]?.scope === 'account' ? 'Account' : webSettings[section] ? 'Web' : 'Mobile app';
}
