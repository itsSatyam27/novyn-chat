"use strict";

const crypto = require("crypto");

class RajaMantriMatchmaking {
  constructor({
    timeoutMs = 60_000,
    createMatchId = () => crypto.randomUUID(),
    onExpired = () => {},
    onProgress = () => {},
  } = {}) {
    this.timeoutMs = timeoutMs;
    this.createMatchId = createMatchId;
    this.onExpired = onExpired;
    this.onProgress = onProgress;
    this.queues = new Map();
    this.byUser = new Map();
  }

  join({ userKey, displayName, socketId, playerCount, excludedUsers = [] }) {
    const user = String(userKey || "").trim().toLowerCase();
    const socket = String(socketId || "").trim();
    const count = Number(playerCount);
    if (!user || !socket || ![3, 4].includes(count)) {
      return { ok: false, message: "Choose a 3-player or 4-player match." };
    }

    this.cancel(user);
    const excluded = new Set(
      (Array.isArray(excludedUsers) ? excludedUsers : [])
        .map((value) => String(value || "").trim().toLowerCase())
        .filter(Boolean),
    );
    excluded.add(user);

    const queue = this.queues.get(count) || [];
    const current = {
      userKey: user,
      displayName: String(displayName || user),
      socketId: socket,
      playerCount: count,
      excludedUsers: excluded,
      joinedAt: Date.now(),
      timer: null,
    };

    const candidates = [...queue, current].sort((a, b) => a.joinedAt - b.joinedAt);
    const group = this._findCompatibleGroup(candidates, count);
    if (group) {
      for (const entry of group) {
        this._removeEntry(entry);
      }
      const remaining = this.queues.get(count) || [];
      this._notifyProgress(count, remaining);
      return {
        ok: true,
        matched: true,
        matchId: this.createMatchId(),
        playerCount: count,
        players: group.map((entry) => ({
          username: entry.userKey,
          displayName: entry.displayName,
          socketId: entry.socketId,
        })),
      };
    }

    current.timer = setTimeout(() => {
      if (!this._removeEntry(current)) return;
      this.onExpired({
        userKey: current.userKey,
        socketId: current.socketId,
        playerCount: current.playerCount,
      });
      this._notifyProgress(count, this.queues.get(count) || []);
    }, this.timeoutMs);
    if (typeof current.timer.unref === "function") current.timer.unref();

    queue.push(current);
    this.queues.set(count, queue);
    this.byUser.set(user, current);
    this._notifyProgress(count, queue);
    return {
      ok: true,
      queued: true,
      playerCount: count,
      playersFound: queue.length,
      timeoutMs: this.timeoutMs,
    };
  }

  _findCompatibleGroup(candidates, targetSize) {
    const chosen = [];
    const search = (start) => {
      if (chosen.length === targetSize) return [...chosen];
      for (let index = start; index < candidates.length; index += 1) {
        const candidate = candidates[index];
        const compatible = chosen.every((member) =>
          !candidate.excludedUsers.has(member.userKey) &&
          !member.excludedUsers.has(candidate.userKey)
        );
        if (!compatible) continue;
        chosen.push(candidate);
        const result = search(index + 1);
        if (result) return result;
        chosen.pop();
      }
      return null;
    };
    return search(0);
  }

  _notifyProgress(playerCount, entries) {
    const progress = {
      playerCount,
      playersFound: entries.length,
      waitingUserKeys: entries.map((entry) => entry.userKey),
    };
    for (const entry of entries) {
      this.onProgress({
        userKey: entry.userKey,
        socketId: entry.socketId,
        ...progress,
      });
    }
  }

  _removeEntry(entry) {
    if (!entry) return false;
    clearTimeout(entry.timer);
    const queue = this.queues.get(entry.playerCount) || [];
    const index = queue.indexOf(entry);
    if (index < 0) return false;
    queue.splice(index, 1);
    if (queue.length) this.queues.set(entry.playerCount, queue);
    else this.queues.delete(entry.playerCount);
    if (this.byUser.get(entry.userKey) === entry) {
      this.byUser.delete(entry.userKey);
    }
    return true;
  }

  cancel(userKey) {
    const entry = this.byUser.get(String(userKey || "").trim().toLowerCase());
    if (!entry) return false;
    const count = entry.playerCount;
    const removed = this._removeEntry(entry);
    if (removed) this._notifyProgress(count, this.queues.get(count) || []);
    return removed;
  }

  disconnect(userKey, socketId) {
    const entry = this.byUser.get(String(userKey || "").trim().toLowerCase());
    if (!entry || (socketId && entry.socketId !== socketId)) return false;
    const count = entry.playerCount;
    const removed = this._removeEntry(entry);
    if (removed) this._notifyProgress(count, this.queues.get(count) || []);
    return removed;
  }

  get size() {
    return this.byUser.size;
  }
}

module.exports = { RajaMantriMatchmaking };
