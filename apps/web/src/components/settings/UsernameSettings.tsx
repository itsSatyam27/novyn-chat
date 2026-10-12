import React, { useEffect, useRef, useState } from 'react';
import { AlertCircle, AtSign, Check, CheckCircle2, KeyRound, ShieldCheck } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { triggerHaptic } from '../../services/capacitor';
import { getSocket } from '../../services/socket';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export const UsernameSettings: React.FC = () => {
  const { user, setUser } = useAuth();
  const [newUsername, setNewUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);
  const desiredRef = useRef('');
  const requestTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const currentUsername = user?.username || '';
  const hasPassword = Boolean(user?.hasPassword);
  const isGoogleAccount = Boolean(user?.isGoogleUser);
  const cleanDesired = newUsername.trim().toLowerCase();
  const isLengthValid = cleanDesired.length >= 3 && cleanDesired.length <= 24;
  const isFormatValid = /^[a-z0-9_]+$/.test(cleanDesired);
  const isDifferent = cleanDesired !== currentUsername.toLowerCase();
  const canSubmit = isLengthValid && isFormatValid && isDifferent && (!hasPassword || password.length > 0);

  useEffect(() => {
    const socket = getSocket();
    const handleSuccess = (payload: { newUsername?: string }) => {
      if (requestTimerRef.current) clearTimeout(requestTimerRef.current);
      requestTimerRef.current = null;
      const updated = payload?.newUsername || desiredRef.current;
      setIsSubmitting(false);
      triggerHaptic('success');
      setNotice({ text: `Username changed to @${updated}.`, error: false });
      setUser(previous => previous ? { ...previous, username: updated } : previous);
      try { localStorage.setItem('novyn_chat_username', updated); } catch (_) {}
      setNewUsername('');
      setPassword('');
    };
    const handleFailure = (payload: { message?: string }) => {
      if (requestTimerRef.current) clearTimeout(requestTimerRef.current);
      requestTimerRef.current = null;
      setIsSubmitting(false);
      triggerHaptic('heavy');
      setNotice({ text: payload?.message || 'Could not update username. Please try again.', error: true });
    };
    socket.on('username_changed', handleSuccess);
    socket.on('username_change_failed', handleFailure);
    return () => {
      if (requestTimerRef.current) clearTimeout(requestTimerRef.current);
      socket.off('username_changed', handleSuccess);
      socket.off('username_change_failed', handleFailure);
    };
  }, [setUser]);

  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    if (!canSubmit || isSubmitting) return;
    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Reconnect before changing your username.', error: true });
      return;
    }
    desiredRef.current = cleanDesired;
    setIsSubmitting(true);
    setNotice(null);
    triggerHaptic('medium');
    socket.emit('change_username', { newUsername: cleanDesired, currentPassword: password });
    requestTimerRef.current = setTimeout(() => {
      requestTimerRef.current = null;
      setIsSubmitting(false);
      triggerHaptic('heavy');
      setNotice({ text: 'Username update timed out. Check your connection and try again.', error: true });
    }, 15000);
  };

  return <section className="username-dashboard" aria-label="Change username">
    {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}
    <article className="username-card">
      <header className="username-card-heading">
        <span><AtSign size={22} aria-hidden="true" /></span>
        <div><h3>Choose your username</h3><p>Your public @handle helps people find you on Novyn.</p></div>
      </header>
      <div className="username-current">
        <div><small>Current username</small><strong>@{currentUsername}</strong></div>
        <span><CheckCircle2 size={14} aria-hidden="true" />Active</span>
      </div>
      {isGoogleAccount && !hasPassword && <div className="username-provider-note"><ShieldCheck size={19} aria-hidden="true" /><span>Your account is verified with Google. No password confirmation is required.</span></div>}
      <form className="username-form" onSubmit={submit}>
        <label><span>New username</span><div className="username-input"><AtSign size={17} aria-hidden="true" /><input value={newUsername} maxLength={24} autoCapitalize="none" autoCorrect="off" spellCheck={false} disabled={isSubmitting} placeholder="new_handle" onChange={event => setNewUsername(event.target.value.toLowerCase().replace(/\s+/g, ''))} /></div></label>
        {cleanDesired && <div className="username-rules" aria-live="polite">
          <span data-valid={isLengthValid}><i>{isLengthValid ? <Check size={12} /> : <AlertCircle size={12} />}</i>3–24 characters</span>
          <span data-valid={isFormatValid}><i>{isFormatValid ? <Check size={12} /> : <AlertCircle size={12} />}</i>Letters, numbers and underscores</span>
          <span data-valid={isDifferent}><i>{isDifferent ? <Check size={12} /> : <AlertCircle size={12} />}</i>Different from your current username</span>
        </div>}
        {hasPassword && <label><span>Confirm with password</span><div className="username-input"><KeyRound size={17} aria-hidden="true" /><input type="password" value={password} disabled={isSubmitting} autoComplete="current-password" placeholder="Enter your account password" onChange={event => setPassword(event.target.value)} /></div></label>}
        <p className="username-impact-note">Friends and group chats will automatically see your new handle. Messages, contacts and encryption keys stay connected to your account.</p>
        <div className="username-actions">
          {(newUsername || password) && <button type="button" disabled={isSubmitting} onClick={() => { setNewUsername(''); setPassword(''); }}>Discard</button>}
          <button type="submit" className="is-primary" disabled={!canSubmit || isSubmitting}>{isSubmitting ? 'Updating…' : 'Update username'}</button>
        </div>
      </form>
    </article>
  </section>;
};
