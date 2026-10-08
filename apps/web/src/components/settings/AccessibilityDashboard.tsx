import { useCallback, useState } from 'react';
import { Contrast, MoveHorizontal, Play, Check } from 'lucide-react';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export function AccessibilityDashboard() {
  const reduced = useBrowserPreference('novyn_reduce_motion', 'false') === 'true';
  const contrast = useBrowserPreference('novyn_high_contrast', 'false') === 'true';
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const [previewEnd, setPreviewEnd] = useState(false);
  const dismiss = useCallback(() => setNotice(null), []);
  const save = (key: string, value: boolean) => {
    try { setBrowserPreference(key, String(value)); setNotice(null); }
    catch { setNotice({ text: 'This browser could not save your preference.', error: true }); }
  };
  return <section className="web-settings accessibility-dashboard" aria-label="Accessibility settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismiss} />}
    <div className="accessibility-grid">
      <article className="accessibility-card accessibility-motion-card">
        <div className="accessibility-control"><span className="accessibility-symbol"><MoveHorizontal size={22} aria-hidden="true" /></span><div><h3>Reduce motion</h3><p>Keep transitions calm and minimize movement.</p></div>
          <button type="button" className={'settings-toggle ' + (reduced ? 'is-on' : 'is-off')} role="switch" aria-label="Reduce motion" aria-checked={reduced} onClick={() => save('novyn_reduce_motion', !reduced)}><span /></button>
        </div>
        <p className="accessibility-detail">Reduces animations across Novyn, including the profile orbit and globe rotation.</p>
      </article>
      <article className="accessibility-card accessibility-contrast-card">
        <div className="accessibility-control"><span className="accessibility-symbol"><Contrast size={22} aria-hidden="true" /></span><div><h3>High contrast</h3><p>Make text and boundaries easier to distinguish.</p></div>
          <button type="button" className={'settings-toggle ' + (contrast ? 'is-on' : 'is-off')} role="switch" aria-label="High contrast" aria-checked={contrast} onClick={() => save('novyn_high_contrast', !contrast)}><span /></button>
        </div>
        <p className="accessibility-detail">Uses stronger text and borders in both light and dark themes.</p>
      </article>
      <article className="accessibility-card accessibility-preview-card">
        <div className="accessibility-preview-heading"><h3>See the difference</h3><span>Live preview</span></div>
        <div className="accessibility-reading-sample"><div className="accessibility-sample-person"><span aria-hidden="true">A</span><div><strong>Alex</strong><small>Message preview</small></div><Check size={18} aria-hidden="true" /></div><p>A little more clarity, a little less movement.</p><small>Text and borders follow your contrast setting.</small></div>
        <div className="accessibility-motion-heading"><span>Motion preview</span><button type="button" onClick={() => setPreviewEnd(value => !value)}><Play size={14} aria-hidden="true" />Try transition</button></div>
        <div className="accessibility-motion-track" aria-hidden="true"><span data-end={previewEnd} /></div>
        <p className="accessibility-preview-note">{reduced ? 'The marker changes position without a sliding animation.' : 'Try the transition to compare movement. Your device’s reduced-motion preference is also respected.'}</p>
      </article>
    </div>
    <p className="accessibility-footer">Saved automatically for this browser. Font and message size are available in Appearance.</p>
  </section>;
}
