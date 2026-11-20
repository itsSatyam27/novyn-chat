"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  isQuietHoursActive,
  shouldDeliverNotification,
} = require("../server/notification-policy");

function preferences(overrides = {}) {
  return {
    notificationsEnabled: true,
    directMessagesEnabled: true,
    groupMessagesEnabled: true,
    groupNotificationsEnabled: true,
    mentionsRepliesEnabled: true,
    friendRequestsEnabled: true,
    friendRequestAcceptedEnabled: true,
    groupInvitationsEnabled: true,
    voiceCallsEnabled: true,
    videoCallsEnabled: true,
    missedCallsEnabled: true,
    gameInvitationsEnabled: true,
    gameTurnEnabled: true,
    gameResultsEnabled: true,
    quietHoursEnabled: false,
    quietHoursStart: "22:00",
    quietHoursEnd: "07:00",
    quietHoursOffsetMinutes: 0,
    ...overrides,
  };
}

test("direct, group, mention and reply preferences are independent", () => {
  assert.equal(shouldDeliverNotification(
    preferences({ directMessagesEnabled: false }),
    { type: "message" },
  ), false);

  assert.equal(shouldDeliverNotification(
    preferences({ groupMessagesEnabled: false }),
    { type: "message", group: true },
  ), false);

  assert.equal(shouldDeliverNotification(
    preferences({ groupNotificationsEnabled: false }),
    { type: "message", group: true },
  ), false);

  assert.equal(shouldDeliverNotification(
    preferences({
      directMessagesEnabled: false,
      groupMessagesEnabled: false,
      mentionsRepliesEnabled: true,
    }),
    { type: "message", group: true, mentionOrReply: true },
  ), true);

  assert.equal(shouldDeliverNotification(
    preferences({ mentionsRepliesEnabled: false }),
    { type: "message", group: true, mentionOrReply: true },
  ), false);
});

test("social notification categories are independently respected", () => {
  assert.equal(shouldDeliverNotification(
    preferences({ friendRequestsEnabled: false }),
    { type: "friend_request" },
  ), false);
  assert.equal(shouldDeliverNotification(
    preferences({ friendRequestAcceptedEnabled: false }),
    { type: "friend_request_accepted" },
  ), false);
  assert.equal(shouldDeliverNotification(
    preferences({ groupInvitationsEnabled: false }),
    { type: "group_invite" },
  ), false);
});

test("voice, video and missed calls have independent preferences", () => {
  assert.equal(shouldDeliverNotification(
    preferences({ voiceCallsEnabled: false }),
    { type: "call", callStatus: "incoming", isVideo: false },
  ), false);
  assert.equal(shouldDeliverNotification(
    preferences({ videoCallsEnabled: false }),
    { type: "call", callStatus: "incoming", isVideo: "1" },
  ), false);
  assert.equal(shouldDeliverNotification(
    preferences({ missedCallsEnabled: false }),
    { type: "call", callStatus: "missed" },
  ), false);
});

test("game invitation, turn and result events respect their own preferences", () => {
  for (const [type, key] of [
    ["game_invitation", "gameInvitationsEnabled"],
    ["game_turn", "gameTurnEnabled"],
    ["game_result", "gameResultsEnabled"],
  ]) {
    assert.equal(
      shouldDeliverNotification(preferences({ [key]: false }), { type }),
      false,
      type,
    );
  }
});

test("quiet hours handle same-day and overnight schedules while calls remain deliverable", () => {
  const overnight = preferences({
    quietHoursEnabled: true,
    quietHoursStart: "22:00",
    quietHoursEnd: "07:00",
    quietHoursOffsetMinutes: 0,
  });
  assert.equal(isQuietHoursActive(overnight, Date.UTC(2026, 10, 20, 23, 0)), true);
  assert.equal(isQuietHoursActive(overnight, Date.UTC(2026, 10, 21, 6, 59)), true);
  assert.equal(isQuietHoursActive(overnight, Date.UTC(2026, 10, 21, 7, 0)), false);
  assert.equal(shouldDeliverNotification(
    overnight,
    { type: "message" },
    Date.UTC(2026, 10, 20, 23, 0),
  ), false);
  assert.equal(shouldDeliverNotification(
    overnight,
    { type: "call", callStatus: "incoming" },
    Date.UTC(2026, 10, 20, 23, 0),
  ), true);

  const daytime = preferences({
    quietHoursEnabled: true,
    quietHoursStart: "09:00",
    quietHoursEnd: "17:00",
  });
  assert.equal(isQuietHoursActive(daytime, Date.UTC(2026, 10, 20, 12, 0)), true);
  assert.equal(isQuietHoursActive(daytime, Date.UTC(2026, 10, 20, 17, 0)), false);
});

test("global push switch suppresses every notification category", () => {
  assert.equal(
    shouldDeliverNotification(
      preferences({ notificationsEnabled: false }),
      { type: "call", callStatus: "incoming" },
    ),
    false,
  );
});
