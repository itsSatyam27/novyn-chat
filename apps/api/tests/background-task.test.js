"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createBackgroundTask } = require("../server/core/background-task");

test("background task prevents overlapping executions", async () => {
  let release;
  let runs = 0;
  const gate = new Promise((resolve) => { release = resolve; });
  const task = createBackgroundTask({
    name: "single-flight-test",
    intervalMs: 60_000,
    run: async () => {
      runs += 1;
      await gate;
    },
    logger: { error() {} },
  });

  const first = task.runOnce();
  await Promise.resolve();
  const second = await task.runOnce();
  assert.deepEqual(second, { ok: false, skipped: true });
  release();
  assert.deepEqual(await first, { ok: true });
  assert.equal(runs, 1);
  assert.equal(task.getStatus().skippedRuns, 1);
  await task.stop();
});

test("failed background task is isolated and can recover on the next run", async () => {
  let runs = 0;
  const task = createBackgroundTask({
    name: "recoverable-test",
    run: async () => {
      runs += 1;
      if (runs === 1) throw new Error("temporary failure");
    },
    logger: { error() {} },
  });

  assert.equal((await task.runOnce()).ok, false);
  assert.equal(task.getStatus().consecutiveFailures, 1);
  assert.equal((await task.runOnce()).ok, true);
  assert.equal(task.getStatus().consecutiveFailures, 0);
  assert.equal(runs, 2);
  await task.stop();
});

test("stopping a task is idempotent and prevents future runs", async () => {
  let runs = 0;
  const task = createBackgroundTask({
    run: async () => { runs += 1; },
    logger: { error() {} },
  });

  await task.stop();
  await task.stop();
  assert.deepEqual(await task.runOnce(), { ok: false, stopped: true });
  assert.equal(runs, 0);
});
