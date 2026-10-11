import { useCallback, useState } from 'react';
import { Check, Moon, Monitor, Sun, Palette } from 'lucide-react';
import { applyColorMode, applyFontFamily, applyThemeAccent, THEME_PRESETS } from '../../services/settingsTheme';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { setDockAlwaysVisible, useDockAlwaysVisible } from '../../services/dockPreferences';
import { triggerHaptic } from '../../services/capacitor';
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
  const accent = useBrowserPreference('novyn_theme_accent', 'purple');
  const dockVisible = useDockAlwaysVisible();
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);

  const preference = (key: string, value: string, apply: () => void) => {
    try {
      setBrowserPreference(key, value);
      apply();
    } catch {
      setNotice({ text: 'This browser could not save your preference.', error: true });
    }
  };

  return (
    <section className="web-settings appearance-dashboard" aria-label="Appearance settings">
      {notice && <SettingsToast notice={notice} onDismiss={dismissNotice} />}
      <div className="appearance-grid">
        <article className="appearance-card appearance-theme-card">
          <h3>Make Novyn feel at home</h3>
          <p>Choose how Novyn looks in this browser.</p>
          <div className="appearance-theme-options" role="group" aria-label="Color mode">
            {modes.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  key={item.value}
                  type="button"
                  className={'appearance-theme-option is-' + item.value}
                  aria-pressed={mode === item.value}
                  onClick={() => preference('novyn_color_mode', item.value, () => applyColorMode(item.value))}
                >
                  <span className="appearance-theme-preview" aria-hidden="true">
                    <i className="theme-preview-incoming" />
                    <i className="theme-preview-outgoing" />
                    <i className="theme-preview-incoming is-short" />
                  </span>
                  <span className="appearance-theme-label">
                    <Icon size={15} aria-hidden="true" />
                    {item.label}
                  </span>
                  {mode === item.value && <Check className="appearance-theme-check" size={16} aria-hidden="true" />}
                </button>
              );
            })}
          </div>
          <p className="appearance-theme-note">
            {mode === 'system'
              ? 'System follows your device’s light or dark mode.'
              : mode === 'dark'
                ? 'A darker view for your chats and settings.'
                : 'A brighter view for your chats and settings.'}
          </p>
        </article>

        <article className="appearance-card appearance-dock-card">
          <div>
            <h3>Always show navigation dock</h3>
            <p>Keep navigation visible while scrolling.</p>
          </div>
          <button
            type="button"
            role="switch"
            aria-label="Always show navigation dock"
            aria-checked={dockVisible}
            className={'settings-toggle ' + (dockVisible ? 'is-on' : 'is-off')}
            onClick={() => setDockAlwaysVisible(!dockVisible)}
          >
            <span />
          </button>
        </article>

        <article className="appearance-card appearance-type-card">
          <h3>Typography &amp; Size</h3>
          <FontSelect value={font} onChange={(next) => preference('novyn_font_family', next, () => applyFontFamily(next))} />
          <MessageSizeSlider onError={() => setNotice({ text: 'This browser could not save your preference.', error: true })} />
          <div className="appearance-chat-preview">This is how chats will read</div>
        </article>

        <article className="appearance-card appearance-wallpaper-card appearance-accent-card">
          <div className="appearance-card-heading">
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: 10,
                  background: 'var(--primary-glow)',
                  display: 'grid',
                  placeItems: 'center',
                  color: 'var(--primary)',
                  flexShrink: 0,
                }}
              >
                <Palette size={18} />
              </div>
              <div>
                <h3 style={{ margin: 0, fontSize: 16 }}>App Themes &amp; Accent Colors</h3>
                <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                  Choose an accent palette to style messages, buttons, badges, and system highlights
                </span>
              </div>
            </div>
          </div>
          <div className="appearance-wallpaper-options appearance-accent-options" role="group" aria-label="App themes and accent colors">
            {Object.entries(THEME_PRESETS).map(([id, preset]) => (
              <button
                type="button"
                key={id}
                aria-pressed={accent === id}
                title={`${preset.name}: ${preset.description}`}
                onClick={() => {
                  triggerHaptic('light');
                  preference('novyn_theme_accent', id, () => applyThemeAccent(id));
                  setNotice({ text: `${preset.name} theme activated!`, error: false });
                }}
              >
                <span
                  className="appearance-wallpaper-swatch appearance-accent-swatch"
                  style={{
                    borderColor: accent === id ? preset.accent : undefined,
                  }}
                  aria-hidden="true"
                >
                  <i className="wallpaper-preview-incoming" />
                  <i
                    className="wallpaper-preview-outgoing"
                    style={{
                      background: preset.gradient,
                      boxShadow: `0 2px 10px ${preset.accentGlow}`,
                    }}
                  />
                  {accent === id && (
                    <span
                      className="accent-check-badge"
                      style={{
                        position: 'absolute',
                        top: 7,
                        right: 7,
                        width: 22,
                        height: 22,
                        borderRadius: '50%',
                        background: preset.accent,
                        display: 'grid',
                        placeItems: 'center',
                        color: '#ffffff',
                        boxShadow: `0 0 10px ${preset.accentGlow}`,
                      }}
                    >
                      <Check size={14} strokeWidth={3} />
                    </span>
                  )}
                  <span
                    style={{
                      position: 'absolute',
                      bottom: 8,
                      left: 10,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 5,
                      fontSize: 10,
                      fontWeight: 700,
                      color: preset.accent,
                    }}
                  >
                    <span
                      style={{
                        width: 7,
                        height: 7,
                        borderRadius: '50%',
                        background: preset.accent,
                        boxShadow: `0 0 6px ${preset.accentGlow}`,
                      }}
                    />
                    {preset.name.split(' ')[0]}
                  </span>
                </span>
                <strong>{preset.name}</strong>
              </button>
            ))}
          </div>
        </article>
      </div>
    </section>
  );
}
