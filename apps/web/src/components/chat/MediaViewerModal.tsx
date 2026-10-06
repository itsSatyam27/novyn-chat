import React, { useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Download, ExternalLink } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface MediaViewerModalProps {
  mediaUrl: string | null;
  onClose: () => void;
}

export const MediaViewerModal: React.FC<MediaViewerModalProps> = ({ mediaUrl, onClose }) => {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    if (mediaUrl) {
      window.addEventListener('keydown', handleKeyDown);
    }
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [mediaUrl, onClose]);

  return (
    <AnimatePresence>
      {mediaUrl && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            zIndex: 999999,
            backgroundColor: 'rgba(247, 254, 253, 0.92)',
            backdropFilter: 'blur(16px)',
            WebkitBackdropFilter: 'blur(16px)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '24px',
          }}
          onClick={onClose}
        >
          {/* Top Floating Control Bar */}
          <div
            style={{
              position: 'absolute',
              top: '24px',
              right: '28px',
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              zIndex: 1000000,
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <a
              href={mediaUrl}
              download
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => triggerHaptic('light')}
              style={{
                width: '44px',
                height: '44px',
                borderRadius: '50%',
                backgroundColor: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                textDecoration: 'none',
              }}
              title="Download image"
            >
              <Download style={{ width: '20px', height: '20px' }} />
            </a>

            <a
              href={mediaUrl}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => triggerHaptic('light')}
              style={{
                width: '44px',
                height: '44px',
                borderRadius: '50%',
                backgroundColor: 'rgba(255, 255, 255, 0.55)',
                border: '1px solid var(--border)',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                textDecoration: 'none',
              }}
              title="Open full size in new tab"
            >
              <ExternalLink style={{ width: '18px', height: '18px' }} />
            </a>

            <button
              type="button"
              onClick={() => {
                triggerHaptic('light');
                onClose();
              }}
              style={{
                width: '44px',
                height: '44px',
                borderRadius: '50%',
                backgroundColor: 'rgba(239, 68, 68, 0.85)',
                border: '1px solid var(--border)',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
              }}
              title="Close (Esc)"
            >
              <X style={{ width: '22px', height: '22px' }} />
            </button>
          </div>

          {/* Centered High-Res Image Preview */}
          <motion.div
            initial={{ scale: 0.88, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.88, opacity: 0 }}
            transition={{ type: 'spring', damping: 26, stiffness: 320 }}
            style={{
              maxWidth: '92vw',
              maxHeight: '86vh',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <img
              src={mediaUrl}
              alt="Preview"
              style={{
                maxWidth: '100%',
                maxHeight: '86vh',
                objectFit: 'contain',
                borderRadius: '16px',
                boxShadow: '0 25px 60px -12px rgba(36, 76, 96, 0.1), 0 0 0 1px rgba(255, 255, 255, 0.12)',
              }}
            />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};
