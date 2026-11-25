const test = require("node:test");
const assert = require("node:assert/strict");
const { createSocketActionRateLimiter } = require("../server/auth/socket-rate-limit");

function makeSocket(userKey, address = "192.0.2.1") {
  return { data: { userKey }, handshake: { address } };
}

test("socket action limits are shared across simultaneous sockets for one account", () => {
  const store = new Map();
  const allow = createSocketActionRateLimiter({
    getStore: () => store,
    getClientIp: (socket) => socket.handshake.address,
  });
  const first = makeSocket("alice");
  const second = makeSocket("alice", "198.51.100.7");

  assert.equal(allow(first, "send_message", 2, 60_000), true);
  assert.equal(allow(second, "send_message", 2, 60_000), true);
  assert.equal(allow(first, "send_message", 2, 60_000), false);
});

test("socket action limits retain a per-socket burst guard", () => {
  const store = new Map();
  const allow = createSocketActionRateLimiter({ getStore: () => store });
  const socket = makeSocket("alice");
  assert.equal(allow(socket, "edit_message", 1, 60_000), true);
  assert.equal(allow(socket, "edit_message", 1, 60_000), false);
});

test("socket action buckets expire and allow a new window", () => {
  const store = new Map();
  let timestamp = 1_000;
  const allow = createSocketActionRateLimiter({
    getStore: () => store,
    now: () => timestamp,
  });
  const socket = makeSocket("alice");
  assert.equal(allow(socket, "send_message", 1, 5_000), true);
  timestamp += 5_001;
  assert.equal(allow(socket, "send_message", 1, 5_000), true);
  assert.equal(store.get("alice:send_message").count, 1);
});

test("socket rate-limit store prunes expired entries and remains bounded", () => {
  const store = new Map([
    ["expired:send_message", { count: 9, expiresAt: 999 }],
    ["active:send_message", { count: 1, expiresAt: 50_000 }],
  ]);
  let timestamp = 1_000;
  const allow = createSocketActionRateLimiter({
    getStore: () => store,
    now: () => timestamp,
    maxEntries: 2,
    pruneIntervalMs: 60_000,
  });
  assert.equal(allow(makeSocket("new-user"), "send_message", 5, 60_000), true);
  assert.equal(store.size, 2);
  assert.ok(store.has("active:send_message"));
  assert.ok(store.has("new-user:send_message"));
  assert.ok(!store.has("expired:send_message"));
});

test("socket rate-limit store refuses new buckets when all capacity is active", () => {
  const store = new Map([
    ["active-user:send_message", { count: 1, expiresAt: 50_000 }],
  ]);
  const allow = createSocketActionRateLimiter({
    getStore: () => store,
    now: () => 1_000,
    maxEntries: 1,
  });
  assert.equal(allow(makeSocket("new-user"), "send_message", 5, 60_000), false);
  assert.equal(store.size, 1);
  assert.ok(store.has("active-user:send_message"));
});

test("socket rate limiter fails closed when the backing store is unavailable", () => {
  const allow = createSocketActionRateLimiter({ getStore: () => null });
  assert.equal(allow(makeSocket("alice"), "send_message", 10, 60_000), false);
});
