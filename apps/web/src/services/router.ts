import type { NavTab } from '../components/layout/NavDock';
import type { SettingsMainCategory, SettingsSubSection } from '../components/settings/SettingsPanel';

export type NavRoute =
  | { tab: 'chats'; chat: string | null }
  | { tab: 'calls' }
  | { tab: 'contacts' }
  | { tab: 'discover' }
  | { tab: 'settings'; category: SettingsMainCategory; subSection: SettingsSubSection; isDetailOpen?: boolean };

export const SUBSECTION_TO_CATEGORY: Record<SettingsSubSection, SettingsMainCategory> = {
  'profile-details': 'profile',
  'profile-username': 'profile',
  'profile-email': 'profile',
  'profile-presence': 'profile',
  'profile-qr': 'profile',
  'security-dashboard': 'security',
  'privacy-blocked': 'privacy',
  'privacy-password': 'privacy',
  'privacy-app-lock': 'privacy',
  'privacy-visibility': 'privacy',
  'privacy-controls': 'privacy',
  'privacy-stealth': 'privacy',
  'privacy-two-factor': 'privacy',
  'privacy-message-keys': 'privacy',
  'privacy-receipts': 'privacy',
  'privacy-retention': 'privacy',
  'privacy-sessions': 'privacy',
  'privacy-linked-devices': 'privacy',
  'privacy-danger': 'privacy',
  'notif-sounds': 'notifications',
  'notif-calls': 'notifications',
  'notif-previews': 'notifications',
  'appear-theme': 'appearance',
  'appear-wallpaper': 'appearance',
  'appear-font': 'appearance',
  'appear-language': 'appearance',
  'appear-accessibility': 'appearance',
  'storage-cache': 'storage',
  'storage-export': 'storage',
  'storage-security': 'storage',
  'feedback-send': 'feedback',
  'feedback-bug': 'feedback',
  'feedback-feature': 'feedback',
};

export function subSectionToSlug(subSection: SettingsSubSection): string {
  switch (subSection) {
    case 'security-dashboard': return 'security';
    case 'profile-details': return 'profile';
    case 'privacy-controls': return 'privacy';
    case 'notif-sounds': return 'notifications';
    case 'appear-theme': return 'appearance';
    case 'appear-language': return 'language';
    case 'appear-accessibility': return 'accessibility';
    case 'storage-cache': return 'storage';
    case 'feedback-send': return 'feedback';
    default: return subSection;
  }
}

export function slugToSettings(slug?: string): { category: SettingsMainCategory; subSection: SettingsSubSection } {
  if (!slug) return { category: 'profile', subSection: 'profile-details' };
  switch (slug) {
    case 'security':
    case 'security-dashboard':
      return { category: 'security', subSection: 'security-dashboard' };
    case 'profile':
    case 'profile-details':
      return { category: 'profile', subSection: 'profile-details' };
    case 'privacy':
    case 'privacy-controls':
      return { category: 'privacy', subSection: 'privacy-controls' };
    case 'notifications':
    case 'notif-sounds':
      return { category: 'notifications', subSection: 'notif-sounds' };
    case 'appearance':
    case 'appear-theme':
      return { category: 'appearance', subSection: 'appear-theme' };
    case 'language':
    case 'appear-language':
      return { category: 'appearance', subSection: 'appear-language' };
    case 'accessibility':
    case 'appear-accessibility':
      return { category: 'appearance', subSection: 'appear-accessibility' };
    case 'storage':
    case 'storage-cache':
      return { category: 'storage', subSection: 'storage-cache' };
    case 'feedback':
    case 'feedback-send':
      return { category: 'feedback', subSection: 'feedback-send' };
    default: {
      const cat = SUBSECTION_TO_CATEGORY[slug as SettingsSubSection] || 'profile';
      return { category: cat, subSection: (slug as SettingsSubSection) || 'profile-details' };
    }
  }
}

export function parseHash(hashString?: string): NavRoute {
  const hash = (hashString ?? (typeof window !== 'undefined' ? window.location.hash : '')).replace(/^#\/?/, '');
  const parts = hash.split('/').filter(Boolean);
  const first = parts[0];

  if (!first || first === 'chats') {
    const chat = parts[1] ? decodeURIComponent(parts[1]) : null;
    return { tab: 'chats', chat };
  }

  if (first === 'calls') return { tab: 'calls' };
  if (first === 'contacts') return { tab: 'contacts' };
  if (first === 'discover') return { tab: 'discover' };

  if (first === 'settings') {
    const slug = parts[1];
    const { category, subSection } = slugToSettings(slug);
    return {
      tab: 'settings',
      category,
      subSection,
      isDetailOpen: Boolean(slug),
    };
  }

  return { tab: 'chats', chat: null };
}

export function buildHash(route: NavRoute): string {
  switch (route.tab) {
    case 'chats':
      return route.chat ? `#/chats/${encodeURIComponent(route.chat)}` : '#/chats';
    case 'calls':
      return '#/calls';
    case 'contacts':
      return '#/contacts';
    case 'discover':
      return '#/discover';
    case 'settings': {
      if (route.isDetailOpen === false) {
        return '#/settings';
      }
      return `#/settings/${subSectionToSlug(route.subSection)}`;
    }
  }
}

export function navigateTo(route: NavRoute, replace = false): void {
  if (typeof window === 'undefined') return;
  const hash = buildHash(route);
  if (window.location.hash === hash) return;

  if (replace) {
    window.history.replaceState(null, '', hash);
  } else {
    window.history.pushState(null, '', hash);
  }
  // Dispatch a synthetic popstate so all listeners immediately sync
  window.dispatchEvent(new PopStateEvent('popstate'));
}

export function navigateBack(): void {
  if (typeof window === 'undefined') return;
  if (window.history.length > 1) {
    window.history.back();
  } else {
    navigateTo({ tab: 'chats', chat: null });
  }
}
