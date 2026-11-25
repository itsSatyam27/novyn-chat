"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const { createRequestObservability } = require("../server/observability/request-logging");

function createHarness(options = {}) {
  const events = [];
  const logger = {
    info(message) { events.push({ level: "info", event: JSON.parse(message) }); },
    warn(message) { events.push({ level: "warn", event: JSON.parse(message) }); },
    error(message) { events.push({ level: "error", event: JSON.parse(message) }); },
  };
  const response = new EventEmitter();
  response.headers = {};
  response.statusCode = 200;
  response.writableFinished = false;
  response.setHeader = function setHeader(name, value) {
    this.headers[name] = value;
  };

  let clock = 0;
  const middleware = createRequestObservability({
    logger,
    now: () => clock,
    requestIdFactory: () => "req-test-123",
    ...options,
  });
  const request = {
    method: "GET",
    originalUrl: "/users/private-user?token=secret",
    baseUrl: "/api",
    query: { token: "secret" },
    route: { path: "/users/:username" },
  };
  let nextCalls = 0;

  middleware(request, response, () => { nextCalls += 1; });

  return {
    request,
    response,
    events,
    setTime(value) { clock = value; },
    getNextCalls() { return nextCalls; },
  };
}

test("request logging assigns a correlation ID and logs only the route template", () => {
  const harness = createHarness();
  assert.equal(harness.request.requestId, "req-test-123");
  assert.equal(harness.response.headers["X-Request-Id"], "req-test-123");
  assert.equal(harness.getNextCalls(), 1);

  harness.setTime(12.345);
  harness.response.writableFinished = true;
  harness.response.emit("finish");

  assert.equal(harness.events.length, 1);
  assert.equal(harness.events[0].level, "info");
  assert.deepEqual(harness.events[0].event, {
    event: "http_request",
    requestId: "req-test-123",
    method: "GET",
    route: "/users/:username",
    statusCode: 200,
    durationMs: 12.35,
  });
  const serialized = JSON.stringify(harness.events[0].event);
  assert.equal(serialized.includes("private-user"), false);
  assert.equal(serialized.includes("secret"), false);
});

test("server errors are logged at error level with a status code", () => {
  const harness = createHarness();
  harness.response.statusCode = 503;
  harness.setTime(20);
  harness.response.writableFinished = true;
  harness.response.emit("finish");

  assert.equal(harness.events.length, 1);
  assert.equal(harness.events[0].level, "error");
  assert.equal(harness.events[0].event.statusCode, 503);
});

test("slow successful requests are logged at warning level", () => {
  const harness = createHarness({ slowRequestMs: 50 });
  harness.setTime(51);
  harness.response.writableFinished = true;
  harness.response.emit("finish");

  assert.equal(harness.events[0].level, "warn");
  assert.equal(harness.events[0].event.durationMs, 51);
});

test("blank threshold uses the safe default rather than warning on every request", () => {
  const harness = createHarness({ slowRequestMs: "" });
  harness.setTime(50);
  harness.response.writableFinished = true;
  harness.response.emit("finish");

  assert.equal(harness.events[0].level, "info");
});

test("aborted responses are logged once even when close is followed by finish", () => {
  const harness = createHarness();
  harness.setTime(8);
  harness.response.writableFinished = false;
  harness.response.emit("close");
  harness.response.writableFinished = true;
  harness.response.emit("finish");

  assert.equal(harness.events.length, 1);
  assert.equal(harness.events[0].level, "warn");
  assert.equal(harness.events[0].event.aborted, true);
});

test("logger failures never interrupt request processing", () => {
  let nextCalls = 0;
  const response = new EventEmitter();
  response.statusCode = 200;
  response.writableFinished = true;
  response.setHeader = () => {};
  const middleware = createRequestObservability({
    logger: { info() { throw new Error("logger unavailable"); } },
    requestIdFactory: () => "req-safe",
  });

  assert.doesNotThrow(() => middleware({ method: "POST" }, response, () => { nextCalls += 1; }));
  assert.equal(nextCalls, 1);
  assert.doesNotThrow(() => response.emit("finish"));
});
