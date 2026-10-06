function createChatAuthorization(deps) {
  const {
    users,
    groups,
    normalizeName,
    normalizeGroupId,
    normalizeChatKind,
    toDisplayName,
    isGroupMember,
    getConversationKey,
    getGroupConversationKey,
  } = deps;

  return function resolveChatTargetForUser(userKey, rawTo, rawType, options = {}) {
    const me = users.get(normalizeName(userKey));
    if (!me) return { ok: false, message: "Account not found." };

    let chatType = normalizeChatKind(rawType);
    const toName = toDisplayName(rawTo);
    const friendKey = normalizeName(toName);
    const possibleGroupId = normalizeGroupId(rawTo);

    if (
      options.inferGroup === true &&
      chatType === "friend" &&
      possibleGroupId &&
      me.groups?.has(possibleGroupId)
    ) {
      chatType = "group";
    }

    if (chatType === "group") {
      const groupId = normalizeGroupId(rawTo);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) {
        return { ok: false, message: "You are not a member of that group." };
      }
      return {
        ok: true,
        type: "group",
        me,
        group,
        targetKey: group.id,
        targetLabel: group.name || group.id,
        conversationKey: getGroupConversationKey(group.id),
      };
    }

    let resolvedFriendKey = friendKey;
    let friend = users.get(resolvedFriendKey);

    // A user may always open their own private Saved Messages conversation.
    // It intentionally does not require adding yourself as a friend.
    if (resolvedFriendKey === normalizeName(userKey) && friend) {
      return {
        ok: true,
        type: "friend",
        me,
        friend,
        isSelf: true,
        targetKey: resolvedFriendKey,
        targetLabel: "Saved Messages",
        conversationKey: getConversationKey(userKey, resolvedFriendKey),
      };
    }

    if ((!friend || !me.friends.has(resolvedFriendKey)) && me.friends instanceof Set) {
      for (const candidateKey of me.friends) {
        const normalizedCandidateKey = normalizeName(candidateKey);
        const candidate = users.get(normalizedCandidateKey);
        if (!candidate) continue;

        const candidateUserKey = normalizeName(candidate.username || normalizedCandidateKey);
        const candidateDisplayKey = normalizeName(candidate.displayName);
        if (candidateUserKey !== friendKey && candidateDisplayKey !== friendKey) continue;

        resolvedFriendKey = normalizedCandidateKey;
        friend = candidate;
        break;
      }
    }

    if (!friend || !me.friends.has(resolvedFriendKey)) {
      return { ok: false, message: "You can message only your friends." };
    }

    return {
      ok: true,
      type: "friend",
      me,
      friend,
      targetKey: resolvedFriendKey,
      targetLabel: friend.username || toName,
      conversationKey: getConversationKey(userKey, resolvedFriendKey),
    };
  };
}

module.exports = { createChatAuthorization };
