import React, { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { Mic, Trash2, Send } from 'lucide-react';
import { uploadVoiceBlob } from '../../services/api';
import { triggerHaptic } from '../../services/capacitor';

interface VoiceRecorderProps {
  onSendVoice: (voiceUrl: string, duration: number) => void;
  onCancel: () => void;
}

export const VoiceRecorder: React.FC<VoiceRecorderProps> = ({ onSendVoice, onCancel }) => {
  const [seconds, setSeconds] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [waveform, setWaveform] = useState(() => Array.from({ length: 18 }, (_, index) => 0.22 + (index % 4) * 0.08));
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const audioContextRef = useRef<AudioContext | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const lastWaveUpdateRef = useRef(0);

  useEffect(() => {
    let timer: any;
    async function startRecording() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const mediaRecorder = new MediaRecorder(stream);
        mediaRecorderRef.current = mediaRecorder;
        audioChunksRef.current = [];

        // Draw the actual microphone signal instead of a decorative loop.
        const audioContext = new AudioContext();
        const analyser = audioContext.createAnalyser();
        analyser.fftSize = 64;
        audioContext.createMediaStreamSource(stream).connect(analyser);
        audioContextRef.current = audioContext;
        const samples = new Uint8Array(analyser.frequencyBinCount);
        const updateWaveform = (now: number) => {
          analyser.getByteFrequencyData(samples);
          if (now - lastWaveUpdateRef.current > 55) {
            lastWaveUpdateRef.current = now;
            setWaveform(Array.from({ length: 18 }, (_, index) => {
              const sample = samples[Math.min(samples.length - 1, Math.floor((index / 18) * samples.length))] || 0;
              return Math.max(0.16, Math.min(1, sample / 180));
            }));
          }
          animationFrameRef.current = requestAnimationFrame(updateWaveform);
        };
        animationFrameRef.current = requestAnimationFrame(updateWaveform);

        mediaRecorder.ondataavailable = (event) => {
          if (event.data.size > 0) {
            audioChunksRef.current.push(event.data);
          }
        };

        mediaRecorder.start();
        triggerHaptic('medium');

        timer = setInterval(() => {
          setSeconds((prev) => prev + 1);
        }, 1000);
      } catch (err) {
        console.error('Microphone access denied:', err);
        onCancel();
      }
    }

    startRecording();

    return () => {
      if (timer) clearInterval(timer);
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      audioContextRef.current?.close().catch(() => {});
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
        mediaRecorderRef.current.stream.getTracks().forEach((track) => track.stop());
      }
    };
  }, [onCancel]);

  const handleStopAndSend = async () => {
    if (!mediaRecorderRef.current) return;
    setIsUploading(true);
    triggerHaptic('light');

    mediaRecorderRef.current.onstop = async () => {
      const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
      mediaRecorderRef.current?.stream.getTracks().forEach((track) => track.stop());
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      audioContextRef.current?.close().catch(() => {});

      const res = await uploadVoiceBlob(audioBlob);
      if (res.ok && res.url) {
        onSendVoice(res.url, seconds);
      } else {
        alert(res.error || 'Failed to upload voice recording');
        onCancel();
      }
    };

    mediaRecorderRef.current.stop();
  };

  const handleCancel = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current.stream.getTracks().forEach((track) => track.stop());
    }
    if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    audioContextRef.current?.close().catch(() => {});
    triggerHaptic('light');
    onCancel();
  };

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  return (
    <motion.div
      className="voice-recorder"
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.98 }}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        width: '100%',
        background: 'var(--chat-surface, var(--bg-surface))',
        border: '1px solid var(--chat-indigo-border, rgba(109, 93, 252, 0.4))',
        borderRadius: '9999px',
        padding: '6px 12px 6px 16px',
        boxSizing: 'border-box',
        boxShadow: '0 8px 24px rgba(53, 43, 130, 0.15)',
      }}
    >
      {/* Live recording status */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div
          className="voice-recorder-mic"
          style={{
            position: 'relative',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            background: 'rgba(239, 68, 68, 0.15)',
            color: '#ef4444',
          }}
        >
          <Mic style={{ width: '16px', height: '16px' }} />
          <span
            style={{
              position: 'absolute',
              inset: '-3px',
              borderRadius: '50%',
              border: '2px solid #ef4444',
              animation: 'ping 1.2s cubic-bezier(0, 0, 0.2, 1) infinite',
              pointerEvents: 'none',
              opacity: 0.7,
            }}
          />
        </div>

        <span className="voice-recorder-time" style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'monospace', letterSpacing: '0.05em' }}>
          {formatTime(seconds)}
        </span>

        {/* Dynamic soundwave animated bars */}
        <div className="voice-recorder-waveform" style={{ display: 'flex', alignItems: 'center', gap: '3.5px', height: '26px' }}>
          {waveform.map((level, i) => (
            <span
              key={i}
              style={{
                width: '3px',
                height: `${Math.round(8 + level * 22)}px`,
                backgroundColor: 'var(--chat-indigo, #6d5dfc)',
                borderRadius: '9999px',
                transition: 'height 75ms ease-out, opacity 150ms ease',
                opacity: 0.45 + level * 0.55,
              }}
            />
          ))}
        </div>
      </div>

      {/* Action buttons (Trash Cancel & Send) */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
        <button
          className="voice-recorder-cancel"
          type="button"
          onClick={handleCancel}
          disabled={isUploading}
          style={{
            background: 'rgba(239, 68, 68, 0.12)',
            border: '1px solid rgba(239, 68, 68, 0.3)',
            color: '#bd3750',
            borderRadius: '50%',
            width: '40px',
            height: '40px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            transition: 'all 0.15s ease',
          }}
          onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.25)')}
          onMouseLeave={(e) => (e.currentTarget.style.background = 'rgba(239, 68, 68, 0.12)')}
          title="Cancel recording"
        >
          <Trash2 style={{ width: '17px', height: '17px' }} />
        </button>

        <button
          className="voice-recorder-send"
          type="button"
          onClick={handleStopAndSend}
          disabled={isUploading}
          style={{
            width: '42px',
            height: '42px',
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #7c6cff 0%, #5545d6 100%)',
            border: 'none',
            color: 'var(--text-on-primary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            boxShadow: '0 5px 16px rgba(89, 73, 215, 0.48)',
            transition: 'all 0.15s ease',
          }}
          onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.94)')}
          onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
          title="Send voice note"
        >
          {isUploading ? (
            <span style={{ width: '18px', height: '18px', border: '2px solid #ffffff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
          ) : (
            <Send style={{ width: '17px', height: '17px', marginLeft: '2px' }} />
          )}
        </button>
      </div>
    </motion.div>
  );
};
