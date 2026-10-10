import { MessageSquarePlus, Bug, Lightbulb, Search, Send, UserX } from 'lucide-react';
import { SettingsToast } from './SettingsToast';
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import type { SettingsSubSection } from './SettingsPanel';
import { applyFontFamily, applyWallpaper, WALLPAPER_PRESETS } from '../../services/settingsTheme';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { saveAccountSettings, setBlockedContact } from '../../services/accountSettings';
import { MessageKeyTransfer } from './MessageKeyTransfer';
import { FontSelect } from './FontSelect';
import { MessageSizeSlider } from './MessageSizeSlider';
import { Modal } from '../ui/Modal';

export function WebSettings({ section, privacyGroup }: { section: SettingsSubSection; privacyGroup?: 'reach' | 'visibility' }) {
  const { user, setUser } = useAuth();
  const { blockedUsers } = useChat();
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ text: string; error: boolean } | null>(null);
  const [contact, setContact] = useState('');
  const [blockedListOpen, setBlockedListOpen] = useState(false);
  const [blockedSearch, setBlockedSearch] = useState('');
  const [qr, setQr] = useState('');
  const [feedbackType, setFeedbackType] = useState(section === 'feedback-bug' ? 'bug' : section === 'feedback-feature' ? 'feature' : 'general');
  const dismissResult = useCallback(() => setResult(null), []);
  const [feedback, setFeedback] = useState('');
  const [email, setEmail] = useState(user?.email || '');
  const font = useBrowserPreference('novyn_font_family', 'plus-jakarta');
  const wallpaper = useBrowserPreference('novyn_wallpaper', 'glass');
  const currentPresence = user?.presenceMode === 'dnd' ? 'busy' : user?.presenceMode === 'offline' ? 'invisible' : user?.presenceMode || 'online';
  const privacyNotice = section.startsWith('privacy-');
  const blockedContacts = Array.from(blockedUsers).sort((a, b) => a.localeCompare(b));
  const filteredBlockedContacts = blockedContacts.filter(username => username.toLowerCase().includes(blockedSearch.trim().toLowerCase()));

  const run = async (action: () => Promise<void>, success: string) => {
    if (busy) return;
    setBusy(true); setResult(null);
    try { await action(); setResult({ text: success, error: false }); }
    catch (error) { setResult({ text: error instanceof Error ? error.message : 'Could not save. Please try again.', error: true }); }
    finally { setBusy(false); }
  };
  const preference = (key: string, value: string, apply?: () => void) => {
    try { setBrowserPreference(key, value); apply?.(); setResult(null); }
    catch { setResult({ text: 'This browser could not save your preference.', error: true }); }
  };
  const account = (change: Parameters<typeof saveAccountSettings>[1], message: string) => {
    if (user) void run(async () => { await saveAccountSettings(user.username, change); setUser(current => current ? ({ ...current, ...change } as typeof current) : current); }, message);
  };
  useEffect(() => {
    if (section !== 'profile-qr' || !user) return;
    let cancelled = false;
    import('qrcode').then(module => module.toDataURL('https://novyn.app/user/' + encodeURIComponent(user.username), {
      width: 280, margin: 3, errorCorrectionLevel: 'M', color: { dark: '#18152d', light: '#ffffff' },
    })).then(value => { if (!cancelled) setQr(value); })
      .catch(() => { if (!cancelled) setResult({ text: 'Could not generate your QR code.', error: true }); });
    return () => { cancelled = true; };
  }, [section, user?.username]);

  return <section className={"web-settings" + (section.startsWith("feedback-") ? " feedback-dashboard" : "")} aria-label="Web settings controls">
    {result && (section.startsWith("feedback-") || privacyNotice) && <SettingsToast notice={result} onDismiss={dismissResult} />}
    {result && !section.startsWith("feedback-") && !privacyNotice && <p role={result.error ? 'alert' : 'status'} className={'web-settings-result ' + (result.error ? 'is-error' : '')}>{result.text}</p>}
    <Modal isOpen={blockedListOpen} onClose={() => { setBlockedListOpen(false); setBlockedSearch(''); }} title="Blocked contacts" className="blocked-contacts-modal" maxWidth="520px">
      <div className="blocked-list-summary"><span>{blockedContacts.length} blocked {blockedContacts.length === 1 ? 'contact' : 'contacts'}</span></div>
      <label className="blocked-list-search"><Search size={17} aria-hidden="true" /><input autoFocus value={blockedSearch} onChange={event => setBlockedSearch(event.target.value)} placeholder="Search blocked contacts" aria-label="Search blocked contacts" /></label>
      <div className="blocked-list-results">
        {blockedContacts.length === 0 && <div className="blocked-list-empty"><UserX size={25} aria-hidden="true" /><strong>No blocked contacts</strong><span>People you block will appear here.</span></div>}
        {blockedContacts.length > 0 && filteredBlockedContacts.length === 0 && <div className="blocked-list-empty"><Search size={24} aria-hidden="true" /><strong>No matches found</strong><span>Try another username.</span></div>}
        {filteredBlockedContacts.map(username => <div className="blocked-list-row" key={username}><span><i>{username.charAt(0).toUpperCase()}</i><strong>@{username}</strong></span><button type="button" disabled={busy} onClick={() => void run(() => setBlockedContact(username, false), `${username} unblocked.`)}>{busy ? 'Updating…' : 'Unblock'}</button></div>)}
      </div>
    </Modal>

    {section === 'appear-wallpaper' && <div className="web-settings-card">
      <h3>Chat background</h3><div className="web-wallpapers" role="group" aria-label="Chat wallpaper">
        {Object.entries(WALLPAPER_PRESETS).map(([id, preset]) => <button key={id} type="button" aria-pressed={wallpaper === id}
          onClick={() => preference('novyn_wallpaper', id, () => applyWallpaper(id))}>
          <span style={{ background: id === 'glass' ? 'linear-gradient(135deg, #dfe7fa, #c6efec)' : preset.background }} /><strong>{preset.name}</strong>
        </button>)}
      </div>
    </div>}
    {section === 'appear-font' && <div className="web-settings-card">
      <FontSelect value={font} onChange={next => preference('novyn_font_family', next, () => applyFontFamily(next))} />
      <MessageSizeSlider onError={() => setResult({ text: 'This browser could not save your preference.', error: true })} />
      <div className="web-message-preview">A little more room to read comfortably.</div>
    </div>}
    {section === 'profile-presence' && <div className="web-settings-card">
      <h3>How you appear to others</h3><div className="web-status-options" role="group" aria-label="Presence status">
        {[
          ['online', 'Online', '#00c69a', 'Available to chat.'],
          ['away', 'Away', '#ff9d00', 'Stepped away; alerts stay enabled.'],
          ['busy', 'Busy', '#ec4899', 'Messages arrive with incoming alerts silenced.'],
          ['invisible', 'Invisible', '#64748b', 'Appear offline while continuing to chat.'],
        ].map(([value, label, color, description]) => <button key={value} type="button" aria-pressed={currentPresence === value} disabled={busy}
          onClick={() => account({ presenceMode: value }, 'Status updated.')}><i style={{ background: color }} /><span><strong>{label}</strong><small>{description}</small></span></button>)}
      </div>
    </div>}
    {section === 'privacy-retention' && <div className="web-settings-card">
      <h3>Keep messages for</h3><div className="web-settings-choices" role="group" aria-label="Message retention">
        {[7, 15, 30].map(days => <button type="button" key={days} aria-pressed={(user?.retentionDays || 30) === days} disabled={busy}
          onClick={() => account({ retentionDays: days }, 'Message retention updated.')}>{days} days</button>)}
      </div><p>Older messages are hidden from your account. Other people keep their own history preference.</p>
    </div>}
    {(section === 'privacy-controls' || section === 'privacy-receipts') && <div className="web-settings-card privacy-controls">
      {(privacyGroup !== 'visibility') && <div className="privacy-choice-list">{([
        ['callPrivacy', 'Who can call me', 'friends'],
        ['messagePrivacy', 'Who can message me', 'friends'],
        ['groupInvitePrivacy', 'Who can add me to groups', 'friends'],
        ['friendRequestPrivacy', 'Who can send friend requests', 'everyone'],
      ] as const).map(([key, label, fallback]) => {
        const value = user?.[key] || fallback;
        const choices = key === 'friendRequestPrivacy'
          ? [['everyone', 'Everyone'], ['mutuals', 'Mutuals'], ['nobody', 'No one']]
          : [['everyone', 'Everyone'], ['friends', 'Friends'], ['nobody', 'No one']];
        return <div className="privacy-choice-row" key={key}>
          <strong>{label}</strong>
          <div className="privacy-choice-buttons" role="group" aria-label={label}>{choices.map(([choice, choiceLabel]) =>
            <button type="button" key={choice} disabled={busy} aria-pressed={value === choice} onClick={() => account({ [key]: choice } as Parameters<typeof saveAccountSettings>[1], `${label} updated.`)}>{choiceLabel}</button>
          )}</div>
        </div>;
      })}</div>}
      {(privacyGroup !== 'reach') && <div className="privacy-choice-list">{([
        ['profilePhotoPrivacy', 'Profile photo', 'everyone'],
        ['presencePrivacy', 'Online & last seen', 'everyone'],
      ] as const).map(([key, label, fallback]) => {
        const value = user?.[key] || fallback;
        return <div className="privacy-choice-row" key={key}>
          <strong>{label}</strong><div className="privacy-choice-buttons" role="group" aria-label={label}>{[['everyone', 'Everyone'], ['friends', 'Friends'], ['nobody', 'No one']].map(([choice, choiceLabel]) =>
            <button type="button" key={choice} disabled={busy} aria-pressed={value === choice} onClick={() => account({ [key]: choice } as Parameters<typeof saveAccountSettings>[1], `${label} updated.`)}>{choiceLabel}</button>
          )}</div>
        </div>;
      })}</div>}
      {(privacyGroup !== 'reach') && <div className="privacy-toggle-list">{([['readReceiptsEnabled', 'Read receipts', 'Let friends know when you’ve read their messages.'], ['typingIndicatorsEnabled', 'Typing status', 'Let friends know when you’re typing.']] as const).map(([key, label, description]) => <div className="privacy-toggle-row" key={key}>
        <span><strong>{label}</strong><small>{description}</small></span>
        <button type="button" role="switch" aria-checked={user?.[key] !== false} aria-label={label} disabled={busy} className={'privacy-switch' + (user?.[key] !== false ? ' is-on' : '')} onClick={() => account({ [key]: user?.[key] === false } as Parameters<typeof saveAccountSettings>[1], `${label} updated.`)}><i /></button>
      </div>)}</div>}
    </div>}
    {section === 'privacy-blocked' && <div className="web-settings-card">
      <form className="web-block-form" onSubmit={event => { event.preventDefault(); void run(async () => { await setBlockedContact(contact.trim(), true); setContact(''); }, 'Contact blocked.'); }}>
        <label className="web-settings-field">Username<input value={contact} required disabled={busy} placeholder="Enter a username" onChange={event => setContact(event.target.value)} /></label>
        <button className="btn btn-primary" type="submit" disabled={busy || !contact.trim()}>Block contact</button>
      </form>
      <div className="blocked-list-launch"><span>{blockedContacts.length === 0 ? 'No blocked contacts.' : `${blockedContacts.length} blocked ${blockedContacts.length === 1 ? 'contact' : 'contacts'}`}</span><button type="button" onClick={() => setBlockedListOpen(true)}>Manage blocked contacts</button></div>
    </div>}
    {section === 'profile-qr' && <div className="web-settings-card android-qr">
      <h3>@{user?.username}</h3>{qr ? <img src={qr} alt={'Profile QR code for @' + user?.username} width={240} height={240} /> : <p role="status">Generating QR code…</p>}
      {qr && <a className="btn btn-primary" download={'novyn-' + user?.username + '-qr.png'} href={qr}>Download QR code</a>}
      <p>This shares your profile, and does not sign in another device.</p>
    </div>}
    {section === 'privacy-message-keys' && <MessageKeyTransfer />}
    {section.startsWith('feedback-') && <div className="feedback-grid"><form className="web-settings-card feedback-form" onSubmit={event => { event.preventDefault(); void run(async () => {
      const response = await fetch('/api/feedback', { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type: feedbackType, message: feedback.trim(), email }) });
      const data = await response.json();
      if (!response.ok || !data.ok) throw new Error(data.error || data.message || 'Could not send feedback.');
      setFeedback('');
    }, 'Feedback sent.'); }}>
      <div className="feedback-heading"><span><MessageSquarePlus size={24} aria-hidden="true" /></span><div><h3>Help shape Novyn</h3><p>Share an idea, report a problem, or tell us what you think.</p></div></div>
      <label className="web-settings-field">Message<textarea placeholder={feedbackType === 'bug' ? 'What happened? Include the steps to reproduce it and what you expected.' : feedbackType === 'feature' ? 'What would you like to do, and how would it help you?' : 'What is working well? What could be better?'} value={feedback} required minLength={5} maxLength={2000} disabled={busy} onChange={event => setFeedback(event.target.value)} /></label>
      <span className="feedback-count">{feedback.length} / 2000</span>
      <label className="web-settings-field">Reply email (optional)<input type="email" value={email} disabled={busy} onChange={event => setEmail(event.target.value)} /></label>
      <p className="feedback-note">Please leave out passwords, message keys, and private conversations.</p>
      <button type="submit" className="btn btn-primary" disabled={busy || feedback.trim().length < 5}><Send size={16} aria-hidden="true" />{busy ? 'Sending…' : 'Send feedback'}</button>
    </form>
    <aside className="feedback-help">
      <section className="feedback-side-card"><h3>Feedback type</h3>      <div className="feedback-types" role="group" aria-label="Feedback type">{[
        { id: 'general', label: 'General feedback', icon: MessageSquarePlus },
        { id: 'bug', label: 'Report a bug', icon: Bug },
        { id: 'feature', label: 'Feature request', icon: Lightbulb },
      ].map(({ id, label, icon: Icon }) => <button key={id} type="button" disabled={busy} aria-pressed={feedbackType === id} onClick={() => setFeedbackType(id)}><Icon size={20} aria-hidden="true" />{label}</button>)}</div>
</section>
      <section className="feedback-side-card feedback-faqs"><h3>Quick answers</h3><p>Help with your Novyn settings.</p>
        <details><summary>How do I sync message keys to Android?</summary><p>In the browser where your messages are readable, open Data &amp; Storage, then Sync message keys. Download a password-protected key file and import it in the Android app. This is a manual transfer; repeat it for new conversations or changed keys. Keep the file and password private.</p></details>
        <details><summary>What does clearing temporary files remove?</summary><p>Clear temporary files in Data &amp; Storage refreshes cached web assets. Your messages, encryption keys, notes, preferences and sign-in stay available. Clearing all site data through your browser can remove your keys.</p></details>
        <details><summary>How do I change my username?</summary><p>Username and linked email are managed in the Novyn mobile app. You can edit your display name and bio in Profile here on the web.</p></details>
        <details><summary>Why am I not getting notifications?</summary><p>Open Sounds &amp; Notifications and enable browser notifications. Allow notifications for Novyn in your browser settings too. Busy status silences incoming alerts. Check your device notification settings if alerts still do not appear.</p></details>
        <details><summary>Can I hide message text in notifications?</summary><p>Turn off Message previews in Sounds &amp; Notifications. Notifications will show “New message” instead of the message text.</p></details>
      </section>
    </aside></div>}
  </section>;
}
