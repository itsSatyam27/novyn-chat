const test = require("node:test");
const assert = require("node:assert/strict");

const {
  collectIndexNames,
  extractQueryMetrics,
  findCursorStage,
  parsePositiveInteger,
} = require("../scripts/explain-game-leaderboard");

test("extracts MongoDB cursor execution metrics and selected indexes", () => {
  const explain = {
    stages: [{
      $cursor: {
        queryPlanner: {
          winningPlan: {
            stage: "FETCH",
            inputStage: {
              stage: "IXSCAN",
              indexName: "game_history_user_played_at",
            },
          },
        },
        executionStats: {
          executionTimeMillis: 8,
          totalDocsExamined: 50,
          totalKeysExamined: 50,
          nReturned: 50,
        },
      },
    }],
  };

  assert.equal(findCursorStage(explain).executionStats.nReturned, 50);
  assert.deepEqual(extractQueryMetrics(explain), {
    cursorExecutionTimeMs: 8,
    totalDocsExamined: 50,
    totalKeysExamined: 50,
    documentsReturnedToPipeline: 50,
    indexesUsed: ["game_history_user_played_at"],
  });
  assert.deepEqual(
    [...collectIndexNames({ stage: "IXSCAN", indexName: "test_idx" })],
    ["test_idx"]
  );
});

test("explain diagnostic handles missing cursor plans and bounds max time", () => {
  assert.deepEqual(extractQueryMetrics({ stages: [] }), {
    cursorExecutionTimeMs: null,
    totalDocsExamined: null,
    totalKeysExamined: null,
    documentsReturnedToPipeline: null,
    indexesUsed: [],
  });
  assert.equal(parsePositiveInteger("500", 30000, 1000, 120000), 1000);
  assert.equal(parsePositiveInteger("45000", 30000, 1000, 120000), 45000);
  assert.equal(parsePositiveInteger("999999", 30000, 1000, 120000), 120000);
  assert.equal(parsePositiveInteger("not-a-number", 30000, 1000, 120000), 30000);
});
