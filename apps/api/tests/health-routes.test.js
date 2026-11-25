"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { registerHealthRoutes } = require("../server/routes/health");

function createHealthHarness(dependencies = {}) {
  const handlers = new Map();
  const app = {
    get(route, handler) {
      handlers.set(route, handler);
    },
  };
  registerHealthRoutes({
    app,
    getMongoUri: dependencies.getMongoUri || (() => ""),
    getMongoStorage: dependencies.getMongoStorage || (() => null),
    hasMongoStorage: dependencies.hasMongoStorage || (() => false),
    getPersistenceStatus: dependencies.getPersistenceStatus,
  });

  function createResponse() {
    return {
      headers: {},
      statusCode: null,
      body: null,
      set(name, value) {
        this.headers[name] = value;
        return this;
      },
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(body) {
        this.body = body;
        return this;
      },
    };
  }

  return { handlers, createResponse };
}

test("liveness reports process health without checking MongoDB", () => {
  const harness = createHealthHarness({
    getMongoUri() {
      throw new Error("liveness must not inspect database configuration");
    },
  });
  const response = harness.createResponse();

  harness.handlers.get("/health")({}, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, { ok: true, status: "live" });
  assert.equal(response.headers["Cache-Control"], "no-store, max-age=0");
});

test("readiness rejects configured MongoDB when storage has not initialized", async () => {
  const harness = createHealthHarness({
    getMongoUri: () => "mongodb://configured.example/novyn",
    getMongoStorage: () => null,
    hasMongoStorage: () => false,
  });
  const response = harness.createResponse();

  await harness.handlers.get("/health/ready")({}, response);

  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, {
    ok: false,
    ready: false,
    storage: "mongodb",
    message: "Database storage is not initialized.",
  });
  assert.equal(response.headers["Cache-Control"], "no-store, max-age=0");
});

test("readiness returns a generic service-unavailable response when MongoDB ping fails", async () => {
  const harness = createHealthHarness({
    getMongoUri: () => "mongodb://configured.example/novyn",
    getMongoStorage: () => ({
      async ping() {
        throw new Error("sensitive database connection details");
      },
    }),
    hasMongoStorage: () => true,
  });
  const response = harness.createResponse();
  const originalWarn = console.warn;
  console.warn = () => {};
  try {
    await harness.handlers.get("/health/ready")({}, response);
  } finally {
    console.warn = originalWarn;
  }

  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, {
    ok: false,
    ready: false,
    storage: "mongodb",
    message: "Database is temporarily unavailable.",
  });
  assert.equal(JSON.stringify(response.body).includes("sensitive"), false);
});

test("readiness succeeds after MongoDB responds to ping", async () => {
  const harness = createHealthHarness({
    getMongoUri: () => "mongodb://configured.example/novyn",
    getMongoStorage: () => ({ async ping() { return true; } }),
    hasMongoStorage: () => true,
  });
  const response = harness.createResponse();

  await harness.handlers.get("/health/ready")({}, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    ok: true,
    ready: true,
    storage: "mongodb",
    persistentStorage: true,
  });
});

test("readiness reports degraded state when persisted writes are failing", async () => {
  const harness = createHealthHarness({
    getPersistenceStatus: () => ({
      chat: { consecutiveFailures: 2 },
      auth: { consecutiveFailures: 0 },
    }),
  });
  const response = harness.createResponse();

  await harness.handlers.get("/health/ready")({}, response);

  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, {
    ok: false,
    ready: false,
    storage: "file",
    persistence: "degraded",
    message: "Persistent storage is temporarily unavailable.",
  });
});

test("readiness recovers after persistence writes succeed again", async () => {
  let failures = 1;
  const harness = createHealthHarness({
    getPersistenceStatus: () => ({
      chat: { consecutiveFailures: failures },
      auth: { consecutiveFailures: 0 },
    }),
  });
  const handler = harness.handlers.get("/health/ready");
  const degradedResponse = harness.createResponse();
  await handler({}, degradedResponse);
  assert.equal(degradedResponse.statusCode, 503);

  failures = 0;
  const healthyResponse = harness.createResponse();
  await handler({}, healthyResponse);
  assert.equal(healthyResponse.statusCode, 200);
  assert.equal(healthyResponse.body.ready, true);
});
