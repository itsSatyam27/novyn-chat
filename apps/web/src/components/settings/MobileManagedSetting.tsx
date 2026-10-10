import { Smartphone } from 'lucide-react';
import type { SettingsSubSection } from './SettingsPanel';

type MobileSetting = {
  title: string;
  path?: string[];
  pending?: string;
  note?: string;
};

// Complete mobile guidance for sections that have no active web controls.
// settingsAvailability explicitly opts browser-useful controls into web editing.
export const mobileManagedSettings: Record<SettingsSubSection, MobileSetting> = {
  'profile-details': { title: 'Profile Details & Bio', path: ['Settings', 'Edit Profile'] },
  'profile-username': { title: 'Change Username', path: ['Settings', 'Edit Profile'] },
  'profile-email': { title: 'Linked Email', path: ['Settings', 'Edit Profile'] },
  'profile-presence': { title: 'Presence & Status', path: ['Settings', 'Presence & Status'] },
  'profile-qr': { title: 'QR Code', path: ['Settings', 'QR Code'] },
  'security-dashboard': { title: 'Security', path: ['Settings', 'Security'] },
  'privacy-message-keys': {
    title: 'Sync Message Keys',
    path: ['Settings', 'Security', 'Import message keys'],
    note: 'To export keys from your original browser, use Transfer message keys on the Messages screen.',
  },
  'privacy-blocked': { title: 'Blocked Contacts', path: ['Settings', 'Security & Privacy', 'Blocked Users'] },
  'privacy-password': {
    title: 'Change Password',
    path: ['Settings', 'Security & Privacy', 'Change Password'],
    note: 'Sign in to the mobile app with the same Novyn account.',
  },
  'privacy-app-lock': {
    title: 'App Lock',
    path: ['Settings', 'Security & Privacy', 'App Lock'],
    note: 'The app lock protects the mobile app on that device.',
  },
  'privacy-visibility': {
    title: 'Last Seen & Profile Photo',
    path: ['Settings', 'Security & Privacy'],
  },
  'privacy-controls': {
    title: 'Privacy Controls',
    path: ['Settings', 'Security & Privacy', 'Privacy Controls'],
  },
  'privacy-stealth': {
    title: 'Stealth Mode',
    path: ['Settings', 'Security & Privacy', 'Stealth Mode'],
    note: 'Device protections apply to the mobile app.',
  },
  'privacy-receipts': {
    title: 'Read Receipts & Activity',
    path: ['Settings', 'Security & Privacy', 'Read Receipts'],
  },
  'privacy-retention': {
    title: 'Message Retention',
    pending: 'Message-retention controls are not available in the mobile app yet.',
  },
  'privacy-two-factor': {
    title: 'Two-Factor Authentication',
    pending: 'Two-factor authentication is not available yet. When available, you’ll manage it in the Novyn mobile app.',
  },
  'privacy-sessions': {
    title: 'Active Sessions',
    pending: 'Session management is not available yet. When available, you’ll manage it in the Novyn mobile app.',
  },
  'privacy-linked-devices': {
    title: 'Linked Devices',
    pending: 'Device linking is not available yet. You can currently transfer message keys using Sync Message Keys.',
  },
  'privacy-danger': {
    title: 'Account Actions',
    pending: 'Account deletion is not available yet. When available, you’ll manage it in the Novyn mobile app.',
    note: 'To end this browser session, choose Log Out on the main Settings page.',
  },
  'notif-sounds': { title: 'Sound & Vibration', path: ['Settings', 'Sound & Vibration'] },
  'notif-calls': { title: 'Call Ringtones', path: ['Settings', 'Sound & Vibration'] },
  'notif-previews': { title: 'Notifications & Message Previews', path: ['Settings', 'Notifications'] },
  'appear-theme': { title: 'Appearance', path: ['Settings', 'Appearance'] },
  'appear-wallpaper': { title: 'Chat Wallpapers', pending: 'Chat wallpaper customization is not available in the mobile app yet.' },
  'appear-font': { title: 'Typography & Size', path: ['Settings', 'Accessibility'], note: 'Additional font-family options are not available in the mobile app yet.' },
  'appear-language': { title: 'Language & Region', path: ['Settings', 'Language & Region'] },
  'appear-accessibility': { title: 'Accessibility', path: ['Settings', 'Accessibility'] },
  'storage-cache': { title: 'Data & Storage', path: ['Settings', 'Data & Storage'] },
  'storage-export': { title: 'Backup & Restore', pending: 'Backup and restore are not available in the mobile app yet.' },
  'storage-security': { title: 'Encryption Status', path: ['Settings', 'Security & Privacy'] },
  'feedback-send': { title: 'Help & Support', path: ['Settings', 'Help & Support'] },
  'feedback-bug': { title: 'Report a Bug', path: ['Settings', 'Help & Support'] },
  'feedback-feature': { title: 'Request a Feature', path: ['Settings', 'Help & Support'] },
};

export function MobileManagedSetting({ setting }: { setting: MobileSetting }) {
  return (
    <article className="mobile-managed-setting" aria-label={setting.title}>
      <div className="mobile-managed-setting-heading">
        <span className="mobile-managed-setting-icon"><Smartphone size={24} aria-hidden="true" /></span>
        <div><span className="mobile-managed-setting-badge">{setting.pending ? 'Coming soon' : 'Mobile app'}</span>
          <h3>{setting.pending ? 'Not available yet' : 'Continue in the mobile app'}</h3></div>
      </div>
      <p>Manage this setting in the Novyn mobile app.</p>
      {setting.pending && <p className="mobile-managed-setting-note">{setting.pending}</p>}
      {setting.path && (
        <div className="mobile-managed-setting-directions">
          <h4>In the Novyn mobile app</h4>
          <ol className="mobile-managed-setting-path" aria-label="Where to find this setting in the mobile app">
            {setting.path.map((step, index) => (
              <li key={step}><span className="mobile-managed-setting-step" aria-hidden="true">{index + 1}</span><span>{step}</span></li>
            ))}
          </ol>
        </div>
      )}
      {setting.note && <p className="mobile-managed-setting-note">{setting.note}</p>}
    </article>
  );
}
