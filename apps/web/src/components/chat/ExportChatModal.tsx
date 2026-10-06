import { getPreferredLocale } from '../../services/regionalPreferences';
import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Message } from '../../types';
import { Download, FileText, Code2, X, CheckCircle2 } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface ExportChatModalProps {
  isOpen: boolean;
  onClose: () => void;
  messages: Message[];
  contactName: string;
}

export const ExportChatModal: React.FC<ExportChatModalProps> = ({
  isOpen,
  onClose,
  messages,
  contactName,
}) => {
  const [format, setFormat] = useState<'txt' | 'json'>('txt');
  const [exported, setExported] = useState(false);

  if (!isOpen) return null;

  const handleExport = () => {
    triggerHaptic('success');
    let content = '';
    let filename = `Novyn-Chat-${contactName}-${new Date().toISOString().slice(0, 10)}`;

    if (format === 'json') {
      filename += '.json';
      content = JSON.stringify(
        {
          exportedAt: new Date().toISOString(),
          conversationWith: contactName,
          totalMessages: messages.length,
          messages,
        },
        null,
        2
      );
    } else {
      filename += '.txt';
      const lines = [
        `==================================================`,
        `  NOVYN CHAT TRANSCRIPT: ${contactName.toUpperCase()}`,
        `  Exported on: ${new Date().toLocaleString(getPreferredLocale())}`,
        `  Total Messages: ${messages.length}`,
        `==================================================\n`,
      ];

      messages.forEach((m) => {
        const timeStr = new Date(m.timestamp).toLocaleString(getPreferredLocale());
        const sender = m.sender;
        let body = m.text || '';
        if (m.isVoice) body = `[Voice Message] (${m.voiceDuration || 0}s)`;
        if (m.attachment) body += ` [Attachment: ${m.attachment.name || m.attachment.kind || 'File'} - ${m.attachment.url}]`;
        lines.push(`[${timeStr}] ${sender}: ${body}`);
      });

      content = lines.join('\n');
    }

    const blob = new Blob([content], {
      type: format === 'json' ? 'application/json' : 'text/plain;charset=utf-8',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    setExported(true);
    setTimeout(() => {
      setExported(false);
      onClose();
    }, 1200);
  };

  return (
    <AnimatePresence>
      <div
        className="chat-option-overlay export-chat-overlay"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 100,
          padding: '16px',
        }}
        onClick={onClose}
      >
        <motion.div
          className="chat-option-modal export-chat-modal"
          initial={{ opacity: 0, scale: 0.95, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 10 }}
          transition={{ duration: 0.15 }}
          style={{
            width: '100%',
            maxWidth: '420px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '20px',
            boxShadow: '0 25px 50px -12px rgba(36, 76, 96, 0.1)',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '18px',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div
                style={{
                  width: '36px',
                  height: '36px',
                  borderRadius: '10px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  border: '1px solid rgba(16, 185, 129, 0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#0e9f8a',
                }}
              >
                <Download style={{ width: '18px', height: '18px' }} />
              </div>
              <div>
                <h3 style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                  Export Chat History
                </h3>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                  {contactName} • {messages.length} messages
                </span>
              </div>
            </div>
            <button
              type="button"
              onClick={onClose}
              style={{
                background: 'none',
                border: 'none',
                color: 'var(--text-muted)',
                cursor: 'pointer',
                padding: '4px',
              }}
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>

          {/* Format Selection Cards */}
          <div style={{ display: 'flex', gap: '10px' }}>
            <div
              className={`export-format-card ${format === 'txt' ? 'is-selected' : ''}`}
              onClick={() => {
                triggerHaptic('light');
                setFormat('txt');
              }}
              style={{
                flex: 1,
                padding: '14px',
                borderRadius: '12px',
                background: format === 'txt' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(255, 255, 255, 0.55)',
                border: `1.5px solid ${format === 'txt' ? '#10b981' : 'var(--border)'}`,
                cursor: 'pointer',
                display: 'flex',
                flexDirection: 'column',
                gap: '6px',
                transition: 'all 0.15s ease',
              }}
            >
              <FileText style={{ width: '20px', height: '20px', color: format === 'txt' ? '#0e9f8a' : 'var(--text-muted)' }} />
              <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>Text (.txt)</span>
              <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>Readable chat log</span>
            </div>

            <div
              className={`export-format-card ${format === 'json' ? 'is-selected' : ''}`}
              onClick={() => {
                triggerHaptic('light');
                setFormat('json');
              }}
              style={{
                flex: 1,
                padding: '14px',
                borderRadius: '12px',
                background: format === 'json' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(255, 255, 255, 0.55)',
                border: `1.5px solid ${format === 'json' ? '#10b981' : 'var(--border)'}`,
                cursor: 'pointer',
                display: 'flex',
                flexDirection: 'column',
                gap: '6px',
                transition: 'all 0.15s ease',
              }}
            >
              <Code2 style={{ width: '20px', height: '20px', color: format === 'json' ? '#0e9f8a' : 'var(--text-muted)' }} />
              <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>JSON (.json)</span>
              <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>Structured backup</span>
            </div>
          </div>

          {/* Action Button */}
          <button
            className="chat-option-primary export-action"
            type="button"
            onClick={handleExport}
            style={{
              width: '100%',
              padding: '12px',
              borderRadius: '12px',
              background: exported ? '#10b981' : 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
              border: 'none',
              color: 'var(--text-main)',
              fontSize: '0.9rem',
              fontWeight: 800,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              boxShadow: '0 8px 20px rgba(16, 185, 129, 0.35)',
              transition: 'all 0.2s ease',
            }}
          >
            {exported ? (
              <>
                <CheckCircle2 style={{ width: '18px', height: '18px' }} /> Downloaded!
              </>
            ) : (
              <>
                <Download style={{ width: '18px', height: '18px' }} /> Download {format.toUpperCase()}
              </>
            )}
          </button>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
