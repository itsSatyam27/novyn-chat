"use strict";

function isQuietHoursActive(user, timestamp = Date.now()) {
  if (!user || user.quietHoursEnabled !== true) return false;
  const parseMinutes = (value) => {
    const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(String(value || ""));
    return match ? Number(match[1]) * 60 + Number(match[2]) : null;
  };
  const start = parseMinutes(user.quietHoursStart);
  const end = parseMinutes(user.quietHoursEnd);
  if (start === null || end === null || start === end) return false;
  const offset = Math.max(-840, Math.min(840, Number(user.quietHoursOffsetMinutes) || 0));
  const local = new Date(timestamp + offset * 60 * 1000);
  const current = local.getUTCHours() * 60 + local.getUTCMinutes();
  return start < end
    ? current >= start && current < end
    : current >= start || current < end;
}

function shouldDeliverNotification(user, payload = {}, timestamp = Date.now()) {
  if (!user || user.notificationsEnabled === false) return false;
  const type = String(payload.type || "message");
  if (type === "message") {
    if (payload.mentionOrReply === true) {
      if (user.mentionsRepliesEnabled === false) return false;
    } else if (payload.group === true) {
      if (user.groupMessagesEnabled === false || user.groupNotificationsEnabled === false) return false;
    } else if (user.directMessagesEnabled === false) {
      return false;
    }
  } else if (type === "friend_request" || type === "friend_request_declined") {
    if (user.friendRequestsEnabled === false) return false;
  } else if (type === "friend_request_accepted") {
    if (user.friendRequestAcceptedEnabled === false) return false;
  } else if (type === "group_invite") {
    if (user.groupInvitationsEnabled === false) return false;
  } else if (type === "call") {
    const status = String(payload.callStatus || "missed");
    if (status === "missed") {
      if (user.missedCallsEnabled === false) return false;
    } else if (status === "incoming") {
      const isVideo = payload.isVideo === true || payload.isVideo === "1";
      if (isVideo ? user.videoCallsEnabled === false : user.voiceCallsEnabled === false) return false;
    }
  } else if (type === "game_invitation" && user.gameInvitationsEnabled === false) {
    return false;
  } else if (type === "game_turn" && user.gameTurnEnabled === false) {
    return false;
  } else if (type === "game_result" && user.gameResultsEnabled === false) {
    return false;
  }
  if (user.doNotDisturbEnabled === true) {
    const target = String(
      payload.group === true
        ? (payload.groupId || payload.chat || "")
        : (payload.chat || payload.from || "")
    ).trim().toLowerCase();
    const favorites = new Set(
      (Array.isArray(user.favoriteChatIds) ? user.favoriteChatIds : [])
        .map((value) => String(value || "").trim().toLowerCase())
        .filter(Boolean)
    );
    if (!target || !favorites.has(target)) return false;
  }
  if (type !== "call" && isQuietHoursActive(user, timestamp)) return false;
  return true;
}

module.exports = { isQuietHoursActive, shouldDeliverNotification };
