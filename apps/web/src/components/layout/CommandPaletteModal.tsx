import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Search,
  MessageSquare,
  Phone,
  Video,
  BarChart3,
  Image as ImageIcon,
  QrCode,
  Download,
  Lock,
  Moon,
  Sparkles,
  X,
  CornerDownLeft,
} from 'lucide-react';
import { Conversation } from '../../types';
import { triggerHaptic } from '../../services/capacitor';

interface CommandItem {
  id: string;
  title: string;
  subtitle?: string;
  category: 'Chats' | 'Actions' | 'Settings';
  icon: React.ReactNode;
  action: () => void;
}

interface CommandPaletteModalProps {
  isOpen: boolean;
  onClose: () => void;
  conversations: Conversation[];
  activeChat: string | null;
  onSelectChat: (username: string) => void;
  onAudioCall: (username: string) => void;
  onVideoCall: (username: string) => void;
  onOpenPollModal: () => void;
  onOpenWallpaperModal: () => void;
  onOpenQRModal: () => void;
  onOpenExportModal: () => void;
  onOpenSearch: () => void;
}

export const CommandPaletteModal: React.FC<CommandPaletteModalProps> = ({
  isOpen,
  onClose,
  conversations,
  activeChat,
  onSelectChat,
  onAudioCall,
  onVideoCall,
  onOpenPollModal,
  onOpenWallpaperModal,
  onOpenQRModal,
  onOpenExportModal,
  onOpenSearch,
}) => {
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  // Build commands list
  const commands: CommandItem[] = [];

  // Active chat actions if in a conversation
  if (activeChat) {
    commands.push({
      id: 'action_audio_call',
      title: `Start Audio Call with ${activeChat}`,
      subtitle: 'Voice call via WebRTC',
      category: 'Actions',
      icon: <Phone style={{ width: '16px', height: '16px', color: '#0e9f8a' }} />,
      action: () => onAudioCall(activeChat),
    });
    commands.push({
      id: 'action_video_call',
      title: `Start Video Call with ${activeChat}`,
      subtitle: 'HD Video call with camera filters',
      category: 'Actions',
      icon: <Video style={{ width: '16px', height: '16px', color: '#2569b2' }} />,
      action: () => onVideoCall(activeChat),
    });
    commands.push({
      id: 'action_create_poll',
      title: 'Create Interactive Poll',
      subtitle: 'Ask a question with multiple live vote choices',
      category: 'Actions',
      icon: <BarChart3 style={{ width: '16px', height: '16px', color: '#a86d0b' }} />,
      action: () => onOpenPollModal(),
    });
    commands.push({
      id: 'action_search_chat',
      title: 'Search In Conversation',
      subtitle: 'Jump to message keyword matches',
      category: 'Actions',
      icon: <Search style={{ width: '16px', height: '16px', color: '#a855f7' }} />,
      action: () => onOpenSearch(),
    });
    commands.push({
      id: 'action_export_chat',
      title: 'Export Chat History',
      subtitle: 'Download transcript as .txt or .json',
      category: 'Actions',
      icon: <Download style={{ width: '16px', height: '16px', color: '#0e9f8a' }} />,
      action: () => onOpenExportModal(),
    });
  }

  // General Actions
  commands.push({
    id: 'action_wallpaper',
    title: 'Customize Chat Wallpaper',
    subtitle: 'Choose background theme or custom image',
    category: 'Settings',
    icon: <ImageIcon style={{ width: '16px', height: '16px', color: '#ec4899' }} />,
    action: () => onOpenWallpaperModal(),
  });
  commands.push({
    id: 'action_qr_code',
    title: 'Show My Profile QR Code',
    subtitle: 'Share your profile card for instant adding',
    category: 'Settings',
    icon: <QrCode style={{ width: '16px', height: '16px', color: '#087fac' }} />,
    action: () => onOpenQRModal(),
  });

  // Chats list
  conversations.forEach((c) => {
    commands.push({
      id: `chat_${c.username}`,
      title: c.displayName || c.username,
      subtitle: `@${c.username}${c.lastMessage ? ` • ${c.lastMessage}` : ''}`,
      category: 'Chats',
      icon: <MessageSquare style={{ width: '16px', height: '16px', color: 'var(--text-muted)' }} />,
      action: () => onSelectChat(c.username),
    });
  });

  // Filter commands
  const filtered = query.trim()
    ? commands.filter(
        (c) =>
          c.title.toLowerCase().includes(query.toLowerCase()) ||
          (c.subtitle && c.subtitle.toLowerCase().includes(query.toLowerCase())) ||
          c.category.toLowerCase().includes(query.toLowerCase())
      )
    : commands;

  useEffect(() => {
    if (isOpen) {
      setQuery('');
      setSelectedIndex(0);
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  // Keyboard navigation inside command palette
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev < filtered.length - 1 ? prev + 1 : 0));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev > 0 ? prev - 1 : filtered.length - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (filtered[selectedIndex]) {
        triggerHaptic('light');
        filtered[selectedIndex].action();
        onClose();
      }
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div
        className="command-palette-backdrop"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(12px)',
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'center',
          paddingTop: '12vh',
          zIndex: 200,
        }}
        onClick={onClose}
      >
        <motion.div
          className="command-palette"
          initial={{ opacity: 0, scale: 0.95, y: -20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: -20 }}
          transition={{ duration: 0.16 }}
          style={{
            width: '100%',
            maxWidth: '560px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '20px',
            boxShadow: '0 30px 60px -12px rgba(36, 76, 96, 0.1)',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Search Header */}
          <div
            className="command-palette-search"
            style={{
              display: 'flex',
              alignItems: 'center',
              padding: '14px 18px',
              borderBottom: '1px solid var(--border)',
              gap: '12px',
            }}
          >
            <Search className="command-palette-search-icon" style={{ width: '20px', height: '20px', color: '#0e9f8a', flexShrink: 0 }} />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Type a command or search contacts..."
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                color: 'var(--text-main)',
                fontSize: '0.98rem',
                outline: 'none',
              }}
            />
            <span
              className="command-palette-key"
              style={{
                fontSize: '0.72rem',
                color: 'var(--text-dark)',
                background: 'rgba(255, 255, 255, 0.55)',
                padding: '3px 6px',
                borderRadius: '6px',
                fontFamily: 'monospace',
              }}
            >
              ESC
            </span>
          </div>

          {/* Results List */}
          <div
            className="command-palette-results"
            style={{
              maxHeight: '360px',
              overflowY: 'auto',
              padding: '8px',
              display: 'flex',
              flexDirection: 'column',
              gap: '2px',
            }}
          >
            {filtered.length === 0 ? (
              <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-dark)', fontSize: '0.88rem' }}>
                No commands or contacts found
              </div>
            ) : (
              filtered.map((item, idx) => {
                const isSelected = idx === selectedIndex;
                const showCategory = idx === 0 || filtered[idx - 1]?.category !== item.category;
                return (
                  <React.Fragment key={item.id}>
                    {showCategory && <div className="command-palette-category">{item.category}</div>}
                    <div
                      className={`command-palette-row ${isSelected ? 'is-selected' : ''}`}
                      onMouseEnter={() => setSelectedIndex(idx)}
                      onClick={() => {
                        triggerHaptic('light');
                        item.action();
                        onClose();
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '12px',
                        padding: '10px 14px',
                        borderRadius: '12px',
                        background: isSelected ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                        border: isSelected ? '1px solid rgba(16, 185, 129, 0.3)' : '1px solid transparent',
                        cursor: 'pointer',
                        transition: 'all 0.1s ease',
                      }}
                    >
                    <div
                      className="command-palette-row-icon"
                      style={{
                        width: '32px',
                        height: '32px',
                        borderRadius: '8px',
                        background: 'rgba(255, 255, 255, 0.55)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      {item.icon}
                    </div>

                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {item.title}
                      </div>
                      {item.subtitle && (
                        <div style={{ fontSize: '0.74rem', color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {item.subtitle}
                        </div>
                      )}
                    </div>

                    {isSelected && (
                      <CornerDownLeft className="command-palette-enter" style={{ width: '14px', height: '14px', color: '#0e9f8a', flexShrink: 0 }} />
                    )}
                    </div>
                  </React.Fragment>
                );
              })
            )}
          </div>

          {/* Footer Info */}
          <div
            className="command-palette-footer"
            style={{
              padding: '8px 16px',
              borderTop: '1px solid var(--border)',
              background: 'rgba(23, 66, 78, 0.05)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              fontSize: '0.72rem',
              color: 'var(--text-dark)',
            }}
          >
            <div style={{ display: 'flex', gap: '12px' }}>
              <span>↑↓ Navigate</span>
              <span>↵ Select</span>
            </div>
            <span>Global Command Palette</span>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
