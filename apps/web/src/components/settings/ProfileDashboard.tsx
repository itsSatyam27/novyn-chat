import { useCallback, useEffect, useRef, useState } from 'react';
import { Bot, ChevronLeft, Copy, Download, Share2, ShieldCheck } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { saveAccountSettings } from '../../services/accountSettings';
import { PRESET_AVATARS } from '../../services/settingsTheme';
import type { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

const statuses = [
  { value: 'online', label: 'Online', color: '#00c69a', description: 'Available to chat.' },
  { value: 'away', label: 'Away', color: '#ff9d00', description: 'Stepped away; incoming alerts stay enabled.' },
  { value: 'busy', label: 'Busy', color: '#ec4899', description: 'Messages still arrive, with incoming alerts silenced.' },
  { value: 'invisible', label: 'Invisible', color: '#64748b', description: 'Appear offline while continuing to chat.' },
];

export function ProfileDashboard({ onBack, onSelectSection }: {
  onBack?: () => void;
  onSelectSection?: (category: SettingsMainCategory, section: SettingsSubSection) => void;
}) {
  const { user } = useAuth();
  const saved = { name: user?.displayName || user?.username || '', bio: user?.bio || '', avatar: user?.avatarId || '' };
  const previous = useRef(saved);
  const [name, setName] = useState(saved.name);
  const [bio, setBio] = useState(saved.bio);
  const [avatar, setAvatar] = useState(saved.avatar);
  const [saving, setSaving] = useState(false);
  const [savingStatus, setSavingStatus] = useState(false);
  const [copying, setCopying] = useState(false);
  const [qr, setQr] = useState('');
  const [qrFailed, setQrFailed] = useState(false);
  const [result, setResult] = useState<SettingsNotice | null>(null);
  const dismissResult = useCallback(() => setResult(null), []);
  const dirty = name !== saved.name || bio !== saved.bio || avatar !== saved.avatar;
  const presence = user?.presenceMode === 'dnd' ? 'busy' : user?.presenceMode === 'offline' ? 'invisible' : user?.presenceMode || 'online';
  const status = statuses.find(item => item.value === presence) || statuses[0];
  const initials = (name.trim() || user?.username || 'You').charAt(0).toUpperCase();

  // Refresh untouched fields if another device edits the profile. Presence
  // updates must not overwrite an unfinished name, bio or avatar edit.
  useEffect(() => {
    const before = previous.current;
    const next = { name: user?.displayName || user?.username || '', bio: user?.bio || '', avatar: user?.avatarId || '' };
    setName(value => value === before.name ? next.name : value);
    setBio(value => value === before.bio ? next.bio : value);
    setAvatar(value => value === before.avatar ? next.avatar : value);
    previous.current = next;
  }, [user?.displayName, user?.username, user?.bio, user?.avatarId]);

  useEffect(() => {
    if (!user?.username) return;
    let cancelled = false;
    setQr(''); setQrFailed(false);
    import('qrcode').then(module => module.toDataURL('https://novyn.app/user/' + encodeURIComponent(user.username), {
      width: 280, margin: 2, errorCorrectionLevel: 'M', color: { dark: '#18152d', light: '#ffffff' },
    })).then(value => { if (!cancelled) setQr(value); })
      .catch(() => { if (!cancelled) setQrFailed(true); });
    return () => { cancelled = true; };
  }, [user?.username]);

  const save = async () => {
    if (!user || saving || !dirty || !name.trim()) return;
    setSaving(true); setResult(null);
    const change = { displayName: name.trim(), bio: bio.trim(), avatarId: avatar };
    try {
      await saveAccountSettings(user.username, change);
      setName(change.displayName); setBio(change.bio);
      setResult({ text: 'Profile updated.', error: false });
    } catch (error) {
      setResult({ text: error instanceof Error ? error.message : 'Could not save your profile. Please try again.', error: true });
    } finally { setSaving(false); }
  };
  const changeStatus = async (value: string) => {
    if (!user || savingStatus || value === presence) return;
    setSavingStatus(true); setResult(null);
    try {
      await saveAccountSettings(user.username, { presenceMode: value });
      setResult({ text: 'Status updated.', error: false });
    } catch (error) {
      setResult({ text: error instanceof Error ? error.message : 'Could not update your status.', error: true });
    } finally { setSavingStatus(false); }
  };
  const discard = () => { setName(saved.name); setBio(saved.bio); setAvatar(saved.avatar); setResult(null); };
  const copyUsername = async () => {
    if (!user?.username || copying) return;
    setCopying(true);
    setResult(null);
    try {
      await navigator.clipboard.writeText(user.username);
      setResult({ text: 'Username copied.', error: false });
    } catch {
      setResult({ text: 'Could not copy. Select your username below and copy it manually.', error: true });
    } finally { setCopying(false); }
  };

  return <section className="web-settings profile-dashboard" aria-label="Profile settings">
    <form onSubmit={event => { event.preventDefault(); void save(); }}>
      <header className="profile-dashboard-header">
        <div>{onBack && <button type="button" className="settings-back" style={{ width: 42, height: 42, borderRadius: 13, background: 'var(--chat-indigo-soft)', borderColor: 'var(--chat-indigo-border)', color: 'var(--chat-indigo)' }} aria-label="Back to Settings" onClick={onBack}><ChevronLeft size={20} /></button>}<h1>Profile</h1></div>
        <div className="profile-dashboard-actions">
          {dirty && <button type="button" className="profile-discard" disabled={saving} onClick={discard}>Discard</button>}
          <button className="btn btn-primary" type="submit" disabled={saving || !dirty || !name.trim()}>{saving ? 'Saving…' : 'Save profile'}</button>
        </div>
      </header>
      {result && <SettingsToast notice={result} onDismiss={dismissResult} />}
      <div className="profile-dashboard-grid">
        <div className="profile-dashboard-column">
        <article className="profile-hero" aria-label="Profile preview">
          <div className="profile-hero-avatar"><span>{initials}</span>
            {avatar && <img key={avatar} src={avatar} alt="" onError={event => { event.currentTarget.style.display = 'none'; }} />}
          </div>
          <h2>{name.trim() || 'Your name'}</h2><span className="profile-hero-handle">@{user?.username}</span>
          <p>{bio.trim() || 'Add a little about yourself.'}</p>
        </article>
        <article className="profile-dashboard-card profile-status-card">
          <h2>Status</h2>
          <div className="profile-status-pills" role="group" aria-label="Presence status">
            {statuses.map(item => <button key={item.value} type="button" aria-pressed={presence === item.value}
              disabled={savingStatus} onClick={() => void changeStatus(item.value)}>
              <i style={{ background: item.color }} aria-hidden="true" />{item.label}
            </button>)}
          </div>
          <p className="profile-status-description">{status.description}</p>
        </article>
        <article className="profile-dashboard-card profile-bio-card">
          <label className="web-settings-field">Display name<input required maxLength={50} value={name} disabled={saving} onChange={event => setName(event.target.value)} /></label>
          <label className="web-settings-field">Bio<textarea maxLength={160} value={bio} disabled={saving} onChange={event => setBio(event.target.value)} /></label>
          <small className="profile-bio-count">{bio.length} / 160</small>
        </article>
        </div>
        <div className="profile-dashboard-column">
        <div className="profile-dashboard-tools">
          <article className="profile-dashboard-card profile-qr-card">
            <div className="profile-card-heading"><h2>QR Code</h2>
              {qr && <a href={qr} download={'novyn-' + user?.username + '-qr.png'} aria-label="Download profile QR code"><Download size={17} /></a>}
            </div>
            {qr ? <img src={qr} alt={'Profile QR code for @' + user?.username} width={104} height={104} />
              : <p role={qrFailed ? 'alert' : 'status'}>{qrFailed ? 'Could not generate your QR code.' : 'Generating QR code…'}</p>}
            <p>Share your profile</p>
          </article>
          <article className="profile-dashboard-card profile-avatar-card">
            <h2>Avatar</h2>
            <div className="profile-avatar-grid" role="group" aria-label="Profile avatar">
              <button type="button" disabled={saving} aria-label="Initials" aria-pressed={avatar === ''} onClick={() => setAvatar('')}><strong>{initials}</strong></button>
              {PRESET_AVATARS.map((url, index) => <button key={url} type="button" disabled={saving} aria-label={'Avatar ' + (index + 1)}
                aria-pressed={avatar === url} onClick={() => setAvatar(url)}>
                <Bot size={23} aria-hidden="true" />
                <img src={url} alt="" loading="lazy" onError={event => { event.currentTarget.style.display = 'none'; }} />
              </button>)}
            </div>
          </article>
        </div>
        <article className="profile-dashboard-card profile-share-card">
          <div className="profile-card-heading"><h2>Share profile</h2><Share2 size={18} aria-hidden="true" /></div>
          <p>Share your username so friends can find you on Novyn.</p>
          <div className="profile-share-actions">
            <span>@{user?.username}</span>
            <button type="button" disabled={!user?.username || copying} onClick={() => void copyUsername()}>
              <Copy size={16} aria-hidden="true" />{copying ? 'Copying…' : 'Copy username'}
            </button>
          </div>
        </article>
        <article className="profile-dashboard-card profile-account-card">
          <div className="profile-card-heading"><h2>Account</h2><ShieldCheck size={18} aria-hidden="true" /></div>
          <div className="profile-account-row"><div><small>Username</small><strong>@{user?.username}</strong></div>
            <button type="button" onClick={() => onSelectSection?.('profile', 'profile-username')}>Change</button></div>
          <div className="profile-account-row"><div><small>Linked email</small><strong>{user?.email || 'No linked email'}</strong></div>
            <button type="button" onClick={() => onSelectSection?.('profile', 'profile-email')}>Manage</button></div>
          <p>Manage your username and email in the Novyn mobile app.</p>
        </article>
        </div>
      </div>
    </form>
  </section>;
}
