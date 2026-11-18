// Socket message mutation handlers extracted from server.js.
// Dependencies are injected so the realtime layer stays testable and does not own app state.
function registerMessageMutationHandlers(socket, deps) {
  const {
    allowSocketAction,
    toDisplayName,
    withUploadToken,
    normalizeChatKind,
    MAX_MESSAGE_LENGTH,
    users,
    groups,
    isGroupMember,
    getGroupConversationKey,
    getConversationKey,
    conversations,
    CALL_LOG_PREFIX,
    DELETED_MESSAGE_TEXT,
    nowIso,
    normalizeName,
    onlineUsers,
    io,
    emitFriendList,
    schedulePersist
  } = deps;

  socket.on("edit_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "edit_message", 50, 60 * 1000)) {
      socket.emit("error_message", { message: "Edit rate limit reached. Slow down a bit." });
      return;
    }

    const messageId = toDisplayName(payload?.messageId);
    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const nextText = withUploadToken(payload?.text);
    if (!messageId || !to || !nextText) return;

    if (nextText.length > MAX_MESSAGE_LENGTH) {
      socket.emit("error_message", { message: `Message too long. Limit is ${MAX_MESSAGE_LENGTH} characters.` });
      return;
    }

    const me = users.get(userKey);
    if (!me) return;
    let conversationKey = "";
    let emitTargets = [];
    let withLabel = "";
    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) {
        socket.emit("error_message", { message: "You can edit messages only in active group chats." });
        return;
      }
      conversationKey = getGroupConversationKey(group.id);
      emitTargets = Array.from(group.members);
      withLabel = group.id;
    } else {
      const toKey = normalizeName(to);
      const friend = users.get(toKey);
      if (!friend || !me.friends.has(toKey)) {
        socket.emit("error_message", { message: "You can edit messages only in active friend chats." });
        return;
      }
      conversationKey = getConversationKey(userKey, toKey);
      emitTargets = [userKey, toKey];
      withLabel = toKey;
    }

    const conversation = conversations.get(conversationKey) || [];
    const message = conversation.find((entry) => entry.id === messageId);
    if (!message) {
      socket.emit("error_message", { message: "Message not found." });
      return;
    }

    if (message.fromKey !== userKey) {
      socket.emit("error_message", { message: "You can edit only your own messages." });
      return;
    }
    if (message.deletedAt) {
      socket.emit("error_message", { message: "Deleted messages cannot be edited." });
      return;
    }
    if (message.attachment) {
      socket.emit("error_message", { message: "Attachment messages cannot be edited." });
      return;
    }
    if (message.isEncrypted) {
      socket.emit("error_message", { message: "Encrypted messages cannot be edited yet." });
      return;
    }
    if (String(message.text || "").startsWith(CALL_LOG_PREFIX)) {
      socket.emit("error_message", { message: "Call log messages cannot be edited." });
      return;
    }

    if (toDisplayName(message.text) === nextText) {
      return;
    }

    message.text = nextText;
    message.editedAt = nowIso();

    const uniqueTargets = Array.from(new Set(emitTargets.map(normalizeName).filter(Boolean)));
    for (const targetKey of uniqueTargets) {
      const targetSocket = onlineUsers.get(targetKey);
      if (!targetSocket) continue;
      const withValue = toType === "group"
        ? withLabel
        : (targetKey === userKey ? users.get(withLabel)?.username || to : me.username);
      io.to(targetSocket).emit("message_edited", {
        messageId: message.id,
        with: withValue,
        toType,
        text: message.text,
        editedAt: message.editedAt,
        by: me.username,
      });
    }

    if (toType === "group") {
      for (const targetKey of uniqueTargets) {
        emitFriendList(targetKey);
      }
    } else {
      emitFriendList(userKey);
      emitFriendList(withLabel);
    }
    schedulePersist();
  });

  socket.on("set_message_pin", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "set_message_pin", 80, 60 * 1000)) return;

    const messageId = toDisplayName(payload?.messageId);
    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const shouldPin = Boolean(payload?.pinned);
    if (!messageId || !to) return;

    const me = users.get(userKey);
    if (!me) return;
    let conversationKey = "";
    let emitTargets = [];
    let withLabel = "";
    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) {
        socket.emit("error_message", { message: "You can pin messages only in active group chats." });
        return;
      }
      conversationKey = getGroupConversationKey(group.id);
      emitTargets = Array.from(group.members);
      withLabel = group.id;
    } else {
      const toKey = normalizeName(to);
      const friend = users.get(toKey);
      if (!friend || !me.friends.has(toKey)) {
        socket.emit("error_message", { message: "You can pin messages only in active friend chats." });
        return;
      }
      conversationKey = getConversationKey(userKey, toKey);
      emitTargets = [userKey, toKey];
      withLabel = toKey;
    }

    const conversation = conversations.get(conversationKey) || [];
    const message = conversation.find((entry) => entry.id === messageId);
    if (!message) {
      socket.emit("error_message", { message: "Message not found." });
      return;
    }
    if (message.deletedAt) {
      socket.emit("error_message", { message: "Deleted messages cannot be pinned." });
      return;
    }

    if (shouldPin) {
      message.pinnedAt = nowIso();
      message.pinnedBy = me.username;
    } else {
      message.pinnedAt = null;
      message.pinnedBy = "";
    }

    const uniqueTargets = Array.from(new Set(emitTargets.map(normalizeName).filter(Boolean)));
    for (const targetKey of uniqueTargets) {
      const targetSocket = onlineUsers.get(targetKey);
      if (!targetSocket) continue;
      const withValue = toType === "group"
        ? withLabel
        : (targetKey === userKey ? users.get(withLabel)?.username || to : me.username);
      io.to(targetSocket).emit("message_pin_updated", {
        messageId: message.id,
        with: withValue,
        toType,
        pinned: shouldPin,
        pinnedAt: message.pinnedAt,
        pinnedBy: message.pinnedBy,
        by: me.username,
      });
    }

    if (toType === "group") {
      for (const targetKey of uniqueTargets) {
        emitFriendList(targetKey);
      }
    }
    schedulePersist();
  });

  socket.on("delete_message", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = socket.data.userKey;
    if (!userKey) { respond({ ok: false, message: "Please sign in again." }); return; }

    const messageId = toDisplayName(payload?.messageId);
    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    if (!messageId || !to) { respond({ ok: false, message: "Message not found." }); return; }

    const me = users.get(userKey);
    if (!me) { respond({ ok: false, message: "Account not found." }); return; }
    let conversationKey = "";
    let emitTargets = [];
    let withLabel = "";
    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) {
        socket.emit("error_message", { message: "You can delete messages only in active group chats." });
        respond({ ok: false, message: "You can delete messages only in active group chats." });
        return;
      }
      conversationKey = getGroupConversationKey(group.id);
      emitTargets = Array.from(group.members);
      withLabel = group.id;
    } else {
      const toKey = normalizeName(to);
      const friend = users.get(toKey);
      if (!friend || !me.friends.has(toKey)) {
        socket.emit("error_message", { message: "You can delete messages only in active friend chats." });
        respond({ ok: false, message: "You can delete messages only in active friend chats." });
        return;
      }
      conversationKey = getConversationKey(userKey, toKey);
      emitTargets = [userKey, toKey];
      withLabel = toKey;
    }

    const conversation = conversations.get(conversationKey) || [];
    const message = conversation.find((entry) => entry.id === messageId);
    if (!message) {
      socket.emit("error_message", { message: "Message not found." });
      respond({ ok: false, message: "Message not found." });
      return;
    }

    if (message.fromKey !== userKey) {
      socket.emit("error_message", { message: "You can delete only your own messages." });
      respond({ ok: false, message: "You can delete only your own messages." });
      return;
    }

    if (message.deletedAt) {
      respond({ ok: true, alreadyDeleted: true });
      return;
    }

    message.deletedAt = nowIso();
    message.text = DELETED_MESSAGE_TEXT;
    message.editedAt = null;
    message.attachment = null;
    message.pinnedAt = null;
    message.pinnedBy = "";
    message.reactions = {};
    if (Array.isArray(message.seenBy)) {
      message.seenBy = [normalizeName(message.fromKey || message.from)];
    }

    const uniqueTargets = Array.from(new Set(emitTargets.map(normalizeName).filter(Boolean)));
    for (const targetKey of uniqueTargets) {
      const targetSocket = onlineUsers.get(targetKey);
      if (!targetSocket) continue;
      const withValue = toType === "group"
        ? withLabel
        : (targetKey === userKey ? users.get(withLabel)?.username || to : me.username);
      io.to(targetSocket).emit("message_deleted", {
        messageId: message.id,
        with: withValue,
        toType,
        text: message.text,
        deletedAt: message.deletedAt,
        by: me.username,
      });
    }

    if (toType === "group") {
      for (const targetKey of uniqueTargets) {
        emitFriendList(targetKey);
      }
    } else {
      emitFriendList(userKey);
      emitFriendList(withLabel);
    }
    schedulePersist();
    respond({ ok: true });
  });
}

module.exports = { registerMessageMutationHandlers };
