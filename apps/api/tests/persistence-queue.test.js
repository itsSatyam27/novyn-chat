"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createResilientPersistenceQueue } = require("../server/core/persistence-queue");

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

test("coalesces bursts of scheduled writes into one save", async () => {
  let writes = 0;
  const queue = createResilientPersistenceQueue({
    write: async () => { writes += 1; },
    debounceMs: 5,
    logger: { error() {} },
  });

  queue.schedule();
  queue.schedule();
  queue.schedule();
  await wait(30);

  assert.equal(writes, 1);
  assert.equal(queue.getStatus().healthy, true);
  await queue.stop();
});

test("retries a failed persistence write with backoff and clears degraded state after recovery", async () => {
  let writes = 0;
  const queue = createResilientPersistenceQueue({
    write: async () => {
      writes += 1;
      if (writes === 1) throw new Error("temporary storage outage");
    },
    debounceMs: 1,
    retryBaseMs: 5,
    retryMaxMs: 10,
    logger: { error() {} },
  });

  queue.schedule();
  await wait(50);

  assert.equal(writes, 2);
  assert.equal(queue.getStatus().healthy, true);
  assert.equal(queue.getStatus().pending, false);
  assert.ok(queue.getStatus().lastSuccessAt);
  await queue.stop();
});

test("a failed explicit flush rejects but keeps the latest state queued for retry", async () => {
  let writes = 0;
  const queue = createResilientPersistenceQueue({
    write: async () => {
      writes += 1;
      if (writes === 1) throw new Error("database temporarily unavailable");
    },
    retryBaseMs: 5,
    retryMaxMs: 10,
    logger: { error() {} },
  });

  await assert.rejects(queue.flush(), /database temporarily unavailable/);
  assert.equal(queue.getStatus().healthy, false);
  assert.equal(queue.getStatus().pending, true);
  await wait(40);
  assert.equal(writes, 2);
  assert.equal(queue.getStatus().healthy, true);
  await queue.stop();
});

test("writes scheduled during an in-flight save are not lost", async () => {
  let releaseFirst;
  let writes = 0;
  const gate = new Promise((resolve) => { releaseFirst = resolve; });
  const queue = createResilientPersistenceQueue({
    write: async () => {
      writes += 1;
      if (writes === 1) await gate;
    },
    logger: { error() {} },
  });

  const firstFlush = queue.flush();
  await Promise.resolve();
  queue.schedule();
  releaseFirst();
  await firstFlush;

  assert.equal(writes, 2);
  assert.equal(queue.getStatus().pending, false);
  await queue.stop();
});

test("stop cancels pending debounce timers without starting another write", async () => {
  let writes = 0;
  const queue = createResilientPersistenceQueue({
    write: async () => { writes += 1; },
    debounceMs: 100,
    logger: { error() {} },
  });

  queue.schedule();
  await queue.stop();
  await wait(10);

  assert.equal(writes, 0);
  assert.equal(queue.getStatus().pending, true);
});
