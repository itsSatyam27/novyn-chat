"use strict";

function createBackgroundTask(options = {}) {
  if (typeof options.run !== "function") {
    throw new TypeError("A background task run function is required.");
  }

  const name = String(options.name || "background-task");
  const intervalMs = Math.max(1, Math.floor(Number(options.intervalMs) || 60_000));
  const run = options.run;
  const logger = options.logger || console;
  const setIntervalFn = options.setIntervalFn || setInterval;
  const clearIntervalFn = options.clearIntervalFn || clearInterval;

  let timer = null;
  let inFlight = null;
  let stopped = false;
  let consecutiveFailures = 0;
  let skippedRuns = 0;
  let lastSuccessAt = null;
  let lastFailureAt = null;

  async function runOnce() {
    if (inFlight) {
      skippedRuns += 1;
      return { ok: false, skipped: true };
    }
    if (stopped) return { ok: false, stopped: true };

    const attempt = (async () => {
      try {
        await run();
        consecutiveFailures = 0;
        lastSuccessAt = new Date().toISOString();
        return { ok: true };
      } catch (error) {
        consecutiveFailures += 1;
        lastFailureAt = new Date().toISOString();
        try {
          logger?.error?.(
            `[NovynBackground] ${name} failed (consecutive failures: ${consecutiveFailures}):`,
            String(error?.message || error || "Unknown error").slice(0, 300)
          );
        } catch (_) {
          // A logging failure must not crash the process or the scheduler.
        }
        return { ok: false, error };
      }
    })();

    inFlight = attempt;
    try {
      return await attempt;
    } finally {
      if (inFlight === attempt) inFlight = null;
    }
  }

  function start() {
    if (stopped || timer) return false;
    timer = setIntervalFn(() => {
      void runOnce();
    }, intervalMs);
    if (typeof timer?.unref === "function") timer.unref();
    return true;
  }

  async function stop() {
    stopped = true;
    if (timer) {
      clearIntervalFn(timer);
      timer = null;
    }
    if (inFlight) await inFlight;
  }

  function getStatus() {
    return {
      running: Boolean(timer),
      inFlight: Boolean(inFlight),
      stopped,
      consecutiveFailures,
      skippedRuns,
      lastSuccessAt,
      lastFailureAt,
    };
  }

  return { start, runOnce, stop, getStatus };
}

module.exports = { createBackgroundTask };
