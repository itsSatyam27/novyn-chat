import { useSyncExternalStore } from 'react';

const KEY = 'novyn_dock_always_visible';
const EVENT = 'novyn:dock-preference';
const read = () => {
  try { return localStorage.getItem(KEY) === 'true'; } catch { return false; }
};
const subscribe = (notify: () => void) => {
  window.addEventListener(EVENT, notify);
  window.addEventListener('storage', notify);
  return () => {
    window.removeEventListener(EVENT, notify);
    window.removeEventListener('storage', notify);
  };
};
export const useDockAlwaysVisible = () => useSyncExternalStore(subscribe, read, () => false);
export function setDockAlwaysVisible(value: boolean) {
  try { localStorage.setItem(KEY, String(value)); } catch { return; }
  window.dispatchEvent(new Event(EVENT));
}
