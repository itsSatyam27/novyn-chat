"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createMongoStorage } = require("../server/db/mongo");

function createFakeMongoClient(hooks = {}) {
  const metrics = {
    clientsCreated: 0,
    connectCalls: 0,
    closeCalls: 0,
    indexCalls: 0,
    databaseNames: [],
  };

  class FakeMongoClient {
    constructor(uri, options) {
      this.uri = uri;
      this.options = options;
      metrics.clientsCreated += 1;
    }

    async connect() {
      metrics.connectCalls += 1;
      if (hooks.connect) await hooks.connect(this);
      return this;
    }

    db(name) {
      metrics.databaseNames.push(name);
      return {
        collection(collectionName) {
          return {
            async createIndex(keys, options) {
              metrics.indexCalls += 1;
              if (hooks.createIndex) {
                await hooks.createIndex({ collectionName, keys, options });
              }
              return options?.name || "index";
            },
          };
        },
        admin() {
          return { ping: async () => ({ ok: 1 }) };
        },
      };
    }

    async close() {
      metrics.closeCalls += 1;
      if (hooks.close) await hooks.close(this);
    }
  }

  return { FakeMongoClient, metrics };
}

test("concurrent MongoDB connect calls share one client and one index setup", async () => {
  const { FakeMongoClient, metrics } = createFakeMongoClient();
  const storage = createMongoStorage({
    uri: "mongodb://example.test/novyn",
    MongoClientClass: FakeMongoClient,
  });

  const results = await Promise.all([
    storage.connect(),
    storage.connect(),
    storage.connect(),
    storage.connect(),
  ]);

  assert.deepEqual(results, [true, true, true, true]);
  assert.equal(metrics.clientsCreated, 1);
  assert.equal(metrics.connectCalls, 1);
  assert.equal(metrics.indexCalls, 5);
  assert.equal(storage.isConnected(), true);
  assert.ok(storage.db);
  assert.deepEqual(metrics.databaseNames, ["novyn"]);
  await storage.close();
  assert.equal(metrics.closeCalls, 1);
  assert.equal(storage.isConnected(), false);
  assert.equal(storage.db, null);
});

test("failed index initialization closes the client and allows a clean retry", async () => {
  let failFirstIndex = true;
  const { FakeMongoClient, metrics } = createFakeMongoClient({
    createIndex: async () => {
      if (failFirstIndex) {
        failFirstIndex = false;
        throw new Error("index creation failed");
      }
    },
  });
  const storage = createMongoStorage({
    uri: "mongodb://example.test/novyn",
    MongoClientClass: FakeMongoClient,
  });

  await assert.rejects(storage.connect(), /index creation failed/);
  assert.equal(storage.isConnected(), false);
  assert.equal(storage.client, null);
  assert.equal(storage.db, null);
  assert.equal(metrics.closeCalls, 1);

  assert.equal(await storage.connect(), true);
  assert.equal(storage.isConnected(), true);
  assert.equal(metrics.clientsCreated, 2);
  await storage.close();
  assert.equal(metrics.closeCalls, 2);
});

test("shutdown waits for an in-flight startup and leaves storage disconnected", async () => {
  let releaseConnect;
  const connectGate = new Promise((resolve) => {
    releaseConnect = resolve;
  });
  const { FakeMongoClient, metrics } = createFakeMongoClient({
    connect: () => connectGate,
  });
  const storage = createMongoStorage({
    uri: "mongodb://example.test/novyn",
    MongoClientClass: FakeMongoClient,
  });

  const startup = storage.connect();
  const shutdown = storage.close();
  releaseConnect();

  await Promise.all([startup, shutdown]);
  assert.equal(storage.isConnected(), false);
  assert.equal(storage.client, null);
  assert.equal(storage.db, null);
  assert.equal(metrics.clientsCreated, 1);
  assert.equal(metrics.closeCalls, 1);

  assert.equal(await storage.connect(), true);
  assert.equal(storage.isConnected(), true);
  await storage.close();
  assert.equal(metrics.closeCalls, 2);
});
