const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const exportsForTest = {};
vm.runInNewContext(ts.transpileModule(
  fs.readFileSync(path.join(__dirname, '../../web/src/services/messagePresentation.ts'), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS } }
).outputText, { exports: exportsForTest });
const { readLastMessage, needsDecryption, withDecryptedText, resolveReplyPreviews, ENCRYPTED_MESSAGE_PLACEHOLDER } = exportsForTest;

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

test('reply previews resolve decrypted originals locally without changing transport metadata', () => {
  const original = { id: 'original', sender: 'alice', text: 'Hello there', isEncrypted: true };
  const reply = { id: 'reply', text: 'Hi', replyTo: { id: 'original', from: 'alice', text: ENCRYPTED_MESSAGE_PLACEHOLDER } };
  const result = resolveReplyPreviews([original, reply]);
  assert.equal(result[1].replyTo.text, 'Hello there');
  assert.equal(result[1].replyTo.sender, 'alice');
  assert.equal(reply.replyTo.text, ENCRYPTED_MESSAGE_PLACEHOLDER);
  assert.equal(resolveReplyPreviews([{ ...original, text: 'Edited' }, reply])[1].replyTo.text, 'Edited');
  assert.equal(resolveReplyPreviews([{ ...original, text: 'Message deleted', isEncrypted: false }, reply])[1].replyTo.text, 'Message deleted');
});

test('reply previews update after decryption and retain safe fallback for missing originals', () => {
  const reply = { id: 'reply', replyTo: { id: 'original', from: 'alice', text: ENCRYPTED_MESSAGE_PLACEHOLDER } };
  assert.equal(resolveReplyPreviews([reply])[0].replyTo.sender, 'alice');
  assert.equal(resolveReplyPreviews([reply])[0].replyTo.text, ENCRYPTED_MESSAGE_PLACEHOLDER);
  const original = { id: 'original', sender: 'alice', text: ENCRYPTED_MESSAGE_PLACEHOLDER };
  assert.equal(resolveReplyPreviews([original, reply])[1].replyTo.text, ENCRYPTED_MESSAGE_PLACEHOLDER);
  assert.equal(resolveReplyPreviews([{ ...original, text: 'Decrypted' }, reply])[1].replyTo.text, 'Decrypted');
  const attachment = { kind: 'image', url: '/image' };
  assert.equal(resolveReplyPreviews([{ ...original, text: '', attachment }, reply])[1].replyTo.attachment, attachment);
});
