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
  const pushes = [];
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
    sendPushToUser: (userKey, payload) => {
      pushes.push({ userKey, payload });
      return Promise.resolve();
    },
    recordCallLog: () => {},
    delivered,
    pushes,
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


test('unanswered outgoing calls send a missed-call push only to the receiver', () => {
  const deps = makeDeps();
  const caller = makeSocket('alice');
  registerCallHandlers(caller, deps);

  caller.handlers.get('call_start')({ to: 'bob', callId: 'unanswered-call' });
  caller.handlers.get('call_end')({ to: 'bob', callId: 'unanswered-call' });

  const missedPushes = deps.pushes.filter(
    (entry) => entry.payload.callStatus === 'missed',
  );
  assert.equal(missedPushes.length, 1);
  assert.equal(missedPushes[0].userKey, 'bob');
  assert.match(missedPushes[0].payload.body, /alice/i);
  assert.equal(
    deps.pushes.some((entry) =>
      entry.userKey === 'alice' && entry.payload.callStatus === 'missed',
    ),
    false,
  );
  assert.equal(deps.activeCalls.size, 0);
});

test('only the invited recipient can accept a ringing call, and acceptance is single-use', () => {
  const deps = makeDeps();
  const caller = makeSocket('alice');
  const recipient = makeSocket('bob');
  registerCallHandlers(caller, deps);
  registerCallHandlers(recipient, deps);

  caller.handlers.get('call_start')({ to: 'bob', callId: 'accept-once' });
  let callerAck = null;
  caller.handlers.get('call_accept')(
    { to: 'bob', callId: 'accept-once' },
    (result) => { callerAck = result; },
  );
  assert.equal(callerAck?.ok, false);
  assert.equal(deps.activeCalls.get('alice')?.status, 'ringing');
  assert.equal(deps.delivered.some((event) =>
    event.name === 'call_accepted' && event.payload.callId === 'accept-once',
  ), false);

  let recipientAck = null;
  recipient.handlers.get('call_accept')(
    { to: 'alice', callId: 'accept-once' },
    (result) => { recipientAck = result; },
  );
  assert.deepEqual(recipientAck, {
    ok: true, callId: 'accept-once', status: 'connected',
  });
  assert.equal(deps.activeCalls.get('alice')?.status, 'connected');
  assert.equal(deps.delivered.some((event) =>
    event.socketId === 'alice-socket' &&
    event.name === 'call_accepted' &&
    event.payload.callId === 'accept-once',
  ), true);

  let repeatedAck = null;
  recipient.handlers.get('call_accept')(
    { to: 'alice', callId: 'accept-once' },
    (result) => { repeatedAck = result; },
  );
  assert.equal(repeatedAck?.ok, false);
  assert.equal(deps.delivered.filter((event) =>
    event.name === 'call_accepted' && event.payload.callId === 'accept-once',
  ).length, 1);
});

test('screen-share state and WebRTC presentation signals reach the peer', () => {
  const deps = makeDeps();
  const caller = makeSocket('alice');
  const recipient = makeSocket('bob');
  registerCallHandlers(caller, deps);
  registerCallHandlers(recipient, deps);

  caller.handlers.get('call_start')({ to: 'bob', isVideo: true, callId: 'share-call' });
  recipient.handlers.get('call_accept')(
    { to: 'alice', callId: 'share-call' },
    () => {},
  );

  caller.handlers.get('call_screen_share_state')({
    to: 'bob',
    callId: 'share-call',
    streamId: 'alice-media-stream',
    replacesVideoTrack: true,
  });
  const shareState = deps.delivered.find((event) =>
    event.socketId === 'bob-socket' &&
    event.name === 'call_screen_share_changed',
  );
  assert.deepEqual(shareState?.payload, {
    from: 'alice',
    callId: 'share-call',
    streamId: 'alice-media-stream',
    replacesVideoTrack: true,
  });

  caller.handlers.get('webrtc_signal')({
    to: 'bob',
    callId: 'share-call',
    signal: {
      type: 'screen_share_state',
      isSharing: true,
      streamId: 'alice-media-stream',
      replacesVideoTrack: true,
    },
  });
  const browserCompatibleSignal = deps.delivered.find((event) =>
    event.socketId === 'bob-socket' &&
    event.name === 'webrtc_signal' &&
    event.payload.signal?.type === 'screen_share_state',
  );
  assert.equal(browserCompatibleSignal?.payload.signal.replacesVideoTrack, true);
  assert.equal(browserCompatibleSignal?.payload.signal.streamId, 'alice-media-stream');

  caller.handlers.get('call_screen_share_state')({
    to: 'bob',
    callId: 'share-call',
    streamId: null,
  });
  const stoppedState = deps.delivered.filter((event) =>
    event.socketId === 'bob-socket' &&
    event.name === 'call_screen_share_changed',
  ).at(-1);
  assert.deepEqual(stoppedState?.payload, {
    from: 'alice',
    callId: 'share-call',
    streamId: null,
    replacesVideoTrack: false,
  });
});
