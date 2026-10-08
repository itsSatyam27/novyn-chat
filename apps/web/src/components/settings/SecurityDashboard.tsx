import { useState } from 'react';
import { ShieldCheck, Smartphone, KeyRound, Ban, History } from 'lucide-react';
import { WebSettings } from './WebSettings';
import { mobileManagedSettings } from './MobileManagedSetting';
import type { SettingsSubSection } from './SettingsPanel';
import { MessageKeyTransferDialog } from '../chat/MessageKeyTransferDialog';
const phoneSettings: SettingsSubSection[] = ['privacy-password', 'privacy-app-lock', 'privacy-visibility', 'privacy-stealth', 'privacy-receipts'];
const pendingSettings: SettingsSubSection[] = ['privacy-two-factor', 'privacy-sessions', 'privacy-linked-devices', 'privacy-danger'];
export function SecurityDashboard() {
  const [keysOpen, setKeysOpen] = useState(false);
  return <section className="security-dashboard" aria-label="Security and privacy settings">
    <div className="security-grid">
      <article className="security-card security-blocked"><h3><Ban size={20} />Blocked Contacts</h3><p>Manage your blocked contacts across your account.</p><WebSettings section="privacy-blocked" /></article>
      <article className="security-card security-retention"><h3><History size={20} />Message Retention</h3><WebSettings section="privacy-retention" /></article>
      <article className="security-card security-keys"><h3><KeyRound size={20} />Sync Message Keys</h3><p>Transfer conversation keys from this browser to Android to read encrypted messages.</p><button type="button" className="btn btn-secondary" aria-haspopup="dialog" onClick={() => setKeysOpen(true)}>Open key transfer</button></article>
      <article className="security-card security-phone"><h3><Smartphone size={20} />Manage in the mobile app</h3><p>Open Novyn on your phone with the same account.</p>{phoneSettings.map(id => { const setting = mobileManagedSettings[id]; return <details key={id}><summary>{setting.title}</summary><div className="security-guidance"><p>Manage this setting in the Novyn mobile app.</p><p>{setting.path?.join(' > ')}</p>{setting.note && <p>{setting.note}</p>}</div></details>; })}</article>
      <article className="security-card security-upcoming"><h3><ShieldCheck size={20} />Not available yet</h3><p>These features are still in development.</p>{pendingSettings.map(id => <details key={id}><summary>{mobileManagedSettings[id].title}</summary><div className="security-guidance"><p>{mobileManagedSettings[id].pending}</p></div></details>)}</article>
    </div>
    <MessageKeyTransferDialog isOpen={keysOpen} onClose={() => setKeysOpen(false)} />
  </section>;
}
