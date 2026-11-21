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
test("all six games support random matchmaking and one account cannot self-match", () => {
  const q = new PublicGameMatchmaking();
  const gameTypes = ["tictactoe", "rps", "connect4", "doodle", "numberclash", "updown"];
  for (const [index, gameType] of gameTypes.entries()) {
    const first = "player_" + index + "_a";
    const second = "player_" + index + "_b";
    assert.equal(q.join({ userKey: first, socketId: first + "_socket", gameType }).queued, true);
    assert.equal(q.join({ userKey: first, socketId: first + "_other_socket", gameType }).queued, true);
    assert.equal(q.join({ userKey: second, socketId: second + "_socket", gameType }).matched, true);
  }
  assert.equal(q.join({ userKey: "alice", socketId: "s1", gameType: "unsupported" }).ok, false);
  assert.equal(q.size, 0);
});
