import { useSyncExternalStore } from 'react';

const EVENT = 'novyn:browser-preferences';
export function readBrowserPreference(key: string, fallback: string): string {
  try { return localStorage.getItem(key) ?? fallback; } catch { return fallback; }
}
export function setBrowserPreference(key: string, value: string): void {
  localStorage.setItem(key, value);
  window.dispatchEvent(new Event(EVENT));
  if (['novyn_settings_language', 'novyn_region', 'novyn_time_zone_mode', 'novyn_time_zone'].includes(key)) {
    document.documentElement.lang = readBrowserPreference('novyn_settings_language', 'en');
    window.dispatchEvent(new Event('novyn-region-change'));
  }
  applyAccessibilityPreferences();
}
export function useBrowserPreference(key: string, fallback: string): string {
  return useSyncExternalStore((notify) => {
    window.addEventListener(EVENT, notify);
    window.addEventListener('storage', notify);
    return () => { window.removeEventListener(EVENT, notify); window.removeEventListener('storage', notify); };
  }, () => readBrowserPreference(key, fallback), () => fallback);
}
export const browserAlertsEnabled = () => readBrowserPreference('novyn_browser_alerts', 'true') !== 'false';
export const messagePreviewsEnabled = () => readBrowserPreference('novyn_preview', 'true') !== 'false';
export const callSoundEnabled = () => readBrowserPreference('novyn_call_sound', 'true') !== 'false';
export function applyAccessibilityPreferences(): void {
  document.documentElement.dataset.reduceMotion = readBrowserPreference('novyn_reduce_motion', 'false');
  document.documentElement.dataset.highContrast = readBrowserPreference('novyn_high_contrast', 'false');
}
