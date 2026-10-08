import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react';
import { BellOff, BellRing, Phone, Play, Square, Volume2 } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { setBrowserPreference, useBrowserPreference } from '../../services/browserPreferences';
import { getSoundVolume, MESSAGE_CHIMES, previewSound, refreshCallAudioVolume, stopAllCallAudio } from '../../services/audioManager';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import { NotificationSettings } from './NotificationSettings';

const bars = [18, 32, 48, 29, 60, 39, 72, 45, 31, 56, 80, 42, 26, 62, 38, 69, 52, 28, 57, 41, 64, 33, 46, 24];
type PreviewKind = 'message' | 'ringtone' | 'ringback';

function SoundWaveform({ playing }: { playing: boolean }) {
  return <div className={'sound-waveform' + (playing ? ' is-playing' : '')} aria-hidden="true">
    {bars.map((height, index) => <i key={index} style={{ height, '--bar-delay': (index % 7) * -.1 + 's' } as CSSProperties} />)}
  </div>;
}

function SoundToggle({ label, description, checked, disabled, onChange }: {
  label: string; description: string; checked: boolean; disabled?: boolean; onChange: (next: boolean) => void;
}) {
  return <div className="web-setting-row"><div><h3>{label}</h3><p>{description}</p></div>
    <button type="button" role="switch" className={'settings-toggle ' + (checked ? 'is-on' : 'is-off')}
      aria-label={label} aria-checked={checked} disabled={disabled} onClick={() => onChange(!checked)}><span /></button>
  </div>;
}

function VolumeSlider({ kind, disabled, onLiveChange, onError }: {
  kind: 'message' | 'call'; disabled: boolean; onLiveChange: (volume: number) => void; onError: () => void;
}) {
  const saved = useBrowserPreference('novyn_' + kind + '_volume', kind === 'message' ? '80' : '85');
  const [draft, setDraft] = useState<number | null>(null);
  const value = draft ?? (Number.isFinite(Number(saved)) ? Math.min(100, Math.max(0, Number(saved))) : kind === 'message' ? 80 : 85);
  const commit = () => {
    if (draft === null) return;
    try { setBrowserPreference('novyn_' + kind + '_volume', String(draft)); if (kind === 'call') refreshCallAudioVolume(); }
    catch { onError(); }
    setDraft(null);
  };
  return <label className="web-settings-field sound-volume-field">
    <span className="appearance-size-label">{kind === 'message' ? 'Message volume' : 'Call volume'}<output>{value}%</output></span>
    <span className="appearance-size-slider"><input type="range" min={0} max={100} step={1} value={value} disabled={disabled}
      aria-label={kind === 'message' ? 'Message volume' : 'Call volume'} aria-valuetext={value + ' percent'}
      style={{ '--size-progress': value + '%' } as CSSProperties}
      onChange={event => { const next = Number(event.target.value); setDraft(next); onLiveChange(next / 100); }}
      onPointerUp={commit} onPointerCancel={commit} onKeyUp={commit} onBlur={commit} /></span>
  </label>;
}

export function SoundDashboard({ active = true }: { active?: boolean }) {
  const { user } = useAuth();
  const sound = useBrowserPreference('novyn_sound', 'true') !== 'false';
  const calls = useBrowserPreference('novyn_call_sound', 'true') !== 'false';
  const chime = useBrowserPreference('novyn_message_chime', 'drift');
  useBrowserPreference('novyn_message_volume', '80');
  useBrowserPreference('novyn_call_volume', '85');
  const busy = user?.presenceMode === 'busy' || (user?.presenceMode as string) === 'dnd';
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const dismiss = useCallback(() => setNotice(null), []);
  const [playing, setPlaying] = useState<PreviewKind | null>(null);
  const [callPreview, setCallPreview] = useState<'ringtone' | 'ringback'>('ringtone');
  const preview = useRef<ReturnType<typeof previewSound> | null>(null);
  const stop = () => { preview.current?.stop(); preview.current = null; };
  useEffect(() => () => { preview.current?.stop(); }, []);
  useEffect(() => {
    if (!active || (playing === 'message' && !sound) || (playing && playing !== 'message' && !calls)) stop();
  }, [active, sound, calls, playing]);
  const saveError = () => setNotice({ text: 'This browser could not save your preference.', error: true });
  const save = (key: string, value: string) => {
    try { setBrowserPreference(key, value); return true; } catch { saveError(); return false; }
  };
  const play = (kind: PreviewKind) => {
    stop(); setPlaying(kind);
    try {
      preview.current = previewSound(kind, failed => {
        setPlaying(null);
        if (failed) setNotice({ text: 'Could not play this preview. Please try again.', error: true });
      });
    } catch { setPlaying(null); setNotice({ text: 'Audio preview is unavailable in this browser.', error: true }); }
  };

  return <section className="web-settings sound-dashboard" aria-label="Sounds and notifications settings">
    {notice && <SettingsToast notice={notice} onDismiss={dismiss} />}
    <div className="sound-grid">
      <article className="appearance-card sound-message-toggle"><SoundToggle label="Message sounds" description="Play sounds for incoming and sent messages."
        checked={sound} onChange={next => save('novyn_sound', String(next))} /></article>
      <article className="appearance-card sound-call-toggle"><SoundToggle label="Call sounds" description="Incoming ringtone and outgoing ringback." checked={calls}
        onChange={next => { if (save('novyn_call_sound', String(next)) && !next) stopAllCallAudio(); }} /></article>
      <article className="appearance-card sound-chime-card">
        <div className="appearance-card-heading"><h3>Message chime</h3><span>Sound for incoming texts</span></div>
        <SoundWaveform playing={playing === 'message'} />
        <div className="sound-preview-row"><button type="button" className="sound-play-button"
          aria-label={playing === 'message' ? 'Stop message preview' : 'Play message sound'} disabled={!sound || getSoundVolume('message') === 0}
          onClick={() => playing === 'message' ? stop() : play('message')}>
          {playing === 'message' ? <Square size={21} fill="currentColor" /> : <Play size={24} fill="currentColor" />}
        </button><VolumeSlider kind="message" disabled={!sound} onError={saveError}
          onLiveChange={volume => { if (playing === 'message') { if (!volume) stop(); else preview.current?.setVolume(volume); } }} /></div>
        <div className="sound-chime-options" role="group" aria-label="Message chime">
          {MESSAGE_CHIMES.map(item => <button key={item.id} type="button" aria-pressed={item.id === chime}
            onClick={() => { if (save('novyn_message_chime', item.id) && sound && getSoundVolume('message') > 0) play('message'); }}>{item.name}</button>)}
        </div>
      </article>
      <article className={'appearance-card sound-busy-card' + (busy ? ' is-active' : '')}>
        <span className="sound-status-icon">{busy ? <BellOff size={22} /> : <BellRing size={22} />}</span>
        <div><div className="appearance-card-heading"><h3>Busy mode</h3><span className="sound-busy-state">{busy ? 'Active' : 'Off'}</span></div>
          <p>{busy ? 'Incoming message and call alerts are muted. You can still preview sounds here.' : 'When your status is Busy, incoming message and call alerts are silenced.'}</p></div>
      </article>
      <article className="appearance-card sound-calls-card">
        <div className="appearance-card-heading"><h3>Call preview</h3><span>{callPreview === 'ringtone' ? 'Incoming ringtone' : 'Outgoing ringback'}</span></div>
        <SoundWaveform playing={playing === callPreview} />
        <div className="sound-preview-row"><button type="button" className="sound-play-button"
          aria-label={(playing === callPreview ? 'Stop ' : 'Play ') + callPreview + ' preview'} disabled={!calls || getSoundVolume('call') === 0}
          onClick={() => playing === callPreview ? stop() : play(callPreview)}>
          {playing === callPreview ? <Square size={21} fill="currentColor" /> : <Play size={24} fill="currentColor" />}
        </button><VolumeSlider kind="call" disabled={!calls} onError={saveError}
          onLiveChange={volume => { if (playing && playing !== 'message') { if (!volume) stop(); else preview.current?.setVolume(volume); } }} /></div>
        <div className="sound-call-previews" role="group" aria-label="Call preview type">
          {(['ringtone', 'ringback'] as const).map(kind => <button key={kind} type="button" aria-pressed={callPreview === kind}
            onClick={() => { setCallPreview(kind); if (calls && getSoundVolume('call') > 0) play(kind); }}>
            {kind === 'ringtone' ? <Phone size={15} /> : <Volume2 size={15} />}
            {kind === 'ringtone' ? 'Ringtone' : 'Ringback'}
          </button>)}
        </div>
      </article>
    </div>
    <NotificationSettings active={active} onNotice={setNotice} />
  </section>;
}
