'use strict';

const MAX_GROUP_CALL_PARTICIPANTS = 4;
const GROUP_CALL_INVITE_TTL_MS = 45_000;

function createGroupCallRegistry() {
  return {
    sessions: new Map(),
    userSessions: new Map(),
  };
}

function registerGroupCallHandlers(socket, deps) {
  const {
    registry,
    users,
    normalizeName,
    toDisplayName,
    onlineUsers,
    io,
    activeCalls,
    clearCallPair,
    usersAreBlocked,
    sendPushToUser,
    allowSocketAction,
  } = deps;
  const scheduleInviteTimeout = deps.scheduleInviteTimeout || ((callback, delay) => {
    const timer = setTimeout(callback, delay);
    timer.unref?.();
    return timer;
  });
  const clearInviteTimeout = deps.clearInviteTimeout || clearTimeout;

  if (!registry?.sessions || !registry?.userSessions) {
    throw new TypeError('A group-call registry is required.');
  }

  const userKey = normalizeName(socket.data?.userKey || '');
  if (!userKey) return;

  const safeName = (value) => toDisplayName(value).slice(0, 128);
  const displayName = (key) => {
    const user = users.get(key);
    return user?.displayName || user?.username || key;
  };
  const participantView = (key) => ({
    username: users.get(key)?.username || key,
    displayName: displayName(key),
  });
  const emitUser = (key, event, payload) => {
    const socketId = onlineUsers.get(key);
    if (socketId) io.to(socketId).emit(event, payload);
  };
  const emitSession = (session, event, payload, exceptKey = null) => {
    for (const key of session.participants) {
      if (key !== exceptKey) emitUser(key, event, payload);
    }
  };
  const sessionView = (session) => ({
    groupCallId: session.groupCallId,
    callId: session.callId,
    isVideo: session.isVideo,
    createdBy: users.get(session.createdBy)?.username || session.createdBy,
    participants: Array.from(session.participants, participantView),
    mediaStates: Object.fromEntries(
      Array.from(session.mediaStates.entries()).map(([key, state]) => [
        users.get(key)?.username || key,
        { audioEnabled: state.audioEnabled, videoEnabled: state.videoEnabled },
      ]),
    ),
    screenSharer: session.screenSharer
      ? users.get(session.screenSharer)?.username || session.screenSharer
      : null,
    screenStreamId: session.screenStreamId || null,
    pendingInvitations: Array.from(session.pending.entries(), ([key, invite]) => ({
      username: users.get(key)?.username || key,
      displayName: displayName(key),
      invitedBy: users.get(invite.invitedBy)?.username || invite.invitedBy,
      expiresAt: invite.expiresAt,
    })),
    capacity: MAX_GROUP_CALL_PARTICIPANTS,
  });
  const respond = (ack, result) => {
    if (typeof ack === 'function') ack(result);
  };
  const getSession = (payload) => {
    const id = safeName(payload?.groupCallId || payload?.callId);
    if (!id) return null;
    const session = registry.sessions.get(id);
    return session && session.participants.has(userKey) ? session : null;
  };
  const clearInviteTimer = (invite) => {
    if (invite?.timer) {
      clearInviteTimeout(invite.timer);
      invite.timer = null;
    }
  };
  const expirePendingInvite = (session, inviteeKey, expectedInvite = null) => {
    const invite = session.pending.get(inviteeKey);
    if (!invite || (expectedInvite && invite !== expectedInvite)) return false;
    session.pending.delete(inviteeKey);
    clearInviteTimer(invite);
    emitSession(session, 'group_call_invitation_expired', {
      groupCallId: session.groupCallId,
      callId: session.callId,
      username: users.get(inviteeKey)?.username || inviteeKey,
      displayName: displayName(inviteeKey),
      invitedBy: users.get(invite.invitedBy)?.username || invite.invitedBy,
      status: 'no_answer',
    });
    return true;
  };
  const cleanupPending = (session) => {
    const now = Date.now();
    for (const [invitee, invite] of session.pending.entries()) {
      if (invite.expiresAt <= now) expirePendingInvite(session, invitee, invite);
    }
  };
  const canInvite = (inviterKey, inviteeKey) => {
    const inviter = users.get(inviterKey);
    const invitee = users.get(inviteeKey);
    if (!inviter || !invitee || !invitee.isRegistered) {
      return 'This user is unavailable.';
    }
    if (inviterKey === inviteeKey) return 'You cannot add yourself.';
    if (inviter.callsEnabled === false || invitee.callsEnabled === false) {
      return 'This user is not accepting calls right now.';
    }
    if (usersAreBlocked?.(inviterKey, inviteeKey)) {
      return 'This user is not accepting calls from you.';
    }
    const areFriends = Boolean(inviter.friends?.has(inviteeKey));
    if (invitee.callPrivacy === 'nobody' ||
        (invitee.callPrivacy !== 'everyone' && !areFriends)) {
      return 'This user is not accepting calls from you.';
    }
    return null;
  };
  const sendGroupInvitation = (session, inviteeKey, invitedByKey) => {
    const expiresAt = Date.now() + GROUP_CALL_INVITE_TTL_MS;
    const invite = { invitedBy: invitedByKey, expiresAt, timer: null };
    session.pending.set(inviteeKey, invite);
    invite.timer = scheduleInviteTimeout(() => {
      expirePendingInvite(session, inviteeKey, invite);
    }, GROUP_CALL_INVITE_TTL_MS);
    const invitation = {
      ...sessionView(session),
      invitedBy: users.get(invitedByKey)?.username || invitedByKey,
      invitedByDisplayName: displayName(invitedByKey),
      expiresAt,
    };
    emitUser(inviteeKey, 'group_call_invitation', invitation);
    Promise.resolve(sendPushToUser?.(inviteeKey, {
      type: 'call',
      callStatus: 'incoming',
      title: session.isVideo ? 'Incoming group video call' : 'Incoming group voice call',
      body: displayName(invitedByKey) + ' invited you to a group call',
      chat: users.get(invitedByKey)?.username || invitedByKey,
      kind: 'friend',
      callId: session.callId,
      groupCallId: session.groupCallId,
      groupCall: true,
      isVideo: session.isVideo,
      tag: 'group-call-' + session.groupCallId,
      callExpiresAt: expiresAt,
    })).catch((error) => {
      console.warn('[GroupCall] Invitation push failed:', error?.message || error);
    });
    return {
      ok: true,
      username: users.get(inviteeKey)?.username || inviteeKey,
      displayName: displayName(inviteeKey),
      invitedBy: users.get(invitedByKey)?.username || invitedByKey,
      expiresAt,
      remainingSlots: MAX_GROUP_CALL_PARTICIPANTS - session.participants.size - session.pending.size,
    };
  };
  const endSession = (session, reason) => {
    if (!registry.sessions.has(session.groupCallId)) return;
    registry.sessions.delete(session.groupCallId);
    for (const key of session.participants) {
      if (registry.userSessions.get(key) === session.groupCallId) {
        registry.userSessions.delete(key);
      }
      emitUser(key, 'group_call_ended', {
        groupCallId: session.groupCallId,
        callId: session.callId,
        reason: reason || 'The group call has ended.',
      });
    }
    for (const invite of session.pending.values()) clearInviteTimer(invite);
    session.pending.clear();
  };
  const removeParticipant = (session, participantKey, reason) => {
    if (!session.participants.delete(participantKey)) return;
    if (registry.userSessions.get(participantKey) === session.groupCallId) {
      registry.userSessions.delete(participantKey);
    }
    session.mediaStates.delete(participantKey);
    if (session.screenSharer === participantKey) {
      session.screenSharer = null;
      session.screenStreamId = null;
      emitSession(session, 'group_call_screen_share_state', {
        groupCallId: session.groupCallId,
        username: users.get(participantKey)?.username || participantKey,
        streamId: null,
      });
    }
    emitSession(session, 'group_call_participant_left', {
      groupCallId: session.groupCallId,
      callId: session.callId,
      participant: users.get(participantKey)?.username || participantKey,
      reason: reason || 'left',
      participants: Array.from(session.participants, participantView),
    });
    if (session.participants.size < 2) {
      endSession(session, 'The group call ended because fewer than two people remain.');
    }
  };

  socket.on('group_call_promote', (payload, ack) => {
    const callId = safeName(payload?.callId);
    if (!callId) return respond(ack, { ok: false, message: 'Missing call ID.' });

    const current = registry.userSessions.get(userKey);
    if (current) {
      const existing = registry.sessions.get(current);
      if (existing?.callId === callId && existing.participants.has(userKey)) {
        const rawInvitees = Array.isArray(payload?.invitees) ? payload.invitees : [];
        cleanupPending(existing);
        const requested = rawInvitees.map((value) => normalizeName(safeName(value)));
        const newInvitees = requested.filter((key) => !existing.pending.has(key));
        if (newInvitees.length > MAX_GROUP_CALL_PARTICIPANTS - existing.participants.size - existing.pending.size) {
          return respond(ack, { ok: false, message: 'There are not enough open places in this call.' });
        }
        if (requested.some((key) => !key) || new Set(requested).size !== requested.length) {
          return respond(ack, { ok: false, message: 'Choose valid, unique contacts.' });
        }
        if (allowSocketAction && requested.length > 0 &&
            !allowSocketAction(socket, 'group_call_invite', 5, 60_000)) {
          return respond(ack, { ok: false, message: 'Too many invitations. Try again shortly.' });
        }
        for (const inviteeKey of requested) {
          if (existing.participants.has(inviteeKey)) {
            return respond(ack, { ok: false, message: 'This person is already in the call.' });
          }
          if (existing.pending.has(inviteeKey)) continue;
          const denial = canInvite(userKey, inviteeKey);
          if (denial) return respond(ack, { ok: false, message: denial });
          if (registry.userSessions.has(inviteeKey) || activeCalls.has(inviteeKey)) {
            return respond(ack, { ok: false, message: 'This person is already in another call.' });
          }
        }
        const invitations = requested.map((inviteeKey) => {
          const pending = existing.pending.get(inviteeKey);
          return pending
            ? {
                ok: true,
                username: users.get(inviteeKey)?.username || inviteeKey,
                displayName: displayName(inviteeKey),
                invitedBy: users.get(pending.invitedBy)?.username || pending.invitedBy,
                expiresAt: pending.expiresAt,
                remainingSlots: MAX_GROUP_CALL_PARTICIPANTS - existing.participants.size - existing.pending.size,
              }
            : sendGroupInvitation(existing, inviteeKey, userKey);
        });
        const view = sessionView(existing);
        emitSession(existing, 'group_call_promoted', view);
        return respond(ack, { ok: true, ...view, invitations });
      }
      return respond(ack, { ok: false, message: 'You are already in another group call.' });
    }

    const active = activeCalls.get(userKey);
    const peerKey = active?.peerKey;
    const peer = peerKey ? activeCalls.get(peerKey) : null;
    if (!active || active.callId !== callId || active.status !== 'connected' ||
        !peer || peer.peerKey !== userKey || peer.callId !== callId ||
        peer.status !== 'connected' ||
        registry.userSessions.has(userKey) || registry.userSessions.has(peerKey)) {
      return respond(ack, { ok: false, message: 'Only a connected one-to-one call can be expanded.' });
    }

    const rawInvitees = Array.isArray(payload?.invitees) ? payload.invitees : [];
    if (rawInvitees.length > MAX_GROUP_CALL_PARTICIPANTS - 2) {
      return respond(ack, { ok: false, message: 'You can add up to two people to this call.' });
    }
    const inviteeKeys = rawInvitees.map((value) => normalizeName(safeName(value)));
    if (inviteeKeys.some((key) => !key) || new Set(inviteeKeys).size !== inviteeKeys.length) {
      return respond(ack, { ok: false, message: 'Choose valid, unique contacts.' });
    }
    if (allowSocketAction && inviteeKeys.length > 0 &&
        !allowSocketAction(socket, 'group_call_invite', 5, 60_000)) {
      return respond(ack, { ok: false, message: 'Too many invitations. Try again shortly.' });
    }
    for (const inviteeKey of inviteeKeys) {
      if (inviteeKey === peerKey) {
        return respond(ack, { ok: false, message: 'This person is already in the call.' });
      }
      const denial = canInvite(userKey, inviteeKey);
      if (denial) return respond(ack, { ok: false, message: denial });
      if (registry.userSessions.has(inviteeKey) || activeCalls.has(inviteeKey)) {
        return respond(ack, { ok: false, message: 'This person is already in another call.' });
      }
    }

    const groupCallId = 'group-' + callId;
    const session = {
      groupCallId,
      callId,
      createdBy: userKey,
      isVideo: payload?.isVideo === true || active.type === 'video',
      participants: new Set([userKey, peerKey]),
      pending: new Map(),
      mediaStates: new Map(),
      createdAt: Date.now(),
      screenSharer: null,
      screenStreamId: null,
    };
    registry.sessions.set(groupCallId, session);
    // The legacy direct-call lock is no longer authoritative once the group
    // registry owns this session. Clear it for both original callers so they
    // can leave the group cleanly and start another call afterward.
    clearCallPair?.(userKey);
    registry.userSessions.set(userKey, groupCallId);
    registry.userSessions.set(peerKey, groupCallId);
    const invitations = inviteeKeys.map((inviteeKey) =>
      sendGroupInvitation(session, inviteeKey, userKey));

    const view = sessionView(session);
    emitSession(session, 'group_call_promoted', view);
    respond(ack, { ok: true, ...view, invitations });
  });

  socket.on('group_call_invite', (payload, ack) => {
    const session = getSession(payload);
    if (!session) return respond(ack, { ok: false, message: 'You are not a participant in this call.' });
    if (allowSocketAction && !allowSocketAction(socket, 'group_call_invite', 5, 60_000)) {
      return respond(ack, { ok: false, message: 'Too many invitations. Try again shortly.' });
    }

    cleanupPending(session);
    const inviteeKey = normalizeName(safeName(payload?.to));
    if (!inviteeKey) return respond(ack, { ok: false, message: 'Choose a valid contact.' });
    if (session.participants.has(inviteeKey)) {
      return respond(ack, { ok: false, message: 'This person is already in the call.' });
    }
    if (session.pending.has(inviteeKey)) {
      return respond(ack, { ok: false, message: 'An invitation is already pending.' });
    }
    if (session.participants.size + session.pending.size >= MAX_GROUP_CALL_PARTICIPANTS) {
      return respond(ack, { ok: false, message: 'Group calls support up to four people.' });
    }
    const denial = canInvite(userKey, inviteeKey);
    if (denial) return respond(ack, { ok: false, message: denial });
    if (registry.userSessions.has(inviteeKey) || activeCalls.has(inviteeKey)) {
      return respond(ack, { ok: false, message: 'This person is already in another call.' });
    }

    const invitation = sendGroupInvitation(session, inviteeKey, userKey);
    respond(ack, invitation);
  });

  socket.on('group_call_accept', (payload, ack) => {
    const groupCallId = safeName(payload?.groupCallId);
    const session = registry.sessions.get(groupCallId);
    const invitation = session?.pending.get(userKey);
    if (!session || !invitation || invitation.expiresAt <= Date.now()) {
      if (session && invitation) expirePendingInvite(session, userKey, invitation);
      else session?.pending.delete(userKey);
      return respond(ack, { ok: false, message: 'This group call invitation has expired.' });
    }
    cleanupPending(session);
    if (session.pending.get(userKey) !== invitation) {
      return respond(ack, { ok: false, message: 'This group call invitation has expired.' });
    }
    if (registry.userSessions.has(userKey) || activeCalls.has(userKey)) {
      clearInviteTimer(invitation);
      session.pending.delete(userKey);
      emitUser(invitation.invitedBy, 'group_call_invitation_declined', {
        groupCallId,
        username: users.get(userKey)?.username || userKey,
        reason: 'The invited person is already in another call.',
      });
      return respond(ack, { ok: false, message: 'End your current call before joining another.' });
    }
    if (session.participants.size >= MAX_GROUP_CALL_PARTICIPANTS) {
      clearInviteTimer(invitation);
      session.pending.delete(userKey);
      emitUser(invitation.invitedBy, 'group_call_invitation_declined', {
        groupCallId,
        username: users.get(userKey)?.username || userKey,
        reason: 'The group call became full before the invitation was accepted.',
      });
      return respond(ack, { ok: false, message: 'This group call is full.' });
    }
    const denial = canInvite(invitation.invitedBy, userKey);
    if (denial) {
      clearInviteTimer(invitation);
      session.pending.delete(userKey);
      emitUser(invitation.invitedBy, 'group_call_invitation_declined', {
        groupCallId,
        username: users.get(userKey)?.username || userKey,
        reason: denial,
      });
      return respond(ack, { ok: false, message: denial });
    }

    clearInviteTimer(invitation);
    session.pending.delete(userKey);
    session.participants.add(userKey);
    registry.userSessions.set(userKey, groupCallId);
    const joined = {
      ...sessionView(session),
      joinedBy: users.get(userKey)?.username || userKey,
    };
    emitSession(session, 'group_call_participant_joined', joined, userKey);
    socket.emit('group_call_joined', joined);
    // A late joiner needs the existing members' microphone/camera states and
    // any screen currently being shared; those events are not replayed by Socket.IO.
    for (const [participantKey, state] of session.mediaStates.entries()) {
      emitUser(userKey, 'group_call_media_state', {
        groupCallId: session.groupCallId,
        username: users.get(participantKey)?.username || participantKey,
        audioEnabled: state.audioEnabled,
        videoEnabled: state.videoEnabled,
      });
    }
    if (session.screenSharer && session.screenStreamId) {
      emitUser(userKey, 'group_call_screen_share_state', {
        groupCallId: session.groupCallId,
        username: users.get(session.screenSharer)?.username || session.screenSharer,
        streamId: session.screenStreamId,
      });
    }
    respond(ack, { ok: true, ...joined });
  });

  socket.on('group_call_decline', (payload, ack) => {
    const groupCallId = safeName(payload?.groupCallId);
    const session = registry.sessions.get(groupCallId);
    const invitation = session?.pending.get(userKey);
    if (!session || !invitation) {
      return respond(ack, { ok: false, message: 'Invitation not found.' });
    }
    clearInviteTimer(invitation);
    session.pending.delete(userKey);
    emitUser(invitation.invitedBy, 'group_call_invitation_declined', {
      groupCallId,
      username: users.get(userKey)?.username || userKey,
    });
    respond(ack, { ok: true });
  });

  socket.on('group_call_state', (payload, ack) => {
    const session = getSession(payload);
    if (!session) return respond(ack, { ok: false, message: 'Call not found.' });
    respond(ack, { ok: true, ...sessionView(session) });
  });

  socket.on('group_call_signal', (payload) => {
    const session = getSession(payload);
    if (!session) return;
    if (allowSocketAction && !allowSocketAction(socket, 'group_call_signal', 180, 60_000)) return;
    const targetKey = normalizeName(safeName(payload?.to));
    if (!targetKey || targetKey === userKey || !session.participants.has(targetKey)) return;
    const rawSignal = payload?.signal;
    if (!rawSignal || typeof rawSignal !== 'object' || Array.isArray(rawSignal)) return;

    const type = rawSignal.type;
    let signal;
    if (type === 'offer' || type === 'answer') {
      const sdp = typeof rawSignal.sdp === 'string' ? rawSignal.sdp : '';
      if (!sdp || sdp.length > 180_000) return;
      signal = { type, sdp };
    } else if (type === 'candidate') {
      const candidate = typeof rawSignal.candidate === 'string' ? rawSignal.candidate : '';
      const sdpMid = rawSignal.sdpMid == null ? null : safeName(rawSignal.sdpMid);
      const sdpMLineIndex = Number(rawSignal.sdpMLineIndex);
      if (!candidate || candidate.length > 4096 ||
          (sdpMid != null && sdpMid.length > 128) ||
          !Number.isInteger(sdpMLineIndex) || sdpMLineIndex < 0 || sdpMLineIndex > 32) return;
      signal = { type, candidate, sdpMid, sdpMLineIndex };
    } else {
      return;
    }

    emitUser(targetKey, 'group_call_signal', {
      groupCallId: session.groupCallId,
      callId: session.callId,
      from: users.get(userKey)?.username || userKey,
      signal,
    });
  });

  socket.on('group_call_media_state', (payload) => {
    const session = getSession(payload);
    if (!session) return;
    const state = {
      audioEnabled: payload?.audioEnabled !== false,
      videoEnabled: payload?.videoEnabled !== false,
    };
    session.mediaStates.set(userKey, state);
    emitSession(session, 'group_call_media_state', {
      groupCallId: session.groupCallId,
      username: users.get(userKey)?.username || userKey,
      ...state,
    });
  });

  socket.on('group_call_screen_share_state', (payload) => {
    const session = getSession(payload);
    if (!session) return;
    const streamId = payload?.streamId == null ? null : safeName(payload.streamId);
    if (streamId && session.screenSharer && session.screenSharer !== userKey) {
      socket.emit('group_call_screen_share_denied', {
        groupCallId: session.groupCallId,
        reason: 'Another participant is already sharing their screen.',
      });
      return;
    }
    if (streamId) {
      session.screenSharer = userKey;
      session.screenStreamId = streamId;
    } else if (session.screenSharer === userKey) {
      session.screenSharer = null;
      session.screenStreamId = null;
    } else {
      return;
    }
    emitSession(session, 'group_call_screen_share_state', {
      groupCallId: session.groupCallId,
      username: users.get(userKey)?.username || userKey,
      streamId,
    });
  });

  socket.on('group_call_leave', (payload, ack) => {
    const session = getSession(payload);
    if (!session) return respond(ack, { ok: false, message: 'Call not found.' });
    const leftId = session.groupCallId;
    removeParticipant(session, userKey, 'left');
    respond(ack, { ok: true, groupCallId: leftId });
  });

  socket.on('disconnect', () => {
    const currentSocketId = onlineUsers.get(userKey);
    if (currentSocketId && currentSocketId !== socket.id) return;
    const groupCallId = registry.userSessions.get(userKey);
    const session = groupCallId ? registry.sessions.get(groupCallId) : null;
    if (session) removeParticipant(session, userKey, 'disconnected');
  });
}

module.exports = {
  MAX_GROUP_CALL_PARTICIPANTS,
  createGroupCallRegistry,
  registerGroupCallHandlers,
};
