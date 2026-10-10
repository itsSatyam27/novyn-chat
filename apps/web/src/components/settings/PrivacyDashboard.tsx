import { useCallback, useState } from 'react';
import { Ban, Check, CheckCheck, Circle, Eye, History, Image, Keyboard, MessageCircle, UserRound, X } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { saveAccountSettings } from '../../services/accountSettings';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import { WebSettings } from './WebSettings';

export function PrivacyDashboard() {
  const { user, setUser } = useAuth();
  const [audience, setAudience] = useState<'friend' | 'other'>('friend');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);
  const save = async (change: Parameters<typeof saveAccountSettings>[1], label: string) => {
    if (!user || busy) return;
    setBusy(true);
    try {
      await saveAccountSettings(user.username, change);
      setUser(current => current ? { ...current, ...change } as typeof current : current);
      setNotice({ text: `${label} updated.`, error: false });
    } catch (error) {
      setNotice({ text: error instanceof Error ? error.message : 'Could not save privacy settings.', error: true });
    } finally { setBusy(false); }
  };
  const visibleTo = (value = 'everyone') => value === 'everyone' || (value === 'friends' && audience === 'friend');
  const photoVisible = visibleTo(user?.profilePhotoPrivacy);
  const presenceVisible = visibleTo(user?.presencePrivacy);
  const mode = user?.presenceMode || 'online';
  const presence = !presenceVisible ? 'Status hidden' : ['offline', 'invisible'].includes(mode) ? 'Offline' : ['busy', 'dnd'].includes(mode) ? 'Busy' : mode === 'away' ? 'Away' : 'Online';
  const name = user?.displayName || user?.username || 'You';
  const previewRows = [
    { label: 'Profile photo', enabled: photoVisible, on: 'Visible', off: 'Hidden' },
    { label: 'Online & last seen', enabled: presenceVisible, on: 'Visible', off: 'Hidden' },
    { label: 'Read receipts', enabled: user?.readReceiptsEnabled !== false, on: 'On', off: 'Off' },
    { label: 'Typing status', enabled: user?.typingIndicatorsEnabled !== false, on: 'On', off: 'Off' },
  ];

  return <section className="privacy-dashboard" aria-label="Privacy settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
    <div className="privacy-overview-grid">
      <article className="security-card privacy-preview-card">
        <h3><span className="privacy-heading-icon"><Eye size={18} /></span>How others see you</h3>
        <div className="privacy-preview-layout">
          <div className="privacy-profile-preview" aria-label="Example of your profile visibility">
            <div className="privacy-preview-avatar">{photoVisible ? user?.avatarId ? <img src={user.avatarId} alt="Your profile" /> : <span>{name.charAt(0).toUpperCase()}</span> : <UserRound size={30} />}{presenceVisible && presence !== 'Offline' && <i data-presence={presence.toLowerCase()} />}</div>
            <strong>{name}</strong><span className="privacy-preview-presence" data-presence={presence.toLowerCase()}>{presence}</span>
            <small>{user?.typingIndicatorsEnabled !== false ? 'Typing indicator shown in chats' : 'Typing indicator hidden'}</small>
          </div>
          <div className="privacy-audience-preview">
            <div className="privacy-preview-audience"><span>View as</span><div className="privacy-choice-buttons" role="group" aria-label="Preview audience"><button type="button" aria-pressed={audience === 'friend'} onClick={() => setAudience('friend')}>A friend</button><button type="button" aria-pressed={audience === 'other'} onClick={() => setAudience('other')}>Anyone else</button></div></div>
            <div className="privacy-preview-results" aria-live="polite">{previewRows.map(row => <div key={row.label} data-visible={row.enabled}><i>{row.enabled ? <Check size={12} /> : <X size={12} />}</i><strong>{row.label}</strong><span>{row.enabled ? row.on : row.off}</span></div>)}</div>
          </div>
        </div>
      </article>
      <article className="security-card privacy-reach-card"><h3><span className="privacy-heading-icon"><MessageCircle size={18} /></span>Who can reach you</h3><WebSettings section="privacy-controls" privacyGroup="reach" /><p>Choose who can call, message, or invite you.</p></article>
      {([
        ['profilePhotoPrivacy', 'Profile photo', Image],
        ['presencePrivacy', 'Online & last seen', Circle],
      ] as const).map(([key, label, Icon]) => <article className="security-card privacy-mini-card" key={key}><h3><span className="privacy-heading-icon"><Icon size={18} /></span>{label}</h3><div className="privacy-choice-buttons" role="group" aria-label={label}>{[['everyone', 'Everyone'], ['friends', 'Friends'], ['nobody', 'No one']].map(([value, text]) => <button type="button" key={value} disabled={busy} aria-pressed={(user?.[key] || 'everyone') === value} onClick={() => void save({ [key]: value }, label)}>{text}</button>)}</div></article>)}
      {([
        ['readReceiptsEnabled', 'Read receipts', 'Let friends know when you’ve read their messages.', CheckCheck],
        ['typingIndicatorsEnabled', 'Typing status', 'Let friends know when you’re typing.', Keyboard],
      ] as const).map(([key, label, description, Icon]) => <article className="security-card privacy-mini-card privacy-mini-toggle" key={key}><div className="privacy-toggle-heading"><h3><span className="privacy-heading-icon"><Icon size={18} /></span>{label}</h3><button type="button" role="switch" aria-label={label} aria-checked={user?.[key] !== false} disabled={busy} className={'privacy-switch' + (user?.[key] !== false ? ' is-on' : '')} onClick={() => void save({ [key]: user?.[key] === false }, label)}><i /></button></div><p>{description}</p></article>)}
      <article className="security-card privacy-blocked-card"><h3><span className="privacy-heading-icon"><Ban size={18} /></span>Blocked contacts</h3><WebSettings section="privacy-blocked" /></article>
      <article className="security-card privacy-retention-card"><h3><span className="privacy-heading-icon"><History size={18} /></span>Message retention</h3><WebSettings section="privacy-retention" /></article>
    </div>
  </section>;
}
