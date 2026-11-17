"use strict";

const MAX_FCM_DEVICES = 25;
const MAX_FCM_TOKEN_LENGTH = 4096;
const FOUR_WEEKS_MS = 28 * 24 * 60 * 60 * 1000;

function safeToken(value) {
  const token = String(value || "").trim();
  return token.length >= 40 && token.length <= MAX_FCM_TOKEN_LENGTH ? token : "";
}

function collectFcmDevices(user) {
  const devices = new Map();
  const add = (raw) => {
    const source = raw && typeof raw === "object" ? raw : { token: raw };
    const token = safeToken(source.token);
    if (!token || devices.has(token)) return;
    const appBuild = Number(source.appBuild);
    const lastNotifiedUpdateBuild = Number(source.lastNotifiedUpdateBuild);
    devices.set(token, {
      token,
      appBuild: Number.isFinite(appBuild) ? Math.max(0, Math.floor(appBuild)) : 0,
      lastNotifiedUpdateBuild: Number.isFinite(lastNotifiedUpdateBuild)
        ? Math.max(0, Math.floor(lastNotifiedUpdateBuild))
        : 0,
      platform: source.platform === "ios" ? "ios" : "android",
      lastRegisteredAt: String(source.lastRegisteredAt || ""),
    });
  };

  if (Array.isArray(user?.fcmDevices)) {
    for (const device of user.fcmDevices) add(device);
  }
  // Migrate older single-token records without dropping their notifications.
  add(user?.fcmToken);
  return Array.from(devices.values()).slice(-MAX_FCM_DEVICES);
}

function registerFcmDevice(users, userKey, user, tokenValue, metadata = {}) {
  const token = safeToken(tokenValue);
  if (!token || !user) return false;

  // A Firebase token belongs to one signed-in Novyn account at a time.
  // Preserve the per-device release marker when moving it between accounts:
  // the marker describes the installed device build, not the account.
  let movedDevice = null;
  for (const [otherKey, otherUser] of users.entries()) {
    if (otherKey === userKey || !otherUser) continue;
    const previous = collectFcmDevices(otherUser);
    const existingDevice = previous.find((device) => device.token === token);
    if (existingDevice) movedDevice = existingDevice;
    const next = previous.filter((device) => device.token !== token);
    if (next.length !== previous.length) {
      otherUser.fcmDevices = next;
      if (safeToken(otherUser.fcmToken) === token) {
        otherUser.fcmToken = next.length ? next[next.length - 1].token : "";
      }
    }
  }

  const devices = collectFcmDevices(user);
  const previous = devices.find((device) => device.token === token) || movedDevice;
  const numericBuild = Number(metadata.appBuild);
  const entry = {
    token,
    appBuild: Number.isFinite(numericBuild) ? Math.max(0, Math.floor(numericBuild)) : 0,
    lastNotifiedUpdateBuild: previous?.lastNotifiedUpdateBuild || 0,
    platform: metadata.platform === "ios" ? "ios" : "android",
    lastRegisteredAt: new Date().toISOString(),
  };
  user.fcmDevices = [
    ...devices.filter((device) => device.token !== token),
    entry,
  ].slice(-MAX_FCM_DEVICES);
  user.fcmToken = token;
  return true;
}

function removeFcmDevice(user, tokenValue) {
  if (!user) return false;
  const token = safeToken(tokenValue);
  // An absent or malformed token must never turn a single-device logout into
  // an accidental sign-out of every registered device on the account.
  if (!token) return false;

  const devices = collectFcmDevices(user);
  const next = devices.filter((device) => device.token !== token);
  user.fcmDevices = next;
  if (safeToken(user.fcmToken) === token) {
    user.fcmToken = next.length ? next[next.length - 1].token : "";
  }
  return next.length !== devices.length;
}

function toDataValue(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value === "object") return undefined;
  return String(value).slice(0, 3900);
}

function createFcmMessage(userKey, user, payload = {}) {
  const type = String(payload.type || "message");
  const isCall = type === "call";
  const isGroup = payload.group === true;
  const dataOnlyTypes = new Set([
    "call",
    "app_update",
    "friend_request",
    "friend_request_accepted",
    "friend_request_declined",
    "group_invite",
  ]);
  // Every mobile alert is data-only so the app can check the signed-in account,
  // apply privacy/DND rules, and render one consistent local notification.
  const dataOnly = type === "message" || dataOnlyTypes.has(type);
  const silent = payload.silent === true;
  const ttlMs = isCall ? 45000 : FOUR_WEEKS_MS;
  const title = String(payload.title || "Novyn").slice(0, 180);
  const body = String(payload.body || "You have a new notification").slice(0, 900);

  const data = {
    type,
    recipient: String(user?.username || userKey || "").slice(0, 120),
    eventId: String(
      payload.eventId ||
      payload.messageId ||
      (isCall ? (String(payload.callId || "call") + ":" + String(payload.callStatus || "missed")) : "") ||
      (type === "app_update" ? "app-update:" + String(payload.build || "0") : "") ||
      (type + ":" + Date.now())
    ).slice(0, 180),
    title,
    body,
    chat: String(isGroup ? (payload.groupId || payload.chat || "") : (payload.chat || payload.from || "")).slice(0, 180),
    kind: isGroup ? "group" : "friend",
    silent: silent ? "1" : "0",
  };

  const optionalFields = [
    "url", "tag", "groupId", "callStatus", "callId", "isVideo",
    "previewEnabled", "from", "displayName", "action", "build",
    "releaseTag", "releaseUrl",
  ];
  for (const key of optionalFields) {
    const value = toDataValue(payload[key]);
    if (value !== undefined) data[key] = value;
  }
  if (type === "message") data.previewEnabled = payload.previewEnabled === false ? "0" : "1";
  if (isCall) {
    data.callStatus = String(payload.callStatus || "missed");
    data.callId = String(payload.callId || "");
    data.isVideo = payload.isVideo ? "1" : "0";
  }

  const message = {
    data,
    android: {
      priority: silent ? "normal" : "high",
      ttl: ttlMs,
      ...(dataOnly ? {} : {
        notification: {
          channelId: isGroup ? "novyn_messages" : "novyn_social",
          ...(payload.tag ? { tag: String(payload.tag).slice(0, 100) } : {}),
          ...(silent ? {} : { sound: "default" }),
        },
      }),
    },
    apns: {
      headers: {
        "apns-expiration": String(Math.floor(Date.now() / 1000) + Math.floor(ttlMs / 1000)),
        ...(dataOnly
          ? { "apns-push-type": "background", "apns-priority": "5" }
          : { "apns-push-type": "alert", "apns-priority": "10" }),
      },
      payload: {
        aps: dataOnly
          ? { "content-available": 1 }
          : {
              alert: { title, body },
              ...(silent ? {} : { sound: "default" }),
            },
      },
    },
  };

  if (!dataOnly) message.notification = { title, body };
  return message;
}

function parseAndroidReleaseBuild(tag) {
  const match = /^novyn-(?:arm64-build|apk)-(\d+)(?:-\d+)*$/i.exec(String(tag || "").trim());
  if (!match) return 0;
  const build = Number(match[1]);
  return Number.isSafeInteger(build) ? build : 0;
}

function isInvalidFcmTokenError(code) {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

function isRetryableFcmError(code) {
  return [
    "messaging/server-unavailable",
    "messaging/internal-error",
    "messaging/unknown-error",
    "messaging/quota-exceeded",
    "messaging/too-many-messages",
    "messaging/message-rate-exceeded",
    "messaging/device-message-rate-exceeded",
  ].includes(code);
}

module.exports = {
  MAX_FCM_DEVICES,
  collectFcmDevices,
  registerFcmDevice,
  removeFcmDevice,
  createFcmMessage,
  parseAndroidReleaseBuild,
  isInvalidFcmTokenError,
  isRetryableFcmError,
};
