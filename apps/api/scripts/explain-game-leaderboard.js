"use strict";

const { MongoClient } = require("mongodb");
const {
  buildMongoGameLeaderboardPipeline,
  normalizeLeaderboardGame,
} = require("../game-leaderboard");

const ALLOWED_GAMES = new Set(["overall", "tictactoe", "rps", "rajamantri"]);

function findCursorStage(node, visited = new Set()) {
  if (!node || typeof node !== "object" || visited.has(node)) return null;
  visited.add(node);

  if (node.$cursor?.executionStats) return node.$cursor;
  if (Array.isArray(node)) {
    for (const entry of node) {
      const found = findCursorStage(entry, visited);
      if (found) return found;
    }
    return null;
  }
  for (const value of Object.values(node)) {
    const found = findCursorStage(value, visited);
    if (found) return found;
  }
  return null;
}

function collectIndexNames(node, names = new Set(), visited = new Set()) {
  if (!node || typeof node !== "object" || visited.has(node)) return names;
  visited.add(node);

  if (
    ["IXSCAN", "DISTINCT_SCAN"].includes(node.stage) &&
    typeof node.indexName === "string"
  ) {
    names.add(node.indexName);
  }

  const values = Array.isArray(node) ? node : Object.values(node);
  for (const value of values) collectIndexNames(value, names, visited);
  return names;
}

function extractQueryMetrics(explain) {
  const cursor = findCursorStage(explain);
  const stats = cursor?.executionStats || {};
  const winningPlan = cursor?.queryPlanner?.winningPlan || null;

  return {
    cursorExecutionTimeMs: Number.isFinite(stats.executionTimeMillis)
      ? stats.executionTimeMillis
      : null,
    totalDocsExamined: Number.isFinite(stats.totalDocsExamined)
      ? stats.totalDocsExamined
      : null,
    totalKeysExamined: Number.isFinite(stats.totalKeysExamined)
      ? stats.totalKeysExamined
      : null,
    documentsReturnedToPipeline: Number.isFinite(stats.nReturned)
      ? stats.nReturned
      : null,
    indexesUsed: [...collectIndexNames(winningPlan)].sort(),
  };
}

function parsePositiveInteger(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

async function main(env = process.env) {
  const uri = String(env.MONGODB_URI || "").trim();
  if (!uri) throw new Error("MONGODB_URI is required.");

  const dbName = String(env.MONGODB_DB || "novyn").trim() || "novyn";
  const selectedGame = normalizeLeaderboardGame(env.LEADERBOARD_GAME || "overall");
  if (!selectedGame || !ALLOWED_GAMES.has(selectedGame)) {
    throw new Error("LEADERBOARD_GAME must be overall, tictactoe, rps, or rajamantri.");
  }

  const rawUserKeys = String(env.LEADERBOARD_USER_KEYS || "")
    .split(",")
    .map((key) => key.trim().toLowerCase())
    .filter(Boolean);
  const userKeys = rawUserKeys.length
    ? [...new Set(rawUserKeys)]
    : null;
  if (userKeys?.length > 500) {
    throw new Error("LEADERBOARD_USER_KEYS is limited to 500 entries.");
  }

  const maxTimeMS = parsePositiveInteger(
    env.LEADERBOARD_EXPLAIN_MAX_TIME_MS,
    30000,
    1000,
    120000
  );
  const client = new MongoClient(uri, {
    serverSelectionTimeoutMS: 8000,
    connectTimeoutMS: 8000,
    maxPoolSize: 1,
  });

  try {
    await client.connect();
    const startedAt = process.hrtime.bigint();
    const explain = await client
      .db(dbName)
      .collection("game_history")
      .aggregate(buildMongoGameLeaderboardPipeline(userKeys, selectedGame), {
        allowDiskUse: true,
        maxTimeMS,
      })
      .explain("executionStats");
    const explainWallTimeMs = Number(process.hrtime.bigint() - startedAt) / 1e6;

    console.log(JSON.stringify({
      diagnostic: "novyn-game-leaderboard-explain",
      readOnly: true,
      database: dbName,
      game: selectedGame,
      scope: userKeys ? "provided-user-set" : "global",
      userFilterCount: userKeys?.length || 0,
      maxTimeMS,
      pipelineStages: buildMongoGameLeaderboardPipeline(userKeys, selectedGame)
        .map((stage) => Object.keys(stage)[0]),
      explainWallTimeMs: Math.round(explainWallTimeMs * 100) / 100,
      ...extractQueryMetrics(explain),
    }, null, 2));
  } finally {
    await client.close();
  }
}

if (require.main === module) {
  main().catch((error) => {
    // Never print the MongoDB URI or connection details into diagnostic output.
    console.error(JSON.stringify({
      diagnostic: "novyn-game-leaderboard-explain",
      ok: false,
      error: error?.name || "Error",
      code: Number.isFinite(Number(error?.code)) ? Number(error.code) : null,
    }));
    process.exitCode = 1;
  });
}

module.exports = {
  collectIndexNames,
  extractQueryMetrics,
  findCursorStage,
  parsePositiveInteger,
};
