// Socket.IO WebRTC signaling handlers. Call state and authorization are injected from the server.
const RING_TIMEOUT_MS = 45_000;
const ringingTimers = new Map();
function clearRingingTimer(callId) {
  const timer = ringingTimers.get(callId);
  if (timer) clearTimeout(timer);
  ringingTimers.delete(callId);
}
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

  function expireRingingCall(callerKey, receiverKey, callId, isVideo) {
    const active = activeCalls.get(callerKey);
    if (!active || active.callId !== callId || active.status !== "ringing" || active.peerKey !== receiverKey) return;
    clearRingingTimer(callId);
    clearCallPair(callerKey);
    const caller = users.get(callerKey);
    const receiver = users.get(receiverKey);
    const callerName = caller?.username || callerKey;
    const callerDisplayName = caller?.displayName || callerName;
    recordCallLog?.(receiverKey, {
      callId, callerId: callerName, receiverId: receiver?.username || receiverKey,
      type: isVideo ? "video" : "voice", status: "missed", duration: 0,
      createdAt: new Date().toISOString(),
    });
    Promise.resolve(sendPushToUser?.(receiverKey, {
      type: "call", callStatus: "missed", title: "Missed call",
      body: "You missed a call from " + callerDisplayName,
      chat: callerName, kind: "friend", callId, isVideo, tag: "call-" + callId,
    })).catch((error) => console.warn("[Call] Missed-call notification failed:", error?.message || error));
    for (const peerKey of [callerKey, receiverKey]) {
      const socketId = onlineUsers.get(peerKey);
      if (socketId) io.to(socketId).emit("call_ended", { from: callerName, callId, reason: "No answer" });
    }
  }

  function scheduleRingingTimeout(callerKey, receiverKey, callId, isVideo) {
    clearRingingTimer(callId);
    const timer = setTimeout(() => expireRingingCall(callerKey, receiverKey, callId, isVideo), RING_TIMEOUT_MS);
    timer.unref?.();
    ringingTimers.set(callId, timer);
  }

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
      setCallPair(userKey, friendKey, "ringing", callId, { type: isVideo ? "video" : "voice", callerKey: userKey });
      scheduleRingingTimeout(userKey, friendKey, callId, isVideo);
      const callerName = me?.username || userKey;
      const callerDisplayName = me?.displayName || callerName;
      io.to(friendSocketId).emit("call_incoming", {
        from: callerName,
        fromDisplayName: callerDisplayName,
        isVideo,
        callId,
      });
      // Also wake a backgrounded mobile client through high-priority FCM.
      // The foreground app ignores this duplicate when its live socket is active.
      Promise.resolve(sendPushToUser?.(friendKey, {
        type: "call",
        callStatus: "incoming",
        title: isVideo ? "Incoming video call" : "Incoming voice call",
        body: callerDisplayName + " is calling you",
        chat: callerName,
        kind: "friend",
        callId,
        isVideo,
        tag: "incoming-call-" + callId,
      })).catch((error) => {
        console.warn("[Call] Incoming-call notification failed:", error?.message || error);
      });
    } else {
      // Keep the ringing session alive while the recipient app is backgrounded,
      // terminated, or temporarily disconnected. FCM will wake the device.
      if (activeCalls.has(userKey) || activeCalls.has(friendKey)) {
        socket.emit("call_ended", { callId, reason: "User is busy" });
        return;
      }
      setCallPair(userKey, friendKey, "ringing", callId, { type: isVideo ? "video" : "voice", callerKey: userKey });
      scheduleRingingTimeout(userKey, friendKey, callId, isVideo);
      const callerName = me?.username || userKey;
      const callerDisplayName = me?.displayName || callerName;
      Promise.resolve(sendPushToUser?.(friendKey, {
        type: "call",
        callStatus: "incoming",
        title: isVideo ? "Incoming video call" : "Incoming voice call",
        body: callerDisplayName + " is calling you",
        chat: callerName,
        kind: "friend",
        callId,
        isVideo,
        tag: "incoming-call-" + callId,
      })).catch((error) => {
        console.warn("[Call] Incoming-call notification failed:", error?.message || error);
      });
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
    if (!friendSocketId && active.status === "ringing") {
      expireRingingCall(friendKey, userKey, callId, active.type === "video");
      socket.emit("call_ended", { callId, reason: "Caller is unavailable" });
      return;
    }
    clearRingingTimer(callId);
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
      clearRingingTimer(callId);
      if (active.status === "ringing") {
        const callerKey = reason === "Call declined" ? friendKey : userKey;
        const missedKey = reason === "Call declined" ? userKey : friendKey;
        const caller = users.get(callerKey);
        const receiver = users.get(missedKey);
        const entry = {
          callId,
          callerId: caller?.username || callerKey,
          receiverId: receiver?.username || missedKey,
          type: active.type || "voice",
          status: "missed",
          duration: 0,
          createdAt: new Date().toISOString(),
        };
        recordCallLog?.(missedKey, entry);
        const missedCaller = users.get(callerKey);
        const missedName = missedCaller?.username || callerKey;
        if (reason === "Call declined") {
          Promise.resolve(sendPushToUser?.(userKey, {
            type: "call", callStatus: "ended", callId, chat: missedName, isVideo: active.type === "video",
          })).catch(() => {});
        } else {
          Promise.resolve(sendPushToUser?.(missedKey, {
            type: "call", callStatus: "missed", title: "Missed call",
            body: "You missed a call from " + (missedCaller?.displayName || missedName),
            chat: missedName, kind: "friend", callId, isVideo: active.type === "video", tag: "call-" + callId,
          })).catch((error) => console.warn("[Call] Missed-call notification failed:", error?.message || error));
        }
      }
      clearCallPair(userKey);
      const friendSocketId = onlineUsers.get(friendKey);
      if (friendSocketId) {
        io.to(friendSocketId).emit("call_ended", { from: userKey, callId, reason });
      }
    }
  });

  // A voice-call participant may request a video upgrade. Only an active
  // participant in the exact call session can send or receive this request.
  socket.on("call_media_upgrade_request", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;
    const peerKey = normalizeName(to);
    const active = activeCalls.get(userKey);
    if (!active || active.peerKey !== peerKey || active.callId !== callId || active.status !== "connected") return;
    const peerSocketId = onlineUsers.get(peerKey);
    if (peerSocketId) {
      io.to(peerSocketId).emit("call_media_upgrade_request", {
        from: users.get(userKey)?.username || userKey, callId,
      });
    }
  });

  socket.on("call_media_upgrade_response", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;
    const peerKey = normalizeName(to);
    const active = activeCalls.get(userKey);
    if (!active || active.peerKey !== peerKey || active.callId !== callId || active.status !== "connected") return;
    const peerSocketId = onlineUsers.get(peerKey);
    if (peerSocketId) {
      io.to(peerSocketId).emit("call_media_upgrade_response", {
        from: users.get(userKey)?.username || userKey,
        callId, accepted: payload?.accepted === true,
      });
    }
  });

  socket.on("call_screen_share_state", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) return;
    const peerKey = normalizeName(to);
    const active = activeCalls.get(userKey);
    if (!active || active.peerKey !== peerKey || active.callId !== callId || active.status !== "connected") return;
    const streamId = payload?.streamId == null ? null : toDisplayName(payload.streamId).slice(0, 128);
    const peerSocketId = onlineUsers.get(peerKey);
    if (peerSocketId) {
      io.to(peerSocketId).emit("call_screen_share_changed", {
        from: users.get(userKey)?.username || userKey, callId, streamId,
      });
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
