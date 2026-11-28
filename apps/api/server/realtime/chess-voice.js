"use strict";

const DEFAULT_SESSION_TTL_MS = 2 * 60 * 60 * 1000;

class ChessVoiceRegistry {
  constructor({ createId, ttlMs = DEFAULT_SESSION_TTL_MS } = {}) {
    this._createId = createId || (() => require("node:crypto").randomUUID());
    this._ttlMs = ttlMs;
    this._byMatch = new Map();
    this._byRoom = new Map();
  }

  _remove(session) {
    if (!session) return;
    this._byMatch.delete(session.matchKey);
    this._byRoom.delete(session.roomId);
  }

  _get(roomId) {
    const session = this._byRoom.get(String(roomId || ""));
    if (!session) return null;
    if (session.expiresAt <= Date.now()) {
      this._remove(session);
      return null;
    }
    return session;
  }

  join(matchKey, userKey, peerKey) {
    const key = String(matchKey || "").trim();
    const user = String(userKey || "").trim().toLowerCase();
    const peer = String(peerKey || "").trim().toLowerCase();
    if (!key || !user || !peer || user === peer) {
      return { ok: false, message: "Invalid Chess voice match." };
    }

    let session = this._byMatch.get(key);
    if (session && session.expiresAt <= Date.now()) {
      this._remove(session);
      session = null;
    }
    const players = [user, peer].sort();
    if (session && (session.players[0] !== players[0] ||
        session.players[1] !== players[1])) {
      return { ok: false, message: "This Chess voice room belongs to another match." };
    }
    if (!session) {
      session = {
        roomId: this._createId(),
        matchKey: key,
        players,
        joined: new Set(),
        expiresAt: Date.now() + this._ttlMs,
      };
      this._byMatch.set(key, session);
      this._byRoom.set(session.roomId, session);
    }

    const wasJoined = session.joined.has(user);
    session.joined.add(user);
    session.expiresAt = Date.now() + this._ttlMs;
    const ready = session.joined.has(peer);
    return {
      ok: true,
      roomId: session.roomId,
      peerUsername: peer,
      peerReady: ready,
      peerJoinedNow: ready && !wasJoined,
      initiator: user.localeCompare(peer) < 0,
    };
  }

  authorizeSignal(roomId, userKey) {
    const session = this._get(roomId);
    const user = String(userKey || "").trim().toLowerCase();
    if (!session || !session.joined.has(user) || session.joined.size !== 2) {
      return { ok: false };
    }
    const peerUsername = session.players.find((player) => player !== user);
    session.expiresAt = Date.now() + this._ttlMs;
    return { ok: true, peerUsername };
  }

  leave(roomId, userKey) {
    const session = this._get(roomId);
    const user = String(userKey || "").trim().toLowerCase();
    if (!session || !session.players.includes(user)) return null;
    session.joined.delete(user);
    const peerUsername = session.players.find((player) => player !== user);
    const peerStillJoined = session.joined.has(peerUsername);
    if (session.joined.size === 0) this._remove(session);
    else session.expiresAt = Date.now() + this._ttlMs;
    return { roomId: session.roomId, peerUsername, peerStillJoined };
  }

  disconnect(userKey) {
    const user = String(userKey || "").trim().toLowerCase();
    const left = [];
    for (const session of Array.from(this._byRoom.values())) {
      if (!session.joined.has(user)) continue;
      const result = this.leave(session.roomId, user);
      if (result) left.push(result);
    }
    return left;
  }

  get size() {
    return this._byRoom.size;
  }
}

module.exports = { ChessVoiceRegistry };
