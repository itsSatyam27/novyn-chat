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
const {
  readLastMessage,
  withCachedLegacyText,
  resolveReplyPreviews,
  LEGACY_MESSAGE_UNAVAILABLE,
} = exportsForTest;

const oldRecord = {
  id: 'message-1',
  from: 'alice',
  to: 'bob',
  timestamp: '2026-09-30T12:00:00Z',
  isEncrypted: true,
};
const summary = { lastMessage: LEGACY_MESSAGE_UNAVAILABLE, lastMessageData: oldRecord };

test('legacy encrypted previews are marked unavailable unless a readable local copy exists', () => {
  for (const username of ['alice', 'bob']) {
    const message = readLastMessage(summary, username);
    assert.equal(message.id, oldRecord.id);
    assert.equal(message.text, LEGACY_MESSAGE_UNAVAILABLE);
    assert.equal(message.isEncrypted, true);
    const cached = { ...message, text: 'Hello there' };
    const preserved = withCachedLegacyText(message, cached);
    assert.equal(preserved.text, 'Hello there');
    assert.equal(preserved.isEncrypted, true);
    assert.equal(withCachedLegacyText(message, { ...cached, id: 'different-message' }), message);
    assert.equal(withCachedLegacyText(message, { ...cached, isEncrypted: false }), message);
  }
});

test('ordinary text, media and empty conversation previews remain compatible', () => {
  assert.equal(readLastMessage({ lastMessage: 'hello' }, 'bob').text, 'hello');
  assert.equal(readLastMessage({ lastMessage: '' }, 'bob'), undefined);
  assert.equal(
    readLastMessage({ lastMessageData: { text: '', attachment: { kind: 'audio' } } }, 'bob').isVoice,
    true,
  );
});

test('reply previews resolve from a locally cached original without crypto operations', () => {
  const original = { id: 'original', sender: 'alice', text: 'Hello there' };
  const reply = {
    id: 'reply',
    text: 'Hi',
    replyTo: { id: 'original', from: 'alice', text: LEGACY_MESSAGE_UNAVAILABLE },
  };
  const result = resolveReplyPreviews([original, reply]);
  assert.equal(result[1].replyTo.text, 'Hello there');
  assert.equal(result[1].replyTo.sender, 'alice');
  assert.equal(reply.replyTo.text, LEGACY_MESSAGE_UNAVAILABLE);
  assert.equal(resolveReplyPreviews([{ ...original, text: 'Edited' }, reply])[1].replyTo.text, 'Edited');
  assert.equal(
    resolveReplyPreviews([{ ...original, text: 'Message deleted' }, reply])[1].replyTo.text,
    'Message deleted',
  );
});

test('reply previews retain the unavailable fallback when the original is missing', () => {
  const reply = {
    id: 'reply',
    replyTo: { id: 'original', from: 'alice', text: LEGACY_MESSAGE_UNAVAILABLE },
  };
  assert.equal(resolveReplyPreviews([reply])[0].replyTo.sender, 'alice');
  assert.equal(resolveReplyPreviews([reply])[0].replyTo.text, LEGACY_MESSAGE_UNAVAILABLE);
  const original = { id: 'original', sender: 'alice', text: LEGACY_MESSAGE_UNAVAILABLE };
  assert.equal(resolveReplyPreviews([original, reply])[1].replyTo.text, LEGACY_MESSAGE_UNAVAILABLE);
});
