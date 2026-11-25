"use strict";

function normalizeErrorStatus(err) {
  const status = Number(err?.status || err?.statusCode);
  return Number.isInteger(status) && status >= 400 && status < 500 ? status : 500;
}

function createHttpErrorHandler({ logger = console } = {}) {
  return function httpErrorHandler(err, req, res, next) {
    if (res.headersSent) return next(err);

    const safeStatus = normalizeErrorStatus(err);
    const event = {
      event: "http_error",
      requestId: req.requestId || null,
      method: String(req.method || "UNKNOWN").toUpperCase(),
      route: req.route && typeof req.route.path === "string" ? req.route.path : "unmatched",
      statusCode: safeStatus,
      errorCode: typeof err?.code === "string" && /^[A-Z0-9_]{1,64}$/.test(err.code) ? err.code : undefined,
    };

    try {
      const write = safeStatus >= 500
        ? (typeof logger.error === "function" ? logger.error.bind(logger) : null)
        : (typeof logger.warn === "function" ? logger.warn.bind(logger) : null);
      if (write) write(JSON.stringify(event));
    } catch (_) {
      // Reporting must never mask the original error.
    }

    if (res.writableEnded) return;
    res.status(safeStatus).json({
      error: safeStatus >= 500 ? "Internal server error" : (err?.message || "Request failed"),
      requestId: req.requestId || undefined,
    });
  };
}

module.exports = { createHttpErrorHandler, normalizeErrorStatus };
