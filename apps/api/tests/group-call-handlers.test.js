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
  const scheduledInvites = [];
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
    scheduleInviteTimeout(callback, delay) {
      const timer = { callback, delay, cancelled: false };
      scheduledInvites.push(timer);
      return timer;
    },
    clearInviteTimeout(timer) {
      if (timer) timer.cancelled = true;
    },
    allowSocketAction: () => true,
  };
  const sockets = new Map();
  for (const name of names) {
    const socket = makeSocket(name);
    sockets.set(name, socket);
    registerGroupCallHandlers(socket, deps);
  }
  return { ...deps, delivered, scheduledInvites, sockets };
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


test('a direct call can be promoted and ring the selected invitee in the same action', () => {
  const fixture = makeFixture();
  fixture.activeCalls.get('alice').type = 'voice';
  fixture.activeCalls.get('bob').type = 'voice';
  const result = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
    isVideo: false,
    invitees: ['carol'],
  });

  assert.equal(result.ok, true);
  assert.equal(result.isVideo, false);
  assert.equal(result.pendingInvitations.length, 1);
  assert.equal(result.pendingInvitations[0].username, 'carol');
  assert.equal(result.invitations[0].username, 'carol');
  assert.equal(fixture.registry.userSessions.get('alice'), result.groupCallId);
  assert.equal(fixture.registry.userSessions.get('bob'), result.groupCallId);
  assert.equal(fixture.activeCalls.size, 0);
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.socketId === 'carol-socket' &&
      entry.name === 'group_call_invitation' &&
      entry.payload.groupCallId === result.groupCallId,
    ),
    true,
  );
});


test('the second participant can add a contact after the first participant promotes the call', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  assert.equal(promoted.ok, true);

  const addedByBob = invoke(fixture.sockets.get('bob'), 'group_call_promote', {
    callId: 'call-1',
    invitees: ['carol'],
  });
  assert.equal(addedByBob.ok, true);
  assert.equal(addedByBob.pendingInvitations[0].username, 'carol');
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.socketId === 'carol-socket' && entry.name === 'group_call_invitation',
    ).length,
    1,
  );
});

test('retries from both original participants do not ring the same pending invite twice', () => {
  const fixture = makeFixture();
  const first = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
    invitees: ['carol'],
  });
  const retry = invoke(fixture.sockets.get('bob'), 'group_call_promote', {
    callId: 'call-1',
    invitees: ['carol'],
  });

  assert.equal(first.ok, true);
  assert.equal(retry.ok, true);
  assert.equal(retry.invitations[0].expiresAt, first.invitations[0].expiresAt);
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.socketId === 'carol-socket' && entry.name === 'group_call_invitation',
    ).length,
    1,
  );
});

test('promotion validates the selected invitee before changing the live one-to-one call', () => {
  const fixture = makeFixture();
  fixture.users.get('carol').callsEnabled = false;
  const result = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
    invitees: ['carol'],
  });

  assert.equal(result.ok, false);
  assert.match(result.message, /not accepting calls/i);
  assert.equal(fixture.activeCalls.size, 2);
  assert.equal(fixture.registry.sessions.size, 0);
  assert.equal(fixture.registry.userSessions.size, 0);
});

test('group invitations notify the active call when the invitee does not answer', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  const invited = invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  assert.equal(invited.ok, true);
  assert.equal(fixture.scheduledInvites.length, 1);
  const timer = fixture.scheduledInvites[0];
  assert.equal(timer.delay, 45_000);
  assert.equal(timer.cancelled, false);

  timer.callback();
  assert.equal(timer.cancelled, true);
  assert.equal(fixture.registry.sessions.get(promoted.groupCallId).pending.size, 0);
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.name === 'group_call_invitation_expired' &&
      entry.payload.username === 'carol',
    ).length,
    2,
    'both active call participants receive the no-answer status',
  );

  // A stale timer callback cannot emit a second no-answer result.
  timer.callback();
  assert.equal(
    fixture.delivered.filter((entry) =>
      entry.name === 'group_call_invitation_expired' &&
      entry.payload.username === 'carol',
    ).length,
    2,
  );
});

test('accepting an invitation cancels its no-answer timer and releases the pending seat', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  const timer = fixture.scheduledInvites[0];
  const joined = invoke(fixture.sockets.get('carol'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });

  assert.equal(joined.ok, true);
  assert.equal(timer.cancelled, true);
  assert.equal(joined.pendingInvitations.length, 0);
  timer.callback();
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.name === 'group_call_invitation_expired' &&
      entry.payload.username === 'carol',
    ),
    false,
  );
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

test('late joiners receive current microphone, camera and screen-share state', () => {
  const fixture = makeFixture();
  const promoted = invoke(fixture.sockets.get('alice'), 'group_call_promote', {
    callId: 'call-1',
  });
  fixture.sockets.get('alice').handlers.get('group_call_media_state')({
    groupCallId: promoted.groupCallId,
    audioEnabled: false,
    videoEnabled: true,
  });
  fixture.sockets.get('bob').handlers.get('group_call_media_state')({
    groupCallId: promoted.groupCallId,
    audioEnabled: true,
    videoEnabled: false,
  });
  fixture.sockets.get('alice').handlers.get('group_call_screen_share_state')({
    groupCallId: promoted.groupCallId,
    streamId: 'screen-a',
  });
  invoke(fixture.sockets.get('alice'), 'group_call_invite', {
    groupCallId: promoted.groupCallId,
    to: 'carol',
  });
  const joined = invoke(fixture.sockets.get('carol'), 'group_call_accept', {
    groupCallId: promoted.groupCallId,
  });

  assert.equal(joined.ok, true);
  assert.equal(joined.mediaStates.alice.audioEnabled, false);
  assert.equal(joined.mediaStates.bob.videoEnabled, false);
  assert.equal(joined.screenSharer, 'alice');
  assert.equal(joined.screenStreamId, 'screen-a');
  assert.equal(
    fixture.delivered.some((entry) =>
      entry.socketId === 'carol-socket' &&
      entry.name === 'group_call_screen_share_state' &&
      entry.payload.streamId === 'screen-a',
    ),
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
