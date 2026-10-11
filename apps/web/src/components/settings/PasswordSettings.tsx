import React, { useState, useEffect } from 'react';
import { Eye, EyeOff, Check, ShieldCheck, KeyRound, CheckCircle2 } from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import { useAuth } from '../../context/AuthContext';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export const PasswordSettings: React.FC = () => {
  const { user, setUser } = useAuth();
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  // If user signed in with Google and hasn't created a password yet
  const isGoogleAccount = Boolean(user?.isGoogleUser);
  const hasPassword = Boolean(user?.hasPassword);

  useEffect(() => {
    const socket = getSocket();
    const handleSuccess = (payload?: { hasPassword?: boolean }) => {
      setIsSubmitting(false);
      triggerHaptic('success');
      setNotice({
        text: hasPassword
          ? 'Password updated successfully! Other sessions have been revoked.'
          : 'Account password created successfully! You can now sign in with either Google or your password.',
        error: false,
      });
      if (payload?.hasPassword && setUser) {
        setUser((prev) => (prev ? { ...prev, hasPassword: true } : prev));
      }
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
    };

    const handleFailure = (payload: { message?: string }) => {
      setIsSubmitting(false);
      triggerHaptic('heavy');
      setNotice({ text: payload?.message || 'Failed to update password. Please check your current password.', error: true });
    };

    socket.on('password_changed', handleSuccess);
    socket.on('password_change_failed', handleFailure);

    return () => {
      socket.off('password_changed', handleSuccess);
      socket.off('password_change_failed', handleFailure);
    };
  }, [hasPassword, setUser]);

  const calculateStrength = (pwd: string) => {
    if (!pwd) return 0;
    let score = 0;
    if (pwd.length >= 6) score++;
    if (pwd.length >= 10) score++;
    if (/[A-Z]/.test(pwd)) score++;
    if (/[0-9]/.test(pwd)) score++;
    if (/[^A-Za-z0-9]/.test(pwd)) score++;
    return score;
  };

  const strength = calculateStrength(newPassword);
  const strengthLabels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
  const strengthColors = ['#ef4444', '#f59e0b', '#eab308', '#10b981', '#059669'];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (hasPassword && !currentPassword) {
      setNotice({ text: 'Please enter your current password.', error: true });
      return;
    }
    if (newPassword.length < 6) {
      setNotice({ text: 'New password must be at least 6 characters.', error: true });
      return;
    }
    if (newPassword !== confirmPassword) {
      setNotice({ text: 'New passwords do not match.', error: true });
      return;
    }
    if (hasPassword && currentPassword === newPassword) {
      setNotice({ text: 'New password must be different from current password.', error: true });
      return;
    }

    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Cannot change password while offline. Please reconnect first.', error: true });
      return;
    }

    setIsSubmitting(true);
    triggerHaptic('medium');
    socket.emit('change_password', { currentPassword, newPassword });

    setTimeout(() => {
      setIsSubmitting((prev) => {
        if (prev) {
          setNotice({ text: 'Server response timed out. Please verify your connection.', error: true });
          return false;
        }
        return false;
      });
    }, 10000);
  };

  return (
    <div className="web-settings-card" style={{ maxWidth: 640 }}>
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div
          style={{
            width: 44,
            height: 44,
            borderRadius: 14,
            background: 'rgba(124, 58, 237, 0.15)',
            border: '1px solid rgba(167, 139, 250, 0.25)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#a78bfa',
          }}
        >
          <KeyRound size={22} />
        </div>
        <div>
          <h3 style={{ margin: 0, fontSize: '1.15rem' }}>
            {hasPassword ? 'Change Account Password' : 'Set Account Password'}
          </h3>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
            {hasPassword
              ? 'Choose a strong password to protect your account and encrypted keys.'
              : 'Create a password to sign in directly with your username on any device.'}
          </p>
        </div>
      </div>

      {/* Google Account Linked Banner */}
      {isGoogleAccount && (
        <div
          style={{
            padding: '14px 16px',
            borderRadius: 16,
            background: 'rgba(66, 133, 244, 0.08)',
            border: '1px solid rgba(66, 133, 244, 0.22)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 20,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: '#fff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 2px 6px rgba(0, 0, 0, 0.15)',
              }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                />
              </svg>
            </div>
            <div>
              <strong style={{ fontSize: '0.88rem', color: 'var(--text-main)', display: 'block' }}>
                Google Account Linked
              </strong>
              <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>
                {user?.email || 'Signed in via Google'}
              </span>
            </div>
          </div>
          <span
            style={{
              padding: '4px 10px',
              borderRadius: 999,
              background: 'rgba(16, 185, 129, 0.15)',
              color: '#10b981',
              fontSize: '0.72rem',
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <CheckCircle2 size={13} /> Active
          </span>
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {/* Current Password (Only shown if user has an existing password) */}
        {hasPassword && (
          <div>
            <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 600, marginBottom: 6, color: 'var(--text-main)' }}>
              Current Password
            </label>
            <div style={{ position: 'relative' }}>
              <input
                type={showCurrent ? 'text' : 'password'}
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                placeholder="Enter current password"
                required
                disabled={isSubmitting}
                style={{
                  width: '100%',
                  padding: '11px 40px 11px 14px',
                  borderRadius: 12,
                  border: '1px solid var(--border)',
                  background: 'var(--bg-app)',
                  color: 'var(--text-main)',
                  fontSize: '0.9rem',
                  outline: 'none',
                }}
              />
              <button
                type="button"
                onClick={() => setShowCurrent(!showCurrent)}
                style={{
                  position: 'absolute',
                  right: 12,
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'none',
                  border: 'none',
                  color: 'var(--text-muted)',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                {showCurrent ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>
        )}

        {/* New Password */}
        <div>
          <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 600, marginBottom: 6, color: 'var(--text-main)' }}>
            {hasPassword ? 'New Password' : 'Create Password'}
          </label>
          <div style={{ position: 'relative' }}>
            <input
              type={showNew ? 'text' : 'password'}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="Minimum 6 characters"
              required
              minLength={6}
              disabled={isSubmitting}
              style={{
                width: '100%',
                padding: '11px 40px 11px 14px',
                borderRadius: 12,
                border: '1px solid var(--border)',
                background: 'var(--bg-app)',
                color: 'var(--text-main)',
                fontSize: '0.9rem',
                outline: 'none',
              }}
            />
            <button
              type="button"
              onClick={() => setShowNew(!showNew)}
              style={{
                position: 'absolute',
                right: 12,
                top: '50%',
                transform: 'translateY(-50%)',
                background: 'none',
                border: 'none',
                color: 'var(--text-muted)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
              }}
            >
              {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>

          {/* Strength Bar */}
          {newPassword && (
            <div style={{ marginTop: 8 }}>
              <div style={{ display: 'flex', gap: 4, height: 4, marginBottom: 4 }}>
                {[1, 2, 3, 4, 5].map((lvl) => (
                  <div
                    key={lvl}
                    style={{
                      flex: 1,
                      borderRadius: 2,
                      background: lvl <= strength ? strengthColors[strength - 1] || '#10b981' : 'rgba(255, 255, 255, 0.1)',
                      transition: 'background 0.2s ease',
                    }}
                  />
                ))}
              </div>
              <span style={{ fontSize: '0.72rem', color: strengthColors[strength - 1] || 'var(--text-muted)', fontWeight: 600 }}>
                {strengthLabels[strength - 1] || 'Too short'}
              </span>
            </div>
          )}
        </div>

        {/* Confirm Password */}
        <div>
          <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 600, marginBottom: 6, color: 'var(--text-main)' }}>
            Confirm Password
          </label>
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Re-enter password"
            required
            minLength={6}
            disabled={isSubmitting}
            style={{
              width: '100%',
              padding: '11px 14px',
              borderRadius: 12,
              border: `1px solid ${confirmPassword && confirmPassword !== newPassword ? '#ef4444' : 'var(--border)'}`,
              background: 'var(--bg-app)',
              color: 'var(--text-main)',
              fontSize: '0.9rem',
              outline: 'none',
            }}
          />
          {confirmPassword && confirmPassword !== newPassword && (
            <span style={{ display: 'block', marginTop: 4, fontSize: '0.72rem', color: '#ef4444' }}>
              Passwords do not match
            </span>
          )}
        </div>

        {/* Note */}
        <div
          style={{
            padding: '12px 14px',
            borderRadius: 12,
            background: 'rgba(99, 102, 241, 0.08)',
            border: '1px solid rgba(99, 102, 241, 0.18)',
            display: 'flex',
            gap: 10,
            alignItems: 'flex-start',
            fontSize: '0.78rem',
            color: 'var(--text-muted)',
            lineHeight: 1.5,
          }}
        >
          <ShieldCheck size={16} style={{ color: '#818cf8', flexShrink: 0, marginTop: 2 }} />
          <span>
            {hasPassword
              ? 'Updating your password will automatically sign out any other active browser or mobile sessions.'
              : 'Once set, you will be able to sign in using either your Google Account or your username and password.'}
          </span>
        </div>

        <button
          type="submit"
          disabled={isSubmitting || (hasPassword && !currentPassword) || newPassword.length < 6 || newPassword !== confirmPassword}
          className="btn btn-primary"
          style={{
            marginTop: 6,
            height: 44,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            fontWeight: 700,
          }}
        >
          {isSubmitting ? (
            hasPassword ? 'Updating password…' : 'Setting password…'
          ) : (
            <>
              <Check size={18} /> {hasPassword ? 'Update Password' : 'Save Account Password'}
            </>
          )}
        </button>
      </form>
    </div>
  );
};
