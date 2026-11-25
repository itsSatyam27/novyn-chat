const test = require("node:test");
const assert = require("node:assert/strict");
const { createIpRateLimiter, getRequestClientIp, getSocketClientIp } = require("../server/auth/rate-limit");

function setRenderEnvironment(t, value) {
  const previous = process.env.RENDER;
  if (value === undefined) delete process.env.RENDER;
  else process.env.RENDER = value;
  t.after(() => {
    if (previous === undefined) delete process.env.RENDER;
    else process.env.RENDER = previous;
  });
}

function invokeLimiter(middleware, req) {
  const result = { status: 200, body: null, nextCalled: false };
  const res = {
    status(code) {
      result.status = code;
      return this;
    },
    json(body) {
      result.body = body;
      return this;
    },
  };
  middleware(req, res, () => {
    result.nextCalled = true;
  });
  return result;
}

test("Render rate limits use the canonical Cloudflare client IP", (t) => {
  setRenderEnvironment(t, "true");

  const store = new Map();
  const limiter = createIpRateLimiter({ store }, "signin", 1, 60_000);
  const request = (clientIp) => ({
    headers: {
      "cf-connecting-ip": clientIp,
      "x-forwarded-for": "198.51.100.99",
    },
    ip: "10.0.0.8",
    socket: { remoteAddress: "10.0.0.9" },
  });

  assert.equal(invokeLimiter(limiter, request("203.0.113.10")).nextCalled, true);
  assert.equal(invokeLimiter(limiter, request("203.0.113.10")).status, 429);
  assert.equal(invokeLimiter(limiter, request("203.0.113.11")).nextCalled, true);
});

test("Render rate limits do not trust X-Forwarded-For when Cloudflare IP is missing or invalid", (t) => {
  setRenderEnvironment(t, "true");

  const request = {
    headers: {
      "cf-connecting-ip": "203.0.113.10, 198.51.100.4",
      "x-forwarded-for": "198.51.100.77",
    },
    ip: "198.51.100.88",
    socket: { remoteAddress: "10.0.0.9" },
  };

  assert.equal(getRequestClientIp(request), "10.0.0.9");
});

test("non-Render deployments use Express's resolved request IP", (t) => {
  setRenderEnvironment(t, undefined);

  assert.equal(
    getRequestClientIp({
      headers: {
        "cf-connecting-ip": "203.0.113.10",
        "x-forwarded-for": "198.51.100.77",
      },
      ip: "192.0.2.44",
      socket: { remoteAddress: "10.0.0.9" },
    }),
    "192.0.2.44"
  );
});

test("invalid Express IP values fall back to a validated socket peer", (t) => {
  setRenderEnvironment(t, undefined);

  assert.equal(
    getRequestClientIp({
      ip: "not-an-ip",
      socket: { remoteAddress: "2001:db8::42" },
    }),
    "2001:db8::42"
  );
});

test("Render Socket.IO rate limits use the canonical Cloudflare client IP", (t) => {
  setRenderEnvironment(t, "true");

  const socket = (clientIp) => ({
    handshake: {
      address: "10.0.0.9",
      headers: {
        "cf-connecting-ip": clientIp,
        "x-forwarded-for": "198.51.100.99",
      },
    },
  });

  assert.equal(getSocketClientIp(socket("203.0.113.20")), "203.0.113.20");
  assert.equal(getSocketClientIp(socket("203.0.113.21")), "203.0.113.21");
});

test("Render Socket.IO rate limits ignore forwarded headers if the trusted edge IP is invalid", (t) => {
  setRenderEnvironment(t, "true");

  assert.equal(
    getSocketClientIp({
      handshake: {
        address: "10.0.0.9",
        headers: {
          "cf-connecting-ip": "203.0.113.20, 198.51.100.4",
          "x-forwarded-for": "198.51.100.77",
        },
      },
    }),
    "10.0.0.9"
  );
});

test("HTTP rate limiting fails closed when its store is unavailable", () => {
  const limiter = createIpRateLimiter({ getStore: () => null }, "signin", 5, 60_000);
  const result = invokeLimiter(limiter, {
    ip: "192.0.2.10",
    socket: { remoteAddress: "192.0.2.10" },
  });

  assert.equal(result.nextCalled, false);
  assert.equal(result.status, 503);
  assert.deepEqual(result.body, {
    error: "Rate limiting is temporarily unavailable. Please try again later.",
  });
});

test("HTTP rate limiting fails closed when the configured store is malformed", () => {
  const limiter = createIpRateLimiter({ store: {} }, "signin", 5, 60_000);
  const result = invokeLimiter(limiter, {
    ip: "192.0.2.10",
    socket: { remoteAddress: "192.0.2.10" },
  });

  assert.equal(result.nextCalled, false);
  assert.equal(result.status, 503);
});

test("rate limit storage refuses new IP buckets when its bounded store is full", (t) => {
  setRenderEnvironment(t, undefined);

  const store = new Map([
    ["signin:192.0.2.10", { count: 1, resetAt: Date.now() + 60_000 }],
  ]);
  const limiter = createIpRateLimiter(
    { store, maxEntries: 1, getClientIp: (req) => req.ip },
    "signin",
    3,
    60_000,
  );

  const existingIp = invokeLimiter(limiter, {
    ip: "192.0.2.10",
    socket: { remoteAddress: "192.0.2.10" },
  });
  assert.equal(existingIp.nextCalled, true, "existing buckets must keep enforcing their limit");

  const newIp = invokeLimiter(limiter, {
    ip: "192.0.2.11",
    socket: { remoteAddress: "192.0.2.11" },
  });
  assert.equal(newIp.nextCalled, false);
  assert.equal(newIp.status, 503);
  assert.deepEqual(newIp.body, {
    error: "Rate limiting is temporarily unavailable. Please try again later.",
  });
  assert.equal(store.size, 1, "the rate-limit store must not grow beyond its configured cap");
});

test("rate limiter prunes expired buckets before refusing a new IP", (t) => {
  setRenderEnvironment(t, undefined);

  const store = new Map([
    ["signin:192.0.2.10", { count: 3, resetAt: Date.now() - 1 }],
  ]);
  const limiter = createIpRateLimiter(
    { store, maxEntries: 1, getClientIp: (req) => req.ip },
    "signin",
    3,
    60_000,
  );

  const result = invokeLimiter(limiter, {
    ip: "192.0.2.11",
    socket: { remoteAddress: "192.0.2.11" },
  });
  assert.equal(result.nextCalled, true);
  assert.equal(result.status, 200);
  assert.equal(store.size, 1);
  assert.ok(store.has("signin:192.0.2.11"));
  assert.ok(!store.has("signin:192.0.2.10"));
});

test("rate limiter prunes malformed entries before allocating a new IP bucket", (t) => {
  setRenderEnvironment(t, undefined);

  const store = new Map([
    ["signin:malformed", { count: 99 }],
  ]);
  const limiter = createIpRateLimiter(
    { store, maxEntries: 1, getClientIp: (req) => req.ip },
    "signin",
    3,
    60_000,
  );

  const result = invokeLimiter(limiter, {
    ip: "192.0.2.12",
    socket: { remoteAddress: "192.0.2.12" },
  });
  assert.equal(result.nextCalled, true);
  assert.equal(store.size, 1);
  assert.ok(store.has("signin:192.0.2.12"));
  assert.ok(!store.has("signin:malformed"));
});

