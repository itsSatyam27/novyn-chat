const fs = require("fs/promises");
const path = require("path");
const crypto = require("crypto");
const { MongoClient } = require("mongodb");

const STATE_FILE = process.env.STATE_FILE
  ? path.resolve(process.cwd(), process.env.STATE_FILE)
  : path.join(process.cwd(), "apps", "api", "runtime", "data", "chat-state.json");
const MONGODB_URI = String(process.env.MONGODB_URI || "").trim();
const MONGODB_DB = String(process.env.MONGODB_DB || "novyn").trim() || "novyn";
const LEGACY_COLLECTION =
  String(process.env.MONGODB_COLLECTION || "chat_state").trim() || "chat_state";
const USERS_COLLECTION = String(process.env.MONGODB_USERS_COLLECTION || "users").trim() || "users";
const CONVERSATIONS_COLLECTION =
  String(process.env.MONGODB_CONVERSATIONS_COLLECTION || "conversations").trim() || "conversations";
const MESSAGES_COLLECTION =
  String(process.env.MONGODB_MESSAGES_COLLECTION || "messages").trim() || "messages";

async function readStateFile() {
  const raw = await fs.readFile(STATE_FILE, "utf8");
  const parsed = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object") {
    throw new Error("State file does not contain a JSON object.");
  }
  if (!Array.isArray(parsed.users) || !Array.isArray(parsed.conversations)) {
    throw new Error("State file must contain users[] and conversations[].");
  }
  return parsed;
}

function buildUserOperations(users, snapshotId, updatedAt) {
  return users.map((entry) => {
    const key = String(entry?.key || entry?.username || "").trim().toLowerCase();
    if (!key) return null;
    return {
      updateOne: {
        filter: { _id: key },
        update: {
          $set: {
            username: String(entry?.username || key).trim(),
            email: String(entry?.email || "").trim().toLowerCase(),
            friends: Array.isArray(entry?.friends) ? entry.friends : [],
            requests: Array.isArray(entry?.requests) ? entry.requests : [],
            unread: Array.isArray(entry?.unread) ? entry.unread : [],
            pushSubs: Array.isArray(entry?.pushSubs) ? entry.pushSubs : [],
            isRegistered: Boolean(entry?.isRegistered),
            passwordSalt: String(entry?.passwordSalt || ""),
            passwordHash: String(entry?.passwordHash || ""),
            avatarId: String(entry?.avatarId || ""),
            age: String(entry?.age || ""),
            gender: String(entry?.gender || ""),
            displayName: String(entry?.displayName || ""),
            bio: String(entry?.bio || ""),
            createdAt: String(entry?.createdAt || ""),
            lastSeenAt: String(entry?.lastSeenAt || ""),
            snapshotId,
            updatedAt,
          },
        },
        upsert: true,
      },
    };
  }).filter(Boolean);
}

function buildConversationOperations(conversations, snapshotId, updatedAt) {
  const ops = [];
  let messageCount = 0;
  const messageOps = [];

  for (const entry of conversations) {
    const key = String(entry?.key || "").trim();
    if (!key) continue;
    const [userA = "", userB = ""] = key.split("::");
    const messages = Array.isArray(entry?.messages) ? entry.messages : [];
    const lastMessage = messages.length ? messages[messages.length - 1] : null;
    ops.push({
      updateOne: {
        filter: { _id: key },
        update: {
          $set: {
            _id: key,
            userA,
            userB,
            messageCount: messages.length,
            lastTimestamp: String(lastMessage?.timestamp || ""),
            snapshotId,
            updatedAt,
          },
        },
        upsert: true,
      },
    });

    for (const message of messages) {
      const messageId = String(message?.id || "").trim() || `${Date.now()}-${messageCount}`;
      const docId = `${key}::${messageId}`;
      messageOps.push({
        updateOne: {
          filter: { _id: docId },
          update: {
            $set: {
              _id: docId,
              conversationKey: key,
              messageId,
              timestamp: String(message?.timestamp || ""),
              message,
              snapshotId,
              updatedAt,
            },
          },
          upsert: true,
        },
      });
      messageCount += 1;
    }
  }

  return { conversationOps: ops, messageOps, messageCount };
}

async function bulkWriteInChunks(collection, operations, chunkSize = 500) {
  if (!operations.length) return;
  for (let i = 0; i < operations.length; i += chunkSize) {
    await collection.bulkWrite(operations.slice(i, i + chunkSize), { ordered: false });
  }
}

async function migrate() {
  if (!MONGODB_URI) {
    throw new Error("Missing MONGODB_URI. Use the same Mongo URI configured on Render.");
  }

  const state = await readStateFile();
  const client = new MongoClient(MONGODB_URI);

  try {
    await client.connect();
    const db = client.db(MONGODB_DB);
    const usersCollection = db.collection(USERS_COLLECTION);
    const conversationsCollection = db.collection(CONVERSATIONS_COLLECTION);
    const messagesCollection = db.collection(MESSAGES_COLLECTION);
    const legacyCollection = db.collection(LEGACY_COLLECTION);

    await Promise.all([
      usersCollection.createIndex({ email: 1 }, { name: "email_idx" }),
      conversationsCollection.createIndex({ updatedAt: -1 }, { name: "updated_at_idx" }),
      messagesCollection.createIndex(
        { conversationKey: 1, timestamp: 1, messageId: 1 },
        { name: "conversation_time_idx" }
      ),
      messagesCollection.createIndex({ messageId: 1 }, { name: "message_id_idx" }),
    ]);

    const updatedAt = new Date();
    const snapshotId = `${Date.now()}-${crypto.randomBytes(6).toString("hex")}`;

    const userOps = buildUserOperations(state.users, snapshotId, updatedAt);
    const { conversationOps, messageOps, messageCount } = buildConversationOperations(
      state.conversations,
      snapshotId,
      updatedAt
    );

    await bulkWriteInChunks(usersCollection, userOps);
    await usersCollection.deleteMany({ snapshotId: { $ne: snapshotId } });

    await bulkWriteInChunks(conversationsCollection, conversationOps);
    await conversationsCollection.deleteMany({ snapshotId: { $ne: snapshotId } });

    await bulkWriteInChunks(messagesCollection, messageOps);
    await messagesCollection.deleteMany({ snapshotId: { $ne: snapshotId } });

    await legacyCollection.updateOne(
      { _id: "main" },
      {
        $set: {
          _id: "main",
          migratedToCollections: true,
          migratedFromFile: path.basename(STATE_FILE),
          migratedAt: updatedAt,
        },
      },
      { upsert: true }
    );

    console.log("Migration complete.");
    console.log(`Mongo DB: ${MONGODB_DB}`);
    console.log(`Users collection: ${USERS_COLLECTION}`);
    console.log(`Conversations collection: ${CONVERSATIONS_COLLECTION}`);
    console.log(`Messages collection: ${MESSAGES_COLLECTION}`);
    console.log(`State file: ${STATE_FILE}`);
    console.log(`Users: ${userOps.length}`);
    console.log(`Conversations: ${conversationOps.length}`);
    console.log(`Messages: ${messageCount}`);
  } finally {
    await client.close();
  }
}

migrate().catch((error) => {
  console.error("State migration failed:");
  console.error(error.message || error);
  process.exit(1);
});
