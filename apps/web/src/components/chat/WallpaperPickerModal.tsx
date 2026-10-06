import React, { useState, useRef } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Check, X, Sparkles, Upload, Link as LinkIcon, Loader2 } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { apiRequest, uploadMediaFile } from '../../services/api';

export interface WallpaperPreset {
  id: string;
  name: string;
  background: string;
  preview: string;
}

// Helper to reliably encode SVG to data URI without breakage
const encodeSvg = (svg: string) => `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg.trim())}`;

// 1. WhatsApp-style Chat Doodles (High contrast, clearly visible vector motifs)
const WHATSAPP_DOODLES = encodeSvg(`
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120" fill="none" stroke="rgba(255,255,255,0.22)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <!-- Chat Bubble -->
  <path d="M15 20h26a6 6 0 0 1 6 6v14a6 6 0 0 1-6 6H25l-7 6v-6h-3a6 6 0 0 1-6-6V26a6 6 0 0 1 6-6z"/>
  <!-- Heart -->
  <path d="M85 22c-3-4-8-4-11 0l-1 1-1-1c-3-4-8-4-11 0-4 4-2 10 3 14l9 8 9-8c5-4 7-10 3-14z"/>
  <!-- Smiley -->
  <circle cx="28" cy="85" r="14"/>
  <circle cx="23" cy="82" r="1.5" fill="rgba(255,255,255,0.4)"/>
  <circle cx="33" cy="82" r="1.5" fill="rgba(255,255,255,0.4)"/>
  <path d="M22 89c2 3 10 3 12 0"/>
  <!-- Coffee Cup -->
  <path d="M75 75h22v14a6 6 0 0 1-6 6H81a6 6 0 0 1-6-6V75z"/>
  <path d="M97 78h4a3 3 0 0 1 3 3v2a3 3 0 0 1-3 3h-4"/>
  <path d="M80 68c0-3 3-4 3-6m6 6c0-3 3-4 3-6"/>
  <!-- Star & Sparkles -->
  <polygon points="105,25 107,31 113,31 108,35 110,41 105,37 100,41 102,35 97,31 103,31" fill="rgba(255,255,255,0.15)"/>
  <path d="M55 85l3-3m-3 0l3 3"/>
  <!-- Paper Airplane -->
  <path d="M70 45l30-15-12 28-6-8-12-5z"/>
</svg>
`);

// 2. Cosmic Galaxy & Space Doodles
const COSMIC_DOODLES = encodeSvg(`
<svg xmlns="http://www.w3.org/2000/svg" width="130" height="130" viewBox="0 0 130 130" fill="none" stroke="rgba(168,85,247,0.3)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <!-- Saturn Planet -->
  <circle cx="40" cy="40" r="15"/>
  <ellipse cx="40" cy="40" rx="26" ry="8" transform="rotate(-25 40 40)"/>
  <!-- Moon Crescent -->
  <path d="M95 20a14 14 0 1 0 14 14 11 11 0 0 1-14-14z"/>
  <!-- Rocket -->
  <path d="M35 105l8-8a15 15 0 0 0 4-11l-1-6-6-1a15 15 0 0 0-11 4l-8 8 3 8 3 3 8 3z"/>
  <circle cx="38" cy="92" r="2" fill="rgba(168,85,247,0.5)"/>
  <!-- Constellations & Stars -->
  <polygon points="95,80 97,85 102,85 98,88 100,93 95,90 90,93 92,88 88,85 93,85" fill="rgba(168,85,247,0.25)"/>
  <circle cx="80" cy="115" r="2" fill="rgba(255,255,255,0.5)"/>
  <circle cx="115" cy="70" r="1.5" fill="rgba(255,255,255,0.5)"/>
  <circle cx="15" cy="20" r="2" fill="rgba(255,255,255,0.5)"/>
  <path d="M100 105l8-8m-8 0l8 8"/>
</svg>
`);

// 3. Matrix & Cyber Tech Circuit Doodles
const TECH_DOODLES = encodeSvg(`
<svg xmlns="http://www.w3.org/2000/svg" width="110" height="110" viewBox="0 0 110 110" fill="none" stroke="rgba(16,185,129,0.32)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <!-- Microchip -->
  <rect x="20" y="20" width="26" height="26" rx="4"/>
  <path d="M26 14v6m8-6v6m8-6v6M26 46v6m8-6v6m8-6v6M14 26h6m-6 8h6m-6 8h6M46 26h6m-6 8h6m-6 8h6"/>
  <!-- Circuit Nodes -->
  <circle cx="85" cy="30" r="5"/>
  <path d="M46 34h25l9-9"/>
  <circle cx="80" cy="80" r="6"/>
  <path d="M33 46v30h35"/>
  <!-- Lightning Bolt -->
  <polygon points="25,75 35,75 30,95 45,82 35,82 38,70" fill="rgba(16,185,129,0.2)"/>
  <!-- Hexagon Node -->
  <polygon points="90,55 98,60 98,70 90,75 82,70 82,60"/>
</svg>
`);

// 4. Retro Arcade & 8-Bit Gaming Doodles
const ARCADE_DOODLES = encodeSvg(`
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120" fill="none" stroke="rgba(236,72,153,0.32)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <!-- Gamepad Controller -->
  <rect x="20" y="25" width="45" height="28" rx="8"/>
  <path d="M28 39h10m-5-5v10"/>
  <circle cx="53" cy="36" r="2" fill="rgba(236,72,153,0.5)"/>
  <circle cx="58" cy="42" r="2" fill="rgba(236,72,153,0.5)"/>
  <!-- Pixel Ghost -->
  <path d="M80 40a12 12 0 0 1 24 0v16l-4-3-4 3-4-3-4 3-4-3-4 3V40z"/>
  <circle cx="87" cy="38" r="1.5" fill="rgba(255,255,255,0.6)"/>
  <circle cx="97" cy="38" r="1.5" fill="rgba(255,255,255,0.6)"/>
  <!-- Gem Diamond -->
  <polygon points="35,80 48,80 55,90 35,105 15,90 22,80"/>
  <!-- Arcade Joystick -->
  <rect x="80" y="90" width="24" height="16" rx="4"/>
  <path d="M92 90V75"/>
  <circle cx="92" cy="72" r="5" fill="rgba(236,72,153,0.3)"/>
</svg>
`);

// 5. Minimal Geometric & Neon Doodles
const GEOMETRIC_DOODLES = encodeSvg(`
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100" fill="none" stroke="rgba(56,189,248,0.3)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <!-- Isometric Cube -->
  <path d="M30 20l20-10 20 10-20 10-20-10z"/>
  <path d="M30 20v22l20 10V40L30 20z"/>
  <path d="M70 20v22l-20 10V40l20-20z"/>
  <!-- Concentric Rings -->
  <circle cx="30" cy="75" r="14"/>
  <circle cx="30" cy="75" r="6"/>
  <!-- Geometric Prism -->
  <polygon points="75,60 90,88 60,88"/>
  <path d="M75 60v28"/>
</svg>
`);

export const WALLPAPER_PRESETS: WallpaperPreset[] = [
  {
    id: 'default',
    name: 'Classic Dark',
    background: 'var(--bg-canvas)',
    preview: '#0b0f19',
  },
  {
    id: 'whatsapp_doodle',
    name: 'Chat Doodles',
    background: `#0b1120 url("${WHATSAPP_DOODLES}") repeat`,
    preview: `#0b1120 url("${WHATSAPP_DOODLES}") repeat`,
  },
  {
    id: 'cosmic_doodle',
    name: 'Cosmic Space',
    background: `#0f0e21 url("${COSMIC_DOODLES}") repeat`,
    preview: `#0f0e21 url("${COSMIC_DOODLES}") repeat`,
  },
  {
    id: 'emerald_tech',
    name: 'Matrix Tech',
    background: `#021a14 url("${TECH_DOODLES}") repeat`,
    preview: `#021a14 url("${TECH_DOODLES}") repeat`,
  },
  {
    id: 'arcade_doodle',
    name: 'Retro Arcade',
    background: `#1b071e url("${ARCADE_DOODLES}") repeat`,
    preview: `#1b071e url("${ARCADE_DOODLES}") repeat`,
  },
  {
    id: 'cyber_geometric',
    name: 'Neon Geometry',
    background: `#061224 url("${GEOMETRIC_DOODLES}") repeat`,
    preview: `#061224 url("${GEOMETRIC_DOODLES}") repeat`,
  },
];

interface WallpaperPickerModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentWallpaper: string;
  onSelectWallpaper: (bg: string) => void;
}

export const WallpaperPickerModal: React.FC<WallpaperPickerModalProps> = ({
  isOpen,
  onClose,
  currentWallpaper,
  onSelectWallpaper,
}) => {
  const [customUrl, setCustomUrl] = useState('');
  const [isResolving, setIsResolving] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleApplyUrl = async () => {
    const raw = customUrl.trim();
    if (!raw) return;

    setIsResolving(true);
    triggerHaptic('light');

    try {
      // Call backend wallpaper resolver (handles Pinterest oEmbed, OpenGraph, and caches directly on server)
      const res = await apiRequest('/api/import-wallpaper-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: raw }),
      });

      let finalImgUrl = raw;
      if (res.ok) {
        const data = res.data;
        if (data.url) {
          finalImgUrl = data.url;
        }
      }

      const bg = `url("${finalImgUrl}") center/cover no-repeat`;
      onSelectWallpaper(bg);
      setCustomUrl('');
      triggerHaptic('success');
      onClose();
    } catch (_) {
      const bg = `url("${raw}") center/cover no-repeat`;
      onSelectWallpaper(bg);
      onClose();
    } finally {
      setIsResolving(false);
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsUploading(true);
    triggerHaptic('medium');

    try {
      const res = await uploadMediaFile(file);
      if (res?.url) {
        const bg = `url("${res.url}") center/cover no-repeat`;
        onSelectWallpaper(bg);
        triggerHaptic('success');
        onClose();
      }
    } catch (err) {
      console.error('Wallpaper upload error:', err);
    } finally {
      setIsUploading(false);
    }
  };

  return createPortal(
    <AnimatePresence>
      <div
        className="chat-option-overlay wallpaper-picker-overlay"
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
          className="chat-option-modal wallpaper-picker-modal"
          initial={{ opacity: 0, scale: 0.95, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 12 }}
          transition={{ duration: 0.16 }}
          style={{
            width: '100%',
            maxWidth: '480px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '24px',
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
                  background: 'rgba(236, 72, 153, 0.15)',
                  border: '1px solid rgba(236, 72, 153, 0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#ec4899',
                }}
              >
                <Sparkles style={{ width: '18px', height: '18px' }} />
              </div>
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                  Chat Wallpaper & Theme
                </h3>
                <span style={{ fontSize: '0.74rem', color: 'var(--text-muted)' }}>
                  Syncs in real-time across both participants
                </span>
              </div>
            </div>
            <button
              className="chat-option-close"
              type="button"
              onClick={onClose}
              style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>

          {/* Presets Grid */}
          <div>
            <label style={{ display: 'block', fontSize: '0.74rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '8px' }}>
              DOODLE & ILLUSTRATED PATTERNS
            </label>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
              {WALLPAPER_PRESETS.map((preset) => {
                const isSelected = currentWallpaper === preset.background;
                return (
                  <div
                    key={preset.id}
                    onClick={() => {
                      triggerHaptic('light');
                      onSelectWallpaper(preset.background);
                    }}
                    style={{
                      height: '84px',
                      borderRadius: '14px',
                      background: preset.preview,
                      border: `2px solid ${isSelected ? '#10b981' : 'var(--border)'}`,
                      boxShadow: isSelected ? '0 0 16px rgba(16, 185, 129, 0.45)' : 'none',
                      cursor: 'pointer',
                      position: 'relative',
                      overflow: 'hidden',
                      display: 'flex',
                      alignItems: 'flex-end',
                      padding: '8px',
                      transition: 'all 0.15s ease',
                    }}
                  >
                    <span style={{ fontSize: '0.72rem', fontWeight: 800, color: 'var(--text-main)', textShadow: '0 2px 4px rgba(36, 76, 96, 0.1)' }}>
                      {preset.name}
                    </span>
                    {isSelected && (
                      <div
                        style={{
                          position: 'absolute',
                          top: '6px',
                          right: '6px',
                          width: '18px',
                          height: '18px',
                          borderRadius: '50%',
                          background: '#10b981',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: 'var(--text-on-primary)',
                        }}
                      >
                        <Check style={{ width: '12px', height: '12px' }} />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Custom Upload or URL */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <label style={{ fontSize: '0.74rem', fontWeight: 700, color: 'var(--text-muted)' }}>
              CUSTOM WALLPAPER (DEVICE UPLOAD OR LINK)
            </label>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleFileUpload}
            />

            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploading}
                style={{
                  flex: 1,
                  padding: '10px 14px',
                  borderRadius: '12px',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  color: 'var(--text-main)',
                  fontSize: '0.84rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  transition: 'background 0.15s ease',
                }}
              >
                {isUploading ? (
                  <>
                    <Loader2 style={{ width: '16px', height: '16px', animation: 'spin 1s linear infinite' }} /> Uploading...
                  </>
                ) : (
                  <>
                    <Upload style={{ width: '16px', height: '16px', color: '#0e9f8a' }} /> Upload from Device
                  </>
                )}
              </button>
            </div>

            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="url"
                value={customUrl}
                onChange={(e) => setCustomUrl(e.target.value)}
                placeholder="Or paste Pinterest, Imgur, or direct image link..."
                style={{
                  flex: 1,
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  borderRadius: '10px',
                  padding: '9px 12px',
                  color: 'var(--text-main)',
                  fontSize: '0.84rem',
                  outline: 'none',
                }}
              />
              <button
                type="button"
                onClick={handleApplyUrl}
                disabled={!customUrl.trim() || isResolving}
                style={{
                  padding: '9px 16px',
                  borderRadius: '10px',
                  background: '#10b981',
                  border: 'none',
                  color: 'var(--text-on-primary)',
                  fontSize: '0.84rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  opacity: customUrl.trim() && !isResolving ? 1 : 0.5,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                }}
              >
                {isResolving ? (
                  <Loader2 style={{ width: '14px', height: '14px', animation: 'spin 1s linear infinite' }} />
                ) : (
                  <>
                    <LinkIcon style={{ width: '14px', height: '14px' }} /> Apply
                  </>
                )}
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>,
    document.body
  );
};
