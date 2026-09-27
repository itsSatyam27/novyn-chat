const DEFAULT_WINDOW_MS = 60 * 1000;

function createIpRateLimiter({ store, getStore, normalizeIp = (value) => String(value || "unknown") } = {}, bucket, maxRequests, windowMs = DEFAULT_WINDOW_MS) {
  const resolveStore = () => getStore ? getStore() : store;\n  if (!store && !getStore) {
    throw new Error("createIpRateLimiter requires a rate-limit store.");
  }
  const safeBucket = String(bucket || "default").trim() || "default";
  const max = Math.max(1, Number(maxRequests) || 1);
  const windowDuration = Math.max(1000, Number(windowMs) || DEFAULT_WINDOW_MS);

  return (req, res, next) => {
    const activeStore = resolveStore();\n    if (!activeStore || typeof activeStore.get !== "function" || typeof activeStore.set !== "function") {\n      next();\n      return;\n    }\n    const ip = normalizeIp(req?.ip || req?.socket?.remoteAddress || "unknown");
    const now = Date.now();
    const key = safeBucket + ":" + ip;
    const current = activeStore.get(key);
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

function pruneHttpRateLimits(store) {
  if (!store || typeof store.entries !== "function") return;
  const now = Date.now();
  for (const [key, entry] of store.entries()) {
    if (!entry || Number(entry.resetAt) <= now) {
      store.delete(key);
    }
  }
}

module.exports = {
  createIpRateLimiter,
  pruneHttpRateLimits,
};
