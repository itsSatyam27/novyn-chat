const test = require("node:test");
const assert = require("node:assert/strict");
const { createShutdownHandler } = require("../server/core/shutdown");

test("graceful shutdown drains startup, transport, timers, persistence, and storage in order", async () => {
  const calls = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => calls.push("startup"),
    closeTransport: async () => calls.push("transport"),
    stopBackgroundWork: async () => calls.push("timers"),
    flushState: async () => calls.push("persist"),
    closeStorage: async () => calls.push("storage"),
    timeoutMs: 1000,
    logger: { error() {} },
  });

  const first = shutdown("SIGTERM");
  const repeated = shutdown("SIGINT");
  assert.equal(first, repeated);
  assert.equal(await first, 0);
  assert.deepEqual(calls, ["startup", "transport", "timers", "persist", "storage"]);
});

test("graceful shutdown continues cleanup after a persistence failure and returns a failure code", async () => {
  const calls = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => calls.push("startup"),
    closeTransport: async () => calls.push("transport"),
    stopBackgroundWork: async () => calls.push("timers"),
    flushState: async () => {
      calls.push("persist");
      throw new Error("disk unavailable");
    },
    closeStorage: async () => calls.push("storage"),
    timeoutMs: 1000,
    logger: { error() {} },
  });

  assert.equal(await shutdown("SIGTERM"), 1);
  assert.deepEqual(calls, ["startup", "transport", "timers", "persist", "storage"]);
});

test("graceful shutdown invokes the hard-timeout handler when a drain step stalls", async () => {
  let releaseTransport;
  let timedOut = false;
  const shutdown = createShutdownHandler({
    closeTransport: () => new Promise((resolve) => {
      releaseTransport = resolve;
    }),
    timeoutMs: 10,
    onTimeout: () => {
      timedOut = true;
    },
    logger: { error() {} },
  });

  const completion = shutdown("SIGTERM");
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.equal(timedOut, true);
  releaseTransport();
  assert.equal(await completion, 1);
});
