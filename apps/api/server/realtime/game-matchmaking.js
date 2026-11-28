"use strict";
const crypto = require("crypto");
class PublicGameMatchmaking {
  constructor({ timeoutMs = 60_000, onExpired = () => {}, createSessionId = () => crypto.randomUUID() } = {}) {
    this.timeoutMs = timeoutMs; this.onExpired = onExpired; this.createSessionId = createSessionId;
    this.queues = new Map(); this.byUser = new Map();
  }
  join({ userKey, displayName, socketId, gameType, level, excludedUsers = [] }) {
    const user = String(userKey || "").trim().toLowerCase();
    const socket = String(socketId || "").trim();
    const type = String(gameType || "").trim().toLowerCase();
    const parsedLevel = Number(level);
    const playerLevel = Number.isInteger(parsedLevel) && parsedLevel >= 1 && parsedLevel <= 10_000
      ? parsedLevel
      : null;
    if (!user || !socket || !["tictactoe", "rps"].includes(type)) return { ok: false, message: "Invalid matchmaking request." };
    this.cancel(user);
    const excluded = new Set(
      (Array.isArray(excludedUsers) ? excludedUsers : [])
        .map((value) => String(value || "").trim().toLowerCase())
        .filter(Boolean),
    );
    excluded.add(user);
    const queue = this.queues.get(type) || [];
    // Match only strangers, then prefer the closest known player level.
    // Queue order remains the tie-breaker, so equally skilled players keep
    // FIFO fairness. Missing level metadata falls back to normal queue order.
    let index = -1;
    let bestLevelDistance = Number.POSITIVE_INFINITY;
    for (let candidateIndex = 0; candidateIndex < queue.length; candidateIndex += 1) {
      const entry = queue[candidateIndex];
      if (
        entry.userKey === user ||
        excluded.has(entry.userKey) ||
        entry.excludedUsers.has(user)
      ) {
        continue;
      }
      const hasComparableLevels =
        playerLevel !== null && Number.isInteger(entry.level);
      const levelDistance = hasComparableLevels
        ? Math.abs(playerLevel - entry.level)
        : Number.POSITIVE_INFINITY;
      if (index === -1 || levelDistance < bestLevelDistance) {
        index = candidateIndex;
        bestLevelDistance = levelDistance;
      }
    }
    if (index >= 0) {
      const opponent = queue.splice(index, 1)[0]; clearTimeout(opponent.timer); this.byUser.delete(opponent.userKey);
      if (queue.length) this.queues.set(type, queue); else this.queues.delete(type);
      return { ok: true, matched: true, sessionId: this.createSessionId(), gameType: type,
        players: [
          { userKey: opponent.userKey, displayName: opponent.displayName, socketId: opponent.socketId, level: opponent.level },
          { userKey: user, displayName: String(displayName || user), socketId: socket, level: playerLevel },
        ] };
    }
    const entry = {
      userKey: user,
      displayName: String(displayName || user),
      socketId: socket,
      gameType: type,
      level: playerLevel,
      excludedUsers: excluded,
      timer: null,
    };
    entry.timer = setTimeout(() => { this.removeEntry(entry); this.onExpired({ userKey: user, socketId: socket, gameType: type }); }, this.timeoutMs);
    if (typeof entry.timer.unref === "function") entry.timer.unref();
    queue.push(entry); this.queues.set(type, queue); this.byUser.set(user, entry);
    return { ok: true, matched: false, queued: true, timeoutMs: this.timeoutMs };
  }
  removeEntry(entry) {
    if (!entry) return false; clearTimeout(entry.timer);
    const queue = this.queues.get(entry.gameType) || []; const index = queue.indexOf(entry);
    if (index >= 0) queue.splice(index, 1);
    if (queue.length) this.queues.set(entry.gameType, queue); else this.queues.delete(entry.gameType);
    if (this.byUser.get(entry.userKey) === entry) this.byUser.delete(entry.userKey);
    return index >= 0;
  }
  cancel(userKey) { return this.removeEntry(this.byUser.get(String(userKey || "").trim().toLowerCase())); }
  disconnect(userKey, socketId) {
    const entry = this.byUser.get(String(userKey || "").trim().toLowerCase());
    if (!entry || (socketId && entry.socketId !== socketId)) return false;
    return this.removeEntry(entry);
  }
  get size() { return this.byUser.size; }
}
module.exports = { PublicGameMatchmaking };
