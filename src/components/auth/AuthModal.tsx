import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../../context/AuthContext';
import { MessageSquare, ShieldCheck, Mail, Lock, User, ArrowRight, X } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { NovynLogo } from '../ui/NovynLogo';
import { PasswordRecovery } from './PasswordRecovery';

interface AuthModalProps {
  isOpen: boolean;
  initialMode?: 'signin' | 'signup';
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({
  isOpen,
  initialMode = 'signin',
  onClose,
}) => {
  const { login, signup, loginWithGoogle } = useAuth();
  const [mode, setMode] = useState<'signin' | 'signup'>(initialMode);
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [recovering, setRecovering] = useState(false);

  useEffect(() => {
    setMode(initialMode);
    setRecovering(false);
    setError('');
  }, [initialMode, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (mode === 'signin') {
        const res = await login({ identifier, password });
        if (!res.ok) setError(res.error || 'Invalid credentials');
      } else {
        const res = await signup({ name, username: identifier, email, password });
        if (!res.ok) setError(res.error || 'Failed to create account');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleGoogle = async () => {
    setError('');
    setLoading(true);
    try {
      const res = await loginWithGoogle();
      if (!res.ok) setError(res.error || 'Google login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatePresence>
      <div className="modal-backdrop auth-modal-backdrop" onClick={onClose}>
        <motion.div
          initial={{ opacity: 0, scale: 0.94, y: 15 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.94, y: 15 }}
          transition={{ type: 'spring', damping: 25, stiffness: 350 }}
          className="auth-modal-card"
          role="dialog"
          aria-modal="true"
          aria-labelledby={recovering ? 'recovery-title' : 'auth-title'}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close Button */}
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              onClose();
            }}
            className="modal-close-btn"
            aria-label="Close"
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>

          {!recovering && <>
          {/* Brand Header */}
          <div className="auth-brand-header" style={{ textAlign: 'center', marginBottom: '24px' }}>
            <div
              className="auth-brand-mark"
              style={{
                width: '52px',
                height: '52px',
                borderRadius: '16px',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 8px 20px rgba(16, 185, 129, 0.25)',
                marginBottom: '12px',
              }}
            >
              <NovynLogo size={32} variant="white" />
            </div>
            <h2 id="auth-title" className="auth-brand-title" style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em' }}>
              {mode === 'signin' ? 'Welcome Back' : 'Create an Account'}
            </h2>
            <p className="auth-brand-subtitle" style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '4px' }}>
              <ShieldCheck style={{ width: '14px', height: '14px', color: '#0e9f8a' }} /> Direct-message encryption with device keys
            </p>
          </div>

          {/* Tab Switcher */}
          <div className="tab-switcher">
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                setMode('signin');
                setRecovering(false);
                setError('');
              }}
              className={`tab-btn ${mode === 'signin' ? 'active' : ''}`}
            >
              Sign In
            </button>
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                setMode('signup');
                setRecovering(false);
                setError('');
              }}
              className={`tab-btn ${mode === 'signup' ? 'active' : ''}`}
            >
              Sign Up
            </button>
          </div>

          {/* Google Sign-in */}
          <button
            type="button"
            onClick={handleGoogle}
            disabled={loading}
            className="btn-google"
          >
            <svg style={{ width: '18px', height: '18px' }} viewBox="0 0 24 24">
              <path
                fill="#EA4335"
                d="M12 5c1.7 0 3 .6 4 1.5l3-3C17.2 1.8 14.8 1 12 1 7.5 1 3.7 3.6 1.9 7.3l3.7 2.9C6.5 7.4 9 5 12 5z"
              />
              <path
                fill="#4285F4"
                d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5c-.3 1.5-1.1 2.8-2.4 3.7l3.7 2.9c2.2-2 3.7-5 3.7-8.8z"
              />
              <path
                fill="#FBBC05"
                d="M5.6 14.8c-.3-.8-.4-1.8-.4-2.8s.2-2 .4-2.8L1.9 6.3C.7 8.7 0 10.3 0 12s.7 3.3 1.9 5.7l3.7-2.9z"
              />
              <path
                fill="#34A853"
                d="M12 23c3.2 0 6-1.1 8-3l-3.7-2.9c-1.1.7-2.5 1.2-4.3 1.2-3 0-5.5-2.4-6.4-5.2L1.9 16C3.7 19.7 7.5 23 12 23z"
              />
            </svg>
            Continue with Google
          </button>

          <div className="divider-box">
            <div className="divider-line" />
            <span className="divider-text">OR WITH PASSWORD</span>
            <div className="divider-line" />
          </div>

          {/* Error Alert */}
          {error && <div className="alert-error">{error}</div>}
          </>}

          {/* Form */}
          {recovering ? <PasswordRecovery initialIdentifier={identifier} onBack={() => setRecovering(false)} /> : <form onSubmit={handleSubmit}>
            {mode === 'signup' && (
              <>
                <div className="input-wrapper">
                  <label className="input-label">Full Name</label>
                  <User className="input-icon" />
                  <input
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Alice Johnson"
                    className="input-field"
                  />
                </div>

                <div className="input-wrapper">
                  <label className="input-label">Email Address</label>
                  <Mail className="input-icon" />
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="alice@example.com"
                    className="input-field"
                  />
                </div>
              </>
            )}

            <div className="input-wrapper">
              <label className="input-label">
                {mode === 'signin' ? 'Username or Email' : 'Choose Username'}
              </label>
              <User className="input-icon" />
              <input
                type="text"
                required
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                placeholder={mode === 'signin' ? 'username or email' : 'alice_27'}
                className="input-field"
              />
            </div>

            <div className="input-wrapper">
              <label className="input-label">Password</label>
              <Lock className="input-icon" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="input-field"
              />
              {mode === 'signin' && (
                <button type="button" className="auth-forgot-password" onClick={() => { setError(''); setRecovering(true); }}>
                  Forgot password?
                </button>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ width: '100%', padding: '14px', fontSize: '0.95rem', marginTop: '8px' }}
            >
              {loading ? (
                <span style={{ display: 'inline-block', width: '16px', height: '16px', border: '2px solid #ffffff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
              ) : (
                <>
                  {mode === 'signin' ? 'Sign In to Novyn' : 'Create Account'}
                  <ArrowRight style={{ width: '18px', height: '18px' }} />
                </>
              )}
            </button>
          </form>}
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
