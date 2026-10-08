import { useCallback, useEffect, useMemo, useState } from 'react';
import { Clock3, Globe2, Languages } from 'lucide-react';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { getDeviceTimeZone, getPreferredLocale, getPreferredTimeZone, getTimeZoneOptions, isValidTimeZone } from '../../services/regionalPreferences';
import { SettingsSelect } from './FontSelect';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import { RegionGlobe } from './RegionGlobe';

const languages = [
  { id: 'en', name: 'English', description: 'English' },
  { id: 'hi', name: 'हिन्दी', description: 'Hindi' },
];
const regions = [
  { id: 'IN', name: 'India', description: 'Indian regional formats' },
  { id: 'US', name: 'United States', description: 'US regional formats' },
  { id: 'GB', name: 'United Kingdom', description: 'UK regional formats' },
];

export function LanguageDashboard() {
  const language = useBrowserPreference('novyn_settings_language', 'en');
  const region = useBrowserPreference('novyn_region', 'IN');
  const mode = useBrowserPreference('novyn_time_zone_mode', 'auto') === 'manual' ? 'manual' : 'auto';
  const savedZone = useBrowserPreference('novyn_time_zone', getDeviceTimeZone());
  const manualZone = isValidTimeZone(savedZone) ? savedZone : getDeviceTimeZone();
  const timeZones = useMemo(() => {
    const options = getTimeZoneOptions();
    return options.some(option => option.id === manualZone) ? options : [...options, { id: manualZone, name: manualZone.replace(/_/g, ' '), description: manualZone }];
  }, [manualZone]);
  const [now, setNow] = useState(() => new Date());
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);
  useEffect(() => {
    let timer = 0;
    const refresh = () => {
      window.clearTimeout(timer);
      setNow(new Date());
      timer = window.setTimeout(refresh, 60000 - Date.now() % 60000 + 30);
    };
    const onVisibility = () => { if (!document.hidden) refresh(); };
    refresh();
    document.addEventListener('visibilitychange', onVisibility);
    return () => { window.clearTimeout(timer); document.removeEventListener('visibilitychange', onVisibility); };
  }, [region, mode, savedZone]);
  const save = (key: string, value: string) => {
    try { setBrowserPreference(key, value); setNotice(null); }
    catch { setNotice({ text: 'This browser could not save your preference.', error: true }); }
  };
  const locale = getPreferredLocale();
  const timeZone = getPreferredTimeZone();
  const city = timeZone.split('/').pop()!.replace(/_/g, ' ');
  const date = new Intl.DateTimeFormat(locale, { dateStyle: 'long', timeZone }).format(now);
  const time = new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit', timeZone, timeZoneName: 'short' }).format(now);
  const weekday = new Intl.DateTimeFormat(locale, { weekday: 'long', timeZone }).format(now);

  return <section className="web-settings language-dashboard" aria-label="Language and region settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
    <div className="language-grid">
      <article className="language-card language-choice-card">
        <div className="language-card-heading"><span><Languages size={21} aria-hidden="true" /></span><div><h3>Your language</h3><p>Make settings feel familiar.</p></div></div>
        <SettingsSelect label="Settings language" options={languages} value={language} onChange={value => save('novyn_settings_language', value)} />
        <p className="language-note">Changes the main settings menu and date formatting. Some labels remain in English.</p>
      </article>
      <article className="language-card language-region-card">
        <div className="language-card-heading"><span><Globe2 size={21} aria-hidden="true" /></span><div><h3>Regional format</h3><p>Choose how dates and times are displayed.</p></div></div>
        <SettingsSelect label="Region" options={regions} value={region} onChange={value => save('novyn_region', value)} />
        <div className="language-zone-settings">
          <h4>Time zone</h4>
          <div className="language-zone-modes" role="group" aria-label="Time zone mode">
            <button type="button" aria-pressed={mode === 'auto'} onClick={() => save('novyn_time_zone_mode', 'auto')}>Automatic</button>
            <button type="button" aria-pressed={mode === 'manual'} onClick={() => save('novyn_time_zone_mode', 'manual')}>Manual</button>
          </div>
          {mode === 'manual' ? <SettingsSelect label="Choose time zone" options={timeZones} value={manualZone} searchable onChange={value => save('novyn_time_zone', value)} />
            : <div className="language-device-zone"><Clock3 size={16} aria-hidden="true" /><span>{getDeviceTimeZone().replace(/_/g, ' ')}</span><small>Device time zone</small></div>}
          <p className="language-note">{mode === 'auto' ? 'Follows your device automatically. No location permission needed.' : 'Applies to dates and times in this browser. Your region stays the same.'}</p>
        </div>
      </article>
      <article className="language-card language-preview-card">
        <div className="language-preview-heading"><h3>Your region</h3><span>Live preview</span></div>
        <RegionGlobe region={region} />
        <div className="language-date-preview"><span>{weekday}</span><output>{date}</output></div>
        <div className="language-time-preview" data-time-zone={timeZone}><Clock3 size={18} aria-hidden="true" /><span>{mode === 'auto' ? 'Device time' : 'Local time'} · {city}</span><output>{time}</output></div>
        <p className="language-note">Saved automatically for this browser. Your messages keep their original language.</p>
      </article>
    </div>
  </section>;
}
