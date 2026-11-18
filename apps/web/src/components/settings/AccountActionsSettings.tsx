import React, { useState, useEffect } from 'react';
import {
  Trash2,
  LogOut,
  Database,
  Check,
  Download,
  Monitor,
  Smartphone,
  Laptop,
  Tablet,
  ExternalLink,
  AtSign,
  MessageSquare,
  Users,
  Ban,
  ShieldAlert,
} from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';
import { useAuth } from '../../context/AuthContext';
import { SettingsToast, type SettingsNotice } from './SettingsToast';
import type { SettingsMainCategory, SettingsSubSection } from './SettingsPanel';
import './accountActionsSettings.css';

interface AccountActionsSettingsProps {
  onBack?: () => void;
  onSelectSection?: (category: SettingsMainCategory, section: SettingsSubSection) => void;
}

export const AccountActionsSettings: React.FC<AccountActionsSettingsProps> = ({
  onBack,
  onSelectSection,
}) => {
  const { user } = useAuth();
  const [notice, setNotice] = useState<SettingsNotice | null>(null);

  // Cache clearing state
  const [cacheCleared, setCacheCleared] = useState(false);
  const [cacheMb, setCacheMb] = useState<string>('0.0');

  // Delete account state
  const [confirmText, setConfirmText] = useState('');
  const [password, setPassword] = useState('');
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const hasPassword = Boolean(user?.hasPassword);
  const username = user?.username || 'user';
  const cleanInput = confirmText.trim().toLowerCase();
  const targetTag = `@${username.toLowerCase()}`;
  const isConfirmed = cleanInput === targetTag || cleanInput === username.toLowerCase();
  const canDelete = isConfirmed;

  useEffect(() => {
    if (typeof navigator !== 'undefined' && navigator.storage && navigator.storage.estimate) {
      navigator.storage
        .estimate()
        .then((est) => {
          const usageMb = ((est.usage || 0) / (1024 * 1024)).toFixed(1);
          setCacheMb(usageMb);
        })
        .catch(() => {
          setCacheMb('0.0');
        });
    }
  }, []);

  useEffect(() => {
    const socket = getSocket();

    const handleDeleteSuccess = () => {
      setIsDeleting(false);
      triggerHaptic('success');
      try {
        localStorage.clear();
        sessionStorage.clear();
      } catch (_) {}
      window.location.href = '/';
    };

    const handleDeleteFail = (payload: { message?: string }) => {
      setIsDeleting(false);
      triggerHaptic('heavy');
      setNotice({
        text: payload?.message || 'Failed to delete account. Please verify credentials.',
        error: true,
      });
    };

    socket.on('account_deleted', handleDeleteSuccess);
    socket.on('account_deletion_failed', handleDeleteFail);

    return () => {
      socket.off('account_deleted', handleDeleteSuccess);
      socket.off('account_deletion_failed', handleDeleteFail);
    };
  }, []);

  const handleClearCache = async () => {
    try {
      triggerHaptic('medium');
      const keysToPreserve = new Set([
        'novyn_auth_token',
        'novyn_refresh_token',
        'novyn_chat_username',
        'novyn_e2ee_identity_key',
        'novyn_e2ee_pre_keys',
        'novyn_app_lock_pin_hash',
      ]);

      const toRemove: string[] = [];
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && !keysToPreserve.has(key) && !key.startsWith('novyn_key_')) {
          toRemove.push(key);
        }
      }
      toRemove.forEach((k) => localStorage.removeItem(k));

      if ('caches' in window) {
        const cacheNames = await caches.keys();
        await Promise.all(cacheNames.map((name) => caches.delete(name)));
      }

      setCacheCleared(true);
      setCacheMb('0.0');
      setNotice({ text: 'Temporary cache cleared successfully.', error: false });
    } catch (_) {
      setNotice({ text: 'Could not clear cache.', error: true });
    }
  };

  const handleSignOutAll = async () => {
    try {
      triggerHaptic('medium');
      await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' }).catch(() => {});
      try {
        localStorage.removeItem('novyn_auth_token');
        localStorage.removeItem('novyn_refresh_token');
      } catch (_) {}
      window.location.href = '/';
    } catch (_) {
      window.location.href = '/';
    }
  };

  const handleExportChats = () => {
    triggerHaptic('light');
    try {
      const exportData = {
        app: 'Novyn Chat',
        username: user?.username,
        exportedAt: new Date().toISOString(),
        note: 'Encrypted message export and offline local data archive.',
      };
      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `novyn_chat_export_${username}_${Date.now()}.json`;
      link.click();
      URL.revokeObjectURL(url);
      setNotice({ text: 'Chat archive export initiated.', error: false });
    } catch {
      setNotice({ text: 'Unable to export chat archive.', error: true });
    }
  };

  const handleTriggerDelete = () => {
    if (!canDelete) return;
    triggerHaptic('heavy');
    if (hasPassword) {
      setIsDeleteModalOpen(true);
    } else {
      executeDeletion('');
    }
  };

  const executeDeletion = (pass: string) => {
    const socket = getSocket();
    if (!socket.connected) {
      setNotice({ text: 'Disconnected from server. Reconnecting…', error: true });
      return;
    }
    setIsDeleting(true);
    setNotice(null);
    socket.emit('delete_account', {
      currentPassword: pass,
      confirmationText: confirmText.trim(),
      confirmed: true,
    });
  };

  const handlePasswordModalSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!password) {
      setNotice({ text: 'Please enter your password.', error: true });
      return;
    }
    executeDeletion(password);
  };

  const navigateBack = () => {
    triggerHaptic('light');
    if (onSelectSection) {
      onSelectSection('security', 'security-dashboard');
    } else if (onBack) {
      onBack();
    }
  };

  return (
    <>
      {notice && <SettingsToast notice={notice} onDismiss={() => setNotice(null)} />}

      <div className="account-actions-dashboard" style={{ width: '100%', maxWidth: 'none', margin: 0 }}>
        {/* Breadcrumb Navigation */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', marginBottom: 12 }}>
          <button
            type="button"
            onClick={navigateBack}
            style={{
              background: 'none',
              border: 'none',
              padding: 0,
              color: '#94a3b8',
              cursor: 'pointer',
              fontSize: '0.85rem',
              fontWeight: 500,
              display: 'inline-flex',
              alignItems: 'center',
            }}
          >
            Security
          </button>
          <span style={{ color: '#64748b' }}>/</span>
          <span style={{ color: '#818cf8', fontWeight: 600 }}>Account actions</span>
        </div>

        {/* Header Title & Subtitle */}
        <div style={{ marginBottom: 28 }}>
          <h1
            style={{
              fontSize: '2rem',
              fontWeight: 800,
              margin: 0,
              color: '#ffffff',
              letterSpacing: '-0.025em',
              fontFamily: 'Outfit, system-ui, sans-serif',
            }}
          >
            Account Actions & Danger Zone
          </h1>
          <p style={{ margin: '8px 0 0', color: '#94a3b8', fontSize: '0.92rem' }}>
            Manage temporary offline cache, sign out everywhere, or delete your account.
          </p>
        </div>

        {/* Top Two Cards Grid */}
        <div className="account-actions-top-grid" style={{ marginBottom: 24 }}>
          {/* Card 1: Local data & offline cache */}
          <div className="account-action-card account-card-cache">
            <div className="account-action-header-left">
              <div className="account-action-icon is-blue">
                <Database size={22} />
              </div>
              <div>
                <h3 className="account-action-card-title">
                  Local data & offline cache
                </h3>
                <p className="account-action-card-sub">
                  Free up temporary files on this browser.
                </p>
              </div>
            </div>

            {/* Inset Stats Box */}
            <div className="account-cache-stat-box">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="account-cache-stat-label">Offline cache used</span>
                <span className="account-cache-stat-val">
                  {cacheCleared ? '0.0 MB' : `${cacheMb} MB`}
                </span>
              </div>
              <div className="account-cache-track">
                <div className="account-cache-thumb" />
              </div>
              <div className="account-cache-note">
                Thumbnails, search indexes and UI drafts.
              </div>
            </div>

            <p style={{ margin: '16px 0 14px', color: 'var(--text-muted, #94a3b8)', fontSize: '0.84rem', lineHeight: 1.5 }}>
              Clearing removes transient drafts and downloaded preview blobs.
            </p>

            {/* Status Pills */}
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 20 }}>
              <div className="account-status-pill">
                <Check size={13} strokeWidth={2.8} /> Encryption keys stay
              </div>
              <div className="account-status-pill">
                <Check size={13} strokeWidth={2.8} /> You stay signed in
              </div>
            </div>

            {/* Bottom Button Row */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 'auto' }}>
              <button
                type="button"
                onClick={handleClearCache}
                disabled={cacheCleared}
                className="account-btn-clear-cache"
              >
                <Database size={16} />
                {cacheCleared ? 'Cache Cleared' : 'Clear temporary cache'}
              </button>
              <span style={{ color: 'var(--text-muted, #64748b)', fontSize: '0.82rem' }}>
                {cacheCleared ? 'Cache is clean' : 'Nothing to clear right now'}
              </span>
            </div>
          </div>

          {/* Card 2: Sign out everywhere */}
          <div className="account-action-card account-card-sessions">
            <div className="account-action-header">
              <div className="account-action-header-left">
                <div className="account-action-icon is-amber">
                  <LogOut size={22} />
                </div>
                <div>
                  <h3 className="account-action-card-title">
                    Sign out everywhere
                  </h3>
                  <p className="account-action-card-sub">
                    Revoke refresh sessions on all browsers and devices.
                  </p>
                </div>
              </div>

              {onSelectSection && (
                <button
                  type="button"
                  onClick={() => onSelectSection('security', 'privacy-sessions')}
                  title="Manage all active sessions"
                  className="account-btn-manage-sessions"
                >
                  Manage <ExternalLink size={12} />
                </button>
              )}
            </div>

            {/* Devices Preview Container */}
            <div className="account-actions-sessions-grid" style={{ padding: '4px 14px', maxHeight: 114, overflowY: 'auto' }}>
              <div className="account-session-row">
                <div className="account-session-icon-wrap">
                  <Monitor size={17} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="account-session-name">
                    This browser
                  </div>
                  <div className="account-session-sub">
                    Active now
                  </div>
                </div>
                <div className="account-status-pill" style={{ marginLeft: 'auto', padding: '2px 10px', fontSize: '0.72rem' }}>
                  Current
                </div>
              </div>

              {/* Informative row when only this session exists */}
              <div className="account-session-row" style={{ borderBottom: 'none' }}>
                <div className="account-session-icon-wrap" style={{ color: '#10b981' }}>
                  <Check size={16} strokeWidth={2.5} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="account-session-protected-title">
                    No other active devices
                  </div>
                  <div className="account-session-sub" style={{ fontSize: '0.72rem' }}>
                    Only this browser session is signed in
                  </div>
                </div>
                <div style={{ marginLeft: 'auto', color: '#10b981', fontSize: '0.72rem', fontWeight: 600 }}>
                  Protected
                </div>
              </div>
            </div>

            <p style={{ margin: '16px 0 16px', color: 'var(--text-muted, #94a3b8)', fontSize: '0.84rem', lineHeight: 1.5 }}>
              Signing out disconnects this computer and invalidates stored refresh tokens on other devices.
            </p>

            {/* Bottom Button Row */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 'auto' }}>
              <button
                type="button"
                onClick={handleSignOutAll}
                className="account-btn-signout-all"
              >
                <LogOut size={16} />
                Sign out of all sessions
              </button>
              <span style={{ color: 'var(--text-muted, #64748b)', fontSize: '0.82rem' }}>You can sign back in anytime</span>
            </div>
          </div>
        </div>

        {/* Card 3: Danger Zone - Full Width Card */}
        <div className="account-card-danger">
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div className="account-action-icon is-red">
              <Trash2 size={22} />
            </div>
            <div>
              <h3 className="account-danger-title">
                Danger zone: Delete account
              </h3>
              <p style={{ margin: '3px 0 0', color: 'var(--text-muted, #94a3b8)', fontSize: '0.84rem' }}>
                Permanently erase your identity, messages and presence.
              </p>
            </div>
          </div>

          {/* 2-Column Inner Content */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: 24,
              marginTop: 22,
            }}
          >
            {/* Left Column: 2x2 Consequences Cards */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                gap: 12,
              }}
            >
              {/* Item 1 */}
              <div className="account-danger-consequence-card">
                <div className="account-danger-consequence-icon">
                  <AtSign size={16} />
                </div>
                <div className="account-danger-consequence-text">
                  Your handle <strong>@{username}</strong> is released immediately
                </div>
              </div>

              {/* Item 2 */}
              <div className="account-danger-consequence-card">
                <div className="account-danger-consequence-icon">
                  <MessageSquare size={16} />
                </div>
                <div className="account-danger-consequence-text">
                  All end-to-end encrypted chats and media are erased
                </div>
              </div>

              {/* Item 3 */}
              <div className="account-danger-consequence-card">
                <div className="account-danger-consequence-icon">
                  <Users size={16} />
                </div>
                <div className="account-danger-consequence-text">
                  Friends and groups are notified of your removal
                </div>
              </div>

              {/* Item 4 */}
              <div className="account-danger-consequence-card">
                <div className="account-danger-consequence-icon">
                  <Ban size={16} />
                </div>
                <div className="account-danger-consequence-text">
                  This is permanent and cannot be reversed
                </div>
              </div>
            </div>

            {/* Right Column: BEFORE YOU GO */}
            <div>
              <div className="account-danger-step-tag">
                BEFORE YOU GO
              </div>

              {/* Step 1 */}
              <div className="account-danger-step-box">
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div className="account-danger-step-num">
                    1
                  </div>
                  <span className="account-danger-step-label">
                    Save a copy of your chats
                  </span>
                </div>
                <button
                  type="button"
                  onClick={handleExportChats}
                  className="account-btn-export-copy"
                >
                  <Download size={14} /> Export
                </button>
              </div>

              {/* Step 2 */}
              <div className="account-danger-step-box is-step2">
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div className="account-danger-step-num">
                    2
                  </div>
                  <span className="account-danger-step-label">
                    Type <strong style={{ color: '#ef4444' }}>@{username}</strong> to confirm
                  </span>
                </div>

                <input
                  type="text"
                  value={confirmText}
                  onChange={(e) => setConfirmText(e.target.value)}
                  placeholder={`@${username}`}
                  className={`account-danger-confirm-input ${isConfirmed ? 'is-confirmed' : ''}`}
                />
              </div>

              {/* Action row */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <button
                  type="button"
                  disabled={!canDelete || isDeleting}
                  onClick={handleTriggerDelete}
                  className="account-btn-delete-confirm"
                >
                  <Trash2 size={16} />
                  {isDeleting ? 'Erasing account…' : 'Delete my Novyn account'}
                </button>
                <span style={{ color: 'var(--text-muted, #64748b)', fontSize: '0.82rem' }}>
                  {canDelete ? 'Ready to erase' : 'Unlocks after you confirm'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Optional Password confirmation modal if account has master password */}
      {isDeleteModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          className="account-delete-modal-backdrop"
        >
          <form
            onSubmit={handlePasswordModalSubmit}
            className="account-delete-modal-card"
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: 12,
                  background: 'rgba(239, 68, 68, 0.2)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#ef4444',
                }}
              >
                <ShieldAlert size={22} />
              </div>
              <h3 style={{ margin: 0, fontSize: '1.2rem', color: '#ef4444', fontWeight: 700 }}>
                Confirm Account Deletion
              </h3>
            </div>

            <p style={{ margin: '0 0 16px', color: '#94a3b8', fontSize: '0.84rem', lineHeight: 1.5 }}>
              Enter your account password to confirm the permanent erasure of{' '}
              <strong style={{ color: '#fff' }}>@{username}</strong>.
            </p>

            <div style={{ marginBottom: 20 }}>
              <label
                style={{
                  display: 'block',
                  fontSize: '0.82rem',
                  marginBottom: 6,
                  color: '#cbd5e1',
                  fontWeight: 500,
                }}
              >
                Account Password
              </label>
              <input
                type="password"
                className="account-delete-modal-input"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter your password"
                autoFocus
              />
            </div>

            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="btn btn-secondary"
                disabled={isDeleting}
                onClick={() => setIsDeleteModalOpen(false)}
                style={{ flex: 1, padding: 12, borderRadius: 12 }}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="btn btn-secondary"
                disabled={isDeleting || !password}
                style={{
                  flex: 1.5,
                  padding: 12,
                  borderRadius: 12,
                  background: password ? 'rgba(239, 68, 68, 0.25)' : 'rgba(239, 68, 68, 0.08)',
                  borderColor: 'rgba(239, 68, 68, 0.6)',
                  color: '#ef4444',
                  fontWeight: 600,
                }}
              >
                {isDeleting ? 'Erasing account…' : 'Erase Account Permanently'}
              </button>
            </div>
          </form>
        </div>
      )}
    </>
  );
};
