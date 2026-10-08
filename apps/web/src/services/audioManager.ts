// Universal Audio Manager for Novyn Chat
// Plays real audio files from /audio/ with fallback to synthesized Web Audio API

let activeRingtoneAudio: HTMLAudioElement | null = null;
let activeCallRingAudio: HTMLAudioElement | null = null;
let synthAudioContext: AudioContext | null = null;
let synthInterval: any = null;

export const MESSAGE_CHIMES = [
  { id: 'drift', name: 'Drift', source: '/audio/notification.mp3' },
  { id: 'pulse', name: 'Pulse', source: '/audio/chime-pulse.wav' },
  { id: 'glass', name: 'Glass', source: '/audio/chime-glass.wav' },
  { id: 'echo', name: 'Echo', source: '/audio/chime-echo.wav' },
] as const;

export function getSoundVolume(kind: 'message' | 'call'): number {
  const saved = localStorage.getItem('novyn_' + kind + '_volume');
  const value = saved === null || saved.trim() === '' ? NaN : Number(saved);
  return Number.isFinite(value) ? Math.min(100, Math.max(0, value)) / 100 : kind === 'message' ? .8 : .85;
}

function messageChimeSource(): string {
  return (MESSAGE_CHIMES.find(item => item.id === localStorage.getItem('novyn_message_chime')) || MESSAGE_CHIMES[0]).source;
}

export function refreshCallAudioVolume(): void {
  const volume = getSoundVolume('call');
  if (!volume) { stopAllCallAudio(); return; }
  if (activeRingtoneAudio) activeRingtoneAudio.volume = volume;
  if (activeCallRingAudio) activeCallRingAudio.volume = volume;
}

// Preview owns its audio; stopping it must never end an actual call's ringtone.
export function previewSound(kind: 'message' | 'ringtone' | 'ringback', onEnd: (failed?: boolean) => void) {
  const audio = new Audio(kind === 'message' ? messageChimeSource() : kind === 'ringtone' ? '/audio/ringtone.mp3' : '/audio/call_ring.mp3');
  audio.volume = getSoundVolume(kind === 'message' ? 'message' : 'call');
  let stopped = false;
  let timer: ReturnType<typeof setTimeout>;
  const stop = (failed = false) => {
    if (stopped) return;
    stopped = true;
    clearTimeout(timer);
    audio.onended = null; audio.onerror = null;
    audio.pause(); audio.currentTime = 0;
    onEnd(failed);
  };
  audio.onended = () => stop();
  audio.onerror = () => stop(true);
  timer = setTimeout(stop, 4000);
  try { audio.play()?.catch(() => stop(true)); } catch { stop(true); }
  return { stop, setVolume: (volume: number) => { audio.volume = Math.max(0, Math.min(1, volume)); } };
}

// 1. INCOMING CALL RINGTONE (/audio/ringtone.mp3)
export function playIncomingRingtone(): void {
  if (localStorage.getItem('novyn_call_sound') === 'false' || getSoundVolume('call') === 0) return;
  stopIncomingRingtone();
  stopOutgoingCallRing();

  try {
    const audio = new Audio('/audio/ringtone.mp3');
    audio.loop = true;
    audio.volume = getSoundVolume('call');
    activeRingtoneAudio = audio;

    const playPromise = audio.play();
    if (playPromise !== undefined) {
      playPromise.catch(() => {
        playSynthesizedRingtone();
      });
    }
  } catch {
    playSynthesizedRingtone();
  }
}

export function stopIncomingRingtone(): void {
  if (activeRingtoneAudio) {
    try {
      activeRingtoneAudio.pause();
      activeRingtoneAudio.currentTime = 0;
    } catch {}
    activeRingtoneAudio = null;
  }
  stopSynthesizedRingtone();
}

// 2. OUTGOING CALL RINGING (/audio/call_ring.mp3)
export function playOutgoingCallRing(): void {
  if (localStorage.getItem('novyn_call_sound') === 'false' || getSoundVolume('call') === 0) return;
  stopOutgoingCallRing();
  stopIncomingRingtone();

  try {
    const audio = new Audio('/audio/call_ring.mp3');
    audio.loop = true;
    audio.volume = getSoundVolume('call');
    activeCallRingAudio = audio;

    const playPromise = audio.play();
    if (playPromise !== undefined) {
      playPromise.catch(() => {
        playSynthesizedRingtone();
      });
    }
  } catch {
    playSynthesizedRingtone();
  }
}

export function stopOutgoingCallRing(): void {
  if (activeCallRingAudio) {
    try {
      activeCallRingAudio.pause();
      activeCallRingAudio.currentTime = 0;
    } catch {}
    activeCallRingAudio = null;
  }
  stopSynthesizedRingtone();
}

// Stop all call audios
export function stopAllCallAudio(): void {
  stopIncomingRingtone();
  stopOutgoingCallRing();
}

// 3. INCOMING MESSAGE NOTIFICATION (/audio/notification.mp3)
export function playMessageNotification(): void {
  const isSoundEnabled = localStorage.getItem('novyn_sound') !== 'false';
  if (!isSoundEnabled || getSoundVolume('message') === 0) return;

  try {
    const audio = new Audio(messageChimeSource());
    audio.volume = getSoundVolume('message');
    const p = audio.play();
    if (p !== undefined) {
      p.catch(() => playSynthesizedChime());
    }
  } catch {
    playSynthesizedChime();
  }
}

// 4. OUTGOING MESSAGE SENT (/audio/message_sent.mp3)
export function playMessageSentSound(): void {
  const isSoundEnabled = localStorage.getItem('novyn_sound') !== 'false';
  if (!isSoundEnabled || getSoundVolume('message') === 0) return;

  try {
    const audio = new Audio('/audio/message_sent.mp3');
    audio.volume = getSoundVolume('message') * .875;
    const p = audio.play();
    if (p !== undefined) {
      p.catch(() => playSynthesizedSent());
    }
  } catch {
    playSynthesizedSent();
  }
}

// --- Synthesizer Fallbacks (Web Audio API) ---

function playSynthesizedRingtone(): void {
  stopSynthesizedRingtone();
  try {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioCtx) return;
    synthAudioContext = new AudioCtx();

    const playTonePair = () => {
      if (!synthAudioContext || synthAudioContext.state === 'closed') return;
      try {
        const osc1 = synthAudioContext.createOscillator();
        const osc2 = synthAudioContext.createOscillator();
        const gain = synthAudioContext.createGain();

        osc1.type = 'sine';
        osc2.type = 'sine';
        osc1.frequency.setValueAtTime(440, synthAudioContext.currentTime);
        osc2.frequency.setValueAtTime(480, synthAudioContext.currentTime);

        gain.gain.setValueAtTime(Math.max(.0001, .08 * getSoundVolume('call')), synthAudioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, synthAudioContext.currentTime + 1.2);

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(synthAudioContext.destination);

        osc1.start();
        osc2.start();
        osc1.stop(synthAudioContext.currentTime + 1.2);
        osc2.stop(synthAudioContext.currentTime + 1.2);
      } catch {}
    };

    playTonePair();
    synthInterval = setInterval(playTonePair, 2500);
  } catch {}
}

function stopSynthesizedRingtone(): void {
  if (synthInterval) {
    clearInterval(synthInterval);
    synthInterval = null;
  }
  if (synthAudioContext && synthAudioContext.state !== 'closed') {
    try {
      synthAudioContext.close();
    } catch {}
    synthAudioContext = null;
  }
}

function playSynthesizedChime(): void {
  try {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
    osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.12); // A5

    gain.gain.setValueAtTime(Math.max(.0001, .08 * getSoundVolume('message')), ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.28);
    setTimeout(() => ctx.close(), 300);
  } catch {}
}

function playSynthesizedSent(): void {
  try {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1174.66, ctx.currentTime + 0.08);

    gain.gain.setValueAtTime(Math.max(.0001, .06 * getSoundVolume('message')), ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.15);
    setTimeout(() => ctx.close(), 200);
  } catch {}
}
