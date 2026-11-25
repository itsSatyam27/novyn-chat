"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createBoundedCache } = require("../server/core/bounded-cache");

test("bounded cache refreshes recently accessed keys and evicts least-recently-used entries", () => {
  const cache = createBoundedCache(2);
  cache.set("old", { ownerKey: "alice" });
  cache.set("recent", { ownerKey: "bob" });

  assert.equal(cache.get("old").ownerKey, "alice");
  cache.set("new", { ownerKey: "carol" });

  assert.equal(cache.size, 2);
  assert.equal(cache.has("old"), true);
  assert.equal(cache.has("recent"), false);
  assert.equal(cache.get("new").ownerKey, "carol");
});

test("cache replacement refreshes recency without increasing its size", () => {
  const cache = createBoundedCache(2);
  cache.set("a", 1);
  cache.set("b", 2);
  cache.set("a", 3);
  cache.set("c", 4);

  assert.equal(cache.size, 2);
  assert.equal(cache.get("a"), 3);
  assert.equal(cache.has("b"), false);
  assert.equal(cache.delete("a"), true);
  assert.equal(cache.size, 1);
  cache.clear();
  assert.equal(cache.size, 0);
});

test("cache capacity is validated and never allows an unbounded zero limit", () => {
  const cache = createBoundedCache(0);
  cache.set("a", 1);
  cache.set("b", 2);
  assert.equal(cache.size, 1);
  assert.equal(cache.has("a"), false);
  assert.equal(cache.get("b"), 2);
});
