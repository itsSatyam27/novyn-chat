"use strict";

function createSocketActionRateLimiter({
  getStore,
  getClientIp = () => "unknown",
  normalizeUserKey = (value) => String(value || "").trim().toLowerCase(),
  now = Date.now,
  maxEntries = 100_000,
  pruneIntervalMs = 60_000,
} = {}) {
  if (typeof getStore !== "function") throw new Error("A socket rate-limit store resolver is required.");
  const entryLimit = Math.max(1, Math.floor(Number(maxEntries) || 100_000));
  const pruneInterval = Math.max(1000, Number(pruneIntervalMs) || 60_000);
  let lastPruneAt = 0;

  function prune(store, timestamp) {
    for (const [storedKey, storedBucket] of store.entries()) {
      if (!storedBucket || !Number.isFinite(Number(storedBucket.expiresAt)) || timestamp >= Number(storedBucket.expiresAt)) {
        store.delete(storedKey);
      }
    }
    lastPruneAt = timestamp;
  }

  return function allowSocketAction(socket, rawKey, maxPerWindow, windowMs) {
    const key = String(rawKey || "").trim();
    if (!socket || !key) return false;

    const store = getStore();
    if (!store || typeof store.get !== "function" || typeof store.set !== "function" ||
        typeof store.delete !== "function" || typeof store.entries !== "function" ||
        !Number.isFinite(store.size)) return false;

    const max = Math.max(1, Number(maxPerWindow) || 1);
    const windowDuration = Math.max(1000, Number(windowMs) || 1000);
    const timestamp = now();
    const userKey = normalizeUserKey(socket.data && socket.data.userKey);
    let ip = "unknown";
    try { ip = String(getClientIp(socket) || "unknown"); } catch (_) { ip = "unknown"; }
    const globalKey = userKey ? userKey + ":" + key : "anonymous:" + ip + ":" + key;
    const existing = store.get(globalKey);

    if (timestamp - lastPruneAt >= pruneInterval) prune(store, timestamp);
    if (!existing && store.size >= entryLimit) {
      prune(store, timestamp);
      if (store.size >= entryLimit) return false;
    }

    const active = existing && timestamp < Number(existing.expiresAt)
      ? existing
      : { count: 0, windowStartedAt: timestamp, expiresAt: timestamp + windowDuration };
    active.count += 1;
    store.set(globalKey, active);
    if (active.count > max) return false;

    if (!socket.data || typeof socket.data !== "object") socket.data = {};
    if (!socket.data.rateBuckets || typeof socket.data.rateBuckets !== "object") {
      socket.data.rateBuckets = Object.create(null);
    }
    const local = socket.data.rateBuckets[key] || { count: 0, windowStartedAt: timestamp };
    if (timestamp - Number(local.windowStartedAt) >= windowDuration) {
      local.windowStartedAt = timestamp;
      local.count = 0;
    }
    local.count += 1;
    socket.data.rateBuckets[key] = local;
    return local.count <= max;
  };
}

module.exports = { createSocketActionRateLimiter };
