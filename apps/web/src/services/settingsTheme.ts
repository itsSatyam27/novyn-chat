// Settings Preferences and Dynamic Theme & Typography Engine

export interface ThemeConfig {
  id: string;
  name: string;
  description: string;
  accent: string;
  accentHover: string;
  accentGlow: string;
  soft: string;
  border: string;
  gradient: string;
}

export const THEME_PRESETS: Record<string, ThemeConfig> = {
  purple: {
    id: 'purple',
    name: 'Electric Violet',
    description: 'Signature vibrant violet glow',
    accent: '#6d5dfc',
    accentHover: '#5746e8',
    accentGlow: 'rgba(109, 93, 252, 0.28)',
    soft: 'rgba(109, 93, 252, 0.16)',
    border: 'rgba(109, 93, 252, 0.28)',
    gradient: 'linear-gradient(135deg, #6d5dfc 0%, #9d4edd 100%)',
  },
  emerald: {
    id: 'emerald',
    name: 'Emerald Mint',
    description: 'Fresh botanical green energy',
    accent: '#10b981',
    accentHover: '#059669',
    accentGlow: 'rgba(16, 185, 129, 0.28)',
    soft: 'rgba(16, 185, 129, 0.16)',
    border: 'rgba(16, 185, 129, 0.28)',
    gradient: 'linear-gradient(135deg, #10b981 0%, #06d6a0 100%)',
  },
  ocean: {
    id: 'ocean',
    name: 'Ocean Azure',
    description: 'Deep maritime & crystal blue',
    accent: '#0ea5e9',
    accentHover: '#0284c7',
    accentGlow: 'rgba(14, 165, 233, 0.28)',
    soft: 'rgba(14, 165, 233, 0.16)',
    border: 'rgba(14, 165, 233, 0.28)',
    gradient: 'linear-gradient(135deg, #0ea5e9 0%, #38bdf8 100%)',
  },
  rose: {
    id: 'rose',
    name: 'Neon Rose',
    description: 'Punchy vivid magenta-rose',
    accent: '#f43f5e',
    accentHover: '#e11d48',
    accentGlow: 'rgba(244, 63, 94, 0.28)',
    soft: 'rgba(244, 63, 94, 0.16)',
    border: 'rgba(244, 63, 94, 0.28)',
    gradient: 'linear-gradient(135deg, #f43f5e 0%, #fb7185 100%)',
  },
  amber: {
    id: 'amber',
    name: 'Sunset Amber',
    description: 'Warm twilight golden radiance',
    accent: '#f59e0b',
    accentHover: '#d97706',
    accentGlow: 'rgba(245, 158, 11, 0.28)',
    soft: 'rgba(245, 158, 11, 0.16)',
    border: 'rgba(245, 158, 11, 0.28)',
    gradient: 'linear-gradient(135deg, #f59e0b 0%, #fbbf24 100%)',
  },
  cyan: {
    id: 'cyan',
    name: 'Cyber Cyan',
    description: 'Futuristic electric cyan pulse',
    accent: '#06b6d4',
    accentHover: '#0891b2',
    accentGlow: 'rgba(6, 182, 212, 0.28)',
    soft: 'rgba(6, 182, 212, 0.16)',
    border: 'rgba(6, 182, 212, 0.28)',
    gradient: 'linear-gradient(135deg, #06b6d4 0%, #22d3ee 100%)',
  },
  crimson: {
    id: 'crimson',
    name: 'Crimson Ruby',
    description: 'Bold dynamic scarlet passion',
    accent: '#ef4444',
    accentHover: '#dc2626',
    accentGlow: 'rgba(239, 68, 68, 0.28)',
    soft: 'rgba(239, 68, 68, 0.16)',
    border: 'rgba(239, 68, 68, 0.28)',
    gradient: 'linear-gradient(135deg, #ef4444 0%, #f87171 100%)',
  },
  indigo: {
    id: 'indigo',
    name: 'Midnight Indigo',
    description: 'Sophisticated deep cosmic indigo',
    accent: '#4f46e5',
    accentHover: '#4338ca',
    accentGlow: 'rgba(79, 70, 229, 0.28)',
    soft: 'rgba(79, 70, 229, 0.16)',
    border: 'rgba(79, 70, 229, 0.28)',
    gradient: 'linear-gradient(135deg, #4f46e5 0%, #6366f1 100%)',
  },
  teal: {
    id: 'teal',
    name: 'Turquoise Teal',
    description: 'Calming balanced oceanic turquoise',
    accent: '#14b8a6',
    accentHover: '#0d9488',
    accentGlow: 'rgba(20, 184, 166, 0.28)',
    soft: 'rgba(20, 184, 166, 0.16)',
    border: 'rgba(20, 184, 166, 0.28)',
    gradient: 'linear-gradient(135deg, #14b8a6 0%, #2dd4bf 100%)',
  },
  slate: {
    id: 'slate',
    name: 'Titanium Slate',
    description: 'Minimalist industrial monochrome',
    accent: '#64748b',
    accentHover: '#475569',
    accentGlow: 'rgba(100, 116, 139, 0.28)',
    soft: 'rgba(100, 116, 139, 0.16)',
    border: 'rgba(100, 116, 139, 0.28)',
    gradient: 'linear-gradient(135deg, #64748b 0%, #94a3b8 100%)',
  },
};

// Original vector backdrops stay crisp at any chat size without remote image downloads.
function landscapeBackground(content: string, base: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600">${content}</svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}") center / cover no-repeat ${base}`;
}

export const WALLPAPER_PRESETS: Record<string, { name: string; background: string; description: string }> = {
  glass: {
    name: 'Lagoon Glass',
    background: 'radial-gradient(ellipse at 10% 10%, #b4d8fa40, transparent 65%), radial-gradient(ellipse at 90% 90%, #82dedb40, transparent 65%), var(--chat-surface-muted, #edf3fc)',
    description: 'Soft blue and mint colors with translucent surfaces',
  },
  midnight: {
    name: 'Midnight OLED',
    background: '#070a11',
    description: 'Ultra-deep pure black background',
  },
  aurora: {
    name: 'Emerald Aurora',
    background: 'radial-gradient(ellipse at 80% 0%, #3d8b8155, transparent 65%), radial-gradient(ellipse at 0% 100%, #235b5355, transparent 70%), #0a1922',
    description: 'Quiet ribbons of emerald light over deep teal',
  },
  cosmic: {
    name: 'Cosmic Nebula',
    background: 'radial-gradient(ellipse at 85% 10%, #9c65ce55, transparent 65%), radial-gradient(ellipse at 0% 100%, #46479a55, transparent 70%), #17152f',
    description: 'Deep violet space glow',
  },
  slate: {
    name: 'Slate Grid',
    background: 'linear-gradient(#a7b7db0a 1px, transparent 1px) center / 32px 32px, linear-gradient(90deg, #a7b7db0a 1px, transparent 1px) center / 32px 32px, #0c1220',
    description: 'A fine, understated grid on dark slate',
  },
  cyber: {
    name: 'Cyberpunk Cyan',
    background: 'radial-gradient(ellipse at 0% 0%, #117b9455, transparent 65%), radial-gradient(ellipse at 100% 100%, #26426766, transparent 70%), #081824',
    description: 'High-tech cyan ambiance',
  },
  sunset: {
    name: 'Warm Sunset',
    background: 'radial-gradient(ellipse at 90% 0%, #c6867655, transparent 65%), radial-gradient(ellipse at 0% 100%, #a6446855, transparent 70%), #2a1c2f',
    description: 'Mellow rose twilight gradient',
  },
  mountains: {
    name: 'Misty Mountains',
    background: landscapeBackground('<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#252746"/><stop offset="1" stop-color="#65678e"/></linearGradient></defs><path fill="url(#sky)" d="M0 0h800v600H0z"/><circle cx="610" cy="150" r="48" fill="#dad4e6" opacity=".6"/><path d="M0 400 170 220 330 390 490 270 800 430v170H0z" fill="#565578"/><path d="M0 510 220 330 420 510 640 350 800 460v140H0z" fill="#3b3d5f"/><path d="M0 530Q200 450 400 550T800 520v80H0z" fill="#292c49"/>', '#292c49'),
    description: 'Layered indigo mountains beneath a soft moon',
  },
  ocean: {
    name: 'Ocean Drift',
    background: landscapeBackground('<path fill="#dceeea" d="M0 0h800v600H0z"/><path d="M0 210Q200 100 400 210T800 210v390H0z" fill="#b3dcd9"/><path d="M0 320Q200 430 400 320T800 320v280H0z" fill="#8dc4c6"/><path d="M0 480Q200 350 400 480T800 480v120H0z" fill="#6ca7b3"/>', '#dceeea'),
    description: 'Calm, flowing waves in seafoam and ocean blue',
  },
  rosewater: {
    name: 'Rosewater',
    background: 'radial-gradient(ellipse at 10% 20%, #f3c8d8, transparent 65%), radial-gradient(ellipse at 95% 85%, #c8c9ef, transparent 65%), #f4e9ee',
    description: 'An airy blend of blush pink and soft lavender',
  },
  dunes: {
    name: 'Desert Dawn',
    background: landscapeBackground('<path fill="#f5e5d7" d="M0 0h800v600H0z"/><circle cx="600" cy="160" r="58" fill="#eec6a2"/><path d="M0 380Q180 230 410 380T800 340v260H0z" fill="#e8c5b0"/><path d="M0 430Q260 570 500 400T800 410v190H0z" fill="#cda99c"/><path d="M0 550Q300 380 800 560v40H0z" fill="#b98d88"/>', '#f5e5d7'),
    description: 'Warm sand dunes under a pale morning sun',
  },
  stars: {
    name: 'Starlit Sky',
    background: landscapeBackground('<defs><radialGradient id="sky"><stop stop-color="#2d365c"/><stop offset="1" stop-color="#111a30"/></radialGradient><pattern id="stars" width="160" height="160" patternUnits="userSpaceOnUse"><g fill="#b2bddf"><circle cx="25" cy="35" r="1.3"/><circle cx="110" cy="80" r="1"/><circle cx="65" cy="135" r=".8"/></g></pattern></defs><path fill="url(#sky)" d="M0 0h800v600H0z"/><path fill="url(#stars)" d="M0 0h800v600H0z"/><path d="M610 105a32 32 0 1 0 40 40 30 30 0 0 1-40-40" fill="#d8d9ef" opacity=".7"/>', '#111a30'),
    description: 'Tiny stars and a crescent moon on midnight blue',
  },
};

export interface FontOption {
  id: string;
  name: string;
  family: string;
  description: string;
}

export const FONT_PRESETS: FontOption[] = [
  {
    id: 'dm-sans',
    name: 'DM Sans',
    family: "'DM Sans', system-ui, sans-serif",
    description: 'Soft, clear lettering for the Lagoon interface',
  },
  {
    id: 'plus-jakarta',
    name: 'Plus Jakarta Sans',
    family: "'Plus Jakarta Sans', system-ui, sans-serif",
    description: 'Modern, crisp & balanced UI font',
  },
  {
    id: 'inter',
    name: 'Inter Display',
    family: "'Inter', -apple-system, system-ui, sans-serif",
    description: 'Neutral, clean & high-legibility tech font',
  },
  {
    id: 'outfit',
    name: 'Outfit Geometric',
    family: "'Outfit', system-ui, sans-serif",
    description: 'Contemporary, sleek & bold geometry',
  },
  {
    id: 'poppins',
    name: 'Poppins Friendly',
    family: "'Poppins', system-ui, sans-serif",
    description: 'Soft rounded geometric curves',
  },
  {
    id: 'fira-code',
    name: 'Fira Code Mono',
    family: "'Fira Code', monospace",
    description: 'Developer monospace aesthetic',
  },
];

export const PRESET_AVATARS = [
  '/avatars/avatar-1.png',
  '/avatars/avatar-2.png',
  '/avatars/avatar-3.png',
  '/avatars/avatar-4.png',
  '/avatars/avatar-5.png',
  '/avatars/avatar-6.png',
  '/avatars/avatar-7.png',
  '/avatars/avatar-8.png',
];

export function applyThemeAccent(key: string): void {
  const theme = THEME_PRESETS[key] || THEME_PRESETS.purple;
  const root = document.documentElement;
  root.style.setProperty('--primary', theme.accent);
  root.style.setProperty('--primary-hover', theme.accentHover);
  root.style.setProperty('--primary-glow', theme.accentGlow);
  root.style.setProperty('--primary-gradient', theme.gradient);
  root.style.setProperty('--border-focus', theme.accent);
  root.style.setProperty('--chat-indigo', theme.accent);
  root.style.setProperty('--chat-indigo-deep', theme.accentHover);
  root.style.setProperty('--chat-indigo-soft', theme.soft);
  root.style.setProperty('--chat-indigo-border', theme.border);
  root.style.setProperty('--welcome-ink', theme.accent);
  localStorage.setItem('novyn_theme_accent', theme.id);
}

/** Apply the app-wide light/dark colour mode and remember the user's choice. */
export function applyColorMode(mode: 'light' | 'dark' | 'system'): void {
  const root = document.documentElement;
  const resolved = mode === 'system' ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : mode;
  root.setAttribute('data-color-mode', resolved);
  root.style.colorScheme = resolved;
  localStorage.setItem('novyn_color_mode', mode);
}

export function applyWallpaper(key: string): void {
  const wp = WALLPAPER_PRESETS[key] || WALLPAPER_PRESETS.glass;
  const root = document.documentElement;
  root.style.setProperty('--chat-wallpaper', wp.background);
  localStorage.setItem('novyn_wallpaper', key);
}

export function applyFontFamily(fontId: string): void {
  const font = FONT_PRESETS.find((f) => f.id === fontId) || FONT_PRESETS[0];
  const root = document.documentElement;
  root.style.setProperty('--app-font-family', font.family);
  localStorage.setItem('novyn_font_family', fontId);
}

export const MESSAGE_SIZE_MIN = 13.5;
export const MESSAGE_SIZE_MAX = 16.5;

export function resolveFontSize(size: string | number): number {
  if (size === 'sm') return MESSAGE_SIZE_MIN;
  if (size === 'md') return 15;
  if (size === 'lg') return MESSAGE_SIZE_MAX;
  const value = typeof size === 'number' ? size : size.trim() ? Number(size) : NaN;
  return Number.isFinite(value) ? Math.round(Math.max(MESSAGE_SIZE_MIN, Math.min(MESSAGE_SIZE_MAX, value)) * 100) / 100 : 15;
}

export function applyFontSize(size: string | number): void {
  const value = resolveFontSize(size);
  document.documentElement.style.setProperty('--message-font-size', value + 'px');
  localStorage.setItem('novyn_font_size', String(value));
}

export function initializeUserPreferences(): void {
  try {
    const selectedMode = localStorage.getItem('novyn_color_mode');
    const savedColorMode = selectedMode === 'system' ? 'system' : selectedMode === 'dark' ? 'dark' : 'light';
    applyColorMode(savedColorMode);
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (localStorage.getItem('novyn_color_mode') === 'system') applyColorMode('system');
    });

    const savedAccent = localStorage.getItem('novyn_theme_accent') || 'purple';
    applyThemeAccent(savedAccent);

    const isFirstGlassLaunch = localStorage.getItem('novyn_design_version') !== 'lagoon-1';
    const previousWallpaper = localStorage.getItem('novyn_wallpaper');
    const savedWallpaper = !previousWallpaper || (isFirstGlassLaunch && previousWallpaper === 'midnight') ? 'glass' : previousWallpaper;
    applyWallpaper(savedWallpaper);

    const previousFont = localStorage.getItem('novyn_font_family');
    const isFirstQuietFontLaunch = localStorage.getItem('novyn_typography_version') !== 'jakarta-1';
    const savedFontFamily = !previousFont || (isFirstQuietFontLaunch && previousFont === 'dm-sans') ? 'plus-jakarta' : previousFont;
    applyFontFamily(savedFontFamily);
    localStorage.setItem('novyn_typography_version', 'jakarta-1');

    const savedFontSize = localStorage.getItem('novyn_font_size') || 'md';
    applyFontSize(savedFontSize);
    localStorage.setItem('novyn_design_version', 'lagoon-1');
  } catch (err) {
    console.error('Failed to initialize preferences:', err);
  }
}

export {
  playMessageNotification as playMessageChime,
  playMessageSentSound,
} from './audioManager';
