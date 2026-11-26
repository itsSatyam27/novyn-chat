// Socket.IO WebRTC signaling handlers. Call state and authorization are injected from the server.
const RING_TIMEOUT_MS = 45_000;
const ringingTimers = new Map();
function clearRingingTimer(callId) {
  const timer = ringingTimers.get(callId);
  if (timer) clearTimeout(timer);
  ringingTimers.delete(callId);
}

function cancelCallForUser(userKey, deps, reason = "Call ended") {
  const active = deps.activeCalls.get(userKey);
  if (!active) return false;
  clearRingingTimer(active.callId);
  const peerKey = active.peerKey;
  deps.clearCallPair(userKey);
  const payload = {
    from: deps.users.get(userKey)?.username || userKey,
    callId: active.callId,
    reason,
  };
  for (const key of [userKey, peerKey]) {
    const socketId = key ? deps.onlineUsers.get(key) : null;
    if (socketId) deps.io.to(socketId).emit("call_ended", payload);
  }
  return true;
}

function registerCallHandlers(socket, deps) {
  const {
    resolveChatTargetForUser,
    toDisplayName,
    users,
    normalizeName,
    onlineUsers,
    activeCalls,
    isUserInGroupCall,
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
    const callExpiresAt = Date.now() + RING_TIMEOUT_MS;
    if (!to || !callId) return;
    if (normalizeName(to) === normalizeName(userKey)) {
      socket.emit("call_ended", { callId, reason: "You cannot call yourself." });
      return;
    }

    const me = users.get(userKey);
    if (me?.callsEnabled === false) {
      socket.emit("call_ended", {
        callId,
        reason: "Calls are disabled in your current status mode.",
      });
      return;
    }
    const friendKey = normalizeName(to);
    const target = users.get(friendKey);
    const areFriends = Boolean(me?.friends?.has(friendKey));
    if (usersAreBlocked?.(userKey, friendKey) || !target || target.callsEnabled === false || target.callPrivacy === "nobody" || (target.callPrivacy !== "everyone" && !areFriends)) {
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
      if (activeCalls.has(userKey) || activeCalls.has(friendKey) ||
          isUserInGroupCall?.(userKey) || isUserInGroupCall?.(friendKey)) {
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
        callExpiresAt,
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
        callExpiresAt,
        isVideo,
        tag: "incoming-call-" + callId,
      })).catch((error) => {
        console.warn("[Call] Incoming-call notification failed:", error?.message || error);
      });
    } else {
      // Keep the ringing session alive while the recipient app is backgrounded,
      // terminated, or temporarily disconnected. FCM will wake the device.
      if (activeCalls.has(userKey) || activeCalls.has(friendKey) ||
          isUserInGroupCall?.(userKey) || isUserInGroupCall?.(friendKey)) {
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
        callExpiresAt,
        isVideo,
        tag: "incoming-call-" + callId,
      })).catch((error) => {
        console.warn("[Call] Incoming-call notification failed:", error?.message || error);
      });
    }
  });

  socket.on("call_accept", (payload, acknowledge) => {
    const respond = (result) => {
      if (typeof acknowledge === "function") acknowledge(result);
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "You are not authenticated." });
    const to = toDisplayName(payload?.to);
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    if (!to || !callId) {
      return respond({ ok: false, message: "Missing caller or call ID." });
    }

    const friendKey = normalizeName(to);
    const active = activeCalls.get(userKey);
    // Only the invited recipient may accept, and only while the pair is
    // genuinely ringing. This prevents a late/replayed accept from reviving
    // an ended call or making the caller display a connected call UI.
    if (!active || active.peerKey !== friendKey || active.callId !== callId ||
        active.status !== "ringing" || active.callerKey !== friendKey) {
      return respond({ ok: false, message: "This call is no longer ringing." });
    }
    const me = users.get(userKey);
    const caller = users.get(friendKey);
    if (me?.callsEnabled === false || caller?.callsEnabled === false) {
      cancelCallForUser(userKey, deps, "Calls are disabled in this status mode.");
      return respond({ ok: false, message: "Calls are disabled in this status mode." });
    }
    const friendSocketId = onlineUsers.get(friendKey);
    if (!friendSocketId) {
      expireRingingCall(friendKey, userKey, callId, active.type === "video");
      return respond({ ok: false, message: "The caller is no longer available." });
    }
    clearRingingTimer(callId);
    setCallPair(userKey, friendKey, "connected", callId);
    console.log(`[Call] Call accepted by ${userKey} for ${friendKey} (socket: ${friendSocketId})`);
    io.to(friendSocketId).emit("call_accepted", { from: userKey, callId });
    respond({ ok: true, callId, status: "connected" });
  });

  socket.on("call_check", (payload, acknowledge) => {
    if (typeof acknowledge !== "function") return;
    const userKey = socket.data.userKey;
    if (!userKey) {
      acknowledge({ active: false });
      return;
    }
    const peerKey = normalizeName(toDisplayName(payload?.to));
    const callId = toDisplayName(payload?.callId).slice(0, 128);
    const active = activeCalls.get(userKey);
    const isActive = Boolean(
      peerKey && callId && active && active.peerKey === peerKey &&
      active.callId === callId &&
      (active.status === "ringing" || active.status === "connected")
    );
    acknowledge({
      callId,
      active: isActive,
      status: isActive ? active.status : "ended",
    });
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
        // Determine the call direction from the authenticated call record,
        // never from a client supplied reason string. Only the callee can
        // receive a missed-call notification; a caller who hangs up while
        // ringing must not be told that they missed their own call.
        const callerKey = normalizeName(active.callerKey || friendKey);
        const calleeKey = callerKey === userKey ? friendKey : userKey;
        const caller = users.get(callerKey);
        const receiver = users.get(calleeKey);
        const entry = {
          callId,
          callerId: caller?.username || callerKey,
          receiverId: receiver?.username || calleeKey,
          type: active.type || "voice",
          status: "missed",
          duration: 0,
          createdAt: new Date().toISOString(),
        };
        recordCallLog?.(calleeKey, entry);
        const missedCaller = users.get(callerKey);
        const missedName = missedCaller?.username || callerKey;
        if (userKey === calleeKey) {
          // The callee declined from the app or its incoming-call alert.
          // Clear that alert without posting a missed-call alert to the caller.
          Promise.resolve(sendPushToUser?.(calleeKey, {
            type: "call", callStatus: "ended", callId, chat: missedName, isVideo: active.type === "video",
          })).catch(() => {});
        } else {
          Promise.resolve(sendPushToUser?.(calleeKey, {
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

  // Only participants in the same connected call may negotiate a voice-to-video upgrade.
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
    if (peerSocketId) io.to(peerSocketId).emit("call_media_upgrade_request", {
      from: users.get(userKey)?.username || userKey, callId,
    });
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
    if (peerSocketId) io.to(peerSocketId).emit("call_media_upgrade_response", {
      from: users.get(userKey)?.username || userKey,
      callId, accepted: payload?.accepted === true,
    });
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
        from: users.get(userKey)?.username || userKey,
        callId,
        streamId,
        replacesVideoTrack: streamId != null && payload?.replacesVideoTrack === true,
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

module.exports = { registerCallHandlers, cancelCallForUser };
