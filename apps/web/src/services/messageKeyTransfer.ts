import { deriveSharedKeyBytes, getMyPublicKeyJwk, importPeerPublicKey, initE2EEIdentity } from './e2ee';

export const TRANSFER_ITERATIONS = 210000;
const encode = (bytes: Uint8Array) => btoa(Array.from(bytes, (b) => String.fromCharCode(b)).join(''));

/** Transfer conversation keys, never the browser's non-extractable private key.
 * This file is encrypted locally and is never uploaded to the Novyn server. */
export async function exportMessageKeys(
  username: string,
  peers: { username: string; publicKey?: string; isGroup?: boolean }[],
  password: string,
): Promise<string> {
  if (password.length < 12) throw new Error('Use a transfer password of at least 12 characters.');
  await initE2EEIdentity(username);
  const identity = await getMyPublicKeyJwk();
  if (!identity) throw new Error('Message keys are unavailable in this browser.');
  const keys = [];
  const seen = new Set<string>();
  for (const peer of peers) {
    const name = peer.username.toLowerCase();
    if (peer.isGroup || !peer.publicKey || seen.has(name)) continue;
    const publicKey = await importPeerPublicKey(peer.publicKey);
    if (!publicKey) throw new Error(`Unable to sync message keys for ${peer.username}.`);
    const key = await deriveSharedKeyBytes(publicKey);
    keys.push({ username: name, publicKey: peer.publicKey, key: encode(key) });
    seen.add(name);
  }
  if (!keys.length) throw new Error('No encrypted conversation keys are available yet.');
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const passwordKey = await crypto.subtle.importKey('raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveKey']);
  const wrappingKey = await crypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations: TRANSFER_ITERATIONS, hash: 'SHA-256' }, passwordKey, { name: 'AES-GCM', length: 256 }, false, ['encrypt']);
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, wrappingKey,
    new TextEncoder().encode(JSON.stringify({ username: username.toLowerCase(), identity, keys })));
  return JSON.stringify({ format: 'novyn-message-keys', version: 1, iterations: TRANSFER_ITERATIONS,
    salt: encode(salt), iv: encode(iv), ciphertext: encode(new Uint8Array(encrypted)) });
}
