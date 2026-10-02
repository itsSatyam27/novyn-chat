const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const exportsForTest = {};
vm.runInNewContext(ts.transpileModule(
  fs.readFileSync(path.join(__dirname, '../src/services/messagePresentation.ts'), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS } }
).outputText, { exports: exportsForTest });
const { readLastMessage, needsDecryption, withDecryptedText, ENCRYPTED_MESSAGE_PLACEHOLDER } = exportsForTest;

const envelope = { id: 'message-1', from: 'alice', to: 'bob', timestamp: '2026-09-30T12:00:00Z', isEncrypted: true, ciphertext: 'encrypted', iv: 'iv' };
const summary = { lastMessage: ENCRYPTED_MESSAGE_PLACEHOLDER, lastMessageData: envelope };

test('encrypted previews retain the envelope and use locally decrypted text for either participant', () => {
  for (const username of ['alice', 'bob']) {
    const message = readLastMessage(summary, username);
    assert.equal(message.id, envelope.id);
    assert.equal(message.ciphertext, envelope.ciphertext);
    assert.equal(needsDecryption(message), true);
    const decrypted = withDecryptedText(message, { ...message, text: 'Hello there' });
    assert.equal(decrypted.text, 'Hello there');
    assert.equal(decrypted.isEncrypted, true);
    assert.equal(needsDecryption(decrypted), false);
    assert.equal(withDecryptedText(readLastMessage(summary, username), decrypted).text, 'Hello there', 'friend-list refresh preserves decrypted text');
  }
});

test('late decryption cannot replace a newer, changed, or deleted preview', () => {
  const original = readLastMessage(summary, 'bob');
  const decrypted = { ...original, text: 'Old message' };
  for (const current of [
    { ...original, id: 'message-2' },
    { ...original, ciphertext: 'new ciphertext' },
    { ...original, iv: 'new iv' },
    { ...original, isEncrypted: false, text: 'Message deleted' },
    { ...original, text: 'Already decrypted' },
  ]) assert.equal(withDecryptedText(current, decrypted), current);
  assert.equal(withDecryptedText(original, original), original, 'failed decryption does not replace the placeholder');
});

test('previews remain compatible with legacy text, media and empty conversations', () => {
  assert.equal(readLastMessage({ lastMessage: 'hello' }, 'bob').text, 'hello');
  assert.equal(readLastMessage({ lastMessage: '' }, 'bob'), undefined);
  assert.equal(readLastMessage({ lastMessageData: { text: '', attachment: { kind: 'audio' } } }, 'bob').isVoice, true);
  assert.equal(needsDecryption({ isEncrypted: true, text: ENCRYPTED_MESSAGE_PLACEHOLDER }), false);
});
