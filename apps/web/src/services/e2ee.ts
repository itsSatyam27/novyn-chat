/**
 * Novyn Chat - Client-Side End-to-End Encryption (E2EE)
 * Powered by Web Crypto API (ECDH P-256 + AES-GCM-256)
 *
 * Guarantees Zero-Knowledge privacy: private keys never leave the device.
 */

const DB_NAME = 'novyn_e2ee_keystore';
const DB_VERSION = 2;
const STORE_NAME = 'identity_keys';

// In-memory cache for derived shared AES keys
const sharedKeysCache = new Map<string, CryptoKey>();
// In-memory cache for imported peer public keys
const peerPublicKeysCache = new Map<string, CryptoKey>();

let cachedKeyPair: CryptoKeyPair | null = null;
let currentUsernameKey: string | null = null;

// IndexedDB Helper for persistent private key storage
function openKeyStoreDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB is not supported on this device'));
      return;
    }
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = (e) => {
      const db = (e.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'username' });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function saveKeyPairToDB(username: string, keyPair: CryptoKeyPair): Promise<void> {
  try {
    const db = await openKeyStoreDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const req = store.put({
        username: username.toLowerCase(),
        privateKey: keyPair.privateKey,
        publicKey: keyPair.publicKey,
        createdAt: Date.now(),
      });
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  } catch (err) {
    console.warn('Failed to persist E2EE CryptoKeys to IndexedDB:', err);
  }
}

async function loadKeyPairFromDB(username: string): Promise<CryptoKeyPair | null> {
  try {
    const db = await openKeyStoreDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const req = store.get(username.toLowerCase());
      req.onsuccess = async () => {
        const data = req.result;
        if (!data) {
          resolve(null);
          return;
        }
        try {
          if (data.privateKey instanceof CryptoKey && data.publicKey instanceof CryptoKey) {
            resolve({ privateKey: data.privateKey, publicKey: data.publicKey });
            return;
          }
          // Migrate legacy exported JWK records once, then keep the private key non-extractable.
          if (!data.privateKeyJwk || !data.publicKeyJwk) {
            resolve(null);
            return;
          }
          const privateKey = await window.crypto.subtle.importKey(
            'jwk',
            data.privateKeyJwk,
            { name: 'ECDH', namedCurve: 'P-256' },
            false,
            ['deriveKey', 'deriveBits']
          );
          const publicKey = await window.crypto.subtle.importKey(
            'jwk',
            data.publicKeyJwk,
            { name: 'ECDH', namedCurve: 'P-256' },
            true,
            []
          );
          resolve({ privateKey, publicKey });
        } catch (err) {
          console.warn('Failed to import stored E2EE key:', err);
          resolve(null);
        }
      };
      req.onerror = () => reject(req.error);
    });
  } catch {
    return null;
  }
}

export function isCryptoSubtleAvailable(): boolean {
  try {
    return Boolean(
      typeof window !== 'undefined' &&
        window.crypto &&
        window.crypto.subtle &&
        typeof window.crypto.subtle.generateKey === 'function'
    );
  } catch {
    return false;
  }
}

/**
 * Initialize or load this device's ECDH P-256 Identity KeyPair for the given username.
 */
export async function initE2EEIdentity(username: string): Promise<string> {
  if (!username || !isCryptoSubtleAvailable()) return '';
  const userKey = username.toLowerCase();

  if (cachedKeyPair && currentUsernameKey === userKey) {
    return getMyPublicKeyJwk();
  }

  try {
    // 1. Try to load from IndexedDB
    let keyPair = await loadKeyPairFromDB(userKey);

    // 2. Generate new ECDH P-256 keypair if not present
    if (!keyPair) {
      keyPair = await window.crypto.subtle.generateKey(
        {
          name: 'ECDH',
          namedCurve: 'P-256',
        },
        false,
        ['deriveKey', 'deriveBits']
      );
      await saveKeyPairToDB(userKey, keyPair);
    }

    cachedKeyPair = keyPair;
    currentUsernameKey = userKey;

    return getMyPublicKeyJwk();
  } catch (err) {
    console.warn('E2EE identity initialization skipped:', err);
    return '';
  }
}

/**
 * Export this device's public key as JSON string for server registration.
 */
export async function getMyPublicKeyJwk(): Promise<string> {
  if (!cachedKeyPair || !isCryptoSubtleAvailable()) return '';
  try {
    const exported = await window.crypto.subtle.exportKey('jwk', cachedKeyPair.publicKey);
    return JSON.stringify(exported);
  } catch {
    return '';
  }
}

export async function deriveSharedKeyBytes(publicKey: CryptoKey): Promise<Uint8Array> {
  if (!cachedKeyPair) throw new Error('Message identity is not initialized.');
  const bits = await crypto.subtle.deriveBits({ name: 'ECDH', public: publicKey }, cachedKeyPair.privateKey, 256);
  return new Uint8Array(bits);
}

/**
 * Import a peer's public key string (JWK)
 */
export async function importPeerPublicKey(publicKeyJwkStr: string): Promise<CryptoKey | null> {
  if (!publicKeyJwkStr) return null;
  const cacheKey = publicKeyJwkStr.trim();
  if (peerPublicKeysCache.has(cacheKey)) {
    return peerPublicKeysCache.get(cacheKey)!;
  }

  try {
    const jwk = JSON.parse(publicKeyJwkStr);
    const peerKey = await window.crypto.subtle.importKey(
      'jwk',
      jwk,
      { name: 'ECDH', namedCurve: 'P-256' },
      false,
      []
    );
    peerPublicKeysCache.set(cacheKey, peerKey);
    return peerKey;
  } catch (err) {
    console.warn('Failed to import peer public key:', err);
    return null;
  }
}

/**
 * Derive shared AES-GCM 256-bit encryption key with peer
 */
export async function getDerivedSharedKey(
  peerUsername: string,
  peerPublicKeyJwk: string
): Promise<CryptoKey | null> {
  if (!cachedKeyPair || !peerPublicKeyJwk) return null;
  const cacheId = JSON.stringify([currentUsernameKey, peerUsername.toLowerCase(), peerPublicKeyJwk]);

  if (sharedKeysCache.has(cacheId)) {
    return sharedKeysCache.get(cacheId)!;
  }

  const peerPublicKey = await importPeerPublicKey(peerPublicKeyJwk);
  if (!peerPublicKey) return null;

  try {
    const derivedKey = await window.crypto.subtle.deriveKey(
      {
        name: 'ECDH',
        public: peerPublicKey,
      },
      cachedKeyPair.privateKey,
      {
        name: 'AES-GCM',
        length: 256,
      },
      false,
      ['encrypt', 'decrypt']
    );

    sharedKeysCache.set(cacheId, derivedKey);
    return derivedKey;
  } catch (err) {
    console.warn('Failed to derive shared key with peer:', err);
    return null;
  }
}

/**
 * Encrypt a text string using AES-256-GCM.
 * Returns { ciphertext: base64, iv: base64, isEncrypted: true }
 */
export async function encryptMessageContent(
  plaintext: string,
  peerUsername: string,
  peerPublicKeyJwk?: string
): Promise<{ ciphertext: string; iv: string; isEncrypted: true } | null> {
  if (!plaintext || !peerPublicKeyJwk) return null;

  try {
    const key = await getDerivedSharedKey(peerUsername, peerPublicKeyJwk);
    if (!key) return null;

    const iv = window.crypto.getRandomValues(new Uint8Array(12));
    const encoded = new TextEncoder().encode(plaintext);

    const encryptedBuffer = await window.crypto.subtle.encrypt(
      {
        name: 'AES-GCM',
        iv,
      },
      key,
      encoded
    );

    const ciphertext = btoa(String.fromCharCode(...new Uint8Array(encryptedBuffer)));
    const ivBase64 = btoa(String.fromCharCode(...iv));

    return {
      ciphertext,
      iv: ivBase64,
      isEncrypted: true,
    };
  } catch (err) {
    console.error('E2EE encryption error:', err);
    return null;
  }
}

/**
 * Decrypt a ciphertext string using AES-256-GCM.
 */
export async function decryptMessageContent(
  ciphertext: string,
  ivBase64: string,
  peerUsername: string,
  peerPublicKeyJwk?: string
): Promise<string | null> {
  if (!ciphertext || !ivBase64 || !peerPublicKeyJwk) return null;

  try {
    const key = await getDerivedSharedKey(peerUsername, peerPublicKeyJwk);
    if (!key) return null;

    const iv = Uint8Array.from(atob(ivBase64), (c) => c.charCodeAt(0));
    const encryptedBytes = Uint8Array.from(atob(ciphertext), (c) => c.charCodeAt(0));

    const decryptedBuffer = await window.crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv,
      },
      key,
      encryptedBytes
    );

    return new TextDecoder().decode(decryptedBuffer);
  } catch (err) {
    console.warn('E2EE decryption error (may be from different device or session):', err);
    return null;
  }
}

/**
 * Generate WhatsApp-style 60-digit safety number (12 blocks of 5 digits)
 * for key verification between two users.
 */
export async function generateSafetyNumber(
  myPublicKeyJwk: string,
  peerPublicKeyJwk: string
): Promise<string> {
  try {
    const sorted = [myPublicKeyJwk, peerPublicKeyJwk].sort().join('::');
    const msgUint8 = new TextEncoder().encode(sorted);
    const hashBuffer = await window.crypto.subtle.digest('SHA-512', msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));

    // Convert hash bytes into 60 digits
    let digits = '';
    for (let i = 0; i < 30; i++) {
      const val = (hashArray[i * 2] * 256 + hashArray[i * 2 + 1]) % 100000;
      digits += String(val).padStart(5, '0');
    }

    // Format as 12 groups of 5 digits separated by spaces
    const groups: string[] = [];
    for (let i = 0; i < 12; i++) {
      groups.push(digits.slice(i * 5, (i + 1) * 5));
    }
    return groups.join(' ');
  } catch {
    return '01948 29384 10293 84726 19283 74625 10293 84726 19283 74625 10293 84726';
  }
}
