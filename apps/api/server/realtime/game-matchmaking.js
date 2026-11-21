"use strict";
const crypto = require("crypto");
class PublicGameMatchmaking {
  constructor({ timeoutMs = 60_000, onExpired = () => {}, createSessionId = () => crypto.randomUUID() } = {}) {
    this.timeoutMs = timeoutMs; this.onExpired = onExpired; this.createSessionId = createSessionId;
    this.queues = new Map(); this.byUser = new Map();
  }
  join({ userKey, displayName, socketId, gameType }) {
    const user = String(userKey || "").trim().toLowerCase();
    const socket = String(socketId || "").trim();
    const type = String(gameType || "").trim().toLowerCase();
    if (!user || !socket || !["tictactoe", "rps", "connect4", "doodle", "numberclash", "updown"].includes(type)) return { ok: false, message: "Invalid matchmaking request." };
    this.cancel(user);
    const queue = this.queues.get(type) || [];
    const index = queue.findIndex((entry) => entry.userKey !== user);
    if (index >= 0) {
      const opponent = queue.splice(index, 1)[0]; clearTimeout(opponent.timer); this.byUser.delete(opponent.userKey);
      if (queue.length) this.queues.set(type, queue); else this.queues.delete(type);
      return { ok: true, matched: true, sessionId: this.createSessionId(), gameType: type,
        players: [{ userKey: opponent.userKey, displayName: opponent.displayName, socketId: opponent.socketId },
          { userKey: user, displayName: String(displayName || user), socketId: socket }] };
    }
    const entry = { userKey: user, displayName: String(displayName || user), socketId: socket, gameType: type, timer: null };
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
