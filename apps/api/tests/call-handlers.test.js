const test = require('node:test');
const assert = require('node:assert/strict');
const { registerCallHandlers } = require('../server/realtime/call-handlers');

function makeSocket(userKey) {
  const handlers = new Map();
  const events = [];
  return {
    data: { userKey },
    handlers,
    events,
    on(name, handler) { handlers.set(name, handler); },
    emit(name, payload) { events.push({ name, payload }); },
  };
}

function makeDeps({ aliceCalls = true, bobCalls = true } = {}) {
  const users = new Map([
    ['alice', {
      username: 'alice',
      isRegistered: true,
      callsEnabled: aliceCalls,
      callPrivacy: 'everyone',
      friends: new Set(['bob']),
    }],
    ['bob', {
      username: 'bob',
      isRegistered: true,
      callsEnabled: bobCalls,
      callPrivacy: 'everyone',
      friends: new Set(['alice']),
    }],
  ]);
  const activeCalls = new Map();
  const onlineUsers = new Map([['alice', 'alice-socket'], ['bob', 'bob-socket']]);
  const delivered = [];
  const deps = {
    resolveChatTargetForUser: () => null,
    toDisplayName: (value) => String(value ?? '').trim(),
    users,
    normalizeName: (value) => String(value ?? '').trim().toLowerCase(),
    onlineUsers,
    activeCalls,
    setCallPair(userKey, peerKey, status, callId, metadata = {}) {
      activeCalls.set(userKey, { ...metadata, peerKey, status, callId });
      activeCalls.set(peerKey, { ...metadata, peerKey: userKey, status, callId });
    },
    clearCallPair(userKey) {
      const active = activeCalls.get(userKey);
      if (!active) return null;
      activeCalls.delete(userKey);
      if (active.peerKey) activeCalls.delete(active.peerKey);
      return active.peerKey;
    },
    io: {
      to(socketId) {
        return { emit: (name, payload) => delivered.push({ socketId, name, payload }) };
      },
    },
    usersAreBlocked: () => false,
    sendPushToUser: () => Promise.resolve(),
    recordCallLog: () => {},
    delivered,
  };
  return deps;
}

test('callsEnabled blocks outgoing and incoming call starts', () => {
  const busyCallerDeps = makeDeps({ aliceCalls: false, bobCalls: true });
  const busyCaller = makeSocket('alice');
  registerCallHandlers(busyCaller, busyCallerDeps);
  busyCaller.handlers.get('call_start')({ to: 'bob', callId: 'busy-outgoing' });
  assert.equal(busyCaller.events.at(-1).name, 'call_ended');
  assert.match(busyCaller.events.at(-1).payload.reason, /disabled/i);
  assert.equal(busyCallerDeps.activeCalls.size, 0);

  const busyRecipientDeps = makeDeps({ aliceCalls: true, bobCalls: false });
  const caller = makeSocket('alice');
  registerCallHandlers(caller, busyRecipientDeps);
  caller.handlers.get('call_start')({ to: 'bob', callId: 'busy-incoming' });
  assert.equal(caller.events.at(-1).name, 'call_ended');
  assert.match(caller.events.at(-1).payload.reason, /not accepting calls/i);
  assert.equal(busyRecipientDeps.activeCalls.size, 0);
});

test('callsEnabled change while ringing cancels the call for both peers', () => {
  const deps = makeDeps();
  deps.setCallPair('alice', 'bob', 'ringing', 'mid-call-toggle', {
    type: 'voice', callerKey: 'alice',
  });
  deps.users.get('bob').callsEnabled = false;
  const receiver = makeSocket('bob');
  registerCallHandlers(receiver, deps);
  receiver.handlers.get('call_accept')({ to: 'alice', callId: 'mid-call-toggle' });

  assert.equal(deps.activeCalls.size, 0);
  assert.equal(deps.delivered.filter((event) => event.name === 'call_ended').length, 2);
});
