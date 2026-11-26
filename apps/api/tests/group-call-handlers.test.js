const test = require('node:test');
const assert = require('node:assert/strict');
const {
  MAX_GROUP_CALL_PARTICIPANTS,
  createGroupCallRegistry,
  registerGroupCallHandlers,
} = require('../server/realtime/group-call-handlers');

function makeSocket(userKey) {
  const handlers = new Map();
  const events = [];
  return {
    id: userKey + '-socket',
    data: { userKey },
    handlers,
    events,
    on(name, handler) { handlers.set(name, handler); },
    emit(name, payload) { events.push({ name, payload }); },
  };
}

function makeFixture() {
  const names = ['alice', 'bob', 'carol', 'dave', 'erin'];
  const users = new Map(names.map((username) => [
    username,
    {
      username,
      displayName: username.toUpperCase(),
      isRegistered: true,
      callsEnabled: true,
      callPrivacy: 'friends',
      friends: new Set(names.filter((name) => name !== username)),
    },
  ]));
  const onlineUsers = new Map(names.map((name) => [name, name + '-socket']));
  const activeCalls = new Map([
    ['alice', { peerKey: 'bob', status: 'connected', callId: 'call-1', type: 'video' }],
    ['bob', { peerKey: 'alice', status: 'connected', callId: 'call-1', type: 'video' }],
  ]);
  const delivered = [];
  const registry = createGroupCallRegistry();
  const deps = {
    registry,
    users,
    normalizeName: (value) => String(value ?? '').trim().toLowerCase(),
    toDisplayName: (value) => String(value ?? '').trim(),
    onlineUsers,
    activeCalls,
    clearCallPair(userKey) {
      const active = activeCalls.get(userKey);
      if (!active) return null;
      activeCalls.delete(userKey);
      if (active.peerKey) activeCalls.delete(active.peerKey);
      return active.peerKey;
    },
    io: {
      to(socketId) {
        return {
          emit(name, payload) { delivered.push({ socketId, name, payload }); },
        };
      },
    },
    usersAreBlocked: () => false,
    sendPushToUser: async () => {},
    allowSocketAction: () => true,
  };
  const sockets = new Map();
  for (const name of names) {
    const socket = makeSocket(name);
    sockets.set(name, socket);
    registerGroupCallHandlers(socket, deps);
  }
  return { ...deps, delivered, sockets };
}

function invoke(socket, event, payload = {}) {
  let response;
  socket.handlers.get(event)(payload, (value) => { response = value; });
  return response;
}

test('promotes a connected direct call into a group session with a four-person cap', () => {
  const fixture = makeFixture();
  const result = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
    isVideo: true,
  });

  assert.equal(result.ok, true);
  assert.equal(result.participants.length, 2);
  assert.equal(result.capacity, MAX_GROUP_CALL_PARTICIPANTS);
  assert.equal(fixture.registry.userSessions.get('alice'), result.groupCallId);
  assert.equal(fixture.registry.userSessions.get('bob'), result.groupCallId);
  assert.equal(fixture.activeCalls.size, 0, 'group registry replaces the old pair-call lock');
  assert.equal(
    fixture.sockets.get('bob').events.some((entry) => entry.name === 'group_call_promoted'),
    false,
  );
  assert.equal(
    fixture.delivered.filter((entry) => entry.name === 'group_call_promoted').length,
    2,
  );
});

test('any current participant can invite another person until all four slots are filled', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  assert.equal(promoted.ok, true);

  const bobInvite = invoke(fixture.sockets.get('bob'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(bobInvite.ok, true);

  const joinedCarol = invoke(fixture.sockets.get('carol'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });
  assert.equal(joinedCarol.ok, true);
  assert.deepEqual(
    joinedCarol.participants.map((person) => person.username).sort(),
    ['alice', 'bob', 'carol'],
  );

  // Carol joined as a normal participant and must have the same invite rights.
  const carolInvite = invoke(fixture.sockets.get('carol'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'dave',
  });
  assert.equal(carolInvite.ok, true);

  const joinedDave = invoke(fixture.sockets.get('dave'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });
  assert.equal(joinedDave.ok, true);
  assert.equal(joinedDave.participants.length, 4);

  const fullInvite = invoke(fixture.sockets.get('dave'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'erin',
  });
  assert.equal(fullInvite.ok, false);
  assert.match(fullInvite.message, /four people/i);
});

test('only active group participants can relay signaling to another participant', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  invoke(fixture.sockets.get('bob'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  invoke(fixture.sockets.get('carol'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });

  fixture.sockets.get('carol').handlers.get('group_call_signal')({
    groupCallId: promoted.groupCallId,
    to: 'alice',
    signal: { type: 'offer', sdp: 'test-sdp' },
  });
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.socketId === 'alice-socket' && entry.name === 'group_call_signal',
    ).length,
    1,
  );

  fixture.sockets.get('erin').handlers.get('group_call_signal')({
    groupCallId: promoted.groupCallId,
    to: 'alice',
    signal: { type: 'offer', sdp: 'forged-sdp' },
  });
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.socketId === 'alice-socket' && entry.name === 'group_call_signal',
    ).length,
    1,
  );
});

test('leaving releases a participant slot and removes the session when fewer than two remain', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  invoke(fixture.sockets.get('bob'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  invoke(fixture.sockets.get('carol'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });

  assert.equal(invoke(fixture.sockets.get('carol'), 'group_call_leave', {
    groupCallId: promoted.groupCallId,
  }).ok, true);
  assert.equal(fixture.registry.userSessions.has('carol'), false);
  assert.equal(fixture.registry.sessions.has(promoted.groupCallId), true);

  fixture.sockets.get('bob').handlers.get('group_call_leave')({
    groupCallId: promoted.groupCallId,
  }, () => {});
  assert.equal(fixture.registry.sessions.has(promoted.groupCallId), false);
  assert.equal(fixture.registry.userSessions.has('alice'), false);
});

test('invite validation respects calls disabled, privacy, and existing calls', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  fixture.users.get('carol').callsEnabled = false;
  const disabled = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(disabled.ok, false);
  assert.match(disabled.message, /not accepting calls/i);

  fixture.users.get('carol').callsEnabled = true;
  fixture.users.get('carol').callPrivacy = 'nobody';
  const privateCall = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(privateCall.ok, false);

  fixture.users.get('carol').callPrivacy = 'friends';
  fixture.activeCalls.set('carol', { peerKey: 'erin', status: 'connected', callId: 'other-call' });
  const busy = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(busy.ok, false);
  assert.match(busy.message, /another call/i);
});

test('pending invitations reserve seats, and declines notify the participant who invited', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  assert.equal(promoted.ok, true);

  const carolInvite = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(carolInvite.ok, true);
  const daveInvite = invoke(fixture.sockets.get('bob'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'dave',
  });
  assert.equal(daveInvite.ok, true);
  const fifthInvite = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'erin',
  });
  assert.equal(fifthInvite.ok, false);

  const decline = invoke(fixture.sockets.get('carol'), 'group_call_decline', {
    groupCallId: promoted.groupCallId,
  });
  assert.equal(decline.ok, true);
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.socketId === 'alice-socket' &&
      entry.name === 'group_call_invitation_declined' &&
      entry.payload.username === 'carol',
    ),
    true,
  );
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.socketId === 'bob-socket' &&
      entry.name === 'group_call_invitation_declined' &&
      entry.payload.username === 'carol',
    ),
    false,
  );
  assert.equal(
    invoke(fixture.sockets.get('alice'), 'group_call_invite', {
      groupCallId: promoted.groupCallId,
      to: 'erin',
    }).ok,
    true,
  );
});

test('group screen sharing is exclusive and is released when its sharer leaves', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  fixture.sockets.get('alice').handlers.get('group_call_screen_share_state')({
    groupCallId: promoted.groupCallId,
    streamId: 'screen-a',
  });
  fixture.sockets.get('bob').handlers.get('group_call_screen_share_state')({
    groupCallId: promoted.groupCallId,
    streamId: 'screen-b',
  });
  assert.equal(
    fixture.sockets.get('bob').events.some((entry) => entry.name === 'group_call_screen_share_denied'),
    true,
  );
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.name === 'group_call_screen_share_state' &&
      entry.payload.streamId === 'screen-a',
    ).length,
    2,
  );

  fixture.sockets.get('alice').handlers.get('group_call_leave')({
    groupCallId: promoted.groupCallId,
  }, () => {});
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.name === 'group_call_screen_share_state' &&
      entry.payload.streamId === null,
    ),
    true,
  );
});

test('group signaling rejects unsupported packet types and oversized SDP', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  fixture.sockets.get('alice').handlers.get('group_call_signal')({
    groupCallId: promoted.groupCallId,
    to: 'bob',
    signal: { type: 'renegotiate-anything', sdp: 'bad' },
  });
  fixture.sockets.get('alice').handlers.get('group_call_signal')({
    groupCallId: promoted.groupCallId,
    to: 'bob',
    signal: { type: 'offer', sdp: 'x'.repeat(180_001) },
  });
  assert.equal(
    fixture.delivered.filter((entry) => entry.name === 'group_call_signal').length,
    0,
  );
});
