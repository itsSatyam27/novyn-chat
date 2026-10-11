import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../../context/AuthContext';
import { ShieldCheck, Mail, Lock, User, ArrowRight, Monitor, Sparkles } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { NovynLogo } from '../ui/NovynLogo';
import { PasswordRecovery } from './PasswordRecovery';
import './mobileAuthPage.css';

interface MobileAuthPageProps {
  initialMode?: 'signin' | 'signup';
  onSwitchToDesktopLanding?: () => void;
}

export const MobileAuthPage: React.FC<MobileAuthPageProps> = ({
  initialMode = 'signin',
  onSwitchToDesktopLanding,
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    triggerHaptic('medium');

    try {
      if (mode === 'signin') {
        const res = await login({ identifier, password });
        if (!res.ok) {
          triggerHaptic('error');
          setError(res.error || 'Invalid credentials');
        } else {
          triggerHaptic('success');
        }
      } else {
        const res = await signup({ name, username: identifier, email, password });
        if (!res.ok) {
          triggerHaptic('error');
          setError(res.error || 'Failed to create account');
        } else {
          triggerHaptic('success');
        }
      }
    } finally {
      setLoading(false);
    }
  };

  const handleGoogle = async () => {
    setError('');
    setLoading(true);
    triggerHaptic('light');
    try {
      const res = await loginWithGoogle();
      if (!res.ok) {
        triggerHaptic('error');
        setError(res.error || 'Google login failed');
      } else {
        triggerHaptic('success');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mobile-auth-container">
      <div className="mobile-auth-glow-top" aria-hidden="true" />

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: 'spring', damping: 24, stiffness: 320 }}
        className="mobile-auth-card"
      >
        {!recovering && (
          <>
            {/* Brand Header */}
            <header className="mobile-auth-brand">
              <div className="mobile-auth-logo-badge">
                <NovynLogo size={36} variant="white" />
              </div>
              <h1 className="mobile-auth-title">
                {mode === 'signin' ? 'Welcome Back' : 'Get Started with Novyn'}
              </h1>
              <p className="mobile-auth-subtitle">
                <ShieldCheck size={14} style={{ color: 'var(--primary)' }} />
                End-to-End Encrypted Messenger
              </p>
            </header>

            {/* Tab Switcher */}
            <div className="mobile-auth-tabs" role="tablist">
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'signin'}
                onClick={() => {
                  triggerHaptic('light');
                  setMode('signin');
                  setRecovering(false);
                  setError('');
                }}
                className={`mobile-auth-tab-btn ${mode === 'signin' ? 'is-active' : ''}`}
              >
                Sign In
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'signup'}
                onClick={() => {
                  triggerHaptic('light');
                  setMode('signup');
                  setRecovering(false);
                  setError('');
                }}
                className={`mobile-auth-tab-btn ${mode === 'signup' ? 'is-active' : ''}`}
              >
                Create Account
              </button>
            </div>

            {/* Google Sign-in */}
            <button
              type="button"
              onClick={handleGoogle}
              disabled={loading}
              className="mobile-auth-btn-google"
            >
              <svg style={{ width: '18px', height: '18px', flexShrink: 0 }} viewBox="0 0 24 24">
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
              <span>Continue with Google</span>
            </button>

            <div className="mobile-auth-divider">
              <span className="mobile-auth-divider-line" />
              <span className="mobile-auth-divider-text">OR WITH PASSWORD</span>
              <span className="mobile-auth-divider-line" />
            </div>

            {/* Error Alert */}
            {error && <div className="mobile-auth-alert-error" role="alert">{error}</div>}
          </>
        )}

        {/* Form / Password Recovery */}
        {recovering ? (
          <PasswordRecovery
            initialIdentifier={identifier}
            onBack={() => setRecovering(false)}
          />
        ) : (
          <form onSubmit={handleSubmit} autoComplete="on">
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
                    autoComplete="name"
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
                    autoComplete="email"
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
                autoComplete="username"
                autoCapitalize="none"
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
                autoComplete={mode === 'signin' ? 'current-password' : 'new-password'}
              />
              {mode === 'signin' && (
                <button
                  type="button"
                  className="auth-forgot-password"
                  onClick={() => {
                    triggerHaptic('light');
                    setError('');
                    setRecovering(true);
                  }}
                >
                  Forgot password?
                </button>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ width: '100%', padding: '14px', fontSize: '0.96rem', marginTop: '10px' }}
            >
              {loading ? (
                <span style={{ display: 'inline-block', width: '18px', height: '18px', border: '2px solid #ffffff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
              ) : (
                <>
                  <span>{mode === 'signin' ? 'Sign In to Novyn' : 'Create Account'}</span>
                  <ArrowRight size={18} />
                </>
              )}
            </button>
          </form>
        )}

        {/* Footer Actions */}
        <footer className="mobile-auth-footer">
          {onSwitchToDesktopLanding && !recovering && (
            <button
              type="button"
              className="mobile-auth-desktop-link-btn"
              onClick={() => {
                triggerHaptic('light');
                onSwitchToDesktopLanding();
              }}
            >
              <Monitor size={14} />
              <span>Explore Features &amp; Downloads</span>
            </button>
          )}

          <div className="mobile-auth-security-tag">
            <ShieldCheck size={13} style={{ color: 'var(--primary)' }} />
            <span>Encrypted with client-side device keys</span>
          </div>
        </footer>
      </motion.div>
    </div>
  );
};
