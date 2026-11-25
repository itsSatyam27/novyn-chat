"use strict";

const crypto = require("node:crypto");
const { pruneHttpRateLimits } = require("./rate-limit");

function createIdentityRateLimiter(
  { store, getStore, getIdentity, maxEntries = 100_000 } = {},
  bucket,
  maxRequests,
  windowMs = 60_000,
) {
  const resolveStore = () => getStore ? getStore() : store;
  if (!store && !getStore) throw new Error("createIdentityRateLimiter requires a rate-limit store.");
  if (typeof getIdentity !== "function") throw new Error("createIdentityRateLimiter requires an identity resolver.");

  const safeBucket = String(bucket || "identity").trim() || "identity";
  const max = Math.max(1, Number(maxRequests) || 1);
  const windowDuration = Math.max(1000, Number(windowMs) || 60_000);
  const entryLimit = Math.max(1, Math.floor(Number(maxEntries) || 100_000));

  return (req, res, next) => {
    let identity = "";
    try {
      identity = String(getIdentity(req) || "").trim().toLowerCase().slice(0, 256);
    } catch (_) {
      identity = "";
    }
    if (!identity) {
      next();
      return;
    }

    const activeStore = resolveStore();
    if (!activeStore || typeof activeStore.get !== "function" || typeof activeStore.set !== "function") {
      res.status(503).json({ error: "Rate limiting is temporarily unavailable. Please try again later." });
      return;
    }

    // Hash identifiers so in-memory limiter keys never retain raw email addresses or usernames.
    const digest = crypto.createHash("sha256").update(identity).digest("hex");
    const key = safeBucket + ":" + digest;
    const now = Date.now();
    const current = activeStore.get(key);
    if (!current && Number.isFinite(activeStore.size) && activeStore.size >= entryLimit) {
      pruneHttpRateLimits(activeStore, now);
      if (activeStore.size >= entryLimit) {
        res.status(503).json({ error: "Rate limiting is temporarily unavailable. Please try again later." });
        return;
      }
    }

    const active = current && now < Number(current.resetAt)
      ? current
      : { count: 0, resetAt: now + windowDuration };
    active.count += 1;
    activeStore.set(key, active);
    if (active.count > max) {
      res.status(429).json({ error: "Too many sign-in attempts for this account. Please try again later." });
      return;
    }
    next();
  };
}

module.exports = { createIdentityRateLimiter };
