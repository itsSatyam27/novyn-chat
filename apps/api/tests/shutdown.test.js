"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createShutdownHandler } = require("../server/core/shutdown");

test("shutdown is idempotent and runs cleanup in the required order", async () => {
  const order = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => { order.push("startup"); },
    closeTransport: async () => { order.push("transport"); },
    stopBackgroundWork: async () => { order.push("background"); },
    flushState: async () => { order.push("flush"); },
    closeStorage: async () => { order.push("storage"); },
    timeoutMs: 1_000,
    logger: { error() {} },
  });

  const first = shutdown("SIGTERM");
  const second = shutdown("SIGINT");
  assert.equal(first, second);
  assert.equal(await first, 0);
  assert.deepEqual(order, ["startup", "transport", "background", "flush", "storage"]);
});

test("shutdown continues cleanup after a step fails and returns a failure exit code", async () => {
  const order = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => { order.push("startup"); },
    closeTransport: async () => { order.push("transport"); throw new Error("transport failed"); },
    stopBackgroundWork: async () => { order.push("background"); },
    flushState: async () => { order.push("flush"); },
    closeStorage: async () => { order.push("storage"); },
    timeoutMs: 1_000,
    logger: { error() {} },
  });

  assert.equal(await shutdown("SIGTERM"), 1);
  assert.deepEqual(order, ["startup", "transport", "background", "flush", "storage"]);
});
