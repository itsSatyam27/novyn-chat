// Socket.IO WebRTC signaling handlers. Call state and authorization are injected from the server.
function registerCallHandlers(socket, deps) {
  const {
    resolveChatTargetForUser,
    toDisplayName,
    users,
    normalizeName,
    onlineUsers,
    activeCalls,
    setCallPair,
    clearCallPair,
    io,
    usersAreBlocked,
    sendPushToUser,
    recordCallLog
  } = deps;

  socket.on("call_start", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const isVideo = Boolean(payload?.isVideo);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;
    if (normalizeName(to) === normalizeName(userKey)) {
      socket.emit("call_ended", { callId, reason: "You cannot call yourself." });
      return;
    }

    const me = users.get(userKey);
    const friendKey = normalizeName(to);
    const target = users.get(friendKey);
    const areFriends = Boolean(me?.friends?.has(friendKey));
    if (usersAreBlocked?.(userKey, friendKey) || !target || target.callPrivacy === "nobody" || (target.callPrivacy !== "everyone" && !areFriends)) {
      socket.emit("call_ended", { callId, reason: "This user is not accepting calls from you." });
      return;
    }
    if (!target.isRegistered) {
      socket.emit("call_ended", { callId, reason: "You are not authorized to call this user." });
      return;
    }
    const friendSocketId = onlineUsers.get(friendKey);

    console.log(`[Call] Call started from ${userKey} to ${friendKey} (socket: ${friendSocketId})`);

    if (friendSocketId) {
      if (activeCalls.has(userKey) || activeCalls.has(friendKey)) {
        socket.emit("call_ended", { callId, reason: "User is busy" });
        return;
      }
      setCallPair(userKey, friendKey, "ringing", callId);
      io.to(friendSocketId).emit("call_incoming", {
        from: me?.username || userKey,
        fromDisplayName: me?.displayName || me?.username || userKey,
        isVideo,
        callId,
      });
    } else {
      const callerName = me?.username || userKey;
      const createdAt = new Date().toISOString();
      const callType = isVideo ? "video" : "voice";
      const callEntry = {
        callId,
        callerId: callerName,
        receiverId: target.username || friendKey,
        type: callType,
        status: "outgoing",
        duration: 0,
        createdAt,
      };
      const missedEntry = {
        ...callEntry,
        status: "missed",
      };
      // Persist both sides so the missed call is visible when the recipient returns.
      recordCallLog?.(userKey, callEntry);
      recordCallLog?.(friendKey, missedEntry);
      // The existing push pipeline delivers this while the recipient is offline.
      Promise.resolve(sendPushToUser?.(friendKey, {
        type: "call",
        title: "Missed call",
        body: (me?.displayName || callerName) + " tried to call you",
        chat: callerName,
        kind: "friend",
        callId,
        tag: "missed-call-" + callId,
      })).catch((error) => {
        console.warn("[Call] Missed-call notification failed:", error?.message || error);
      });
      socket.emit("call_ended", { callId, reason: "User is offline", status: "offline" });
    }
  });

  socket.on("call_accept", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;

    const friendKey = normalizeName(to);
    const friendSocketId = onlineUsers.get(friendKey);
    const active = activeCalls.get(userKey);
    if (!active || active.peerKey !== friendKey || active.callId !== callId) return;
    setCallPair(userKey, friendKey, "connected", callId);
    console.log(`[Call] Call accepted by ${userKey} for ${friendKey} (socket: ${friendSocketId})`);
    if (friendSocketId) {
      io.to(friendSocketId).emit("call_accepted", { from: userKey, callId });
    }
  });

  socket.on("call_end", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    const reason = payload?.reason || "Call ended";

    if (to && callId) {
      const friendKey = normalizeName(to);
      const active = activeCalls.get(userKey);
      if (!active || active.peerKey !== friendKey || active.callId !== callId) return;
      clearCallPair(userKey);
      const friendSocketId = onlineUsers.get(friendKey);
      if (friendSocketId) {
        io.to(friendSocketId).emit("call_ended", { from: userKey, callId, reason });
      }
    }
  });

  socket.on("webrtc_signal", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    const signal = payload?.signal;
    if (!to || !callId || !signal) return;

    const friendKey = normalizeName(to);
    const active = activeCalls.get(userKey);
    if (!active || active.peerKey !== friendKey || active.callId !== callId) return;
    const friendSocketId = onlineUsers.get(friendKey);
    if (friendSocketId) {
      io.to(friendSocketId).emit("webrtc_signal", { from: userKey, callId, signal });
    }
  });


}

module.exports = { registerCallHandlers };
