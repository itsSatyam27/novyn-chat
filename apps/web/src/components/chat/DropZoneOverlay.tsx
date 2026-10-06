import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { UploadCloud, File, Image as ImageIcon, X, Send } from 'lucide-react';
import { Attachment } from '../../types';
import { triggerHaptic } from '../../services/capacitor';

interface DropZoneOverlayProps {
  isDragging: boolean;
  onFileSelect: (file: File) => void;
}

export const DropZoneOverlay: React.FC<DropZoneOverlayProps> = ({ isDragging }) => {
  if (!isDragging) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.96 }}
        transition={{ duration: 0.15 }}
        style={{
          position: 'absolute',
          inset: '12px',
          borderRadius: '24px',
          background: 'rgba(247, 254, 253, 0.88)',
          backdropFilter: 'blur(16px)',
          border: '2px dashed #10b981',
          boxShadow: '0 0 40px rgba(16, 185, 129, 0.25)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '16px',
          zIndex: 50,
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            width: '64px',
            height: '64px',
            borderRadius: '20px',
            background: 'rgba(16, 185, 129, 0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#0e9f8a',
            boxShadow: '0 10px 25px rgba(16, 185, 129, 0.3)',
          }}
        >
          <UploadCloud style={{ width: '32px', height: '32px' }} />
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '4px' }}>
            Drop file to send
          </div>
          <div style={{ fontSize: '0.84rem', color: 'var(--text-muted)' }}>
            Photos, videos, audio notes, and documents
          </div>
        </div>
      </motion.div>
    </AnimatePresence>
  );
};
