const fs = require("fs/promises");
const path = require("path");
const { MongoClient } = require("mongodb");
require("dotenv").config();

const DATA_DIR = path.join(process.cwd(), "apps", "api", "runtime", "data");
const CHAT_STATE_FILE = path.join(DATA_DIR, "chat-state.json");
const AUTH_STATE_FILE = path.join(DATA_DIR, "auth-state.json");

const MONGODB_URI = String(process.env.MONGODB_URI || "").trim();
const MONGODB_DB = String(process.env.MONGODB_DB || "novyn").trim() || "novyn";
const USERS_COLLECTION = String(process.env.MONGODB_USERS_COLLECTION || "users").trim() || "users";
const CONVERSATIONS_COLLECTION = String(process.env.MONGODB_CONVERSATIONS_COLLECTION || "conversations").trim() || "conversations";
const MESSAGES_COLLECTION = String(process.env.MONGODB_MESSAGES_COLLECTION || "messages").trim() || "messages";
const LEGACY_COLLECTION = String(process.env.MONGODB_COLLECTION || "chat_state").trim() || "chat_state";

async function clearLocalFiles() {
  await fs.mkdir(DATA_DIR, { recursive: true });

  const emptyChatState = {
    users: [],
    groups: [],
    conversations: [],
    scheduledMessages: [],
  };

  const emptyAuthState = {
    refreshSessions: [],
    authUserAliases: [],
  };

  await fs.writeFile(CHAT_STATE_FILE, JSON.stringify(emptyChatState, null, 2), "utf8");
  await fs.writeFile(AUTH_STATE_FILE, JSON.stringify(emptyAuthState, null, 2), "utf8");
  console.log("✓ Local chat-state.json and auth-state.json cleared successfully.");
}

async function clearMongo() {
  if (!MONGODB_URI) {
    console.log("ℹ No MONGODB_URI configured. Skipping MongoDB cleanup.");
    return;
  }

  let client;
  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db(MONGODB_DB);

    await Promise.allSettled([
      db.collection(USERS_COLLECTION).deleteMany({}),
      db.collection(CONVERSATIONS_COLLECTION).deleteMany({}),
      db.collection(MESSAGES_COLLECTION).deleteMany({}),
      db.collection(LEGACY_COLLECTION).deleteMany({}),
    ]);

    console.log(`✓ MongoDB database "${MONGODB_DB}" collections (${USERS_COLLECTION}, ${CONVERSATIONS_COLLECTION}, ${MESSAGES_COLLECTION}, ${LEGACY_COLLECTION}) cleared successfully.`);
  } catch (err) {
    console.warn("⚠ Failed to connect to MongoDB to clear collections:", err?.message || err);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

async function main() {
  console.log("Clearing user list and chat state...");
  await clearLocalFiles();
  await clearMongo();
  console.log("All user data cleared!");
}

main().catch((err) => {
  console.error("Error clearing users:", err);
  process.exit(1);
});
