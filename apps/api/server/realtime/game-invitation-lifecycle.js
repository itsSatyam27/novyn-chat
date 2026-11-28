"use strict";

function emitGameInvitationTimeoutToParticipants({
  io,
  onlineUsers,
  invite,
  messageId,
  reason,
}) {
  if (!io || typeof io.to !== "function" ||
      !onlineUsers || typeof onlineUsers.get !== "function" ||
      !invite || !messageId) {
    return [];
  }

  const socketIds = new Set();
  for (const userKey of [invite.fromKey, invite.toKey]) {
    const key = String(userKey || "").trim();
    if (!key) continue;
    const socketId = onlineUsers.get(key);
    if (typeof socketId === "string" && socketId.trim()) {
      socketIds.add(socketId);
    }
  }

  const acceptedSocketId = String(invite.acceptedSocketId || "").trim();
  if (acceptedSocketId) socketIds.add(acceptedSocketId);

  const packet = {
    messageId: String(messageId),
    gameType: invite.gameType,
  };
  if (reason) packet.reason = String(reason);

  for (const socketId of socketIds) {
    io.to(socketId).emit("game_invite_timeout", packet);
  }
  return [...socketIds];
}

module.exports = { emitGameInvitationTimeoutToParticipants };
