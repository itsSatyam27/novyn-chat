const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { createIdentityRateLimiter } = require("../server/auth/identity-rate-limit");

function invoke(middleware, identity, ip) {
  const result = { status: 200, nextCalled: false, body: null };
  const req = { body: { identifier: identity }, ip };
  const res = {
    status(code) { result.status = code; return this; },
    json(body) { result.body = body; return this; },
  };
  middleware(req, res, () => { result.nextCalled = true; });
  return result;
}

test("identity rate limiting follows one account across changing IP addresses", () => {
  const store = new Map();
  const limiter = createIdentityRateLimiter({
    store,
    getIdentity: (req) => req.body.identifier,
  }, "signin-account", 2, 60_000);

  assert.equal(invoke(limiter, "Alice@Example.test", "192.0.2.1").nextCalled, true);
  assert.equal(invoke(limiter, "alice@example.test", "192.0.2.2").nextCalled, true);
  const blocked = invoke(limiter, "ALICE@example.test", "198.51.100.8");
  assert.equal(blocked.status, 429);
  assert.equal(blocked.nextCalled, false);

  const digest = crypto.createHash("sha256").update("alice@example.test").digest("hex");
  assert.ok(store.has("signin-account:" + digest));
  assert.ok(![...store.keys()].some((key) => key.includes("alice") || key.includes("@example")));
  assert.equal(invoke(limiter, "bob@example.test", "192.0.2.1").nextCalled, true);
});

test("identity limiter skips missing identifiers and fails closed without a store", () => {
  const emptyStoreLimiter = createIdentityRateLimiter({
    store: new Map(),
    getIdentity: (req) => req.body.identifier,
  }, "signin-account", 2, 60_000);
  assert.equal(invoke(emptyStoreLimiter, "", "192.0.2.1").nextCalled, true);

  const unavailable = createIdentityRateLimiter({
    getStore: () => null,
    getIdentity: (req) => req.body.identifier,
  }, "signin-account", 2, 60_000);
  const result = invoke(unavailable, "alice@example.test", "192.0.2.1");
  assert.equal(result.status, 503);
  assert.equal(result.nextCalled, false);
});
