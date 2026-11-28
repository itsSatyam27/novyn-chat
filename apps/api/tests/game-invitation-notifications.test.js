"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  emitGameInviteClosed,
  expirePendingGameInvite,
} = require("../server/realtime/game-invitation-notifications");

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

test("an expired pending invite notifies both inviter and invitee", () => {
  const invite = {
    fromKey: "alice",
    toKey: "bob",
    gameType: "tictactoe",
  };
  const pendingGameInvites = new Map([["invite-1", invite]]);
  const onlineUsers = new Map([
    ["alice", "socket-alice"],
    ["bob", "socket-bob"],
  ]);
  const io = fakeIo();

  assert.equal(expirePendingGameInvite({
    messageId: "invite-1",
    invite,
    pendingGameInvites,
    onlineUsers,
    io,
  }), true);
  assert.equal(pendingGameInvites.has("invite-1"), false);
  assert.deepEqual(io.events.map((event) => event.socketId).sort(), [
    "socket-alice",
    "socket-bob",
  ]);
  assert.ok(io.events.every((event) =>
    event.event === "game_invite_timeout" &&
    event.payload.messageId === "invite-1" &&
    event.payload.reason === "expired"
  ));
});

test("a stale timeout cannot remove or notify a replacement invite", () => {
  const oldInvite = { fromKey: "alice", toKey: "bob", gameType: "rps" };
  const replacement = { fromKey: "alice", toKey: "bob", gameType: "rps" };
  const pendingGameInvites = new Map([["invite-2", replacement]]);
  const io = fakeIo();

  assert.equal(expirePendingGameInvite({
    messageId: "invite-2",
    invite: oldInvite,
    pendingGameInvites,
    onlineUsers: new Map([["alice", "a"], ["bob", "b"]]),
    io,
  }), false);
  assert.equal(pendingGameInvites.get("invite-2"), replacement);
  assert.deepEqual(io.events, []);
});

test("cancelling an invite notifies a waiting recipient even before acceptance", () => {
  const invite = {
    fromKey: "alice",
    toKey: "bob",
    gameType: "rajamantri",
  };
  const io = fakeIo();
  const count = emitGameInviteClosed({
    invite,
    messageId: "invite-3",
    onlineUsers: new Map([
      ["alice", "socket-alice"],
      ["bob", "socket-bob"],
    ]),
    io,
    reason: "cancelled",
  });

  assert.equal(count, 1);
  assert.deepEqual(io.events, [{
    socketId: "socket-bob",
    event: "game_invite_timeout",
    payload: {
      messageId: "invite-3",
      gameType: "rajamantri",
      reason: "cancelled",
    },
  }]);
});

test("accept and reject actions can close the active popup on the acting socket", () => {
  const invite = {
    fromKey: "alice",
    toKey: "bob",
    gameType: "tictactoe",
  };
  const onlineUsers = new Map([["bob", "socket-bob"]]);

  for (const reason of ["accepted", "rejected"]) {
    const io = fakeIo();
    emitGameInviteClosed({
      invite,
      messageId: "invite-" + reason,
      onlineUsers,
      io,
      reason,
      extraSocketIds: ["socket-bob-current"],
    });
    assert.deepEqual(
      io.events.map((event) => event.socketId).sort(),
      ["socket-bob", "socket-bob-current"],
    );
    assert.ok(io.events.every((event) => event.payload.reason === reason));
  }
});

test("accepted invite cancellation notifies a single live recipient socket", () => {
  const invite = {
    fromKey: "alice",
    toKey: "bob",
    acceptedSocketId: "socket-bob-current",
    gameType: "rajamantri",
  };
  const io = fakeIo();
  emitGameInviteClosed({
    invite,
    messageId: "invite-4",
    onlineUsers: new Map([["bob", "socket-bob-current"]]),
    io,
    reason: "cancelled",
  });
  assert.equal(io.events.length, 1);
  assert.equal(io.events[0].socketId, "socket-bob-current");
});
