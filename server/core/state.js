// Central in-process runtime state.
// Durable state belongs in MongoDB; these maps are intentionally limited to
// live/session/ephemeral state and should not be treated as the database.
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
};
