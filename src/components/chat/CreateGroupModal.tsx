import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Users, X, Check, Search, Plus, Loader2 } from 'lucide-react';
import { useChat } from '../../context/ChatContext';
import { Avatar } from '../ui/Avatar';
import { triggerHaptic } from '../../services/capacitor';

interface CreateGroupModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const CreateGroupModal: React.FC<CreateGroupModalProps> = ({ isOpen, onClose }) => {
  const { conversations, createGroup } = useChat();
  const [groupName, setGroupName] = useState('');
  const [selectedMembers, setSelectedMembers] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  if (!isOpen) return null;

  // Filter only direct friend conversations (not other groups)
  const availableFriends = conversations.filter((c) => !c.isGroup);

  const filteredFriends = availableFriends.filter((f) => {
    const q = searchQuery.toLowerCase();
    return (
      f.username.toLowerCase().includes(q) ||
      (f.displayName && f.displayName.toLowerCase().includes(q))
    );
  });

  const toggleMember = (username: string) => {
    triggerHaptic('light');
    setSelectedMembers((prev) =>
      prev.includes(username) ? prev.filter((u) => u !== username) : [...prev, username]
    );
    setErrorMsg('');
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    const name = groupName.trim();
    if (!name) {
      setErrorMsg('Please enter a group name.');
      return;
    }
    if (selectedMembers.length === 0) {
      setErrorMsg('Please select at least 1 friend to create a group.');
      return;
    }

    setIsSubmitting(true);
    triggerHaptic('medium');

    try {
      createGroup(name, selectedMembers);
      triggerHaptic('success');
      onClose();
    } catch (err) {
      setErrorMsg('Failed to create group. Try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return createPortal(
    <AnimatePresence>
      <div
        className="create-group-overlay"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '16px',
        }}
        onClick={onClose}
      >
        <motion.div
          className="create-group-modal"
          initial={{ opacity: 0, scale: 0.95, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 12 }}
          transition={{ duration: 0.16 }}
          style={{
            width: '100%',
            maxWidth: '460px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '24px',
            boxShadow: '0 25px 50px -12px rgba(36, 76, 96, 0.1)',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '18px',
            maxHeight: '90vh',
            overflow: 'hidden',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div
                style={{
                  width: '38px',
                  height: '38px',
                  borderRadius: '12px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  border: '1px solid rgba(16, 185, 129, 0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#0e9f8a',
                }}
              >
                <Users style={{ width: '20px', height: '20px' }} />
              </div>
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                  Create New Group
                </h3>
                <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>
                  {selectedMembers.length} member{selectedMembers.length === 1 ? '' : 's'} selected
                </span>
              </div>
            </div>
            <button
              type="button"
              onClick={onClose}
              style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>

          <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: '16px', overflow: 'hidden' }}>
            {/* Group Name Input */}
            <div>
              <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '6px' }}>
                GROUP NAME
              </label>
              <input
                className="create-group-input"
                type="text"
                value={groupName}
                onChange={(e) => {
                  setGroupName(e.target.value);
                  setErrorMsg('');
                }}
                placeholder="e.g. Study Squad, Project Novyn, Friends"
                maxLength={48}
                style={{
                  width: '100%',
                  padding: '11px 14px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  borderRadius: '12px',
                  color: 'var(--text-main)',
                  fontSize: '0.9rem',
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
              />
            </div>

            {/* Members Search */}
            <div>
              <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '6px' }}>
                ADD MEMBERS
              </label>
              <div
                className="create-group-search"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '8px 12px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  borderRadius: '10px',
                  marginBottom: '10px',
                }}
              >
                <Search style={{ width: '14px', height: '14px', color: 'var(--text-muted)' }} />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search your contacts..."
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: 'var(--text-main)',
                    fontSize: '0.82rem',
                    outline: 'none',
                    width: '100%',
                  }}
                />
              </div>

              {/* Friends List Container */}
              <div
                style={{
                  maxHeight: '180px',
                  overflowY: 'auto',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '6px',
                  paddingRight: '4px',
                }}
              >
                {filteredFriends.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '16px', color: 'var(--text-dark)', fontSize: '0.82rem' }}>
                    {availableFriends.length === 0 ? 'Add friends first to start a group chat.' : 'No matching contacts.'}
                  </div>
                ) : (
                  filteredFriends.map((friend) => {
                    const isSelected = selectedMembers.includes(friend.username);
                    return (
                      <div
                        className={`create-group-member ${isSelected ? 'is-selected' : ''}`}
                        key={friend.username}
                        onClick={() => toggleMember(friend.username)}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          padding: '8px 12px',
                          borderRadius: '10px',
                          background: isSelected ? 'rgba(16, 185, 129, 0.12)' : 'rgba(255, 255, 255, 0.55)',
                          border: `1px solid ${isSelected ? 'rgba(16, 185, 129, 0.3)' : 'transparent'}`,
                          cursor: 'pointer',
                          transition: 'all 0.15s ease',
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <Avatar
                            name={friend.displayName || friend.username}
                            avatarUrl={friend.avatarId}
                            online={friend.online}
                            size="sm"
                          />
                          <div>
                            <div style={{ fontSize: '0.84rem', fontWeight: 700, color: 'var(--text-main)' }}>
                              {friend.displayName || friend.username}
                            </div>
                            <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
                              @{friend.username}
                            </div>
                          </div>
                        </div>

                        <div
                          style={{
                            width: '22px',
                            height: '22px',
                            borderRadius: '6px',
                            background: isSelected ? '#10b981' : 'rgba(255, 255, 255, 0.55)',
                            border: `1px solid ${isSelected ? '#10b981' : 'var(--border)'}`,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'var(--text-main)',
                            transition: 'all 0.15s ease',
                          }}
                        >
                          {isSelected && <Check style={{ width: '14px', height: '14px' }} />}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>

            {errorMsg && (
              <div style={{ fontSize: '0.78rem', color: '#ef4444', fontWeight: 600 }}>
                {errorMsg}
              </div>
            )}

            {/* Actions */}
            <div className="create-group-actions" style={{ display: 'flex', gap: '10px', marginTop: '4px' }}>
              <button
                type="button"
                onClick={onClose}
                style={{
                  flex: 1,
                  padding: '11px',
                  borderRadius: '12px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  color: 'var(--text-muted)',
                  fontSize: '0.86rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                }}
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting || !groupName.trim() || selectedMembers.length === 0}
                style={{
                  flex: 2,
                  padding: '11px',
                  borderRadius: '12px',
                  background: '#10b981',
                  border: 'none',
                  color: 'var(--text-on-primary)',
                  fontSize: '0.86rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  opacity: !groupName.trim() || selectedMembers.length === 0 || isSubmitting ? 0.5 : 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                }}
              >
                {isSubmitting ? (
                  <Loader2 style={{ width: '16px', height: '16px', animation: 'spin 1s linear infinite' }} />
                ) : (
                  <>
                    <Plus style={{ width: '16px', height: '16px' }} /> Create Group
                  </>
                )}
              </button>
            </div>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>,
    document.body
  );
};
