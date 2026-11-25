"use strict";

function createBoundedCache(maxEntries = 5000) {
  const limit = Number.isFinite(Number(maxEntries))
    ? Math.max(1, Math.floor(Number(maxEntries)))
    : 5000;
  const entries = new Map();

  function get(key) {
    if (!entries.has(key)) return undefined;
    const value = entries.get(key);
    entries.delete(key);
    entries.set(key, value);
    return value;
  }

  function set(key, value) {
    if (entries.has(key)) entries.delete(key);
    entries.set(key, value);
    while (entries.size > limit) {
      entries.delete(entries.keys().next().value);
    }
    return cache;
  }

  const cache = {
    get,
    set,
    has: (key) => entries.has(key),
    delete: (key) => entries.delete(key),
    clear: () => entries.clear(),
    get size() { return entries.size; },
  };
  return cache;
}

module.exports = { createBoundedCache };
