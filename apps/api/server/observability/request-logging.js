"use strict";

const crypto = require("node:crypto");

const DEFAULT_SLOW_REQUEST_MS = 1_000;

function normalizeThreshold(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0
    ? parsed
    : DEFAULT_SLOW_REQUEST_MS;
}

function createRequestObservability({
  logger = console,
  slowRequestMs = DEFAULT_SLOW_REQUEST_MS,
  now = () => Number(process.hrtime.bigint()) / 1e6,
  requestIdFactory = () => crypto.randomUUID(),
} = {}) {
  const slowThresholdMs = normalizeThreshold(slowRequestMs);

  return function requestObservability(req, res, next) {
    const requestId = requestIdFactory();
    const startedAt = now();
    let logged = false;

    req.requestId = requestId;
    res.setHeader("X-Request-Id", requestId);

    const logRequest = (aborted = false) => {
      if (logged) return;
      logged = true;

      const durationMs = Math.max(0, now() - startedAt);
      const routePath = req.route && typeof req.route.path === "string"
        ? req.route.path
        : "unmatched";
      const route = req.baseUrl
        ? `${req.baseUrl}${routePath === "unmatched" ? "" : routePath}`
        : routePath;
      const statusCode = Number(res.statusCode) || 0;
      const event = {
        event: "http_request",
        requestId,
        method: String(req.method || "UNKNOWN").toUpperCase(),
        route,
        statusCode,
        durationMs: Math.round(durationMs * 100) / 100,
      };

      if (aborted) event.aborted = true;

      const level = statusCode >= 500
        ? "error"
        : (aborted || durationMs >= slowThresholdMs ? "warn" : "info");

      try {
        const write = typeof logger?.[level] === "function"
          ? logger[level].bind(logger)
          : (typeof logger?.info === "function" ? logger.info.bind(logger) : null);
        if (write) write(JSON.stringify(event));
      } catch (_) {
        // Observability must never interfere with the request/response lifecycle.
      }
    };

    res.once("finish", () => logRequest(false));
    res.once("close", () => {
      if (!res.writableFinished) logRequest(true);
    });

    next();
  };
}

module.exports = { createRequestObservability, DEFAULT_SLOW_REQUEST_MS };
