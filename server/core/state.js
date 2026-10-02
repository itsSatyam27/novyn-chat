// Central in-process runtime state.
// Users and conversations are authoritative in this process and persisted as
// snapshots. This implementation supports one backend process/replica only.
module.exports = {
  users: new Map(),
  onlineUsers: new Map(),
  conversations: new Map(),
  groups: new Map(),
  scheduledMessages: new Map(),
  scheduledMessageTimers: new Map(),
  activeCalls: new Map(),
  passwordResetTokens: new Map(),
  passwordResetByUser: new Map(),
  passwordResetRate: new Map(),
  emailChangeTokens: new Map(),
  emailChangeByUser: new Map(),
  emailChangeRate: new Map(),
  refreshSessions: new Map(),
  refreshByUser: new Map(),
  authUserAliases: new Map(),
  httpRateLimits: new Map(),
  socketRateLimits: new Map(),
};
