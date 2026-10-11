// App Lock & Screen Protection Service for Web & Mobile Webview

const PIN_STORAGE_KEY = 'novyn_app_lock_pin_hash';
const TIMEOUT_STORAGE_KEY = 'novyn_app_lock_timeout';
const LOCK_STATE_KEY = 'novyn_app_lock_is_locked';
const EVENT_LOCK_CHANGE = 'novyn:app-lock-change';

// Simple fast SHA-256 hash using Web Crypto API
async function hashPin(pin: string): Promise<string> {
  const enc = new TextEncoder().encode(`novyn-salt-${pin}`);
  const buf = await window.crypto.subtle.digest('SHA-256', enc);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function isAppLockConfigured(): boolean {
  if (typeof window === 'undefined') return false;
  return Boolean(localStorage.getItem(PIN_STORAGE_KEY));
}

export function isAppLocked(): boolean {
  if (typeof window === 'undefined') return false;
  if (!isAppLockConfigured()) return false;
  return sessionStorage.getItem(LOCK_STATE_KEY) === 'true';
}

export function lockApp(): void {
  if (!isAppLockConfigured()) return;
  sessionStorage.setItem(LOCK_STATE_KEY, 'true');
  window.dispatchEvent(new Event(EVENT_LOCK_CHANGE));
}

export function unlockApp(): void {
  sessionStorage.removeItem(LOCK_STATE_KEY);
  resetActivityTimer();
  window.dispatchEvent(new Event(EVENT_LOCK_CHANGE));
}

export async function setAppLockPin(pin: string): Promise<boolean> {
  if (!/^\d{4}$/.test(pin)) return false;
  const hash = await hashPin(pin);
  localStorage.setItem(PIN_STORAGE_KEY, hash);
  if (!localStorage.getItem(TIMEOUT_STORAGE_KEY)) {
    localStorage.setItem(TIMEOUT_STORAGE_KEY, '5'); // Default: 5 minutes
  }
  window.dispatchEvent(new Event(EVENT_LOCK_CHANGE));
  return true;
}

export async function verifyAppLockPin(pin: string): Promise<boolean> {
  const savedHash = localStorage.getItem(PIN_STORAGE_KEY);
  if (!savedHash) return false;
  const testHash = await hashPin(pin);
  return testHash === savedHash;
}

export function disableAppLock(): void {
  localStorage.removeItem(PIN_STORAGE_KEY);
  sessionStorage.removeItem(LOCK_STATE_KEY);
  window.dispatchEvent(new Event(EVENT_LOCK_CHANGE));
}

export function getAutoLockTimeout(): number {
  if (typeof window === 'undefined') return 5;
  const val = localStorage.getItem(TIMEOUT_STORAGE_KEY);
  return val !== null ? Number(val) : 5;
}

export function setAutoLockTimeout(minutes: number): void {
  localStorage.setItem(TIMEOUT_STORAGE_KEY, String(minutes));
  resetActivityTimer();
  window.dispatchEvent(new Event(EVENT_LOCK_CHANGE));
}

// Inactivity tracking
let inactivityTimer: number | null = null;

export function resetActivityTimer(): void {
  if (inactivityTimer) {
    window.clearTimeout(inactivityTimer);
    inactivityTimer = null;
  }

  if (!isAppLockConfigured()) return;
  const minutes = getAutoLockTimeout();
  if (minutes <= 0) return; // 0 means lock only manually or on tab background

  inactivityTimer = window.setTimeout(() => {
    lockApp();
  }, minutes * 60 * 1000);
}

// Initialize activity and visibility listeners once
if (typeof window !== 'undefined') {
  const handleActivity = () => {
    if (!isAppLocked()) {
      resetActivityTimer();
    }
  };

  window.addEventListener('mousemove', handleActivity, { passive: true });
  window.addEventListener('keydown', handleActivity, { passive: true });
  window.addEventListener('touchstart', handleActivity, { passive: true });

  document.addEventListener('visibilitychange', () => {
    if (document.hidden && isAppLockConfigured() && getAutoLockTimeout() === 0) {
      lockApp();
    }
  });

  resetActivityTimer();
}

export function subscribeAppLock(callback: () => void): () => void {
  if (typeof window === 'undefined') return () => {};
  window.addEventListener(EVENT_LOCK_CHANGE, callback);
  return () => window.removeEventListener(EVENT_LOCK_CHANGE, callback);
}
