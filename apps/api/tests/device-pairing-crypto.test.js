const test = require('node:test');
const assert = require('node:assert/strict');
const { webcrypto } = require('node:crypto');

const subtle = webcrypto.subtle;
const encoder = new TextEncoder();
const info = encoder.encode('novyn-device-pairing-v1');

async function deriveWrappingKey(privateKey, peerPublicKey, sessionId, usage) {
  const shared = await subtle.deriveBits(
    { name: 'ECDH', public: peerPublicKey },
    privateKey,
    256
  );
  const imported = await subtle.importKey('raw', shared, 'HKDF', false, ['deriveKey']);
  return subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: encoder.encode(sessionId),
      info,
    },
    imported,
    { name: 'AES-GCM', length: 256 },
    false,
    [usage]
  );
}

test('Novyn QR pairing derives matching ECDH/HKDF keys and only relays AES-GCM ciphertext', async () => {
  const android = await subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );
  const browser = await subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );

  const androidPrivateJwk = await subtle.exportKey('jwk', android.privateKey);
  const browserPublicJwk = await subtle.exportKey('jwk', browser.publicKey);
  assert.equal(typeof androidPrivateJwk.d, 'string');
  assert.equal(Object.hasOwn(browserPublicJwk, 'd'), false);

  const sessionId = 'A'.repeat(32);
  const browserWrapKey = await deriveWrappingKey(
    browser.privateKey,
    android.publicKey,
    sessionId,
    'encrypt'
  );
  const androidWrapKey = await deriveWrappingKey(
    android.privateKey,
    browser.publicKey,
    sessionId,
    'decrypt'
  );
  const privatePayload = JSON.stringify({
    format: 'novyn-primary-device-identity',
    version: 1,
    username: 'alice',
    identity: androidPrivateJwk,
  });
  const iv = webcrypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await subtle.encrypt(
    { name: 'AES-GCM', iv },
    browserWrapKey,
    encoder.encode(privatePayload)
  );

  assert.equal(Buffer.from(ciphertext).includes(Buffer.from(androidPrivateJwk.d)), false);
  const decrypted = await subtle.decrypt(
    { name: 'AES-GCM', iv },
    androidWrapKey,
    ciphertext
  );
  const restored = JSON.parse(new TextDecoder().decode(decrypted));
  assert.equal(restored.username, 'alice');
  assert.equal(restored.identity.d, androidPrivateJwk.d);

  const wrongSessionKey = await deriveWrappingKey(
    android.privateKey,
    browser.publicKey,
    'B'.repeat(32),
    'decrypt'
  );
  await assert.rejects(
    subtle.decrypt({ name: 'AES-GCM', iv }, wrongSessionKey, ciphertext)
  );

  const qrPayload = {
    type: 'novyn-device-pairing',
    version: 1,
    sessionId,
    username: 'alice',
    browserPublicKey: browserPublicJwk,
  };
  const qr = JSON.stringify(qrPayload);
  assert.equal(qr.includes(androidPrivateJwk.d), false);
  assert.equal(Object.hasOwn(qrPayload.browserPublicKey, 'd'), false);
});
