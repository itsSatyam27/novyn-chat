const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { isAllowedSocketOrigin, parseAllowedSocketOrigins } = require('../server/security/origins');
const { canReadMedia } = require('../server/security/media-access');
const { createAuthToken, verifyAuthToken } = require('../server/auth/tokens');
const { createPasswordSecret, verifyPassword } = require('../server/auth/password');
const { createCsrf } = require('../server/auth/csrf');
const { createSocketAuthMiddleware } = require('../server/realtime/socket-auth');
const { createRegistrationReservations } = require('../server/auth/registration-reservations');

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

test('password records expose signup fields and reject wrong passwords', async () => {
  const { passwordSalt, passwordHash } = await createPasswordSecret('correct-password');
  assert.ok(passwordSalt);
  assert.ok(passwordHash);
  assert.equal(await verifyPassword('correct-password', passwordSalt, passwordHash), true);
  assert.equal(await verifyPassword('wrong-password', passwordSalt, passwordHash), false);
  assert.equal(await verifyPassword('anything', '', ''), false);
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
  assert.equal(isAllowedSocketOrigin('', { isProduction: true, allowedOrigins: [] }), true, 'native clients have no browser Origin header');
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

test('auth token helper protects reserved identity and lifetime claims from extra fields', () => {
  const secret = 'test-secret';
  const issuedAt = Date.now();
  const token = createAuthToken({
    secret,
    kind: 'access',
    userKey: 'alice',
    ttlMs: 10_000,
    extra: {
      sub: 'mallory',
      kind: 'refresh',
      iat: 1,
      exp: Date.now() + 60 * 60 * 1000,
      sid: 'session-1',
    },
  });
  const payload = verifyAuthToken({ secret, rawToken: token, expectedKind: 'access' });
  assert.ok(payload);
  assert.equal(payload.sub, 'alice');
  assert.equal(payload.kind, 'access');
  assert.ok(payload.iat >= issuedAt);
  assert.ok(payload.exp <= issuedAt + 11_000);
  assert.equal(payload.sid, 'session-1');
});

test('auth token verifier rejects correctly signed tokens with unsupported headers', () => {
  const secret = 'test-secret';
  const payload = {
    sub: 'alice',
    kind: 'access',
    iat: Date.now(),
    exp: Date.now() + 10_000,
  };
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const sign = (header) => {
    const body = encode(header) + '.' + encode(payload);
    const signature = crypto.createHmac('sha256', secret).update(body).digest('base64url');
    return body + '.' + signature;
  };

  assert.equal(
    verifyAuthToken({ secret, rawToken: sign({ alg: 'none', typ: 'JWT' }), expectedKind: 'access' }),
    null
  );
  assert.equal(
    verifyAuthToken({ secret, rawToken: sign({ alg: 'HS256', typ: 'NOT-JWT' }), expectedKind: 'access' }),
    null
  );
});

 
test('socket middleware rejects unauthenticated sockets before event handlers', () => {
  const middleware = createSocketAuthMiddleware({
    isProduction: true, allowedOrigins: ['https://chat.example'],
    resolveUserFromAuthCookies: () => ({ userKey: '', sessionId: '' }),
    getAuthCookiesFromHeader: () => ({}), normalizeText: (value) => String(value || ''),
  });
  const socket = { handshake: { headers: { origin: 'https://chat.example' } }, data: {} };
  let error;
  middleware(socket, (err) => { error = err; });
  assert.equal(error?.message, 'Authentication required');
  assert.equal(socket.data.userKey, undefined);
});

test('socket middleware sets authenticated identity and session only after validation', () => {
  const middleware = createSocketAuthMiddleware({
    isProduction: true, allowedOrigins: ['https://chat.example'],
    resolveUserFromAuthCookies: () => ({ userKey: 'alice', sessionId: 'session-1' }),
    getAuthCookiesFromHeader: () => ({}), normalizeText: (value) => String(value || ''),
  });
  const socket = { handshake: { headers: { origin: 'https://chat.example' } }, data: {} };
  let accepted = false;
  middleware(socket, (err) => { assert.equal(err, undefined); accepted = true; });
  assert.equal(accepted, true);
  assert.equal(socket.data.userKey, 'alice');
  assert.equal(socket.data.sessionId, 'session-1');
});

test('socket middleware rejects disallowed origins before authentication', () => {
  let authResolved = false;
  const middleware = createSocketAuthMiddleware({
    isProduction: true, allowedOrigins: ['https://chat.example'],
    resolveUserFromAuthCookies: () => { authResolved = true; return { userKey: 'alice' }; },
    getAuthCookiesFromHeader: () => ({}), normalizeText: (value) => String(value || ''),
  });
  const socket = { handshake: { headers: { origin: 'https://attacker.example' } }, data: {} };
  let error;
  middleware(socket, (err) => { error = err; });
  assert.equal(error?.message, 'Origin not allowed');
  assert.equal(authResolved, false);
});


test('signup reservations block duplicate email and username while hashing is pending', () => {
  const reservations = createRegistrationReservations();
  assert.equal(reservations.reserve('Alice@Example.test', 'Alice'), true);
  assert.equal(reservations.reserve('alice@example.test', 'another'), false, 'email matching is case-insensitive');
  assert.equal(reservations.reserve('other@example.test', 'ALICE'), false, 'username matching is case-insensitive');
  reservations.release('ALICE@example.test', 'alice');
  assert.equal(reservations.reserve('alice@example.test', 'alice'), true, 'released identities can be retried');
  reservations.release('alice@example.test', 'alice');

  assert.equal(reservations.reserve('google@example.test', 'google_user', 'GoogleUID'), true);
  assert.equal(reservations.reserve('different@example.test', 'other_user', 'GoogleUID'), false);
  assert.equal(reservations.reserve('different@example.test', 'other_user', 'googleuid'), true, 'external IDs remain case-sensitive');
  reservations.release('google@example.test', 'google_user', 'GoogleUID');
  reservations.release('different@example.test', 'other_user', 'googleuid');

  assert.equal(reservations.reserve('', '', 'link-only-uid'), true);
  assert.equal(reservations.reserve('', '', 'link-only-uid'), false, 'Google linking must reserve a UID even without email or username locks');
  reservations.release('', '', 'link-only-uid');
  assert.equal(reservations.reserve('', '', 'link-only-uid'), true, 'UID-only reservations can be released and retried');
  reservations.release('', '', 'link-only-uid');
});


test('production socket origin configuration requires exact HTTPS origins', () => {
  assert.deepEqual(
    parseAllowedSocketOrigins('https://chat.example, https://admin.example', { isProduction: true }),
    ['https://chat.example', 'https://admin.example'],
  );
  assert.throws(
    () => parseAllowedSocketOrigins('', { isProduction: true }),
    /ALLOWED_ORIGIN must contain at least one exact HTTPS browser origin/i,
  );
  for (const invalid of [
    'http://chat.example',
    'https://chat.example/',
    'https://chat.example/app',
    'https://chat.example?mode=app',
    'https://user:pass@chat.example',
    'not-an-origin',
  ]) {
    assert.throws(
      () => parseAllowedSocketOrigins(invalid, { isProduction: true }),
      /exact HTTPS origins/i,
      invalid,
    );
  }
});

test('development socket origin configuration remains permissive for local setup', () => {
  assert.deepEqual(
    parseAllowedSocketOrigins(' http://localhost:5173, ,https://preview.example/ ', { isProduction: false }),
    ['http://localhost:5173', 'https://preview.example/'],
  );
});


test('auth token verification rejects oversized, malformed, and invalid time-claim tokens', () => {
  const secret = 'test-secret';
  assert.equal(verifyAuthToken({ secret, rawToken: 'a'.repeat(8193), expectedKind: 'access' }), null);
  assert.equal(verifyAuthToken({ secret, rawToken: 'not.a.valid+token', expectedKind: 'access' }), null);

  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const signPayload = (payload) => {
    const body = encode({ alg: 'HS256', typ: 'JWT' }) + '.' + encode(payload);
    return body + '.' + crypto.createHmac('sha256', secret).update(body).digest('base64url');
  };
  const base = { sub: 'alice', kind: 'access', iat: Date.now(), exp: Date.now() + 60_000 };
  assert.equal(verifyAuthToken({ secret, rawToken: signPayload({ ...base, iat: Date.now() + 120_000 }), expectedKind: 'access' }), null);
  assert.equal(verifyAuthToken({ secret, rawToken: signPayload({ ...base, exp: base.iat }), expectedKind: 'access' }), null);
  const { iat, ...missingIssuedAt } = base;
  assert.equal(verifyAuthToken({ secret, rawToken: signPayload(missingIssuedAt), expectedKind: 'access' }), null);
});
