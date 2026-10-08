import { useState, type CSSProperties } from 'react';
import { applyFontSize, MESSAGE_SIZE_MAX, MESSAGE_SIZE_MIN, resolveFontSize } from '../../services/settingsTheme';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';

export function MessageSizeSlider({ onError }: { onError: () => void }) {
  const saved = useBrowserPreference('novyn_font_size', 'md');
  const [draft, setDraft] = useState<number | null>(null);
  const value = draft ?? resolveFontSize(saved);
  const progress = Math.round((value - MESSAGE_SIZE_MIN) / (MESSAGE_SIZE_MAX - MESSAGE_SIZE_MIN) * 100);
  const commit = () => {
    if (draft === null) return;
    try { applyFontSize(draft); setBrowserPreference('novyn_font_size', String(draft)); }
    catch { onError(); }
    setDraft(null);
  };

  return <label className="web-settings-field appearance-size-field">
    <span className="appearance-size-label">Message text size<output>{value} px</output></span>
    <span className="appearance-size-slider"><span aria-hidden="true">Aa</span>
      <input type="range" min={0} max={100} step={1} value={progress} aria-label="Message text size" aria-valuetext={value + ' pixels'}
        style={{ '--size-progress': progress + '%' } as CSSProperties}
        onChange={event => {
          const next = resolveFontSize(MESSAGE_SIZE_MIN + Number(event.target.value) / 100 * (MESSAGE_SIZE_MAX - MESSAGE_SIZE_MIN));
          setDraft(next);
          document.documentElement.style.setProperty('--message-font-size', next + 'px');
        }} onPointerUp={commit} onPointerCancel={commit} onKeyUp={commit} onBlur={commit} />
      <span aria-hidden="true">Aa</span>
    </span>
  </label>;
}
