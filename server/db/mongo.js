"use strict";

const { MongoClient } = require("mongodb");

function createMongoStorage(options = {}) {
  const uri = String(options.uri || "").trim();
  const dbName = String(options.dbName || "novyn").trim() || "novyn";
  const legacyCollectionName = String(options.legacyCollectionName || "chat_state").trim() || "chat_state";
  const usersCollectionName = String(options.usersCollectionName || "users").trim() || "users";
  const conversationsCollectionName = String(options.conversationsCollectionName || "conversations").trim() || "conversations";
  const messagesCollectionName = String(options.messagesCollectionName || "messages").trim() || "messages";

  let client = null;
  let db = null;
  let collections = null;

  function isConnected() {
    return Boolean(
      collections?.legacy &&
      collections?.users &&
      collections?.conversations &&
      collections?.messages
    );
  }

  async function ensureIndexes() {
    if (!isConnected()) return;
    await Promise.all([
      collections.users.createIndex({ email: 1 }, { name: "email_idx" }),
      collections.conversations.createIndex({ updatedAt: -1 }, { name: "updated_at_idx" }),
      collections.messages.createIndex(
        { conversationKey: 1, timestamp: 1, messageId: 1 },
        { name: "conversation_time_idx" }
      ),
      collections.messages.createIndex({ messageId: 1 }, { name: "message_id_idx" }),
    ]);
  }

  async function connect() {
    if (!uri) return false;
    if (isConnected()) return true;

    client = new MongoClient(uri);
    try {
      await client.connect();
      db = client.db(dbName);
      collections = {
        legacy: db.collection(legacyCollectionName),
        users: db.collection(usersCollectionName),
        conversations: db.collection(conversationsCollectionName),
        messages: db.collection(messagesCollectionName),
      };
      await ensureIndexes();
      return true;
    } catch (error) {
      await close();
      throw error;
    }
  }

  async function close() {
    if (client) {
      await client.close();
    }
    client = null;
    db = null;
    collections = null;
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
