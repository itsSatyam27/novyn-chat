"use strict";

function normalizeDelay(value, fallback, minimum = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(minimum, Math.floor(parsed)) : fallback;
}

function safeErrorMessage(error) {
  return String(error?.message || error || "Unknown persistence error")
    .replace(/mongodb(?:\+srv)?:\/\/\S+/gi, "[redacted MongoDB URI]")
    .slice(0, 300);
}

/**
 * Debounced, single-flight persistence with bounded exponential backoff.
 * Failed writes stay dirty and retry in the background until storage recovers.
 * flush() performs one write attempt and rejects on failure so shutdown and
 * critical callers can report that persistence did not complete.
 */
function createResilientPersistenceQueue(options = {}) {
  if (typeof options.write !== "function") {
    throw new TypeError("A persistence write function is required.");
  }

  const write = options.write;
  const label = String(options.label || "state");
  const debounceMs = normalizeDelay(options.debounceMs, 180);
  const retryBaseMs = normalizeDelay(options.retryBaseMs, 500, 1);
  const retryMaxMs = Math.max(
    retryBaseMs,
    normalizeDelay(options.retryMaxMs, 30_000, 1)
  );
  const logger = options.logger || console;
  const setTimeoutFn = options.setTimeoutFn || setTimeout;
  const clearTimeoutFn = options.clearTimeoutFn || clearTimeout;

  let timer = null;
  let inFlight = null;
  let dirty = false;
  let stopped = false;
  let consecutiveFailures = 0;
  let lastSuccessAt = null;
  let lastFailureAt = null;

  function clearTimer() {
    if (timer) {
      clearTimeoutFn(timer);
      timer = null;
    }
  }

  function retryDelayMs() {
    const exponent = Math.min(30, Math.max(0, consecutiveFailures - 1));
    return Math.min(retryMaxMs, retryBaseMs * (2 ** exponent));
  }

  function scheduleTimer(delayMs) {
    if (stopped || timer || inFlight || !dirty) return;
    timer = setTimeoutFn(() => {
      timer = null;
      void flush({ force: false }).catch(() => {});
    }, Math.max(0, delayMs));
    if (typeof timer?.unref === "function") timer.unref();
  }

  function schedule() {
    if (stopped) return false;
    dirty = true;
    scheduleTimer(debounceMs);
    return true;
  }

  async function flush({ force = true } = {}) {
    clearTimer();
    if (inFlight) {
      await inFlight;
      if (dirty) return flush({ force: false });
      return;
    }

    if (force) dirty = true;
    if (!dirty) return;

    const attempt = (async () => {
      while (dirty) {
        dirty = false;
        try {
          await write();
          consecutiveFailures = 0;
          lastSuccessAt = Date.now();
        } catch (error) {
          dirty = true;
          consecutiveFailures += 1;
          lastFailureAt = Date.now();
          const delayMs = retryDelayMs();
          try {
            logger?.error?.(
              `[NovynPersistence] ${label} write failed; retrying in ${delayMs}ms:`,
              safeErrorMessage(error)
            );
          } catch (_) {
            // Logging must never replace the original persistence failure.
          }
          throw error;
        }
      }
    })();

    inFlight = attempt;
    try {
      await attempt;
    } finally {
      if (inFlight === attempt) inFlight = null;
      if (dirty && !stopped) scheduleTimer(retryDelayMs());
    }
  }

  async function stop() {
    stopped = true;
    clearTimer();
    if (inFlight) {
      try {
        await inFlight;
      } catch (_) {
        // Shutdown performs a final explicit flush after background work stops.
      }
    }
  }

  function getStatus() {
    return {
      healthy: consecutiveFailures === 0,
      pending: dirty,
      writing: Boolean(inFlight),
      consecutiveFailures,
      lastSuccessAt: lastSuccessAt ? new Date(lastSuccessAt).toISOString() : null,
      lastFailureAt: lastFailureAt ? new Date(lastFailureAt).toISOString() : null,
    };
  }

  return { schedule, flush, stop, getStatus };
}

module.exports = { createResilientPersistenceQueue };
