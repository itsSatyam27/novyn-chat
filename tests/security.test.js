const test = require('node:test');
const assert = require('node:assert/strict');
const { isAllowedSocketOrigin } = require('../server/security/origins');
const { canReadMedia } = require('../server/security/media-access');
const { createAuthToken, verifyAuthToken } = require('../server/auth/tokens');
const { createPasswordSecret, verifyPassword } = require('../server/auth/password');
const { createCsrf } = require('../server/auth/csrf');

test('production CSRF rejects missing tokens and cross-site origins', (t) => {
  const previous = process.env.NODE_ENV;
  process.env.NODE_ENV = 'production';
  t.after(() => { if (previous === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = previous; });
  const csrf = createCsrf({ cookieName: 'csrf', headerName: 'x-csrf', secure: true });
  for (const [origin, token, expected] of [
    ['https://chat.example', 'abc123', true],
    ['https://chat.example', '', false],
    ['https://evil.example', 'abc123', false],
  ]) {
    let accepted = false;
    let status = 200;
    const response = { cookie() {}, status(code) { status = code; return this; }, json() {} };
    csrf.middleware({ method: 'POST', headers: { host: 'chat.example', origin, cookie: 'csrf=abc123', 'x-csrf': token } }, response, () => { accepted = true; });
    assert.equal(accepted, expected);
    assert.equal(status, expected ? 200 : 403);
  }
});

test('password records expose signup fields and reject wrong passwords', () => {
  const { passwordSalt, passwordHash } = createPasswordSecret('correct-password');
  assert.ok(passwordSalt);
  assert.ok(passwordHash);
  assert.equal(verifyPassword('correct-password', passwordSalt, passwordHash), true);
  assert.equal(verifyPassword('wrong-password', passwordSalt, passwordHash), false);
  assert.equal(verifyPassword('anything', '', ''), false);
});

test('development allows exact loopback origins; production requires the allowlist', () => {
  const dev = { isProduction: false, allowedOrigins: [] };
  for (const origin of ['http://localhost:5173', 'http://127.0.0.1:5174', 'http://[::1]:3000']) {
    assert.equal(isAllowedSocketOrigin(origin, dev), true);
    assert.equal(isAllowedSocketOrigin(origin, { ...dev, isProduction: true }), false);
  }
  for (const origin of ['http://localhost.evil.test', 'http://localhost@evil.test', 'null', 'file://localhost']) {
    assert.equal(isAllowedSocketOrigin(origin, dev), false);
  }
  assert.equal(isAllowedSocketOrigin('https://chat.example', { isProduction: true, allowedOrigins: ['https://chat.example'] }), true);
});

test('media access follows ownership and current conversation membership', () => {
  const options = {
    filename: 'file-1.png', ownerKey: 'alice', userKey: 'bob',
    conversations: new Map([['group:one', [{ text: 'photo', attachment: { url: '/uploads/file-1.png?token=known' } }]]]),
    wallpapers: new Map(), canReadConversation: (_, user) => user === 'bob',
  };
  assert.equal(canReadMedia(options), true);
  assert.equal(canReadMedia({ ...options, userKey: 'alice' }), true);
  assert.equal(canReadMedia({ ...options, userKey: 'eve' }), false);
  assert.equal(canReadMedia({ ...options, userKey: '' }), false);
  assert.equal(canReadMedia({ ...options, canReadConversation: () => false }), false);
  options.conversations.get('group:one')[0].deletedAt = '2026-01-01';
  assert.equal(canReadMedia(options), false);
});

test('signed auth tokens reject tampering and the wrong token kind', () => {
  const secret = 'test-secret';
  const token = createAuthToken({ secret, kind: 'access', userKey: 'alice', ttlMs: 10000 });
  assert.equal(verifyAuthToken({ secret, rawToken: token, expectedKind: 'access' }).sub, 'alice');
  assert.equal(verifyAuthToken({ secret, rawToken: token, expectedKind: 'refresh' }), null);
  assert.equal(verifyAuthToken({ secret: 'wrong', rawToken: token, expectedKind: 'access' }), null);
});
