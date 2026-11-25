const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildGameLeaderboard,
  buildGameLeaderboardFromAggregates,
  buildMongoGameLeaderboardPipeline,
  normalizeLeaderboardGame,
} = require("../game-leaderboard");

function account(username) {
  return { username, displayName: username.toUpperCase(), isRegistered: true };
}

test("normalizes leaderboard game filters and aliases", () => {
  assert.equal(normalizeLeaderboardGame("Overall"), "overall");
  assert.equal(normalizeLeaderboardGame("rock-paper-scissors"), "rps");
  assert.equal(normalizeLeaderboardGame("Raja Mantri"), "rajamantri");
  assert.equal(normalizeLeaderboardGame("made-up-game"), null);
});

test("builds overall and game-specific scores from persisted non-bot matches", () => {
  const users = new Map([
    ["alice", account("alice")],
    ["bob", account("bob")],
    ["suspended", { ...account("suspended"), isSuspended: true }],
  ]);
  const matches = [
    { userKey: "alice", gameType: "tictactoe", result: "win", playedAt: "2026-01-01T10:00:00.000Z" },
    { userKey: "alice", gameType: "tictactoe", result: "win", playedAt: "2026-01-01T10:01:00.000Z" },
    { userKey: "alice", gameType: "tictactoe", result: "win", playedAt: "2026-01-01T10:02:00.000Z" },
    { userKey: "alice", gameType: "rps", result: "loss", playedAt: "2026-01-01T10:03:00.000Z" },
    { userKey: "bob", gameType: "rps", result: "win", playedAt: "2026-01-01T10:00:00.000Z" },
    { userKey: "alice", gameType: "rps", result: "win", isBotMatch: true, playedAt: "2026-01-01T10:04:00.000Z" },
    { userKey: "suspended", gameType: "rps", result: "win", playedAt: "2026-01-01T10:05:00.000Z" },
  ];

  const overall = buildGameLeaderboard({
    matches,
    users,
    viewerKey: "alice",
    selectedGame: "overall",
  });
  assert.equal(overall[0].username, "alice");
  assert.equal(overall[0].matches, 4);
  assert.equal(overall[0].wins, 3);
  assert.equal(overall[0].losses, 1);
  assert.equal(overall[0].score, 130);
  assert.equal(overall[0].rank, 1);

  const ticTacToe = buildGameLeaderboard({
    matches,
    users,
    viewerKey: "alice",
    selectedGame: "tictactoe",
  });
  assert.equal(ticTacToe[0].username, "alice");
  assert.equal(ticTacToe[0].matches, 3);
  assert.equal(ticTacToe[0].score, 120);
  assert.deepEqual(ticTacToe.map((entry) => entry.username), ["alice"]);
});

test("keeps the signed-in account visible without completed matches", () => {
  const users = new Map([["alice", account("alice")]]);
  const rows = buildGameLeaderboard({
    matches: [],
    users,
    viewerKey: "alice",
    selectedGame: "rps",
  });
  assert.equal(rows.length, 1);
  assert.equal(rows[0].isSelf, true);
  assert.equal(rows[0].score, 0);
  assert.equal(rows[0].matches, 0);
});


test("Mongo leaderboard aggregation filters bots, normalizes aliases and groups streaks in storage", () => {
  const globalPipeline = buildMongoGameLeaderboardPipeline();
  assert.deepEqual(globalPipeline[0].$match.isBotMatch, { $ne: true });
  assert.deepEqual(globalPipeline[0].$match.opponentType, { $ne: "bot" });
  assert.equal(globalPipeline[0].$match.userKey.$type, "string");
  assert.deepEqual(globalPipeline[0].$match.result.$in, ["win", "loss", "draw"]);
  assert.ok(globalPipeline.some((stage) => stage.$addFields?.parsedPlayedAt?.$dateFromString));
  assert.ok(globalPipeline.some((stage) => stage.$setWindowFields));
  assert.ok(globalPipeline.some((stage) => stage.$group?._id?.streakSegment));
  assert.ok(globalPipeline.some((stage) => stage.$group?.overallScore));
  assert.ok(globalPipeline.some((stage) => stage.$project?.overall));

  const friendsPipeline = buildMongoGameLeaderboardPipeline(["alice", "bob"]);
  assert.deepEqual(friendsPipeline[0].$match.userKey, { $in: ["alice", "bob"] });
});

test("Mongo aggregate summaries preserve score, win-rate, streak bonus, and empty self row", () => {
  const users = new Map([
    ["alice", account("alice")],
    ["bob", account("bob")],
  ]);
  const aggregates = [
    {
      userKey: "alice",
      overall: {
        matches: 4, wins: 3, losses: 1, draws: 0, score: 130,
        lastPlayedAt: "2026-01-01T10:03:00.000Z",
      },
      games: [
        {
          gameType: "tictactoe", matches: 3, wins: 3, losses: 0, draws: 0,
          score: 120, lastPlayedAt: "2026-01-01T10:02:00.000Z",
        },
        {
          gameType: "rps", matches: 1, wins: 0, losses: 1, draws: 0,
          score: 10, lastPlayedAt: "2026-01-01T10:03:00.000Z",
        },
      ],
    },
    {
      userKey: "bob",
      overall: {
        matches: 1, wins: 1, losses: 0, draws: 0, score: 35,
        lastPlayedAt: "2026-01-01T10:00:00.000Z",
      },
      games: [
        {
          gameType: "rps", matches: 1, wins: 1, losses: 0, draws: 0,
          score: 35, lastPlayedAt: "2026-01-01T10:00:00.000Z",
        },
      ],
    },
  ];

  const overall = buildGameLeaderboardFromAggregates({
    aggregates, users, viewerKey: "alice", selectedGame: "overall",
  });
  assert.deepEqual(overall.map((entry) => entry.username), ["alice", "bob"]);
  assert.equal(overall[0].score, 130);
  assert.equal(overall[0].winRate, 75);
  assert.equal(overall[0].lastPlayedAt, "2026-01-01T10:03:00.000Z");

  const ticTacToe = buildGameLeaderboardFromAggregates({
    aggregates, users, viewerKey: "alice", selectedGame: "tictactoe",
  });
  assert.equal(ticTacToe.length, 1);
  assert.equal(ticTacToe[0].score, 120);
  assert.equal(ticTacToe[0].matches, 3);

  const emptySelf = buildGameLeaderboardFromAggregates({
    aggregates: [], users, viewerKey: "alice", selectedGame: "rps",
  });
  assert.equal(emptySelf.length, 1);
  assert.equal(emptySelf[0].isSelf, true);
  assert.equal(emptySelf[0].score, 0);
});
