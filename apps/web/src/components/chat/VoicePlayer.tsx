import React, { useState, useRef, useEffect } from 'react';
import { Play, Pause } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface VoicePlayerProps {
  url: string;
  isMe: boolean;
  duration?: number;
}

// Simulated dynamic audio waveform heights
const WAVEFORM_BARS = [
  6, 12, 18, 24, 14, 28, 20, 10, 16, 26, 30, 22, 14, 18, 26, 16, 22, 28, 18, 12, 8, 14, 20, 10,
];

export const VoicePlayer: React.FC<VoicePlayerProps> = ({ url, isMe, duration: defaultDuration }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(defaultDuration || 0);
  const [playbackRate, setPlaybackRate] = useState<1 | 1.5 | 2>(1);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    const audio = new Audio(url);
    audioRef.current = audio;

    audio.onloadedmetadata = () => {
      if (audio.duration && Number.isFinite(audio.duration)) {
        setDuration(Math.round(audio.duration));
      }
    };

    audio.ontimeupdate = () => {
      setCurrentTime(audio.currentTime);
    };

    audio.onended = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };

    return () => {
      audio.pause();
      audio.src = '';
    };
  }, [url]);

  const togglePlay = () => {
    if (!audioRef.current) return;
    triggerHaptic('light');

    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.playbackRate = playbackRate;
      audioRef.current.play().catch(console.error);
      setIsPlaying(true);
    }
  };

  const handleWaveformClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!audioRef.current || !duration) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const fraction = Math.max(0, Math.min(1, clickX / rect.width));
    const newTime = fraction * duration;
    audioRef.current.currentTime = newTime;
    setCurrentTime(newTime);
    triggerHaptic('light');
  };

  const cycleSpeed = (e: React.MouseEvent) => {
    e.stopPropagation();
    triggerHaptic('light');
    const nextRate: 1 | 1.5 | 2 = playbackRate === 1 ? 1.5 : playbackRate === 1.5 ? 2 : 1;
    setPlaybackRate(nextRate);
    if (audioRef.current) {
      audioRef.current.playbackRate = nextRate;
    }
  };

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const progressFraction = duration > 0 ? currentTime / duration : 0;
  const activeBarIndex = Math.floor(progressFraction * WAVEFORM_BARS.length);

  return (
    <div
      className={`voice-player ${isMe ? 'is-me' : 'is-other'} ${isPlaying ? 'is-playing' : ''}`}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '8px 10px',
        minWidth: '240px',
        maxWidth: '300px',
        userSelect: 'none',
      }}
    >
      {/* Play/Pause Button */}
      <button
        type="button"
        className="voice-player-toggle"
        onClick={togglePlay}
        style={{
          width: '42px',
          height: '42px',
          borderRadius: '50%',
          background: isMe ? '#ffffff' : '#10b981',
          color: isMe ? '#059669' : 'var(--text-main)',
          border: 'none',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
          flexShrink: 0,
          boxShadow: isMe ? '0 4px 12px rgba(36, 76, 96, 0.1)' : '0 4px 14px rgba(16, 185, 129, 0.4)',
          transition: 'all 0.15s ease',
        }}
        onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.92)')}
        onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
      >
        {isPlaying ? (
          <Pause style={{ width: '19px', height: '19px' }} />
        ) : (
          <Play style={{ width: '19px', height: '19px', marginLeft: '2px' }} />
        )}
      </button>

      {/* Waveform & Time Controls */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '6px', minWidth: 0 }}>
        {/* Interactive Sound Waveform Bars */}
        <div
          className="voice-player-waveform"
          onClick={handleWaveformClick}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '2.5px',
            height: '32px',
            cursor: 'pointer',
            padding: '2px 0',
          }}
          title="Click to seek"
        >
          {WAVEFORM_BARS.map((barHeight, idx) => {
            const isPlayed = idx <= activeBarIndex;
            return (
              <span
                key={idx}
                className={`voice-player-bar ${isPlayed ? 'is-played' : ''}`}
                style={{
                  flex: 1,
                  height: `${barHeight}px`,
                  borderRadius: '9999px',
                  animationDelay: `${idx * 42}ms`,
                }}
              />
            );
          })}
        </div>

        {/* Time and Speed Badge */}
        <div
          className="voice-player-meta"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            fontSize: '0.72rem',
            color: isMe ? 'rgba(20, 52, 63, 0.9)' : 'var(--text-muted)',
            fontFamily: 'monospace',
            fontWeight: 700,
          }}
        >
          <span>{isPlaying || currentTime > 0 ? formatTime(currentTime) : formatTime(duration || 0)}</span>

          <button
            type="button"
            className="voice-player-speed"
            onClick={cycleSpeed}
            style={{
              background: isMe ? 'rgba(23, 66, 78, 0.05)' : 'rgba(255, 255, 255, 0.55)',
              border: isMe ? '1px solid var(--border)' : '1px solid var(--border)',
              color: isMe ? 'var(--text-main)' : '#078779',
              fontSize: '0.68rem',
              fontWeight: 800,
              padding: '2px 7px',
              borderRadius: '8px',
              cursor: 'pointer',
              transition: 'all 0.15s ease',
            }}
            title="Playback speed (1x, 1.5x, 2x)"
          >
            {playbackRate}x
          </button>
        </div>
      </div>
    </div>
  );
};
