const test = require('node:test');
const assert = require('node:assert/strict');
const { createSocketAuthMiddleware } = require('../server/realtime/socket-auth');

function makeMiddleware(auth, origin = 'https://chat.example') {
  return createSocketAuthMiddleware({
    isProduction: true,
    allowedOrigins: ['https://chat.example'],
    resolveUserFromAuthCookies: () => auth,
    getAuthCookiesFromHeader: (header) => header || {},
    normalizeText: (value) => String(value || '').trim(),
  });
}

test('socket auth rejects unauthenticated connections', () => {
  const middleware = makeMiddleware({ userKey: null });
  const socket = { handshake: { headers: { origin: 'https://chat.example' } }, data: {} };
  let error;
  middleware(socket, (nextError) => { error = nextError; });
  assert.ok(error instanceof Error);
  assert.equal(error.message, 'Authentication required');
  assert.equal(socket.data.userKey, undefined);
});

test('socket auth populates identity for authenticated connections', () => {
  const middleware = makeMiddleware({ userKey: 'alice', sessionId: 'session-1' });
  const socket = { handshake: { headers: { origin: 'https://chat.example', cookie: 'session=valid' } }, data: {} };
  let error;
  middleware(socket, (nextError) => { error = nextError; });
  assert.equal(error, undefined);
  assert.equal(socket.data.userKey, 'alice');
  assert.equal(socket.data.sessionId, 'session-1');
});

test('socket auth rejects disallowed origins before authentication', () => {
  let authCalls = 0;
  const middleware = createSocketAuthMiddleware({
    isProduction: true,
    allowedOrigins: ['https://chat.example'],
    resolveUserFromAuthCookies: () => { authCalls++; return { userKey: 'alice' }; },
    getAuthCookiesFromHeader: () => ({}),
    normalizeText: (value) => String(value || '').trim(),
  });
  const socket = { handshake: { headers: { origin: 'https://attacker.example' } }, data: {} };
  let error;
  middleware(socket, (nextError) => { error = nextError; });
  assert.ok(error instanceof Error);
  assert.equal(error.message, 'Origin not allowed');
  assert.equal(authCalls, 0);
});
