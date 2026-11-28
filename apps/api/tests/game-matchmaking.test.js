"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { PublicGameMatchmaking } = require("../server/realtime/game-matchmaking");
test("pairs different strangers only for the same game", () => {
  const q = new PublicGameMatchmaking({ createSessionId: () => "session-1" });
  assert.equal(q.join({ userKey:"alice", displayName:"Alice", socketId:"s1", gameType:"tictactoe" }).queued, true);
  assert.equal(q.join({ userKey:"bob", socketId:"s2", gameType:"rps" }).queued, true);
  const match = q.join({ userKey:"charlie", displayName:"Charlie", socketId:"s3", gameType:"tictactoe" });
  assert.equal(match.matched, true); assert.equal(match.sessionId, "session-1");
  assert.deepEqual(match.players.map(p => p.userKey), ["alice","charlie"]); assert.equal(q.size, 1); q.cancel("bob");
});
test("one queue entry per user and cancellation", () => {
  const q = new PublicGameMatchmaking();
  q.join({userKey:"alice",socketId:"s1",gameType:"tictactoe"});
  q.join({userKey:"alice",socketId:"s1",gameType:"rps"});
  assert.equal(q.size,1); assert.equal(q.queues.has("tictactoe"),false);
  assert.equal(q.cancel("alice"),true); assert.equal(q.size,0);
});
test("disconnect removes only the owning socket queue entry", () => {
  const q = new PublicGameMatchmaking(); q.join({userKey:"alice",socketId:"old",gameType:"tictactoe"});
  assert.equal(q.disconnect("alice","new"),false); assert.equal(q.disconnect("alice","old"),true);
});
test("the two supported games allow random matchmaking and one account cannot self-match", () => {
  const q = new PublicGameMatchmaking();
  for (const [index, gameType] of ["tictactoe", "rps"].entries()) {
    const first = "player_" + index + "_a";
    const second = "player_" + index + "_b";
    assert.equal(q.join({ userKey: first, socketId: first + "_socket", gameType }).queued, true);
    assert.equal(q.join({ userKey: first, socketId: first + "_other_socket", gameType }).queued, true);
    assert.equal(q.join({ userKey: second, socketId: second + "_socket", gameType }).matched, true);
  }
  for (const gameType of ["connect4", "doodle", "numberclash", "updown", "unsupported"]) {
    assert.equal(q.join({ userKey: "alice", socketId: "s1", gameType }).ok, false);
  }
  assert.equal(q.size, 0);
});


test("random matchmaking never pairs mutual friends", () => {
  const q = new PublicGameMatchmaking();
  assert.equal(q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "tictactoe",
    excludedUsers: ["bob"],
  }).queued, true);
  const bob = q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "tictactoe",
    excludedUsers: ["alice"],
  });
  assert.equal(bob.queued, true);
  assert.equal(q.size, 2);
  q.cancel("alice");
  q.cancel("bob");
});

test("one-sided or stale friend records still exclude the pair but allow a stranger", () => {
  const q = new PublicGameMatchmaking({ createSessionId: () => "stranger-session" });
  q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "rps",
    excludedUsers: ["bob"],
  });
  const bob = q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "rps",
  });
  assert.equal(bob.queued, true);
  const charlie = q.join({
    userKey: "charlie",
    socketId: "charlie_socket",
    gameType: "rps",
  });
  assert.equal(charlie.matched, true);
  assert.deepEqual(charlie.players.map((player) => player.userKey), ["alice", "charlie"]);
  assert.equal(q.size, 1);
  q.cancel("bob");
});

test("matchmaking carries validated game levels to both matched players", () => {
  const q = new PublicGameMatchmaking({ createSessionId: () => "levels-session" });
  assert.equal(q.join({
    userKey: "alice",
    displayName: "Alice",
    socketId: "alice_socket",
    gameType: "tictactoe",
    level: 4,
  }).queued, true);
  const match = q.join({
    userKey: "bob",
    displayName: "Bob",
    socketId: "bob_socket",
    gameType: "tictactoe",
    level: 6,
  });
  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.level), [4, 6]);
});

test("invalid matchmaking level metadata is omitted instead of trusted", () => {
  const q = new PublicGameMatchmaking({ createSessionId: () => "safe-level-session" });
  q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "rps",
    level: 50_000,
  });
  const match = q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "rps",
    level: 3.5,
  });
  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.level), [null, null]);
});


test("public matchmaking chooses the closest available player level", () => {
  const q = new PublicGameMatchmaking({ createSessionId: () => "closest-level-session" });
  q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "tictactoe",
    level: 2,
    excludedUsers: ["bob"],
  });
  q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "tictactoe",
    level: 8,
    excludedUsers: ["alice"],
  });

  const match = q.join({
    userKey: "charlie",
    socketId: "charlie_socket",
    gameType: "tictactoe",
    level: 7,
  });

  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.userKey), ["bob", "charlie"]);
  assert.equal(q.size, 1);
  assert.equal(q.cancel("alice"), true);
});

test("equal level distance preserves FIFO order", () => {
  const q = new PublicGameMatchmaking();
  q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "rps",
    level: 4,
    excludedUsers: ["bob"],
  });
  q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "rps",
    level: 8,
    excludedUsers: ["alice"],
  });

  const match = q.join({
    userKey: "charlie",
    socketId: "charlie_socket",
    gameType: "rps",
    level: 6,
  });

  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.userKey), ["alice", "charlie"]);
  assert.equal(q.size, 1);
  q.cancel("bob");
});

test("unknown level metadata keeps the existing FIFO fallback", () => {
  const q = new PublicGameMatchmaking();
  q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "rps",
    excludedUsers: ["bob"],
  });
  q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "rps",
    level: 9,
    excludedUsers: ["alice"],
  });

  const match = q.join({
    userKey: "charlie",
    socketId: "charlie_socket",
    gameType: "rps",
  });

  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.userKey), ["alice", "charlie"]);
  assert.equal(q.size, 1);
  q.cancel("bob");
});


test("skill gap expands gradually for players who have waited in the queue", () => {
  let now = 1_000;
  const q = new PublicGameMatchmaking({ now: () => now });

  assert.equal(q.join({
    userKey: "alice",
    socketId: "alice_socket",
    gameType: "tictactoe",
    level: 1,
    excludedUsers: ["bob"],
  }).queued, true);

  // A five-level gap is too wide for a new queue entry.
  assert.equal(q.join({
    userKey: "bob",
    socketId: "bob_socket",
    gameType: "tictactoe",
    level: 6,
    excludedUsers: ["alice"],
  }).queued, true);
  assert.equal(q.size, 2);

  // After waiting, Bob's allowed skill range expands to include level 1.
  now += 15_000;
  assert.equal(q.cancel("alice"), true);
  const match = q.join({
    userKey: "charlie",
    socketId: "charlie_socket",
    gameType: "tictactoe",
    level: 1,
  });

  assert.equal(match.matched, true);
  assert.deepEqual(match.players.map((player) => player.userKey), ["bob", "charlie"]);
  assert.equal(q.size, 0);
});

test("rejoining matchmaking replaces the old queue timeout", async () => {
  const expired = [];
  const q = new PublicGameMatchmaking({
    timeoutMs: 25,
    onExpired: (entry) => expired.push(entry),
  });

  assert.equal(q.join({
    userKey: "alice",
    socketId: "old_socket",
    gameType: "tictactoe",
    level: 1,
  }).queued, true);

  assert.equal(q.join({
    userKey: "alice",
    socketId: "new_socket",
    gameType: "rps",
    level: 2,
  }).queued, true);

  await new Promise((resolve) => setTimeout(resolve, 45));

  assert.deepEqual(expired, [{
    userKey: "alice",
    socketId: "new_socket",
    gameType: "rps",
  }]);
  assert.equal(q.size, 0);
});
