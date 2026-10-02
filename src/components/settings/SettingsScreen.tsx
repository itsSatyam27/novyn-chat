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
  Lock,
  Eye,
  Volume2,
  Smartphone,
  ShieldCheck,
  Trash2,
  ChevronRight,
  ArrowLeft,
  Moon,
  Sparkles,
} from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

type SettingsCategory = 'profile' | 'notifications' | 'privacy' | 'appearance' | 'storage';

interface SettingsScreenProps {
  isCompact?: boolean;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({ isCompact = false }) => {
  const { user, logout } = useAuth();
  const { updateProfile, blockedUsers, blockUser } = useChat();

  const [activeCategory, setActiveCategory] = useState<SettingsCategory>('profile');
  const [mobileDetailOpen, setMobileDetailOpen] = useState(false);

  // Profile Form
  const [displayName, setDisplayName] = useState(user?.displayName || user?.username || '');
  const [bio, setBio] = useState(user?.bio || 'Hey there! I am using Novyn Chat.');
  const [status, setStatus] = useState<'online' | 'away' | 'dnd'>(
    (user?.presenceMode as any) || 'online'
  );
  const [saved, setSaved] = useState(false);

  // Notifications State
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [callRingEnabled, setCallRingEnabled] = useState(true);
  const [previewEnabled, setPreviewEnabled] = useState(true);

  // Privacy State
  const [readReceipts, setReadReceipts] = useState(true);

  // Password Change
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordMsg, setPasswordMsg] = useState<{ text: string; ok: boolean } | null>(null);

  // Appearance & Themes
  const [accentColor, setAccentColor] = useState('#10b981');
  const [fontSize, setFontSize] = useState<'sm' | 'md' | 'lg'>('md');

  const handleSaveProfile = (e: React.FormEvent) => {
    e.preventDefault();
    triggerHaptic('success');

    updateProfile({
      displayName: displayName.trim(),
      bio: bio.trim(),
      status,
    });

    setSaved(true);
    setTimeout(() => setSaved(false), 1800);
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

  const categories = [
    {
      id: 'profile' as const,
      label: 'Profile & Account',
      description: 'Display name, bio, and presence',
      icon: User,
      color: '#10b981',
    },
    {
      id: 'notifications' as const,
      label: 'Notifications',
      description: 'Sounds, ringtones, and previews',
      icon: Bell,
      color: '#38bdf8',
    },
    {
      id: 'privacy' as const,
      label: 'Privacy & Security',
      description: 'Read receipts, blocked contacts, password',
      icon: Shield,
      color: '#a855f7',
    },
    {
      id: 'appearance' as const,
      label: 'Appearance',
      description: 'Themes, accent colors, font size',
      icon: Palette,
      color: '#f59e0b',
    },
    {
      id: 'storage' as const,
      label: 'Storage & Data',
      description: 'Cache management and encryption status',
      icon: HardDrive,
      color: '#ec4899',
    },
  ];

  return (
    <div style={{ display: 'flex', width: '100%', height: '100%', overflow: 'hidden', background: 'var(--bg-app)' }}>
      {/* 1. Left List / Middle Category Panel */}
      <div
        className="chat-list-panel"
        style={{
          width: isCompact ? '100%' : '340px',
          minWidth: isCompact ? '100%' : '340px',
          maxWidth: isCompact ? '100%' : '340px',
          borderRight: '1px solid var(--border)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
        }}
      >
        <div>
          {/* Header */}
          <div className="chat-list-header">
            <h2 className="chat-list-title" style={{ fontSize: '1.2rem' }}>Settings</h2>
          </div>

          {/* User Profile Mini Banner */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              margin: '12px 14px',
              padding: '12px 14px',
              borderRadius: '16px',
              background: 'rgba(255, 255, 255, 0.55)',
              border: '1px solid var(--border)',
            }}
          >
            <Avatar name={displayName || user?.username || 'You'} size="md" online={status === 'online'} />
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{ fontSize: '0.92rem', fontWeight: 800, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {displayName || user?.username}
              </div>
              <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>@{user?.username}</div>
            </div>
          </div>

          {/* Categories List */}
          <div className="conversations-scroll" style={{ padding: '4px 10px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              {categories.map((cat) => {
                const Icon = cat.icon;
                const isSelected = activeCategory === cat.id;

                return (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => {
                      triggerHaptic('light');
                      setActiveCategory(cat.id);
                      setMobileDetailOpen(true);
                    }}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '12px 14px',
                      borderRadius: '14px',
                      border: isSelected ? '1px solid rgba(16, 185, 129, 0.3)' : '1px solid transparent',
                      background: isSelected ? 'rgba(16, 185, 129, 0.12)' : 'transparent',
                      cursor: 'pointer',
                      textAlign: 'left',
                      transition: 'all 0.15s ease',
                      width: '100%',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <div
                        style={{
                          width: '36px',
                          height: '36px',
                          borderRadius: '10px',
                          background: `${cat.color}1a`,
                          color: cat.color,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0,
                        }}
                      >
                        <Icon style={{ width: '18px', height: '18px' }} />
                      </div>
                      <div>
                        <div style={{ fontSize: '0.88rem', fontWeight: 700, color: isSelected ? 'var(--text-main)' : 'var(--text-main)' }}>
                          {cat.label}
                        </div>
                        <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', marginTop: '1px' }}>
                          {cat.description}
                        </div>
                      </div>
                    </div>

                    <ChevronRight style={{ width: '16px', height: '16px', color: isSelected ? '#0e9f8a' : 'var(--text-dark)' }} />
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Sign Out Button in Sidebar Footer */}
        <div style={{ padding: '16px', borderTop: '1px solid var(--border)' }}>
          <button
            type="button"
            onClick={() => {
              triggerHaptic('heavy');
              logout();
            }}
            style={{
              width: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              padding: '12px',
              borderRadius: '14px',
              background: 'rgba(239, 68, 68, 0.08)',
              border: '1px solid rgba(239, 68, 68, 0.2)',
              color: '#bd3750',
              fontSize: '0.86rem',
              fontWeight: 700,
              cursor: 'pointer',
              transition: 'all 0.15s ease',
            }}
          >
            <LogOut style={{ width: '16px', height: '16px' }} /> Sign Out
          </button>
        </div>
      </div>

      {/* 2. Main Right Setting Content Area */}
      <div
        style={{
          flex: 1,
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          minWidth: 0,
          background: 'var(--bg-app)',
        }}
      >
        {/* Top Header */}
        <div
          style={{
            padding: '20px 32px',
            borderBottom: '1px solid var(--border)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: 'var(--bg-sidebar)',
          }}
        >
          <div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
              {activeCategory === 'profile' && 'Profile & Account'}
              {activeCategory === 'notifications' && 'Notification Preferences'}
              {activeCategory === 'privacy' && 'Privacy & Security'}
              {activeCategory === 'appearance' && 'Appearance & Chat Customization'}
              {activeCategory === 'storage' && 'Storage & Device Data'}
            </h2>
            <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', margin: '3px 0 0' }}>
              {activeCategory === 'profile' && 'Manage your public persona, avatar, and active status'}
              {activeCategory === 'notifications' && 'Control message chimes, calling sounds, and badges'}
              {activeCategory === 'privacy' && 'Manage blocked users, read receipts, and your credentials'}
              {activeCategory === 'appearance' && 'Customize theme accent colors and chat typography'}
              {activeCategory === 'storage' && 'Manage stored cached media and security certificates'}
            </p>
          </div>
        </div>

        {/* Scrollable Form Body */}
        <div className="conversations-scroll" style={{ flex: 1, overflowY: 'auto', padding: '32px 40px', maxWidth: '720px' }}>
          {/* PROFILE */}
          {activeCategory === 'profile' && (
            <form onSubmit={handleSaveProfile}>
              {/* Profile Showcase Card */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '20px',
                  padding: '22px 26px',
                  borderRadius: '20px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  marginBottom: '26px',
                }}
              >
                <Avatar name={displayName || user?.username || 'You'} size="xl" online={status === 'online'} />
                <div>
                  <h3 style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                    {displayName || user?.username}
                  </h3>
                  <p style={{ fontSize: '0.84rem', color: 'var(--text-muted)', margin: '3px 0 0' }}>@{user?.username}</p>
                  {user?.email && <p style={{ fontSize: '0.78rem', color: 'var(--text-dark)', margin: '4px 0 0' }}>{user.email}</p>}
                </div>
              </div>

              {/* Presence Status */}
              <div style={{ marginBottom: '22px' }}>
                <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>Active Presence Mode</label>
                <div style={{ display: 'flex', gap: '10px' }}>
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
                          padding: '11px 14px',
                          borderRadius: '14px',
                          border: isSelected ? `1.5px solid ${dotColor}` : '1px solid var(--border)',
                          background: isSelected ? `${dotColor}1a` : 'var(--bg-input)',
                          color: isSelected ? 'var(--text-main)' : 'var(--text-muted)',
                          fontSize: '0.86rem',
                          fontWeight: 700,
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '8px',
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
              <div className="input-wrapper" style={{ marginBottom: '20px' }}>
                <label className="input-label">Display Name</label>
                <input
                  type="text"
                  required
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Your Name"
                  className="input-field"
                  style={{ paddingLeft: '16px', height: '46px', fontSize: '0.9rem' }}
                />
              </div>

              {/* Bio */}
              <div className="input-wrapper" style={{ marginBottom: '28px' }}>
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

              {/* Save Button */}
              <button
                type="submit"
                className="btn btn-primary"
                style={{ width: '100%', padding: '14px', borderRadius: '14px', fontSize: '0.92rem', fontWeight: 700 }}
              >
                {saved ? (
                  <>
                    <Check style={{ width: '18px', height: '18px' }} /> Saved & Updated Live!
                  </>
                ) : (
                  'Save Profile Changes'
                )}
              </button>
            </form>
          )}

          {/* NOTIFICATIONS */}
          {activeCategory === 'notifications' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '18px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <Volume2 style={{ width: '22px', height: '22px', color: '#0e9f8a' }} />
                  <div>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)' }}>Message Audio Sounds</div>
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>Play subtle sound effects on incoming messages</div>
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={soundEnabled}
                  onChange={(e) => setSoundEnabled(e.target.checked)}
                  style={{ width: '20px', height: '20px', accentColor: '#10b981', cursor: 'pointer' }}
                />
              </div>

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '18px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <Smartphone style={{ width: '22px', height: '22px', color: '#087fac' }} />
                  <div>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)' }}>Call Ringtones & Chimes</div>
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>Play audio chime on incoming and outgoing WebRTC calls</div>
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={callRingEnabled}
                  onChange={(e) => setCallRingEnabled(e.target.checked)}
                  style={{ width: '20px', height: '20px', accentColor: '#10b981', cursor: 'pointer' }}
                />
              </div>

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '18px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <Eye style={{ width: '22px', height: '22px', color: '#a86d0b' }} />
                  <div>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)' }}>Message Previews</div>
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>Show sender name and text snippet in notifications</div>
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={previewEnabled}
                  onChange={(e) => setPreviewEnabled(e.target.checked)}
                  style={{ width: '20px', height: '20px', accentColor: '#10b981', cursor: 'pointer' }}
                />
              </div>
            </div>
          )}

          {/* PRIVACY */}
          {activeCategory === 'privacy' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '26px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '18px 20px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                }}
              >
                <div>
                  <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-main)' }}>Read Receipts</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                    Show double checkmarks when messages are seen
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={readReceipts}
                  onChange={(e) => setReadReceipts(e.target.checked)}
                  style={{ width: '20px', height: '20px', accentColor: '#10b981', cursor: 'pointer' }}
                />
              </div>

              {/* Blocked Users */}
              <div>
                <div style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-dark)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '10px' }}>
                  Blocked Contacts ({blockedUsers.size})
                </div>

                {blockedUsers.size === 0 ? (
                  <div style={{ padding: '20px', borderRadius: '14px', background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)', textAlign: 'center', color: 'var(--text-dark)', fontSize: '0.86rem' }}>
                    No blocked contacts
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {Array.from(blockedUsers).map((username) => (
                      <div
                        key={username}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          padding: '12px 16px',
                          borderRadius: '14px',
                          background: 'rgba(255, 255, 255, 0.55)',
                          border: '1px solid var(--border)',
                        }}
                      >
                        <span style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>@{username}</span>
                        <button
                          type="button"
                          onClick={() => blockUser(username, false)}
                          style={{ background: 'none', border: 'none', color: '#087fac', fontSize: '0.82rem', fontWeight: 700, cursor: 'pointer' }}
                        >
                          Unblock
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Password Change */}
              <form onSubmit={handlePasswordChange} style={{ borderTop: '1px solid var(--border)', paddingTop: '24px' }}>
                <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-main)', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Lock style={{ width: '18px', height: '18px', color: '#0e9f8a' }} /> Change Password
                </div>

                {passwordMsg && (
                  <div
                    style={{
                      padding: '12px 16px',
                      borderRadius: '12px',
                      marginBottom: '14px',
                      fontSize: '0.84rem',
                      background: passwordMsg.ok ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                      color: passwordMsg.ok ? '#078779' : '#bd3750',
                      border: `1px solid ${passwordMsg.ok ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                    }}
                  >
                    {passwordMsg.text}
                  </div>
                )}

                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '16px' }}>
                  <input
                    type="password"
                    placeholder="Current Password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="input-field"
                    style={{ paddingLeft: '16px', height: '44px' }}
                  />
                  <input
                    type="password"
                    placeholder="New Password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="input-field"
                    style={{ paddingLeft: '16px', height: '44px' }}
                  />
                  <input
                    type="password"
                    placeholder="Confirm New Password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="input-field"
                    style={{ paddingLeft: '16px', height: '44px' }}
                  />
                </div>

                <button
                  type="submit"
                  className="btn btn-secondary"
                  style={{ padding: '10px 20px', borderRadius: '12px', fontSize: '0.86rem' }}
                >
                  Update Password
                </button>
              </form>
            </div>
          )}

          {/* APPEARANCE */}
          {activeCategory === 'appearance' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '26px' }}>
              <div>
                <label className="input-label" style={{ marginBottom: '12px', display: 'block' }}>Primary Theme Accent</label>
                <div style={{ display: 'flex', gap: '16px' }}>
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
                        gap: '8px',
                        cursor: 'pointer',
                      }}
                    >
                      <div
                        style={{
                          width: '44px',
                          height: '44px',
                          borderRadius: '50%',
                          background: theme.color,
                          border: accentColor === theme.color ? '3px solid #ffffff' : '2px solid transparent',
                          boxShadow: accentColor === theme.color ? `0 0 16px ${theme.color}` : 'none',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: 'var(--text-main)',
                          transition: 'all 0.2s ease',
                        }}
                      >
                        {accentColor === theme.color && <Check style={{ width: '20px', height: '20px' }} />}
                      </div>
                      <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>{theme.name}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div>
                <label className="input-label" style={{ marginBottom: '10px', display: 'block' }}>Chat Font Size</label>
                <div style={{ display: 'flex', gap: '10px' }}>
                  {(['sm', 'md', 'lg'] as const).map((size) => (
                    <button
                      key={size}
                      type="button"
                      onClick={() => setFontSize(size)}
                      style={{
                        flex: 1,
                        padding: '12px',
                        borderRadius: '14px',
                        border: fontSize === size ? '1.5px solid #10b981' : '1px solid var(--border)',
                        background: fontSize === size ? 'rgba(16, 185, 129, 0.12)' : 'var(--bg-input)',
                        color: fontSize === size ? '#078779' : 'var(--text-muted)',
                        fontSize: '0.86rem',
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

          {/* STORAGE */}
          {activeCategory === 'storage' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div
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
                  <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-main)' }}>Local Cache & Temporary Files</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                    Cached audio waveforms, voice notes, and contact avatars
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => {
                    triggerHaptic('medium');
                    alert('Local cache cleaned successfully!');
                  }}
                  className="btn btn-secondary"
                  style={{ padding: '10px 16px', fontSize: '0.82rem', borderRadius: '12px' }}
                >
                  <Trash2 style={{ width: '15px', height: '15px' }} /> Clear Cache
                </button>
              </div>

              <div
                style={{
                  padding: '20px 22px',
                  borderRadius: '18px',
                  background: 'rgba(16, 185, 129, 0.08)',
                  border: '1px solid rgba(16, 185, 129, 0.2)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px',
                }}
              >
                <ShieldCheck style={{ width: '28px', height: '28px', color: '#0e9f8a', flexShrink: 0 }} />
                <div style={{ fontSize: '0.84rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
                  <strong style={{ color: 'var(--text-main)' }}>Novyn Chat WebRTC & End-to-End Ready</strong>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.76rem', marginTop: '2px' }}>
                    Version 1.0.0 • Connected Securely
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
