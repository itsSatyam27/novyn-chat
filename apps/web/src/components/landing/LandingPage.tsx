import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  MessageSquare,
  ShieldCheck,
  Zap,
  Mic,
  Video,
  Smartphone,
  ArrowRight,
  Sparkles,
  Radio,
  Globe,
  Laptop,
  CheckCircle2,
  X,
  BellRing,
  Download,
  Lock,
  Gamepad2,
  KeyRound,
  PhoneCall,
  RefreshCw,
  Play,
  Pause,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { NovynLogo } from '../ui/NovynLogo';

const APK_DOWNLOAD_URL = '/downloads/novyn.apk';
const APK_FILENAME = 'novyn.apk';

function triggerApkDownload() {
  triggerHaptic('medium');
  const a = document.createElement('a');
  a.href = APK_DOWNLOAD_URL;
  a.download = APK_FILENAME;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

interface LandingPageProps {
  onOpenAuth: (mode?: 'signin' | 'signup') => void;
}

export const LandingPage: React.FC<LandingPageProps> = ({ onOpenAuth }) => {
  const [comingSoonPlatform, setComingSoonPlatform] = useState<{ name: string; type: string; icon: any } | null>(null);
  const [notifyEmail, setNotifyEmail] = useState('');
  const [notifySuccess, setNotifySuccess] = useState(false);

  // Cinematic opening splash state
  const [showIntro, setShowIntro] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setShowIntro(false);
    }, 1900);
    return () => clearTimeout(timer);
  }, []);

  // Hero interactive tabs: 'chat' | 'voice' | 'games'
  const [activeHeroTab, setActiveHeroTab] = useState<'chat' | 'voice' | 'games'>('chat');

  // Interactive Live Cipher Simulator State
  const [plainInput, setPlainInput] = useState('Secret meeting at 5:00 PM in Room 402');
  const [fakeCipher, setFakeCipher] = useState('8zK9pX2L4mWv/7Qj95aBc71uE9d');
  const [fakeIv, setFakeIv] = useState('3dF92aK10pX8');

  // Interactive Mini-Game (Tic-Tac-Toe) on Landing Page
  const [board, setBoard] = useState<(string | null)[]>(Array(9).fill(null));
  const [isXNext, setIsXNext] = useState(true);
  const [gameStatus, setGameStatus] = useState<'playing' | 'won' | 'draw'>('playing');

  // Voice note demo playing state
  const [isPlayingVoice, setIsPlayingVoice] = useState(false);

  // Re-scramble fake ciphertext when plain input changes
  useEffect(() => {
    if (!plainInput.trim()) {
      setFakeCipher('...');
      return;
    }
    let hash = 0;
    for (let i = 0; i < plainInput.length; i++) {
      hash = (hash << 5) - hash + plainInput.charCodeAt(i);
      hash |= 0;
    }
    const b64 = btoa(encodeURIComponent(plainInput)).substring(0, 24) + '==';
    setFakeCipher(b64);
    setFakeIv(Math.abs(hash).toString(16).padStart(12, 'a').substring(0, 12));
  }, [plainInput]);

  // Tic-Tac-Toe logic
  const handleCellClick = (index: number) => {
    if (board[index] || gameStatus !== 'playing') return;
    triggerHaptic('light');

    const newBoard = [...board];
    newBoard[index] = 'X';
    setBoard(newBoard);

    if (checkWinner(newBoard, 'X')) {
      setGameStatus('won');
      triggerHaptic('success');
      return;
    }

    if (newBoard.every((cell) => cell !== null)) {
      setGameStatus('draw');
      return;
    }

    setIsXNext(false);
    setTimeout(() => {
      const emptyIndices = newBoard.map((val, idx) => (val === null ? idx : null)).filter((val) => val !== null) as number[];
      if (emptyIndices.length > 0) {
        const randomMove = emptyIndices[Math.floor(Math.random() * emptyIndices.length)];
        newBoard[randomMove] = 'O';
        setBoard([...newBoard]);
        if (checkWinner(newBoard, 'O')) {
          setGameStatus('won');
        } else if (newBoard.every((c) => c !== null)) {
          setGameStatus('draw');
        }
      }
      setIsXNext(true);
    }, 350);
  };

  const checkWinner = (squares: (string | null)[], player: string) => {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    return lines.some(([a, b, c]) => squares[a] === player && squares[b] === player && squares[c] === player);
  };

  const resetGame = () => {
    triggerHaptic('light');
    setBoard(Array(9).fill(null));
    setIsXNext(true);
    setGameStatus('playing');
  };

  const handleOpenComingSoon = (platform: { name: string; type: string; icon: any }) => {
    triggerHaptic('medium');
    setComingSoonPlatform(platform);
    setNotifySuccess(false);
    setNotifyEmail('');
  };

  const handleNotifySubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!notifyEmail.trim()) return;
    triggerHaptic('success');
    setNotifySuccess(true);
    setTimeout(() => {
      setComingSoonPlatform(null);
      setNotifySuccess(false);
    }, 2500);
  };

  return (
    <div
      className="landing-page-root ambient-grid"
      style={{
        height: '100vh',
        width: '100%',
        overflowY: 'auto',
        overflowX: 'hidden',
        background: 'var(--bg-surface)',
        position: 'relative',
        scrollBehavior: 'smooth',
      }}
    >
      {/* ── Cinematic Opening Splash & Logo Reveal ─────────────────────────── */}
      <AnimatePresence>
        {showIntro && (
          <motion.div
            key="cinematic-splash-overlay"
            className="landing-intro"
            initial={{ opacity: 1 }}
            exit={{
              opacity: 0,
              y: -45,
              filter: 'blur(12px)',
              transition: { duration: 0.7, ease: [0.16, 1, 0.3, 1] },
            }}
            onClick={() => {
              triggerHaptic('light');
              setShowIntro(false);
            }}
            style={{
              position: 'fixed',
              inset: 0,
              zIndex: 99999,
              background: 'var(--bg-surface)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              overflow: 'hidden',
            }}
          >
            {/* Ambient radiant background flare */}
            <motion.div
              className="landing-intro-glow"
              initial={{ scale: 0.3, opacity: 0 }}
              animate={{
                scale: [0.3, 1.4, 1.1],
                opacity: [0, 0.75, 0.45],
              }}
              transition={{ duration: 1.6, ease: 'easeOut' }}
              style={{
                position: 'absolute',
                width: '500px',
                height: '500px',
                borderRadius: '50%',
                background: 'radial-gradient(circle, rgba(16, 185, 129, 0.35) 0%, rgba(6, 182, 212, 0.15) 50%, transparent 70%)',
                filter: 'blur(70px)',
                pointerEvents: 'none',
              }}
            />

            {/* Glowing wings logo badge */}
            <motion.div
              initial={{ scale: 0.35, opacity: 0, y: 25 }}
              animate={{
                scale: [0.35, 1.15, 1],
                opacity: [0, 1, 1],
                y: [25, -6, 0],
              }}
              transition={{ duration: 0.85, ease: [0.16, 1, 0.3, 1] }}
              style={{ position: 'relative', zIndex: 2 }}
            >
              <div
                className="landing-intro-mark"
                style={{
                  width: '92px',
                  height: '92px',
                  borderRadius: '28px',
                  background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 0 55px rgba(16, 185, 129, 0.65), 0 14px 35px rgba(36, 76, 96, 0.1)',
                  border: '1.5px solid var(--border)',
                }}
              >
                <motion.div
                  animate={{
                    scale: [1, 1.08, 1],
                  }}
                  transition={{
                    repeat: Infinity,
                    duration: 1.8,
                    ease: 'easeInOut',
                  }}
                >
                  <NovynLogo size={56} variant="white" />
                </motion.div>
              </div>
            </motion.div>

            {/* Brand Title */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.35, duration: 0.6 }}
              style={{ textAlign: 'center', marginTop: '24px', zIndex: 2 }}
            >
              <h1
                className="landing-intro-name"
                style={{
                  fontSize: '2rem',
                  fontWeight: 900,
                  letterSpacing: '0.22em',
                  color: 'var(--text-main)',
                  margin: '0 0 6px',
                  textTransform: 'uppercase',
                }}
              >
                Novyn
              </h1>
              <motion.span
                className="landing-intro-tagline"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.55, duration: 0.5 }}
                style={{
                  fontSize: '0.74rem',
                  fontWeight: 800,
                  color: '#0e9f8a',
                  letterSpacing: '0.14em',
                  textTransform: 'uppercase',
                  display: 'inline-block',
                }}
              >
                Universal Encrypted Messenger
              </motion.span>
            </motion.div>

            {/* Tap to skip */}
            <motion.span
              className="landing-intro-skip"
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.4 }}
              transition={{ delay: 0.9, duration: 0.4 }}
              style={{
                position: 'absolute',
                bottom: '36px',
                fontSize: '0.74rem',
                color: 'var(--text-muted)',
                letterSpacing: '0.05em',
              }}
            >
              Tap anywhere to enter
            </motion.span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Dynamic Ambient Mesh Glows */}
      <div
        style={{
          position: 'fixed',
          top: '-15%',
          left: '15%',
          width: '550px',
          height: '550px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(16, 185, 129, 0.18) 0%, rgba(16, 185, 129, 0) 70%)',
          filter: 'blur(70px)',
          pointerEvents: 'none',
          zIndex: 0,
          animation: 'glowFloat 12s ease-in-out infinite',
        }}
      />
      <div
        style={{
          position: 'fixed',
          top: '30%',
          right: '-10%',
          width: '600px',
          height: '600px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(6, 182, 212, 0.14) 0%, rgba(139, 92, 246, 0.1) 50%, transparent 70%)',
          filter: 'blur(90px)',
          pointerEvents: 'none',
          zIndex: 0,
          animation: 'glowFloatReverse 16s ease-in-out infinite',
        }}
      />

      {/* Sticky Top Navbar */}
      <nav className="landing-navbar">
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }} onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
            <div
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 18px rgba(16, 185, 129, 0.35)',
                flexShrink: 0,
              }}
            >
              <NovynLogo size={24} variant="white" />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em', lineHeight: 1.1 }}>
                Novyn
              </span>
              <span style={{ fontSize: '0.68rem', color: '#0e9f8a', fontWeight: 700, letterSpacing: '0.04em' }}>
                v2.0 ENCRYPTED
              </span>
            </div>
          </div>

          {/* Platform Pills */}
          <div className="landing-platform-menu">
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '6px 14px',
                borderRadius: '12px',
                background: 'rgba(16, 185, 129, 0.08)',
                border: '1px solid rgba(16, 185, 129, 0.25)',
                fontSize: '0.84rem',
                fontWeight: 700,
                color: 'var(--text-main)',
                cursor: 'pointer',
              }}
              onClick={() => {
                triggerHaptic('light');
                onOpenAuth('signin');
              }}
            >
              <Globe style={{ width: '15px', height: '15px', color: '#0e9f8a' }} />
              <span>Web</span>
              <span
                style={{
                  fontSize: '0.62rem',
                  color: '#0e9f8a',
                  background: 'rgba(16, 185, 129, 0.15)',
                  padding: '2px 6px',
                  borderRadius: '6px',
                  fontWeight: 800,
                }}
              >
                LIVE
              </span>
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '6px 14px',
                borderRadius: '12px',
                background: 'rgba(56, 189, 248, 0.08)',
                border: '1px solid rgba(56, 189, 248, 0.25)',
                fontSize: '0.84rem',
                fontWeight: 600,
                color: '#087fac',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
              }}
              onClick={triggerApkDownload}
            >
              <Smartphone style={{ width: '15px', height: '15px', color: '#087fac' }} />
              <span>Android</span>
              <span
                style={{
                  fontSize: '0.62rem',
                  color: '#087fac',
                  background: 'rgba(56, 189, 248, 0.14)',
                  padding: '2px 6px',
                  borderRadius: '6px',
                  fontWeight: 700,
                }}
              >
                APK
              </span>
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '6px 14px',
                borderRadius: '12px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                fontSize: '0.84rem',
                fontWeight: 600,
                color: 'var(--text-muted)',
                cursor: 'pointer',
              }}
              onClick={() =>
                handleOpenComingSoon({
                  name: 'Novyn Desktop App',
                  type: 'Windows & macOS',
                  icon: Laptop,
                })
              }
            >
              <Laptop style={{ width: '15px', height: '15px', color: '#8651b3' }} />
              <span>Desktop</span>
              <span
                style={{
                  fontSize: '0.62rem',
                  color: '#8651b3',
                  background: 'rgba(168, 85, 247, 0.12)',
                  padding: '2px 6px',
                  borderRadius: '6px',
                  fontWeight: 700,
                }}
              >
                BETA
              </span>
            </div>
          </div>
        </div>

        {/* Right Action CTAs */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              onOpenAuth('signin');
            }}
            className="btn btn-secondary"
            style={{ padding: '8px 18px', fontSize: '0.86rem', borderRadius: '12px' }}
          >
            Sign In
          </button>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('medium');
              onOpenAuth('signup');
            }}
            className="btn btn-primary"
            style={{ padding: '8px 20px', fontSize: '0.86rem', borderRadius: '12px' }}
          >
            Get Started <ArrowRight style={{ width: '14px', height: '14px' }} />
          </button>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="landing-hero" style={{ position: 'relative', zIndex: 1, paddingTop: '52px' }}>
        <motion.div
          initial={{ opacity: 0, y: -12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="hero-badge"
          style={{
            background: 'linear-gradient(90deg, rgba(16, 185, 129, 0.15) 0%, rgba(6, 182, 212, 0.15) 100%)',
            border: '1px solid rgba(16, 185, 129, 0.35)',
            boxShadow: '0 0 20px rgba(16, 185, 129, 0.2)',
          }}
        >
          <Sparkles style={{ width: '15px', height: '15px', color: '#078779' }} />
          <span style={{ fontWeight: 700, letterSpacing: '0.02em' }}>
            Zero-Knowledge E2EE • WebRTC Calls • In-Chat Games
          </span>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, delay: 0.08 }}
          className="hero-title"
          style={{ maxWidth: '850px' }}
        >
          Next-Level Communication. <br />
          <span
            style={{
              background: 'linear-gradient(135deg, #10b981 0%, #38bdf8 50%, #a855f7 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              display: 'inline-block',
            }}
          >
            Zero Compromise on Privacy.
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, delay: 0.16 }}
          className="hero-subtitle"
          style={{ maxWidth: '640px', fontSize: '1.05rem', color: 'var(--text-muted)' }}
        >
          WhatsApp-grade ECDH P-256 client encryption, crystal-clear WebRTC audio & video, live voice waveforms, and turn-based games — synchronized instantaneously across Web & Android.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, delay: 0.24 }}
          className="hero-cta-group"
        >
          <button
            type="button"
            onClick={() => {
              triggerHaptic('medium');
              onOpenAuth('signup');
            }}
            className="btn btn-primary"
            style={{
              borderRadius: '16px',
              padding: '14px 28px',
              fontSize: '0.96rem',
              fontWeight: 800,
              boxShadow: '0 8px 30px rgba(16, 185, 129, 0.4)',
            }}
          >
            Start Chatting Free <ArrowRight style={{ width: '18px', height: '18px' }} />
          </button>

          <button
            type="button"
            onClick={triggerApkDownload}
            className="btn btn-secondary"
            style={{
              borderRadius: '16px',
              padding: '14px 24px',
              fontSize: '0.96rem',
              fontWeight: 700,
              border: '1px solid rgba(56, 189, 248, 0.35)',
              color: '#087fac',
              background: 'rgba(56, 189, 248, 0.08)',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <Download style={{ width: '18px', height: '18px' }} />
            Download APK (Android)
          </button>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.32 }}
          className="hero-pills"
        >
          <div className="hero-pill-item">
            <ShieldCheck style={{ width: '16px', height: '16px', color: '#0e9f8a' }} />
            <span>256-Bit AES-GCM Encryption</span>
          </div>
          <div className="hero-pill-item">
            <Radio style={{ width: '16px', height: '16px', color: '#087fac' }} />
            <span>&lt;30ms WebSocket Latency</span>
          </div>
          <div className="hero-pill-item">
            <KeyRound style={{ width: '16px', height: '16px', color: '#a855f7' }} />
            <span>Keys Never Leave Device</span>
          </div>
        </motion.div>

        {/* Hero Mockup Sandbox */}
        <motion.div
          initial={{ opacity: 0, y: 35 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.35 }}
          className="mockup-container"
          style={{
            maxWidth: '880px',
            background: 'rgba(12, 17, 29, 0.85)',
            border: '1px solid var(--border)',
            borderRadius: '26px',
            boxShadow: '0 25px 65px rgba(36, 76, 96, 0.1), 0 0 50px rgba(16, 185, 129, 0.08)',
            position: 'relative',
          }}
        >
          <div className="mockup-header">
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div className="mockup-dots">
                <span className="mockup-dot" style={{ background: '#ef4444' }} />
                <span className="mockup-dot" style={{ background: '#f59e0b' }} />
                <span className="mockup-dot" style={{ background: '#10b981' }} />
              </div>
              <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                novyn.chat / live-preview
              </span>
            </div>

            {/* Mode Switcher */}
            <div
              style={{
                display: 'flex',
                background: 'rgba(23, 66, 78, 0.1125)',
                padding: '3px',
                borderRadius: '12px',
                border: '1px solid var(--border)',
                gap: '4px',
              }}
            >
              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setActiveHeroTab('chat');
                }}
                style={{
                  background: activeHeroTab === 'chat' ? '#10b981' : 'transparent',
                  color: activeHeroTab === 'chat' ? 'var(--text-main)' : 'var(--text-muted)',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '5px 12px',
                  fontSize: '0.76rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '5px',
                  transition: 'all 0.18s ease',
                }}
              >
                <MessageSquare style={{ width: '13px', height: '13px' }} />
                <span>Chat</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setActiveHeroTab('voice');
                }}
                style={{
                  background: activeHeroTab === 'voice' ? '#06b6d4' : 'transparent',
                  color: activeHeroTab === 'voice' ? 'var(--text-main)' : 'var(--text-muted)',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '5px 12px',
                  fontSize: '0.76rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '5px',
                  transition: 'all 0.18s ease',
                }}
              >
                <PhoneCall style={{ width: '13px', height: '13px' }} />
                <span>Calls</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  setActiveHeroTab('games');
                }}
                style={{
                  background: activeHeroTab === 'games' ? '#8b5cf6' : 'transparent',
                  color: activeHeroTab === 'games' ? 'var(--text-main)' : 'var(--text-muted)',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '5px 12px',
                  fontSize: '0.76rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '5px',
                  transition: 'all 0.18s ease',
                }}
              >
                <Gamepad2 style={{ width: '13px', height: '13px' }} />
                <span>Mini-Game</span>
              </button>
            </div>
          </div>

          {/* Mode 1: Live Chat Demo */}
          {activeHeroTab === 'chat' && (
            <div className="mockup-messages" style={{ minHeight: '260px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  padding: '6px 14px',
                  borderRadius: '10px',
                  background: 'rgba(16, 185, 129, 0.08)',
                  border: '1px solid rgba(16, 185, 129, 0.2)',
                  color: '#078779',
                  fontSize: '0.72rem',
                  fontWeight: 600,
                  margin: '0 auto 8px',
                  width: 'fit-content',
                }}
              >
                <Lock style={{ width: '12px', height: '12px' }} />
                <span>Messages & calls are End-to-End Encrypted. No one outside can read them.</span>
              </div>

              <div className="mockup-msg mockup-msg-in" style={{ position: 'relative' }}>
                <span style={{ color: '#078779', fontWeight: 700, fontSize: '0.76rem', display: 'block', marginBottom: '4px' }}>
                  Alex • Online
                </span>
                Hey! Did you see Novyn's new E2EE 60-digit safety code verification? Also testing the live audio waveforms! 🎙️
                <span style={{ display: 'block', fontSize: '0.66rem', color: 'var(--text-muted)', textAlign: 'right', marginTop: '6px' }}>
                  10:42 AM
                </span>
                <span
                  style={{
                    position: 'absolute',
                    bottom: '-8px',
                    left: '14px',
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border)',
                    borderRadius: '9999px',
                    padding: '1px 6px',
                    fontSize: '0.68rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '3px',
                  }}
                >
                  ❤️ <span>2</span>
                </span>
              </div>

              <div
                className="mockup-msg mockup-msg-out"
                style={{
                  maxWidth: '360px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '6px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <button
                    type="button"
                    onClick={() => setIsPlayingVoice(!isPlayingVoice)}
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: '#ffffff',
                      border: 'none',
                      color: '#059669',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      flexShrink: 0,
                    }}
                  >
                    {isPlayingVoice ? <Pause style={{ width: '16px', height: '16px' }} /> : <Play style={{ width: '16px', height: '16px', marginLeft: '2px' }} />}
                  </button>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '3px', flex: 1, height: '30px' }}>
                    {[8, 14, 22, 10, 18, 26, 12, 16, 24, 18, 12, 20, 14, 8].map((h, i) => (
                      <div
                        key={i}
                        style={{
                          flex: 1,
                          height: isPlayingVoice ? undefined : `${h}px`,
                          animation: isPlayingVoice ? `liveWaveform ${0.4 + (i % 4) * 0.15}s ease infinite alternate` : 'none',
                          background: 'rgba(255, 255, 255, 0.9)',
                          borderRadius: '4px',
                        }}
                      />
                    ))}
                  </div>
                  <span style={{ fontSize: '0.72rem', fontWeight: 700, color: 'rgba(20, 52, 63, 0.9)' }}>
                    0:18
                  </span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.64rem', color: 'rgba(20, 52, 63, 0.75)' }}>
                  <span>Voice message • 1.5x</span>
                  <span>10:43 AM ✓✓</span>
                </div>
              </div>
            </div>
          )}

          {/* Mode 2: WebRTC Calling Demo */}
          {activeHeroTab === 'voice' && (
            <div
              style={{
                minHeight: '260px',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '20px',
                textAlign: 'center',
              }}
            >
              <div
                style={{
                  width: '100%',
                  maxWidth: '440px',
                  background: 'rgba(6, 182, 212, 0.05)',
                  border: '1px solid rgba(6, 182, 212, 0.3)',
                  borderRadius: '20px',
                  padding: '24px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '14px',
                }}
              >
                <div style={{ position: 'relative' }}>
                  <div
                    style={{
                      width: '68px',
                      height: '68px',
                      borderRadius: '50%',
                      background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '1.5rem',
                      fontWeight: 800,
                      color: 'var(--text-main)',
                      boxShadow: '0 0 25px rgba(6, 182, 212, 0.4)',
                    }}
                  >
                    A
                  </div>
                  <span
                    style={{
                      position: 'absolute',
                      bottom: '2px',
                      right: '2px',
                      width: '16px',
                      height: '16px',
                      borderRadius: '50%',
                      background: '#10b981',
                      border: '3px solid #e4f0f0',
                    }}
                  />
                </div>

                <div>
                  <h4 style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                    Alex Rivers
                  </h4>
                  <span style={{ fontSize: '0.78rem', color: '#06b6d4', fontWeight: 600 }}>
                    ● 03:42 • WebRTC Direct P2P (TURN Relay)
                  </span>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '4px', height: '24px' }}>
                  {[10, 20, 14, 24, 18, 12, 22, 16, 8, 18, 24, 12].map((h, i) => (
                    <div
                      key={i}
                      style={{
                        width: '4px',
                        height: `${h}px`,
                        animation: `liveWaveform ${0.5 + (i % 3) * 0.2}s ease infinite alternate`,
                        background: '#06b6d4',
                        borderRadius: '2px',
                      }}
                    />
                  ))}
                </div>

                <div style={{ display: 'flex', gap: '14px', marginTop: '6px' }}>
                  <div style={{ width: '42px', height: '42px', borderRadius: '50%', background: 'rgba(255, 255, 255, 0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-main)' }}>
                    <Mic style={{ width: '18px', height: '18px' }} />
                  </div>
                  <div style={{ width: '42px', height: '42px', borderRadius: '50%', background: 'rgba(255, 255, 255, 0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-main)' }}>
                    <Video style={{ width: '18px', height: '18px' }} />
                  </div>
                  <div style={{ width: '42px', height: '42px', borderRadius: '50%', background: '#ef4444', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-on-primary)' }}>
                    <PhoneCall style={{ width: '18px', height: '18px', transform: 'rotate(135deg)' }} />
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Mode 3: Playable Mini-Game Demo */}
          {activeHeroTab === 'games' && (
            <div
              style={{
                minHeight: '260px',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '16px',
              }}
            >
              <div
                style={{
                  background: 'rgba(139, 92, 246, 0.08)',
                  border: '1px solid rgba(139, 92, 246, 0.3)',
                  borderRadius: '20px',
                  padding: '20px 24px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '12px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%', gap: '16px' }}>
                  <span style={{ fontSize: '0.82rem', fontWeight: 800, color: '#8651b3' }}>
                    🎮 Tic-Tac-Toe In-Chat Duel
                  </span>
                  <button
                    type="button"
                    onClick={resetGame}
                    style={{
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      color: 'var(--text-muted)',
                      borderRadius: '8px',
                      padding: '4px 8px',
                      fontSize: '0.72rem',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      cursor: 'pointer',
                    }}
                  >
                    <RefreshCw style={{ width: '12px', height: '12px' }} />
                    Reset
                  </button>
                </div>

                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(3, 56px)',
                    gridTemplateRows: 'repeat(3, 56px)',
                    gap: '8px',
                  }}
                >
                  {board.map((cell, idx) => (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => handleCellClick(idx)}
                      disabled={cell !== null || gameStatus !== 'playing' || !isXNext}
                      style={{
                        background: cell ? 'rgba(139, 92, 246, 0.18)' : 'rgba(255, 255, 255, 0.55)',
                        border: '1px solid rgba(139, 92, 246, 0.3)',
                        borderRadius: '12px',
                        fontSize: '1.4rem',
                        fontWeight: 800,
                        color: cell === 'X' ? '#0e9f8a' : '#087fac',
                        cursor: cell || gameStatus !== 'playing' ? 'default' : 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      {cell}
                    </button>
                  ))}
                </div>

                <div style={{ fontSize: '0.76rem', fontWeight: 700, color: 'var(--text-main)' }}>
                  {gameStatus === 'won' ? (
                    <span style={{ color: '#0e9f8a' }}>🎉 Winner Detected! Press Reset to replay.</span>
                  ) : gameStatus === 'draw' ? (
                    <span style={{ color: '#a86d0b' }}>🤝 Draw game! Well played.</span>
                  ) : isXNext ? (
                    <span>Your Turn (X) — Tap any empty square</span>
                  ) : (
                    <span style={{ color: '#087fac' }}>Bot Thinking (O)...</span>
                  )}
                </div>
              </div>
            </div>
          )}
        </motion.div>
      </section>

      {/* Real-Time Zero-Knowledge Cipher Playground */}
      <section className="landing-crypto-section" style={{ padding: '60px 24px', maxWidth: '1060px', margin: '0 auto', position: 'relative', zIndex: 1 }}>
        <div style={{ textAlign: 'center', marginBottom: '36px' }}>
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              padding: '4px 14px',
              borderRadius: '9999px',
              background: 'rgba(16, 185, 129, 0.1)',
              border: '1px solid rgba(16, 185, 129, 0.3)',
              fontSize: '0.78rem',
              fontWeight: 700,
              color: '#0e9f8a',
              marginBottom: '10px',
            }}
          >
            <Lock style={{ width: '13px', height: '13px' }} />
            LIVE CRYPTO ENGINE
          </div>
          <h2 style={{ fontSize: '2.2rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em', margin: 0 }}>
            See E2EE Zero-Knowledge in Action
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.94rem', maxWidth: '580px', margin: '8px auto 0' }}>
            Type any phrase below to watch the client-side AES-GCM-256 cipher scramble it before it ever hits the server.
          </p>
        </div>

        <div
          className="landing-crypto-panel"
          style={{
            background: 'rgba(247, 254, 253, 0.85)',
            border: '1px solid var(--border)',
            borderRadius: '24px',
            padding: '28px',
            boxShadow: '0 20px 50px rgba(36, 76, 96, 0.1)',
          }}
        >
          <div style={{ marginBottom: '22px' }}>
            <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '8px' }}>
              Your Plaintext Message (Typed on Device)
            </label>
            <input
              type="text"
              value={plainInput}
              onChange={(e) => setPlainInput(e.target.value)}
              className="input-field"
              style={{
                height: '48px',
                fontSize: '0.95rem',
                borderRadius: '14px',
                paddingLeft: '16px',
                background: 'rgba(23, 66, 78, 0.1)',
                border: '1px solid var(--border)',
              }}
              placeholder="Type anything here..."
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '16px' }}>
            {/* Cloud/Database view */}
            <div
              className="landing-crypto-card landing-crypto-card--server"
              style={{
                background: 'rgba(239, 68, 68, 0.05)',
                border: '1px solid rgba(239, 68, 68, 0.25)',
                borderRadius: '16px',
                padding: '20px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <span style={{ fontSize: '0.82rem', fontWeight: 800, color: '#bd3750' }}>
                  ☁️ WHAT SERVER & MONGODB SEES
                </span>
                <span style={{ fontSize: '0.68rem', background: 'rgba(239, 68, 68, 0.15)', color: '#bd3750', padding: '2px 8px', borderRadius: '6px', fontWeight: 700 }}>
                  ZERO-KNOWLEDGE
                </span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', margin: '0 0 10px' }}>
                Only randomized Base64 ciphertext & initialization vectors exist on the database.
              </p>
              <div style={{ background: 'var(--bg-surface)', padding: '12px', borderRadius: '10px', fontFamily: 'monospace', fontSize: '0.82rem', color: '#ac3049', wordBreak: 'break-all' }}>
                <div><span style={{ color: 'var(--text-muted)' }}>ciphertext:</span> "{fakeCipher}"</div>
                <div><span style={{ color: 'var(--text-muted)' }}>iv:</span> "{fakeIv}"</div>
                <div><span style={{ color: 'var(--text-muted)' }}>isEncrypted:</span> true</div>
              </div>
            </div>

            {/* Recipient Device View */}
            <div
              className="landing-crypto-card landing-crypto-card--recipient"
              style={{
                background: 'rgba(16, 185, 129, 0.05)',
                border: '1px solid rgba(16, 185, 129, 0.25)',
                borderRadius: '16px',
                padding: '20px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <span style={{ fontSize: '0.82rem', fontWeight: 800, color: '#078779' }}>
                  📱 WHAT RECIPIENT DECRYPTS
                </span>
                <span style={{ fontSize: '0.68rem', background: 'rgba(16, 185, 129, 0.15)', color: '#078779', padding: '2px 8px', borderRadius: '6px', fontWeight: 700 }}>
                  ECDH P-256 MATCH
                </span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', margin: '0 0 10px' }}>
                Decrypted on-device using the recipient's private key stored locally in IndexedDB.
              </p>
              <div style={{ background: 'var(--bg-surface)', padding: '12px', borderRadius: '10px', fontFamily: 'monospace', fontSize: '0.86rem', color: '#078779', wordBreak: 'break-word', minHeight: '68px', display: 'flex', alignItems: 'center' }}>
                "{plainInput || 'Empty message'}"
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* High-Impact Bento Grid Showcase */}
      <section className="landing-features-section" style={{ padding: '40px 24px 70px', maxWidth: '1100px', margin: '0 auto', position: 'relative', zIndex: 1 }}>
        <div style={{ textAlign: 'center', marginBottom: '46px' }}>
          <h2 style={{ fontSize: '2.4rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em', margin: '0 0 10px' }}>
            Engineered for Privacy, Polish & Velocity
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem', maxWidth: '600px', margin: '0 auto' }}>
            Built on Web Crypto standards, WebSockets, and Capacitor native hardware bridges.
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '22px' }}>
          {/* Bento Card 1: E2EE */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(16, 185, 129, 0.12)', color: '#0e9f8a', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <ShieldCheck style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              Zero-Knowledge Architecture
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Signal and WhatsApp-modeled cryptography. Private identity keys reside solely in your local browser's IndexedDB. 60-digit safety numbers & QR codes prevent man-in-the-middle attacks.
            </p>
          </div>

          {/* Bento Card 2: Voice Notes */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(6, 182, 212, 0.12)', color: '#06b6d4', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Mic style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              Live Waveform Voice Engine
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Record voice notes with live Canvas sound-frequency visualization. Playback at variable speeds (1x, 1.5x, 2x) with smooth scrubbing and synthesized haptic taps.
            </p>
          </div>

          {/* Bento Card 3: WebRTC Calls */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(99, 102, 241, 0.12)', color: '#818cf8', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Video style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              P2P WebRTC HD Audio & Video
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Direct browser-to-browser streaming with DTLS-SRTP media encryption. Integrated TURN relay fallback for reliable calling across carrier firewalls and mobile networks.
            </p>
          </div>

          {/* Bento Card 4: In-Chat Games */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(168, 85, 247, 0.12)', color: '#8651b3', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Gamepad2 style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              In-Chat Turn-Based Mini Games
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Challenge friends right inside message bubbles. Real-time move synchronization for Tic-Tac-Toe, Rock-Paper-Scissors, and Connect 4 without leaving the conversation.
            </p>
          </div>

          {/* Bento Card 5: Mobile & Capacitor */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(244, 63, 94, 0.12)', color: '#fb7185', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Smartphone style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              Mobile-First Hardware Haptics
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Unified Capacitor Android shell. Enjoy physical vibration feedback on sends, reactions, and swipes, native photo camera capture, and status bar synchronization.
            </p>
          </div>

          {/* Bento Card 6: Pro Messaging */}
          <div className="bento-card">
            <div style={{ width: '50px', height: '50px', borderRadius: '14px', background: 'rgba(245, 158, 11, 0.12)', color: '#a0690b', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Zap style={{ width: '26px', height: '26px' }} />
            </div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
              Pro Messaging Utilities
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>
              Per-chat draft auto-saving, message pinning, interactive polls, real-time typing indicators, read receipts, and per-conversation custom OLED wallpapers.
            </p>
          </div>
        </div>
      </section>

      {/* Platform Download & Access Cards */}
      <section className="landing-platforms-section" style={{ padding: '20px 24px 80px', maxWidth: '1100px', margin: '0 auto', position: 'relative', zIndex: 1 }}>
        <div style={{ textAlign: 'center', marginBottom: '36px' }}>
          <h2 style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em', margin: 0 }}>
            Connect Across Every Screen
          </h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(310px, 1fr))', gap: '20px' }}>
          {/* 1. Web Client */}
          <div
            className="landing-platform-card landing-platform-card--web"
            style={{
              padding: '28px',
              borderRadius: '24px',
              background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.08) 0%, rgba(255, 255, 255, 0.55) 100%)',
              border: '1.5px solid rgba(16, 185, 129, 0.4)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              boxShadow: '0 8px 30px rgba(16, 185, 129, 0.15)',
            }}
          >
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(16, 185, 129, 0.15)', color: '#0e9f8a', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Globe style={{ width: '24px', height: '24px' }} />
                </div>
                <span style={{ fontSize: '0.72rem', fontWeight: 800, color: '#0e9f8a', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.3)', padding: '4px 10px', borderRadius: '9999px' }}>
                  ● LIVE NOW
                </span>
              </div>
              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
                Novyn Web
              </h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.55, margin: '0 0 20px' }}>
                Zero installation required. Connect from Chrome, Brave, Firefox, or Safari with instantaneous multi-tab sync.
              </p>
            </div>

            <button
              type="button"
              onClick={() => {
                triggerHaptic('medium');
                onOpenAuth('signup');
              }}
              className="btn btn-primary"
              style={{ width: '100%', padding: '12px', borderRadius: '14px', fontSize: '0.9rem', fontWeight: 700 }}
            >
              Launch Web App <ArrowRight style={{ width: '16px', height: '16px' }} />
            </button>
          </div>

          {/* 2. Mobile App */}
          <div
            className="landing-platform-card landing-platform-card--android"
            style={{
              padding: '28px',
              borderRadius: '24px',
              background: 'linear-gradient(135deg, rgba(56, 189, 248, 0.08) 0%, rgba(255, 255, 255, 0.55) 100%)',
              border: '1.5px solid rgba(56, 189, 248, 0.35)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              boxShadow: '0 8px 30px rgba(56, 189, 248, 0.12)',
            }}
          >
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(56, 189, 248, 0.15)', color: '#087fac', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Smartphone style={{ width: '24px', height: '24px' }} />
                </div>
                <span style={{ fontSize: '0.72rem', fontWeight: 800, color: '#087fac', background: 'rgba(56, 189, 248, 0.15)', border: '1px solid rgba(56, 189, 248, 0.3)', padding: '4px 10px', borderRadius: '9999px' }}>
                  ↓ DOWNLOAD
                </span>
              </div>
              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
                Novyn Android
              </h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.55, margin: '0 0 20px' }}>
                Native Android APK with physical vibration haptics, incoming ringtones, and camera integration. Direct install.
              </p>
            </div>

            <button
              type="button"
              onClick={triggerApkDownload}
              className="btn btn-secondary"
              style={{
                width: '100%',
                padding: '12px',
                borderRadius: '14px',
                fontSize: '0.9rem',
                fontWeight: 700,
                color: '#087fac',
                border: '1px solid rgba(56, 189, 248, 0.4)',
                background: 'rgba(56, 189, 248, 0.08)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
              }}
            >
              <Download style={{ width: '16px', height: '16px' }} />
              Download APK (Android)
            </button>
          </div>

          {/* 3. Desktop App */}
          <div
            className="landing-platform-card landing-platform-card--desktop"
            style={{
              padding: '28px',
              borderRadius: '24px',
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
            }}
          >
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(168, 85, 247, 0.12)', color: '#8651b3', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Laptop style={{ width: '24px', height: '24px' }} />
                </div>
                <span style={{ fontSize: '0.72rem', fontWeight: 700, color: '#8651b3', background: 'rgba(168, 85, 247, 0.12)', border: '1px solid rgba(168, 85, 247, 0.25)', padding: '4px 10px', borderRadius: '9999px' }}>
                  COMING SOON
                </span>
              </div>
              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '8px' }}>
                Novyn Desktop
              </h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.55, margin: '0 0 20px' }}>
                Dedicated Windows & macOS app with system tray dock, global shortcuts, and automatic background updates.
              </p>
            </div>

            <button
              type="button"
              onClick={() =>
                handleOpenComingSoon({
                  name: 'Novyn Desktop App',
                  type: 'Windows & macOS',
                  icon: Laptop,
                })
              }
              className="btn btn-secondary"
              style={{
                width: '100%',
                padding: '12px',
                borderRadius: '14px',
                fontSize: '0.9rem',
                fontWeight: 700,
                color: '#8651b3',
                border: '1px solid rgba(168, 85, 247, 0.3)',
              }}
            >
              Get Notified (Desktop) <BellRing style={{ width: '15px', height: '15px' }} />
            </button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid var(--border)', padding: '36px 24px', textAlign: 'center', fontSize: '0.86rem', color: 'var(--text-dark)', position: 'relative', zIndex: 1 }}>
        <div style={{ maxWidth: '1100px', margin: '0 auto', display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: '18px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <NovynLogo size={18} variant="white" withBadge badgeSize={30} />
            <span style={{ fontWeight: 800, color: 'var(--text-main)', fontSize: '1rem' }}>Novyn Chat</span>
          </div>
          <p style={{ margin: 0 }}>© 2026 Novyn Technologies. Zero-Knowledge E2EE Architecture.</p>
          <div style={{ display: 'flex', gap: '18px' }}>
            <button onClick={() => onOpenAuth('signin')} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontWeight: 600 }}>
              Sign In
            </button>
            <button onClick={() => onOpenAuth('signup')} style={{ background: 'none', border: 'none', color: '#0e9f8a', cursor: 'pointer', fontWeight: 600 }}>
              Create Account
            </button>
          </div>
        </div>
      </footer>

      {/* Coming Soon Modal */}
      <AnimatePresence>
        {comingSoonPlatform && (
          <div
            className="landing-coming-soon-overlay"
            style={{
              position: 'fixed',
              inset: 0,
              zIndex: 100,
              background: 'rgba(23, 66, 78, 0.12)',
              backdropFilter: 'blur(14px)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '20px',
            }}
            onClick={() => setComingSoonPlatform(null)}
          >
            <motion.div
              className="landing-coming-soon-dialog"
              initial={{ scale: 0.92, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.92, opacity: 0, y: 20 }}
              transition={{ type: 'spring', damping: 25, stiffness: 350 }}
              style={{
                width: '100%',
                maxWidth: '460px',
                background: 'var(--bg-surface)',
                border: '1px solid var(--border)',
                borderRadius: '24px',
                padding: '30px',
                boxShadow: '0 25px 60px rgba(36, 76, 96, 0.1)',
                position: 'relative',
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <button
                className="landing-coming-soon-close"
                type="button"
                onClick={() => setComingSoonPlatform(null)}
                style={{
                  position: 'absolute',
                  top: '20px',
                  right: '20px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  color: 'var(--text-muted)',
                  width: '32px',
                  height: '32px',
                  borderRadius: '10px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
              >
                <X style={{ width: '16px', height: '16px' }} />
              </button>

              <div style={{ textAlign: 'center', marginBottom: '22px' }}>
                <div
                  style={{
                    width: '64px',
                    height: '64px',
                    borderRadius: '20px',
                    background: 'linear-gradient(135deg, rgba(56, 189, 248, 0.15) 0%, rgba(168, 85, 247, 0.15) 100%)',
                    border: '1px solid rgba(56, 189, 248, 0.3)',
                    color: '#087fac',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    margin: '0 auto 16px',
                  }}
                >
                  <comingSoonPlatform.icon style={{ width: '32px', height: '32px' }} />
                </div>
                <h3 style={{ fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-main)', margin: '0 0 6px' }}>
                  {comingSoonPlatform.name}
                </h3>
                <div style={{ fontSize: '0.8rem', fontWeight: 700, color: '#087fac', marginBottom: '10px' }}>
                  {comingSoonPlatform.type} • Private Beta
                </div>
                <p style={{ fontSize: '0.86rem', color: 'var(--text-muted)', lineHeight: 1.5, margin: 0 }}>
                  We are putting the final touches on our dedicated standalone experience. Leave your email to be the first to test early access builds!
                </p>
              </div>

              {notifySuccess ? (
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '14px 18px',
                    borderRadius: '14px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    border: '1px solid rgba(16, 185, 129, 0.3)',
                    color: '#078779',
                    fontSize: '0.88rem',
                    fontWeight: 600,
                  }}
                >
                  <CheckCircle2 style={{ width: '18px', height: '18px', flexShrink: 0 }} />
                  <span>You are on the VIP early access list! We will notify you once ready.</span>
                </div>
              ) : (
                <form onSubmit={handleNotifySubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <input
                    type="email"
                    required
                    value={notifyEmail}
                    onChange={(e) => setNotifyEmail(e.target.value)}
                    placeholder="Enter your email address..."
                    className="input-field"
                    style={{ height: '46px', fontSize: '0.9rem', borderRadius: '12px', paddingLeft: '14px' }}
                  />

                  <button
                    type="submit"
                    className="btn btn-primary"
                    style={{ height: '46px', borderRadius: '12px', fontSize: '0.92rem', fontWeight: 700 }}
                  >
                    Notify Me on Release 🚀
                  </button>
                </form>
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};
