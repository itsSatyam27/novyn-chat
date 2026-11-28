"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { ChessVoiceRegistry } = require("../server/realtime/chess-voice");

test("Chess voice registry rejects public random matchmaking rooms", () => {
  const registry = new ChessVoiceRegistry({ createId: () => "voice-room-random" });
  const result = registry.join("random:match-public", "alice", "stranger");

  assert.equal(result.ok, false);
  assert.match(result.message, /friend matches/i);
});

test("Chess voice requires both participants before signaling is authorized", () => {
  const registry = new ChessVoiceRegistry({ createId: () => "voice-room-1" });
  const first = registry.join("friend:chat-1", "alice", "bob");
  assert.equal(first.ok, true);
  assert.equal(first.roomId, "voice-room-1");
  assert.equal(first.peerReady, false);
  assert.equal(registry.authorizeSignal(first.roomId, "alice").ok, false);

  const second = registry.join("friend:chat-1", "bob", "alice");
  assert.equal(second.ok, true);
  assert.equal(second.roomId, first.roomId);
  assert.equal(second.peerReady, true);
  assert.equal(second.initiator, false);
  assert.equal(registry.authorizeSignal(first.roomId, "alice").peerUsername, "bob");
  assert.equal(registry.authorizeSignal(first.roomId, "mallory").ok, false);
});

test("Chess voice rooms reject a third participant and mismatched match pairing", () => {
  const registry = new ChessVoiceRegistry({ createId: () => "voice-room-2" });
  const joined = registry.join("friend:chat:message-8", "alice", "bob");
  assert.equal(joined.ok, true);
  assert.equal(registry.join("friend:chat:message-8", "mallory", "alice").ok, false);
  assert.equal(registry.join("friend:chat:message-8", "alice", "mallory").ok, false);
});

test("Chess voice leave revokes signaling and lets the same opponent reconnect", () => {
  const registry = new ChessVoiceRegistry({ createId: () => "voice-room-3" });
  const first = registry.join("friend:chat-3", "alice", "bob");
  registry.join("friend:chat-3", "bob", "alice");

  const left = registry.leave(first.roomId, "bob");
  assert.equal(left.peerUsername, "alice");
  assert.equal(left.peerStillJoined, true);
  assert.equal(registry.authorizeSignal(first.roomId, "alice").ok, false);

  const rejoined = registry.join("friend:chat-3", "bob", "alice");
  assert.equal(rejoined.roomId, first.roomId);
  assert.equal(rejoined.peerReady, true);
  assert.equal(registry.authorizeSignal(first.roomId, "alice").ok, true);
});

test("Chess voice disconnect removes every active membership", () => {
  const registry = new ChessVoiceRegistry({ createId: () => "voice-room-4" });
  const first = registry.join("random:match-4", "alice", "bob");
  registry.join("random:match-4", "bob", "alice");
  const removed = registry.disconnect("alice");
  assert.equal(removed.length, 1);
  assert.equal(removed[0].peerUsername, "bob");
  assert.equal(registry.authorizeSignal(first.roomId, "bob").ok, false);
  registry.leave(first.roomId, "bob");
  assert.equal(registry.size, 0);
});
