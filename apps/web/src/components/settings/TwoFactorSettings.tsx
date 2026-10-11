import React, { useState, useEffect } from 'react';
import { ShieldCheck, ShieldAlert, KeyRound, Copy, Check, Download, AlertTriangle, RefreshCw, Smartphone, QrCode } from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import { useAuth } from '../../context/AuthContext';
import { generateBase32Secret, generateBackupCodes, getOtpAuthUrl } from '../../services/totp';
import { SettingsToast, type SettingsNotice } from './SettingsToast';

export const TwoFactorSettings: React.FC = () => {
  const { user, setUser } = useAuth();
  const [isEnabled, setIsEnabled] = useState(Boolean(user?.twoFactorEnabled));
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  // Wizard state
  const [isWizardOpen, setIsWizardOpen] = useState(false);
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [secret, setSecret] = useState('');
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState('');
  const [verificationCode, setVerificationCode] = useState('');
  const [generatedCodes, setGeneratedCodes] = useState<string[]>([]);
  const [copiedSecret, setCopiedSecret] = useState(false);
  const [copiedCodes, setCopiedCodes] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Disable modal state
  const [isDisableOpen, setIsDisableOpen] = useState(false);
  const [disablePassword, setDisablePassword] = useState('');

  const hasPassword = Boolean(user?.hasPassword);

  useEffect(() => {
    const socket = getSocket();

    const handleStatus = (payload: { enabled?: boolean; backupCodesCount?: number; backupCodes?: string[] }) => {
      setIsSubmitting(false);
      const active = Boolean(payload?.enabled);
      setIsEnabled(active);
      if (Array.isArray(payload?.backupCodes)) {
        setBackupCodes(payload.backupCodes);
      }
      if (setUser) {
        setUser((prev) => (prev ? { ...prev, twoFactorEnabled: active } : prev));
      }
    };

    const handleError = (payload: { message?: string }) => {
      setIsSubmitting(false);
      triggerHaptic('heavy');
      setNotice({
        text: payload?.message || 'Action failed. Please try again.',
        error: true,
      });
    };

    socket.on('2fa_status', handleStatus);
    socket.on('2fa_error', handleError);

    socket.emit('get_2fa_status');

    return () => {
      socket.off('2fa_status', handleStatus);
      socket.off('2fa_error', handleError);
    };
  }, [setUser]);

  const startSetupWizard = async () => {
    const newSecret = generateBase32Secret(20);
    const newBackupCodes = generateBackupCodes(8);
    setSecret(newSecret);
    setGeneratedCodes(newBackupCodes);
    setStep(1);
    setVerificationCode('');
    setIsWizardOpen(true);
    triggerHaptic('light');

    const otpUrl = getOtpAuthUrl(user?.username || 'User', newSecret);
    try {
      const qrcodeModule = await import('qrcode');
      const url = await qrcodeModule.toDataURL(otpUrl, {
        width: 260,
        margin: 2,
        errorCorrectionLevel: 'M',
        color: { dark: '#000000', light: '#ffffff' },
      });
      setQrCodeDataUrl(url);
    } catch (_) {
      setQrCodeDataUrl('');
    }
  };

  const handleCopySecret = async () => {
    if (!secret) return;
    try {
      await navigator.clipboard.writeText(secret);
      setCopiedSecret(true);
      triggerHaptic('light');
      setTimeout(() => setCopiedSecret(false), 2000);
    } catch (_) {}
  };

  const handleCopyCodes = async () => {
    const list = generatedCodes.length > 0 ? generatedCodes : backupCodes;
    if (list.length === 0) return;
    try {
      await navigator.clipboard.writeText(list.join('\n'));
      setCopiedCodes(true);
      triggerHaptic('light');
      setTimeout(() => setCopiedCodes(false), 2000);
    } catch (_) {}
  };

  const handleDownloadCodes = () => {
    const list = generatedCodes.length > 0 ? generatedCodes : backupCodes;
    if (list.length === 0) return;
    const content = `Novyn Two-Factor Authentication Recovery Codes\nAccount: @${user?.username || 'user'}\nGenerated: ${new Date().toLocaleString()}\n\nKeep these codes in a safe place. Each code can be used once.\n\n${list.join('\n')}\n`;
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `novyn-2fa-backup-codes-${user?.username || 'user'}.txt`;
    a.click();
    URL.revokeObjectURL(url);
    triggerHaptic('success');
  };

  const handleVerifyCode = (e: React.FormEvent) => {
    e.preventDefault();
    const cleanCode = verificationCode.trim().replace(/\s+/g, '');
    if (cleanCode.length !== 6) {
      setNotice({ text: 'Please enter a 6-digit verification code.', error: true });
      return;
    }

    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Disconnected from server. Please reconnect.', error: true });
      return;
    }

    setIsSubmitting(true);
    setNotice(null);
    triggerHaptic('medium');

    socket.emit('enable_2fa', {
      secret,
      code: cleanCode,
      backupCodes: generatedCodes,
    });

    // Advance to step 3 on success
    const handleOnce = (payload: { enabled?: boolean }) => {
      if (payload?.enabled) {
        setStep(3);
        triggerHaptic('success');
        setNotice({ text: 'Two-factor authentication successfully enabled!', error: false });
      }
      socket.off('2fa_status', handleOnce);
    };
    socket.once('2fa_status', handleOnce);
  };

  const handleDisable2FA = (e: React.FormEvent) => {
    e.preventDefault();
    if (hasPassword && !disablePassword) {
      setNotice({ text: 'Please enter your password to disable 2FA.', error: true });
      return;
    }

    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Disconnected from server. Please reconnect.', error: true });
      return;
    }

    setIsSubmitting(true);
    setNotice(null);
    triggerHaptic('medium');

    socket.emit('disable_2fa', {
      currentPassword: disablePassword,
    });

    const handleOnce = (payload: { enabled?: boolean }) => {
      if (!payload?.enabled) {
        setIsDisableOpen(false);
        setDisablePassword('');
        triggerHaptic('success');
        setNotice({ text: 'Two-factor authentication disabled.', error: false });
      }
      socket.off('2fa_status', handleOnce);
    };
    socket.once('2fa_status', handleOnce);
  };

  return (
    <>
      <div className="web-settings-card" style={{ maxWidth: 640 }}>
        {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

        {/* Header Icon + Title */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 14,
              background: isEnabled ? 'rgba(16, 185, 129, 0.15)' : 'rgba(124, 58, 237, 0.15)',
              border: `1px solid ${isEnabled ? 'rgba(16, 185, 129, 0.3)' : 'rgba(167, 139, 250, 0.25)'}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: isEnabled ? '#10b981' : '#a78bfa',
            }}
          >
            {isEnabled ? <ShieldCheck size={22} /> : <Smartphone size={22} />}
          </div>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.15rem' }}>Two-Factor Authentication (2FA)</h3>
            <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
              Add an extra layer of security using an authenticator app (Google Authenticator, Authy, Apple Passwords).
            </p>
          </div>
        </div>

        {/* Status Card */}
        <div
          style={{
            padding: '16px 20px',
            borderRadius: 16,
            background: isEnabled ? 'rgba(16, 185, 129, 0.08)' : 'rgba(255, 255, 255, 0.03)',
            border: `1px solid ${isEnabled ? 'rgba(16, 185, 129, 0.25)' : 'rgba(255, 255, 255, 0.07)'}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 24,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            {isEnabled ? <ShieldCheck size={28} color="#10b981" /> : <ShieldAlert size={28} color="#94a3b8" />}
            <div>
              <strong style={{ fontSize: '1rem', color: isEnabled ? '#10b981' : '#fff' }}>
                {isEnabled ? 'Two-Factor Authentication is Enabled' : '2FA is Not Configured'}
              </strong>
              <p style={{ margin: '2px 0 0', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                {isEnabled
                  ? 'Your account requires a 6-digit TOTP code on new device sign-ins.'
                  : 'Protect your account against credential theft with a TOTP authenticator.'}
              </p>
            </div>
          </div>
          <span
            style={{
              padding: '6px 12px',
              borderRadius: 20,
              fontSize: '0.78rem',
              fontWeight: 600,
              background: isEnabled ? 'rgba(16, 185, 129, 0.15)' : 'rgba(255, 255, 255, 0.08)',
              color: isEnabled ? '#10b981' : 'var(--text-muted)',
              border: `1px solid ${isEnabled ? 'rgba(16, 185, 129, 0.3)' : 'rgba(255, 255, 255, 0.1)'}`,
            }}
          >
            {isEnabled ? 'Active' : 'Disabled'}
          </span>
        </div>

        {/* Actions depending on state */}
        {!isEnabled ? (
          <div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 20 }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                <QrCode size={18} color="#a78bfa" style={{ marginTop: 2, flexShrink: 0 }} />
                <span style={{ fontSize: '0.84rem', color: 'var(--text-main)' }}>
                  Compatible with Google Authenticator, Microsoft Authenticator, Authy, Apple Keychain, and 1Password.
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                <KeyRound size={18} color="#a78bfa" style={{ marginTop: 2, flexShrink: 0 }} />
                <span style={{ fontSize: '0.84rem', color: 'var(--text-main)' }}>
                  Includes 8 offline backup recovery codes in case you ever lose access to your authenticator device.
                </span>
              </div>
            </div>

            <button
              type="button"
              className="btn btn-primary"
              onClick={startSetupWizard}
              style={{
                width: '100%',
                padding: 13,
                borderRadius: 12,
                fontWeight: 600,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
              }}
            >
              <Smartphone size={18} /> Setup Two-Factor Authentication
            </button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* Backup Codes Display */}
            {backupCodes.length > 0 && (
              <div
                style={{
                  padding: 16,
                  borderRadius: 14,
                  background: 'rgba(0, 0, 0, 0.25)',
                  border: '1px solid rgba(255, 255, 255, 0.08)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#fff' }}>Backup Recovery Codes</span>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleCopyCodes}
                      style={{ padding: '6px 10px', fontSize: '0.78rem', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 4 }}
                    >
                      {copiedCodes ? <Check size={12} /> : <Copy size={12} />} {copiedCodes ? 'Copied' : 'Copy'}
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleDownloadCodes}
                      style={{ padding: '6px 10px', fontSize: '0.78rem', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 4 }}
                    >
                      <Download size={12} /> Download
                    </button>
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
                  {backupCodes.map((code, idx) => (
                    <div
                      key={idx}
                      style={{
                        padding: '6px 10px',
                        borderRadius: 6,
                        background: 'rgba(255, 255, 255, 0.03)',
                        fontFamily: 'monospace',
                        fontSize: '0.85rem',
                        color: 'var(--text-main)',
                        textAlign: 'center',
                        letterSpacing: '0.5px',
                      }}
                    >
                      {code}
                    </div>
                  ))}
                </div>
              </div>
            )}

            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setIsDisableOpen(true)}
              style={{
                padding: 12,
                borderRadius: 12,
                borderColor: 'rgba(239, 68, 68, 0.4)',
                color: '#ef4444',
                fontWeight: 600,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
              }}
            >
              <AlertTriangle size={16} /> Disable Two-Factor Authentication
            </button>
          </div>
        )}
      </div>

      {/* 2FA Setup Wizard Modal */}
      {isWizardOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 9999,
            background: 'rgba(0, 0, 0, 0.75)',
            backdropFilter: 'blur(8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 16,
          }}
        >
          <div
            style={{
              background: '#130e24',
              border: '1px solid rgba(255, 255, 255, 0.12)',
              borderRadius: 20,
              padding: 28,
              maxWidth: 480,
              width: '100%',
              boxShadow: '0 20px 50px rgba(0, 0, 0, 0.6)',
              boxSizing: 'border-box',
            }}
          >
            {/* Step progress pills */}
            <div style={{ display: 'flex', gap: 6, marginBottom: 20 }}>
              {[1, 2, 3].map((s) => (
                <div
                  key={s}
                  style={{
                    flex: 1,
                    height: 4,
                    borderRadius: 2,
                    background: s <= step ? 'var(--chat-indigo, #6366f1)' : 'rgba(255, 255, 255, 0.1)',
                    transition: 'background 0.3s',
                  }}
                />
              ))}
            </div>

            {step === 1 && (
              <div>
                <h3 style={{ margin: '0 0 6px', fontSize: '1.2rem' }}>Scan QR Code</h3>
                <p style={{ margin: '0 0 18px', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
                  Open your authenticator app and scan this QR code or enter the secret manually.
                </p>

                {/* QR Code */}
                <div
                  style={{
                    background: '#fff',
                    padding: 14,
                    borderRadius: 16,
                    width: 'fit-content',
                    margin: '0 auto 16px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  {qrCodeDataUrl ? (
                    <img src={qrCodeDataUrl} alt="2FA QR Code" width={220} height={220} />
                  ) : (
                    <div style={{ width: 220, height: 220, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#000' }}>
                      Generating QR…
                    </div>
                  )}
                </div>

                {/* Secret Key with Copy */}
                <div
                  style={{
                    padding: '10px 14px',
                    borderRadius: 12,
                    background: 'rgba(255, 255, 255, 0.04)',
                    border: '1px solid rgba(255, 255, 255, 0.08)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    marginBottom: 20,
                  }}
                >
                  <span style={{ fontFamily: 'monospace', fontSize: '0.85rem', color: '#a78bfa', letterSpacing: '1px' }}>
                    {secret}
                  </span>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={handleCopySecret}
                    style={{ padding: '6px 12px', fontSize: '0.78rem', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 4 }}
                  >
                    {copiedSecret ? <Check size={12} /> : <Copy size={12} />} {copiedSecret ? 'Copied' : 'Copy'}
                  </button>
                </div>

                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => setIsWizardOpen(false)}
                    style={{ flex: 1, padding: 12, borderRadius: 12 }}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="btn btn-primary"
                    onClick={() => {
                      setStep(2);
                      triggerHaptic('light');
                    }}
                    style={{ flex: 2, padding: 12, borderRadius: 12, fontWeight: 600 }}
                  >
                    Continue to Verify
                  </button>
                </div>
              </div>
            )}

            {step === 2 && (
              <form onSubmit={handleVerifyCode}>
                <h3 style={{ margin: '0 0 6px', fontSize: '1.2rem' }}>Enter 6-Digit Code</h3>
                <p style={{ margin: '0 0 20px', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
                  Enter the 6-digit verification code currently shown in your authenticator app.
                </p>

                <div style={{ marginBottom: 24 }}>
                  <input
                    type="text"
                    inputMode="numeric"
                    autoFocus
                    maxLength={6}
                    value={verificationCode}
                    onChange={(e) => setVerificationCode(e.target.value.replace(/\D/g, ''))}
                    placeholder="000000"
                    style={{
                      width: '100%',
                      boxSizing: 'border-box',
                      padding: 14,
                      borderRadius: 14,
                      background: 'rgba(0, 0, 0, 0.35)',
                      border: '1px solid rgba(255, 255, 255, 0.15)',
                      color: '#fff',
                      fontSize: '1.6rem',
                      fontFamily: 'monospace',
                      textAlign: 'center',
                      letterSpacing: '8px',
                      outline: 'none',
                    }}
                  />
                </div>

                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    disabled={isSubmitting}
                    onClick={() => setStep(1)}
                    style={{ flex: 1, padding: 12, borderRadius: 12 }}
                  >
                    Back
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={isSubmitting || verificationCode.length !== 6}
                    style={{ flex: 2, padding: 12, borderRadius: 12, fontWeight: 600 }}
                  >
                    {isSubmitting ? 'Verifying…' : 'Verify & Enable'}
                  </button>
                </div>
              </form>
            )}

            {step === 3 && (
              <div>
                <div style={{ textAlign: 'center', marginBottom: 16 }}>
                  <div
                    style={{
                      width: 50,
                      height: 50,
                      borderRadius: '50%',
                      background: 'rgba(16, 185, 129, 0.15)',
                      border: '1px solid rgba(16, 185, 129, 0.3)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#10b981',
                      margin: '0 auto 10px',
                    }}
                  >
                    <Check size={26} />
                  </div>
                  <h3 style={{ margin: '0 0 4px', fontSize: '1.2rem' }}>Save Recovery Codes</h3>
                  <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.82rem' }}>
                    Store these emergency one-time recovery codes in a safe place.
                  </p>
                </div>

                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(2, 1fr)',
                    gap: 8,
                    padding: 14,
                    borderRadius: 12,
                    background: 'rgba(0, 0, 0, 0.3)',
                    border: '1px solid rgba(255, 255, 255, 0.08)',
                    marginBottom: 16,
                  }}
                >
                  {generatedCodes.map((code, idx) => (
                    <div
                      key={idx}
                      style={{
                        padding: '6px 10px',
                        borderRadius: 6,
                        background: 'rgba(255, 255, 255, 0.04)',
                        fontFamily: 'monospace',
                        fontSize: '0.85rem',
                        color: 'var(--text-main)',
                        textAlign: 'center',
                      }}
                    >
                      {code}
                    </div>
                  ))}
                </div>

                <div style={{ display: 'flex', gap: 10, marginBottom: 16 }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={handleCopyCodes}
                    style={{ flex: 1, padding: 10, borderRadius: 10, fontSize: '0.82rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                  >
                    {copiedCodes ? <Check size={14} /> : <Copy size={14} />} {copiedCodes ? 'Copied' : 'Copy All'}
                  </button>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={handleDownloadCodes}
                    style={{ flex: 1, padding: 10, borderRadius: 10, fontSize: '0.82rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                  >
                    <Download size={14} /> Download .txt
                  </button>
                </div>

                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() => setIsWizardOpen(false)}
                  style={{ width: '100%', padding: 12, borderRadius: 12, fontWeight: 600 }}
                >
                  Done
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Disable 2FA Modal */}
      {isDisableOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 9999,
            background: 'rgba(0, 0, 0, 0.75)',
            backdropFilter: 'blur(8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 16,
          }}
        >
          <form
            onSubmit={handleDisable2FA}
            style={{
              background: '#130e24',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              borderRadius: 20,
              padding: 24,
              maxWidth: 420,
              width: '100%',
              boxShadow: '0 20px 50px rgba(0, 0, 0, 0.6)',
              boxSizing: 'border-box',
            }}
          >
            <h3 style={{ margin: '0 0 8px', fontSize: '1.15rem', color: '#ef4444' }}>
              Disable Two-Factor Authentication?
            </h3>
            <p style={{ margin: '0 0 16px', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
              Disabling 2FA makes your account significantly more vulnerable to unauthorized sign-in attempts.
            </p>

            {hasPassword && (
              <div style={{ marginBottom: 20 }}>
                <label style={{ display: 'block', fontSize: '0.82rem', marginBottom: 6, color: 'var(--text-main)' }}>
                  Confirm with Account Password
                </label>
                <input
                  type="password"
                  value={disablePassword}
                  onChange={(e) => setDisablePassword(e.target.value)}
                  placeholder="Enter current password"
                  style={{
                    width: '100%',
                    boxSizing: 'border-box',
                    padding: 12,
                    borderRadius: 12,
                    background: 'rgba(0, 0, 0, 0.25)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    color: '#fff',
                    outline: 'none',
                  }}
                />
              </div>
            )}

            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="btn btn-secondary"
                disabled={isSubmitting}
                onClick={() => setIsDisableOpen(false)}
                style={{ flex: 1, padding: 12, borderRadius: 12 }}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="btn btn-secondary"
                disabled={isSubmitting || (hasPassword && !disablePassword)}
                style={{
                  flex: 1,
                  padding: 12,
                  borderRadius: 12,
                  borderColor: 'rgba(239, 68, 68, 0.5)',
                  background: 'rgba(239, 68, 68, 0.15)',
                  color: '#ef4444',
                  fontWeight: 600,
                }}
              >
                {isSubmitting ? 'Disabling…' : 'Disable 2FA'}
              </button>
            </div>
          </form>
        </div>
      )}
    </>
  );
};
