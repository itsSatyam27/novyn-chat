"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createHttpErrorHandler, normalizeErrorStatus } = require("../server/observability/http-error-handler");

function responseHarness() {
  return {
    statusCode: null,
    body: null,
    writableEnded: false,
    headersSent: false,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; this.writableEnded = true; return this; },
  };
}

test("unexpected errors return safe 500 response with correlation ID and no internal details", () => {
  const logs = [];
  const handler = createHttpErrorHandler({ logger: { error: (line) => logs.push(JSON.parse(line)) } });
  const res = responseHarness();
  handler(new Error("database password and stack"), { requestId: "req-abc", method: "GET", route: { path: "/thing" } }, res, () => {});
  assert.equal(res.statusCode, 500);
  assert.deepEqual(res.body, { error: "Internal server error", requestId: "req-abc" });
  assert.equal(JSON.stringify(res.body).includes("password"), false);
  assert.equal(logs.length, 1);
  assert.equal(logs[0].requestId, "req-abc");
  assert.equal(logs[0].route, "/thing");
});

test("valid 4xx errors preserve their status and message", () => {
  const logs = [];
  const handler = createHttpErrorHandler({ logger: { warn: (line) => logs.push(JSON.parse(line)) } });
  const res = responseHarness();
  handler(Object.assign(new Error("Invalid request"), { status: 422, code: "VALIDATION" }), { requestId: "req-2", method: "POST" }, res, () => {});
  assert.equal(res.statusCode, 422);
  assert.deepEqual(res.body, { error: "Invalid request", requestId: "req-2" });
  assert.equal(logs[0].statusCode, 422);
  assert.equal(logs[0].errorCode, "VALIDATION");
});

test("errors with headers already sent delegate to Express", () => {
  let delegated = null;
  const handler = createHttpErrorHandler();
  const err = new Error("sent");
  handler(err, {}, { headersSent: true }, (nextErr) => { delegated = nextErr; });
  assert.equal(delegated, err);
});

test("errors after response ended do not write a second response", () => {
  let writes = 0;
  const handler = createHttpErrorHandler();
  handler(new Error("late"), { requestId: "req-3" }, { writableEnded: true, status() { writes++; return this; }, json() { writes++; } }, () => {});
  assert.equal(writes, 0);
});

test("logger failure cannot break error response", () => {
  const handler = createHttpErrorHandler({ logger: { error() { throw new Error("logger failed"); } } });
  const res = responseHarness();
  assert.doesNotThrow(() => handler(new Error("original"), { requestId: "req-safe" }, res, () => {}));
  assert.equal(res.statusCode, 500);
});

test("error status normalization only permits client 4xx statuses", () => {
  assert.equal(normalizeErrorStatus({ status: 400 }), 400);
  assert.equal(normalizeErrorStatus({ status: 404 }), 404);
  assert.equal(normalizeErrorStatus({ status: 99 }), 500);
  assert.equal(normalizeErrorStatus({ status: 502 }), 500);
  assert.equal(normalizeErrorStatus({ status: "abc" }), 500);
});
