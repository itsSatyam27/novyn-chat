"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  collectFcmDevices,
  registerFcmDevice,
  removeFcmDevice,
  createFcmMessage,
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

test("app update and direct message pushes are data-only and have offline TTL", () => {
  const update = createFcmMessage("alice", { username: "alice" }, {
    type: "app_update", build: 52, title: "Update ready", body: "Install Novyn",
  });
  const direct = createFcmMessage("alice", { username: "alice" }, {
    type: "message", chat: "bob", body: "Hello",
  });

  assert.equal(update.notification, undefined);
  assert.equal(update.data.build, "52");
  assert.equal(update.data.recipient, "alice");
  assert.equal(update.android.priority, "high");
  assert.equal(update.android.ttl, 28 * 24 * 60 * 60 * 1000);
  assert.equal(direct.notification, undefined);
  assert.equal(direct.data.chat, "bob");
});

test("group message push keeps a system notification while carrying group routing data", () => {
  const group = createFcmMessage("alice", { username: "alice" }, {
    type: "message", group: true, groupId: "room-1", title: "Group message", body: "Hello group",
  });
  assert.deepEqual(group.notification, { title: "Group message", body: "Hello group" });
  assert.equal(group.data.kind, "group");
  assert.equal(group.data.groupId, "room-1");
});

test("classifies invalid token and retryable Firebase errors", () => {
  assert.equal(isInvalidFcmTokenError("messaging/registration-token-not-registered"), true);
  assert.equal(isRetryableFcmError("messaging/server-unavailable"), true);
  assert.equal(isRetryableFcmError("messaging/invalid-argument"), false);
});
