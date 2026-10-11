import React, { useState, useEffect } from 'react';
import { AtSign, Check, AlertCircle, KeyRound, CheckCircle2, ShieldCheck } from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import { useAuth } from '../../context/AuthContext';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export const UsernameSettings: React.FC = () => {
  const { user, setUser } = useAuth();
  const [newUsername, setNewUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  const currentUsername = user?.username || '';
  const hasPassword = Boolean(user?.hasPassword);
  const isGoogleAccount = Boolean(user?.isGoogleUser);

  useEffect(() => {
    const socket = getSocket();

    const handleSuccess = (payload: { oldUsername?: string; newUsername?: string }) => {
      setIsSubmitting(false);
      triggerHaptic('success');
      const updated = payload?.newUsername || newUsername.trim().toLowerCase();
      setNotice({
        text: `Username successfully changed to @${updated}!`,
        error: false,
      });

      if (setUser) {
        setUser((prev) => (prev ? { ...prev, username: updated } : prev));
      }
      try {
        localStorage.setItem('novyn_chat_username', updated);
      } catch (_) {}

      setNewUsername('');
      setPassword('');
    };

    const handleFailure = (payload: { message?: string }) => {
      setIsSubmitting(false);
      triggerHaptic('heavy');
      setNotice({
        text: payload?.message || 'Failed to update username. Please try again.',
        error: true,
      });
    };

    socket.on('username_changed', handleSuccess);
    socket.on('username_change_failed', handleFailure);

    return () => {
      socket.off('username_changed', handleSuccess);
      socket.off('username_change_failed', handleFailure);
    };
  }, [newUsername, setUser]);

  const cleanDesired = newUsername.trim().toLowerCase();
  const isLengthValid = cleanDesired.length >= 3 && cleanDesired.length <= 24;
  const isFormatValid = /^[a-z0-9_]+$/.test(cleanDesired);
  const isDifferent = cleanDesired !== currentUsername.toLowerCase();
  const canSubmit = isLengthValid && isFormatValid && isDifferent && (!hasPassword || password.length > 0);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!cleanDesired) {
      setNotice({ text: 'Please enter a new username.', error: true });
      return;
    }
    if (!isLengthValid) {
      setNotice({ text: 'Username must be between 3 and 24 characters.', error: true });
      return;
    }
    if (!isFormatValid) {
      setNotice({ text: 'Username can only contain letters, numbers, and underscores.', error: true });
      return;
    }
    if (!isDifferent) {
      setNotice({ text: 'New username must be different from your current username.', error: true });
      return;
    }
    if (hasPassword && !password) {
      setNotice({ text: 'Please enter your account password to confirm this change.', error: true });
      return;
    }

    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Server disconnected. Please wait for reconnection.', error: true });
      return;
    }

    setIsSubmitting(true);
    setNotice(null);
    triggerHaptic('medium');
    socket.emit('change_username', {
      newUsername: cleanDesired,
      currentPassword: password,
    });
  };

  return (
    <div className="web-settings-card" style={{ maxWidth: 640 }}>
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      {/* Header Icon + Title */}
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
            <AtSign size={22} />
          </div>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.15rem' }}>Change Username</h3>
            <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
              Your username is your unique identifier on Novyn.
            </p>
          </div>
        </div>

        {/* Current Username Card */}
        <div
          style={{
            padding: '14px 16px',
            borderRadius: 14,
            background: 'rgba(255, 255, 255, 0.03)',
            border: '1px solid rgba(255, 255, 255, 0.06)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 20,
          }}
        >
          <div>
            <small style={{ color: 'var(--text-muted)', display: 'block', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Current Handle
            </small>
            <strong style={{ fontSize: '1.05rem', color: '#fff' }}>@{currentUsername}</strong>
          </div>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '4px 10px',
              borderRadius: 20,
              fontSize: '0.75rem',
              fontWeight: 600,
              background: 'rgba(16, 185, 129, 0.12)',
              color: '#10b981',
              border: '1px solid rgba(16, 185, 129, 0.25)',
            }}
          >
            <CheckCircle2 size={13} /> Active
          </span>
        </div>

        {/* Google User Info Notice if applicable */}
        {isGoogleAccount && !hasPassword && (
          <div
            style={{
              padding: '12px 16px',
              borderRadius: 14,
              background: 'rgba(66, 133, 244, 0.08)',
              border: '1px solid rgba(66, 133, 244, 0.22)',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              marginBottom: 20,
            }}
          >
            <ShieldCheck size={20} color="#4285F4" style={{ flexShrink: 0 }} />
            <span style={{ fontSize: '0.82rem', color: 'var(--text-main, #f1f5f9)' }}>
              Verified via Google Sign-In. You can update your handle without entering a current password.
            </span>
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* New Username Input */}
          <div>
            <label
              style={{
                display: 'block',
                fontSize: '0.85rem',
                fontWeight: 500,
                marginBottom: 8,
                color: 'var(--text-main)',
              }}
            >
              New Username
            </label>
            <div style={{ position: 'relative' }}>
              <span
                style={{
                  position: 'absolute',
                  left: 14,
                  top: '50%',
                  transform: 'translateY(-50%)',
                  color: 'var(--text-muted)',
                  fontSize: '0.95rem',
                  fontWeight: 600,
                }}
              >
                @
              </span>
              <input
                type="text"
                value={newUsername}
                onChange={(e) => setNewUsername(e.target.value.toLowerCase().replace(/\s+/g, ''))}
                placeholder="new_handle"
                maxLength={24}
                autoCapitalize="none"
                autoCorrect="off"
                spellCheck={false}
                style={{
                  width: '100%',
                  boxSizing: 'border-box',
                  padding: '12px 14px 12px 32px',
                  borderRadius: 12,
                  background: 'rgba(0, 0, 0, 0.25)',
                  border: `1px solid ${cleanDesired ? (isLengthValid && isFormatValid && isDifferent ? 'rgba(16, 185, 129, 0.5)' : 'rgba(239, 68, 68, 0.5)') : 'rgba(255, 255, 255, 0.1)'}`,
                  color: '#fff',
                  fontSize: '0.95rem',
                  fontFamily: 'monospace',
                  outline: 'none',
                }}
              />
            </div>
          </div>

          {/* Validation Checklist */}
          {cleanDesired.length > 0 && (
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                gap: 6,
                padding: '10px 14px',
                borderRadius: 12,
                background: 'rgba(255, 255, 255, 0.02)',
                border: '1px solid rgba(255, 255, 255, 0.05)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.78rem', color: isLengthValid ? '#10b981' : 'var(--text-muted)' }}>
                {isLengthValid ? <Check size={14} /> : <AlertCircle size={14} />} 3 to 24 characters
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.78rem', color: isFormatValid ? '#10b981' : 'var(--text-muted)' }}>
                {isFormatValid ? <Check size={14} /> : <AlertCircle size={14} />} Lowercase letters, numbers, and underscores only
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.78rem', color: isDifferent ? '#10b981' : 'var(--text-muted)' }}>
                {isDifferent ? <Check size={14} /> : <AlertCircle size={14} />} Different from current handle
              </div>
            </div>
          )}

          {/* Password confirmation if user has password */}
          {hasPassword && (
            <div>
              <label
                style={{
                  display: 'block',
                  fontSize: '0.85rem',
                  fontWeight: 500,
                  marginBottom: 8,
                  color: 'var(--text-main)',
                }}
              >
                Confirm with Account Password
              </label>
              <div style={{ position: 'relative' }}>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter current password"
                  style={{
                    width: '100%',
                    boxSizing: 'border-box',
                    padding: '12px 14px',
                    borderRadius: 12,
                    background: 'rgba(0, 0, 0, 0.25)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    color: '#fff',
                    fontSize: '0.95rem',
                    outline: 'none',
                  }}
                />
              </div>
            </div>
          )}

          {/* Impact information notice */}
          <p style={{ margin: 0, fontSize: '0.78rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
            Note: Friends and group chats will automatically see your new handle. All your messages, contacts, and end-to-end encryption keys remain completely intact.
          </p>

          {/* Actions */}
          <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
            {cleanDesired && (
              <button
                type="button"
                className="btn btn-secondary"
                disabled={isSubmitting}
                onClick={() => {
                  setNewUsername('');
                  setPassword('');
                }}
                style={{ flex: 1, padding: 12, borderRadius: 12 }}
              >
                Discard
              </button>
            )}
            <button
              type="submit"
              className="btn btn-primary"
              disabled={isSubmitting || !canSubmit}
              style={{
                flex: 2,
                padding: 12,
                borderRadius: 12,
                background: canSubmit ? 'var(--chat-indigo, #6366f1)' : 'rgba(99, 102, 241, 0.4)',
                fontWeight: 600,
              }}
            >
              {isSubmitting ? 'Updating handle…' : 'Update Username'}
            </button>
          </div>
        </form>
    </div>
  );
};
