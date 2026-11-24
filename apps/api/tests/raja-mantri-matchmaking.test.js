"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { RajaMantriMatchmaking } = require("../server/realtime/raja-mantri-matchmaking");

test("groups three strangers only into a three-player room", () => {
  const q = new RajaMantriMatchmaking({ createMatchId: () => "rm-3p" });
  assert.equal(q.join({ userKey: "a", socketId: "sa", playerCount: 3 }).queued, true);
  assert.equal(q.join({ userKey: "b", socketId: "sb", playerCount: 4 }).queued, true);
  const result = q.join({ userKey: "c", socketId: "sc", playerCount: 3 });
  assert.equal(result.queued, true);
  const matched = q.join({ userKey: "d", socketId: "sd", playerCount: 3 });
  assert.equal(matched.matched, true);
  assert.equal(matched.matchId, "rm-3p");
  assert.equal(matched.playerCount, 3);
  assert.deepEqual(matched.players.map((p) => p.username), ["a", "c", "d"]);
  assert.equal(q.size, 1);
  q.cancel("b");
});

test("groups four strangers only when all four seats are available", () => {
  const q = new RajaMantriMatchmaking({ createMatchId: () => "rm-4p" });
  for (const [userKey, socketId] of [["a", "sa"], ["b", "sb"], ["c", "sc"]]) {
    assert.equal(q.join({ userKey, socketId, playerCount: 4 }).queued, true);
  }
  assert.equal(q.size, 3);
  const result = q.join({ userKey: "d", socketId: "sd", playerCount: 4 });
  assert.equal(result.matched, true);
  assert.equal(result.players.length, 4);
  assert.equal(q.size, 0);
});

test("does not form a room with friends or blocked accounts", () => {
  const q = new RajaMantriMatchmaking();
  q.join({ userKey: "a", socketId: "sa", playerCount: 3, excludedUsers: ["b"] });
  q.join({ userKey: "b", socketId: "sb", playerCount: 3 });
  q.join({ userKey: "c", socketId: "sc", playerCount: 3 });
  assert.equal(q.size, 3);
  q.cancel("a");
  q.cancel("b");
  q.cancel("c");
});

test("supports cancel and socket-owned disconnect without removing a newer socket", () => {
  const q = new RajaMantriMatchmaking();
  q.join({ userKey: "a", socketId: "old", playerCount: 3 });
  assert.equal(q.disconnect("a", "new"), false);
  assert.equal(q.disconnect("a", "old"), true);
  q.join({ userKey: "b", socketId: "sb", playerCount: 4 });
  assert.equal(q.cancel("b"), true);
  assert.equal(q.size, 0);
});

test("removes timed-out players and notifies the owning socket", async () => {
  const expired = [];
  const q = new RajaMantriMatchmaking({
    timeoutMs: 15,
    onExpired: (entry) => expired.push(entry),
  });
  q.join({ userKey: "a", socketId: "sa", playerCount: 3 });
  await new Promise((resolve) => setTimeout(resolve, 35));
  assert.equal(q.size, 0);
  assert.equal(expired.length, 1);
  assert.equal(expired[0].socketId, "sa");
  assert.equal(expired[0].playerCount, 3);
});
