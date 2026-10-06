import React, { useState, useEffect, useRef } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import {
  User,
  Shield,
  Bell,
  Palette,
  HardDrive,
  Check,
  Lock,
  Eye,
  EyeOff,
  Volume2,
  Smartphone,
  ShieldCheck,
  Trash2,
  Globe,
  Sparkles,
  Ban,
  CheckCircle2,
  Play,
  Square,
  Plus,
  AtSign,
  Mail,
  Download,
  AlertTriangle,
  LogOut,
  RefreshCw,
  QrCode,
  Laptop,
  Upload,
  FileText,
  ChevronLeft,
  MessageSquarePlus,
  Bug,
  Lightbulb,
  Star,
  Send,
  Moon,
  Sun,
} from 'lucide-react';
import { triggerHaptic, isNativeMobile } from '../../services/capacitor';
import { useDockAlwaysVisible, setDockAlwaysVisible } from '../../services/dockPreferences';
import { SettingsSubSection } from './SettingsPanel';
import { getSocket } from '../../services/socket';
import {
  playIncomingRingtone,
  playOutgoingCallRing,
  stopAllCallAudio,
  playMessageNotification,
  playMessageSentSound,
} from '../../services/audioManager';
import {
  applyColorMode,
  applyWallpaper,
  applyFontFamily,
  applyFontSize,
  WALLPAPER_PRESETS,
  FONT_PRESETS,
  PRESET_AVATARS,
} from '../../services/settingsTheme';

interface SettingsDetailViewProps {
  activeSubSection: SettingsSubSection;
  onBack?: () => void;
}

export const SettingsDetailView: React.FC<SettingsDetailViewProps> = ({ activeSubSection, onBack }) => {
  const { user, setUser, logout } = useAuth();
  const { updateProfile, blockedUsers, blockUser, conversations, messages } = useChat();

  // Profile Form
  const [displayName, setDisplayName] = useState(user?.displayName || user?.username || '');
  const [bio, setBio] = useState(user?.bio || 'Hey there! I am using Novyn Chat.');
  const [avatarId, setAvatarId] = useState(user?.avatarId || '');
  const [status, setStatus] = useState<'online' | 'away' | 'busy' | 'invisible'>(
    user?.presenceMode === 'dnd' ? 'busy' : user?.presenceMode === 'offline' ? 'invisible' : user?.presenceMode || 'online'
  );
  const [saved, setSaved] = useState(false);

  // Username Change State
  const [newUsername, setNewUsername] = useState('');
  const [usernameMsg, setUsernameMsg] = useState<{ text: string; ok: boolean } | null>(null);
  const [isChangingUsername, setIsChangingUsername] = useState(false);

  // Notifications State
  const [soundEnabled, setSoundEnabled] = useState(() => localStorage.getItem('novyn_sound') !== 'false');
  const [vibrationEnabled, setVibrationEnabled] = useState(() => localStorage.getItem('novyn_vibration') !== 'false');
  const supportsVibration = isNativeMobile || typeof navigator !== 'undefined' && 'vibrate' in navigator;
  const [previewEnabled, setPreviewEnabled] = useState(() => localStorage.getItem('novyn_preview') !== 'false');
  const [isPlayingRingtone, setIsPlayingRingtone] = useState(false);
  const [isPlayingCallRing, setIsPlayingCallRing] = useState(false);

  const testIncomingRingtone = () => {
    if (isPlayingRingtone) {
      stopAllCallAudio();
      setIsPlayingRingtone(false);
    } else {
      stopAllCallAudio();
      setIsPlayingCallRing(false);
      playIncomingRingtone();
      setIsPlayingRingtone(true);
      setTimeout(() => {
        stopAllCallAudio();
        setIsPlayingRingtone(false);
      }, 5000);
    }
  };

  const testOutgoingCallRing = () => {
    if (isPlayingCallRing) {
      stopAllCallAudio();
      setIsPlayingCallRing(false);
    } else {
      stopAllCallAudio();
      setIsPlayingRingtone(false);
      playOutgoingCallRing();
      setIsPlayingCallRing(true);
      setTimeout(() => {
        stopAllCallAudio();
        setIsPlayingCallRing(false);
      }, 5000);
    }
  };

  // Privacy State
  const [readReceipts, setReadReceipts] = useState(() => localStorage.getItem('novyn_receipts') !== 'false');
  const [retentionDays, setRetentionDays] = useState<7 | 15 | 30>(() => {
    const saved = Number(user?.retentionDays || localStorage.getItem(`novyn_retention_days_${user?.username || 'guest'}`) || 30);
    return saved === 7 || saved === 15 ? saved : 30;
  });
  useEffect(() => {
    const saved = Number(user?.retentionDays || localStorage.getItem(`novyn_retention_days_${user?.username || 'guest'}`) || 30);
    setRetentionDays(saved === 7 || saved === 15 ? saved : 30);
  }, [user?.username, user?.retentionDays]);
  const [newBlockInput, setNewBlockInput] = useState('');

  // Password Change
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrentPw, setShowCurrentPw] = useState(false);
  const [showNewPw, setShowNewPw] = useState(false);
  const [passwordMsg, setPasswordMsg] = useState<{ text: string; ok: boolean } | null>(null);

  const dockAlwaysVisible = useDockAlwaysVisible();
  // Appearance & Themes
  const [colorMode, setColorMode] = useState<'light' | 'dark'>(
    () => localStorage.getItem('novyn_color_mode') === 'dark' ? 'dark' : 'light'
  );
  const [activeWallpaper, setActiveWallpaperState] = useState(() => localStorage.getItem('novyn_wallpaper') || 'midnight');
  const [activeFontFamily, setActiveFontFamilyState] = useState(() => localStorage.getItem('novyn_font_family') || 'plus-jakarta');
  const [activeFontSize, setActiveFontSizeState] = useState<'sm' | 'md' | 'lg'>(
    () => (localStorage.getItem('novyn_font_size') as any) || 'md'
  );

  // Storage State
  const [cacheCleared, setCacheCleared] = useState(false);
  const [exportSuccess, setExportSuccess] = useState(false);

  const userUsernameRef = useRef(user?.username);
  useEffect(() => {
    if (!user) return;
    if (userUsernameRef.current !== user.username) {
      userUsernameRef.current = user.username;
      setDisplayName(user.displayName || user.username || '');
      setBio(user.bio || 'Hey there! I am using Novyn Chat.');
      setAvatarId(user.avatarId || localStorage.getItem(`novyn_avatar_${user.username}`) || '');
      setStatus(user.presenceMode === 'dnd' ? 'busy' : user.presenceMode === 'offline' ? 'invisible' : user.presenceMode || 'online');
    }
  }, [user?.username]);

  const handleSaveProfile = (e: React.FormEvent) => {
    e.preventDefault();
    triggerHaptic('success');

    if (user?.username) {
      localStorage.setItem(`novyn_avatar_${user.username}`, avatarId);
    }

    updateProfile({
      displayName: displayName.trim(),
      bio: bio.trim(),
      status,
      avatarId,
    });

    setSaved(true);
    setTimeout(() => setSaved(false), 1800);
  };

  const handleSelectAvatar = (url: string) => {
    triggerHaptic('light');
    setAvatarId(url);
    if (user?.username) {
      localStorage.setItem(`novyn_avatar_${user.username}`, url);
    }
    updateProfile({
      displayName: displayName.trim() || user?.displayName,
      bio: bio.trim() || user?.bio,
      status,
      avatarId: url,
    });
  };

  const handleUsernameChangeSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const clean = newUsername.trim().toLowerCase();
    if (!clean) return;

    const socket = getSocket();
    if (!socket) {
      setUsernameMsg({ text: 'Socket disconnected. Please refresh.', ok: false });
      return;
    }

    setIsChangingUsername(true);
    triggerHaptic('medium');

    socket.emit('change_username', { newUsername: clean }, (res: any) => {
      setIsChangingUsername(false);
      if (res?.ok) {
        triggerHaptic('success');
        setUsernameMsg({ text: `Username successfully updated to @${clean}!`, ok: true });
        if (setUser) {
          setUser((prev: any) => (prev ? { ...prev, username: clean } : prev));
        }
        setNewUsername('');
      } else {
        triggerHaptic('error');
        setUsernameMsg({ text: res?.message || 'Could not change username', ok: false });
      }
    });
  };

  const handleBlockUserSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const clean = newBlockInput.trim();
    if (!clean) return;
    triggerHaptic('medium');
    blockUser(clean, true);
    setNewBlockInput('');
  };

  const handlePasswordChange = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentPassword) {
      setPasswordMsg({ text: 'Please enter your current password', ok: false });
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordMsg({ text: 'New passwords do not match', ok: false });
      return;
    }
    if (newPassword.length < 6) {
      setPasswordMsg({ text: 'Password must be at least 6 characters', ok: false });
      return;
    }

    triggerHaptic('success');
    setPasswordMsg({ text: 'Password updated successfully!', ok: true });
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setTimeout(() => setPasswordMsg(null), 3500);
  };

  const handleClearCache = () => {
    triggerHaptic('medium');
    try {
      const keysToRemove = Object.keys(localStorage).filter(k => k.startsWith('novyn_cache_') || k.startsWith('tmp_'));
      keysToRemove.forEach(k => localStorage.removeItem(k));
    } catch {}

    setCacheCleared(true);
    setTimeout(() => setCacheCleared(false), 2500);
  };

  const handleExportData = () => {
    triggerHaptic('success');
    const dataToExport = {
      user: {
        username: user?.username,
        displayName: user?.displayName,
        email: user?.email,
        bio: user?.bio,
      },
      conversations: conversations.map(c => ({
        partner: c.username,
        displayName: c.displayName,
        unreadCount: c.unreadCount,
        lastMessage: c.lastMessage,
      })),
      exportDate: new Date().toISOString(),
      app: 'Novyn Chat v1.0.0',
    };

    const jsonString = `data:text/json;charset=utf-8,${encodeURIComponent(JSON.stringify(dataToExport, null, 2))}`;
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute('href', jsonString);
    downloadAnchor.setAttribute('download', `novyn_chat_backup_${user?.username || 'user'}.json`);
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();

    setExportSuccess(true);
    setTimeout(() => setExportSuccess(false), 3000);
  };

  const [importStatus, setImportStatus] = useState<{ text: string; ok: boolean } | null>(null);

  const handleImportFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const content = event.target?.result as string;
        const parsed = JSON.parse(content);

        if (!parsed || (!parsed.conversations && !parsed.user)) {
          triggerHaptic('error');
          setImportStatus({ text: 'Invalid backup file format. Please upload a valid Novyn JSON archive.', ok: false });
          return;
        }

        triggerHaptic('success');
        const count = parsed.conversations?.length || 0;
        setImportStatus({
          text: `Backup successfully verified & restored! Loaded archive with ${count} conversation(s).`,
          ok: true,
        });

        setTimeout(() => setImportStatus(null), 5000);
      } catch (err) {
        triggerHaptic('error');
        setImportStatus({ text: 'Failed to read file. Please ensure it is a valid JSON document.', ok: false });
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  return (
    <div className="settings-detail" style={{ flex: 1, height: '100%', display: 'flex', flexDirection: 'column', minWidth: 0, background: 'var(--bg-app)' }}>
      {/* Header - 64px aligned with Columns 2 and 3 */}
      <div
        className="chat-list-header settings-detail-header"
        style={{
          padding: '0 20px',
          height: '64px',
          display: 'flex',
          alignItems: 'center',
          borderBottom: '1px solid var(--border)',
          background: 'var(--bg-sidebar)',
          flexShrink: 0,
        }}
      >
        {onBack && (
          <button
            type="button"
            onClick={() => {
              triggerHaptic('light');
              onBack();
            }}
            style={{
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
              color: 'var(--text-main)',
              cursor: 'pointer',
              width: '36px',
              height: '36px',
              borderRadius: '10px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginRight: '12px',
              flexShrink: 0,
              transition: 'background 0.15s ease',
            }}
            title="Back to Settings"
          >
            <ChevronLeft style={{ width: '20px', height: '20px' }} />
          </button>
        )}

        <div className="settings-detail-title">
          <span>Account workspace</span>
          <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {activeSubSection === 'profile-details' && 'Profile settings'}
          {activeSubSection === 'profile-username' && 'Change Username (@handle)'}
          {activeSubSection === 'profile-email' && 'Linked Email Address'}
          {activeSubSection === 'profile-presence' && 'Presence Mode & Status'}
          {activeSubSection === 'privacy-blocked' && 'Blocked Contacts & Blacklist'}
          {activeSubSection === 'privacy-password' && 'Change Account Password'}
          {activeSubSection === 'privacy-receipts' && 'Read Receipts & Activity'}
          {activeSubSection === 'privacy-retention' && 'Message Retention'}
          {activeSubSection === 'privacy-sessions' && 'Active Devices & Sessions'}
          {activeSubSection === 'privacy-linked-devices' && 'Linked Devices (Multi-Device Sync)'}
          {activeSubSection === 'privacy-danger' && 'Account Safety & Actions'}
          {activeSubSection === 'notif-sounds' && 'Message Audio Chimes'}
          {activeSubSection === 'notif-calls' && 'Call Ringtones & Synthesizer'}
          {activeSubSection === 'notif-previews' && 'Message Notification Previews'}
          {activeSubSection === 'appear-theme' && 'Primary Theme Accent'}
          {activeSubSection === 'appear-wallpaper' && 'Chat Wallpapers & Backdrop'}
          {activeSubSection === 'appear-font' && 'Typography & Message Sizing'}
          {activeSubSection === 'storage-cache' && 'Storage & Cache Management'}
          {activeSubSection === 'storage-export' && 'Backup & Restore Chat Data'}
          {activeSubSection === 'storage-security' && 'P2P WebRTC & TLS Security'}
          {activeSubSection === 'feedback-send' && 'Share your thoughts'}
          {activeSubSection === 'feedback-bug' && 'Report a problem'}
          {activeSubSection === 'feedback-feature' && 'Suggest something new'}
          </h2>
        </div>
      </div>

      {/* Main Body */}
      <div className="conversations-scroll settings-detail-body" key={activeSubSection} style={{ flex: 1, overflowY: 'auto', padding: '20px 20px 80px', maxWidth: '780px' }}>
        {/* 1. PROFILE DETAILS & PRESET AVATARS */}
        {activeSubSection === 'profile-details' && (
          <form onSubmit={handleSaveProfile} className="profile-editor">
            <div
              className="profile-editor-hero"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '20px',
                padding: '20px 24px',
                borderRadius: '20px',
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.55) 0%, rgba(255, 255, 255, 0.55) 100%)',
                border: '1px solid var(--border)',
                marginBottom: '24px',
                boxShadow: '0 8px 30px rgba(36, 76, 96, 0.1)',
              }}
            >
              <Avatar name={displayName || user?.username || 'You'} avatarUrl={avatarId} size="xl" online={status === 'online'} />
              <div>
                <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                  {displayName || user?.username}
                </h3>
                <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', margin: '2px 0 0' }}>@{user?.username}</p>
                {user?.email && <p style={{ fontSize: '0.78rem', color: 'var(--text-dark)', margin: '3px 0 0' }}>{user.email}</p>}
              </div>
            </div>

            {/* Illustrated Preset Avatars Selector */}
            <div className="profile-editor-avatars" style={{ marginBottom: '22px' }}>
              <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>Choose Illustrated Avatar</label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(58px, 1fr))', gap: '12px' }}>
                {/* Default Initials Option */}
                <div
                  onClick={() => handleSelectAvatar('')}
                  style={{
                    width: '58px',
                    height: '58px',
                    borderRadius: '16px',
                    border: !avatarId ? '2.5px solid var(--border-focus)' : '1px solid var(--border)',
                    background: !avatarId ? 'var(--primary-glow)' : 'rgba(255, 255, 255, 0.55)',
                    cursor: 'pointer',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: !avatarId ? '0 0 14px var(--primary-glow)' : 'none',
                    transition: 'all 0.15s ease',
                    position: 'relative',
                  }}
                  title="Default Initials Avatar"
                >
                  <span style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-main)' }}>
                    {(displayName || user?.username || 'U').charAt(0).toUpperCase()}
                  </span>
                  {!avatarId && (
                    <div style={{ position: 'absolute', top: '2px', right: '2px', width: '14px', height: '14px', borderRadius: '50%', background: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-on-primary)' }}>
                      <Check style={{ width: '10px', height: '10px' }} />
                    </div>
                  )}
                </div>

                {/* Preset Illustrated Avatars */}
                {PRESET_AVATARS.map((url, i) => {
                  const isSelected = avatarId === url;
                  return (
                    <div
                      key={i}
                      onClick={() => handleSelectAvatar(url)}
                      style={{
                        width: '58px',
                        height: '58px',
                        borderRadius: '16px',
                        border: isSelected ? '2.5px solid var(--border-focus)' : '1px solid var(--border)',
                        background: isSelected ? 'var(--primary-glow)' : 'rgba(255, 255, 255, 0.55)',
                        cursor: 'pointer',
                        padding: '4px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: isSelected ? '0 0 14px var(--primary-glow)' : 'none',
                        transition: 'all 0.15s ease',
                        position: 'relative',
                      }}
                    >
                      <img src={url} alt="Avatar" style={{ width: '100%', height: '100%', borderRadius: '12px', objectFit: 'cover' }} />
                      {isSelected && (
                        <div style={{ position: 'absolute', top: '2px', right: '2px', width: '16px', height: '16px', borderRadius: '50%', background: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-on-primary)', boxShadow: '0 0 8px rgba(36, 76, 96, 0.1)' }}>
                          <Check style={{ width: '11px', height: '11px' }} />
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="input-wrapper profile-editor-field" style={{ marginBottom: '20px' }}>
              <label className="input-label">Display Name</label>
              <input
                type="text"
                required
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Your Display Name"
                className="input-field"
                style={{ paddingLeft: '16px', height: '46px', fontSize: '0.9rem' }}
              />
            </div>

            <div className="input-wrapper profile-editor-field profile-editor-bio" style={{ marginBottom: '26px' }}>
              <label className="input-label">About / Status Bio</label>
              <textarea
                rows={3}
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                placeholder="Tell friends what you are up to..."
                className="input-field"
                style={{ padding: '14px 16px', resize: 'none', height: 'auto', fontSize: '0.9rem' }}
              />
            </div>

            <button
              type="submit"
              className="btn btn-primary profile-editor-save"
              style={{ width: '100%', padding: '13px', borderRadius: '14px', fontSize: '0.92rem', fontWeight: 700 }}
            >
              {saved ? (
                <>
                  <Check style={{ width: '18px', height: '18px' }} /> Saved & Broadcasted Live!
                </>
              ) : (
                'Save Profile Changes'
              )}
            </button>
          </form>
        )}

        {/* 2. CHANGE USERNAME */}
        {activeSubSection === 'profile-username' && (
          <form className="profile-section profile-username-form" onSubmit={handleUsernameChangeSubmit}>
            <div style={{ marginBottom: '20px' }}>
              <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', margin: 0, lineHeight: 1.5 }}>
                Your username is your unique ID across Novyn Chat. Friends can find and message you using <code style={{ color: 'var(--primary)', background: 'rgba(255, 255, 255, 0.55)', padding: '2px 6px', borderRadius: '6px' }}>@{user?.username}</code>.
              </p>
            </div>

            {usernameMsg && (
              <div
                style={{
                  padding: '14px 18px',
                  borderRadius: '14px',
                  marginBottom: '18px',
                  fontSize: '0.84rem',
                  background: usernameMsg.ok ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                  color: usernameMsg.ok ? '#078779' : '#bd3750',
                  border: `1px solid ${usernameMsg.ok ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                }}
              >
                {usernameMsg.text}
              </div>
            )}

            <div
              className="profile-current-username-card"
              style={{
                padding: '18px 20px',
                borderRadius: '16px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                marginBottom: '20px',
              }}
            >
              <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '4px' }}>CURRENT USERNAME</div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)' }}>@{user?.username}</div>
            </div>

            <div className="input-wrapper" style={{ marginBottom: '22px' }}>
              <label className="input-label">New Username</label>
              <div style={{ position: 'relative' }}>
                <span style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontWeight: 700 }}>@</span>
                <input
                  type="text"
                  required
                  placeholder="new_username"
                  value={newUsername}
                  onChange={(e) => setNewUsername(e.target.value)}
                  className="input-field"
                  style={{ paddingLeft: '34px', height: '46px' }}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isChangingUsername}
              className="btn btn-primary"
              style={{ width: '100%', padding: '13px', borderRadius: '14px', fontSize: '0.9rem', fontWeight: 700 }}
            >
              {isChangingUsername ? 'Updating Username...' : 'Save New Username'}
            </button>
          </form>
        )}

        {/* 3. LINKED EMAIL */}
        {activeSubSection === 'profile-email' && (
          <div className="profile-section profile-email-section">
            <div style={{ marginBottom: '20px' }}>
              <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', margin: 0 }}>
                Your linked email address is used for password recovery and account security.
              </p>
            </div>

            <div
              className="profile-email-card"
              style={{
                padding: '22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <Mail style={{ width: '24px', height: '24px', color: 'var(--primary)' }} />
                <div>
                  <div style={{ fontSize: '0.96rem', fontWeight: 700, color: 'var(--text-main)' }}>
                    {user?.email || 'No email linked yet'}
                  </div>
                  <div style={{ fontSize: '0.74rem', color: user?.email ? '#0e9f8a' : '#a86d0b', marginTop: '2px' }}>
                    {user?.email ? '● Verified & Active' : 'Sign up or update email to secure account'}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 4. PRESENCE STATUS */}
        {activeSubSection === 'profile-presence' && (
          <div className="profile-section profile-presence-section">
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {[
                { id: 'online', label: 'Active', desc: 'Display green active badge and receive direct calls & notifications', color: '#10b981' },
                { id: 'away', label: 'Away', desc: 'Shows yellow away indicator when stepped away from screen', color: '#f59e0b' },
                { id: 'busy', label: 'Busy', desc: 'Let contacts know you are busy', color: '#ec4899' },
                { id: 'invisible', label: 'Invisible', desc: 'Appear offline to other contacts', color: '#64748b' },
              ].map((item) => {
                const isSelected = status === item.id;

                return (
                  <div
                    key={item.id}
                    className={`profile-presence-option ${isSelected ? 'is-selected' : ''}`}
                    onClick={() => {
                      setStatus(item.id as any);
                      updateProfile({ status: item.id });
                      triggerHaptic('success');
                    }}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px 20px',
                      borderRadius: '16px',
                      border: isSelected ? `1.5px solid ${item.color}` : '1px solid var(--border)',
                      background: isSelected ? `${item.color}15` : 'rgba(255, 255, 255, 0.55)',
                      cursor: 'pointer',
                      transition: 'all 0.18s ease',
                      boxShadow: isSelected ? `0 4px 20px ${item.color}1a` : 'none',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                      <span style={{ width: '12px', height: '12px', borderRadius: '50%', background: item.color, boxShadow: `0 0 10px ${item.color}` }} />
                      <div>
                        <div style={{ fontSize: '0.92rem', fontWeight: 700, color: isSelected ? 'var(--text-main)' : 'var(--text-muted)' }}>
                          {item.label}
                        </div>
                        <div style={{ fontSize: '0.76rem', color: 'var(--text-muted)', marginTop: '2px' }}>{item.desc}</div>
                      </div>
                    </div>

                    {isSelected && <span className="profile-presence-current">Current</span>}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 5. BLOCKED CONTACTS */}
        {activeSubSection === 'privacy-blocked' && (
          <div className="privacy-section privacy-blocked-section">
            <form className="privacy-block-form" onSubmit={handleBlockUserSubmit} style={{ display: 'flex', gap: '10px', marginBottom: '22px' }}>
              <input
                type="text"
                value={newBlockInput}
                onChange={(e) => setNewBlockInput(e.target.value)}
                placeholder="Enter username to block..."
                className="input-field"
                style={{ flex: 1, paddingLeft: '16px', height: '44px' }}
              />
              <button
                type="submit"
                className="btn btn-secondary"
                style={{ padding: '0 18px', height: '44px', borderRadius: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <Plus style={{ width: '16px', height: '16px' }} /> Block User
              </button>
            </form>

            {blockedUsers.size === 0 ? (
              <div
                className="privacy-empty-state"
                style={{
                  padding: '48px 24px',
                  borderRadius: '20px',
                  background: 'linear-gradient(135deg, rgba(168, 85, 247, 0.04) 0%, rgba(255, 255, 255, 0.55) 100%)',
                  border: '1px solid rgba(168, 85, 247, 0.18)',
                  textAlign: 'center',
                  color: 'var(--text-dark)',
                  boxShadow: '0 8px 30px rgba(36, 76, 96, 0.1)',
                }}
              >
                <div
                  style={{
                    width: '56px',
                    height: '56px',
                    borderRadius: '50%',
                    background: 'rgba(168, 85, 247, 0.12)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    margin: '0 auto 16px',
                    border: '1px solid rgba(168, 85, 247, 0.3)',
                    color: '#a855f7',
                  }}
                >
                  <Ban style={{ width: '28px', height: '28px' }} />
                </div>
                <h4 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)', margin: '0 0 6px' }}>No Blocked Contacts</h4>
                <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', margin: 0, maxWidth: '340px', marginInline: 'auto', lineHeight: 1.4 }}>
                  You have not blocked any contacts. Blocked users will appear here with instant unblock controls.
                </p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {Array.from(blockedUsers).map((username) => (
                  <div
                    key={username}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px 20px',
                      borderRadius: '16px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                      <Avatar name={username} size="md" />
                      <div>
                        <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)' }}>@{username}</div>
                        <div style={{ fontSize: '0.72rem', color: '#ef4444', marginTop: '2px' }}>Blocked on chat & calling</div>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => {
                        triggerHaptic('medium');
                        blockUser(username, false);
                      }}
                      className="btn btn-secondary"
                      style={{ padding: '8px 18px', fontSize: '0.82rem', borderRadius: '10px', color: '#087fac' }}
                    >
                      Unblock
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 6. CHANGE PASSWORD */}
        {activeSubSection === 'privacy-password' && (
          <form className="privacy-section privacy-password-form" onSubmit={handlePasswordChange}>
            {passwordMsg && (
              <div
                style={{
                  padding: '14px 18px',
                  borderRadius: '14px',
                  marginBottom: '18px',
                  fontSize: '0.84rem',
                  background: passwordMsg.ok ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                  color: passwordMsg.ok ? '#078779' : '#bd3750',
                  border: `1px solid ${passwordMsg.ok ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                }}
              >
                {passwordMsg.text}
              </div>
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginBottom: '22px' }}>
              <div className="input-wrapper">
                <label className="input-label">Current Password</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showCurrentPw ? 'text' : 'password'}
                    required
                    placeholder="Enter current password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="input-field"
                    style={{ paddingLeft: '16px', paddingRight: '42px', height: '46px' }}
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPw(!showCurrentPw)}
                    style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
                  >
                    {showCurrentPw ? <EyeOff style={{ width: '16px', height: '16px' }} /> : <Eye style={{ width: '16px', height: '16px' }} />}
                  </button>
                </div>
              </div>

              <div className="input-wrapper">
                <label className="input-label">New Password</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showNewPw ? 'text' : 'password'}
                    required
                    placeholder="At least 6 characters"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="input-field"
                    style={{ paddingLeft: '16px', paddingRight: '42px', height: '46px' }}
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPw(!showNewPw)}
                    style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
                  >
                    {showNewPw ? <EyeOff style={{ width: '16px', height: '16px' }} /> : <Eye style={{ width: '16px', height: '16px' }} />}
                  </button>
                </div>
              </div>

              <div className="input-wrapper">
                <label className="input-label">Confirm New Password</label>
                <input
                  type="password"
                  required
                  placeholder="Re-type new password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="input-field"
                  style={{ paddingLeft: '16px', height: '46px' }}
                />
              </div>
            </div>

            <button
              type="submit"
              className="btn btn-primary"
              style={{ width: '100%', padding: '13px', borderRadius: '14px', fontSize: '0.9rem', fontWeight: 700 }}
            >
              Update Password
            </button>
          </form>
        )}

        {/* 7. READ RECEIPTS */}
        {activeSubSection === 'privacy-receipts' && (
          <div className="privacy-section">
            <div
              className="privacy-setting-row"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '20px 22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                marginBottom: '16px',
              }}
            >
              <div>
                <div style={{ fontSize: '0.94rem', fontWeight: 700, color: 'var(--text-main)' }}>Send Read Receipts</div>
                <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '3px' }}>
                  Displays double checkmarks when messages are seen by contacts
                </div>
              </div>
              <button
                type="button"
                className={`settings-toggle ${readReceipts ? 'is-on' : 'is-off'}`}
                role="switch"
                aria-checked={readReceipts}
                aria-label="Toggle read receipts"
                onClick={() => {
                  const nextValue = !readReceipts;
                  setReadReceipts(nextValue);
                  localStorage.setItem('novyn_receipts', String(nextValue));
                  triggerHaptic('light');
                }}
              >
                <span />
                <span className="settings-toggle-label">{readReceipts ? 'ON' : 'OFF'}</span>
              </button>
            </div>
          </div>
        )}

        {activeSubSection === 'privacy-retention' && (
          <div className="privacy-section retention-section">
            <div className="privacy-setting-row retention-card" style={{ padding: '22px', borderRadius: '18px', background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '14px' }}>
                <div className="retention-icon"><Sparkles style={{ width: '20px', height: '20px' }} /></div>
                <div>
                  <div style={{ fontSize: '0.96rem', fontWeight: 750, color: 'var(--text-main)' }}>Keep messages for</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px', lineHeight: 1.5 }}>Messages older than this period are hidden from your account. Other participants keep their own retention preference.</div>
                </div>
              </div>
              <div className="retention-options" role="group" aria-label="Message retention period">
                {([7, 15, 30] as const).map((days) => (
                  <button key={days} type="button" className={retentionDays === days ? 'is-selected' : ''} aria-pressed={retentionDays === days} onClick={() => {
                    setRetentionDays(days);
                    localStorage.setItem(`novyn_retention_days_${user?.username || 'guest'}`, String(days));
                    setUser((current) => current ? { ...current, retentionDays: days } : current);
                    getSocket()?.emit('update_profile', { retentionDays: days });
                    triggerHaptic('light');
                  }}>
                    <strong>{days}</strong><span>days</span>
                  </button>
                ))}
              </div>
            </div>
            <p className="retention-note">Your default is 30 days. Changing this preference affects only what you see; it does not remove history for other people.</p>
          </div>
        )}

        {/* 8. SESSIONS */}
        {activeSubSection === 'privacy-sessions' && (
          <div className="privacy-section">
            <div
              className="privacy-session-card"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '20px 24px',
                borderRadius: '18px',
                background: 'linear-gradient(135deg, var(--primary-glow) 0%, rgba(16, 185, 129, 0.02) 100%)',
                border: '1px solid var(--border-focus)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <Globe style={{ width: '26px', height: '26px', color: 'var(--primary)' }} />
                <div>
                  <div style={{ fontSize: '0.94rem', fontWeight: 700, color: 'var(--text-main)' }}>
                    Current Web Client <span style={{ fontSize: '0.72rem', color: 'var(--primary)', marginLeft: '6px' }}>● Active Now</span>
                  </div>
                  <div style={{ fontSize: '0.76rem', color: 'var(--text-muted)', marginTop: '3px' }}>
                    Google Chrome • Windows NT • WebRTC & E2EE Ready
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 8.5 LINKED DEVICES (COMING SOON) */}
        {activeSubSection === 'privacy-linked-devices' && (
          <div className="privacy-section">
            <div
              className="privacy-linked-devices-card"
              style={{
                padding: '36px 28px',
                borderRadius: '24px',
                background: 'linear-gradient(135deg, rgba(6, 182, 212, 0.08) 0%, rgba(139, 92, 246, 0.04) 100%)',
                border: '1px solid rgba(6, 182, 212, 0.25)',
                textAlign: 'center',
                boxShadow: '0 8px 32px rgba(36, 76, 96, 0.1)',
                position: 'relative',
                overflow: 'hidden',
              }}
            >
              {/* Coming Soon Pill */}
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '4px 12px',
                  borderRadius: '20px',
                  background: 'rgba(6, 182, 212, 0.15)',
                  border: '1px solid rgba(6, 182, 212, 0.4)',
                  color: '#22d3ee',
                  fontSize: '0.75rem',
                  fontWeight: 800,
                  letterSpacing: '0.04em',
                  marginBottom: '20px',
                }}
              >
                <Sparkles style={{ width: '13px', height: '13px' }} /> COMING SOON
              </div>

              {/* Multi-Device Graphic Illustration */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '24px',
                  marginBottom: '24px',
                }}
              >
                <div
                  style={{
                    width: '64px',
                    height: '64px',
                    borderRadius: '18px',
                    background: 'rgba(255, 255, 255, 0.55)',
                    border: '1px solid var(--border)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#087fac',
                  }}
                >
                  <Laptop style={{ width: '32px', height: '32px' }} />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px' }}>
                  <div style={{ width: '40px', height: '2px', background: 'linear-gradient(90deg, #38bdf8, #a855f7)' }} />
                  <QrCode style={{ width: '22px', height: '22px', color: '#a855f7' }} />
                </div>

                <div
                  style={{
                    width: '64px',
                    height: '64px',
                    borderRadius: '18px',
                    background: 'rgba(255, 255, 255, 0.55)',
                    border: '1px solid var(--border)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#a855f7',
                  }}
                >
                  <Smartphone style={{ width: '32px', height: '32px' }} />
                </div>
              </div>

              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', margin: '0 0 8px' }}>
                Multi-Device QR Code Linking
              </h3>
              <p style={{ fontSize: '0.86rem', color: 'var(--text-muted)', maxWidth: '440px', margin: '0 auto 24px', lineHeight: 1.55 }}>
                Soon you will be able to link up to 4 devices (phones, tablets, and web browsers) simultaneously with instant end-to-end synchronized chat history.
              </p>

              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  alert('🚀 Multi-Device QR Pairing is in active development and will be available in Novyn v1.2!');
                }}
                className="btn btn-primary"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '12px 26px',
                  borderRadius: '14px',
                  fontSize: '0.9rem',
                  fontWeight: 700,
                  background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
                  border: 'none',
                }}
              >
                <QrCode style={{ width: '18px', height: '18px' }} /> Link a New Device
              </button>
            </div>
          </div>
        )}

        {/* 9. DANGER ZONE */}
        {activeSubSection === 'privacy-danger' && (
          <div className="privacy-section privacy-danger-section" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div
              className="privacy-danger-card"
              style={{
                padding: '22px',
                borderRadius: '18px',
                background: 'rgba(239, 68, 68, 0.06)',
                border: '1px solid rgba(239, 68, 68, 0.2)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <div>
                <div style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-main)' }}>Log Out All Devices</div>
                <div style={{ fontSize: '0.76rem', color: 'var(--text-muted)', marginTop: '3px' }}>
                  Revoke all active sessions and log out immediately
                </div>
              </div>

              <button
                type="button"
                onClick={() => {
                  triggerHaptic('heavy');
                  logout();
                }}
                className="btn btn-secondary"
                style={{ padding: '10px 18px', fontSize: '0.84rem', borderRadius: '12px', color: '#bd3750' }}
              >
                <LogOut style={{ width: '15px', height: '15px' }} /> Sign Out All
              </button>
            </div>
          </div>
        )}

        {/* 10. SOUNDS */}
        {activeSubSection === 'notif-sounds' && (
          <div className="notification-section notification-sounds-section">
            <div className="android-vibration-setting">
              <span><strong>Vibration & tap feedback</strong><small>{supportsVibration ? 'Haptic feedback on supported devices' : 'Vibration is not supported by this browser'}</small></span>
              <button type="button" className={`settings-toggle ${vibrationEnabled && supportsVibration ? 'is-on' : 'is-off'}`}
                role="switch" aria-label="Toggle vibration" aria-checked={vibrationEnabled && supportsVibration}
                disabled={!supportsVibration} onClick={() => {
                  const nextValue = !vibrationEnabled;
                  setVibrationEnabled(nextValue);
                  localStorage.setItem('novyn_vibration', String(nextValue));
                  if (nextValue) triggerHaptic('light');
                }}><span /><span className="settings-toggle-label">{vibrationEnabled && supportsVibration ? 'ON' : 'OFF'}</span></button>
            </div>
            <div
              className="notification-master-card"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '20px 22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                marginBottom: '20px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <Volume2 style={{ width: '24px', height: '24px', color: 'var(--primary)' }} />
                <div>
                  <div style={{ fontSize: '0.94rem', fontWeight: 700, color: 'var(--text-main)' }}>Enable Message Sounds</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>Play audio on message sent & received</div>
                </div>
              </div>
              <button
                type="button"
                className={`settings-toggle ${soundEnabled ? 'is-on' : 'is-off'}`}
                role="switch"
                aria-checked={soundEnabled}
                aria-label="Toggle message sounds"
                onClick={() => {
                  const nextValue = !soundEnabled;
                  setSoundEnabled(nextValue);
                  localStorage.setItem('novyn_sound', String(nextValue));
                  triggerHaptic('light');
                }}
              >
                <span />
                <span className="settings-toggle-label">{soundEnabled ? 'ON' : 'OFF'}</span>
              </button>
            </div>

            <div className="notification-sound-list" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {/* Notification Chime */}
              <div
                className="notification-sound-card"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '16px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div>
                  <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>Incoming Notification</div>
                  <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>notification.mp3 • Played on receiving messages</div>
                </div>

                <button
                  type="button"
                  onClick={playMessageNotification}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '9px 16px', borderRadius: '12px', fontSize: '0.82rem' }}
                >
                  <Play style={{ width: '14px', height: '14px', color: 'var(--primary)' }} /> Play Sound
                </button>
              </div>

              {/* Message Sent Chime */}
              <div
                className="notification-sound-card"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '16px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div>
                  <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>Message Sent Sound</div>
                  <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>message_sent.mp3 • Played on sending messages</div>
                </div>

                <button
                  type="button"
                  onClick={playMessageSentSound}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '9px 16px', borderRadius: '12px', fontSize: '0.82rem' }}
                >
                  <Play style={{ width: '14px', height: '14px', color: 'var(--primary)' }} /> Play Sound
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 11. CALLS */}
        {activeSubSection === 'notif-calls' && (
          <div className="notification-section notification-calls-section">
            <div
              className="notification-master-card"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '20px 22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                marginBottom: '20px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <Smartphone style={{ width: '24px', height: '24px', color: '#087fac' }} />
                <div>
                  <div style={{ fontSize: '0.94rem', fontWeight: 700, color: 'var(--text-main)' }}>WebRTC Call Audio</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>Ringtone melody & outgoing dial tones</div>
                </div>
              </div>
            </div>

            <div className="notification-sound-list" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {/* Incoming Call Ringtone */}
              <div
                className={`notification-sound-card ${isPlayingRingtone ? 'is-playing' : ''}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '16px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: isPlayingRingtone ? '1px solid var(--border-focus)' : '1px solid var(--border)',
                  boxShadow: isPlayingRingtone ? '0 0 16px var(--primary-glow)' : 'none',
                }}
              >
                <div>
                  <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>Incoming Call Ringtone</div>
                  <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>ringtone.mp3 • Played when you receive a call</div>
                </div>

                <button
                  type="button"
                  onClick={testIncomingRingtone}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '9px 16px', borderRadius: '12px', fontSize: '0.82rem' }}
                >
                  {isPlayingRingtone ? (
                    <>
                      <Square style={{ width: '14px', height: '14px', color: '#ef4444' }} /> Stop
                    </>
                  ) : (
                    <>
                      <Play style={{ width: '14px', height: '14px', color: 'var(--primary)' }} /> Preview
                    </>
                  )}
                </button>
              </div>

              {/* Outgoing Call Ringing */}
              <div
                className={`notification-sound-card ${isPlayingCallRing ? 'is-playing' : ''}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '16px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: isPlayingCallRing ? '1px solid #38bdf8' : '1px solid var(--border)',
                  boxShadow: isPlayingCallRing ? '0 0 16px rgba(56, 189, 248, 0.25)' : 'none',
                }}
              >
                <div>
                  <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>Outgoing Call Dial Ringing</div>
                  <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>call_ring.mp3 • Played when you dial someone</div>
                </div>

                <button
                  type="button"
                  onClick={testOutgoingCallRing}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '9px 16px', borderRadius: '12px', fontSize: '0.82rem' }}
                >
                  {isPlayingCallRing ? (
                    <>
                      <Square style={{ width: '14px', height: '14px', color: '#ef4444' }} /> Stop
                    </>
                  ) : (
                    <>
                      <Play style={{ width: '14px', height: '14px', color: '#087fac' }} /> Preview
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 12. PREVIEWS */}
        {activeSubSection === 'notif-previews' && (
          <div className="notification-section notification-preview-section">
            <div
              className="notification-master-card"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '20px 22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <Eye style={{ width: '24px', height: '24px', color: '#a86d0b' }} />
                <div>
                  <div style={{ fontSize: '0.94rem', fontWeight: 700, color: 'var(--text-main)' }}>Show Text Snippets</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>Include message preview in notifications</div>
                </div>
              </div>
              <button
                type="button"
                className={`settings-toggle ${previewEnabled ? 'is-on' : 'is-off'}`}
                role="switch"
                aria-checked={previewEnabled}
                aria-label="Toggle notification text snippets"
                onClick={() => {
                  const nextValue = !previewEnabled;
                  setPreviewEnabled(nextValue);
                  localStorage.setItem('novyn_preview', String(nextValue));
                  triggerHaptic('light');
                }}
              >
                <span />
                <span className="settings-toggle-label">{previewEnabled ? 'ON' : 'OFF'}</span>
              </button>
            </div>
          </div>
        )}

        {/* 13. THEME ACCENTS */}
        {activeSubSection === 'appear-theme' && (
          <div>
            <div className="color-mode-preference">
              <div className="color-mode-copy">
                <div className="color-mode-icon">{colorMode === 'dark' ? <Moon size={20} /> : <Sun size={20} />}</div>
                <span><strong>Dark mode</strong><small>Use a softer, low-light interface across Novyn.</small></span>
              </div>
              <button
                type="button"
                className={`color-mode-switch ${colorMode === 'dark' ? 'is-dark' : ''}`}
                role="switch"
                aria-checked={colorMode === 'dark'}
                aria-label="Toggle dark mode"
                onClick={() => {
                  const next = colorMode === 'dark' ? 'light' : 'dark';
                  setColorMode(next);
                  applyColorMode(next);
                  triggerHaptic('light');
                }}
              >
                <span />
              </button>
            </div>
            <div className="dock-preference">
              <span><strong>Always show dock</strong><small>Keep navigation visible instead of tucking it away when idle.</small></span>
              <button
                type="button"
                className={`color-mode-switch ${dockAlwaysVisible ? 'is-dark' : ''}`}
                role="switch"
                aria-checked={dockAlwaysVisible}
                aria-label="Toggle always-visible dock"
                onClick={() => {
                  setDockAlwaysVisible(!dockAlwaysVisible);
                  triggerHaptic('light');
                }}
              >
                <span />
              </button>
            </div>
            <div className="signature-theme-card">
              <span className="signature-theme-swatch"><Check style={{ width: '18px', height: '18px' }} /></span>
              <span><strong>Novyn Purple</strong><small>Your signature accent for both light and dark mode.</small></span>
            </div>
          </div>
        )}

        {/* 14. WALLPAPERS */}
        {activeSubSection === 'appear-wallpaper' && (
          <div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: '14px', marginBottom: '24px' }}>
              {Object.entries(WALLPAPER_PRESETS).map(([key, wp]) => {
                const isSelected = activeWallpaper === key;

                return (
                  <div
                    key={key}
                    onClick={() => {
                      triggerHaptic('light');
                      setActiveWallpaperState(key);
                      applyWallpaper(key);
                    }}
                    style={{
                      height: '96px',
                      borderRadius: '16px',
                      background: wp.background,
                      border: isSelected ? '2.5px solid var(--primary)' : '1px solid var(--border)',
                      cursor: 'pointer',
                      padding: '12px',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      boxShadow: isSelected ? '0 0 18px var(--primary-glow)' : 'none',
                      transition: 'all 0.18s ease',
                    }}
                  >
                    <span style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-main)' }}>{wp.name}</span>
                    {isSelected && <Check style={{ width: '18px', height: '18px', color: 'var(--primary)', alignSelf: 'flex-end' }} />}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 15. TYPOGRAPHY & FONT SIZING */}
        {activeSubSection === 'appear-font' && (
          <div className="typography-section">
            {/* Font Family Selector */}
            <div className="typography-font-family" style={{ marginBottom: '24px' }}>
              <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>
                App Font Family
              </label>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {FONT_PRESETS.map((font) => {
                  const isSelected = activeFontFamily === font.id;

                  return (
                    <div
                      key={font.id}
                      className={`typography-font-card ${isSelected ? 'is-selected' : ''}`}
                      onClick={() => {
                        triggerHaptic('light');
                        setActiveFontFamilyState(font.id);
                        applyFontFamily(font.id);
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        padding: '14px 18px',
                        borderRadius: '16px',
                        border: isSelected ? '1.5px solid var(--border-focus)' : '1px solid var(--border)',
                        background: isSelected ? 'var(--primary-glow)' : 'rgba(255, 255, 255, 0.55)',
                        cursor: 'pointer',
                        transition: 'all 0.18s ease',
                        boxShadow: isSelected ? '0 4px 18px var(--primary-glow)' : 'none',
                        fontFamily: font.family,
                      }}
                    >
                      <div>
                        <div style={{ fontSize: '0.96rem', fontWeight: 700, color: isSelected ? 'var(--text-main)' : 'var(--text-main)' }}>
                          {font.name}
                        </div>
                        <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)', marginTop: '2px', fontFamily: 'inherit' }}>
                          {font.description}
                        </div>
                      </div>

                      {isSelected && <span className="typography-current">Selected</span>}
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Font Size Selector */}
            <div className="typography-size-section" style={{ marginBottom: '24px' }}>
              <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>
                Message Text Sizing
              </label>
              <div style={{ display: 'flex', gap: '12px' }}>
                {(['sm', 'md', 'lg'] as const).map((size) => (
                  <button
                    key={size}
                    type="button"
                    className={`typography-size-button ${activeFontSize === size ? 'is-selected' : ''}`}
                    onClick={() => {
                      triggerHaptic('light');
                      setActiveFontSizeState(size);
                      applyFontSize(size);
                    }}
                    style={{
                      flex: 1,
                      padding: '14px',
                      borderRadius: '16px',
                      border: activeFontSize === size ? '1.5px solid var(--border-focus)' : '1px solid var(--border)',
                      background: activeFontSize === size ? 'var(--primary-glow)' : 'var(--bg-input)',
                      color: activeFontSize === size ? 'var(--text-main)' : 'var(--text-muted)',
                      fontSize: '0.88rem',
                      fontWeight: 700,
                      cursor: 'pointer',
                      transition: 'all 0.15s ease',
                    }}
                  >
                    {size === 'sm' ? 'Compact (13.5px)' : size === 'md' ? 'Default (15px)' : 'Large (16.5px)'}
                  </button>
                ))}
              </div>
            </div>

            {/* Live Message Bubble Preview */}
            <div
              className="typography-preview"
              style={{
                padding: '22px',
                borderRadius: '18px',
                background: 'var(--chat-wallpaper, var(--bg-main))',
                border: '1px solid var(--border)',
                transition: 'background 0.3s ease',
              }}
            >
              <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '12px', letterSpacing: '0.05em' }}>
                LIVE CHAT TYPOGRAPHY PREVIEW:
              </div>
              <div className="bubble other" style={{ maxWidth: '320px', marginBottom: '10px' }}>
                Hey there! How does this new font and accent look to you? ✨
              </div>
              <div className="bubble me" style={{ maxWidth: '320px', alignSelf: 'flex-end', marginLeft: 'auto' }}>
                It looks super crisp, modern, and instantly readable! 🚀
              </div>
            </div>
          </div>
        )}

        {/* 16. CACHE & STORAGE */}
        {activeSubSection === 'storage-cache' && (
          <div className="storage-section storage-cache-section">
            <div
              className="storage-cache-card"
              style={{
                padding: '22px',
                borderRadius: '18px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <div>
                <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-main)' }}>Temporary Media & Local Blobs</div>
                <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                  {cacheCleared ? '0 KB - Cache Cleared' : '~4.2 MB cached audio waveforms and image previews'}
                </div>
              </div>

              <button
                type="button"
                onClick={handleClearCache}
                className="btn btn-secondary"
                style={{ padding: '10px 18px', fontSize: '0.84rem', borderRadius: '12px' }}
              >
                {cacheCleared ? (
                  <>
                    <Check style={{ width: '15px', height: '15px', color: 'var(--primary)' }} /> Cleared!
                  </>
                ) : (
                  <>
                    <Trash2 style={{ width: '15px', height: '15px' }} /> Clear Cache
                  </>
                )}
              </button>
            </div>
          </div>
        )}

        {/* 17. BACKUP & RESTORE CHAT ARCHIVE */}
        {activeSubSection === 'storage-export' && (
          <div className="storage-section storage-backup-section" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
            {importStatus && (
              <div
                style={{
                  padding: '14px 18px',
                  borderRadius: '16px',
                  fontSize: '0.86rem',
                  background: importStatus.ok ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                  color: importStatus.ok ? '#078779' : '#bd3750',
                  border: `1px solid ${importStatus.ok ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                  lineHeight: 1.45,
                }}
              >
                {importStatus.text}
              </div>
            )}

            {/* Export Card */}
            <div
              className="storage-export-card"
              style={{
                padding: '24px',
                borderRadius: '20px',
                background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '12px', background: 'var(--primary-glow)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Download style={{ width: '20px', height: '20px' }} />
                </div>
                <div>
                  <h4 style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>Export Chat Backup</h4>
                  <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', margin: '2px 0 0' }}>
                    Save a complete JSON archive of your messages, friends, and active chats to your device.
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={handleExportData}
                className="btn btn-primary"
                style={{ padding: '11px 22px', borderRadius: '12px', fontSize: '0.88rem', fontWeight: 700 }}
              >
                {exportSuccess ? (
                  <>
                    <Check style={{ width: '16px', height: '16px' }} /> Backup Downloaded!
                  </>
                ) : (
                  'Download JSON Backup'
                )}
              </button>
            </div>

            {/* Import / Restore Card */}
            <div
              className="storage-import-card"
              style={{
                padding: '24px',
                borderRadius: '20px',
                background: 'linear-gradient(135deg, rgba(56, 189, 248, 0.06) 0%, rgba(255, 255, 255, 0.55) 100%)',
                border: '1px solid rgba(56, 189, 248, 0.25)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '12px', background: 'rgba(56, 189, 248, 0.15)', color: '#087fac', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Upload style={{ width: '20px', height: '20px' }} />
                </div>
                <div>
                  <h4 style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>Restore & Import Backup</h4>
                  <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', margin: '2px 0 0' }}>
                    Select a previously exported Novyn JSON backup file to restore conversations.
                  </p>
                </div>
              </div>

              <label
                className="btn btn-secondary"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '11px 22px',
                  borderRadius: '12px',
                  fontSize: '0.88rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  color: '#087fac',
                  border: '1px solid rgba(56, 189, 248, 0.3)',
                }}
              >
                <Upload style={{ width: '16px', height: '16px' }} /> Choose Backup File (.json)
                <input
                  type="file"
                  accept=".json,application/json"
                  onChange={handleImportFileChange}
                  style={{ display: 'none' }}
                />
              </label>
            </div>
          </div>
        )}

        {/* 18. ENCRYPTION & SECURITY */}
        {activeSubSection === 'storage-security' && (
          <div className="storage-section storage-security-section">
            <div
              className="storage-security-card"
              style={{
                padding: '24px',
                borderRadius: '20px',
                background: 'linear-gradient(135deg, var(--primary-glow) 0%, rgba(16, 185, 129, 0.02) 100%)',
                border: '1px solid var(--border-focus)',
                display: 'flex',
                alignItems: 'flex-start',
                gap: '16px',
              }}
            >
              <ShieldCheck style={{ width: '30px', height: '30px', color: 'var(--primary)', flexShrink: 0, marginTop: '2px' }} />
              <div>
                <strong style={{ fontSize: '1rem', color: 'var(--text-main)' }}>P2P WebRTC & End-to-End Encryption</strong>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', lineHeight: 1.55, margin: '6px 0 0' }}>
                  Direct voice, video, and message channels communicate with TLS transport encryption and direct P2P streaming over verified STUN signaling servers.
                </p>
                <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)', marginTop: '12px' }}>
                  Novyn Client v1.0.0 • Verified STUN Signaling Active
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 19-21. FEEDBACK PANELS */}
        {(activeSubSection === 'feedback-send' || activeSubSection === 'feedback-bug' || activeSubSection === 'feedback-feature') && (
          <FeedbackSettingsPanel type={
            activeSubSection === 'feedback-bug' ? 'bug' :
            activeSubSection === 'feedback-feature' ? 'feature' : 'general'
          } />
        )}
      </div>
    </div>
  );
};

// ── FeedbackSettingsPanel ─────────────────────────────────────────────────
// Inline feedback form rendered inside the Settings detail column.
type FeedbackPanelType = 'general' | 'bug' | 'feature';

const PANEL_META: Record<FeedbackPanelType, { icon: any; color: string; title: string; placeholder: string }> = {
  general: {
    icon: MessageSquarePlus,
    color: '#06b6d4',
    title: 'Share Your Thoughts',
    placeholder: "What's on your mind? We read every message…",
  },
  bug: {
    icon: Bug,
    color: '#f87171',
    title: 'Report a Bug',
    placeholder: 'Describe what happened, what you expected, and steps to reproduce…',
  },
  feature: {
    icon: Lightbulb,
    color: '#f59e0b',
    title: 'Request a Feature',
    placeholder: 'What would you like to see in Novyn? Describe the use case…',
  },
};

const FeedbackSettingsPanel: React.FC<{ type: FeedbackPanelType }> = ({ type }) => {
  const { user } = useAuth();
  const meta = PANEL_META[type];
  const Icon = meta.icon;

  const [message, setMessage]         = useState('');
  const [email, setEmail]             = useState(user?.email || '');
  const [rating, setRating]           = useState(0);
  const [hoverRating, setHoverRating] = useState(0);
  const [loading, setLoading]         = useState(false);
  const [success, setSuccess]         = useState(false);
  const [error, setError]             = useState('');

  // Reset when switching panel type
  useEffect(() => {
    setMessage(''); setRating(0); setHoverRating(0); setError(''); setSuccess(false);
  }, [type]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!message.trim() || message.trim().length < 5) {
      setError('Please write at least a few words.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          type,
          message: message.trim(),
          email: email.trim() || undefined,
          rating: rating || undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Submission failed.');
      setSuccess(true);
      setMessage(''); setRating(0);
    } catch (err: any) {
      setError(err.message || 'Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const charLimit = 2000;

  return (
    <div className={`feedback-panel feedback-panel--${type}`} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

      {/* Header card */}
      <div className="feedback-header-card" style={{
        padding: '20px 22px',
        borderRadius: '20px',
        background: `linear-gradient(135deg, ${meta.color}14 0%, rgba(255,255,255,0.02) 100%)`,
        border: `1px solid ${meta.color}30`,
        display: 'flex', alignItems: 'center', gap: '14px',
      }}>
        <div style={{
          width: '46px', height: '46px', borderRadius: '14px', flexShrink: 0,
          background: `${meta.color}1a`, color: meta.color,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon style={{ width: '22px', height: '22px' }} />
        </div>
        <div>
          <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)' }}>{meta.title}</h3>
          <p style={{ margin: '3px 0 0', fontSize: '0.78rem', color: 'var(--text-muted)', lineHeight: 1.4 }}>
            {user ? `Sending as ${user.username}` : 'You\'re not logged in — add your email to get a reply'}
          </p>
        </div>
      </div>

      {success ? (
        /* Success state */
        <div style={{
          padding: '32px 24px', borderRadius: '20px', textAlign: 'center',
          background: 'rgba(16,185,129,0.07)', border: '1px solid rgba(16,185,129,0.25)',
        }}>
          <div style={{
            width: '56px', height: '56px', borderRadius: '50%', margin: '0 auto 14px',
            background: 'rgba(16,185,129,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <CheckCircle2 style={{ width: '28px', height: '28px', color: '#0e9f8a' }} />
          </div>
          <h4 style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-main)', margin: '0 0 6px' }}>Thanks for the feedback!</h4>
          <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', margin: 0, lineHeight: 1.5 }}>
            We read every submission and use it to make Novyn better.
          </p>
          <button
            type="button"
            onClick={() => setSuccess(false)}
            style={{
              marginTop: '16px', padding: '8px 20px', borderRadius: '10px',
              background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)',
              color: 'var(--text-muted)', fontSize: '0.84rem', cursor: 'pointer',
            }}
          >
            Send another
          </button>
        </div>
      ) : (
        <form className="feedback-form" onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>

          {/* Star rating */}
          <div className="feedback-rating-card" style={{
            padding: '16px 18px', borderRadius: '14px',
            background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)',
          }}>
            <p style={{ margin: '0 0 10px', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-muted)' }}>
              Rate your overall experience (optional)
            </p>
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              {[1, 2, 3, 4, 5].map(star => (
                <button
                  key={star}
                  type="button"
                  className="feedback-star"
                  onClick={() => setRating(star === rating ? 0 : star)}
                  onMouseEnter={() => setHoverRating(star)}
                  onMouseLeave={() => setHoverRating(0)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '2px' }}
                  aria-label={`${star} star`}
                >
                  <Star
                    style={{
                      width: '24px', height: '24px',
                      transform: (hoverRating || rating) >= star ? 'scale(1.2)' : 'scale(1)',
                      transition: 'all 0.15s ease',
                    }}
                    fill={(hoverRating || rating) >= star ? '#f59e0b' : 'transparent'}
                    stroke={(hoverRating || rating) >= star ? '#f59e0b' : '#475569'}
                    strokeWidth={1.5}
                  />
                </button>
              ))}
              {rating > 0 && (
                <span style={{ fontSize: '0.8rem', color: '#a86d0b', fontWeight: 700, marginLeft: '4px' }}>
                  {['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'][rating]}
                </span>
              )}
            </div>
          </div>

          {/* Message */}
          <div className="feedback-message-field" style={{ position: 'relative' }}>
            <textarea
              className="feedback-textarea"
              value={message}
              onChange={e => { setMessage(e.target.value.slice(0, charLimit)); setError(''); }}
              placeholder={meta.placeholder}
              rows={5}
              style={{
                width: '100%', resize: 'none', padding: '14px 16px',
                borderRadius: '14px', fontSize: '0.88rem', lineHeight: 1.6,
                background: 'rgba(255, 255, 255, 0.55)',
                border: `1px solid ${error ? '#f87171' : 'var(--border)'}`,
                color: 'var(--text-main)', outline: 'none', boxSizing: 'border-box',
                fontFamily: 'inherit', transition: 'border-color 0.15s',
              }}
              onFocus={e => { if (!error) e.target.style.borderColor = 'var(--border-focus)'; }}
              onBlur={e => { if (!error) e.target.style.borderColor = 'var(--border)'; }}
            />
            <span style={{
              position: 'absolute', bottom: '10px', right: '14px',
              fontSize: '0.7rem',
              color: message.length > charLimit * 0.9 ? '#bd3750' : 'var(--text-dark)',
            }}>
              {message.length}/{charLimit}
            </span>
          </div>

          {/* Email (for anonymous users) */}
          {!user && (
            <input
              className="feedback-email-input"
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="Your email (optional — so we can reply)"
              style={{
                width: '100%', padding: '12px 14px', borderRadius: '12px',
                fontSize: '0.87rem', background: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)', color: 'var(--text-main)',
                outline: 'none', boxSizing: 'border-box', fontFamily: 'inherit',
              }}
            />
          )}

          {/* Error */}
          {error && (
            <p style={{ margin: 0, fontSize: '0.82rem', color: '#bd3750', fontWeight: 600 }}>{error}</p>
          )}

          {/* Submit */}
          <button
            type="submit"
            className="feedback-submit"
            disabled={loading || !message.trim()}
            style={{
              padding: '13px 20px', borderRadius: '14px', fontWeight: 700,
              fontSize: '0.9rem', border: 'none', cursor: loading || !message.trim() ? 'not-allowed' : 'pointer',
              background: loading || !message.trim()
                ? 'rgba(255, 255, 255, 0.55)'
                : `linear-gradient(135deg, ${meta.color} 0%, ${meta.color}bb 100%)`,
              color: loading || !message.trim() ? 'var(--text-dark)' : 'var(--text-main)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
              transition: 'all 0.2s ease',
              boxShadow: loading || !message.trim() ? 'none' : `0 4px 14px ${meta.color}40`,
            }}
          >
            {loading ? (
              <>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"
                  style={{ animation: 'spin 0.8s linear infinite' }}>
                  <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
                </svg>
                Sending…
              </>
            ) : (
              <>
                <Send style={{ width: '15px', height: '15px' }} />
                Send Feedback
              </>
            )}
          </button>

        </form>
      )}
    </div>
  );
};
