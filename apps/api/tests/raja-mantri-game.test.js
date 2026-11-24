"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createRajaMantriGameSession,
  pickRajaMantriChit,
  autoPickRajaMantriChit,
  setRajaMantriPlayerConnected,
  guessRajaMantriChor,
  advanceRajaMantriRound,
  getRajaMantriGameView,
} = require("../server/realtime/raja-mantri-game");

function makeSession(playerCount, random = () => 0.17) {
  return createRajaMantriGameSession({
    sessionId: "rm-session",
    playerCount,
    random,
    players: Array.from({ length: playerCount }, (_, index) => ({
      username: `user${index + 1}`,
      displayName: `User ${index + 1}`,
    })),
  });
}

function pickAll(session) {
  for (const player of session.players) {
    assert.equal(pickRajaMantriChit(session, player.username).ok, true);
  }
  assert.equal(session.phase, "guessing");
}

test("three-player sessions assign Raja, Sipahi and Chor and keep other roles private", () => {
  const session = makeSession(3);
  assert.equal(session.players.length, 3);
  assert.deepEqual(new Set(session.players.map((player) => player.role)), new Set(["raja", "sipahi", "chor"]));
  pickAll(session);
  const view = getRajaMantriGameView(session, "user1");
  assert.equal(view.players.length, 3);
  assert.equal(view.players.find((player) => player.username === "user1").role, session.players[0].role);
  const unseen = view.players.filter((player) => player.username !== "user1");
  assert.ok(unseen.every((player) => player.role === null));
});

test("four-player sessions reveal Raja once every player has picked", () => {
  const session = makeSession(4);
  pickAll(session);
  const view = getRajaMantriGameView(session, "user1");
  const raja = view.players.find((player) => player.role === "raja");
  assert.ok(raja);
  assert.equal(raja.roleRevealed, true);
  assert.equal(view.players.length, 4);
});

test("only the Sipahi may guess and three-player scoring stays within its three roles", () => {
  const session = makeSession(3);
  pickAll(session);
  const sipahi = session.players.find((player) => player.role === "sipahi");
  const chor = session.players.find((player) => player.role === "chor");
  const wrongUser = session.players.find((player) => player.role !== "sipahi");
  assert.equal(guessRajaMantriChor(session, wrongUser.username, chor.username).ok, false);
  const result = guessRajaMantriChor(session, sipahi.username, chor.username);
  assert.equal(result.ok, true);
  assert.equal(session.phase, "result");
  assert.equal(session.players.find((player) => player.role === "raja").roundDelta, 1000);
  assert.equal(sipahi.roundDelta, 500);
  assert.equal(chor.roundDelta, 0);
});

test("wrong suspect gives the three-player Chor points and four-player classic scoring is preserved", () => {
  const three = makeSession(3);
  pickAll(three);
  const sipahi3 = three.players.find((player) => player.role === "sipahi");
  const raja3 = three.players.find((player) => player.role === "raja");
  const chor3 = three.players.find((player) => player.role === "chor");
  assert.equal(guessRajaMantriChor(three, sipahi3.username, raja3.username).ok, true);
  assert.equal(raja3.roundDelta, 1000);
  assert.equal(sipahi3.roundDelta, 0);
  assert.equal(chor3.roundDelta, 500);

  const four = makeSession(4);
  pickAll(four);
  const sipahi4 = four.players.find((player) => player.role === "sipahi");
  const mantri4 = four.players.find((player) => player.role === "mantri");
  const chor4 = four.players.find((player) => player.role === "chor");
  assert.equal(guessRajaMantriChor(four, sipahi4.username, mantri4.username).ok, true);
  assert.equal(mantri4.roundDelta, 800);
  assert.equal(chor4.roundDelta, 500);
});

test("only host advances result rounds and five rounds finish the match", () => {
  const session = makeSession(3);
  for (let round = 1; round <= 5; round += 1) {
    pickAll(session);
    const sipahi = session.players.find((player) => player.role === "sipahi");
    const chor = session.players.find((player) => player.role === "chor");
    assert.equal(guessRajaMantriChor(session, sipahi.username, chor.username).ok, true);
    if (round < 5) {
      assert.equal(advanceRajaMantriRound(session, "user2").ok, false);
      assert.equal(advanceRajaMantriRound(session, session.hostUsername).ok, true);
      assert.equal(session.round, round + 1);
    }
  }
  assert.equal(advanceRajaMantriRound(session, session.hostUsername).ok, true);
  assert.equal(session.phase, "finished");
});

test("a bot Sipahi automatically resolves the round after all human picks", () => {
  const session = createRajaMantriGameSession({
    sessionId: "rm-bots",
    playerCount: 3,
    random: () => 0.9,
    players: [
      { username: "host", displayName: "Host" },
      { username: "bot-1", displayName: "Bot 1", isBot: true },
      { username: "bot-2", displayName: "Bot 2", isBot: true },
    ],
  });
  const host = session.players.find((player) => player.username === "host");
  assert.equal(pickRajaMantriChit(session, host.username).ok, true);
  assert.equal(session.phase, "result");
  assert.ok(session.lastResult);
});


test("an offline player is auto-controlled and auto-picked after the response window", () => {
  const session = makeSession(3);
  const offline = session.players.find((player) => player.username === "user2");
  assert.equal(setRajaMantriPlayerConnected(session, offline.username, false).ok, true);
  assert.equal(offline.autoControlled, true);
  assert.equal(offline.isConnected, false);
  assert.equal(autoPickRajaMantriChit(session, offline.username).ok, true);
  assert.equal(offline.picked, true);
  assert.equal(offline.autoPicked, true);
});

test("auto-picking the final unresponsive player starts the Sipahi phase", () => {
  const session = makeSession(3);
  const [first, second, third] = session.players;
  assert.equal(pickRajaMantriChit(session, first.username).ok, true);
  assert.equal(autoPickRajaMantriChit(session, second.username).ok, true);
  assert.equal(autoPickRajaMantriChit(session, third.username).ok, true);
  assert.equal(session.phase, "guessing");
  assert.ok(session.responseDeadlineAt > Date.now());
});

test("an offline Sipahi is replaced by bot control and the round resolves", () => {
  const session = makeSession(3);
  pickAll(session);
  const sipahi = session.players.find((player) => player.role === "sipahi");
  assert.equal(setRajaMantriPlayerConnected(session, sipahi.username, false).ok, true);
  assert.equal(session.phase, "result");
  assert.equal(session.lastResult.autoPlayed, true);
});

test("a reconnected player regains control for the next round", () => {
  const session = makeSession(3);
  const player = session.players[1];
  assert.equal(setRajaMantriPlayerConnected(session, player.username, false).ok, true);
  assert.equal(setRajaMantriPlayerConnected(session, player.username, true).ok, true);
  assert.equal(player.autoControlled, false);
  assert.equal(player.isConnected, true);
});
