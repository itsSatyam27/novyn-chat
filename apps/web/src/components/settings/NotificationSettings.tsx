import { useEffect, useState } from 'react';
import { Bell, ShieldCheck } from 'lucide-react';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import type { SettingsNotice } from './SettingsToast';

const readPermission = () => typeof Notification === 'undefined' ? 'unsupported' as const : Notification.permission;

export function NotificationSettings({ active, onNotice }: { active: boolean; onNotice: (notice: SettingsNotice) => void }) {
  const enabled = useBrowserPreference('novyn_browser_alerts', 'true') !== 'false';
  const previews = useBrowserPreference('novyn_preview', 'true') !== 'false';
  const [permission, setPermission] = useState(readPermission);
  const [requesting, setRequesting] = useState(false);
  const available = permission === 'granted';
  const blocked = permission === 'denied' || permission === 'unsupported';
  useEffect(() => {
    const refresh = () => setPermission(readPermission());
    if (active) refresh();
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
    return () => { window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh); };
  }, [active]);
  const save = (key: string, value: boolean) => {
    try { setBrowserPreference(key, String(value)); }
    catch { onNotice({ text: 'This browser could not save your preference.', error: true }); }
  };
  const enable = async () => {
    if (requesting || blocked) return;
    if (available) { save('novyn_browser_alerts', true); return; }
    setRequesting(true);
    try {
      const next = await Notification.requestPermission();
      setPermission(next);
      if (next === 'granted') { save('novyn_browser_alerts', true); }
      else onNotice({ text: next === 'denied' ? 'Notifications are blocked. Allow them in your browser’s site settings.' : 'Notification permission was not enabled.', error: false });
    } catch { onNotice({ text: 'Could not request notification permission. Check your browser’s site settings.', error: true }); }
    finally { setRequesting(false); }
  };

  return <section className="notification-settings" aria-labelledby="notification-settings-title">
    <div className="notification-section-heading"><Bell size={20} aria-hidden="true" /><div>
      <h3 id="notification-settings-title">Notifications</h3><p>Control desktop alerts and the details they show.</p>
    </div></div>
    <div className="notification-grid">
      <article className="appearance-card notification-controls">
        <div className="web-setting-row"><div><h3>Browser notifications</h3><p>Show desktop alerts while Novyn is open.</p></div>
          <button type="button" role="switch" aria-label="Browser notifications" aria-checked={enabled && available}
            disabled={blocked || requesting} className={'settings-toggle ' + (enabled && available ? 'is-on' : 'is-off')}
            onClick={() => { if (enabled && available) save('novyn_browser_alerts', false); else void enable(); }}><span /></button>
        </div>
        <div className="web-setting-row"><div><h3>Message previews</h3><p>Include message text in desktop alerts.</p></div>
          <button type="button" role="switch" aria-label="Message previews" aria-checked={previews}
            className={'settings-toggle ' + (previews ? 'is-on' : 'is-off')} onClick={() => save('novyn_preview', !previews)}><span /></button>
        </div>
        <div className="notification-permission">
          <div><ShieldCheck size={16} aria-hidden="true" /><span>Browser permission</span>
            <strong data-permission={permission}>{available ? 'Allowed' : permission === 'denied' ? 'Blocked' : permission === 'default' ? 'Not enabled' : 'Unavailable'}</strong></div>
          {permission === 'default' && <><p>Allow notifications to receive desktop alerts from Novyn.</p>
            <button type="button" className="btn btn-primary" disabled={requesting} onClick={() => void enable()}>{requesting ? 'Waiting for permission…' : 'Enable browser notifications'}</button></>}
          {permission === 'denied' && <p>Open your browser’s site settings and allow notifications, then return here.</p>}
          {permission === 'unsupported' && <p>Desktop notifications are unavailable in this browser. Messages still arrive in Novyn.</p>}
        </div>
        <p className="notification-footnote">Turning off desktop alerts keeps messages and unread counts available.</p>
      </article>
      <article className="appearance-card notification-example">
        <div className="appearance-card-heading"><h3>Notification preview</h3><span>Example</span></div>
        <div className="notification-sample" aria-label="Example notification">
          <span className="notification-sample-icon"><Bell size={20} aria-hidden="true" /></span>
          <div><div className="notification-sample-app"><strong>Novyn</strong><span>now</span></div>
            <strong>Alex</strong><p>{previews ? 'Hey, are you free to chat?' : 'New message'}</p></div>
        </div>
        <p>{previews ? 'Message text appears in your notifications.' : 'Message text stays hidden. Only the sender and “New message” appear.'}</p>
        {(!enabled || !available) && <span className="notification-paused">Desktop alerts are currently off.</span>}
      </article>
    </div>
  </section>;
}
