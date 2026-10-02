import React, { useState } from 'react';
import { ArrowLeft, ArrowRight, Check, KeyRound, Lock, Mail, User } from 'lucide-react';
import { connectSocket, getSocket } from '../../services/socket';

export function PasswordRecovery({ onBack, initialIdentifier = '' }: { onBack: () => void; initialIdentifier?: string }) {
  const [identifier, setIdentifier] = useState(initialIdentifier);
  const [codeSent, setCodeSent] = useState(false);
  const [token, setToken] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [complete, setComplete] = useState(false);
  const [hasError, setHasError] = useState(false);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage('');
    setHasError(false);
    const socket = getSocket();
    const successEvent = codeSent ? 'password_reset_success' : 'password_reset_sent';
    const result = await new Promise<{ ok: boolean; message: string }>((resolve) => {
      const finish = (ok: boolean, text: string) => {
        clearTimeout(timer);
        socket.off(successEvent, success);
        socket.off('password_reset_failed', failure);
        socket.off('connect_error', connectionError);
        socket.off('connect', send);
        resolve({ ok, message: text });
      };
      const success = (data: { message: string }) => finish(true, data.message);
      const failure = (data: { message: string }) => finish(false, data.message);
      const connectionError = () => finish(false, 'Unable to connect. Please try again.');
      const send = () => socket.emit(codeSent ? 'reset_password' : 'request_password_reset', { identifier, token, newPassword });
      const timer = setTimeout(() => finish(false, 'Request timed out. Please try again.'), 15000);
      socket.once(successEvent, success);
      socket.once('password_reset_failed', failure);
      socket.once('connect_error', connectionError);
      if (socket.connected) send();
      else { socket.once('connect', send); connectSocket(); }
    });
    setLoading(false);
    setMessage(result.message);
    setHasError(!result.ok);
    if (result.ok) {
      if (codeSent) { setComplete(true); setNewPassword(''); setToken(''); }
      else setCodeSent(true);
    }
  };

  return (
    <form className="password-recovery" onSubmit={submit} aria-busy={loading}>
      <header className="recovery-header">
        <div className="recovery-badge" aria-hidden="true">
          {complete ? <Check /> : codeSent ? <Mail /> : <KeyRound />}
        </div>
        <h2 id="recovery-title">{complete ? 'Password updated' : codeSent ? 'Check your email' : 'Forgot password?'}</h2>
        <p>{complete
          ? 'Your new password is ready. Sign in to get back to your conversations.'
          : codeSent
            ? 'Enter your verification code and choose a new password.'
            : 'Enter your username or email and we’ll send a reset code to your account’s email address.'}</p>
      </header>

      {message && <div className={`recovery-notice${hasError ? ' recovery-notice-error' : ''}`} role={hasError ? 'alert' : 'status'}>{message}</div>}

      {!complete && <div className="recovery-fields">
        <div>
          <label className="input-label" htmlFor="recovery-identifier">Username or email</label>
          <div className="recovery-input">
            <User aria-hidden="true" />
            <input id="recovery-identifier" className="input-field" autoComplete="username" autoCapitalize="none" spellCheck={false} placeholder="Enter your username or email" autoFocus required value={identifier} disabled={codeSent || loading} onChange={(e) => setIdentifier(e.target.value)} />
          </div>
        </div>
        {codeSent && <>
          <div>
            <label className="input-label" htmlFor="recovery-code">Verification code</label>
            <div className="recovery-input">
              <KeyRound aria-hidden="true" />
              <input id="recovery-code" className="input-field" autoComplete="one-time-code" placeholder="Enter the code from your email" autoFocus required disabled={loading} value={token} onChange={(e) => setToken(e.target.value)} />
            </div>
          </div>
          <div>
            <label className="input-label" htmlFor="recovery-password">New password</label>
            <div className="recovery-input">
              <Lock aria-hidden="true" />
              <input id="recovery-password" className="input-field" type="password" autoComplete="new-password" placeholder="Create a new password" aria-describedby="recovery-password-hint" required minLength={12} disabled={loading} value={newPassword} onChange={(e) => setNewPassword(e.target.value)} />
            </div>
            <p id="recovery-password-hint" className="recovery-hint">Use at least 12 characters.</p>
          </div>
        </>}
      </div>}

      <div className="recovery-actions">
        {!complete && <button className="btn btn-primary" type="submit" disabled={loading}>
          {loading ? 'Please wait…' : codeSent ? 'Update password' : 'Send reset code'}
          {!loading && <ArrowRight size={18} aria-hidden="true" />}
        </button>}
        <button className={`btn ${complete ? 'btn-primary' : 'btn-secondary'}`} type="button" disabled={loading} onClick={onBack}>
          <ArrowLeft size={18} aria-hidden="true" /> Back to sign in
        </button>
      </div>
    </form>
  );
}
