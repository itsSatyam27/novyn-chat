// Creates a synthetic WebCrypto fixture for the Android regression tests.
// No real account, backend, or browser profile is used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto, pbkdf2Sync } = require('node:crypto');
const ts = require('typescript');
const root = path.resolve(__dirname, '..');
const records = new Map();
const request = (result) => {
  const req = { result };
  queueMicrotask(() => req.onsuccess?.());
  return req;
};
const db = { transaction: () => ({ objectStore: () => ({
  get: (key) => request(records.get(key)),
  put: (record) => { records.set(record.username, record); return request(record.username); },
}) }) };
const cache = {};
function load(name) {
  if (cache[name]) return cache[name];
  const source = fs.readFileSync(path.join(root, 'apps/web/src/services', `${name}.ts`), 'utf8');
  const javascript = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const exports = {};
  vm.runInNewContext(javascript, { exports, require: (id) => load(id.replace('./', '')), window: { crypto: webcrypto },
    crypto: webcrypto, CryptoKey: webcrypto.CryptoKey, indexedDB: { open: () => request(db) },
    TextEncoder, TextDecoder, Uint8Array, btoa, atob, console });
  return cache[name] = exports;
}
(async () => {
  const e2ee = load('e2ee');
  const transfer = load('messageKeyTransfer');
  const peer = await webcrypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey', 'deriveBits']);
  const peerPublicKey = JSON.stringify(await webcrypto.subtle.exportKey('jwk', peer.publicKey));
  const accountPublicKey = await e2ee.initE2EEIdentity('interop-alice');
  const importedAccount = await webcrypto.subtle.importKey('jwk', JSON.parse(accountPublicKey), { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const peerSharedKey = await webcrypto.subtle.deriveKey({ name: 'ECDH', public: importedAccount }, peer.privateKey, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  const password = 'synthetic-test-password-only';
  const file = await transfer.exportMessageKeys('interop-alice', [{ username: 'interop-bob', publicKey: peerPublicKey }], password);
  const envelope = JSON.parse(file);
  const key = await webcrypto.subtle.importKey('raw', pbkdf2Sync(password, Buffer.from(envelope.salt, 'base64'), 210000, 32, 'sha256'), 'AES-GCM', false, ['decrypt']);
  const data = JSON.parse(new TextDecoder().decode(await webcrypto.subtle.decrypt({ name: 'AES-GCM', iv: Buffer.from(envelope.iv, 'base64') }, key, Buffer.from(envelope.ciphertext, 'base64'))));
  assert.equal(data.username, 'interop-alice');
  assert.equal(records.get('interop-alice').privateKey.extractable, false);
  assert.equal(JSON.stringify(data).includes('privateKey'), false);
  const messages = [];
  for (const text of ['Hello from web 👋 नमस्ते', 'x'.repeat(5000)]) {
    const iv = webcrypto.getRandomValues(new Uint8Array(12));
    const ciphertext = await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv }, peerSharedKey, new TextEncoder().encode(text));
    messages.push({ text, iv: Buffer.from(iv).toString('base64'), ciphertext: Buffer.from(ciphertext).toString('base64') });
  }
  const outbound = await e2ee.encryptMessageContent('Android → web test', 'interop-bob', peerPublicKey);
  assert.equal(await e2ee.decryptMessageContent(outbound.ciphertext, outbound.iv, 'interop-bob', peerPublicKey), 'Android → web test');
  await assert.rejects(transfer.exportMessageKeys('interop-alice', [], password), /No encrypted/);
  await assert.rejects(transfer.exportMessageKeys('interop-alice', [], 'short'), /12 characters/);
  const destination = path.join(root, 'apps/mobile/flutter/test/fixtures/message_key_transfer.json');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, JSON.stringify({ password, file, peerPublicKey, messages, sharedKey: data.keys[0].key }));
  console.log('WebCrypto interop fixture verified: protected transfer, non-extractable identity, UTF-8 and long messages.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
