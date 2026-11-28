"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  emitGameInvitationTimeoutToParticipants,
} = require("../server/realtime/game-invitation-lifecycle");

function fakeIo() {
  const events = [];
  return {
    events,
    to(socketId) {
      return {
        emit(event, payload) {
          events.push({ socketId, event, payload });
        },
      };
    },
  };
}

test("game invite expiry notifies both the inviter and recipient", () => {
  const io = fakeIo();
  const onlineUsers = new Map([
    ["alice", "socket-alice"],
    ["bob", "socket-bob"],
  ]);

  const targets = emitGameInvitationTimeoutToParticipants({
    io,
    onlineUsers,
    invite: { fromKey: "alice", toKey: "bob", gameType: "tictactoe" },
    messageId: "invite-1",
  });

  assert.deepEqual(targets, ["socket-alice", "socket-bob"]);
  assert.deepEqual(io.events, [
    {
      socketId: "socket-alice",
      event: "game_invite_timeout",
      payload: { messageId: "invite-1", gameType: "tictactoe" },
    },
    {
      socketId: "socket-bob",
      event: "game_invite_timeout",
      payload: { messageId: "invite-1", gameType: "tictactoe" },
    },
  ]);
});

test("game invite timeout deduplicates participant and accepted socket IDs", () => {
  const io = fakeIo();
  const onlineUsers = new Map([
    ["alice", "shared-socket"],
    ["bob", "shared-socket"],
  ]);

  const targets = emitGameInvitationTimeoutToParticipants({
    io,
    onlineUsers,
    invite: {
      fromKey: "alice",
      toKey: "bob",
      acceptedSocketId: "shared-socket",
      gameType: "rajamantri",
    },
    messageId: "invite-2",
    reason: "cancelled",
  });

  assert.deepEqual(targets, ["shared-socket"]);
  assert.equal(io.events.length, 1);
  assert.deepEqual(io.events[0].payload, {
    messageId: "invite-2",
    gameType: "rajamantri",
    reason: "cancelled",
  });
});

test("game invite timeout ignores unavailable participant sockets safely", () => {
  const io = fakeIo();
  const targets = emitGameInvitationTimeoutToParticipants({
    io,
    onlineUsers: new Map([["alice", "socket-alice"], ["bob", null]]),
    invite: { fromKey: "alice", toKey: "bob", gameType: "rps" },
    messageId: "invite-3",
  });

  assert.deepEqual(targets, ["socket-alice"]);
  assert.equal(io.events.length, 1);
});
