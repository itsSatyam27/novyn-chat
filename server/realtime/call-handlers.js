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
    io
  } = deps;

  socket.on("call_start", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const isVideo = Boolean(payload?.isVideo);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;

    const callTarget = resolveChatTargetForUser(userKey, to, "friend", { inferGroup: false });
    if (!callTarget.ok || callTarget.type !== "friend") {
      socket.emit("call_ended", { callId, reason: "You are not authorized to call this user." });
      return;
    }

    const me = users.get(userKey);
    const friendKey = normalizeName(to);
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
      socket.emit("call_ended", { callId, reason: "User is offline" });
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
