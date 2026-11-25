"use strict";

const net = require("node:net");

const DEFAULT_WINDOW_MS = 60 * 1000;

function validIp(value) {
  const candidate = String(value ?? "").trim();
  return net.isIP(candidate) ? candidate : "";
}

function getRequestClientIp(req) {
  // Render routes public web-service traffic through Cloudflare before it
  // reaches the service. Cloudflare's single-value CF-Connecting-IP header is
  // preferable to X-Forwarded-For, which may contain client-supplied entries.
  if (String(process.env.RENDER || "").toLowerCase() === "true") {
    const cloudflareIp = validIp(req?.headers?.["cf-connecting-ip"]);
    if (cloudflareIp) return cloudflareIp;

    // Do not fall back to X-Forwarded-For when the trusted edge header is
    // absent or malformed. The socket peer is conservative (it may be the
    // shared proxy), but it cannot be chosen by the HTTP client.
    return validIp(req?.socket?.remoteAddress) || "unknown";
  }

  return validIp(req?.ip) || validIp(req?.socket?.remoteAddress) || "unknown";
}

function getSocketClientIp(socket) {
  const address = socket?.handshake?.address;
  return getRequestClientIp({
    headers: socket?.handshake?.headers,
    ip: address,
    socket: { remoteAddress: address },
  });
}

function createIpRateLimiter(
  {
    store,
    getStore,
    getClientIp = getRequestClientIp,
    normalizeIp = (value) => String(value || "unknown"),
    maxEntries = 100_000,
  } = {},
  bucket,
  maxRequests,
  windowMs = DEFAULT_WINDOW_MS
) {
  const resolveStore = () => getStore ? getStore() : store;
  if (!store && !getStore) {
    throw new Error("createIpRateLimiter requires a rate-limit store.");
  }
  const safeBucket = String(bucket || "default").trim() || "default";
  const max = Math.max(1, Number(maxRequests) || 1);
  const windowDuration = Math.max(1000, Number(windowMs) || DEFAULT_WINDOW_MS);
  const entryLimit = Math.max(1, Math.floor(Number(maxEntries) || 100_000));
  const unavailable = () => ({
    error: "Rate limiting is temporarily unavailable. Please try again later.",
  });

  return (req, res, next) => {
    const activeStore = resolveStore();
    if (!activeStore || typeof activeStore.get !== "function" || typeof activeStore.set !== "function") {
      res.status(503).json(unavailable());
      return;
    }
    const ip = String(normalizeIp(getClientIp(req)) || "unknown");
    const now = Date.now();
    const key = safeBucket + ":" + ip;
    const current = activeStore.get(key);

    // A Map-backed per-IP store can otherwise grow without bound when requests
    // arrive from many distinct IPs. Prune expired buckets before refusing a
    // new key, and fail closed rather than allocating beyond the configured cap.
    if (!current && Number.isFinite(activeStore.size) && activeStore.size >= entryLimit) {
      pruneHttpRateLimits(activeStore, now);
      if (activeStore.size >= entryLimit) {
        res.status(503).json(unavailable());
        return;
      }
    }
    const active = current && now <= Number(current.resetAt)
      ? current
      : { count: 0, resetAt: now + windowDuration };

    active.count += 1;
    activeStore.set(key, active);

    if (active.count > max) {
      res.status(429).json({ error: "Too many requests. Please try again later." });
      return;
    }
    next();
  };
}

function pruneHttpRateLimits(store, now = Date.now()) {
  if (!store || typeof store.entries !== "function" || typeof store.delete !== "function") return;
  for (const [key, entry] of store.entries()) {
    const resetAt = Number(entry?.resetAt);
    if (!entry || !Number.isFinite(resetAt) || resetAt <= now) {
      store.delete(key);
    }
  }
}

module.exports = {
  createIpRateLimiter,
  getRequestClientIp,
  getSocketClientIp,
  pruneHttpRateLimits,
};
