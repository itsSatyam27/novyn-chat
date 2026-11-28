const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

function readEnvText(value) {
  return String(value || "").trim();
}


function parseJsonMaybe(rawText) {
  const text = readEnvText(rawText).replace(/^\uFEFF/, "");
  if (!text) return null;
  return JSON.parse(text);
}

function loadFirebaseServiceAccount() {
  const rawJson = readEnvText(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  if (rawJson) {
    try {
      return parseJsonMaybe(rawJson);
    } catch (err) {
      console.warn("Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:", err?.message || err);
    }
  }

  const configuredPath = readEnvText(process.env.FIREBASE_SERVICE_ACCOUNT_FILE);
  const fallbackPath = path.resolve(__dirname, "../../../novynchat-firebase-adminsdk.json");
  const serviceAccountPath = configuredPath ? path.resolve(configuredPath) : fallbackPath;
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    try {
      const fileContents = fs.readFileSync(serviceAccountPath, "utf8");
      return parseJsonMaybe(fileContents);
    } catch (err) {
      console.warn(
        `Failed to read Firebase service account file "${serviceAccountPath}":`,
        err?.message || err
      );
    }
  }

  const projectId = readEnvText(process.env.FIREBASE_PROJECT_ID);
  const clientEmail = readEnvText(process.env.FIREBASE_CLIENT_EMAIL);
  const privateKeyRaw = String(process.env.FIREBASE_PRIVATE_KEY || "");
  const privateKey = privateKeyRaw.replace(/\\n/g, "\n").trim();
  if (projectId && clientEmail && privateKey) {
    return {
      type: "service_account",
      project_id: projectId,
      client_email: clientEmail,
      private_key: privateKey,
    };
  }

  return null;
}

function loadLegacyFirebaseServiceAccount() {
  const rawJson = readEnvText(process.env.FIREBASE_LEGACY_SERVICE_ACCOUNT_JSON);
  if (!rawJson) return null;

  try {
    return parseJsonMaybe(rawJson);
  } catch (err) {
    console.warn("Failed to parse FIREBASE_LEGACY_SERVICE_ACCOUNT_JSON:", err?.message || err);
    return null;
  }
}

let firebaseAdmin = null;
let firebaseLegacyAdmin = null;
try {
  const serviceAccount = loadFirebaseServiceAccount();
  if (serviceAccount) {
    firebaseAdmin = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
    });
  } else {
    console.warn(
      "Firebase Admin SDK unavailable: set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_FILE, or FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY."
    );
  }
} catch (err) {
  console.warn("Firebase Admin SDK unavailable:", err?.message || err);
}

try {
  const legacyServiceAccount = loadLegacyFirebaseServiceAccount();
  if (legacyServiceAccount &&
      legacyServiceAccount.project_id !== firebaseAdmin?.options?.projectId) {
    firebaseLegacyAdmin = admin.initializeApp({
      credential: admin.credential.cert(legacyServiceAccount),
      projectId: legacyServiceAccount.project_id,
    }, "legacy");
  }
} catch (err) {
  console.warn("Legacy Firebase Admin SDK unavailable:", err?.message || err);
}

async function verifyFirebaseIdToken(idToken) {
  const firebaseApps = [firebaseAdmin, firebaseLegacyAdmin].filter(Boolean);
  let verificationError;
  for (const firebaseApp of firebaseApps) {
    try {
      return await admin.auth(firebaseApp).verifyIdToken(idToken);
    } catch (err) {
      verificationError = err;
    }
  }
  throw verificationError || new Error("Firebase Admin SDK is not configured.");
}


module.exports = {
  admin,
  firebaseAdmin,
  firebaseLegacyAdmin,
  verifyFirebaseIdToken,
};
