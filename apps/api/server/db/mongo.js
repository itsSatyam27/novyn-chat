"use strict";

const { MongoClient } = require("mongodb");

function createMongoStorage(options = {}) {
  const uri = String(options.uri || "").trim();
  const dbName = String(options.dbName || "novyn").trim() || "novyn";
  const legacyCollectionName = String(options.legacyCollectionName || "chat_state").trim() || "chat_state";
  const usersCollectionName = String(options.usersCollectionName || "users").trim() || "users";
  const conversationsCollectionName = String(options.conversationsCollectionName || "conversations").trim() || "conversations";
  const messagesCollectionName = String(options.messagesCollectionName || "messages").trim() || "messages";
  const MongoClientClass = options.MongoClientClass || MongoClient;

  let client = null;
  let db = null;
  let collections = null;
  let connectPromise = null;
  let closePromise = null;

  function isConnected() {
    return Boolean(
      collections?.legacy &&
      collections?.users &&
      collections?.conversations &&
      collections?.messages &&
      collections?.auth_sessions &&
      collections?.media
    );
  }

  async function ensureIndexes(targetCollections = collections) {
    if (!targetCollections) return;

    const indexOperations = [
      targetCollections.users.createIndex({ email: 1 }, { name: "email_idx" }),
      targetCollections.conversations.createIndex({ updatedAt: -1 }, { name: "updated_at_idx" }),
      targetCollections.messages.createIndex(
        { conversationKey: 1, timestamp: 1, messageId: 1 },
        { name: "conversation_time_idx" }
      ),
      targetCollections.messages.createIndex({ messageId: 1 }, { name: "message_id_idx" }),
      targetCollections.media.createIndex({ ownerKey: 1 }, { name: "media_owner_idx" }),
    ];

    // Wait for every index operation to settle before closing a failed client.
    // Promise.all() rejects immediately and can leave other index commands running.
    const results = await Promise.allSettled(indexOperations);
    const failedOperation = results.find((result) => result.status === "rejected");
    if (failedOperation) throw failedOperation.reason;
  }

  async function connect() {
    if (!uri) return false;

    // Serialize connection attempts and shutdowns. A closing client must never
    // overlap a newly-created client, and concurrent callers share one attempt.
    if (closePromise) await closePromise;
    if (isConnected()) return true;
    if (connectPromise) return connectPromise;

    const attempt = (async () => {
      const nextClient = new MongoClientClass(uri, {
        // Fail promptly when Atlas is unreachable instead of leaving API calls
        // waiting on the driver's long default server-selection window.
        serverSelectionTimeoutMS: Number(options.serverSelectionTimeoutMS) || 8000,
        connectTimeoutMS: Number(options.connectTimeoutMS) || 8000,
        socketTimeoutMS: Number(options.socketTimeoutMS) || 15000,
        waitQueueTimeoutMS: Number(options.waitQueueTimeoutMS) || 5000,
        maxPoolSize: Number(options.maxPoolSize) || 20,
      });

      try {
        await nextClient.connect();
        const nextDb = nextClient.db(dbName);
        const nextCollections = {
          legacy: nextDb.collection(legacyCollectionName),
          users: nextDb.collection(usersCollectionName),
          conversations: nextDb.collection(conversationsCollectionName),
          messages: nextDb.collection(messagesCollectionName),
          auth_sessions: nextDb.collection(options.authSessionsCollectionName || "auth_sessions"),
          feedback: nextDb.collection("feedback"),
          media: nextDb.collection(options.mediaCollectionName || "media_metadata"),
        };

        // Publish the client only after all required indexes are ready. Health
        // checks and request handlers can therefore never observe partial setup.
        await ensureIndexes(nextCollections);
        client = nextClient;
        db = nextDb;
        collections = nextCollections;
        return true;
      } catch (error) {
        try {
          await nextClient.close();
        } catch (closeError) {
          // Preserve the initialization error while retaining cleanup context.
          if (error && typeof error === "object" && !error.closeError) {
            error.closeError = closeError;
          }
        }
        throw error;
      }
    })();

    connectPromise = attempt;
    try {
      return await attempt;
    } finally {
      if (connectPromise === attempt) connectPromise = null;
    }
  }

  async function close() {
    if (closePromise) return closePromise;

    const pendingConnect = connectPromise;
    const closing = (async () => {
      // If shutdown races startup, let startup finish (or fail) before taking
      // ownership of the client. This prevents a late connect from reopening
      // storage after close() has returned.
      if (pendingConnect) {
        try {
          await pendingConnect;
        } catch (_) {
          // The failed connect has already attempted to close its local client.
        }
      }

      const activeClient = client;
      client = null;
      db = null;
      collections = null;
      if (activeClient) await activeClient.close();
    })();

    closePromise = closing;
    try {
      await closing;
    } finally {
      if (closePromise === closing) closePromise = null;
    }
  }

  async function ping() {
    if (!client || !db || !isConnected()) {
      throw new Error("MongoDB storage is not initialized.");
    }
    await db.admin().ping();
    return true;
  }

  function getCollection(name) {
    if (!collections) return null;
    const key = String(name || "").trim();
    if (!key) return null;
    return collections[key] || null;
  }

  return {
    connect,
    close,
    isConnected,
    ping,
    getCollection,
    get db() {
      return db;
    },
    get client() {
      return client;
    },
    get collections() {
      return collections;
    },
  };
}

module.exports = { createMongoStorage };
