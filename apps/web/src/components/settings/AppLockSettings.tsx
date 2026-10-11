import React, { useState, useEffect } from 'react';
import { Lock, Unlock, ShieldAlert, KeyRound, Check, Clock, Trash2 } from 'lucide-react';
import {
  isAppLockConfigured,
  setAppLockPin,
  verifyAppLockPin,
  disableAppLock,
  getAutoLockTimeout,
  setAutoLockTimeout,
  lockApp,
  subscribeAppLock,
} from '../../services/appLock';
import { triggerHaptic } from '../../services/capacitor';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export const AppLockSettings: React.FC = () => {
  const [isConfigured, setIsConfigured] = useState(() => isAppLockConfigured());
  const [timeout, setTimeoutVal] = useState(() => getAutoLockTimeout());
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  // Setup / Change PIN Dialog State
  const [dialogMode, setDialogMode] = useState<'create' | 'change' | 'disable' | null>(null);
  const [step, setStep] = useState<'current' | 'new' | 'confirm'>('new');
  const [currentPin, setCurrentPin] = useState('');
  const [newPin, setNewPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    return subscribeAppLock(() => {
      setIsConfigured(isAppLockConfigured());
      setTimeoutVal(getAutoLockTimeout());
    });
  }, []);

  const resetDialog = () => {
    setDialogMode(null);
    setStep('new');
    setCurrentPin('');
    setNewPin('');
    setConfirmPin('');
    setErrorMsg('');
  };

  const handleStartSetup = () => {
    triggerHaptic('light');
    setDialogMode('create');
    setStep('new');
  };

  const handleStartChange = () => {
    triggerHaptic('light');
    setDialogMode('change');
    setStep('current');
  };

  const handleStartDisable = () => {
    triggerHaptic('medium');
    setDialogMode('disable');
    setStep('current');
  };

  const handleVerifyCurrentPin = async () => {
    if (currentPin.length !== 4) return;
    const ok = await verifyAppLockPin(currentPin);
    if (!ok) {
      triggerHaptic('heavy');
      setErrorMsg('Incorrect PIN. Please try again.');
      setCurrentPin('');
      return;
    }

    triggerHaptic('success');
    setErrorMsg('');
    if (dialogMode === 'disable') {
      disableAppLock();
      resetDialog();
      setNotice({ text: 'Screen lock PIN has been disabled.', error: false });
    } else if (dialogMode === 'change') {
      setStep('new');
    }
  };

  const handleSaveNewPin = async () => {
    if (newPin.length !== 4) {
      setErrorMsg('PIN must be exactly 4 digits.');
      return;
    }
    if (newPin !== confirmPin) {
      triggerHaptic('heavy');
      setErrorMsg('PINs do not match. Please re-enter.');
      setConfirmPin('');
      return;
    }

    const ok = await setAppLockPin(newPin);
    if (ok) {
      triggerHaptic('success');
      resetDialog();
      setNotice({
        text: dialogMode === 'change' ? 'PIN updated successfully!' : 'Screen lock PIN enabled!',
        error: false,
      });
    }
  };

  const handleTimeoutChange = (val: number) => {
    triggerHaptic('light');
    setAutoLockTimeout(val);
    setTimeoutVal(val);
    setNotice({ text: 'Auto-lock timeout updated.', error: false });
  };

  const handleLockNow = () => {
    triggerHaptic('medium');
    lockApp();
  };

  const timeoutOptions = [
    { label: 'Immediately on tab blur', val: 0 },
    { label: 'After 1 minute', val: 1 },
    { label: 'After 5 minutes', val: 5 },
    { label: 'After 15 minutes', val: 15 },
  ];

  return (
    <div className="web-settings-card" style={{ maxWidth: 640 }}>
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div
          style={{
            width: 44,
            height: 44,
            borderRadius: 14,
            background: isConfigured ? 'rgba(16, 185, 129, 0.15)' : 'rgba(124, 58, 237, 0.15)',
            border: `1px solid ${isConfigured ? 'rgba(16, 185, 129, 0.3)' : 'rgba(167, 139, 250, 0.25)'}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: isConfigured ? '#10b981' : '#a78bfa',
          }}
        >
          {isConfigured ? <Lock size={22} /> : <Unlock size={22} />}
        </div>
        <div>
          <h3 style={{ margin: 0, fontSize: '1.15rem' }}>Screen Lock &amp; PIN</h3>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
            Require a 4-digit passcode to open and view your messages in this browser.
          </p>
        </div>
      </div>

      {/* Main Switch / Status Row */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '16px',
          borderRadius: 14,
          background: 'var(--bg-app)',
          border: '1px solid var(--border)',
          marginBottom: 16,
        }}
      >
        <div>
          <strong style={{ display: 'block', fontSize: '0.9rem', color: 'var(--text-main)' }}>
            Passcode Protection
          </strong>
          <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
            {isConfigured ? 'Enabled · Chats are protected' : 'Disabled · Anyone on this device can view chats'}
          </span>
        </div>
        {isConfigured ? (
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleStartChange}
              style={{ fontSize: '0.78rem', padding: '6px 12px', minHeight: 34 }}
            >
              Change PIN
            </button>
            <button
              type="button"
              className="btn"
              onClick={handleStartDisable}
              style={{
                fontSize: '0.78rem',
                padding: '6px 12px',
                minHeight: 34,
                color: '#ef4444',
                borderColor: 'rgba(239, 68, 68, 0.3)',
                background: 'rgba(239, 68, 68, 0.08)',
              }}
            >
              Turn Off
            </button>
          </div>
        ) : (
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleStartSetup}
            style={{ fontSize: '0.82rem', padding: '7px 16px', minHeight: 36, fontWeight: 700 }}
          >
            Set up PIN
          </button>
        )}
      </div>

      {/* Auto-Lock Timer & Instant Lock (Shown when Configured) */}
      {isConfigured && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 600, marginBottom: 8, color: 'var(--text-main)' }}>
              Auto-Lock Inactivity Timeout
            </label>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 8 }}>
              {timeoutOptions.map((opt) => (
                <button
                  key={opt.val}
                  type="button"
                  onClick={() => handleTimeoutChange(opt.val)}
                  style={{
                    padding: '10px 14px',
                    borderRadius: 10,
                    border: `1px solid ${timeout === opt.val ? 'var(--primary)' : 'var(--border)'}`,
                    background: timeout === opt.val ? 'var(--primary-glow)' : 'var(--bg-app)',
                    color: timeout === opt.val ? 'var(--primary)' : 'var(--text-main)',
                    fontSize: '0.8rem',
                    fontWeight: timeout === opt.val ? 700 : 500,
                    cursor: 'pointer',
                    textAlign: 'left',
                    transition: 'all 0.15s ease',
                  }}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-start', paddingTop: 8 }}>
            <button
              type="button"
              onClick={handleLockNow}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600 }}
            >
              <Lock size={15} /> Lock App Now
            </button>
          </div>
        </div>
      )}

      {/* PIN Setup / Verification Interactive Modal Overlay */}
      {dialogMode && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.65)',
            backdropFilter: 'blur(8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 16,
          }}
          onClick={resetDialog}
        >
          <div
            style={{
              width: '100%',
              maxWidth: 380,
              background: '#130e24',
              border: '1px solid rgba(255, 255, 255, 0.12)',
              borderRadius: 22,
              padding: '24px',
              boxShadow: '0 20px 50px rgba(0, 0, 0, 0.5)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 6px', fontSize: '1.2rem', color: '#fff', textAlign: 'center' }}>
              {dialogMode === 'create'
                ? 'Set 4-Digit Passcode'
                : dialogMode === 'change'
                ? step === 'current'
                  ? 'Enter Current PIN'
                  : 'Enter New PIN'
                : 'Enter PIN to Disable'}
            </h3>
            <p style={{ margin: '0 0 20px', fontSize: '0.8rem', color: '#aaa', textAlign: 'center' }}>
              {step === 'current'
                ? 'Verify your identity before modifying lock settings'
                : step === 'new'
                ? 'Choose a 4-digit PIN you will remember'
                : 'Confirm your 4-digit PIN'}
            </p>

            {errorMsg && (
              <div
                style={{
                  padding: '8px 12px',
                  borderRadius: 8,
                  background: 'rgba(239, 68, 68, 0.15)',
                  color: '#ef4444',
                  fontSize: '0.78rem',
                  marginBottom: 16,
                  textAlign: 'center',
                }}
              >
                {errorMsg}
              </div>
            )}

            {step === 'current' ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <input
                  type="password"
                  inputMode="numeric"
                  maxLength={4}
                  autoFocus
                  value={currentPin}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 4);
                    setCurrentPin(val);
                    setErrorMsg('');
                  }}
                  placeholder="••••"
                  style={{
                    fontSize: '1.8rem',
                    textAlign: 'center',
                    letterSpacing: '0.5em',
                    padding: '10px',
                    borderRadius: 12,
                    border: '1px solid rgba(255, 255, 255, 0.15)',
                    background: '#1d1536',
                    color: '#fff',
                    outline: 'none',
                  }}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={currentPin.length !== 4}
                  onClick={handleVerifyCurrentPin}
                  style={{ height: 42, fontWeight: 700 }}
                >
                  Confirm
                </button>
              </div>
            ) : step === 'new' ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <input
                  type="password"
                  inputMode="numeric"
                  maxLength={4}
                  autoFocus
                  value={newPin}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 4);
                    setNewPin(val);
                    setErrorMsg('');
                  }}
                  placeholder="••••"
                  style={{
                    fontSize: '1.8rem',
                    textAlign: 'center',
                    letterSpacing: '0.5em',
                    padding: '10px',
                    borderRadius: 12,
                    border: '1px solid rgba(255, 255, 255, 0.15)',
                    background: '#1d1536',
                    color: '#fff',
                    outline: 'none',
                  }}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={newPin.length !== 4}
                  onClick={() => {
                    if (newPin.length === 4) {
                      triggerHaptic('light');
                      setStep('confirm');
                    }
                  }}
                  style={{ height: 42, fontWeight: 700 }}
                >
                  Next
                </button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <input
                  type="password"
                  inputMode="numeric"
                  maxLength={4}
                  autoFocus
                  value={confirmPin}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 4);
                    setConfirmPin(val);
                    setErrorMsg('');
                  }}
                  placeholder="••••"
                  style={{
                    fontSize: '1.8rem',
                    textAlign: 'center',
                    letterSpacing: '0.5em',
                    padding: '10px',
                    borderRadius: 12,
                    border: '1px solid rgba(255, 255, 255, 0.15)',
                    background: '#1d1536',
                    color: '#fff',
                    outline: 'none',
                  }}
                />
                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => {
                      setStep('new');
                      setConfirmPin('');
                    }}
                    style={{ flex: 1, height: 42 }}
                  >
                    Back
                  </button>
                  <button
                    type="button"
                    className="btn btn-primary"
                    disabled={confirmPin.length !== 4}
                    onClick={handleSaveNewPin}
                    style={{ flex: 1, height: 42, fontWeight: 700 }}
                  >
                    Enable PIN
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
