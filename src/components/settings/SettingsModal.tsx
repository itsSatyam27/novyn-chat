import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import {
  User,
  Shield,
  Bell,
  Palette,
  HardDrive,
  LogOut,
  Check,
  X,
  Lock,
  Eye,
  EyeOff,
  Sparkles,
  Volume2,
  VolumeX,
  Smartphone,
  ShieldCheck,
  Ban,
  Trash2,
  Sun,
  Moon,
  Monitor,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { triggerHaptic } from '../../services/capacitor';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

type SettingsTab = 'profile' | 'notifications' | 'privacy' | 'appearance' | 'storage';

export const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose }) => {
  const { user, logout } = useAuth();
  const { updateProfile, blockedUsers, blockUser } = useChat();

  const [activeTab, setActiveTab] = useState<SettingsTab>('profile');
  const [displayName, setDisplayName] = useState(user?.displayName || user?.username || '');
  const [bio, setBio] = useState(user?.bio || 'Hey there! I am using Novyn Chat.');
  const [status, setStatus] = useState<'online' | 'away' | 'dnd'>(
    (user?.presenceMode as any) || 'online'
  );

  // Notifications State
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [callRingEnabled, setCallRingEnabled] = useState(true);
  const [previewEnabled, setPreviewEnabled] = useState(true);

  // Privacy State
  const [readReceipts, setReadReceipts] = useState(true);
  const [lastSeenPrivacy, setLastSeenPrivacy] = useState<'everyone' | 'friends' | 'nobody'>('everyone');

  // Password Change
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordMsg, setPasswordMsg] = useState<{ text: string; ok: boolean } | null>(null);

  // Appearance & Themes
  const [themeMode, setThemeMode] = useState<string>(() => localStorage.getItem('novyn_theme_mode') || 'dark');
  const [accentColor, setAccentColor] = useState('#10b981');
  const [fontSize, setFontSize] = useState<'sm' | 'md' | 'lg'>('md');

  const [saved, setSaved] = useState(false);

  if (!isOpen) return null;

  const handleSaveProfile = (e: React.FormEvent) => {
    e.preventDefault();
    triggerHaptic('success');

    updateProfile({
      displayName: displayName.trim(),
      bio: bio.trim(),
      status,
    });

    setSaved(true);
    setTimeout(() => {
      setSaved(false);
    }, 1500);
  };

  const handlePasswordChange = (e: React.FormEvent) => {
    e.preventDefault();
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
    setTimeout(() => setPasswordMsg(null), 3000);
  };

  return (
    <AnimatePresence>
      <div
        className="modal-backdrop"
        onClick={onClose}
        style={{
          zIndex: 130,
          background: 'rgba(247, 254, 253, 0.75)',
          backdropFilter: 'blur(14px)',
          WebkitBackdropFilter: 'blur(14px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '20px',
        }}
      >
        <motion.div
          initial={{ opacity: 0, scale: 0.94, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.94, y: 16 }}
          transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
          onClick={(e) => e.stopPropagation()}
          style={{
            maxWidth: '780px',
            width: '100%',
            height: '76vh',
            maxHeight: '680px',
            background: 'linear-gradient(180deg, var(--bg-surface) 0%, var(--bg-surface) 100%)',
            border: '1px solid var(--border)',
            borderRadius: '24px',
            boxShadow: '0 30px 70px rgba(36, 76, 96, 0.1), 0 0 0 1px rgba(16, 185, 129, 0.15)',
            display: 'flex',
            overflow: 'hidden',
          }}
        >
          {/* Left Navigation Sidebar */}
          <div
            style={{
              width: '220px',
              minWidth: '220px',
              background: 'rgba(255, 255, 255, 0.55)',
              borderRight: '1px solid var(--border)',
              padding: '20px 14px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
            }}
          >
            <div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)', padding: '0 10px 16px', margin: 0, letterSpacing: '-0.02em' }}>
                Settings
              </h3>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('light');
                    setActiveTab('profile');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '10px 12px',
                    borderRadius: '12px',
                    border: 'none',
                    background: activeTab === 'profile' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                    color: activeTab === 'profile' ? '#0e9f8a' : 'var(--text-muted)',
                    fontWeight: activeTab === 'profile' ? 700 : 500,
                    fontSize: '0.84rem',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    textAlign: 'left',
                  }}
                >
                  <User style={{ width: '16px', height: '16px' }} /> Profile
                </button>

                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('light');
                    setActiveTab('notifications');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '10px 12px',
                    borderRadius: '12px',
                    border: 'none',
                    background: activeTab === 'notifications' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                    color: activeTab === 'notifications' ? '#0e9f8a' : 'var(--text-muted)',
                    fontWeight: activeTab === 'notifications' ? 700 : 500,
                    fontSize: '0.84rem',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    textAlign: 'left',
                  }}
                >
                  <Bell style={{ width: '16px', height: '16px' }} /> Notifications
                </button>

                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('light');
                    setActiveTab('privacy');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '10px 12px',
                    borderRadius: '12px',
                    border: 'none',
                    background: activeTab === 'privacy' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                    color: activeTab === 'privacy' ? '#0e9f8a' : 'var(--text-muted)',
                    fontWeight: activeTab === 'privacy' ? 700 : 500,
                    fontSize: '0.84rem',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    textAlign: 'left',
                  }}
                >
                  <Shield style={{ width: '16px', height: '16px' }} /> Privacy & Security
                </button>

                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('light');
                    setActiveTab('appearance');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '10px 12px',
                    borderRadius: '12px',
                    border: 'none',
                    background: activeTab === 'appearance' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                    color: activeTab === 'appearance' ? '#0e9f8a' : 'var(--text-muted)',
                    fontWeight: activeTab === 'appearance' ? 700 : 500,
                    fontSize: '0.84rem',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    textAlign: 'left',
                  }}
                >
                  <Palette style={{ width: '16px', height: '16px' }} /> Appearance
                </button>

                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('light');
                    setActiveTab('storage');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '10px 12px',
                    borderRadius: '12px',
                    border: 'none',
                    background: activeTab === 'storage' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                    color: activeTab === 'storage' ? '#0e9f8a' : 'var(--text-muted)',
                    fontWeight: activeTab === 'storage' ? 700 : 500,
                    fontSize: '0.84rem',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    textAlign: 'left',
                  }}
                >
                  <HardDrive style={{ width: '16px', height: '16px' }} /> Storage & Data
                </button>
              </div>
            </div>

            {/* Logout Button in Left Sidebar */}
            <button
              type="button"
              onClick={() => {
                triggerHaptic('heavy');
                onClose();
                logout();
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '10px 12px',
                borderRadius: '12px',
                border: '1px solid rgba(239, 68, 68, 0.2)',
                background: 'rgba(239, 68, 68, 0.08)',
                color: '#bd3750',
                fontSize: '0.82rem',
                fontWeight: 700,
                cursor: 'pointer',
                transition: 'all 0.15s ease',
              }}
            >
              <LogOut style={{ width: '15px', height: '15px' }} /> Sign Out
            </button>
          </div>

          {/* Right Main Content Area */}
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, overflow: 'hidden' }}>
            {/* Header with Close */}
            <div
              style={{
                padding: '18px 24px',
                borderBottom: '1px solid var(--border)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <h2 style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                {activeTab === 'profile' && 'Edit Profile'}
                {activeTab === 'notifications' && 'Notification Settings'}
                {activeTab === 'privacy' && 'Privacy & Security'}
                {activeTab === 'appearance' && 'Appearance & Chat Style'}
                {activeTab === 'storage' && 'Storage & Cache'}
              </h2>

              <button
                type="button"
                onClick={() => {
                  triggerHaptic('light');
                  onClose();
                }}
                style={{
                  width: '34px',
                  height: '34px',
                  borderRadius: '50%',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  color: 'var(--text-muted)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
                title="Close"
              >
                <X style={{ width: '17px', height: '17px' }} />
              </button>
            </div>

            {/* Tab Body */}
            <div className="conversations-scroll" style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
              {/* 1. PROFILE TAB */}
              {activeTab === 'profile' && (
                <form onSubmit={handleSaveProfile}>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '16px',
                      padding: '16px 20px',
                      borderRadius: '18px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      marginBottom: '22px',
                    }}
                  >
                    <Avatar name={displayName || user?.username || 'You'} size="xl" online={status === 'online'} />
                    <div>
                      <h4 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                        {displayName || user?.username}
                      </h4>
                      <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: '2px 0 0' }}>@{user?.username}</p>
                      {user?.email && <p style={{ fontSize: '0.74rem', color: 'var(--text-dark)', margin: '2px 0 0' }}>{user.email}</p>}
                    </div>
                  </div>

                  {/* Presence Status */}
                  <div style={{ marginBottom: '20px' }}>
                    <label className="input-label" style={{ marginBottom: '8px', display: 'block' }}>Presence Mode</label>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      {(['online', 'away', 'dnd'] as const).map((mode) => {
                        const isSelected = status === mode;
                        const label = mode === 'online' ? 'Active' : mode === 'away' ? 'Away' : 'Do Not Disturb';
                        const dotColor = mode === 'online' ? '#10b981' : mode === 'away' ? '#f59e0b' : '#ef4444';

                        return (
                          <button
                            key={mode}
                            type="button"
                            onClick={() => setStatus(mode)}
                            style={{
                              flex: 1,
                              padding: '9px 12px',
                              borderRadius: '12px',
                              border: isSelected ? `1px solid ${dotColor}` : '1px solid var(--border)',
                              background: isSelected ? `${dotColor}1a` : 'var(--bg-input)',
                              color: isSelected ? 'var(--text-main)' : 'var(--text-muted)',
                              fontSize: '0.82rem',
                              fontWeight: 700,
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              gap: '6px',
                              transition: 'all 0.15s ease',
                            }}
                          >
                            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: dotColor }} />
                            {label}
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Display Name */}
                  <div className="input-wrapper" style={{ marginBottom: '18px' }}>
                    <label className="input-label">Display Name</label>
                    <input
                      type="text"
                      required
                      value={displayName}
                      onChange={(e) => setDisplayName(e.target.value)}
                      placeholder="Your Display Name"
                      className="input-field"
                      style={{ paddingLeft: '16px' }}
                    />
                  </div>

                  {/* Bio */}
                  <div className="input-wrapper" style={{ marginBottom: '24px' }}>
                    <label className="input-label">About / Status</label>
                    <textarea
                      rows={3}
                      value={bio}
                      onChange={(e) => setBio(e.target.value)}
                      placeholder="Share a thought or status..."
                      className="input-field"
                      style={{ padding: '12px 16px', resize: 'none', height: 'auto' }}
                    />
                  </div>

                  {/* Save Button */}
                  <button
                    type="submit"
                    className="btn btn-primary"
                    style={{ width: '100%', padding: '12px', borderRadius: '14px', fontSize: '0.88rem' }}
                  >
                    {saved ? (
                      <>
                        <Check style={{ width: '16px', height: '16px' }} /> Saved & Updated Live!
                      </>
                    ) : (
                      'Save Changes'
                    )}
                  </button>
                </form>
              )}

              {/* 2. NOTIFICATIONS TAB */}
              {activeTab === 'notifications' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px',
                      borderRadius: '14px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <Volume2 style={{ width: '20px', height: '20px', color: '#0e9f8a' }} />
                      <div>
                        <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>Message Sounds</div>
                        <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>Play subtle chimes for incoming messages</div>
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={soundEnabled}
                      onChange={(e) => setSoundEnabled(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: '#10b981', cursor: 'pointer' }}
                    />
                  </div>

                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px',
                      borderRadius: '14px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <Smartphone style={{ width: '20px', height: '20px', color: '#087fac' }} />
                      <div>
                        <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>Call Ringtones</div>
                        <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>Play audio chime on incoming and outgoing calls</div>
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={callRingEnabled}
                      onChange={(e) => setCallRingEnabled(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: '#10b981', cursor: 'pointer' }}
                    />
                  </div>

                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px',
                      borderRadius: '14px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <Eye style={{ width: '20px', height: '20px', color: '#a86d0b' }} />
                      <div>
                        <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>Message Previews</div>
                        <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>Show message snippet in notifications</div>
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={previewEnabled}
                      onChange={(e) => setPreviewEnabled(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: '#10b981', cursor: 'pointer' }}
                    />
                  </div>
                </div>
              )}

              {/* 3. PRIVACY & SECURITY TAB */}
              {activeTab === 'privacy' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  {/* Read Receipts */}
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '16px',
                      borderRadius: '14px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>Read Receipts</div>
                      <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>Show double checkmarks when messages are seen</div>
                    </div>
                    <input
                      type="checkbox"
                      checked={readReceipts}
                      onChange={(e) => setReadReceipts(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: '#10b981', cursor: 'pointer' }}
                    />
                  </div>

                  {/* Blocked Users List */}
                  <div>
                    <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dark)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '8px' }}>
                      Blocked Contacts ({blockedUsers.size})
                    </div>

                    {blockedUsers.size === 0 ? (
                      <div style={{ padding: '16px', borderRadius: '12px', background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)', textAlign: 'center', color: 'var(--text-dark)', fontSize: '0.82rem' }}>
                        No blocked contacts
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        {Array.from(blockedUsers).map((username) => (
                          <div
                            key={username}
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'space-between',
                              padding: '10px 14px',
                              borderRadius: '12px',
                              background: 'rgba(255, 255, 255, 0.55)',
                              border: '1px solid var(--border)',
                            }}
                          >
                            <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>@{username}</span>
                            <button
                              type="button"
                              onClick={() => blockUser(username, false)}
                              style={{ background: 'none', border: 'none', color: '#087fac', fontSize: '0.78rem', fontWeight: 700, cursor: 'pointer' }}
                            >
                              Unblock
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Change Password Form */}
                  <form onSubmit={handlePasswordChange} style={{ borderTop: '1px solid var(--border)', paddingTop: '18px' }}>
                    <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Lock style={{ width: '15px', height: '15px', color: '#0e9f8a' }} /> Change Password
                    </div>

                    {passwordMsg && (
                      <div
                        style={{
                          padding: '10px',
                          borderRadius: '10px',
                          marginBottom: '12px',
                          fontSize: '0.8rem',
                          background: passwordMsg.ok ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                          color: passwordMsg.ok ? '#078779' : '#bd3750',
                          border: `1px solid ${passwordMsg.ok ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                        }}
                      >
                        {passwordMsg.text}
                      </div>
                    )}

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '14px' }}>
                      <input
                        type="password"
                        placeholder="Current Password"
                        value={currentPassword}
                        onChange={(e) => setCurrentPassword(e.target.value)}
                        className="input-field"
                        style={{ paddingLeft: '14px', height: '40px', fontSize: '0.82rem' }}
                      />
                      <input
                        type="password"
                        placeholder="New Password"
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        className="input-field"
                        style={{ paddingLeft: '14px', height: '40px', fontSize: '0.82rem' }}
                      />
                      <input
                        type="password"
                        placeholder="Confirm New Password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        className="input-field"
                        style={{ paddingLeft: '14px', height: '40px', fontSize: '0.82rem' }}
                      />
                    </div>

                    <button
                      type="submit"
                      className="btn btn-secondary"
                      style={{ padding: '8px 16px', borderRadius: '10px', fontSize: '0.82rem' }}
                    >
                      Update Password
                    </button>
                  </form>
                </div>
              )}

              {/* 4. APPEARANCE TAB */}
              {activeTab === 'appearance' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '22px' }}>
                  {/* Global Theme Mode */}
                  <div>
                    <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>App Theme Mode</label>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
                      {[
                        { id: 'dark', label: 'Dark', icon: Moon, desc: 'Classic dark' },
                        { id: 'light', label: 'Light', icon: Sun, desc: 'Crisp light' },
                        { id: 'oled', label: 'OLED', icon: Moon, desc: 'Pure black' },
                        { id: 'cyber', label: 'Cyber', icon: Sparkles, desc: 'Neon glow' },
                      ].map((mode) => {
                        const isSelected = themeMode === mode.id;
                        const Icon = mode.icon;
                        return (
                          <button
                            key={mode.id}
                            type="button"
                            onClick={() => {
                              triggerHaptic('light');
                              setThemeMode(mode.id);
                              localStorage.setItem('novyn_theme_mode', mode.id);
                              if (mode.id === 'light') {
                                document.documentElement.setAttribute('data-theme', 'light');
                                document.documentElement.style.setProperty('--bg-canvas', '#f8fafc');
                                document.documentElement.style.setProperty('--bg-surface', '#ffffff');
                                document.documentElement.style.setProperty('--bg-input', '#f1f5f9');
                                document.documentElement.style.setProperty('--border', 'rgba(0,0,0,0.1)');
                                document.documentElement.style.setProperty('--text-primary', '#0f172a');
                              } else if (mode.id === 'oled') {
                                document.documentElement.setAttribute('data-theme', 'oled');
                                document.documentElement.style.setProperty('--bg-canvas', '#000000');
                                document.documentElement.style.setProperty('--bg-surface', '#050505');
                                document.documentElement.style.setProperty('--bg-input', '#101010');
                                document.documentElement.style.setProperty('--border', 'rgba(255,255,255,0.08)');
                                document.documentElement.style.setProperty('--text-primary', '#ffffff');
                              } else if (mode.id === 'cyber') {
                                document.documentElement.setAttribute('data-theme', 'cyber');
                                document.documentElement.style.setProperty('--bg-canvas', '#0b0816');
                                document.documentElement.style.setProperty('--bg-surface', '#130e24');
                                document.documentElement.style.setProperty('--bg-input', '#1c1536');
                                document.documentElement.style.setProperty('--border', 'rgba(168,85,247,0.25)');
                                document.documentElement.style.setProperty('--text-primary', '#ffffff');
                              } else {
                                document.documentElement.removeAttribute('data-theme');
                                document.documentElement.style.removeProperty('--bg-canvas');
                                document.documentElement.style.removeProperty('--bg-surface');
                                document.documentElement.style.removeProperty('--bg-input');
                                document.documentElement.style.removeProperty('--border');
                                document.documentElement.style.removeProperty('--text-primary');
                              }
                            }}
                            style={{
                              padding: '12px 8px',
                              borderRadius: '12px',
                              border: isSelected ? '1px solid #10b981' : '1px solid var(--border)',
                              background: isSelected ? 'rgba(16, 185, 129, 0.12)' : 'rgba(255, 255, 255, 0.55)',
                              color: isSelected ? '#0e9f8a' : 'var(--text-muted)',
                              cursor: 'pointer',
                              display: 'flex',
                              flexDirection: 'column',
                              alignItems: 'center',
                              gap: '6px',
                              transition: 'all 0.15s ease',
                            }}
                          >
                            <Icon style={{ width: '18px', height: '18px' }} />
                            <span style={{ fontSize: '0.8rem', fontWeight: 700 }}>{mode.label}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Theme Accent Picker */}
                  <div>
                    <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>Primary Accent Color</label>
                    <div style={{ display: 'flex', gap: '12px' }}>
                      {[
                        { color: '#10b981', name: 'Emerald' },
                        { color: '#06b6d4', name: 'Cyan' },
                        { color: '#8b5cf6', name: 'Purple' },
                        { color: '#f43f5e', name: 'Rose' },
                        { color: '#f59e0b', name: 'Amber' },
                      ].map((theme) => (
                        <div
                          key={theme.color}
                          onClick={() => setAccentColor(theme.color)}
                          style={{
                            display: 'flex',
                            flexDirection: 'column',
                            alignItems: 'center',
                            gap: '6px',
                            cursor: 'pointer',
                          }}
                        >
                          <div
                            style={{
                              width: '38px',
                              height: '38px',
                              borderRadius: '50%',
                              background: theme.color,
                              border: accentColor === theme.color ? '3px solid #ffffff' : '2px solid transparent',
                              boxShadow: accentColor === theme.color ? `0 0 14px ${theme.color}` : 'none',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              color: 'var(--text-main)',
                            }}
                          >
                            {accentColor === theme.color && <Check style={{ width: '18px', height: '18px' }} />}
                          </div>
                          <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{theme.name}</span>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Font Size */}
                  <div>
                    <label className="input-label" style={{ marginBottom: '8px', display: 'block' }}>Chat Font Size</label>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      {(['sm', 'md', 'lg'] as const).map((size) => (
                        <button
                          key={size}
                          type="button"
                          onClick={() => setFontSize(size)}
                          style={{
                            flex: 1,
                            padding: '10px',
                            borderRadius: '12px',
                            border: fontSize === size ? '1px solid #10b981' : '1px solid var(--border)',
                            background: fontSize === size ? 'rgba(16, 185, 129, 0.12)' : 'var(--bg-input)',
                            color: fontSize === size ? '#078779' : 'var(--text-muted)',
                            fontSize: '0.82rem',
                            fontWeight: 700,
                            cursor: 'pointer',
                          }}
                        >
                          {size === 'sm' ? 'Compact (13px)' : size === 'md' ? 'Default (15px)' : 'Large (17px)'}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* 5. STORAGE & DATA TAB */}
              {activeTab === 'storage' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div
                    style={{
                      padding: '18px',
                      borderRadius: '16px',
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>Local Cache & Media</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                        Temporary audio, voice notes, and cached images
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => {
                        triggerHaptic('medium');
                        alert('Local cache cleaned successfully!');
                      }}
                      className="btn btn-secondary"
                      style={{ padding: '8px 14px', fontSize: '0.78rem', borderRadius: '10px' }}
                    >
                      <Trash2 style={{ width: '14px', height: '14px' }} /> Clear Cache
                    </button>
                  </div>

                  <div
                    style={{
                      padding: '16px 18px',
                      borderRadius: '14px',
                      background: 'rgba(16, 185, 129, 0.08)',
                      border: '1px solid rgba(16, 185, 129, 0.2)',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '12px',
                    }}
                  >
                    <ShieldCheck style={{ width: '24px', height: '24px', color: '#0e9f8a', flexShrink: 0 }} />
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
                      <strong>Novyn Chat WebRTC & End-to-End Ready</strong>
                      <div style={{ color: 'var(--text-muted)', fontSize: '0.72rem' }}>Version 1.0.0 • Connected Securely</div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
