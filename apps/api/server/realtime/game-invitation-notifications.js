"use strict";

function emitGameInviteClosed({
  invite,
  messageId,
  onlineUsers,
  io,
  reason,
  includeSender = false,
}) {
  if (!invite || !messageId || !onlineUsers || !io) return 0;
  const socketIds = new Set([
    invite.acceptedSocketId,
    onlineUsers.get(invite.toKey),
    ...(includeSender ? [onlineUsers.get(invite.fromKey)] : []),
  ].filter((value) => typeof value === "string" && value.length > 0));
  const packet = {
    messageId,
    gameType: invite.gameType,
    reason: reason || "expired",
  };
  for (const socketId of socketIds) {
    io.to(socketId).emit("game_invite_timeout", packet);
  }
  return socketIds.size;
}

function expirePendingGameInvite({
  messageId,
  invite,
  pendingGameInvites,
  onlineUsers,
  io,
}) {
  if (!messageId || !invite || pendingGameInvites.get(messageId) !== invite) {
    return false;
  }
  pendingGameInvites.delete(messageId);
  emitGameInviteClosed({
    invite,
    messageId,
    onlineUsers,
    io,
    reason: "expired",
    includeSender: true,
  });
  return true;
}

module.exports = {
  emitGameInviteClosed,
  expirePendingGameInvite,
};
