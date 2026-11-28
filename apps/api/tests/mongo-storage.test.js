"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createMongoStorage } = require("../server/db/mongo");

function createFakeMongoClient() {
  const collections = new Map();
  const indexCalls = [];

  class FakeMongoClient {
    constructor(uri) {
      this.uri = uri;
      this.closed = false;
    }

    async connect() {}

    db(name) {
      return {
        collection(collectionName) {
          if (!collections.has(collectionName)) {
            collections.set(collectionName, {
              collectionName,
              async createIndex(keys, options) {
                indexCalls.push({ collectionName, keys, options });
                return options?.name || "index";
              },
            });
          }
          return collections.get(collectionName);
        },
        admin() {
          return { ping: async () => ({ ok: 1 }) };
        },
      };
    }

    async close() {
      this.closed = true;
    }
  }

  return { FakeMongoClient, collections, indexCalls };
}

test("Mongo storage exposes and indexes game_history for leaderboard queries", async () => {
  const { FakeMongoClient, collections, indexCalls } = createFakeMongoClient();
  const storage = createMongoStorage({
    uri: "mongodb://example.test/novyn",
    MongoClientClass: FakeMongoClient,
  });

  assert.equal(await storage.connect(), true);
  assert.equal(storage.isConnected(), true);

  const history = storage.getCollection("game_history");
  assert.ok(history);
  assert.equal(history, collections.get("game_history"));
  assert.ok(indexCalls.some((entry) =>
    entry.collectionName === "game_history" &&
    entry.keys.userKey === 1 &&
    entry.keys.playedAt === 1 &&
    entry.options.name === "game_history_user_played_at"
  ));

  await storage.close();
  assert.equal(storage.isConnected(), false);
  assert.equal(storage.getCollection("game_history"), null);
});

test("Mongo storage supports a configured game history collection name", async () => {
  const { FakeMongoClient, collections } = createFakeMongoClient();
  const storage = createMongoStorage({
    uri: "mongodb://example.test/novyn",
    gameHistoryCollectionName: "novyn_game_history",
    MongoClientClass: FakeMongoClient,
  });

  assert.equal(await storage.connect(), true);
  assert.ok(storage.getCollection("game_history"));
  assert.ok(collections.has("novyn_game_history"));
  assert.equal(storage.getCollection("game_history"), collections.get("novyn_game_history"));

  await storage.close();
});
