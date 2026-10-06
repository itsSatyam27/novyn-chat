// Settings Preferences and Dynamic Theme & Typography Engine

export interface ThemeConfig {
  accent: string;
  accentHover: string;
  accentGlow: string;
  name: string;
}

export const THEME_PRESETS: Record<string, ThemeConfig> = {
  purple: {
    name: 'Purple',
    accent: '#6d5dfc',
    accentHover: '#5746e8',
    accentGlow: 'rgba(109, 93, 252, 0.24)',
  },
};

export const WALLPAPER_PRESETS: Record<string, { name: string; background: string; description: string }> = {
  glass: {
    name: 'Lagoon Glass',
    background: 'transparent',
    description: 'Soft blue and mint colors with translucent surfaces',
  },
  midnight: {
    name: 'Midnight OLED',
    background: '#070a11',
    description: 'Ultra-deep pure black background',
  },
  aurora: {
    name: 'Emerald Aurora',
    background: 'radial-gradient(ellipse at top right, rgba(16, 185, 129, 0.12) 0%, #070c14 70%)',
    description: 'Subtle emerald neon gradient',
  },
  cosmic: {
    name: 'Cosmic Nebula',
    background: 'radial-gradient(ellipse at top right, rgba(139, 92, 246, 0.14) 0%, #070913 70%)',
    description: 'Deep violet space glow',
  },
  slate: {
    name: 'Slate Grid',
    background: '#0c1220',
    description: 'Polished studio dark slate',
  },
  cyber: {
    name: 'Cyberpunk Cyan',
    background: 'radial-gradient(ellipse at top right, rgba(6, 182, 212, 0.12) 0%, #050d18 70%)',
    description: 'High-tech cyan ambiance',
  },
  sunset: {
    name: 'Warm Sunset',
    background: 'radial-gradient(ellipse at top right, rgba(244, 63, 94, 0.12) 0%, #0c0812 70%)',
    description: 'Mellow rose twilight gradient',
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
  'https://api.dicebear.com/7.x/bottts/svg?seed=Felix',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Luna',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Nova',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Echo',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Astra',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Cyber',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Shadow',
  'https://api.dicebear.com/7.x/bottts/svg?seed=Zenith',
];

export function applyThemeAccent(key: string): void {
  const theme = THEME_PRESETS.purple;
  const root = document.documentElement;
  root.style.setProperty('--primary', theme.accent);
  root.style.setProperty('--primary-hover', theme.accentHover);
  root.style.setProperty('--primary-glow', theme.accentGlow);
  root.style.setProperty('--border-focus', theme.accent);
  localStorage.setItem('novyn_theme_accent', 'purple');
}

/** Apply the app-wide light/dark colour mode and remember the user's choice. */
export function applyColorMode(mode: 'light' | 'dark'): void {
  const root = document.documentElement;
  root.setAttribute('data-color-mode', mode);
  root.style.colorScheme = mode;
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

export function applyFontSize(size: 'sm' | 'md' | 'lg'): void {
  const root = document.documentElement;
  const px = size === 'sm' ? '13.5px' : size === 'lg' ? '16.5px' : '15px';
  root.style.setProperty('--message-font-size', px);
  localStorage.setItem('novyn_font_size', size);
}

export function initializeUserPreferences(): void {
  try {
    const savedColorMode = localStorage.getItem('novyn_color_mode') === 'dark' ? 'dark' : 'light';
    applyColorMode(savedColorMode);

    applyThemeAccent('purple');

    const isFirstGlassLaunch = localStorage.getItem('novyn_design_version') !== 'lagoon-1';
    const previousWallpaper = localStorage.getItem('novyn_wallpaper');
    const savedWallpaper = !previousWallpaper || (isFirstGlassLaunch && previousWallpaper === 'midnight') ? 'glass' : previousWallpaper;
    applyWallpaper(savedWallpaper);

    const previousFont = localStorage.getItem('novyn_font_family');
    const isFirstQuietFontLaunch = localStorage.getItem('novyn_typography_version') !== 'jakarta-1';
    const savedFontFamily = !previousFont || (isFirstQuietFontLaunch && previousFont === 'dm-sans') ? 'plus-jakarta' : previousFont;
    applyFontFamily(savedFontFamily);
    localStorage.setItem('novyn_typography_version', 'jakarta-1');

    const savedFontSize = (localStorage.getItem('novyn_font_size') as any) || 'md';
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
