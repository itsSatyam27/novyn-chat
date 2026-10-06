import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import {
  Phone,
  PhoneOff,
  Mic,
  MicOff,
  Video,
  VideoOff,
  Monitor,
  Minimize2,
  Maximize2,
  Sparkles,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

type VideoFilter = 'normal' | 'studio' | 'warm' | 'cyberpunk' | 'noir' | 'blur';

const FILTER_PRESETS: { id: VideoFilter; label: string; css: string }[] = [
  { id: 'normal', label: 'Normal', css: 'none' },
  { id: 'studio', label: 'Studio', css: 'contrast(1.08) brightness(1.05) saturate(1.15)' },
  { id: 'warm', label: 'Warm', css: 'sepia(0.25) saturate(1.2) hue-rotate(-10deg)' },
  { id: 'cyberpunk', label: 'Cyberpunk', css: 'contrast(1.2) saturate(1.45) hue-rotate(20deg)' },
  { id: 'noir', label: 'Noir', css: 'grayscale(1) contrast(1.25)' },
  { id: 'blur', label: 'Soft Glow', css: 'brightness(1.06) contrast(1.02)' },
];

export const CallModal: React.FC = () => {
  const {
    callState,
    answerCall,
    endCall,
    toggleMute,
    toggleCamera,
    toggleScreenShare,
  } = useChat();

  const [seconds, setSeconds] = useState(0);
  const [isMinimized, setIsMinimized] = useState(false);
  const [videoFilter, setVideoFilter] = useState<VideoFilter>('normal');
  const [showFilterPicker, setShowFilterPicker] = useState(false);

  const localVideoRef = useRef<HTMLVideoElement | null>(null);
  const remoteVideoRef = useRef<HTMLVideoElement | null>(null);
  const remoteAudioRef = useRef<HTMLAudioElement | null>(null);

  const attachLocalVideo = useCallback((node: HTMLVideoElement | null) => {
    localVideoRef.current = node;
    if (node && callState.localStream) {
      node.srcObject = callState.localStream;
      node.play().catch(() => {});
    }
  }, [callState.localStream]);

  const attachRemoteVideo = useCallback((node: HTMLVideoElement | null) => {
    remoteVideoRef.current = node;
    if (node && callState.remoteStream) {
      node.srcObject = callState.remoteStream;
      node.play().catch(() => {});
    }
  }, [callState.remoteStream]);

  // Persistent Audio Playback (Ensures sound ALWAYS propagates across all modes)
  useEffect(() => {
    if (remoteAudioRef.current && callState.remoteStream) {
      remoteAudioRef.current.srcObject = callState.remoteStream;
      remoteAudioRef.current.play().catch((err) => {
        console.warn('[Call] Remote audio autoplay error:', err);
      });
    }
  }, [callState.remoteStream, callState.status]);

  // Bind local stream to video element
  useEffect(() => {
    if (localVideoRef.current && callState.localStream) {
      localVideoRef.current.srcObject = callState.localStream;
      localVideoRef.current.play().catch(() => {});
    }
  // The local PiP mounts only once the connected video layout is visible.
  // Include the connection/remote stream state so an already-acquired camera
  // stream is attached after that element has mounted.
  }, [callState.localStream, callState.remoteStream, callState.status, callState.isVideo, callState.isScreenSharing, callState.isCameraOff, isMinimized]);

  // Bind remote stream to video element
  useEffect(() => {
    if (remoteVideoRef.current && callState.remoteStream) {
      remoteVideoRef.current.srcObject = callState.remoteStream;
      remoteVideoRef.current.play().catch(() => {});
    }
  }, [callState.remoteStream, callState.isVideo, isMinimized]);

  // Duration Timer
  useEffect(() => {
    let timer: any;
    if (callState.status === 'connected') {
      timer = setInterval(() => {
        setSeconds((prev) => prev + 1);
      }, 1000);
    } else {
      setSeconds(0);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [callState.status]);

  if (!callState.isActive) return null;

  const formatDuration = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const hasRemoteVideo = Boolean(
    callState.remoteStream &&
    callState.remoteStream.getVideoTracks().length > 0 &&
    callState.remoteStream.getVideoTracks().some((t) => t.enabled && t.readyState === 'live')
  );
  const isScreenPresentation = Boolean(callState.isScreenSharing || callState.remoteIsScreenSharing);

  return (
    <>
      {/* 0. Hidden Always-Active Audio Element */}
      <audio
        ref={remoteAudioRef}
        autoPlay
        playsInline
        style={{ position: 'absolute', width: 0, height: 0, opacity: 0, pointerEvents: 'none' }}
      />

      {/* 1. Minimized Floating Call Tile (Picture-in-Picture on bottom right) */}
      {isMinimized && (
        <motion.div
          drag
          dragConstraints={{ left: -300, right: 0, top: -500, bottom: 0 }}
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.8, opacity: 0 }}
          style={{
            position: 'fixed',
            bottom: '24px',
            right: '24px',
            zIndex: 200,
            background: 'var(--bg-surface)',
            border: '1px solid rgba(16, 185, 129, 0.4)',
            borderRadius: '20px',
            padding: '10px 16px',
            boxShadow: '0 12px 36px rgba(36, 76, 96, 0.1)',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            cursor: 'grab',
          }}
        >
          <Avatar name={callState.remoteDisplayName || callState.remoteUser} size="sm" />

          <div>
            <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-main)' }}>
              {callState.remoteDisplayName || callState.remoteUser}
            </div>
            <div style={{ fontSize: '0.72rem', color: '#0e9f8a', fontFamily: 'monospace' }}>
              {callState.status === 'connected' ? formatDuration(seconds) : 'Calling...'}
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <button
              type="button"
              onClick={toggleMute}
              style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: callState.isMuted ? '#ef4444' : 'rgba(255, 255, 255, 0.55)',
                border: 'none',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
              }}
            >
              {callState.isMuted ? <MicOff style={{ width: '14px', height: '14px' }} /> : <Mic style={{ width: '14px', height: '14px' }} />}
            </button>

            <button
              type="button"
              onClick={() => setIsMinimized(false)}
              style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: 'rgba(255, 255, 255, 0.55)',
                border: 'none',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
              }}
              title="Expand call"
            >
              <Maximize2 style={{ width: '14px', height: '14px' }} />
            </button>

            <button
              type="button"
              onClick={() => endCall()}
              style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: '#ef4444',
                border: 'none',
                color: 'var(--text-on-primary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
              }}
              title="End"
            >
              <PhoneOff style={{ width: '14px', height: '14px' }} />
            </button>
          </div>
        </motion.div>
      )}

      {/* 2. Full-Screen Video Call Layout */}
      {!isMinimized && (callState.isVideo || callState.isScreenSharing || hasRemoteVideo) && callState.status === 'connected' && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 150,
            background: 'var(--bg-surface)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {/* Remote Full-Screen Video Feed */}
          <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
            <video
                ref={attachRemoteVideo}
              autoPlay
              playsInline
              style={{
                width: '100%',
                height: '100%',
                // Desktop displays are landscape. Fitting them avoids a portrait
                // phone cutting off the sides of the shared screen.
                objectFit: callState.remoteIsScreenSharing ? 'contain' : 'cover',
                background: callState.remoteIsScreenSharing ? '#080b12' : 'transparent',
                display: hasRemoteVideo ? 'block' : 'none',
              }}
            />

            {!hasRemoteVideo && (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
                <Avatar name={callState.remoteDisplayName || callState.remoteUser} size="xl" />
                <p style={{ color: 'var(--text-muted)', marginTop: '16px', fontSize: '0.9rem' }}>
                  Camera off / Audio only
                </p>
              </div>
            )}

            {/* Draggable Local Camera Picture-in-Picture (PIP) Tile */}
            <motion.div
              drag
              dragConstraints={{ left: -window.innerWidth + 200, right: 0, top: 0, bottom: window.innerHeight - 200 }}
              style={{
                position: 'absolute',
                top: '24px',
                right: '24px',
                width: '160px',
                height: '110px',
                borderRadius: '16px',
                overflow: 'hidden',
                background: 'var(--bg-surface)',
                border: '2px solid var(--border)',
                boxShadow: '0 8px 32px rgba(36, 76, 96, 0.1)',
                cursor: 'grab',
                zIndex: 10,
              }}
            >
              <video
                ref={attachLocalVideo}
                autoPlay
                playsInline
                muted
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: callState.isScreenSharing ? 'contain' : 'cover',
                  transform: callState.isScreenSharing ? 'none' : 'scaleX(-1)',
                  display: callState.localStream && !callState.isCameraOff ? 'block' : 'none',
                  filter: callState.isScreenSharing ? 'none' : FILTER_PRESETS.find((p) => p.id === videoFilter)?.css || 'none',
                  transition: 'filter 0.3s ease',
                }}
              />
              {(!callState.localStream || callState.isCameraOff) && (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-dark)' }}>
                  <VideoOff style={{ width: '22px', height: '22px' }} />
                </div>
              )}
            </motion.div>

            {/* Top Bar Header with Minimize and Timer */}
            <div
              style={{
                position: 'absolute',
                top: '24px',
                left: '24px',
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                background: 'rgba(23, 66, 78, 0.12)',
                backdropFilter: 'blur(12px)',
                WebkitBackdropFilter: 'blur(12px)',
                padding: '8px 16px',
                borderRadius: '9999px',
                border: '1px solid var(--border)',
                zIndex: 10,
              }}
            >
              <span style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>
                {callState.remoteDisplayName || callState.remoteUser}
              </span>
              <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#10b981' }} />
              <span style={{ fontSize: '0.82rem', fontFamily: 'monospace', color: '#0e9f8a', fontWeight: 700 }}>
                {formatDuration(seconds)}
              </span>

              <button
                type="button"
                onClick={() => setIsMinimized(true)}
                style={{ background: 'none', border: 'none', color: 'var(--text-main)', cursor: 'pointer', marginLeft: '6px' }}
                title="Minimize call"
              >
                <Minimize2 style={{ width: '15px', height: '15px' }} />
              </button>
            </div>

            {/* Bottom Floating Glass Controls */}
            <div
              style={{
                position: 'absolute',
                bottom: '32px',
                left: '50%',
                transform: 'translateX(-50%)',
                display: 'flex',
                alignItems: 'center',
                gap: '14px',
                background: 'rgba(247, 254, 253, 0.88)',
                backdropFilter: 'blur(20px)',
                WebkitBackdropFilter: 'blur(20px)',
                padding: '12px 22px',
                borderRadius: '9999px',
                border: '1px solid var(--border)',
                boxShadow: '0 20px 50px rgba(36, 76, 96, 0.1)',
                zIndex: 10,
              }}
            >
              {/* Mic Toggle */}
              <button
                type="button"
                onClick={toggleMute}
                style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '50%',
                  background: callState.isMuted ? '#ef4444' : 'rgba(255, 255, 255, 0.55)',
                  border: 'none',
                  color: 'var(--text-main)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
                title={callState.isMuted ? 'Unmute Mic' : 'Mute Mic'}
              >
                {callState.isMuted ? <MicOff style={{ width: '20px', height: '20px' }} /> : <Mic style={{ width: '20px', height: '20px' }} />}
              </button>

              {/* Camera Toggle */}
              <button
                type="button"
                onClick={toggleCamera}
                style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '50%',
                  background: callState.isCameraOff ? '#ef4444' : 'rgba(255, 255, 255, 0.55)',
                  border: 'none',
                  color: 'var(--text-main)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
                title={callState.isCameraOff ? 'Turn Camera On' : 'Turn Camera Off'}
              >
                  {callState.isCameraOff ? <VideoOff style={{ width: '20px', height: '20px' }} /> : <Video style={{ width: '20px', height: '20px' }} />}
              </button>

              {/* Filters are camera-only, never part of a screen share. */}
              {!isScreenPresentation && <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setShowFilterPicker((prev) => !prev);
                }}
                style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '50%',
                  background: showFilterPicker || videoFilter !== 'normal' ? 'linear-gradient(135deg, #ec4899 0%, #8b5cf6 100%)' : 'rgba(255, 255, 255, 0.55)',
                  border: 'none',
                  color: 'var(--text-main)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: videoFilter !== 'normal' ? '0 4px 14px rgba(236, 72, 153, 0.4)' : 'none',
                }}
                title="Camera Video Filters"
              >
                <Sparkles style={{ width: '19px', height: '19px' }} />
              </button>}

              {/* Screen Share */}
              <button
                type="button"
                onClick={toggleScreenShare}
                style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '50%',
                  background: callState.isScreenSharing ? '#10b981' : 'rgba(255, 255, 255, 0.55)',
                  border: 'none',
                  color: 'var(--text-main)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
                title={callState.isScreenSharing ? 'Stop Screen Share' : 'Share Screen'}
              >
                <Monitor style={{ width: '20px', height: '20px' }} />
              </button>

              {/* End Call */}
              <button
                type="button"
                onClick={() => endCall()}
                style={{
                  width: '52px',
                  height: '52px',
                  borderRadius: '50%',
                  background: '#ef4444',
                  border: 'none',
                  color: 'var(--text-on-primary)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: '0 8px 24px rgba(239, 68, 68, 0.5)',
                }}
                title="End Call"
              >
                <PhoneOff style={{ width: '22px', height: '22px' }} />
              </button>
            </div>

            {/* Floating Filter Selector Pills Drawer */}
            {!isScreenPresentation && showFilterPicker && (
              <div
                style={{
                  position: 'absolute',
                  bottom: '100px',
                  left: '50%',
                  transform: 'translateX(-50%)',
                  background: 'rgba(247, 254, 253, 0.92)',
                  backdropFilter: 'blur(20px)',
                  border: '1px solid var(--border)',
                  borderRadius: '9999px',
                  padding: '6px 10px',
                  display: 'flex',
                  gap: '6px',
                  zIndex: 20,
                  boxShadow: '0 10px 30px rgba(36, 76, 96, 0.1)',
                }}
              >
                {FILTER_PRESETS.map((preset) => {
                  const isActive = videoFilter === preset.id;
                  return (
                    <button
                      key={preset.id}
                      type="button"
                      onClick={() => {
                        triggerHaptic('light');
                        setVideoFilter(preset.id);
                      }}
                      style={{
                        background: isActive ? 'linear-gradient(135deg, #ec4899 0%, #8b5cf6 100%)' : 'rgba(255, 255, 255, 0.55)',
                        border: 'none',
                        color: 'var(--text-main)',
                        fontSize: '0.74rem',
                        fontWeight: 700,
                        padding: '6px 12px',
                        borderRadius: '9999px',
                        cursor: 'pointer',
                        whiteSpace: 'nowrap',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      {preset.label}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* 3. Audio Call & Ringing / Incoming Call Glass Modal Card */}
      {!isMinimized && (!callState.isVideo && !callState.isScreenSharing && !hasRemoteVideo || callState.status !== 'connected') && (
        <AnimatePresence>
          <div
            className="modal-backdrop call-modal-backdrop"
            style={{
              zIndex: 150,
              background: 'rgba(247, 254, 253, 0.75)',
              backdropFilter: 'blur(16px)',
              WebkitBackdropFilter: 'blur(16px)',
            }}
          >
            <motion.div
              className="call-modal-card"
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
              style={{
                maxWidth: '380px',
                width: '90%',
                background: 'linear-gradient(180deg, var(--bg-surface) 0%, var(--bg-surface) 100%)',
                border: '1px solid var(--border)',
                borderRadius: '28px',
                boxShadow: '0 30px 70px rgba(36, 76, 96, 0.1), 0 0 0 1px rgba(16, 185, 129, 0.15)',
                padding: '36px 28px',
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                position: 'relative',
              }}
            >
              {/* Minimize button (when connected) */}
              {callState.status === 'connected' && (
                <button
                  className="call-minimize-button"
                  type="button"
                  onClick={() => setIsMinimized(true)}
                  style={{
                    position: 'absolute',
                    top: '18px',
                    right: '18px',
                    background: 'rgba(255, 255, 255, 0.55)',
                    border: 'none',
                    color: 'var(--text-muted)',
                    borderRadius: '50%',
                    width: '32px',
                    height: '32px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                  }}
                  title="Minimize call"
                >
                  <Minimize2 style={{ width: '15px', height: '15px' }} />
                </button>
              )}

              {/* Avatar with Animated Glowing Pulse Ring */}
              <div className="call-avatar-wrap" style={{ position: 'relative', marginBottom: '22px' }}>
                <Avatar name={callState.remoteDisplayName || callState.remoteUser} size="xl" />
                <span
                  style={{
                    position: 'absolute',
                    inset: '-8px',
                    borderRadius: '50%',
                    border: '2px solid #10b981',
                    animation: 'pulse 1.8s cubic-bezier(0, 0, 0.2, 1) infinite',
                    pointerEvents: 'none',
                    opacity: 0.6,
                  }}
                />
              </div>

              <h2 className="call-contact-name" style={{ fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '4px', letterSpacing: '-0.02em' }}>
                {callState.remoteDisplayName || callState.remoteUser}
              </h2>

              <p className="call-status-text" style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: 500, marginBottom: '24px' }}>
                {callState.status === 'ringing' && (callState.isIncoming ? 'Incoming call...' : 'Ringing...')}
                {callState.status === 'calling' && 'Calling...'}
                {callState.status === 'connected' && (
                  <span style={{ color: '#0e9f8a', fontFamily: 'monospace', fontWeight: 700, fontSize: '1.05rem' }}>
                    {formatDuration(seconds)}
                  </span>
                )}
              </p>

              {/* Animated sound wave equalizer during audio call */}
              {callState.status === 'connected' && (
                <div className="call-waveform" style={{ display: 'flex', alignItems: 'center', gap: '4px', height: '24px', marginBottom: '28px' }}>
                  {[12, 22, 16, 28, 14, 8, 24, 18, 10, 20, 15].map((h, i) => (
                    <span
                      key={i}
                      style={{
                        width: '3.5px',
                        height: `${h}px`,
                        backgroundColor: '#10b981',
                        borderRadius: '9999px',
                        animation: 'pulse 0.9s infinite alternate',
                        animationDelay: `${i * 0.08}s`,
                      }}
                    />
                  ))}
                </div>
              )}

              {/* Controls */}
              {callState.isIncoming && callState.status === 'ringing' ? (
                /* Incoming Call Actions (Decline Red & Accept Green) */
                <div className="call-incoming-controls" style={{ display: 'flex', alignItems: 'center', gap: '28px' }}>
                  <button
                    className="call-control call-control--decline"
                    type="button"
                    onClick={() => {
                      triggerHaptic('medium');
                      endCall();
                    }}
                    style={{
                      width: '60px',
                      height: '60px',
                      borderRadius: '50%',
                      background: '#ef4444',
                      border: 'none',
                      color: 'var(--text-on-primary)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 10px 28px rgba(239, 68, 68, 0.45)',
                      transition: 'transform 0.15s ease',
                    }}
                    onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.92)')}
                    onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
                    title="Decline Call"
                  >
                    <PhoneOff style={{ width: '26px', height: '26px' }} />
                  </button>

                  <button
                    className="call-control call-control--accept"
                    type="button"
                    onClick={() => {
                      triggerHaptic('success');
                      answerCall();
                    }}
                    style={{
                      width: '60px',
                      height: '60px',
                      borderRadius: '50%',
                      background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                      border: 'none',
                      color: 'var(--text-on-primary)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 10px 28px rgba(16, 185, 129, 0.45)',
                      transition: 'transform 0.15s ease',
                    }}
                    onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.92)')}
                    onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
                    title="Accept Call"
                  >
                    <Phone style={{ width: '26px', height: '26px' }} />
                  </button>
                </div>
              ) : (
                /* Connected / Calling Action Controls */
                <div className="call-connected-controls" style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <button
                    className={`call-control call-control--utility ${callState.isMuted ? 'is-alert' : ''}`}
                    type="button"
                    onClick={toggleMute}
                    style={{
                      width: '46px',
                      height: '46px',
                      borderRadius: '50%',
                      background: callState.isMuted ? '#ef4444' : 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      color: 'var(--text-main)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
                    title={callState.isMuted ? 'Unmute Mic' : 'Mute Mic'}
                  >
                    {callState.isMuted ? <MicOff style={{ width: '20px', height: '20px' }} /> : <Mic style={{ width: '20px', height: '20px' }} />}
                  </button>

                  <button
                    className="call-control call-control--end"
                    type="button"
                    onClick={() => {
                      triggerHaptic('medium');
                      endCall();
                    }}
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      background: '#ef4444',
                      border: 'none',
                      color: 'var(--text-on-primary)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 10px 28px rgba(239, 68, 68, 0.45)',
                    }}
                    title="End Call"
                  >
                    <PhoneOff style={{ width: '24px', height: '24px' }} />
                  </button>

                  <button
                    className={`call-control call-control--utility ${callState.isCameraOff ? 'is-alert' : ''}`}
                    type="button"
                    onClick={toggleCamera}
                    style={{
                      width: '46px',
                      height: '46px',
                      borderRadius: '50%',
                      background: callState.isCameraOff ? '#ef4444' : 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      color: 'var(--text-main)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
                    title={callState.isCameraOff ? 'Turn on Camera' : 'Turn off Camera'}
                  >
                    {callState.isCameraOff ? <VideoOff style={{ width: '20px', height: '20px' }} /> : <Video style={{ width: '20px', height: '20px' }} />}
                  </button>

                  <button
                    className={`call-control call-control--utility ${callState.isScreenSharing ? 'is-active' : ''}`}
                    type="button"
                    onClick={toggleScreenShare}
                    style={{
                      width: '46px',
                      height: '46px',
                      borderRadius: '50%',
                      background: callState.isScreenSharing ? '#10b981' : 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      color: 'var(--text-main)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                    }}
                    title={callState.isScreenSharing ? 'Stop Screen Share' : 'Share Screen'}
                  >
                    <Monitor style={{ width: '20px', height: '20px' }} />
                  </button>
                </div>
              )}
            </motion.div>
          </div>
        </AnimatePresence>
      )}
    </>
  );
};
