"use strict";

function createShutdownHandler({
  waitForStartup = async () => {},
  closeTransport = async () => {},
  stopBackgroundWork = async () => {},
  flushState = async () => {},
  closeStorage = async () => {},
  timeoutMs = 25_000,
  onTimeout = () => {},
  logger = console,
} = {}) {
  let shutdownPromise = null;

  return function shutdown(signal = "shutdown") {
    if (shutdownPromise) return shutdownPromise;

    shutdownPromise = (async () => {
      let exitCode = 0;
      let timedOut = false;
      const deadlineMs = Math.max(1, Number(timeoutMs) || 25_000);
      const deadline = setTimeout(() => {
        timedOut = true;
        try {
          logger?.error?.(`[NovynShutdown] Timed out after ${deadlineMs}ms during ${signal}.`);
          onTimeout(signal);
        } catch (error) {
          logger?.error?.("[NovynShutdown] Timeout handler failed:", error?.message || error);
        }
      }, deadlineMs);

      const runStep = async (name, action) => {
        try {
          await action(signal);
        } catch (error) {
          exitCode = 1;
          logger?.error?.(`[NovynShutdown] ${name} failed:`, error?.message || error);
        }
      };

      try {
        // Wait for startup to settle before closing the listener. A SIGTERM
        // during Mongo loading must not race the boot process and reopen it.
        await runStep("startup completion", waitForStartup);
        await runStep("transport drain", closeTransport);
        await runStep("background cleanup", stopBackgroundWork);
        await runStep("state persistence", flushState);
        await runStep("storage close", closeStorage);
      } finally {
        clearTimeout(deadline);
      }

      return timedOut ? 1 : exitCode;
    })();

    return shutdownPromise;
  };
}

module.exports = { createShutdownHandler };
