const test = require('node:test');
const assert = require('node:assert/strict');
const { buildUserSearchResults } = require('../server/users/search');

function makeUser(username, overrides = {}) {
  return {
    username,
    isRegistered: true,
    displayName: username.toUpperCase(),
    avatarId: `avatar-${username}`,
    bio: 'hello',
    friends: new Set(),
    requests: new Set(),
    friendRequestPrivacy: 'everyone',
    ...overrides,
  };
}

function searchFixture(users, options = {}) {
  const byName = new Map(users.map((user) => [user.username.toLowerCase(), user]));
  return buildUserSearchResults({
    users: byName,
    userKey: 'me',
    query: options.query || 'ali',
    usersAreBlocked: (left, right) =>
      options.blocked?.has(`${left}:${right}`) ||
      options.blocked?.has(`${right}:${left}`),
    privacyAllows: (user, viewer, setting) =>
      options.hidden?.has(`${user.username}:${setting}`) !== true,
    getEffectivePresence: (key) => options.presence?.get(key) || 'offline',
    getVisibleLastSeen: (user) => user.lastSeenAt || null,
    limit: options.limit || 8,
  });
}

test('username search is case-insensitive and ranks exact and prefix matches first', () => {
  const me = makeUser('me');
  const contains = makeUser('xali');
  const prefix = makeUser('alice');
  const exact = makeUser('ali');
  const results = searchFixture([contains, exact, me, prefix]);

  assert.deepEqual(
    results.map((user) => user.username),
    ['ali', 'alice', 'xali'],
  );
});

test('username search excludes self, unregistered users, blocked users and friends', () => {
  const me = makeUser('me');
  me.friends.add('alicia');
  const results = searchFixture([
    me,
    makeUser('alicia'),
    makeUser('alina', { isRegistered: false }),
    makeUser('alison'),
  ], { blocked: new Set(['me:alison']) });

  assert.deepEqual(results, []);
});

test('username search reports request state and respects friend-request privacy', () => {
  const me = makeUser('me');
  const sent = makeUser('alina');
  sent.requests.add('me');
  const incoming = makeUser('alison');
  me.requests.add('alison');
  const nobody = makeUser('alice', { friendRequestPrivacy: 'nobody' });
  const results = searchFixture([me, sent, incoming, nobody]);

  assert.equal(results.find((user) => user.username === 'alina').requestStatus, 'sent');
  assert.equal(results.find((user) => user.username === 'alison').requestStatus, 'incoming');
  assert.equal(results.find((user) => user.username === 'alice').canRequest, false);
});

test('username search limits profile data and honors avatar and presence privacy', () => {
  const me = makeUser('me');
  const alice = makeUser('alice', {
    email: 'private@example.com',
    age: 30,
    lastSeenAt: '2026-11-14T00:00:00.000Z',
  });
  const results = searchFixture([me, alice], {
    hidden: new Set(['alice:profilePhotoPrivacy']),
    presence: new Map([['alice', 'online']]),
  });
  const result = results[0];

  assert.equal(result.avatarId, '');
  assert.equal(result.online, true);
  assert.equal(Object.hasOwn(result, 'email'), false);
  assert.equal(Object.hasOwn(result, 'age'), false);
});
