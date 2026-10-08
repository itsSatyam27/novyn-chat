import { useCallback, useState } from 'react';
import { Check, Moon, Monitor, Sun } from 'lucide-react';
import { applyColorMode, applyFontFamily, applyWallpaper, WALLPAPER_PRESETS } from '../../services/settingsTheme';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { setDockAlwaysVisible, useDockAlwaysVisible } from '../../services/dockPreferences';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import { FontSelect } from './FontSelect';
import { MessageSizeSlider } from './MessageSizeSlider';

const modes = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System', icon: Monitor },
] as const;
export function AppearanceDashboard() {
  const mode = useBrowserPreference('novyn_color_mode', 'light');
  const font = useBrowserPreference('novyn_font_family', 'plus-jakarta');
  const wallpaper = useBrowserPreference('novyn_wallpaper', 'glass');
  const dockVisible = useDockAlwaysVisible();
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);
  const preference = (key: string, value: string, apply: () => void) => {
    try { setBrowserPreference(key, value); apply(); }
    catch { setNotice({ text: 'This browser could not save your preference.', error: true }); }
  };

  return <section className="web-settings appearance-dashboard" aria-label="Appearance settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
    <div className="appearance-grid">
      <article className="appearance-card appearance-theme-card">
        <h3>Make Novyn feel at home</h3><p>Choose how Novyn looks in this browser.</p>
        <div className="appearance-theme-options" role="group" aria-label="Color mode">
          {modes.map(item => {
            const Icon = item.icon;
            return <button key={item.value} type="button" className={'appearance-theme-option is-' + item.value}
              aria-pressed={mode === item.value} onClick={() => preference('novyn_color_mode', item.value, () => applyColorMode(item.value))}>
              <span className="appearance-theme-preview" aria-hidden="true">
                <i className="theme-preview-incoming" /><i className="theme-preview-outgoing" />
                <i className="theme-preview-incoming is-short" />
              </span>
              <span className="appearance-theme-label"><Icon size={15} aria-hidden="true" />{item.label}</span>
              {mode === item.value && <Check className="appearance-theme-check" size={16} aria-hidden="true" />}
            </button>;
          })}
        </div>
        <p className="appearance-theme-note">{mode === 'system' ? 'System follows your device’s light or dark mode.' : mode === 'dark' ? 'A darker view for your chats and settings.' : 'A brighter view for your chats and settings.'}</p>
      </article>
      <article className="appearance-card appearance-dock-card">
        <div><h3>Always show navigation dock</h3><p>Keep navigation visible while scrolling.</p></div>
        <button type="button" role="switch" aria-label="Always show navigation dock" aria-checked={dockVisible}
          className={'settings-toggle ' + (dockVisible ? 'is-on' : 'is-off')} onClick={() => setDockAlwaysVisible(!dockVisible)}><span /></button>
      </article>
      <article className="appearance-card appearance-type-card">
        <h3>Typography &amp; Size</h3>
        <FontSelect value={font} onChange={next => preference('novyn_font_family', next, () => applyFontFamily(next))} />
        <MessageSizeSlider onError={() => setNotice({ text: 'This browser could not save your preference.', error: true })} />
        <div className="appearance-chat-preview">This is how chats will read</div>
      </article>
      <article className="appearance-card appearance-wallpaper-card">
        <div className="appearance-card-heading"><h3>Chat Wallpapers</h3><span>Choose a backdrop for your conversations</span></div>
        <div className="appearance-wallpaper-options" role="group" aria-label="Chat wallpaper">
          {Object.entries(WALLPAPER_PRESETS).map(([id, preset]) => <button type="button" key={id} aria-pressed={wallpaper === id}
            title={preset.name + ': ' + preset.description} onClick={() => preference('novyn_wallpaper', id, () => applyWallpaper(id))}>
            <span className="appearance-wallpaper-swatch" style={{ background: preset.background }} aria-hidden="true">
              <i className="wallpaper-preview-incoming" /><i className="wallpaper-preview-outgoing" />{wallpaper === id && <Check size={16} />}
            </span><strong>{preset.name}</strong>
          </button>)}
        </div>
      </article>
    </div>
  </section>;
}
