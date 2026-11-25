"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  collectFcmDevices,
  registerFcmDevice,
  removeFcmDevice,
  createFcmMessage,
  parseAndroidReleaseBuild,
  isInvalidFcmTokenError,
  isRetryableFcmError,
} = require("../server/notification-utils");

const tokenA = "a".repeat(150);
const tokenB = "b".repeat(150);
const tokenC = "c".repeat(150);

test("collects current device registrations and migrates the legacy token", () => {
  const devices = collectFcmDevices({
    fcmToken: tokenA,
    fcmDevices: [{ token: tokenA, appBuild: 47, platform: "android" }, { token: tokenB, appBuild: 52 }],
  });
  assert.equal(devices.length, 2);
  assert.equal(devices[0].token, tokenA);
  assert.equal(devices[0].appBuild, 47);
  assert.equal(devices[1].token, tokenB);
});

test("registration moves a token to the active account and preserves update markers", () => {
  const oldUser = { username: "alice", fcmToken: tokenA, fcmDevices: [{ token: tokenA, appBuild: 10, lastNotifiedUpdateBuild: 30 }] };
  const newUser = { username: "bob", fcmToken: "", fcmDevices: [] };
  const users = new Map([["alice", oldUser], ["bob", newUser]]);

  registerFcmDevice(users, "bob", newUser, tokenA, { appBuild: 52, platform: "android" });

  assert.equal(oldUser.fcmToken, "");
  assert.deepEqual(oldUser.fcmDevices, []);
  assert.equal(newUser.fcmToken, tokenA);
  assert.equal(newUser.fcmDevices.length, 1);
  assert.equal(newUser.fcmDevices[0].appBuild, 52);
  assert.equal(newUser.fcmDevices[0].lastNotifiedUpdateBuild, 30);
});

test("an absent or malformed logout token never clears every device", () => {
  const user = {
    fcmToken: tokenB,
    fcmDevices: [
      { token: tokenA, appBuild: 40 },
      { token: tokenB, appBuild: 50 },
    ],
  };

  assert.equal(removeFcmDevice(user, null), false);
  assert.equal(removeFcmDevice(user, "invalid"), false);
  assert.equal(user.fcmDevices.length, 2);
  assert.equal(user.fcmToken, tokenB);
});

test("logout removes only this device token and preserves other devices", () => {
  const user = {
    fcmToken: tokenB,
    fcmDevices: [
      { token: tokenA, appBuild: 40 },
      { token: tokenB, appBuild: 50 },
    ],
  };

  removeFcmDevice(user, tokenA);

  assert.equal(user.fcmDevices.length, 1);
  assert.equal(user.fcmDevices[0].token, tokenB);
  assert.equal(user.fcmToken, tokenB);
});

test("app updates and direct messages include OS-visible alerts with offline TTL", () => {
  const update = createFcmMessage("alice", { username: "alice" }, {
    type: "app_update", build: 52, title: "Update ready", body: "Install Novyn",
  });
  const direct = createFcmMessage("alice", { username: "alice" }, {
    type: "message", chat: "bob", body: "Hello",
  });

  assert.equal(update.notification.body, "Install Novyn");
  assert.equal(update.android.notification.channelId, "novyn_app_updates_sound_vibrate");
  assert.equal(update.data.build, "52");
  assert.equal(update.data.recipient, "alice");
  assert.equal(update.android.priority, "high");
  assert.equal(update.android.ttl, 28 * 24 * 60 * 60 * 1000);
  assert.equal(direct.notification.body, "Hello");
  assert.equal(direct.android.notification.channelId, "novyn_messages_sound_vibrate");
  assert.equal(direct.data.chat, "bob");
});

test("group messages include OS-visible alerts and preserve group routing metadata", () => {
  const group = createFcmMessage("alice", { username: "alice" }, {
    type: "message", group: true, groupId: "room-1", title: "Group message", body: "Hello group",
  });
  assert.equal(group.notification.body, "Hello group");
  assert.equal(group.android.notification.channelId, "novyn_messages_sound_vibrate");
  assert.equal(group.data.kind, "group");
  assert.equal(group.data.groupId, "room-1");
  assert.equal(group.android.priority, "high");
  assert.equal(group.android.ttl, 28 * 24 * 60 * 60 * 1000);
});

test("calls use a short high-priority delivery window", () => {
  const call = createFcmMessage("alice", { username: "alice" }, {
    type: "call", callStatus: "incoming", callId: "call-123", chat: "bob",
  });
  assert.equal(call.notification, undefined);
  assert.equal(call.data.recipient, "alice");
  assert.equal(call.data.callStatus, "incoming");
  assert.equal(call.android.priority, "high");
  assert.equal(call.android.ttl, 45 * 1000);
});

test("social notifications include OS-visible alerts and retain account routing", () => {
  const social = createFcmMessage("alice", { username: "alice" }, {
    type: "friend_request", eventId: "request-1", from: "bob",
    title: "Friend request", body: "Bob sent a request",
  });
  assert.equal(social.notification.title, "Friend request");
  assert.equal(social.notification.body, "Bob sent a request");
  assert.equal(social.data.type, "friend_request");
  assert.equal(social.data.eventId, "request-1");
  assert.equal(social.data.from, "bob");
  assert.equal(social.data.recipient, "alice");
});

test("game notifications include OS-visible alerts and retain game routing metadata", () => {
  for (const type of ["game_invitation", "game_turn", "game_result"]) {
    const game = createFcmMessage("alice", { username: "alice" }, {
      type,
      eventId: type + ":game-7",
      gameId: "game-7",
      gameType: "tic_tac_toe",
      chat: "room-1",
      group: true,
      groupId: "room-1",
      title: "Your turn",
      body: "It's your turn",
      soundEnabled: false,
      vibrationEnabled: true,
      mentionOrReply: true,
    });
    assert.equal(game.notification.body, "It's your turn");
    assert.equal(game.android.notification.channelId, "novyn_games_silent_vibrate");
    assert.equal(game.data.type, type);
    assert.equal(game.data.eventId, type + ":game-7");
    assert.equal(game.data.gameId, "game-7");
    assert.equal(game.data.gameType, "tic_tac_toe");
    assert.equal(game.data.kind, "group");
    assert.equal(game.data.groupId, "room-1");
    assert.equal(game.data.soundEnabled, "false");
    assert.equal(game.data.vibrationEnabled, "true");
    assert.equal(game.data.mentionOrReply, "true");
  }
});

test("notification presentation preferences are forwarded as FCM data", () => {
  const message = createFcmMessage("alice", { username: "alice" }, {
    type: "friend_request",
    soundEnabled: false,
    vibrationEnabled: false,
  });
  assert.equal(message.data.soundEnabled, "false");
  assert.equal(message.data.vibrationEnabled, "false");
  assert.equal(message.notification.title, "Novyn");
  assert.equal(message.android.notification.channelId, "novyn_social_silent_no_vibrate");
});

test("encrypted direct messages use Android data-only delivery and keep iOS alerts generic", () => {
  const encrypted = createFcmMessage("alice", { username: "alice" }, {
    type: "message",
    chat: "bob",
    body: "secret plaintext",
    ciphertext: "ciphertext",
    iv: "nonce",
    senderPublicKey: "public-key",
    messageId: "msg-1",
  });

  // Android must invoke the app's background handler so the phone can
  // decrypt locally before creating its notification. A notification field
  // would be auto-rendered by FCM and bypass that handler.
  assert.equal(encrypted.notification, undefined);
  assert.equal(encrypted.android.notification, undefined);
  assert.equal(encrypted.android.priority, "high");
  assert.equal(encrypted.android.ttl, 28 * 24 * 60 * 60 * 1000);

  // iOS keeps an OS-visible generic alert; neither platform receives plaintext.
  assert.equal(encrypted.apns.payload.aps.alert.body, "You have a new message");
  assert.equal(encrypted.data.body, "You have a new message");
  assert.equal(encrypted.data.ciphertext, "ciphertext");
  assert.equal(encrypted.data.iv, "nonce");
  assert.equal(encrypted.data.senderPublicKey, "public-key");
  assert.equal(encrypted.data.messageId, "msg-1");
  assert.doesNotMatch(JSON.stringify(encrypted), /secret plaintext/);
});

test("disabled message previews use a private system notification fallback", () => {
  const message = createFcmMessage("alice", { username: "alice" }, {
    type: "message",
    chat: "bob",
    body: "private body",
  });
  const hidden = createFcmMessage("alice", {
    username: "alice",
    messagePreviewEnabled: false,
  }, {
    type: "message",
    chat: "bob",
    body: "private body",
  });
  assert.equal(message.notification.body, "private body");
  assert.equal(hidden.notification.body, "You have a new message");
  assert.equal(hidden.data.previewEnabled, "0");
});

test("explicit silent events never create an OS-visible alert", () => {
  const silent = createFcmMessage("alice", { username: "alice" }, {
    type: "message",
    chat: "bob",
    body: "quiet",
    silent: true,
  });
  assert.equal(silent.notification, undefined);
  assert.equal(silent.android.notification, undefined);
  assert.equal(silent.android.priority, "normal");
});

test("recognizes current and legacy ARM64 APK release tags", () => {
  assert.equal(parseAndroidReleaseBuild("novyn-arm64-build-62-1"), 62);
  assert.equal(parseAndroidReleaseBuild("novyn-apk-47-1"), 47);
  assert.equal(parseAndroidReleaseBuild("novyn-apk-47"), 47);
  assert.equal(parseAndroidReleaseBuild("novyn-apk-beta-48"), 0);
  assert.equal(parseAndroidReleaseBuild("unrelated-release-49"), 0);
});

test("classifies invalid token and retryable Firebase errors", () => {
  assert.equal(isInvalidFcmTokenError("messaging/registration-token-not-registered"), true);
  assert.equal(isRetryableFcmError("messaging/server-unavailable"), true);
  assert.equal(isRetryableFcmError("messaging/invalid-argument"), false);
});
