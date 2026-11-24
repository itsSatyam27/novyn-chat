"use strict";

const crypto = require("crypto");

const ROLE_SETS = Object.freeze({
  3: ["raja", "sipahi", "chor"],
  4: ["raja", "mantri", "sipahi", "chor"],
});

function shuffle(values, random = Math.random) {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const other = Math.floor(random() * (index + 1));
    [result[index], result[other]] = [result[other], result[index]];
  }
  return result;
}

function createRajaMantriGameSession({
  sessionId = crypto.randomUUID(),
  playerCount,
  players,
  totalRounds = 5,
  random = Math.random,
} = {}) {
  const count = Number(playerCount);
  if (![3, 4].includes(count) || !Array.isArray(players) || players.length !== count) {
    throw new TypeError("A Raja Mantri match requires exactly three or four players.");
  }
  const normalizedPlayers = players.map((player, index) => ({
    username: String(player.username || "").trim().toLowerCase(),
    displayName: String(player.displayName || player.username || `Player ${index + 1}`).trim(),
    isBot: player.isBot === true,
    score: 0,
    roundDelta: 0,
    role: null,
    roleRevealed: false,
    picked: player.isBot === true,
  }));
  if (normalizedPlayers.some((player) => !player.username)) {
    throw new TypeError("Each Raja Mantri player needs a username or bot id.");
  }
  const unique = new Set(normalizedPlayers.map((player) => player.username));
  if (unique.size !== normalizedPlayers.length) {
    throw new TypeError("Raja Mantri player usernames must be unique.");
  }
  const host = normalizedPlayers.find((player) => !player.isBot);
  if (!host) throw new TypeError("A Raja Mantri room must have a human host.");

  const session = {
    sessionId,
    playerCount: count,
    totalRounds: Math.max(1, Math.min(20, Number(totalRounds) || 5)),
    round: 1,
    phase: "picking",
    hostUsername: host.username,
    players: normalizedPlayers,
    sipahiUsername: "",
    lastResult: null,
    random,
    createdAt: Date.now(),
  };
  assignRoundRoles(session);
  return session;
}

function assignRoundRoles(session) {
  const roles = shuffle(ROLE_SETS[session.playerCount], session.random);
  session.players.forEach((player, index) => {
    player.role = roles[index];
    player.roleRevealed = false;
    player.picked = player.isBot;
    player.roundDelta = 0;
  });
  session.sipahiUsername = "";
  session.lastResult = null;
  session.phase = "picking";
  if (session.players.every((player) => player.picked)) beginGuessing(session);
}

function beginGuessing(session) {
  session.phase = "guessing";
  const raja = session.players.find((player) => player.role === "raja");
  if (session.playerCount === 4 && raja) raja.roleRevealed = true;
  const sipahi = session.players.find((player) => player.role === "sipahi");
  session.sipahiUsername = sipahi?.username || "";
}

function pickRajaMantriChit(session, username) {
  const userKey = String(username || "").trim().toLowerCase();
  const player = session?.players.find((entry) => entry.username === userKey);
  if (!session || session.phase !== "picking") return { ok: false, reason: "This round is no longer accepting picks." };
  if (!player || player.isBot) return { ok: false, reason: "You are not an active player in this match." };
  if (player.picked) return { ok: false, reason: "You have already picked your chit." };
  player.picked = true;
  player.roleRevealed = true;
  if (session.players.every((entry) => entry.picked)) beginGuessing(session);
  return { ok: true, session };
}

function guessRajaMantriChor(session, username, suspectUsername) {
  const userKey = String(username || "").trim().toLowerCase();
  const suspectKey = String(suspectUsername || "").trim().toLowerCase();
  if (!session || session.phase !== "guessing") return { ok: false, reason: "The Sipahi is not ready to guess yet." };
  if (userKey !== session.sipahiUsername) return { ok: false, reason: "Only the Sipahi can choose a suspect." };
  const guesser = session.players.find((player) => player.username === userKey);
  const suspect = session.players.find((player) => player.username === suspectKey);
  if (!guesser || !suspect || suspect.username === userKey) {
    return { ok: false, reason: "Choose another player from this room." };
  }
  const allowedRoles = session.playerCount === 3
    ? new Set(["raja", "chor"])
    : new Set(["chor", "mantri"]);
  if (!allowedRoles.has(suspect.role)) {
    return { ok: false, reason: "That player is not a valid suspect." };
  }

  const raja = session.players.find((player) => player.role === "raja");
  const sipahi = session.players.find((player) => player.role === "sipahi");
  const chor = session.players.find((player) => player.role === "chor");
  const mantri = session.players.find((player) => player.role === "mantri");
  const correct = suspect.role === "chor";

  if (raja) raja.roundDelta = 1000;
  if (session.playerCount === 3) {
    if (correct) {
      if (sipahi) sipahi.roundDelta = 500;
      if (chor) chor.roundDelta = 0;
    } else {
      if (sipahi) sipahi.roundDelta = 0;
      if (chor) chor.roundDelta = 500;
    }
  } else if (correct) {
    if (sipahi) sipahi.roundDelta = 500;
    if (mantri) mantri.roundDelta = 800;
    if (chor) chor.roundDelta = 0;
  } else {
    if (sipahi) sipahi.roundDelta = 0;
    if (mantri) mantri.roundDelta = 800;
    if (chor) chor.roundDelta = 500;
  }

  for (const player of session.players) {
    player.score += player.roundDelta;
    player.roleRevealed = true;
  }
  session.phase = "result";
  session.lastResult = {
    guesserUsername: guesser.username,
    suspectUsername: suspect.username,
    suspectRole: suspect.role,
    correct,
    round: session.round,
  };
  return { ok: true, session };
}

function advanceRajaMantriRound(session, username) {
  const userKey = String(username || "").trim().toLowerCase();
  if (!session || session.phase !== "result" || userKey !== session.hostUsername) {
    return { ok: false, reason: "Only the host can continue to the next round." };
  }
  if (session.round >= session.totalRounds) {
    session.phase = "finished";
    return { ok: true, session };
  }
  session.round += 1;
  assignRoundRoles(session);
  return { ok: true, session };
}

function getRajaMantriGameView(session, username) {
  if (!session) return null;
  const userKey = String(username || "").trim().toLowerCase();
  const me = session.players.find((player) => player.username === userKey);
  if (!me) return null;
  return {
    sessionId: session.sessionId,
    playerCount: session.playerCount,
    round: session.round,
    totalRounds: session.totalRounds,
    phase: session.phase,
    hostUsername: session.hostUsername,
    sipahiUsername: session.phase === "guessing" || session.phase === "result" || session.phase === "finished"
      ? session.sipahiUsername
      : "",
    myRole: me.role,
    myPicked: me.picked,
    isHost: userKey === session.hostUsername,
    lastResult: session.lastResult ? { ...session.lastResult } : null,
    players: session.players.map((player) => ({
      username: player.username,
      displayName: player.displayName,
      score: player.score,
      roundDelta: player.roundDelta,
      role: player.username === userKey || player.roleRevealed ? player.role : null,
      roleRevealed: player.roleRevealed,
      picked: player.picked,
      isBot: player.isBot,
    })),
  };
}

module.exports = {
  createRajaMantriGameSession,
  pickRajaMantriChit,
  guessRajaMantriChor,
  advanceRajaMantriRound,
  getRajaMantriGameView,
};
