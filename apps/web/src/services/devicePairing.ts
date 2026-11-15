import { apiRequest } from './api';
import { installPrimaryIdentityFromPairing } from './e2ee';

const PAIRING_TYPE = 'novyn-device-pairing';
const PAIRING_INFO = new TextEncoder().encode('novyn-device-pairing-v1');
const encoder = new TextEncoder();

export interface DevicePairingChallenge {
  sessionId: string;
  username: string;
  qrDataUrl: string;
  expiresAt: number;
  privateKey: CryptoKey;
}

function isValidP256PublicJwk(value: any): boolean {
  return Boolean(
    value && value.kty === 'EC' && value.crv === 'P-256' &&
    typeof value.x === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value.x) &&
    typeof value.y === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value.y) &&
    !Object.prototype.hasOwnProperty.call(value, 'd')
  );
}

function base64ToBytes(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function bytesToArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

export async function createDevicePairingChallenge(
  username: string
): Promise<DevicePairingChallenge> {
  if (!username.trim()) throw new Error('Sign in before linking a device.');
  if (!window.isSecureContext || !window.crypto?.subtle) {
    throw new Error('Secure browser cryptography requires HTTPS.');
  }

  const ephemeral = await window.crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );
  const browserPublicKey = await window.crypto.subtle.exportKey('jwk', ephemeral.publicKey);
  if (!isValidP256PublicJwk(browserPublicKey)) {
    throw new Error('Could not create a valid browser pairing key.');
  }

  const created = await apiRequest<{
    ok: boolean;
    sessionId: string;
    username: string;
    expiresAt: number;
    error?: string;
    message?: string;
  }>('/api/device-pairing', {
    method: 'POST',
    body: JSON.stringify({ browserPublicKey }),
  });
  if (!created.ok || !created.data?.sessionId ||
      !/^[A-Za-z0-9_-]{32}$/.test(created.data.sessionId)) {
    throw new Error(created.data?.error || created.data?.message || 'Could not create a pairing session.');
  }

  const qrPayload = JSON.stringify({
    type: PAIRING_TYPE,
    version: 1,
    sessionId: created.data.sessionId,
    username: created.data.username || username,
    browserPublicKey,
  });
  const QRCode = await import('qrcode');
  const qrDataUrl = await QRCode.toDataURL(qrPayload, {
    width: 320,
    margin: 2,
    errorCorrectionLevel: 'Q',
    color: { dark: '#111827', light: '#ffffff' },
  });

  return {
    sessionId: created.data.sessionId,
    username: created.data.username || username,
    qrDataUrl,
    expiresAt: Number(created.data.expiresAt) || Date.now() + 120000,
    privateKey: ephemeral.privateKey,
  };
}

export async function pollAndCompleteDevicePairing(
  challenge: DevicePairingChallenge
): Promise<boolean> {
  const response = await apiRequest<{
    ok: boolean;
    status: 'pending' | 'approved';
    response?: {
      androidPublicKey: string | JsonWebKey;
      iv: string;
      ciphertext: string;
    };
    error?: string;
  }>(`/api/device-pairing/${challenge.sessionId}`);

  if (!response.ok) {
    if (response.status === 0) return false;
    throw new Error(response.data?.error || 'The pairing session expired. Create a new QR code.');
  }
  if (response.data?.status === 'pending') return false;
  if (response.data?.status !== 'approved' || !response.data.response) {
    throw new Error('The pairing response is invalid.');
  }

  const envelope = response.data.response;
  const androidPublicJwk = typeof envelope.androidPublicKey === 'string'
    ? JSON.parse(envelope.androidPublicKey)
    : envelope.androidPublicKey;
  if (!isValidP256PublicJwk(androidPublicJwk) ||
      typeof envelope.iv !== 'string' || typeof envelope.ciphertext !== 'string') {
    throw new Error('The Android pairing response is malformed.');
  }

  const androidPublicKey = await window.crypto.subtle.importKey(
    'jwk',
    androidPublicJwk,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );
  const sharedSecret = await window.crypto.subtle.deriveBits(
    { name: 'ECDH', public: androidPublicKey },
    challenge.privateKey,
    256
  );
  const hkdfKey = await window.crypto.subtle.importKey(
    'raw',
    sharedSecret,
    'HKDF',
    false,
    ['deriveKey']
  );
  const wrappingKey = await window.crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: encoder.encode(challenge.sessionId),
      info: PAIRING_INFO,
    },
    hkdfKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt']
  );

  let plaintext: string;
  try {
    const clear = await window.crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: bytesToArrayBuffer(base64ToBytes(envelope.iv)),
      },
      wrappingKey,
      bytesToArrayBuffer(base64ToBytes(envelope.ciphertext))
    );
    plaintext = new TextDecoder().decode(clear);
  } catch {
    throw new Error('Could not verify the encrypted Android pairing response.');
  }

  const payload = JSON.parse(plaintext);
  if (payload?.format !== 'novyn-primary-device-identity' ||
      payload?.version !== 1 ||
      String(payload?.username || '').toLowerCase() !== challenge.username.toLowerCase() ||
      !payload.identity) {
    throw new Error('The encrypted identity belongs to a different Novyn account.');
  }

  // This persists the key first, archives the previous browser identity and
  // preserves old per-conversation keys before consuming the server relay.
  await installPrimaryIdentityFromPairing(
    challenge.username,
    payload.identity,
    payload.legacyKeys
  );
  const consumed = await apiRequest(
    `/api/device-pairing/${challenge.sessionId}/consume`,
    { method: 'POST', body: JSON.stringify({}) }
  );
  if (!consumed.ok) {
    console.warn('Pairing was installed but relay cleanup was deferred.');
  }
  return true;
}

export async function cancelDevicePairing(sessionId: string): Promise<void> {
  if (!/^[A-Za-z0-9_-]{32}$/.test(sessionId)) return;
  await apiRequest(`/api/device-pairing/${sessionId}`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}
