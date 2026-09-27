const fs = require("fs");
const fsp = require("fs/promises");
const crypto = require("crypto");
const path = require("path");
const http = require("http");
const express = require("express");
const multer = require("multer");
const { createMongoStorage } = require("./server/db/mongo");
const { createSocketAuthMiddleware } = require("./server/realtime/socket-auth");
const { registerMessageMutationHandlers } = require("./server/realtime/message-mutations");
const { registerCallHandlers } = require("./server/realtime/call-handlers");
const { Server } = require("socket.io");
const webpush = require("web-push");
const { cloudinary, hasCloudinaryConfig } = require("./cloudinary");
const { createChatAuthorization } = require("./server/chat/authorization");
const { createIpRateLimiter, pruneHttpRateLimits } = require("./server/auth/rate-limit");
const { createAuthToken: signAuthToken, verifyAuthToken: verifySignedAuthToken } = require("./server/auth/tokens");
const { createAuthSessions } = require("./server/auth/sessions");
const { parseCookies, safeTimingEqual: csrfSafeTimingEqual, createCsrf } = require("./server/auth/csrf");
const runtimeState = require("./server/core/state");
require("dotenv").config();
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
  const fallbackPath = path.join(__dirname, "novynchat-firebase-adminsdk.json");
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

let firebaseAdmin = null;
try {
  const serviceAccount = loadFirebaseServiceAccount();
  if (serviceAccount) {
    firebaseAdmin = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    console.warn(
      "Firebase Admin SDK unavailable: set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_FILE, or FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY."
    );
  }
} catch (err) {
  console.warn("Firebase Admin SDK unavailable:", err?.message || err);
}

let nodemailer = null;
try {
  nodemailer = require("nodemailer");
} catch (_) {
  nodemailer = null;
}

const app = express();
const server = http.createServer(app);
app.disable("x-powered-by");
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader("Permissions-Policy", "camera=(self), microphone=(self), geolocation=()");
  res.setHeader("X-Frame-Options", "DENY");
  if (process.env.NODE_ENV === "production") {
    res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  }
  next();
});
app.use(express.json({ limit: "64kb" }));
app.use("/api/auth", createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-api", 80, 15 * 60 * 1000));
app.use("/upload-voice", createIpRateLimiter({ getStore: () => httpRateLimits }, "voice-upload", 40, 15 * 60 * 1000));
app.use("/upload-file", createIpRateLimiter({ getStore: () => httpRateLimits }, "file-upload", 40, 15 * 60 * 1000));
app.use((req, res, next) => {
  ensureCsrfCookie(req, res);
  next();
});

const defaultUploadsDir = path.join(__dirname, "uploads");
const configuredUploadsDir = String(process.env.UPLOADS_DIR || "").trim();
let uploadsDir = configuredUploadsDir ? path.resolve(configuredUploadsDir) : defaultUploadsDir;
try {
  fs.mkdirSync(uploadsDir, { recursive: true });
} catch (err) {
  if (configuredUploadsDir) {
    console.warn(
      `UPLOADS_DIR "${configuredUploadsDir}" is not writable. Falling back to "${defaultUploadsDir}".`,
      err
    );
    uploadsDir = defaultUploadsDir;
    fs.mkdirSync(uploadsDir, { recursive: true });
  } else {
    throw err;
  }
}

if (!hasCloudinaryConfig && process.env.NODE_ENV === "production" && !configuredUploadsDir) {
  console.warn(
    "Cloudinary is not configured and UPLOADS_DIR is not set. Uploaded media is stored on local disk and can disappear after restarts/redeploys."
  );
}

const uploadVoice = multer({
  dest: uploadsDir,
  limits: {
    fileSize: 6 * 1024 * 1024,
  },
});
const uploadFile = multer({
  dest: uploadsDir,
  limits: {
    fileSize: 15 * 1024 * 1024,
  },
});
const uploadTokenSecret =
  process.env.UPLOAD_TOKEN_SECRET ||
  process.env.CLOUDINARY_API_SECRET ||
  (process.env.NODE_ENV === "production" ? null : "dev-secret");

if (!uploadTokenSecret) {
  throw new Error("UPLOAD_TOKEN_SECRET must be configured in production.");
}

if (!process.env.UPLOAD_TOKEN_SECRET && !process.env.CLOUDINARY_API_SECRET) {
  console.warn(
    "UPLOAD_TOKEN_SECRET is not set. Using an insecure dev secret for upload links."
  );
}

const VAPID_SUBJECT = toDisplayName(process.env.VAPID_SUBJECT) || "mailto:admin@novyn.local";
const VAPID_PUBLIC_KEY = toDisplayName(process.env.VAPID_PUBLIC_KEY);
const VAPID_PRIVATE_KEY = toDisplayName(process.env.VAPID_PRIVATE_KEY);
let vapidKeys = null;

if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY) {
  vapidKeys = { publicKey: VAPID_PUBLIC_KEY, privateKey: VAPID_PRIVATE_KEY };
} else {
  try {
    vapidKeys = webpush.generateVAPIDKeys();
    console.warn("VAPID keys are not set. Generated temporary keys for this session.");
    console.warn(`VAPID_PUBLIC_KEY=${vapidKeys.publicKey}`);
    console.warn(`VAPID_PRIVATE_KEY=${vapidKeys.privateKey}`);
  } catch (err) {
    console.warn("Failed to generate VAPID keys. Push notifications disabled.", err);
    vapidKeys = null;
  }
}

const pushEnabled = Boolean(vapidKeys?.publicKey && vapidKeys?.privateKey);
if (pushEnabled) {
  webpush.setVapidDetails(VAPID_SUBJECT, vapidKeys.publicKey, vapidKeys.privateKey);
}

function signUploadToken(filename) {
  return crypto.createHmac("sha256", uploadTokenSecret).update(filename).digest("hex");
}

function withUploadToken(rawUrl) {
  const text = toDisplayName(rawUrl);
  if (!text) return text;

  const [base, hash] = text.split("#");
  const baseText = String(base || "");
  let prefix = "";
  let pathWithQuery = baseText;

  if (/^https?:\/\//i.test(baseText)) {
    try {
      const parsed = new URL(baseText);
      if (!String(parsed.pathname || "").startsWith("/uploads/")) return text;
      prefix = parsed.origin;
      pathWithQuery = `${parsed.pathname || ""}${parsed.search || ""}`;
    } catch (_) {
      return text;
    }
  } else if (baseText.startsWith("uploads/")) {
    pathWithQuery = `/${baseText}`;
  } else if (!baseText.startsWith("/uploads/")) {
    return text;
  }

  const [pathOnly, queryString = ""] = String(pathWithQuery || "").split("?");
  const filename = path.basename(pathOnly || "");
  if (!filename) return text;
  const token = signUploadToken(filename);
  const params = new URLSearchParams(queryString || "");
  params.set("token", token);
  const serialized = params.toString();
  const nextBase = serialized ? `${pathOnly}?${serialized}` : pathOnly;
  return `${prefix}${nextBase}${hash ? `#${hash}` : ""}`;
}

function sanitizeAttachmentName(name) {
  const cleaned = String(name || "")
    .replace(/[\\/:*?"<>|]+/g, "_")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleaned) return "file";
  return cleaned.slice(0, 120);
}

function resolveAttachmentKind(mime) {
  const lower = String(mime || "").toLowerCase();
  return lower.startsWith("image/") ? "image" : "file";
}

function resolveUploadExtension(mime, originalName, fallbackExt = ".bin") {
  const extMap = {
    "audio/webm": ".webm",
    "audio/wav": ".wav",
    "audio/mpeg": ".mp3",
    "audio/ogg": ".ogg",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/gif": ".gif",
    "image/webp": ".webp",
    "image/svg+xml": ".svg",
    "application/pdf": ".pdf",
    "text/plain": ".txt",
    "text/csv": ".csv",
    "application/zip": ".zip",
    "application/x-zip-compressed": ".zip",
    "application/x-rar-compressed": ".rar",
    "application/x-7z-compressed": ".7z",
    "application/msword": ".doc",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
    "application/vnd.ms-powerpoint": ".ppt",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": ".pptx",
    "application/vnd.ms-excel": ".xls",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": ".xlsx",
  };
  const ext = extMap[String(mime || "").toLowerCase()] || path.extname(originalName || "") || fallbackExt;
  return ext.startsWith(".") ? ext : `.${ext}`;
}

function sanitizeMessageAttachment(rawAttachment, fallbackUrl = "") {
  if (!rawAttachment) return null;
  const attachment = typeof rawAttachment === "string" ? { url: rawAttachment } : rawAttachment;
  if (!attachment || typeof attachment !== "object") return null;

  const rawUrl = toDisplayName(attachment.url || fallbackUrl);
  let normalizedUrl = rawUrl;
  if (
    normalizedUrl
    && !/^(?:https?:)?\/\//i.test(normalizedUrl)
    && !/^data:/i.test(normalizedUrl)
    && !/^blob:/i.test(normalizedUrl)
  ) {
    if (normalizedUrl.startsWith("uploads/")) {
      normalizedUrl = `/${normalizedUrl}`;
    } else if (
      !normalizedUrl.includes("/")
      && /^[a-z0-9][a-z0-9._-]*\.(?:png|jpe?g|gif|webp|bmp|svg|mp4|mov|webm|mp3|wav|ogg|m4a|aac|pdf|txt|csv|zip|rar|7z|docx?|pptx?|xlsx?)(?:[?#].*)?$/i.test(normalizedUrl)
    ) {
      normalizedUrl = `/uploads/${normalizedUrl}`;
    }
  }

  const url = withUploadToken(normalizedUrl);
  if (!url) return null;

  const mime = toDisplayName(attachment.mime).toLowerCase().slice(0, 120);
  const fallbackName = path.basename(String(url).split("?")[0] || "file");
  const name = sanitizeAttachmentName(attachment.name || fallbackName || "file");
  const kind = String(attachment.kind || "").toLowerCase() === "image"
    || mime.startsWith("image/")
    || /\.(?:png|jpe?g|gif|webp|bmp|svg)(?:[?#].*)?$/i.test(String(url || ""))
    ? "image"
    : "file";
  const numericSize = Number(attachment.size);
  const size = Number.isFinite(numericSize) ? Math.max(0, Math.floor(numericSize)) : 0;

  return {
    url,
    name,
    mime,
    size,
    kind,
  };
}

// ── APK Download Route ────────────────────────────────────────────────────
// Serves the Android APK from public/downloads/ with the correct headers
// so the browser triggers a download instead of trying to render it.
app.get("/downloads/:filename", (req, res) => {
  const filename = path.basename(req.params.filename || "");
  if (!filename.endsWith(".apk")) {
    res.status(400).json({ error: "Invalid file type." });
    return;
  }
  const filePath = path.join(__dirname, "public", "downloads", filename);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: "APK not found. Check back soon." });
    return;
  }
  res.setHeader("Content-Type", "application/vnd.android.package-archive");
  res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.sendFile(filePath);
});

// ── Feedback Endpoint ─────────────────────────────────────────────────────

app.get("/uploads/:file", (req, res) => {
  const filename = path.basename(req.params.file || "");
  const token = String(req.query.token || "");
  if (!filename || token !== signUploadToken(filename)) {
    res.status(403).json({ error: "Unauthorized" });
    return;
  }
  const filePath = path.join(uploadsDir, filename);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: "Not found" });
    return;
  }
  res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.set("Pragma", "no-cache");
  res.set("Expires", "0");
  if (String(req.query.download || "") === "1") {
    const downloadName = sanitizeAttachmentName(req.query.name || filename);
    res.setHeader("Content-Disposition", `attachment; filename="${downloadName}"`);
  }
  res.sendFile(filePath);
});

app.post(
  "/upload-voice",
  requireCsrf,
  (req, res, next) => {
    uploadVoice.single("voice")(req, res, (err) => {
      if (!err) {
        next();
        return;
      }
      if (err?.code === "LIMIT_FILE_SIZE") {
        res.status(413).json({ error: "Voice file is too large." });
        return;
      }
      res.status(400).json({ error: "Invalid upload payload." });
    });
  },
  async (req, res) => {
    if (!req.file?.path) {
      res.status(400).json({ error: "No voice file uploaded." });
      return;
    }

    const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), {
      allowRefreshFallback: true,
    });
    if (!auth.userKey) {
      fs.unlink(req.file.path, () => {});
      res.status(401).json({ error: "Sign in required." });
      return;
    }

    const mime = String(req.file.mimetype || "").toLowerCase();
    if (!ALLOWED_VOICE_MIME.has(mime)) {
      fs.unlink(req.file.path, () => {});
      res.status(415).json({ error: "Unsupported voice format." });
      return;
    }

    try {
      if (hasCloudinaryConfig) {
        const result = await cloudinary.uploader.upload(req.file.path, {
          resource_type: "auto",
          folder: "novyn_voice",
        });

        fs.unlink(req.file.path, () => {});
        res.json({ url: result.secure_url });
        return;
      }

      const extMap = {
        "audio/webm": ".webm",
        "audio/wav": ".wav",
        "audio/mpeg": ".mp3",
        "audio/ogg": ".ogg",
        "audio/mp4": ".m4a",
        "audio/aac": ".aac",
      };
      const ext = extMap[mime] || path.extname(req.file.originalname || "") || ".webm";
      const safeExt = ext.startsWith(".") ? ext : `.${ext}`;
      const filename = `voice-${Date.now()}-${crypto.randomBytes(3).toString("hex")}${safeExt}`;
      const destPath = path.join(uploadsDir, filename);
      fs.renameSync(req.file.path, destPath);
      const token = signUploadToken(filename);
      res.json({ url: `/uploads/${filename}?token=${token}` });
    } catch (error) {
      console.error(error);
      res.status(500).json({ error: "Upload failed" });
    }
  }
);

app.post(
  "/upload-file",
  requireCsrf,
  (req, res, next) => {
    uploadFile.single("file")(req, res, (err) => {
      if (!err) {
        next();
        return;
      }
      if (err?.code === "LIMIT_FILE_SIZE") {
        res.status(413).json({ error: "File is too large." });
        return;
      }
      res.status(400).json({ error: "Invalid upload payload." });
    });
  },
  async (req, res) => {
    if (!req.file?.path) {
      res.status(400).json({ error: "No file uploaded." });
      return;
    }

    const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), {
      allowRefreshFallback: true,
    });
    if (!auth.userKey) {
      fs.unlink(req.file.path, () => {});
      res.status(401).json({ error: "Sign in required." });
      return;
    }

    const mime = String(req.file.mimetype || "").toLowerCase();
    if (!ALLOWED_FILE_MIME.has(mime)) {
      fs.unlink(req.file.path, () => {});
      res.status(415).json({ error: "Unsupported file type." });
      return;
    }

    const attachmentName = sanitizeAttachmentName(req.file.originalname || "file");
    const kind = resolveAttachmentKind(mime);
    const size = Math.max(0, Number(req.file.size) || 0);

    try {
      if (hasCloudinaryConfig) {
        const result = await cloudinary.uploader.upload(req.file.path, {
          resource_type: "auto",
          folder: kind === "image" ? "novyn_images" : "novyn_files",
        });
        fs.unlink(req.file.path, () => {});
        res.json({
          url: result.secure_url,
          name: attachmentName,
          mime,
          size,
          kind,
        });
        return;
      }

      const ext = resolveUploadExtension(mime, attachmentName, ".bin");
      const filename = `file-${Date.now()}-${crypto.randomBytes(3).toString("hex")}${ext}`;
      const destPath = path.join(uploadsDir, filename);
      fs.renameSync(req.file.path, destPath);
      const token = signUploadToken(filename);
      res.json({
        url: `/uploads/${filename}?token=${token}`,
        name: attachmentName,
        mime,
        size,
        kind,
      });
    } catch (error) {
      fs.unlink(req.file.path, () => {});
      console.error(error);
      res.status(500).json({ error: "File upload failed." });
    }
  }
);

const allowedSocketOrigins = toDisplayName(process.env.ALLOWED_ORIGIN)
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

const socketCorsOrigin = (origin, callback) => {
  if (!origin) {
    // Native clients and same-origin requests may omit Origin.
    callback(null, process.env.NODE_ENV !== "production");
    return;
  }
  if (allowedSocketOrigins.includes(origin)) {
    callback(null, true);
    return;
  }
  callback(new Error("Origin not allowed"));
};

const io = new Server(server, {
  cors: {
    origin: socketCorsOrigin,
    credentials: true,
  },
  maxHttpBufferSize: 256 * 1024,
});

app.get(["/login", "/login.html"], (req, res) => {
  res.redirect(302, "/");
});

app.get("/api/push/public-key", (req, res) => {
  if (!pushEnabled) {
    res.status(503).json({ error: "Push notifications are not configured." });
    return;
  }
  res.json({ publicKey: vapidKeys.publicKey });
});

app.get("/api/rtc/ice", (req, res) => {
  const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), {
    allowRefreshFallback: true,
  });
  const user = auth.userKey ? users.get(auth.userKey) : null;
  const authenticated = Boolean(user?.isRegistered);
  res.json({
    iceServers: getRtcIceServersForClient(authenticated),
    authenticated,
  });
});

app.get("/api/stats", (req, res) => {
  const totalUsers = Array.from(users.values()).filter((user) => user?.isRegistered).length;
  const onlineCount = onlineUsers.size;
  const now = Date.now();
  const newUsersToday = Array.from(users.values()).filter((user) => {
    if (!user?.isRegistered) return false;
    if (!user.createdAt) return false;
    const created = Date.parse(user.createdAt);
    if (!Number.isFinite(created)) return false;
    return now - created <= 24 * 60 * 60 * 1000;
  }).length;
  let messageCount = 0;
  conversations.forEach((messages) => {
    if (Array.isArray(messages)) {
      messageCount += messages.length;
    }
  });
  res.json({
    users: totalUsers,
    online: onlineCount,
    messages: messageCount,
    newUsersToday,
  });
});

const conversationWallpapers = new Map();

const DATA_DIR = path.join(__dirname, "data");
const DATA_FILE = path.join(DATA_DIR, "chat-state.json");
const AUTH_STATE_FILE = path.join(DATA_DIR, "auth-state.json");
const ABUSE_REPORT_FILE = path.join(DATA_DIR, "abuse-reports.log");
const MONGODB_URI = toDisplayName(process.env.MONGODB_URI);
const MONGODB_DB = toDisplayName(process.env.MONGODB_DB) || "novyn";
const MONGODB_LEGACY_COLLECTION = toDisplayName(process.env.MONGODB_COLLECTION) || "chat_state";
const MONGODB_USERS_COLLECTION = toDisplayName(process.env.MONGODB_USERS_COLLECTION) || "users";
const MONGODB_CONVERSATIONS_COLLECTION =
  toDisplayName(process.env.MONGODB_CONVERSATIONS_COLLECTION) || "conversations";
const MONGODB_MESSAGES_COLLECTION = toDisplayName(process.env.MONGODB_MESSAGES_COLLECTION) || "messages";
const CHAT_RETENTION_DAYS = Math.max(
  1,
  Number.isFinite(Number(process.env.CHAT_RETENTION_DAYS))
    ? Math.floor(Number(process.env.CHAT_RETENTION_DAYS))
    : 30
);
const MIN_PASSWORD_LENGTH = 12;
const PASSWORD_ITERATIONS = 120000;
const PASSWORD_KEY_LENGTH = 64;
const PASSWORD_DIGEST = "sha512";
const DELETED_MESSAGE_TEXT = "This message was deleted.";
const CALL_LOG_PREFIX = "__call_log__:";
const ENCRYPTED_MESSAGE_PLACEHOLDER = "🔒 Encrypted message";
const PASSWORD_RESET_CODE_TTL_MS = 15 * 60 * 1000;
const PASSWORD_RESET_MAX_ATTEMPTS = 5;
const PASSWORD_RESET_WINDOW_MS = 15 * 60 * 1000;
const PASSWORD_RESET_MAX_PER_WINDOW = 3;
const PASSWORD_RESET_RESEND_COOLDOWN_MS = 30 * 1000;
const EMAIL_CHANGE_CODE_TTL_MS = 15 * 60 * 1000;
const EMAIL_CHANGE_MAX_ATTEMPTS = 5;
const EMAIL_CHANGE_WINDOW_MS = 15 * 60 * 1000;
const EMAIL_CHANGE_MAX_PER_WINDOW = 3;
const EMAIL_CHANGE_RESEND_COOLDOWN_MS = 30 * 1000;
const PASSWORD_RESET_LOG_CODES = process.env.NODE_ENV !== "production";
const SMTP_HOST = toDisplayName(process.env.SMTP_HOST);
const SMTP_PORT = Number.isFinite(Number(process.env.SMTP_PORT))
  ? Math.max(1, Math.floor(Number(process.env.SMTP_PORT)))
  : 587;
const SMTP_SECURE = parseEnvBoolean(process.env.SMTP_SECURE, SMTP_PORT === 465);
const SMTP_USER = toDisplayName(process.env.SMTP_USER);
const SMTP_PASS = toDisplayName(process.env.SMTP_PASS);
const SMTP_FROM = toDisplayName(process.env.SMTP_FROM) || SMTP_USER;
const SMTP_REPLY_TO = toDisplayName(process.env.SMTP_REPLY_TO);
const SMTP_CONNECTION_TIMEOUT_MS = Number.isFinite(Number(process.env.SMTP_CONNECTION_TIMEOUT_MS))
  ? Math.max(1000, Math.floor(Number(process.env.SMTP_CONNECTION_TIMEOUT_MS)))
  : 12000;
const SMTP_GREETING_TIMEOUT_MS = Number.isFinite(Number(process.env.SMTP_GREETING_TIMEOUT_MS))
  ? Math.max(1000, Math.floor(Number(process.env.SMTP_GREETING_TIMEOUT_MS)))
  : 12000;
const SMTP_SOCKET_TIMEOUT_MS = Number.isFinite(Number(process.env.SMTP_SOCKET_TIMEOUT_MS))
  ? Math.max(1000, Math.floor(Number(process.env.SMTP_SOCKET_TIMEOUT_MS)))
  : 15000;
const SMTP_SEND_TIMEOUT_MS = Number.isFinite(Number(process.env.SMTP_SEND_TIMEOUT_MS))
  ? Math.max(2000, Math.floor(Number(process.env.SMTP_SEND_TIMEOUT_MS)))
  : 18000;
const PASSWORD_RESET_EMAIL_SUBJECT =
  toDisplayName(process.env.PASSWORD_RESET_EMAIL_SUBJECT) || "Your Novyn password reset code";
const EMAIL_CHANGE_EMAIL_SUBJECT =
  toDisplayName(process.env.EMAIL_CHANGE_EMAIL_SUBJECT) || "Verify your new Novyn email";
const MAX_MESSAGE_LENGTH = 1000;
const MAX_GROUP_NAME_LENGTH = 48;
const MAX_GROUP_MEMBERS = 48;
const GROUP_ID_PREFIX = "grp_";
const GROUP_CONVERSATION_PREFIX = "__group__:";
const SCHEDULE_MIN_DELAY_MS = 30 * 1000;
const SCHEDULE_MAX_DELAY_MS = 45 * 24 * 60 * 60 * 1000;
const ALLOWED_VOICE_MIME = new Set([
  "audio/webm",
  "audio/wav",
  "audio/mpeg",
  "audio/ogg",
  "audio/mp4",
  "audio/aac",
]);
const ALLOWED_FILE_MIME = new Set([
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "application/pdf",
  "text/plain",
  "text/csv",
  "application/zip",
  "application/x-zip-compressed",
  "application/x-rar-compressed",
  "application/x-7z-compressed",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);
const DEFAULT_RTC_ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];
const RTC_ICE_SERVERS_JSON = toDisplayName(process.env.RTC_ICE_SERVERS_JSON);
const RTC_STUN_URLS = toDisplayName(process.env.RTC_STUN_URLS);
const RTC_TURN_URL = toDisplayName(process.env.RTC_TURN_URL);
const RTC_TURN_USERNAME = toDisplayName(process.env.RTC_TURN_USERNAME);
const RTC_TURN_CREDENTIAL = toDisplayName(process.env.RTC_TURN_CREDENTIAL);
const RTC_TURN_CREDENTIAL_TYPE = toDisplayName(process.env.RTC_TURN_CREDENTIAL_TYPE) || "password";
const RTC_ICE_SERVERS = resolveRtcIceServers();
const AUTH_SECRET =
  toDisplayName(process.env.AUTH_SECRET) ||
  (process.env.NODE_ENV === "production" ? "" : toDisplayName(process.env.UPLOAD_TOKEN_SECRET) || "dev-auth-secret");

if (!AUTH_SECRET) {
  throw new Error("AUTH_SECRET must be configured in production.");
}
const AUTH_ACCESS_COOKIE = "novyn_at";
const AUTH_REFRESH_COOKIE = "novyn_rt";
const AUTH_CSRF_COOKIE = "novyn_csrf";
const AUTH_CSRF_HEADER = "x-novyn-csrf";
const AUTH_CSRF_TOKEN_BYTES = 24;
const AUTH_ACCESS_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days (prevents premature logouts)
const AUTH_REFRESH_REMEMBER_TTL_MS = 90 * 24 * 60 * 60 * 1000; // 90 days
const AUTH_REFRESH_SESSION_TTL_MS = 14 * 24 * 60 * 60 * 1000; // 14 days
const AUTH_ALIAS_TTL_MS = AUTH_REFRESH_REMEMBER_TTL_MS;
const AUTH_COOKIE_SECURE = process.env.NODE_ENV === "production";

const csrfProtection = createCsrf({
  cookieName: AUTH_CSRF_COOKIE,
  headerName: AUTH_CSRF_HEADER,
  secure: AUTH_COOKIE_SECURE,
  tokenBytes: AUTH_CSRF_TOKEN_BYTES,
});

if (process.env.NODE_ENV !== "production" && !process.env.AUTH_SECRET) {
  console.warn("AUTH_SECRET is not set. Development fallback is enabled only outside production.");
}

const passwordResetEmailConfigured = Boolean(
  nodemailer && SMTP_HOST && SMTP_USER && SMTP_PASS && SMTP_FROM
);
const passwordResetMailer = passwordResetEmailConfigured
  ? nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: SMTP_SECURE,
      connectionTimeout: SMTP_CONNECTION_TIMEOUT_MS,
      greetingTimeout: SMTP_GREETING_TIMEOUT_MS,
      socketTimeout: SMTP_SOCKET_TIMEOUT_MS,
      auth: {
        user: SMTP_USER,
        pass: SMTP_PASS,
      },
    })
  : null;

if (!nodemailer && process.env.NODE_ENV === "production") {
  console.warn(
    "nodemailer is not installed. Run `npm install nodemailer` to enable password reset emails."
  );
}

if (!passwordResetEmailConfigured && !PASSWORD_RESET_LOG_CODES) {
  console.warn(
    "SMTP config missing. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM for password reset emails."
  );
}

const {
  users,
  onlineUsers,
  conversations,
  groups,
  scheduledMessages,
  scheduledMessageTimers,
  activeCalls,
  passwordResetTokens,
  passwordResetByUser,
  passwordResetRate,
  emailChangeTokens,
  emailChangeByUser,
  emailChangeRate,
  refreshSessions,
  refreshByUser,
  authUserAliases,
  httpRateLimits,
} = runtimeState;

let mongoStorage = null;
let mongoClient = null;
let mongoLegacyCollection = null;
let mongoUsersCollection = null;
let mongoConversationsCollection = null;
let mongoMessagesCollection = null;

let persistTimer = null;
let persistInFlight = Promise.resolve();
let authPersistTimer = null;
let authPersistInFlight = Promise.resolve();

const {
  normalizeName,
  toDisplayName,
  normalizeEmail,
  isPlausibleEmail,
  parseEnvBoolean,
  normalizeHandleInput,
  normalizeChatKind,
  normalizePresenceMode,
  normalizeGroupId,
} = require("./server/core/normalization");

const authSessions = createAuthSessions({
  refreshSessions,
  refreshByUser,
  authUserAliases,
  schedulePersist: () => scheduleAuthStatePersist(),
});

function getGroupConversationKey(groupId) {
  return `${GROUP_CONVERSATION_PREFIX}${normalizeGroupId(groupId)}`;
}

function isGroupConversationKey(value) {
  return toDisplayName(value).startsWith(GROUP_CONVERSATION_PREFIX);
}

function getGroupIdFromConversationKey(value) {
  if (!isGroupConversationKey(value)) return "";
  return normalizeGroupId(toDisplayName(value).slice(GROUP_CONVERSATION_PREFIX.length));
}

function createGroupId(seed = "group") {
  const cleanedSeed = normalizeName(seed).replace(/[^a-z0-9]/g, "").slice(0, 14) || "group";
  const suffix = crypto.randomBytes(3).toString("hex");
  return `${GROUP_ID_PREFIX}${cleanedSeed}_${suffix}`;
}

function createGroupRecord(name, ownerKey, memberKeys = []) {
  const owner = normalizeName(ownerKey);
  const members = new Set(memberKeys.map(normalizeName).filter(Boolean));
  if (owner) members.add(owner);
  return {
    id: "",
    name: toDisplayName(name).slice(0, MAX_GROUP_NAME_LENGTH) || "Group chat",
    ownerKey: owner,
    admins: new Set(owner ? [owner] : []),
    members,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };
}

function parseIceUrls(rawValue) {
  const value = toDisplayName(rawValue);
  if (!value) return [];
  return value
    .split(",")
    .map((item) => toDisplayName(item))
    .filter(Boolean);
}

function normalizeIceServerEntry(entry) {
  if (!entry || typeof entry !== "object") return null;

  const rawUrls = entry.urls;
  let urls = "";
  if (typeof rawUrls === "string") {
    urls = toDisplayName(rawUrls);
  } else if (Array.isArray(rawUrls)) {
    urls = rawUrls.map((item) => toDisplayName(item)).filter(Boolean);
  }

  if (!urls || (Array.isArray(urls) && urls.length === 0)) {
    return null;
  }

  const normalized = { urls };
  const username = toDisplayName(entry.username);
  if (username) normalized.username = username;
  if (entry.credential !== undefined && entry.credential !== null) {
    normalized.credential = String(entry.credential);
  }
  const credentialType = toDisplayName(entry.credentialType);
  if (credentialType) normalized.credentialType = credentialType;

  return normalized;
}

function cloneIceServerEntry(entry, options = {}) {
  const includeSensitive = options.includeSensitive !== false;
  const cloned = {
    urls: Array.isArray(entry.urls) ? entry.urls.slice() : entry.urls,
  };
  if (includeSensitive && entry.username) cloned.username = entry.username;
  if (includeSensitive && entry.credential !== undefined) cloned.credential = entry.credential;
  if (includeSensitive && entry.credentialType) cloned.credentialType = entry.credentialType;
  return cloned;
}

function resolveRtcIceServers() {
  if (RTC_ICE_SERVERS_JSON) {
    try {
      const parsed = JSON.parse(RTC_ICE_SERVERS_JSON);
      const list = Array.isArray(parsed) ? parsed : [parsed];
      const normalized = list.map((entry) => normalizeIceServerEntry(entry)).filter(Boolean);
      if (normalized.length) {
        return normalized;
      }
    } catch (err) {
      console.warn("RTC_ICE_SERVERS_JSON is invalid. Falling back to RTC_STUN_URLS/RTC_TURN_*.");
    }
  }

  const configured = [];
  const stunUrls = parseIceUrls(RTC_STUN_URLS);
  stunUrls.forEach((url) => {
    configured.push({ urls: url });
  });

  const turnUrl = toDisplayName(RTC_TURN_URL);
  if (turnUrl || RTC_TURN_USERNAME || RTC_TURN_CREDENTIAL) {
    if (turnUrl && RTC_TURN_USERNAME && RTC_TURN_CREDENTIAL) {
      configured.push({
        urls: turnUrl,
        username: RTC_TURN_USERNAME,
        credential: RTC_TURN_CREDENTIAL,
        credentialType: RTC_TURN_CREDENTIAL_TYPE,
      });
    } else {
      console.warn(
        "TURN config is incomplete. Set RTC_TURN_URL, RTC_TURN_USERNAME, and RTC_TURN_CREDENTIAL together."
      );
    }
  }

  const normalizedConfigured = configured
    .map((entry) => normalizeIceServerEntry(entry))
    .filter(Boolean);
  if (normalizedConfigured.length) {
    return normalizedConfigured;
  }

  return DEFAULT_RTC_ICE_SERVERS.map((entry) => cloneIceServerEntry(entry));
}

function getRtcIceServersForClient(authenticated) {
  if (authenticated) {
    return RTC_ICE_SERVERS.map((entry) => cloneIceServerEntry(entry, { includeSensitive: true }));
  }
  const publicEntries = RTC_ICE_SERVERS
    .filter((entry) => !entry.username && entry.credential === undefined)
    .map((entry) => cloneIceServerEntry(entry, { includeSensitive: false }));
  if (publicEntries.length) {
    return publicEntries;
  }
  return DEFAULT_RTC_ICE_SERVERS.map((entry) =>
    cloneIceServerEntry(entry, { includeSensitive: false })
  );
}

const { createPasswordSecret, verifyPassword } = require("./server/auth/password");

function nowIso() {
  return new Date().toISOString();
}

function createMessageId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function toBase64Url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function fromBase64Url(input) {
  const safe = String(input || "").replace(/-/g, "+").replace(/_/g, "/");
  const pad = safe.length % 4;
  const padded = pad ? `${safe}${"=".repeat(4 - pad)}` : safe;
  return Buffer.from(padded, "base64");
}

function safeTimingEqual(left, right) {
  return csrfSafeTimingEqual(left, right);
}

function createCsrfToken() {
  return csrfProtection.createToken();
}

function ensureCsrfCookie(req, res) {
  return csrfProtection.ensureCookie(req, res);
}

function isSameOriginRequest(req) {
  return csrfProtection.isSameOriginRequest(req);
}

function requireCsrf(req, res, next) {
  return csrfProtection.middleware(req, res, next);
}

function createUserRecord(username) {
  return {
    username: toDisplayName(username),
    email: "",
    googleUid: "",
    friends: new Set(),
    groups: new Set(),
    requests: new Set(),
    unread: new Map(),
    blockedUsers: new Set(),
    mutedUsers: new Set(),
    pushSubs: [],
    isRegistered: false,
    passwordSalt: "",
    passwordHash: "",
    avatarId: "",
    age: "",
    gender: "",
    displayName: "",
    bio: "",
    createdAt: "",
    lastSeenAt: "",
    presenceMode: "online",
    publicKey: "",
  };
}

function serializeState() {
  return {
    users: Array.from(users.entries()).map(([key, user]) => ({
      key,
      username: user.username,
      email: toDisplayName(user.email),
      googleUid: toDisplayName(user.googleUid),
      friends: Array.from(user.friends),
      groups: Array.from(user.groups || []),
      requests: Array.from(user.requests),
      unread: Array.from(user.unread.entries()),
      blockedUsers: Array.from(user.blockedUsers || []),
      mutedUsers: Array.from(user.mutedUsers || []),
      pushSubs: Array.isArray(user.pushSubs) ? user.pushSubs : [],
      isRegistered: Boolean(user.isRegistered),
      passwordSalt: toDisplayName(user.passwordSalt),
      passwordHash: toDisplayName(user.passwordHash),
      avatarId: toDisplayName(user.avatarId),
      age: toDisplayName(user.age),
      gender: toDisplayName(user.gender),
      displayName: toDisplayName(user.displayName),
      bio: toDisplayName(user.bio),
      createdAt: toDisplayName(user.createdAt),
      lastSeenAt: toDisplayName(user.lastSeenAt),
      presenceMode: normalizePresenceMode(user.presenceMode),
      publicKey: toDisplayName(user.publicKey),
    })),
    conversations: Array.from(conversations.entries()).map(([key, messages]) => ({
      key,
      messages,
    })),
    groups: Array.from(groups.values()).map((group) => ({
      id: group.id,
      name: group.name,
      ownerKey: group.ownerKey,
      admins: Array.from(group.admins || []),
      members: Array.from(group.members || []),
      createdAt: group.createdAt || "",
      updatedAt: group.updatedAt || "",
    })),
    scheduledMessages: Array.from(scheduledMessages.values()).map((entry) => ({
      id: entry.id,
      fromKey: entry.fromKey,
      toType: normalizeChatKind(entry.toType),
      toKey: entry.toKey,
      text: toDisplayName(entry.text),
      attachment: entry.attachment || null,
      replyTo: entry.replyTo || null,
      sendAt: entry.sendAt,
      createdAt: entry.createdAt,
      clientTempId: toDisplayName(entry.clientTempId),
    })),
  };
}

function serializeAuthRuntimeState() {
  return {
    refreshSessions: Array.from(refreshSessions.entries()).map(([tokenId, entry]) => ({
      tokenId: toDisplayName(tokenId),
      userKey: normalizeName(entry?.userKey),
      expiresAt: Number(entry?.expiresAt) || 0,
      remember: Boolean(entry?.remember),
    })),
    authUserAliases: Array.from(authUserAliases.entries()).map(([oldKey, entry]) => ({
      oldKey: normalizeName(oldKey),
      newKey: normalizeName(entry?.newKey),
      expiresAt: Number(entry?.expiresAt) || 0,
    })),
    savedAt: nowIso(),
  };
}

function applyLoadedAuthRuntimeState(parsed) {
  refreshSessions.clear();
  refreshByUser.clear();
  authUserAliases.clear();

  const now = Date.now();
  const rawSessions = Array.isArray(parsed?.refreshSessions) ? parsed.refreshSessions : [];
  for (const rawEntry of rawSessions) {
    const tokenId = toDisplayName(rawEntry?.tokenId || rawEntry?.jti || rawEntry?.id || rawEntry?.key);
    const userKey = normalizeName(rawEntry?.userKey || rawEntry?.sub || "");
    const expiresAt = Number(rawEntry?.expiresAt);
    if (!tokenId || !userKey || !users.has(userKey) || !Number.isFinite(expiresAt) || expiresAt <= now) {
      continue;
    }
    const entry = {
      userKey,
      expiresAt,
      remember: Boolean(rawEntry?.remember),
    };
    refreshSessions.set(tokenId, entry);
    if (!refreshByUser.has(userKey)) {
      refreshByUser.set(userKey, new Set());
    }
    refreshByUser.get(userKey).add(tokenId);
  }

  const rawAliases = Array.isArray(parsed?.authUserAliases) ? parsed.authUserAliases : [];
  for (const rawAlias of rawAliases) {
    const oldKey = normalizeName(rawAlias?.oldKey || rawAlias?.key || rawAlias?.from || "");
    const newKey = normalizeName(rawAlias?.newKey || rawAlias?.to || "");
    const expiresAt = Number(rawAlias?.expiresAt);
    if (!oldKey || !newKey || !users.has(newKey) || !Number.isFinite(expiresAt) || expiresAt <= now) {
      continue;
    }
    authUserAliases.set(oldKey, { newKey, expiresAt });
  }

  pruneExpiredAuthState();
}

async function persistFileNow() {
  const payload = JSON.stringify(serializeState(), null, 2);
  await fsp.mkdir(DATA_DIR, { recursive: true });
  await fsp.writeFile(DATA_FILE, payload, "utf8");
}

async function persistAuthStateNow() {
  const payload = JSON.stringify(serializeAuthRuntimeState(), null, 2);
  await fsp.mkdir(DATA_DIR, { recursive: true });
  await fsp.writeFile(AUTH_STATE_FILE, payload, "utf8");
}

function hasMongoStorage() {
  return Boolean(mongoUsersCollection && mongoConversationsCollection && mongoMessagesCollection);
}

async function bulkWriteInChunks(collection, operations, chunkSize = 500) {
  if (!collection || !Array.isArray(operations) || operations.length === 0) return;
  for (let i = 0; i < operations.length; i += chunkSize) {
    const chunk = operations.slice(i, i + chunkSize);
    // Keep unordered writes to tolerate individual bad docs without aborting the batch.
    await collection.bulkWrite(chunk, { ordered: false });
  }
}

function buildConversationDoc(entry, snapshotId, updatedAt) {
  const key = toDisplayName(entry?.key);
  if (!key) return null;
  const [userA = "", userB = ""] = key.split("::");
  const messages = Array.isArray(entry?.messages) ? entry.messages : [];
  const lastMessage = messages.length ? messages[messages.length - 1] : null;
  return {
    _id: key,
    userA,
    userB,
    messageCount: messages.length,
    lastTimestamp: toDisplayName(lastMessage?.timestamp),
    snapshotId,
    updatedAt,
  };
}

function buildMessageDoc(conversationKey, rawMessage, orderIndex, snapshotId, updatedAt) {
  const key = toDisplayName(conversationKey);
  if (!key) return null;
  const message = hydrateMessage(rawMessage);
  const messageId = toDisplayName(message.id) || `${Date.now()}-${orderIndex}`;
  const messageDocId = `${key}::${messageId}`;
  return {
    _id: messageDocId,
    conversationKey: key,
    messageId,
    timestamp: toDisplayName(message.timestamp),
    message,
    snapshotId,
    updatedAt,
  };
}

async function persistMongoNow() {
  if (!hasMongoStorage()) {
    return;
  }

  const state = serializeState();
  const snapshotId = `${Date.now()}-${crypto.randomBytes(6).toString("hex")}`;
  const updatedAt = new Date();

  const userOps = state.users
    .filter((entry) => normalizeName(entry?.key || entry?.username))
    .map((entry) => {
      const key = normalizeName(entry.key || entry.username);
      return {
        updateOne: {
          filter: { _id: key },
          update: {
            $set: {
              username: toDisplayName(entry.username),
              email: normalizeEmail(entry.email),
              googleUid: toDisplayName(entry.googleUid),
              friends: Array.isArray(entry.friends) ? entry.friends : [],
              groups: Array.isArray(entry.groups) ? entry.groups : [],
              requests: Array.isArray(entry.requests) ? entry.requests : [],
              unread: Array.isArray(entry.unread) ? entry.unread : [],
              blockedUsers: Array.isArray(entry.blockedUsers) ? entry.blockedUsers : [],
              mutedUsers: Array.isArray(entry.mutedUsers) ? entry.mutedUsers : [],
              pushSubs: Array.isArray(entry.pushSubs) ? entry.pushSubs : [],
              isRegistered: Boolean(entry.isRegistered),
              passwordSalt: toDisplayName(entry.passwordSalt),
              passwordHash: toDisplayName(entry.passwordHash),
              avatarId: toDisplayName(entry.avatarId),
              age: toDisplayName(entry.age),
              gender: toDisplayName(entry.gender),
              displayName: toDisplayName(entry.displayName),
              bio: toDisplayName(entry.bio),
              createdAt: toDisplayName(entry.createdAt),
              lastSeenAt: toDisplayName(entry.lastSeenAt),
              presenceMode: normalizePresenceMode(entry.presenceMode),
              snapshotId,
              updatedAt,
            },
          },
          upsert: true,
        },
      };
    });
  await bulkWriteInChunks(mongoUsersCollection, userOps);
  await mongoUsersCollection.deleteMany({ snapshotId: { $ne: snapshotId } });

  const conversationOps = [];
  let messageOrder = 0;
  let pendingMessageOps = [];

  for (const entry of state.conversations) {
    const conversationDoc = buildConversationDoc(entry, snapshotId, updatedAt);
    if (conversationDoc) {
      conversationOps.push({
        updateOne: {
          filter: { _id: conversationDoc._id },
          update: { $set: conversationDoc },
          upsert: true,
        },
      });
    }

    const key = toDisplayName(entry?.key);
    const messages = Array.isArray(entry?.messages) ? entry.messages : [];
    for (const rawMessage of messages) {
      const messageDoc = buildMessageDoc(key, rawMessage, messageOrder++, snapshotId, updatedAt);
      if (!messageDoc) continue;
      pendingMessageOps.push({
        updateOne: {
          filter: { _id: messageDoc._id },
          update: { $set: messageDoc },
          upsert: true,
        },
      });
      if (pendingMessageOps.length >= 500) {
        await bulkWriteInChunks(mongoMessagesCollection, pendingMessageOps);
        pendingMessageOps = [];
      }
    }
  }

  await bulkWriteInChunks(mongoConversationsCollection, conversationOps);
  await mongoConversationsCollection.deleteMany({ snapshotId: { $ne: snapshotId } });
  if (pendingMessageOps.length) {
    await bulkWriteInChunks(mongoMessagesCollection, pendingMessageOps);
  }
  await mongoMessagesCollection.deleteMany({ snapshotId: { $ne: snapshotId } });

  if (mongoLegacyCollection) {
    await mongoLegacyCollection.updateOne(
      { _id: "main" },
      {
        $set: {
          _id: "main",
          migratedToCollections: true,
          updatedAt,
          retentionDays: CHAT_RETENTION_DAYS,
          groups: state.groups || [],
          scheduledMessages: state.scheduledMessages || [],
        },
      },
      { upsert: true }
    );
  }
}

async function persistNow() {
  if (hasMongoStorage()) {
    await persistMongoNow();
    return;
  }

  await persistFileNow();
}

function schedulePersist() {
  if (persistTimer) {
    clearTimeout(persistTimer);
  }

  persistTimer = setTimeout(() => {
    persistTimer = null;
    persistInFlight = persistInFlight
      .then(() => persistNow())
      .catch((err) => {
        console.error("Failed to persist chat state:", err);
      });
  }, 180);
}

function scheduleAuthStatePersist() {
  if (authPersistTimer) {
    clearTimeout(authPersistTimer);
  }

  authPersistTimer = setTimeout(() => {
    authPersistTimer = null;
    authPersistInFlight = authPersistInFlight
      .then(() => persistAuthStateNow())
      .catch((err) => {
        console.error("Failed to persist auth session state:", err);
      });
  }, 120);
}

function createResetToken() {
  const value = Math.floor(100000 + Math.random() * 900000);
  return String(value);
}

function createResetTokenId() {
  return crypto.randomBytes(12).toString("hex");
}

function createResetTokenHash(token, salt) {
  return crypto
    .createHmac("sha256", AUTH_SECRET)
    .update(`${toDisplayName(token)}:${toDisplayName(salt)}`)
    .digest("hex");
}

function dropPasswordResetTokenById(tokenId) {
  const id = toDisplayName(tokenId);
  if (!id) return;
  const entry = passwordResetTokens.get(id);
  if (!entry) return;
  passwordResetTokens.delete(id);
  if (entry.userKey && passwordResetByUser.get(entry.userKey) === id) {
    passwordResetByUser.delete(entry.userKey);
  }
}

function pruneExpiredPasswordResetTokens() {
  const now = Date.now();
  for (const [tokenId, entry] of passwordResetTokens.entries()) {
    if (!entry || Number(entry.expiresAt) <= now) {
      dropPasswordResetTokenById(tokenId);
    }
  }
  for (const [userKey, rate] of passwordResetRate.entries()) {
    if (!rate || now - Number(rate.windowStartedAt || 0) > PASSWORD_RESET_WINDOW_MS) {
      passwordResetRate.delete(userKey);
    }
  }
}

function canIssuePasswordReset(userKey) {
  const key = normalizeName(userKey);
  if (!key) {
    return { allowed: false, message: "Please wait before requesting another code." };
  }
  const now = Date.now();
  const state = passwordResetRate.get(key) || {
    windowStartedAt: now,
    sentCount: 0,
    lastSentAt: 0,
  };

  if (now - state.windowStartedAt > PASSWORD_RESET_WINDOW_MS) {
    state.windowStartedAt = now;
    state.sentCount = 0;
  }
  if (now - state.lastSentAt < PASSWORD_RESET_RESEND_COOLDOWN_MS) {
    return { allowed: false, message: "Please wait before requesting another code." };
  }
  if (state.sentCount >= PASSWORD_RESET_MAX_PER_WINDOW) {
    return { allowed: false, message: "Too many reset requests. Try again later." };
  }
  return { allowed: true, state };
}

function markPasswordResetIssued(userKey, state) {
  const key = normalizeName(userKey);
  if (!key || !state) return;
  const now = Date.now();
  state.sentCount = Number(state.sentCount || 0) + 1;
  state.lastSentAt = now;
  if (!state.windowStartedAt) state.windowStartedAt = now;
  passwordResetRate.set(key, state);
}

function dropEmailChangeTokenById(tokenId) {
  const id = toDisplayName(tokenId);
  if (!id) return;
  const entry = emailChangeTokens.get(id);
  if (!entry) return;
  emailChangeTokens.delete(id);
  if (entry.userKey && emailChangeByUser.get(entry.userKey) === id) {
    emailChangeByUser.delete(entry.userKey);
  }
}

function pruneExpiredEmailChangeTokens() {
  const now = Date.now();
  for (const [tokenId, entry] of emailChangeTokens.entries()) {
    if (!entry || Number(entry.expiresAt) <= now) {
      dropEmailChangeTokenById(tokenId);
    }
  }
  for (const [userKey, rate] of emailChangeRate.entries()) {
    if (!rate || now - Number(rate.windowStartedAt || 0) > EMAIL_CHANGE_WINDOW_MS) {
      emailChangeRate.delete(userKey);
    }
  }
}

function canIssueEmailChangeCode(userKey) {
  const key = normalizeName(userKey);
  if (!key) {
    return { allowed: false, message: "Please wait before requesting another code." };
  }
  const now = Date.now();
  const state = emailChangeRate.get(key) || {
    windowStartedAt: now,
    sentCount: 0,
    lastSentAt: 0,
  };

  if (now - state.windowStartedAt > EMAIL_CHANGE_WINDOW_MS) {
    state.windowStartedAt = now;
    state.sentCount = 0;
  }
  if (now - state.lastSentAt < EMAIL_CHANGE_RESEND_COOLDOWN_MS) {
    return { allowed: false, message: "Please wait before requesting another code." };
  }
  if (state.sentCount >= EMAIL_CHANGE_MAX_PER_WINDOW) {
    return { allowed: false, message: "Too many verification requests. Try again later." };
  }
  return { allowed: true, state };
}

function markEmailChangeCodeIssued(userKey, state) {
  const key = normalizeName(userKey);
  if (!key || !state) return;
  const now = Date.now();
  state.sentCount = Number(state.sentCount || 0) + 1;
  state.lastSentAt = now;
  if (!state.windowStartedAt) state.windowStartedAt = now;
  emailChangeRate.set(key, state);
}

function isPasswordResetDeliveryAvailable() {
  return Boolean(passwordResetMailer) || PASSWORD_RESET_LOG_CODES;
}

async function dispatchPasswordResetCode(user, code) {
  const email = normalizeEmail(user?.email);
  const resetCode = toDisplayName(code);
  if (!email || !resetCode) return false;

  if (!passwordResetMailer) {
    if (PASSWORD_RESET_LOG_CODES) {
      console.log(`[Password reset code] ${email}: ${resetCode}`);
      return true;
    }
    return false;
  }

  const recipientName = toDisplayName(user?.name || user?.username) || "there";
  const expiresMinutes = Math.max(1, Math.ceil(PASSWORD_RESET_CODE_TTL_MS / (60 * 1000)));
  const text = [
    `Hi ${recipientName},`,
    "",
    "Use this code to reset your Novyn password:",
    resetCode,
    "",
    `This code expires in ${expiresMinutes} minute(s).`,
    "If you didn't request this reset, you can ignore this email.",
    "",
    "Novyn Team",
  ].join("\n");

  try {
    const mailPayload = {
      from: SMTP_FROM,
      to: email,
      subject: PASSWORD_RESET_EMAIL_SUBJECT,
      text,
      ...(SMTP_REPLY_TO ? { replyTo: SMTP_REPLY_TO } : {}),
    };
    await Promise.race([
      passwordResetMailer.sendMail(mailPayload),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error("SMTP send timeout")), SMTP_SEND_TIMEOUT_MS);
      }),
    ]);
    return true;
  } catch (err) {
    console.warn(`Failed to send password reset email to ${email}:`, err?.message || err);
    if (PASSWORD_RESET_LOG_CODES) {
      console.log(`[Password reset code fallback] ${email}: ${resetCode}`);
      return true;
    }
    return false;
  }
}

function maskEmailAddress(email) {
  const value = normalizeEmail(email || "");
  if (!value || !value.includes("@")) return value;
  const [local, domain] = value.split("@");
  if (!domain) return value;
  if (!local) return `***@${domain}`;
  if (local.length === 1) return `*@${domain}`;
  if (local.length === 2) return `${local[0]}*@${domain}`;
  return `${local[0]}${"*".repeat(local.length - 2)}${local[local.length - 1]}@${domain}`;
}

async function dispatchEmailChangeCode(user, nextEmail, code) {
  const email = normalizeEmail(nextEmail);
  const verifyCode = toDisplayName(code);
  if (!email || !verifyCode) return false;

  if (!passwordResetMailer) {
    if (PASSWORD_RESET_LOG_CODES) {
      console.log(`[Email change code] ${email} (${user?.username || "user"}): ${verifyCode}`);
      return true;
    }
    return false;
  }

  const recipientName = toDisplayName(user?.displayName || user?.username) || "there";
  const expiresMinutes = Math.max(1, Math.ceil(EMAIL_CHANGE_CODE_TTL_MS / (60 * 1000)));
  const text = [
    `Hi ${recipientName},`,
    "",
    "Use this code to verify your new Novyn email address:",
    verifyCode,
    "",
    `This code expires in ${expiresMinutes} minute(s).`,
    "If you didn't request this change, you can ignore this email.",
    "",
    "Novyn Team",
  ].join("\n");

  try {
    const mailPayload = {
      from: SMTP_FROM,
      to: email,
      subject: EMAIL_CHANGE_EMAIL_SUBJECT,
      text,
      ...(SMTP_REPLY_TO ? { replyTo: SMTP_REPLY_TO } : {}),
    };
    await Promise.race([
      passwordResetMailer.sendMail(mailPayload),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error("SMTP send timeout")), SMTP_SEND_TIMEOUT_MS);
      }),
    ]);
    return true;
  } catch (err) {
    console.warn(`Failed to send email-change code to ${email}:`, err?.message || err);
    if (PASSWORD_RESET_LOG_CODES) {
      console.log(`[Email change code fallback] ${email}: ${verifyCode}`);
      return true;
    }
    return false;
  }
}

function normalizePushSubscription(raw) {
  const endpoint = toDisplayName(raw?.endpoint);
  const keys = raw?.keys || {};
  const p256dh = toDisplayName(keys.p256dh);
  const auth = toDisplayName(keys.auth);
  if (!endpoint || !p256dh || !auth) return null;
  return {
    endpoint,
    keys: { p256dh, auth },
    expirationTime:
      raw?.expirationTime === null || raw?.expirationTime === undefined
        ? null
        : raw.expirationTime,
  };
}

function upsertPushSubscription(user, raw) {
  if (!user) return false;
  const normalized = normalizePushSubscription(raw);
  if (!normalized) return false;
  if (!Array.isArray(user.pushSubs)) user.pushSubs = [];
  const existingIndex = user.pushSubs.findIndex((sub) => sub.endpoint === normalized.endpoint);
  if (existingIndex >= 0) {
    user.pushSubs[existingIndex] = normalized;
    return true;
  }
  user.pushSubs.push(normalized);
  return true;
}

function removePushSubscription(user, endpoint) {
  if (!user || !Array.isArray(user.pushSubs) || !endpoint) return false;
  const before = user.pushSubs.length;
  user.pushSubs = user.pushSubs.filter((sub) => sub.endpoint !== endpoint);
  return user.pushSubs.length !== before;
}

function detachSubscriptionFromAll(endpoint, exceptKey) {
  if (!endpoint) return false;
  let changed = false;
  for (const [key, user] of users.entries()) {
    if (exceptKey && key === exceptKey) continue;
    if (removePushSubscription(user, endpoint)) {
      changed = true;
    }
  }
  return changed;
}

function formatPushBody(text, fallback = "New message") {
  const cleaned = String(text || "").replace(/\s+/g, " ").trim();
  if (!cleaned) return fallback;
  if (cleaned.length <= 120) return cleaned;
  return `${cleaned.slice(0, 117)}...`;
}

async function sendPushToUser(userKey, payload) {
  if (!pushEnabled || !userKey) return;
  const user = users.get(userKey);
  if (!user || !Array.isArray(user.pushSubs) || user.pushSubs.length === 0) return;

  const body = JSON.stringify(payload || {});
  const remaining = [];
  let changed = false;

  for (const sub of user.pushSubs) {
    try {
      await webpush.sendNotification(sub, body);
      remaining.push(sub);
    } catch (err) {
      const status = err?.statusCode;
      if (status === 404 || status === 410) {
        changed = true;
        continue;
      }
      console.warn("Push notification failed:", status || err?.message || err);
      remaining.push(sub);
    }
  }

  if (changed) {
    user.pushSubs = remaining;
    schedulePersist();
  }
}

async function appendAbuseReport(entry) {
  try {
    await fsp.mkdir(DATA_DIR, { recursive: true });
    await fsp.appendFile(ABUSE_REPORT_FILE, `${JSON.stringify(entry)}\n`, "utf8");
  } catch (err) {
    console.warn("Failed to persist abuse report:", err?.message || err);
  }
}

function hydrateMessage(rawMessage) {
  const message = rawMessage || {};
  const from = toDisplayName(message.from);
  const to = toDisplayName(message.to);
  const fromKey = normalizeName(message.fromKey || from);
  const toType = normalizeChatKind(message.toType || (message.groupId ? "group" : "friend"));
  const toKey = toType === "group"
    ? normalizeGroupId(message.groupId || message.toKey || to)
    : normalizeName(message.toKey || to);
  const seenBy = Array.isArray(message.seenBy)
    ? Array.from(new Set(message.seenBy.map(normalizeName).filter(Boolean)))
    : [];

  const hydrated = {
    id: toDisplayName(message.id) || createMessageId(),
    from: from || fromKey,
    to: to || toKey,
    fromKey,
    toKey,
    toType,
    groupId: toType === "group" ? toKey : "",
    text: withUploadToken(message.text),
    timestamp: toDisplayName(message.timestamp) || nowIso(),
    deliveredAt: toDisplayName(message.deliveredAt) || null,
    seenAt: toDisplayName(message.seenAt) || null,
    deletedAt: toDisplayName(message.deletedAt) || null,
    editedAt: toDisplayName(message.editedAt) || null,
    pinnedAt: toDisplayName(message.pinnedAt) || null,
    pinnedBy: toDisplayName(message.pinnedBy) || "",
    reactions: message.reactions || {},
    poll: message.poll || null,
    game: message.game || null,
    ciphertext: toDisplayName(message.ciphertext) || undefined,
    iv: toDisplayName(message.iv) || undefined,
    isEncrypted: Boolean(message.isEncrypted),
  };
  if (toType === "group") {
    hydrated.seenBy = seenBy.length ? seenBy : (fromKey ? [fromKey] : []);
  }
  const attachment = sanitizeMessageAttachment(message.attachment, hydrated.text);
  if (attachment) hydrated.attachment = attachment;
  if (hydrated.deletedAt && !hydrated.text) {
    hydrated.text = DELETED_MESSAGE_TEXT;
  }
  if (message.replyTo && message.replyTo.id) {
    hydrated.replyTo = {
      id: toDisplayName(message.replyTo.id),
      from: toDisplayName(message.replyTo.from),
      text: toDisplayName(message.replyTo.text),
    };
  }
  return hydrated;
}

function applyLoadedState(parsed) {
  users.clear();
  conversations.clear();
  groups.clear();
  scheduledMessages.clear();
  for (const timer of scheduledMessageTimers.values()) {
    clearTimeout(timer);
  }
  scheduledMessageTimers.clear();

  for (const entry of parsed?.users || []) {
    const key = normalizeName(entry?.key || entry?.username);
    if (!key) continue;

    const user = createUserRecord(entry.username || key);
    user.friends = new Set((entry.friends || []).map(normalizeName).filter(Boolean));
    user.groups = new Set((entry.groups || []).map(normalizeGroupId).filter(Boolean));
    user.requests = new Set((entry.requests || []).map(normalizeName).filter(Boolean));
    user.blockedUsers = new Set((entry.blockedUsers || []).map(normalizeName).filter(Boolean));
    user.mutedUsers = new Set((entry.mutedUsers || []).map(normalizeName).filter(Boolean));
    user.isRegistered = Boolean(entry.isRegistered);
    user.passwordSalt = toDisplayName(entry.passwordSalt);
    user.passwordHash = toDisplayName(entry.passwordHash);
    user.email = normalizeEmail(entry.email);
    user.googleUid = toDisplayName(entry.googleUid);
    user.avatarId = toDisplayName(entry.avatarId);
    user.age = toDisplayName(entry.age);
    user.gender = toDisplayName(entry.gender);
    user.displayName = toDisplayName(entry.displayName);
    user.bio = toDisplayName(entry.bio);
    user.createdAt = toDisplayName(entry.createdAt);
    user.lastSeenAt = toDisplayName(entry.lastSeenAt);
    user.presenceMode = normalizePresenceMode(entry.presenceMode);
    user.publicKey = toDisplayName(entry.publicKey);
    user.pushSubs = Array.isArray(entry.pushSubs)
      ? entry.pushSubs.filter((sub) => sub && sub.endpoint && sub.keys)
      : [];

    for (const unreadEntry of entry.unread || []) {
      if (!Array.isArray(unreadEntry) || unreadEntry.length < 2) continue;
      const friendKey = normalizeName(unreadEntry[0]);
      if (!friendKey) continue;
      const count = Number(unreadEntry[1]);
      user.unread.set(friendKey, Number.isFinite(count) ? Math.max(0, Math.floor(count)) : 0);
    }

    users.set(key, user);
  }

  for (const entry of parsed?.conversations || []) {
    const key = toDisplayName(entry?.key);
    if (!key) continue;
    const messages = Array.isArray(entry.messages)
      ? entry.messages
          .map(hydrateMessage)
          .filter((message) => message.fromKey && message.toKey && (message.text || message.attachment))
      : [];
    conversations.set(key, messages);
  }

  for (const entry of parsed?.groups || []) {
    const id = normalizeGroupId(entry?.id);
    if (!id) continue;
    const ownerKey = normalizeName(entry?.ownerKey);
    const members = new Set((entry?.members || []).map(normalizeName).filter((memberKey) => users.has(memberKey)));
    if (!members.size) continue;
    const group = createGroupRecord(entry?.name || id, ownerKey, Array.from(members));
    group.id = id;
    group.createdAt = toDisplayName(entry?.createdAt) || group.createdAt;
    group.updatedAt = toDisplayName(entry?.updatedAt) || group.updatedAt;
    group.ownerKey = members.has(ownerKey) ? ownerKey : Array.from(members)[0];
    group.admins = new Set(
      (entry?.admins || [])
        .map(normalizeName)
        .filter((adminKey) => members.has(adminKey))
    );
    if (!group.admins.size && group.ownerKey) group.admins.add(group.ownerKey);
    group.members = members;
    groups.set(id, group);
  }

  for (const group of groups.values()) {
    for (const memberKey of group.members) {
      const user = users.get(memberKey);
      if (!user) continue;
      if (!(user.groups instanceof Set)) user.groups = new Set();
      user.groups.add(group.id);
      if (!(user.unread instanceof Map)) user.unread = new Map();
      if (!user.unread.has(group.id)) user.unread.set(group.id, 0);
    }
  }

  for (const user of users.values()) {
    if (!(user.groups instanceof Set)) continue;
    for (const groupKey of Array.from(user.groups)) {
      if (!groups.has(normalizeGroupId(groupKey))) {
        user.groups.delete(groupKey);
        user.unread?.delete(groupKey);
      }
    }
  }

  for (const rawEntry of parsed?.scheduledMessages || []) {
    const id = toDisplayName(rawEntry?.id) || createMessageId();
    const fromKey = normalizeName(rawEntry?.fromKey);
    const toType = normalizeChatKind(rawEntry?.toType || (rawEntry?.toType === "group" ? "group" : "friend"));
    const toKey = toType === "group"
      ? normalizeGroupId(rawEntry?.toKey)
      : normalizeName(rawEntry?.toKey);
    const text = withUploadToken(rawEntry?.text);
    const sendAt = toDisplayName(rawEntry?.sendAt);
    if (!fromKey || !toKey || !text || !sendAt) continue;
    const when = Date.parse(sendAt);
    if (!Number.isFinite(when)) continue;
    const attachment = sanitizeMessageAttachment(rawEntry?.attachment, text);
    const replyTo = rawEntry?.replyTo && rawEntry.replyTo.id
      ? {
          id: toDisplayName(rawEntry.replyTo.id),
          from: toDisplayName(rawEntry.replyTo.from),
          text: toDisplayName(rawEntry.replyTo.text),
        }
      : null;
    scheduledMessages.set(id, {
      id,
      fromKey,
      toType,
      toKey,
      text,
      attachment: attachment || null,
      replyTo,
      sendAt: new Date(when).toISOString(),
      createdAt: toDisplayName(rawEntry?.createdAt) || nowIso(),
      clientTempId: toDisplayName(rawEntry?.clientTempId || ""),
    });
  }
}

// Older encrypted messages were stored with both ciphertext and the original body.
// The ciphertext is sufficient for clients to decrypt, so scrub only the redundant
// plaintext when both cryptographic fields are present.
function scrubEncryptedMessagePlaintext() {
  let scrubbed = 0;
  for (const conversation of conversations.values()) {
    for (const message of conversation) {
      if (!message?.isEncrypted || !message.ciphertext || !message.iv) continue;
      if (message.text !== ENCRYPTED_MESSAGE_PLACEHOLDER) {
        message.text = ENCRYPTED_MESSAGE_PLACEHOLDER;
        scrubbed += 1;
      }
      if (message.replyTo?.text && message.replyTo.text !== ENCRYPTED_MESSAGE_PLACEHOLDER) {
        message.replyTo.text = ENCRYPTED_MESSAGE_PLACEHOLDER;
        scrubbed += 1;
      }
    }
  }
  return scrubbed;
}

async function loadStateFromFile() {
  if (!fs.existsSync(DATA_FILE)) {
    return false;
  }

  try {
    const raw = await fsp.readFile(DATA_FILE, "utf8");
    const parsed = JSON.parse(raw);
    applyLoadedState(parsed);
    return true;
  } catch (err) {
    console.error("Failed to load persisted chat state from file:", err);
    return false;
  }
}

async function loadAuthStateFromFile() {
  if (!fs.existsSync(AUTH_STATE_FILE)) {
    return false;
  }
  try {
    const raw = await fsp.readFile(AUTH_STATE_FILE, "utf8");
    const parsed = JSON.parse(raw);
    applyLoadedAuthRuntimeState(parsed);
    return true;
  } catch (err) {
    console.error("Failed to load persisted auth session state:", err);
    return false;
  }
}

function toSerializedUserEntry(doc) {
  const key = normalizeName(doc?._id || doc?.key || doc?.username);
  if (!key) return null;
  return {
    key,
    username: toDisplayName(doc?.username || key),
    email: normalizeEmail(doc?.email),
    googleUid: toDisplayName(doc?.googleUid),
    friends: Array.isArray(doc?.friends) ? doc.friends : [],
    groups: Array.isArray(doc?.groups) ? doc.groups : [],
    requests: Array.isArray(doc?.requests) ? doc.requests : [],
    unread: Array.isArray(doc?.unread) ? doc.unread : [],
    blockedUsers: Array.isArray(doc?.blockedUsers) ? doc.blockedUsers : [],
    mutedUsers: Array.isArray(doc?.mutedUsers) ? doc.mutedUsers : [],
    pushSubs: Array.isArray(doc?.pushSubs) ? doc.pushSubs : [],
    isRegistered: Boolean(doc?.isRegistered),
    passwordSalt: toDisplayName(doc?.passwordSalt),
    passwordHash: toDisplayName(doc?.passwordHash),
    avatarId: toDisplayName(doc?.avatarId),
    age: toDisplayName(doc?.age),
    gender: toDisplayName(doc?.gender),
    displayName: toDisplayName(doc?.displayName),
    bio: toDisplayName(doc?.bio),
    createdAt: toDisplayName(doc?.createdAt),
    lastSeenAt: toDisplayName(doc?.lastSeenAt),
    presenceMode: normalizePresenceMode(doc?.presenceMode),
    publicKey: toDisplayName(doc?.publicKey),
  };
}

function toSerializedMessageEntry(doc) {
  if (doc?.message && typeof doc.message === "object") {
    return doc.message;
  }
  return {
    id: toDisplayName(doc?.messageId || doc?.id),
    from: toDisplayName(doc?.from),
    to: toDisplayName(doc?.to),
    fromKey: normalizeName(doc?.fromKey),
    toKey: normalizeName(doc?.toKey),
    toType: normalizeChatKind(doc?.toType),
    groupId: normalizeGroupId(doc?.groupId),
    text: toDisplayName(doc?.text),
    timestamp: toDisplayName(doc?.timestamp),
    deliveredAt: toDisplayName(doc?.deliveredAt),
    seenAt: toDisplayName(doc?.seenAt),
    deletedAt: toDisplayName(doc?.deletedAt),
    editedAt: toDisplayName(doc?.editedAt),
    pinnedAt: toDisplayName(doc?.pinnedAt),
    pinnedBy: toDisplayName(doc?.pinnedBy),
    reactions: doc?.reactions || {},
    replyTo: doc?.replyTo || undefined,
    attachment: doc?.attachment || undefined,
    poll: doc?.poll || undefined,
    game: doc?.game || undefined,
    ciphertext: toDisplayName(doc?.ciphertext) || undefined,
    iv: toDisplayName(doc?.iv) || undefined,
    isEncrypted: Boolean(doc?.isEncrypted),
    seenBy: Array.isArray(doc?.seenBy) ? doc.seenBy : undefined,
  };
}

async function loadStateFromMongoCollections() {
  if (!hasMongoStorage()) return false;

  // A snapshot write spans multiple collections. Load one complete snapshot,
  // rather than accidentally mixing old/new documents after a crash.
  const latestCandidates = await Promise.all([
    mongoUsersCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
    mongoConversationsCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
    mongoMessagesCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
  ]);
  const latest = latestCandidates
    .filter(Boolean)
    .sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")))[0];
  const snapshotId = toDisplayName(latest?.snapshotId);
  const snapshotFilter = snapshotId ? { snapshotId } : {};

  const [userDocs, conversationDocs, messageDocs, legacyDoc] = await Promise.all([
    mongoUsersCollection.find(snapshotFilter, { projection: { snapshotId: 0, updatedAt: 0 } }).toArray(),
    mongoConversationsCollection.find(snapshotFilter, { projection: { _id: 1 } }).toArray(),
    mongoMessagesCollection
      .find(snapshotFilter, { projection: { _id: 0, snapshotId: 0, updatedAt: 0 } })
      .sort({ conversationKey: 1, timestamp: 1, messageId: 1 })
      .toArray(),
    mongoLegacyCollection
      ? mongoLegacyCollection.findOne(
          { _id: "main" },
          { projection: { groups: 1, scheduledMessages: 1 } }
        )
      : null,
  ]);

  if (!userDocs.length && !conversationDocs.length && !messageDocs.length) return false;

  const messageMap = new Map();
  for (const doc of messageDocs) {
    const conversationKey = toDisplayName(doc?.conversationKey);
    if (!conversationKey) continue;
    if (!messageMap.has(conversationKey)) messageMap.set(conversationKey, []);
    messageMap.get(conversationKey).push(toSerializedMessageEntry(doc));
  }

  const conversationKeySet = new Set();
  for (const doc of conversationDocs) {
    const key = toDisplayName(doc?._id);
    if (key) conversationKeySet.add(key);
  }
  for (const key of messageMap.keys()) conversationKeySet.add(key);

  const parsed = {
    users: userDocs.map(toSerializedUserEntry).filter(Boolean),
    conversations: Array.from(conversationKeySet).sort().map((key) => ({
      key,
      messages: messageMap.get(key) || [],
    })),
    groups: Array.isArray(legacyDoc?.groups) ? legacyDoc.groups : [],
    scheduledMessages: Array.isArray(legacyDoc?.scheduledMessages) ? legacyDoc.scheduledMessages : [],
  };

  applyLoadedState(parsed);
  return true;
}

async function loadStateFromLegacyMongoDocument() {
  if (!mongoLegacyCollection) return false;
  const doc = await mongoLegacyCollection.findOne({ _id: "main" });
  if (!doc?.state) return false;
  applyLoadedState(doc.state);
  return true;
}

async function ensureMongoIndexes() {
  if (!hasMongoStorage()) return;
  await Promise.all([
    mongoUsersCollection.createIndex({ email: 1 }, { name: "email_idx" }),
    mongoConversationsCollection.createIndex({ updatedAt: -1 }, { name: "updated_at_idx" }),
    mongoMessagesCollection.createIndex(
      { conversationKey: 1, timestamp: 1, messageId: 1 },
      { name: "conversation_time_idx" }
    ),
    mongoMessagesCollection.createIndex({ messageId: 1 }, { name: "message_id_idx" }),
  ]);
}

async function initializeMongo() {
  if (!MONGODB_URI) return;

  try {
    mongoStorage = createMongoStorage({
      uri: MONGODB_URI,
      dbName: MONGODB_DB,
      legacyCollectionName: MONGODB_LEGACY_COLLECTION,
      usersCollectionName: MONGODB_USERS_COLLECTION,
      conversationsCollectionName: MONGODB_CONVERSATIONS_COLLECTION,
      messagesCollectionName: MONGODB_MESSAGES_COLLECTION,
    });
    await mongoStorage.connect();

    const collections = mongoStorage.collections;
    mongoLegacyCollection = collections.legacy;
    mongoUsersCollection = collections.users;
    mongoConversationsCollection = collections.conversations;
    mongoMessagesCollection = collections.messages;

    console.log(`Connected to MongoDB database: ${MONGODB_DB}`);
  } catch (err) {
    mongoStorage = null;
    mongoLegacyCollection = null;
    mongoUsersCollection = null;
    mongoConversationsCollection = null;
    mongoMessagesCollection = null;
    console.error("Failed to connect MongoDB, falling back to local file storage:", err);
  }
}

async function loadState() {
  await initializeMongo();
  let loaded = false;

  if (hasMongoStorage()) {
    try {
      loaded = await loadStateFromMongoCollections();
      if (!loaded) {
        loaded = await loadStateFromLegacyMongoDocument();
        if (loaded) {
          await persistMongoNow();
          console.log("Migrated legacy chat_state Mongo document into split collections.");
        }
      }
      if (!loaded) {
        const loadedFromFile = await loadStateFromFile();
        if (loadedFromFile) {
          loaded = true;
          await persistMongoNow();
          console.log("Migrated local file state into split Mongo collections.");
        }
      }
    } catch (err) {
      console.error("Failed to load chat state from MongoDB collections, trying local file:", err);
    }
  }

  if (!loaded) {
    loaded = await loadStateFromFile();
  }

  if (loaded) {
    const pruned = pruneExpiredMessages();
    const scrubbed = scrubEncryptedMessagePlaintext();
    if (pruned || scrubbed) {
      await persistNow();
      if (pruned) {
        console.log(`Pruned expired messages older than ${CHAT_RETENTION_DAYS} day(s).`);
      }
      if (scrubbed) {
        console.log(`Removed plaintext from ${scrubbed} encrypted message field(s).`);
      }
    }
  }

  await loadAuthStateFromFile();
}

function getOrCreateUser(username) {
  const key = normalizeName(username);
  if (!users.has(key)) {
    users.set(key, createUserRecord(username));
    schedulePersist();
  }
  return users.get(key);
}

function isUsernameTaken(username) {
  const existing = users.get(normalizeName(username));
  return Boolean(existing?.isRegistered);
}

function findUserByEmail(email) {
  const key = normalizeEmail(email);
  if (!key) return null;
  for (const user of users.values()) {
    if (normalizeEmail(user?.email) === key) return user;
  }
  return null;
}

function findUserByGoogleUid(googleUid) {
  const key = toDisplayName(googleUid);
  if (!key) return null;
  for (const user of users.values()) {
    if (toDisplayName(user?.googleUid) === key) return user;
  }
  return null;
}

function isEmailTaken(email) {
  const existing = findUserByEmail(email);
  return Boolean(existing?.isRegistered);
}

function pickAvailableUsername(seed) {
  const base = normalizeHandleInput(seed);
  if (base && !isUsernameTaken(base)) return base;
  const suggestions = buildUsernameSuggestions(base || "user", 1);
  if (suggestions.length) return suggestions[0];
  return `user${Date.now().toString().slice(-4)}`;
}

function buildUsernameSuggestions(requestedName, count = 5) {
  const raw = normalizeName(requestedName).replace(/[^a-z0-9_]/g, "") || "user";
  const maxBaseLength = 24;
  const suggestions = [];
  let suffix = 1;

  while (suggestions.length < count && suffix < 10000) {
    const suffixText = String(suffix);
    const availableLength = maxBaseLength - suffixText.length;
    const base = raw.slice(0, Math.max(1, availableLength));
    const candidate = `${base}${suffixText}`;

    if (!isUsernameTaken(candidate)) {
      suggestions.push(candidate);
    }

    suffix += 1;
  }

  return suggestions;
}

function buildFriendSearchSuggestions(query, me, limit = 6) {
  const needle = normalizeName(query).replace(/[^a-z0-9_]/g, "");
  if (!needle) return [];
  const meKey = me ? normalizeName(me.username) : "";
  const meBlockedUsers = me?.blockedUsers instanceof Set ? me.blockedUsers : new Set();
  const results = [];

  users.forEach((user) => {
    if (!user?.isRegistered) return;
    const name = user.username || "";
    const key = normalizeName(name);
    if (!key || key === meKey) return;
    if (meBlockedUsers.has(key)) return;
    if (user?.blockedUsers instanceof Set && user.blockedUsers.has(meKey)) return;
    if (!key.includes(needle)) return;
    results.push(name);
  });

  results.sort((a, b) => {
    const aKey = normalizeName(a);
    const bKey = normalizeName(b);
    const aStarts = aKey.startsWith(needle);
    const bStarts = bKey.startsWith(needle);
    if (aStarts !== bStarts) return aStarts ? -1 : 1;
    return a.localeCompare(b);
  });

  const filtered = [];
  for (const name of results) {
    const key = normalizeName(name);
    if (!key || !meKey) {
      filtered.push(name);
      continue;
    }
    const friend = users.get(key);
    if (me.friends.has(key)) continue;
    if (me.requests.has(key)) continue;
    if (friend?.requests?.has(meKey)) continue;
    filtered.push(name);
    if (filtered.length >= limit) break;
  }
  return filtered.slice(0, limit);
}

function isBlockedBy(user, otherKey) {
  if (!user) return false;
  if (!(user.blockedUsers instanceof Set)) {
    user.blockedUsers = new Set();
  }
  return user.blockedUsers.has(normalizeName(otherKey));
}

function isMutedBy(user, otherKey) {
  if (!user) return false;
  if (!(user.mutedUsers instanceof Set)) {
    user.mutedUsers = new Set();
  }
  return user.mutedUsers.has(normalizeName(otherKey));
}

function usersAreBlocked(userAKey, userBKey) {
  const aKey = normalizeName(userAKey);
  const bKey = normalizeName(userBKey);
  if (!aKey || !bKey) return false;
  const userA = users.get(aKey);
  const userB = users.get(bKey);
  if (!userA || !userB) return false;
  return isBlockedBy(userA, bKey) || isBlockedBy(userB, aKey);
}

function getGroup(groupId) {
  const key = normalizeGroupId(groupId);
  if (!key) return null;
  return groups.get(key) || null;
}

function isGroupMember(group, userKey) {
  if (!group || !(group.members instanceof Set)) return false;
  return group.members.has(normalizeName(userKey));
}

function getGroupMemberUsernames(group) {
  if (!group || !(group.members instanceof Set)) return [];
  const names = [];
  for (const memberKey of group.members) {
    const user = users.get(memberKey);
    if (user?.username) names.push(user.username);
  }
  return names;
}

function getGroupMemberRole(group, memberKey) {
  const key = normalizeName(memberKey);
  if (!group || !key || !isGroupMember(group, key)) return "member";
  const ownerKey = normalizeName(group.ownerKey);
  if (ownerKey && key === ownerKey) return "owner";
  if (group.admins instanceof Set && group.admins.has(key)) return "admin";
  return "member";
}

function isSocketOnline(userKey) {
  return onlineUsers.has(normalizeName(userKey));
}

function getEffectivePresence(userKey) {
  const key = normalizeName(userKey);
  const user = users.get(key);
  if (!user || !isSocketOnline(key)) {
    return "offline";
  }
  const mode = normalizePresenceMode(user.presenceMode);
  return mode === "offline" ? "offline" : mode;
}

function isUserAvailable(userKey) {
  return getEffectivePresence(userKey) !== "offline";
}

function buildGroupInfoForViewer(group, viewerKey) {
  const viewer = normalizeName(viewerKey);
  if (!group || !viewer || !isGroupMember(group, viewer)) return null;
  const members = [];
  for (const memberKey of group.members || []) {
    const user = users.get(memberKey);
    const username = user?.username || memberKey;
    const role = getGroupMemberRole(group, memberKey);
    const presence = getEffectivePresence(memberKey);
    members.push({
      username,
      displayName: user?.displayName || "",
      avatarId: user?.avatarId || "",
      online: presence !== "offline",
      presence,
      lastSeenAt: user?.lastSeenAt || "",
      role,
      isOwner: role === "owner",
      isAdmin: role === "owner" || role === "admin",
    });
  }

  members.sort((a, b) => {
    const roleRank = (role) => (role === "owner" ? 3 : role === "admin" ? 2 : 1);
    const delta = roleRank(b.role) - roleRank(a.role);
    if (delta !== 0) return delta;
    return normalizeName(a.username).localeCompare(normalizeName(b.username));
  });

  const ownerUser = users.get(normalizeName(group.ownerKey));
  const viewerUser = users.get(viewer);
  const viewerRole = getGroupMemberRole(group, viewer);

  return {
    id: group.id,
    name: group.name || group.id,
    owner: ownerUser?.username || group.ownerKey || "",
    createdAt: group.createdAt || "",
    updatedAt: group.updatedAt || "",
    members,
    me: {
      username: viewerUser?.username || viewer,
      role: viewerRole,
      isOwner: viewerRole === "owner",
      isAdmin: viewerRole === "owner" || viewerRole === "admin",
    },
  };
}

function emitGroupInfoToMember(memberKey, group) {
  const normalizedMemberKey = normalizeName(memberKey);
  if (!normalizedMemberKey || !group) return;
  const memberSocket = onlineUsers.get(normalizedMemberKey);
  if (!memberSocket) return;
  const payload = buildGroupInfoForViewer(group, normalizedMemberKey);
  if (!payload) return;
  io.to(memberSocket).emit("group_info", { group: payload });
}

function getConversationKeyForTarget(userKey, targetKey, targetType = "friend") {
  const kind = normalizeChatKind(targetType);
  if (kind === "group") {
    return getGroupConversationKey(targetKey);
  }
  return getConversationKey(userKey, targetKey);
}

function getConversationKey(userA, userB) {
  const a = normalizeName(userA);
  const b = normalizeName(userB);
  return [a, b].sort().join("::");
}

function findMessageByClientTempId(conversationKey, senderKey, targetKey, clientTempId, targetType = "friend") {
  const tempId = toDisplayName(clientTempId);
  if (!tempId) return null;
  const safeConversationKey = toDisplayName(conversationKey);
  if (!safeConversationKey) return null;
  const conversation = conversations.get(safeConversationKey);
  if (!Array.isArray(conversation) || conversation.length === 0) return null;

  const fromKey = normalizeName(senderKey);
  const kind = normalizeChatKind(targetType);
  const normalizedTarget = kind === "group" ? normalizeGroupId(targetKey) : normalizeName(targetKey);
  for (let i = conversation.length - 1; i >= 0; i -= 1) {
    const message = conversation[i];
    if (!message || toDisplayName(message.clientTempId) !== tempId) continue;
    const messageFromKey = normalizeName(message.fromKey || message.from);
    const messageToKey = normalizeName(message.toKey || message.to);
    if (messageFromKey !== fromKey) continue;
    if (kind === "group") {
      const messageGroupId = normalizeGroupId(message.groupId || message.toKey || message.to);
      if (normalizeChatKind(message.toType) === "group" && messageGroupId === normalizedTarget) {
        return message;
      }
      continue;
    }
    if (messageToKey === normalizedTarget) {
      return message;
    }
  }
  return null;
}

function normalizeReplyPayload(rawReply) {
  if (!rawReply || typeof rawReply !== "object" || !rawReply.id) return null;
  return {
    id: toDisplayName(rawReply.id),
    from: toDisplayName(rawReply.from),
    text: toDisplayName(rawReply.text),
  };
}

const resolveChatTargetForUser = createChatAuthorization({
  users,
  groups,
  normalizeName,
  normalizeGroupId,
  normalizeChatKind,
  toDisplayName,
  isGroupMember,
  getConversationKey,
  getGroupConversationKey,
});

function createStoredMessage(params = {}) {
  const chatType = normalizeChatKind(params.toType);
  const timestamp = toDisplayName(params.timestamp) || nowIso();
  const message = {
    id: toDisplayName(params.id) || createMessageId(),
    from: toDisplayName(params.from) || normalizeName(params.fromKey),
    to: toDisplayName(params.to) || "",
    fromKey: normalizeName(params.fromKey),
    toKey: chatType === "group" ? normalizeGroupId(params.toKey) : normalizeName(params.toKey),
    toType: chatType,
    groupId: chatType === "group" ? normalizeGroupId(params.groupId || params.toKey) : "",
    text: withUploadToken(params.text),
    timestamp,
    deliveredAt: toDisplayName(params.deliveredAt) || null,
    seenAt: toDisplayName(params.seenAt) || null,
    deletedAt: null,
    editedAt: null,
    pinnedAt: null,
    pinnedBy: "",
    reactions: {},
  };
  if (chatType === "group") {
    message.seenBy = Array.isArray(params.seenBy)
      ? Array.from(new Set(params.seenBy.map(normalizeName).filter(Boolean)))
      : [normalizeName(params.fromKey)];
  }
  const attachment = sanitizeMessageAttachment(params.attachment, message.text);
  if (attachment) message.attachment = attachment;
  const replyTo = normalizeReplyPayload(params.replyTo);
  if (replyTo) message.replyTo = replyTo;
  if (params.poll) message.poll = params.poll;
  if (params.game) message.game = params.game;
  if (params.ciphertext) message.ciphertext = toDisplayName(params.ciphertext);
  if (params.iv) message.iv = toDisplayName(params.iv);
  if (params.isEncrypted) message.isEncrypted = Boolean(params.isEncrypted);
  const temp = toDisplayName(params.clientTempId).slice(0, 64);
  if (temp) message.clientTempId = temp;
  return message;
}

function deliverFriendMessage(params = {}) {
  const fromKey = normalizeName(params.fromKey);
  const toKey = normalizeName(params.toKey);
  const text = withUploadToken(params.text);
  const clientTempId = toDisplayName(params.clientTempId).slice(0, 64);
  if (!fromKey || !toKey || !text) {
    return { ok: false, message: "Invalid message payload." };
  }

  const me = users.get(fromKey);
  const friend = users.get(toKey);
  if (!me || !friend || !me.friends.has(toKey)) {
    return { ok: false, message: "You can message only your friends." };
  }
  if (usersAreBlocked(fromKey, toKey)) {
    return { ok: false, code: "blocked", friend };
  }

  const conversationKey = getConversationKey(fromKey, toKey);
  if (clientTempId) {
    const existing = findMessageByClientTempId(conversationKey, fromKey, toKey, clientTempId, "friend");
    if (existing) {
      return { ok: true, existing: true, message: existing, me, friend };
    }
  }

  const recipientSocketId = onlineUsers.get(toKey);
  const recipientSocket = recipientSocketId ? io.sockets.sockets.get(recipientSocketId) : null;
  const recipientViewing = Boolean(
    recipientSocket &&
    recipientSocket.data?.activeChatKind === "friend" &&
    normalizeName(recipientSocket.data?.activeChatWith) === fromKey
  );

  const timestamp = toDisplayName(params.timestamp) || nowIso();
  const message = createStoredMessage({
    id: params.id,
    from: me.username,
    to: friend.username,
    fromKey,
    toKey,
    toType: "friend",
    text,
    timestamp,
    deliveredAt: recipientSocketId ? timestamp : null,
    seenAt: recipientViewing ? timestamp : null,
    attachment: params.attachment,
    replyTo: params.replyTo,
    poll: params.poll,
    game: params.game,
    ciphertext: params.ciphertext,
    iv: params.iv,
    isEncrypted: params.isEncrypted,
    clientTempId,
  });

  const conversation = conversations.get(conversationKey) || [];
  conversation.push(message);
  conversations.set(conversationKey, conversation);
  runRetentionMaintenance();

  recipientViewing ? setUnreadCount(friend, fromKey, 0) : incrementUnread(friend, fromKey);

  const senderSocketId = onlineUsers.get(fromKey);
  if (senderSocketId) {
    io.to(senderSocketId).emit("private_message", message);
  }
  if (recipientSocketId) {
    io.to(recipientSocketId).emit("private_message", message);
  } else if (!isMutedBy(friend, fromKey)) {
    const bodyText = formatPushBody(text);
    void sendPushToUser(toKey, {
      type: "message",
      title: `New message from ${me.username}`,
      body: bodyText,
      tag: `msg-${fromKey}`,
      url: `/?source=push&chat=${encodeURIComponent(me.username)}`,
      icon: "/icons/icon-192.png",
      badge: "/icons/novyn-badge.svg",
    });
  }

  emitMessageStatus(message);
  emitFriendList(fromKey);
  emitFriendList(toKey);
  schedulePersist();
  return { ok: true, existing: false, message, me, friend };
}

function deliverGroupMessage(params = {}) {
  const fromKey = normalizeName(params.fromKey);
  const groupId = normalizeGroupId(params.groupId || params.toKey);
  const text = withUploadToken(params.text);
  const clientTempId = toDisplayName(params.clientTempId).slice(0, 64);
  if (!fromKey || !groupId || !text) {
    return { ok: false, message: "Invalid group message payload." };
  }
  const me = users.get(fromKey);
  const group = groups.get(groupId);
  if (!me || !group || !isGroupMember(group, fromKey)) {
    return { ok: false, message: "You are not a member of that group." };
  }

  const conversationKey = getGroupConversationKey(groupId);
  if (clientTempId) {
    const existing = findMessageByClientTempId(conversationKey, fromKey, groupId, clientTempId, "group");
    if (existing) {
      return { ok: true, existing: true, message: existing, me, group };
    }
  }

  const timestamp = toDisplayName(params.timestamp) || nowIso();
  const message = createStoredMessage({
    id: params.id,
    from: me.username,
    to: group.name || group.id,
    fromKey,
    toKey: group.id,
    toType: "group",
    groupId: group.id,
    text,
    timestamp,
    deliveredAt: timestamp,
    seenAt: null,
    seenBy: [fromKey],
    attachment: params.attachment,
    replyTo: params.replyTo,
    poll: params.poll,
    game: params.game,
    clientTempId,
  });

  const conversation = conversations.get(conversationKey) || [];
  conversation.push(message);
  conversations.set(conversationKey, conversation);
  group.updatedAt = nowIso();
  runRetentionMaintenance();

  let seenByChanged = false;
  for (const memberKey of group.members) {
    const member = users.get(memberKey);
    if (!member) continue;
    const memberSocketId = onlineUsers.get(memberKey);
    const memberSocket = memberSocketId ? io.sockets.sockets.get(memberSocketId) : null;
    const viewingSameGroup = Boolean(
      memberSocket &&
      memberSocket.data?.activeChatKind === "group" &&
      normalizeGroupId(memberSocket.data?.activeChatWith) === group.id
    );

    if (memberKey === fromKey || viewingSameGroup) {
      setUnreadCount(member, group.id, 0);
      if (memberKey !== fromKey && !message.seenBy.includes(memberKey)) {
        message.seenBy.push(memberKey);
        seenByChanged = true;
      }
    } else {
      incrementUnread(member, group.id);
    }

    if (memberSocketId) {
      io.to(memberSocketId).emit("private_message", message);
    } else if (memberKey !== fromKey) {
      const bodyText = formatPushBody(text);
      void sendPushToUser(memberKey, {
        type: "message",
        title: `New message in ${group.name}`,
        body: `${me.username}: ${bodyText}`,
        tag: `grp-${group.id}`,
        url: `/?source=push&chat=${encodeURIComponent(group.id)}&kind=group`,
        icon: "/icons/icon-192.png",
        badge: "/icons/novyn-badge.svg",
      });
    }

    emitFriendList(memberKey);
  }

  if (seenByChanged) {
    emitGroupMessageStatus(group, message);
  }

  schedulePersist();
  return { ok: true, existing: false, message, me, group };
}

function setCallPair(userKey, peerKey, status, callId) {
  activeCalls.set(userKey, { peerKey, status, callId });
  activeCalls.set(peerKey, { peerKey: userKey, status, callId });
}

function clearCallPair(userKey) {
  const state = activeCalls.get(userKey);
  if (!state) return null;
  const peerKey = state.peerKey;
  activeCalls.delete(userKey);
  if (peerKey) activeCalls.delete(peerKey);
  return peerKey;
}

function applyUsernameChange(userKey, newUsername) {
  const oldKey = normalizeName(userKey);
  const user = users.get(oldKey);
  if (!user) {
    return { ok: false, message: "User not found." };
  }

  const desired = toDisplayName(newUsername);
  if (!desired) {
    return { ok: false, message: "Username is required." };
  }

  const newKey = normalizeName(desired);
  if (!newKey) {
    return { ok: false, message: "Invalid username." };
  }

  const oldUsername = user.username || oldKey;
  const sameKey = newKey === oldKey;
  if (sameKey && desired === oldUsername) {
    return { ok: false, message: "That's already your username." };
  }

  if (!sameKey) {
    const existing = users.get(newKey);
    if (existing) {
      return { ok: false, message: "That username is already taken." };
    }
  }

  if (activeCalls.has(oldKey)) {
    return { ok: false, message: "End your call before changing username." };
  }

  if (!sameKey) {
    users.delete(oldKey);
    users.set(newKey, user);
  }

  user.username = desired;
  user.isRegistered = true;

  if (!sameKey && onlineUsers.has(oldKey)) {
    const socketId = onlineUsers.get(oldKey);
    onlineUsers.delete(oldKey);
    onlineUsers.set(newKey, socketId);
  }

  if (!sameKey) {
    users.forEach((other) => {
      if (!other || other === user) return;
      if (other.friends.has(oldKey)) {
        other.friends.delete(oldKey);
        other.friends.add(newKey);
      }
      if (other.requests.has(oldKey)) {
        other.requests.delete(oldKey);
        other.requests.add(newKey);
      }
      if (other.unread.has(oldKey)) {
        const count = other.unread.get(oldKey);
        other.unread.delete(oldKey);
        other.unread.set(newKey, count);
      }
      if (other.blockedUsers instanceof Set && other.blockedUsers.has(oldKey)) {
        other.blockedUsers.delete(oldKey);
        other.blockedUsers.add(newKey);
      }
      if (other.mutedUsers instanceof Set && other.mutedUsers.has(oldKey)) {
        other.mutedUsers.delete(oldKey);
        other.mutedUsers.add(newKey);
      }
    });
    for (const group of groups.values()) {
      let touched = false;
      if (group.ownerKey === oldKey) {
        group.ownerKey = newKey;
        touched = true;
      }
      if (group.members instanceof Set && group.members.has(oldKey)) {
        group.members.delete(oldKey);
        group.members.add(newKey);
        touched = true;
      }
      if (group.admins instanceof Set && group.admins.has(oldKey)) {
        group.admins.delete(oldKey);
        group.admins.add(newKey);
        touched = true;
      }
      if (touched) {
        group.updatedAt = nowIso();
      }
    }
    for (const scheduled of scheduledMessages.values()) {
      if (scheduled.fromKey === oldKey) {
        scheduled.fromKey = newKey;
      }
      if (scheduled.toType === "friend" && scheduled.toKey === oldKey) {
        scheduled.toKey = newKey;
      }
      if (scheduled.replyTo && normalizeName(scheduled.replyTo.from) === oldKey) {
        scheduled.replyTo.from = desired;
      }
    }
    moveRefreshSessionsToUser(oldKey, newKey);
    linkAuthAlias(oldKey, newKey);
  }

  const nextConversations = new Map();
  conversations.forEach((messages, key) => {
    const [a, b] = key.split("::");
    const containsOld = a === oldKey || b === oldKey;
    const newA = a === oldKey ? newKey : a;
    const newB = b === oldKey ? newKey : b;
    const nextKey = containsOld ? getConversationKey(newA, newB) : key;

    if (containsOld) {
      for (const msg of messages) {
        if (normalizeName(msg.fromKey) === oldKey) {
          msg.fromKey = newKey;
          msg.from = desired;
        }
        if (normalizeName(msg.toKey) === oldKey) {
          msg.toKey = newKey;
          msg.to = desired;
        }
        if (msg.replyTo && normalizeName(msg.replyTo.from) === oldKey) {
          msg.replyTo.from = desired;
        }
        if (Array.isArray(msg.seenBy) && msg.seenBy.length) {
          msg.seenBy = Array.from(
            new Set(
              msg.seenBy.map((entry) => (normalizeName(entry) === oldKey ? newKey : normalizeName(entry)))
            )
          );
        }
      }
    }

    if (nextConversations.has(nextKey)) {
      nextConversations.set(nextKey, nextConversations.get(nextKey).concat(messages));
    } else {
      nextConversations.set(nextKey, messages);
    }
  });
  conversations.clear();
  nextConversations.forEach((value, key) => conversations.set(key, value));

  return {
    ok: true,
    oldKey,
    newKey,
    oldUsername,
    newUsername: desired,
  };
}

function getRetentionCutoffMs() {
  return Date.now() - CHAT_RETENTION_DAYS * 24 * 60 * 60 * 1000;
}

function getMessageTimestampMs(message) {
  const value = Date.parse(toDisplayName(message?.timestamp));
  return Number.isNaN(value) ? Date.now() : value;
}

function recomputeUnreadFromConversations() {
  for (const user of users.values()) {
    const entries = [];
    for (const friendKey of user.friends) {
      entries.push([friendKey, 0]);
    }
    for (const groupKey of user.groups || []) {
      entries.push([normalizeGroupId(groupKey), 0]);
    }
    user.unread = new Map(entries);
  }

  for (const [conversationKey, messages] of conversations.entries()) {
    const groupId = getGroupIdFromConversationKey(conversationKey);
    const isGroup = Boolean(groupId);
    for (const message of messages) {
      if (!message) continue;
      if (isGroup || normalizeChatKind(message.toType) === "group") {
        const group = groups.get(groupId || normalizeGroupId(message.groupId || message.toKey));
        if (!group) continue;
        const seenBy = Array.isArray(message.seenBy) ? message.seenBy.map(normalizeName) : [];
        for (const memberKey of group.members) {
          if (memberKey === normalizeName(message.fromKey)) continue;
          if (seenBy.includes(memberKey)) continue;
          const member = users.get(memberKey);
          if (!member || !member.groups.has(group.id)) continue;
          const current = member.unread.get(group.id) || 0;
          member.unread.set(group.id, current + 1);
        }
        continue;
      }
      if (message.seenAt) continue;
      const recipient = users.get(message.toKey);
      if (!recipient || !recipient.friends.has(message.fromKey)) continue;
      const current = recipient.unread.get(message.fromKey) || 0;
      recipient.unread.set(message.fromKey, current + 1);
    }
  }
}

function pruneExpiredMessages() {
  const cutoffMs = getRetentionCutoffMs();
  let changed = false;

  for (const [key, messages] of conversations.entries()) {
    const filtered = messages.filter((message) => getMessageTimestampMs(message) >= cutoffMs);
    if (filtered.length !== messages.length) {
      changed = true;
    }

    if (!filtered.length) {
      if (messages.length) {
        changed = true;
      }
      conversations.delete(key);
      continue;
    }

    if (filtered.length !== messages.length) {
      conversations.set(key, filtered);
    }
  }

  if (changed) {
    recomputeUnreadFromConversations();
  }

  return changed;
}

function runRetentionMaintenance() {
  pruneExpiredAuthState();
  pruneHttpRateLimits(httpRateLimits);
  pruneExpiredPasswordResetTokens();
  pruneExpiredEmailChangeTokens();
  const pruned = pruneExpiredMessages();
  if (!pruned) {
    return;
  }

  schedulePersist();
  for (const userKey of onlineUsers.keys()) {
    emitFriendList(userKey);
  }
}

function startRetentionMaintenanceLoop() {
  const intervalMs = 60 * 60 * 1000;
  const timer = setInterval(runRetentionMaintenance, intervalMs);
  if (typeof timer.unref === "function") {
    timer.unref();
  }
}

function getUnreadCount(user, friendKey) {
  return user?.unread?.get(normalizeName(friendKey)) || 0;
}

function setUnreadCount(user, friendKey, value) {
  if (!user) return false;
  const key = normalizeName(friendKey);
  const safeValue = Math.max(0, Number.isFinite(Number(value)) ? Math.floor(Number(value)) : 0);
  const hasKey = user.unread.has(key);
  const previous = hasKey ? user.unread.get(key) : null;

  if (hasKey && previous === safeValue) {
    return false;
  }

  user.unread.set(key, safeValue);
  return true;
}

function incrementUnread(user, friendKey) {
  const current = getUnreadCount(user, friendKey);
  return setUnreadCount(user, friendKey, current + 1);
}

function initializeUnreadPair(userAKey, userBKey) {
  const userA = getOrCreateUser(userAKey);
  const userB = getOrCreateUser(userBKey);

  const changedA = setUnreadCount(userA, userBKey, getUnreadCount(userA, userBKey));
  const changedB = setUnreadCount(userB, userAKey, getUnreadCount(userB, userAKey));

  if (changedA || changedB) {
    schedulePersist();
  }
}

function getConversationSummaryByKey(conversationKey) {
  const key = toDisplayName(conversationKey);
  if (!key) {
    return {
      lastMessage: "",
      lastTimestamp: null,
      lastFrom: "",
    };
  }
  const messages = conversations.get(key) || [];

  if (!messages.length) {
    return {
      lastMessage: "",
      lastTimestamp: null,
      lastFrom: "",
    };
  }

  const message = messages[messages.length - 1];
  const text = message.deletedAt ? DELETED_MESSAGE_TEXT : toDisplayName(message.text);
  const compact = text.length > 52 ? `${text.slice(0, 49)}...` : text;

  return {
    lastMessage: compact,
    lastTimestamp: message.timestamp || null,
    lastFrom: message.from || "",
  };
}

function getConversationSummary(userKey, friendKey) {
  return getConversationSummaryByKey(getConversationKey(userKey, friendKey));
}

function getGroupConversationSummary(groupId) {
  return getConversationSummaryByKey(getGroupConversationKey(groupId));
}

function normalizeSearchFilter(filter) {
  const value = toDisplayName(filter).toLowerCase();
  if (value === "media") return "media";
  if (value === "links") return "links";
  if (value === "files") return "files";
  if (value === "unread") return "unread";
  return "all";
}

function messageHasLink(message) {
  const text = toDisplayName(message?.text);
  if (!text) return false;
  return /(?:https?:\/\/|www\.)[^\s<]+/i.test(text);
}

function messageHasMedia(message) {
  const attachment = sanitizeMessageAttachment(message?.attachment, message?.text);
  if (attachment?.kind === "image") return true;
  const text = toDisplayName(message?.text);
  if (!text) return false;
  return /\.(png|jpe?g|gif|webp|svg|mp4|mov|webm)(\?|#|$)/i.test(text);
}

function messageHasFile(message) {
  const attachment = sanitizeMessageAttachment(message?.attachment, message?.text);
  if (attachment?.kind === "file") return true;
  const text = toDisplayName(message?.text);
  if (!text) return false;
  return /\.(pdf|zip|rar|7z|docx?|pptx?|xlsx?|txt|csv)(\?|#|$)/i.test(text);
}

function messageMatchesSearchFilter(message, filter, userKey) {
  if (filter === "media") return messageHasMedia(message);
  if (filter === "links") return messageHasLink(message);
  if (filter === "files") return messageHasFile(message);
  if (filter === "unread") {
    if (normalizeChatKind(message?.toType) === "group") {
      const viewerKey = normalizeName(userKey);
      const fromKey = normalizeName(message?.fromKey || message?.from);
      const seenBy = Array.isArray(message?.seenBy)
        ? message.seenBy.map(normalizeName)
        : [];
      return fromKey !== viewerKey && !seenBy.includes(viewerKey);
    }
    const toKey = normalizeName(message?.toKey || message?.to);
    return toKey === normalizeName(userKey) && !toDisplayName(message?.seenAt);
  }
  return true;
}

function buildGlobalSearchResults(userKey, options = {}) {
  const key = normalizeName(userKey);
  const user = users.get(key);
  if (!user) return [];

  const rawQuery = toDisplayName(options.query);
  const query = normalizeName(rawQuery);
  const filter = normalizeSearchFilter(options.filter);
  const maxResults = Math.max(1, Math.min(250, Number(options.limit) || 80));
  const hits = [];

  function pushHit(chatKind, withValue, withDisplayName, message, extraSearchable = "") {
    if (!message || message.deletedAt) return;
    if (!messageMatchesSearchFilter(message, filter, key)) return;
    const attachment = sanitizeMessageAttachment(message.attachment, message.text);
    const searchable = normalizeName(
      `${message.text || ""} ${message.from || ""} ${message.to || ""} ${attachment?.name || ""} ${extraSearchable}`
    );
    if (query && !searchable.includes(query)) return;

    const text = toDisplayName(message.text);
    const preview = text.length > 140 ? `${text.slice(0, 137)}...` : text;
    const fromKey = normalizeName(message.fromKey || message.from);
    const isGroup = chatKind === "group";
    const seenBy = Array.isArray(message.seenBy) ? message.seenBy.map(normalizeName) : [];
    const unread = isGroup
      ? fromKey !== key && !seenBy.includes(key)
      : normalizeName(message.toKey || message.to) === key && !toDisplayName(message.seenAt);
    hits.push({
      messageId: toDisplayName(message.id),
      kind: isGroup ? "group" : "friend",
      with: withValue,
      withDisplayName: toDisplayName(withDisplayName),
      from: toDisplayName(message.from),
      mine: fromKey === key,
      text: preview,
      timestamp: toDisplayName(message.timestamp),
      unread,
      hasAttachment: Boolean(attachment),
      attachmentKind: attachment?.kind || "",
    });
  }

  for (const friendKey of user.friends) {
    const friend = users.get(friendKey);
    if (!friend) continue;
    if (isBlockedBy(user, friendKey) || isBlockedBy(friend, key)) continue;

    const conversationKey = getConversationKey(key, friendKey);
    const messages = conversations.get(conversationKey) || [];
    if (!Array.isArray(messages) || !messages.length) continue;

    for (let i = messages.length - 1; i >= 0; i -= 1) {
      const message = messages[i];
      pushHit("friend", friend.username || friendKey, friend.displayName || friend.username || friendKey, message);
    }
  }

  for (const groupId of user.groups || []) {
    const group = groups.get(normalizeGroupId(groupId));
    if (!group || !isGroupMember(group, key)) continue;
    const conversationKey = getGroupConversationKey(group.id);
    const messages = conversations.get(conversationKey) || [];
    if (!Array.isArray(messages) || !messages.length) continue;
    for (let i = messages.length - 1; i >= 0; i -= 1) {
      const message = messages[i];
      pushHit(
        "group",
        group.id,
        group.name || group.id,
        message,
        `${group.name || ""} ${group.id || ""}`
      );
    }
  }

  hits.sort((a, b) => toDisplayName(b.timestamp).localeCompare(toDisplayName(a.timestamp)));
  return hits.slice(0, maxResults);
}

function buildFriendList(forUser) {
  const userKey = normalizeName(forUser);
  const user = users.get(userKey);
  if (!user) return [];

  const friendKeys = Array.from(user.friends || []);
  const validFriendKeys = Array.from(
    new Set(
      friendKeys
        .map((friendKey) => normalizeName(friendKey))
        .filter((friendKey) => users.has(friendKey))
    )
  );
  if (validFriendKeys.length !== friendKeys.length) {
    user.friends = new Set(validFriendKeys);
    schedulePersist();
  }

  const directList = validFriendKeys.map((friendKey) => {
    const friend = users.get(friendKey);
    const summary = getConversationSummary(userKey, friendKey);
    const presence = getEffectivePresence(friendKey);

    return {
      username: friend?.username || friendKey,
      kind: "friend",
      groupId: "",
      online: presence !== "offline",
      presence,
      unreadCount: getUnreadCount(user, friendKey),
      lastMessage: summary.lastMessage,
      lastTimestamp: summary.lastTimestamp,
      lastFrom: summary.lastFrom,
      avatarId: friend?.avatarId || "",
      displayName: friend?.displayName || "",
      bio: friend?.bio || "",
      lastSeenAt: friend?.lastSeenAt || "",
      publicKey: friend?.publicKey || "",
      muted: isMutedBy(user, friendKey),
      blockedByMe: isBlockedBy(user, friendKey),
      blockedYou: isBlockedBy(friend, userKey),
      memberCount: 2,
      onlineCount: onlineUsers.has(friendKey) ? 1 : 0,
    };
  });

  const groupList = Array.from(user.groups || [])
    .map((groupKey) => groups.get(normalizeGroupId(groupKey)))
    .filter((group) => group && isGroupMember(group, userKey))
    .map((group) => {
      const summary = getGroupConversationSummary(group.id);
      let onlineCount = 0;
      for (const memberKey of group.members) {
        if (memberKey === userKey) continue;
        if (isUserAvailable(memberKey)) onlineCount += 1;
      }
      return {
        username: group.id,
        kind: "group",
        groupId: group.id,
        online: onlineCount > 0,
        unreadCount: getUnreadCount(user, group.id),
        lastMessage: summary.lastMessage,
        lastTimestamp: summary.lastTimestamp,
        lastFrom: summary.lastFrom,
        avatarId: "",
        displayName: group.name || group.id,
        bio: `${group.members.size} member${group.members.size === 1 ? "" : "s"}`,
        lastSeenAt: "",
        muted: false,
        blockedByMe: false,
        blockedYou: false,
        memberCount: group.members.size,
        onlineCount,
      };
    });

  const list = directList.concat(groupList);

  list.sort((a, b) => {
    if (a.lastTimestamp && b.lastTimestamp) {
      return b.lastTimestamp.localeCompare(a.lastTimestamp);
    }
    if (a.lastTimestamp) return -1;
    if (b.lastTimestamp) return 1;
    const aName = a.displayName || a.username;
    const bName = b.displayName || b.username;
    return aName.localeCompare(bName);
  });

  return list;
}

function buildDiscoverOnlineList(forUser, limit = 20) {
  const userKey = normalizeName(forUser);
  const me = users.get(userKey);
  if (!me) return [];

  const exclude = new Set([userKey, ...me.friends, ...me.requests]);
  const list = [];

  for (const onlineKey of onlineUsers.keys()) {
    if (exclude.has(onlineKey)) continue;
    const user = users.get(onlineKey);
    if (!user || !user.isRegistered) continue;
    if (isBlockedBy(me, onlineKey) || isBlockedBy(user, userKey)) continue;
    const presence = getEffectivePresence(onlineKey);
    if (presence === "offline") continue;
    list.push({
      username: user.username || onlineKey,
      displayName: user.displayName || "",
      avatarId: user.avatarId || "",
      bio: user.bio || "",
      lastSeenAt: user.lastSeenAt || "",
      online: true,
      presence,
    });
  }

  list.sort((a, b) => a.username.localeCompare(b.username));
  return list.slice(0, limit);
}

function emitDiscoverOnlineToAll(limit = 30) {
  for (const [userKey, socketId] of onlineUsers.entries()) {
    if (!socketId) continue;
    io.to(socketId).emit("discover_online", {
      users: buildDiscoverOnlineList(userKey, limit),
    });
  }
}

function emitFriendList(username) {
  const userKey = normalizeName(username);
  const socketId = onlineUsers.get(userKey);
  if (!socketId) return;

  io.to(socketId).emit("friend_list_updated", {
    friends: buildFriendList(userKey),
  });
}

function emitRequests(username) {
  const userKey = normalizeName(username);
  const socketId = onlineUsers.get(userKey);
  if (!socketId) return;

  const user = users.get(userKey);
  if (!user) return;

  const requests = Array.from(user.requests).map((requesterKey) => {
    const requester = users.get(requesterKey);
    return requester?.username || requesterKey;
  });

  io.to(socketId).emit("requests_updated", { requests });
}

function emitSafetyState(username) {
  const userKey = normalizeName(username);
  const socketId = onlineUsers.get(userKey);
  if (!socketId) return;
  const user = users.get(userKey);
  if (!user) return;

  io.to(socketId).emit("safety_state_updated", {
    blocked: Array.from(user.blockedUsers || [])
      .map((targetKey) => users.get(targetKey)?.username || targetKey),
    muted: Array.from(user.mutedUsers || [])
      .map((targetKey) => users.get(targetKey)?.username || targetKey),
  });
}

function emitStatusToFriends(username) {
  const userKey = normalizeName(username);
  const user = users.get(userKey);
  if (!user) return;
  const presence = getEffectivePresence(userKey);
  const online = presence !== "offline";

  for (const friendKey of user.friends) {
    const friendSocket = onlineUsers.get(friendKey);
    if (!friendSocket) continue;

    io.to(friendSocket).emit("user_status", {
      username: user.username,
      online,
      presence,
      lastSeenAt: user.lastSeenAt || null,
    });
  }
}

function emitMessageStatus(message) {
  if (!message?.id) return;
  if (normalizeChatKind(message?.toType) === "group") return;

  const senderSocket = onlineUsers.get(message.fromKey);
  const receiverSocket = onlineUsers.get(message.toKey);

  const senderPayload = {
    id: message.id,
    with: message.to,
    deliveredAt: message.deliveredAt || null,
    seenAt: message.seenAt || null,
  };

  const receiverPayload = {
    id: message.id,
    with: message.from,
    deliveredAt: message.deliveredAt || null,
    seenAt: message.seenAt || null,
  };

  if (senderSocket) {
    io.to(senderSocket).emit("message_status", senderPayload);
  }

  if (receiverSocket) {
    io.to(receiverSocket).emit("message_status", receiverPayload);
  }
}

function emitGroupMessageStatus(group, message) {
  if (!group || !message?.id) return;
  const groupId = normalizeGroupId(group.id || message.groupId || message.toKey);
  if (!groupId) return;
  const seenBy = Array.isArray(message.seenBy)
    ? Array.from(new Set(message.seenBy.map(normalizeName).filter(Boolean)))
    : [];
  const payload = {
    id: message.id,
    with: groupId,
    toType: "group",
    groupId,
    deliveredAt: message.deliveredAt || null,
    seenAt: message.seenAt || null,
    seenBy,
    seenCount: Math.max(0, seenBy.length - 1),
    memberCount: Math.max(0, Number(group.members?.size || 0)),
  };
  for (const memberKey of group.members || []) {
    const socketId = onlineUsers.get(normalizeName(memberKey));
    if (!socketId) continue;
    io.to(socketId).emit("message_status", payload);
  }
}

function markUndeliveredAsDelivered(userKey) {
  let changed = false;

  for (const conversation of conversations.values()) {
    for (const message of conversation) {
      if (message.toKey === userKey && !message.deliveredAt) {
        message.deliveredAt = nowIso();
        changed = true;
        emitMessageStatus(message);
      }
    }
  }

  if (changed) {
    schedulePersist();
  }
}

function markConversationAsSeen(viewerKey, targetKey, targetType = "friend") {
  const chatType = normalizeChatKind(targetType);
  if (chatType === "group") {
    const groupId = normalizeGroupId(targetKey);
    const viewer = users.get(viewerKey);
    const group = groups.get(groupId);
    if (!viewer || !group || !isGroupMember(group, viewerKey)) return;
    const key = getGroupConversationKey(groupId);
    const conversation = conversations.get(key) || [];
    const unreadChanged = setUnreadCount(viewer, groupId, 0);
    let seenChanged = false;
    const touchedMessages = [];
    for (const message of conversation) {
      if (!message || normalizeName(message.fromKey) === viewerKey) continue;
      if (!Array.isArray(message.seenBy)) message.seenBy = [];
      if (!message.seenBy.includes(viewerKey)) {
        message.seenBy.push(viewerKey);
        seenChanged = true;
        touchedMessages.push(message);
      }
    }
    if (unreadChanged || seenChanged) {
      schedulePersist();
    }
    if (seenChanged) {
      for (const message of touchedMessages) {
        emitGroupMessageStatus(group, message);
      }
    }
    if (unreadChanged) {
      emitFriendList(viewerKey);
    }
    return;
  }

  const friendKey = normalizeName(targetKey);
  const key = getConversationKey(viewerKey, friendKey);
  const conversation = conversations.get(key) || [];
  const viewer = users.get(viewerKey);

  const unreadChanged = setUnreadCount(viewer, friendKey, 0);
  let statusChanged = false;

  for (const message of conversation) {
    if (message.toKey === viewerKey && message.fromKey === friendKey && !message.seenAt) {
      const seenAt = nowIso();
      if (!message.deliveredAt) {
        message.deliveredAt = seenAt;
      }
      message.seenAt = seenAt;
      statusChanged = true;
      emitMessageStatus(message);
    }
  }

  if (unreadChanged || statusChanged) {
    schedulePersist();
  }

  if (unreadChanged) {
    emitFriendList(viewerKey);
  }
}

function removeFriendship(userAKey, userBKey) {
  const aKey = normalizeName(userAKey);
  const bKey = normalizeName(userBKey);
  const userA = users.get(aKey);
  const userB = users.get(bKey);

  if (!userA || !userB) {
    return false;
  }

  const wereFriends = userA.friends.has(bKey) || userB.friends.has(aKey);
  if (!wereFriends) {
    return false;
  }

  userA.friends.delete(bKey);
  userB.friends.delete(aKey);

  userA.requests.delete(bKey);
  userB.requests.delete(aKey);

  userA.unread.delete(bKey);
  userB.unread.delete(aKey);
  if (userA.mutedUsers instanceof Set) userA.mutedUsers.delete(bKey);
  if (userB.mutedUsers instanceof Set) userB.mutedUsers.delete(aKey);

  const conversationKey = getConversationKey(aKey, bKey);
  conversations.delete(conversationKey);

  return true;
}

function revokeAllRefreshSessionsForUser(rawUserKey) {
  const userKey = normalizeName(rawUserKey);
  if (!userKey) return;
  const tokenSet = refreshByUser.get(userKey);
  if (!tokenSet || !tokenSet.size) return;
  for (const tokenId of Array.from(tokenSet)) {
    revokeRefreshSession(tokenId);
  }
}

function emitGroupListUpdatesForUser(username) {
  const userKey = normalizeName(username);
  const user = users.get(userKey);
  if (!user || !(user.groups instanceof Set)) return;
  const touchedMembers = new Set();
  for (const groupKey of user.groups) {
    const group = groups.get(normalizeGroupId(groupKey));
    if (!group) continue;
    for (const memberKey of group.members) {
      touchedMembers.add(memberKey);
      emitGroupInfoToMember(memberKey, group);
    }
  }
  for (const memberKey of touchedMembers) {
    emitFriendList(memberKey);
  }
}

function buildRegisterSuccessPayload(userKey, user) {
  return {
    username: user.username,
    email: user.email || "",
    presenceMode: normalizePresenceMode(user.presenceMode),
    friends: buildFriendList(userKey),
    requests: Array.from(user.requests).map((requesterKey) => {
      const requester = users.get(requesterKey);
      return requester?.username || requesterKey;
    }),
    safety: {
      blocked: Array.from(user.blockedUsers || [])
        .map((targetKey) => users.get(targetKey)?.username || targetKey),
      muted: Array.from(user.mutedUsers || [])
        .map((targetKey) => users.get(targetKey)?.username || targetKey),
    },
    profile: {
      avatarId: user.avatarId || "",
      age: user.age || "",
      gender: user.gender || "",
      displayName: user.displayName || "",
      bio: user.bio || "",
    },
  };
}

function finalizeSocketAuthentication(socket, user) {
  if (!socket || !user?.username) return false;
  const presenceMode = normalizePresenceMode(user.presenceMode);
  if (presenceMode === "offline") {
    if (!user.lastSeenAt) {
      user.lastSeenAt = nowIso();
    }
  } else {
    user.lastSeenAt = "";
  }
  const userKey = normalizeName(user.username);

  socket.data.userKey = userKey;
  socket.data.activeChatWith = null;
  socket.data.activeChatKind = "friend";

  const previousSocketId = onlineUsers.get(userKey);
  onlineUsers.set(userKey, socket.id);

  if (previousSocketId && previousSocketId !== socket.id) {
    const previousSocket = io.sockets.sockets.get(previousSocketId);
    if (previousSocket) {
      previousSocket.emit("error_message", {
        message: "You were signed out because this account logged in elsewhere.",
      });
      previousSocket.disconnect(true);
    }
  }

  markUndeliveredAsDelivered(userKey);
  socket.emit("register_success", buildRegisterSuccessPayload(userKey, user));
  emitStatusToFriends(userKey);
  emitFriendList(userKey);
  emitGroupListUpdatesForUser(userKey);
  emitSafetyState(userKey);
  emitDiscoverOnlineToAll();
  schedulePersist();
  return true;
}

function allowSocketAction(socket, key, maxPerWindow, windowMs) {
  if (!socket || !key) return false;
  const max = Math.max(1, Number(maxPerWindow) || 1);
  const windowDuration = Math.max(1000, Number(windowMs) || 1000);
  if (!socket.data.rateBuckets) {
    socket.data.rateBuckets = {};
  }
  const now = Date.now();
  const bucket = socket.data.rateBuckets[key] || {
    count: 0,
    windowStartedAt: now,
  };
  if (now - bucket.windowStartedAt > windowDuration) {
    bucket.windowStartedAt = now;
    bucket.count = 0;
  }
  bucket.count += 1;
  socket.data.rateBuckets[key] = bucket;
  return bucket.count <= max;
}

function clearScheduledMessageTimer(messageId) {
  const id = toDisplayName(messageId);
  if (!id) return;
  const timer = scheduledMessageTimers.get(id);
  if (timer) clearTimeout(timer);
  scheduledMessageTimers.delete(id);
}

function normalizeScheduledSendAt(rawValue) {
  const value = toDisplayName(rawValue);
  if (!value) {
    return { ok: false, message: "Choose a date and time for scheduled send." };
  }
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) {
    return { ok: false, message: "Scheduled time is invalid." };
  }
  const delay = timestamp - Date.now();
  if (delay < SCHEDULE_MIN_DELAY_MS) {
    return { ok: false, message: "Choose a time at least 30 seconds in the future." };
  }
  if (delay > SCHEDULE_MAX_DELAY_MS) {
    return { ok: false, message: "Scheduled time is too far in the future." };
  }
  return { ok: true, sendAt: new Date(timestamp).toISOString() };
}

function toScheduledMessageSummary(entry) {
  if (!entry) return null;
  const toType = normalizeChatKind(entry.toType);
  const toKey = toType === "group" ? normalizeGroupId(entry.toKey) : normalizeName(entry.toKey);
  const toLabel = toType === "group"
    ? (groups.get(toKey)?.name || toKey)
    : (users.get(toKey)?.username || toKey);
  return {
    id: entry.id,
    toType,
    to: toKey,
    toLabel,
    text: toDisplayName(entry.text),
    sendAt: toDisplayName(entry.sendAt),
    createdAt: toDisplayName(entry.createdAt),
    hasAttachment: Boolean(entry.attachment),
    replyTo: entry.replyTo || null,
  };
}

function listScheduledMessagesForUser(userKey, options = {}) {
  const key = normalizeName(userKey);
  if (!key) return [];
  const filterType = options.toType ? normalizeChatKind(options.toType) : "";
  const filterTo = filterType === "group"
    ? normalizeGroupId(options.to)
    : normalizeName(options.to);
  const list = [];
  for (const entry of scheduledMessages.values()) {
    if (!entry || normalizeName(entry.fromKey) !== key) continue;
    const entryType = normalizeChatKind(entry.toType);
    const entryTo = entryType === "group" ? normalizeGroupId(entry.toKey) : normalizeName(entry.toKey);
    if (filterType && entryType !== filterType) continue;
    if (filterTo && entryTo !== filterTo) continue;
    const summary = toScheduledMessageSummary(entry);
    if (summary) list.push(summary);
  }
  list.sort((a, b) => toDisplayName(a.sendAt).localeCompare(toDisplayName(b.sendAt)));
  return list;
}

function emitScheduledMessagesUpdated(userKey, options = {}) {
  const key = normalizeName(userKey);
  const socketId = onlineUsers.get(key);
  if (!socketId) return;
  io.to(socketId).emit("scheduled_messages_updated", {
    toType: options.toType ? normalizeChatKind(options.toType) : "",
    to: toDisplayName(options.to || ""),
    messages: listScheduledMessagesForUser(key, options),
  });
}

function deliverScheduledMessageById(messageId) {
  const id = toDisplayName(messageId);
  if (!id) return;
  clearScheduledMessageTimer(id);
  const entry = scheduledMessages.get(id);
  if (!entry) return;

  const sendAtMs = Date.parse(entry.sendAt);
  if (Number.isFinite(sendAtMs) && sendAtMs > Date.now() + 500) {
    queueScheduledMessageDelivery(id);
    return;
  }

  let result = null;
  if (normalizeChatKind(entry.toType) === "group") {
    result = deliverGroupMessage({
      fromKey: entry.fromKey,
      groupId: entry.toKey,
      text: entry.text,
      attachment: entry.attachment,
      replyTo: entry.replyTo,
      timestamp: nowIso(),
    });
  } else {
    result = deliverFriendMessage({
      fromKey: entry.fromKey,
      toKey: entry.toKey,
      text: entry.text,
      attachment: entry.attachment,
      replyTo: entry.replyTo,
      timestamp: nowIso(),
    });
  }

  scheduledMessages.delete(id);

  const senderSocket = onlineUsers.get(entry.fromKey);
  if (senderSocket) {
    if (result?.ok) {
      io.to(senderSocket).emit("scheduled_message_sent", {
        id,
        toType: normalizeChatKind(entry.toType),
        to: entry.toKey,
        messageId: result.message?.id || "",
      });
    } else {
      io.to(senderSocket).emit("scheduled_message_failed", {
        id,
        toType: normalizeChatKind(entry.toType),
        to: entry.toKey,
        reason: result?.message || "Could not deliver scheduled message.",
      });
    }
  }

  emitScheduledMessagesUpdated(entry.fromKey, { toType: entry.toType, to: entry.toKey });
  schedulePersist();
}

function queueScheduledMessageDelivery(messageId) {
  const id = toDisplayName(messageId);
  if (!id) return;
  const entry = scheduledMessages.get(id);
  if (!entry) return;

  clearScheduledMessageTimer(id);
  const sendAtMs = Date.parse(entry.sendAt);
  if (!Number.isFinite(sendAtMs)) {
    scheduledMessages.delete(id);
    return;
  }
  const delay = sendAtMs - Date.now();
  if (delay <= 0) {
    setImmediate(() => deliverScheduledMessageById(id));
    return;
  }
  const maxDelay = 2_147_000_000;
  const timeoutDelay = Math.min(maxDelay, delay);
  const timer = setTimeout(() => {
    if (timeoutDelay < delay) {
      queueScheduledMessageDelivery(id);
      return;
    }
    deliverScheduledMessageById(id);
  }, timeoutDelay);
  scheduledMessageTimers.set(id, timer);
}

function queueAllScheduledMessages() {
  for (const messageId of scheduledMessages.keys()) {
    queueScheduledMessageDelivery(messageId);
  }
}

function authenticateSigninPayload(payload) {
  const identifier = toDisplayName(payload?.identifier || payload?.email || payload?.username || "");
  const password = toDisplayName(payload?.password || "");
  const isEmail = identifier.includes("@");

  if (!identifier) {
    return { ok: false, status: 400, message: "Email or username is required.", suggestions: [] };
  }
  if (!password) {
    return { ok: false, status: 400, message: "Password is required.", suggestions: [] };
  }

  if (isEmail) {
    const user = findUserByEmail(identifier);
    if (!user || !user.isRegistered) {
      return { ok: false, status: 401, message: "Email doesn't exist. Sign up.", suggestions: [] };
    }
    if (!verifyPassword(password, user.passwordSalt, user.passwordHash)) {
      return { ok: false, status: 401, message: "Incorrect password.", suggestions: [] };
    }
    return { ok: true, user };
  }

  const userKey = normalizeName(identifier);
  const user = users.get(userKey);
  const suggestions = buildUsernameSuggestions(identifier);
  if (!user || !user.isRegistered) {
    return {
      ok: false,
      status: 401,
      message: "Username doesn't exist. Sign up.",
      suggestions,
    };
  }

  if (!user.passwordSalt || !user.passwordHash) {
    const secret = createPasswordSecret(password);
    user.passwordSalt = secret.passwordSalt;
    user.passwordHash = secret.passwordHash;
    user.isRegistered = true;
    schedulePersist();
  } else if (!verifyPassword(password, user.passwordSalt, user.passwordHash)) {
    return { ok: false, status: 401, message: "Incorrect password.", suggestions };
  }

  return { ok: true, user };
}

function authenticateSignupPayload(payload) {
  const email = normalizeEmail(payload?.email || "");
  const displayName = toDisplayName(payload?.name || payload?.displayName || "");
  const usernameInput = toDisplayName(payload?.username || "");
  const password = toDisplayName(payload?.password || "");

  if (!email) {
    return { ok: false, status: 400, message: "Email is required to sign up." };
  }
  if (isEmailTaken(email)) {
    return { ok: false, status: 409, message: "Email already registered. Sign in." };
  }
  if (!displayName) {
    return { ok: false, status: 400, message: "Name is required to sign up." };
  }
  const requestedHandle = normalizeHandleInput(usernameInput);
  if (!requestedHandle) {
    return { ok: false, status: 400, message: "Username is required." };
  }
  if (isUsernameTaken(requestedHandle)) {
    return { ok: false, status: 409, message: "This username is taken." };
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return {
      ok: false,
      status: 400,
      message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.`,
    };
  }

  const user = getOrCreateUser(requestedHandle);
  const secret = createPasswordSecret(password);
  user.passwordSalt = secret.passwordSalt;
  user.passwordHash = secret.passwordHash;
  user.isRegistered = true;
  user.email = email;
  user.displayName = displayName;
  if (!user.createdAt) {
    user.createdAt = nowIso();
  }
  schedulePersist();

  return { ok: true, user };
}

app.post("/api/auth/signin", createIpRateLimiter("auth-signin", 25, 15 * 60 * 1000), requireCsrf, (req, res) => {
  const result = authenticateSigninPayload(req.body || {});
  if (!result.ok) {
    res.status(result.status || 401).json({
      message: result.message || "Authentication failed.",
      suggestions: result.suggestions || [],
    });
    return;
  }
  const remember = readRememberFlag(req.body?.remember);
  const userKey = normalizeName(result.user.username);
  const tokens = issueAuthTokensForUser(userKey, remember);
  if (!tokens) {
    res.status(500).json({ message: "Unable to create session." });
    return;
  }
  applyAuthCookies(res, tokens);
  res.json({
    username: result.user.username,
    email: result.user.email || "",
  });
});

app.post(
  "/api/auth/signup",
  createIpRateLimiter("auth-signup", 20, 15 * 60 * 1000),
  requireCsrf,
  (req, res) => {
    const result = authenticateSignupPayload(req.body || {});
    if (!result.ok) {
      res.status(result.status || 400).json({ message: result.message || "Unable to sign up." });
      return;
    }
    const remember = readRememberFlag(req.body?.remember);
    const userKey = normalizeName(result.user.username);
    const tokens = issueAuthTokensForUser(userKey, remember);
    if (!tokens) {
      res.status(500).json({ message: "Unable to create session." });
      return;
    }
    applyAuthCookies(res, tokens);
    res.json({
      username: result.user.username,
      email: result.user.email || "",
    });
  }
);

app.post(
  "/api/auth/google",
  createIpRateLimiter("auth-google", 25, 15 * 60 * 1000),
  async (req, res) => {
    if (!firebaseAdmin) {
      res.status(503).json({
        message:
          "Firebase authentication is not configured on server. Set FIREBASE_SERVICE_ACCOUNT_JSON (or FIREBASE_SERVICE_ACCOUNT_FILE) in your deployment environment.",
      });
      return;
    }

    const idToken = toDisplayName(req.body?.idToken || "");
    const remember = readRememberFlag(req.body?.remember);
    if (!idToken) {
      res.status(400).json({ message: "Google sign-in token is required." });
      return;
    }

    let decoded;
    try {
      decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    } catch (err) {
      res.status(401).json({ message: "Invalid Google sign-in token." });
      return;
    }

    const googleUid = toDisplayName(decoded.uid || decoded.sub || "");
    if (!googleUid) {
      res.status(400).json({ message: "Google account identifier is missing." });
      return;
    }

    const email = normalizeEmail(decoded.email || "");
    if (!email) {
      res.status(400).json({ message: "Google account email is required." });
      return;
    }
    const googleDisplayName = toDisplayName(decoded.name || decoded.displayName || email.split("@")[0] || "");
    const linkIdentifier = toDisplayName(req.body?.identifier || "");
    const linkPassword = toDisplayName(req.body?.password || "");

    let user = findUserByGoogleUid(googleUid) || findUserByEmail(email);
    let linkedExisting = Boolean(user);

    if (!user && linkIdentifier && linkPassword) {
      const linkedAuth = authenticateSigninPayload({
        identifier: linkIdentifier,
        password: linkPassword,
      });
      if (!linkedAuth.ok || !linkedAuth.user) {
        res.status(linkedAuth.status || 401).json({
          message: "Could not link Google account. Check your existing account credentials and try again.",
        });
        return;
      }

      const candidate = linkedAuth.user;
      const candidateEmail = normalizeEmail(candidate.email || "");
      if (candidateEmail && candidateEmail !== email) {
        res.status(409).json({
          message: `This account is already using ${candidateEmail}. Sign in with that Google email or update your email first.`,
        });
        return;
      }

      user = candidate;
      linkedExisting = true;
    }

    let createdAccount = false;
    if (!user) {
      const username = pickAvailableUsername(decoded.name || email.split("@")[0] || `user${Date.now()}`);
      user = getOrCreateUser(username);
      createdAccount = true;
    }

    const currentUserGoogleUid = toDisplayName(user.googleUid);
    if (currentUserGoogleUid && currentUserGoogleUid !== googleUid) {
      res.status(409).json({
        message: "This account is already linked to another Google account.",
      });
      return;
    }

    const existingGoogleOwner = findUserByGoogleUid(googleUid);
    if (existingGoogleOwner && normalizeName(existingGoogleOwner.username) !== normalizeName(user.username)) {
      res.status(409).json({
        message: "This Google account is already linked to another user.",
      });
      return;
    }

    let userChanged = false;
    if (toDisplayName(user.googleUid) !== googleUid) {
      user.googleUid = googleUid;
      userChanged = true;
    }
    if (!user.isRegistered) {
      user.isRegistered = true;
      userChanged = true;
    }
    if (!user.createdAt) {
      user.createdAt = nowIso();
      userChanged = true;
    }
    if (!normalizeEmail(user.email || "")) {
      user.email = email;
      userChanged = true;
    }
    if (!toDisplayName(user.displayName) && googleDisplayName) {
      user.displayName = googleDisplayName;
      userChanged = true;
    }
    if (userChanged) {
      schedulePersist();
    }

    const tokens = issueAuthTokensForUser(user.username, remember);
    if (!tokens) {
      res.status(500).json({ message: "Unable to create session." });
      return;
    }
    applyAuthCookies(res, tokens);
    res.json({
      username: user.username,
      email: user.email || "",
      linkedExisting: Boolean(linkedExisting),
      createdAccount: Boolean(createdAccount),
    });
  }
);

app.get("/api/auth/session", (req, res) => {
  const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), {
    allowRefreshFallback: true,
  });
  if (!auth.userKey) {
    res.status(401).json({ message: "Not signed in." });
    return;
  }
  const user = users.get(auth.userKey);
  if (!user || !user.isRegistered) {
    clearAuthCookies(res);
    res.status(401).json({ message: "Session expired." });
    return;
  }
  if (auth.via === "refresh") {
    const tokens = issueAuthTokensForUser(auth.userKey, true);
    if (tokens) applyAuthCookies(res, tokens);
  }
  res.json({
    authenticated: true,
    username: user.username,
    displayName: user.displayName || user.username,
    email: user.email || "",
    avatarId: user.avatarId || "",
    bio: user.bio || "",
    presenceMode: user.presenceMode || "online",
  });
});

app.post("/api/auth/refresh", createIpRateLimiter("auth-refresh", 120, 15 * 60 * 1000), (req, res) => {
  const cookies = getAuthCookiesFromHeader(req.headers.cookie);
  const refreshPayload = verifyAuthToken(cookies.refreshToken, "refresh");
  if (!refreshPayload?.jti) {
    clearAuthCookies(res);
    res.status(401).json({ message: "Session expired." });
    return;
  }
  const session = refreshSessions.get(refreshPayload.jti);
  if (!session || Date.now() > Number(session.expiresAt)) {
    revokeRefreshSession(refreshPayload.jti);
    clearAuthCookies(res);
    res.status(401).json({ message: "Session expired." });
    return;
  }
  const userKey = resolveCurrentUserKey(session.userKey || refreshPayload.sub);
  const user = userKey ? users.get(userKey) : null;
  if (!user || !user.isRegistered) {
    revokeRefreshSession(refreshPayload.jti);
    clearAuthCookies(res);
    res.status(401).json({ message: "Session expired." });
    return;
  }

  const remember = Boolean(session.remember);
  revokeRefreshSession(refreshPayload.jti);
  const tokens = issueAuthTokensForUser(userKey, remember);
  if (!tokens) {
    clearAuthCookies(res);
    res.status(500).json({ message: "Unable to refresh session." });
    return;
  }
  applyAuthCookies(res, tokens);
  res.json({ ok: true });
});

app.post("/api/auth/logout", createIpRateLimiter("auth-logout", 120, 15 * 60 * 1000), requireCsrf, (req, res) => {
  const cookies = getAuthCookiesFromHeader(req.headers.cookie);
  const refreshPayload = verifyAuthToken(cookies.refreshToken, "refresh");
  if (refreshPayload?.jti) {
    revokeRefreshSession(refreshPayload.jti);
  }
  clearAuthCookies(res);
  res.json({ ok: true });
});

const { assertSafeExternalUrl, readResponseWithLimit } = require("./server/security/ssrf");

app.get("/api/link-preview", async (req, res) => {
  const targetUrl = String(req.query?.url || "").trim();
  if (!targetUrl) {
    res.status(400).json({ error: "Invalid URL" });
    return;
  }

  try {
    const safeUrl = await assertSafeExternalUrl(targetUrl);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const response = await fetch(safeUrl.href, {
      signal: controller.signal,
      redirect: "manual",
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });
    clearTimeout(timeout);

    if (!response.ok) {
      res.status(400).json({ error: "Failed to fetch URL" });
      return;
    }

    if (response.status >= 300 && response.status < 400) {
      res.status(400).json({ error: "Redirects are not allowed." });
      return;
    }
    const html = await readResponseWithLimit(response, 1024 * 1024);
    const titleMatch = html.match(/<meta\s+property=["']og:title["']\s+content=["'](.*?)["']/i) ||
      html.match(/<title[^>]*>(.*?)<\/title>/i) ||
      html.match(/<meta\s+name=["']title["']\s+content=["'](.*?)["']/i);
    const descMatch = html.match(/<meta\s+property=["']og:description["']\s+content=["'](.*?)["']/i) ||
      html.match(/<meta\s+name=["']description["']\s+content=["'](.*?)["']/i);
    const imageMatch = html.match(/<meta\s+property=["']og:image["']\s+content=["'](.*?)["']/i) ||
      html.match(/<meta\s+name=["']twitter:image["']\s+content=["'](.*?)["']/i);
    const siteMatch = html.match(/<meta\s+property=["']og:site_name["']\s+content=["'](.*?)["']/i);

    let parsedUrl = null;
    try {
      parsedUrl = new URL(targetUrl);
    } catch (_) {}

    const title = titleMatch ? titleMatch[1].replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").slice(0, 120) : (parsedUrl?.hostname || targetUrl);
    const description = descMatch ? descMatch[1].replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").slice(0, 200) : "";
    let image = imageMatch ? imageMatch[1] : "";
    if (image && !image.startsWith("http") && parsedUrl) {
      image = new URL(image, parsedUrl.origin).href;
    }
    const siteName = siteMatch ? siteMatch[1] : (parsedUrl?.hostname.replace(/^www\./, '') || "");

    res.json({
      url: safeUrl.href,
      title,
      description,
      image,
      siteName,
      domain: parsedUrl?.hostname || "",
    });
  } catch (err) {
    const message = String(err?.message || "");
    const clientError = /Unsafe destination|Unsupported URL|credentials|Redirects|Response too large/.test(message);
    res.status(clientError ? 400 : 500).json({ error: clientError ? "URL is not allowed." : "Failed to parse link preview" });
  }
});

app.post("/api/import-wallpaper-url", async (req, res) => {
  const targetUrl = String(req.body?.url || "").trim();
  if (!targetUrl || !targetUrl.startsWith("http")) {
    return res.status(400).json({ error: "Invalid URL" });
  }

  try {
    let directImageUrl = targetUrl;

    // 1. Pinterest oEmbed handler for pins
    if (targetUrl.includes("pinterest.com/pin/") || targetUrl.includes("pin.it/")) {
      try {
        const oembedRes = await fetch(`https://www.pinterest.com/oembed.json?url=${encodeURIComponent(targetUrl)}`);
        if (oembedRes.ok) {
          const oembedData = await oembedRes.json();
          if (oembedData.url || oembedData.thumbnail_url) {
            directImageUrl = oembedData.url || oembedData.thumbnail_url;
          }
        }
      } catch (_) {}
    }

    // 2. OpenGraph / Twitter Image fallback if not a direct image file
    if (!directImageUrl.match(/\.(jpeg|jpg|gif|png|webp|svg)(\?.*)?$/i)) {
      try {
        const ogRes = await fetch(directImageUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          },
        });
        if (ogRes.ok) {
          const html = await ogRes.text();
          const ogImage = html.match(/<meta\s+(?:property|name)=["'](?:og:image|twitter:image)["']\s+content=["'](.*?)["']/i);
          if (ogImage && ogImage[1]) {
            directImageUrl = ogImage[1];
          }
        }
      } catch (_) {}
    }

    // 3. Download the image and cache locally in uploads directory
    try {
      const imgRes = await fetch(directImageUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          Referer: new URL(directImageUrl).origin,
        },
      });

      if (imgRes.ok) {
        const buffer = Buffer.from(await imgRes.arrayBuffer());
        let ext = path.extname(new URL(directImageUrl).pathname) || ".jpg";
        if (ext.length > 5 || !ext) ext = ".jpg";
        const filename = `wallpaper-${Date.now()}-${crypto.randomBytes(3).toString("hex")}${ext}`;
        const destPath = path.join(uploadsDir, filename);
        fs.writeFileSync(destPath, buffer);
        const token = signUploadToken(filename);
        return res.json({ url: `/uploads/${filename}?token=${token}` });
      }
    } catch (_) {}

    // Fallback to direct URL if fetch failed
    res.json({ url: directImageUrl });
  } catch (err) {
    console.error("Import wallpaper error:", err);
    res.json({ url: targetUrl });
  }
});

// ── Feedback Endpoint ─────────────────────────────────────────────────────
// Accepts feedback from any visitor (auth optional).
// Persists to MongoDB feedback collection + emails admin via SMTP.
{
  const FEEDBACK_TO_EMAIL = toDisplayName(process.env.FEEDBACK_TO_EMAIL || "");

  app.post("/api/feedback", createIpRateLimiter("feedback", 5, 60 * 60 * 1000), async (req, res) => {
    const type    = toDisplayName(req.body?.type    || "general").slice(0, 50);
    const message = toDisplayName(req.body?.message || "").slice(0, 2000);
    const email   = toDisplayName(req.body?.email   || "").slice(0, 200);
    const rating  = Number.isFinite(Number(req.body?.rating))
      ? Math.min(5, Math.max(1, Math.floor(Number(req.body.rating))))
      : null;

    if (!message || message.length < 5) {
      res.status(400).json({ error: "Message is too short." });
      return;
    }

    // Resolve sender — logged-in user or anonymous
    const cookieAuth = resolveUserFromAuthCookies(
      getAuthCookiesFromHeader(req.headers.cookie),
      { allowRefreshFallback: true }
    );
    const userKey  = cookieAuth.userKey || null;
    const user     = userKey ? users.get(userKey) : null;
    const fromUser = user ? (user.username || userKey) : "anonymous";

    const entry = {
      id:        `fb_${Date.now().toString(36)}_${crypto.randomBytes(3).toString("hex")}`,
      type,
      message,
      rating,
      email:     email || user?.email || "",
      fromUser,
      userKey,
      ip:        req.ip || "",
      createdAt: nowIso(),
    };

    // 1. Persist to MongoDB or flat-file fallback
    try {
      if (hasMongoStorage() && mongoClient) {
        const db = mongoClient.db(MONGODB_DB);
        await db.collection("feedback").insertOne(entry);
      } else {
        const feedbackFile = path.join(DATA_DIR, "feedback.log");
        await fsp.mkdir(DATA_DIR, { recursive: true });
        await fsp.appendFile(feedbackFile, `${JSON.stringify(entry)}\n`, "utf8");
      }
    } catch (err) {
      console.warn("Failed to save feedback:", err?.message || err);
    }

    // 2. Email notification to admin
    if (passwordResetMailer && FEEDBACK_TO_EMAIL) {
      const stars    = rating ? `${"★".repeat(rating)}${"☆".repeat(5 - rating)} (${rating}/5)` : "Not rated";
      const replyTo  = entry.email || null;
      const typeLabel = type.charAt(0).toUpperCase() + type.slice(1);
      try {
        await passwordResetMailer.sendMail({
          from:    process.env.SMTP_FROM,
          to:      FEEDBACK_TO_EMAIL,
          replyTo: replyTo || undefined,
          subject: `[Novyn Feedback] ${typeLabel} from ${fromUser}`,
          html: `
            <div style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px;background:#0d1117;color:#e2e8f0;border-radius:12px;">
              <h2 style="color:#10b981;margin:0 0 20px;font-size:1.3rem;">📬 New Feedback — Novyn</h2>
              <table style="width:100%;border-collapse:collapse;font-size:14px;margin-bottom:20px;">
                <tr><td style="padding:6px 0;color:#94a3b8;width:110px;">Type</td><td style="padding:6px 0;font-weight:700;color:#38bdf8;text-transform:capitalize;">${typeLabel}</td></tr>
                <tr><td style="padding:6px 0;color:#94a3b8;">From</td><td style="padding:6px 0;">${fromUser}${entry.email ? ` &lt;${entry.email}&gt;` : ""}</td></tr>
                <tr><td style="padding:6px 0;color:#94a3b8;">Rating</td><td style="padding:6px 0;">${stars}</td></tr>
                <tr><td style="padding:6px 0;color:#94a3b8;">Time</td><td style="padding:6px 0;">${entry.createdAt}</td></tr>
              </table>
              <div style="padding:16px 20px;background:#1e293b;border-radius:10px;border-left:4px solid #10b981;">
                <p style="margin:0;line-height:1.7;white-space:pre-wrap;font-size:14px;">${message.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")}</p>
              </div>
              <p style="margin-top:20px;font-size:11px;color:#475569;">ID: ${entry.id}</p>
            </div>
          `,
        });
      } catch (err) {
        console.warn("Failed to email feedback:", err?.message || err);
      }
    }

    res.json({ ok: true, id: entry.id });
  });
}

const distDir = path.join(__dirname, "dist");
const publicDir = path.join(__dirname, "public");

if (fs.existsSync(distDir)) {
  app.use(express.static(distDir));
}
app.use(express.static(publicDir));

app.use("/api", (req, res) => {
  res.status(404).json({ error: "Not found" });
});

app.get("*", (req, res, next) => {
  if (req.path.startsWith("/api") || req.path.startsWith("/uploads")) {
    return next();
  }
  if (fs.existsSync(path.join(distDir, "index.html"))) {
    return res.sendFile(path.join(distDir, "index.html"));
  }
  if (fs.existsSync(path.join(publicDir, "index.html"))) {
    return res.sendFile(path.join(publicDir, "index.html"));
  }
  next();
});

app.use((req, res) => {
  if (req.method === "GET" || req.method === "HEAD") {
    res.status(404);
    res.set("Cache-Control", "no-cache, must-revalidate");
    if (req.method === "HEAD") {
      res.end();
      return;
    }
    res.sendFile(path.join(__dirname, "404.html"));
    return;
  }
  res.status(404).json({ error: "Not found" });
});

io.use(
  createSocketAuthMiddleware({
    isProduction: process.env.NODE_ENV === "production",
    allowedOrigins: allowedSocketOrigins,
    resolveUserFromAuthCookies,
    getAuthCookiesFromHeader,
    normalizeText: toDisplayName,
  })
);

io.on("connection", (socket) => {
  socket.on("resume_session", () => {
    const userKey = resolveCurrentUserKey(socket.data.userKey);
    if (!userKey) {
      socket.emit("auth_failed", { message: "Session expired. Please sign in again." });
      return;
    }
    const user = users.get(userKey);
    if (!user || !user.isRegistered) {
      socket.emit("auth_failed", { message: "Session expired. Please sign in again." });
      return;
    }
    finalizeSocketAuthentication(socket, user);
  });
  socket.on("register", (payload) => {
    if (!allowSocketAction(socket, "register", 10, 15 * 60 * 1000)) {
      socket.emit("auth_failed", { message: "Too many authentication attempts. Try again later." });
      return;
    }
    const isStringPayload = typeof payload === "string";
    const raw = payload || {};
    const mode = isStringPayload ? "" : toDisplayName(raw?.mode || "").toLowerCase();
    const modeNormalized = mode === "signup" ? "signup" : "signin";
    const email = isStringPayload ? "" : normalizeEmail(raw?.email || "");
    const displayName = isStringPayload ? "" : toDisplayName(raw?.name || raw?.displayName || "");
    const usernameInput = isStringPayload ? toDisplayName(payload) : toDisplayName(raw?.username);
    const password = toDisplayName(isStringPayload ? "" : raw?.password);

    let user = null;

    if (email) {
      const existingByEmail = findUserByEmail(email);
      const wantsSignup = modeNormalized === "signup";
      const wantsSignin = !wantsSignup;

      if (wantsSignin) {
        if (!existingByEmail || !existingByEmail.isRegistered) {
          socket.emit("auth_failed", { message: "Email doesn't exist. Sign up." });
          return;
        }
        if (!password) {
          socket.emit("auth_failed", { message: "Password is required." });
          return;
        }
        if (!verifyPassword(password, existingByEmail.passwordSalt, existingByEmail.passwordHash)) {
          socket.emit("auth_failed", { message: "Incorrect password." });
          return;
        }
        user = existingByEmail;
      } else {
        if (isEmailTaken(email)) {
          socket.emit("auth_failed", { message: "Email already registered. Sign in." });
          return;
        }
        if (!displayName) {
          socket.emit("auth_failed", { message: "Name is required to sign up." });
          return;
        }
        const requestedHandle = normalizeHandleInput(usernameInput);
        if (!requestedHandle) {
          socket.emit("auth_failed", { message: "Username is required." });
          return;
        }
        if (isUsernameTaken(requestedHandle)) {
          socket.emit("auth_failed", { message: "This username is taken." });
          return;
        }
        if (password.length < MIN_PASSWORD_LENGTH) {
          socket.emit("auth_failed", {
            message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.`,
          });
          return;
        }
        const username = requestedHandle;
        user = getOrCreateUser(username);
        const secret = createPasswordSecret(password);
        user.passwordSalt = secret.passwordSalt;
        user.passwordHash = secret.passwordHash;
        user.isRegistered = true;
        user.email = email;
        user.displayName = displayName;
        if (!user.createdAt) {
          user.createdAt = nowIso();
        }
      }
    } else {
      const wantsSignup = modeNormalized === "signup";
      const username = usernameInput;
      const userKey = normalizeName(username);

      if (wantsSignup) {
        socket.emit("auth_failed", { message: "Email is required to sign up." });
        return;
      }

      if (!username) {
        socket.emit("auth_failed", { message: "Username is required." });
        return;
      }

      const existing = users.get(userKey);
      const usernameExists = Boolean(existing?.isRegistered);
      const suggestions = buildUsernameSuggestions(username);

      if (!usernameExists) {
        socket.emit("auth_failed", {
          message: "Username doesn't exist. Sign up.",
          suggestions,
        });
        return;
      }

      if (!password) {
        socket.emit("auth_failed", {
          message: "Password is required.",
          suggestions,
        });
        return;
      }

      if (!existing.passwordSalt || !existing.passwordHash) {
        const secret = createPasswordSecret(password);
        existing.passwordSalt = secret.passwordSalt;
        existing.passwordHash = secret.passwordHash;
      } else if (!verifyPassword(password, existing.passwordSalt, existing.passwordHash)) {
        socket.emit("auth_failed", {
          message: "Incorrect password.",
          suggestions,
        });
        return;
      }

      existing.username = username;
      existing.lastSeenAt = "";
      user = existing;
    }

    if (!user) {
      socket.emit("error_message", { message: "Unable to authenticate." });
      return;
    }

    finalizeSocketAuthentication(socket, user);
  });
  socket.on("request_password_reset", async (payload) => {
    pruneExpiredPasswordResetTokens();
    const identifier = toDisplayName(payload?.identifier || payload?.email || payload);
    const genericSentMessage = "If an account exists, a reset code has been sent.";
    if (!isPasswordResetDeliveryAvailable()) {
      socket.emit("password_reset_failed", {
        message: "Password reset email service is unavailable. Try again later.",
      });
      return;
    }
    if (!identifier) {
      socket.emit("password_reset_sent", { message: genericSentMessage });
      return;
    }

    const isEmail = identifier.includes("@");
    const user = isEmail ? findUserByEmail(identifier) : users.get(normalizeName(identifier));
    if (!user || !user.isRegistered) {
      socket.emit("password_reset_sent", { message: genericSentMessage });
      return;
    }

    const userKey = normalizeName(user.username);
    const rate = canIssuePasswordReset(userKey);
    if (!rate.allowed) {
      socket.emit("password_reset_failed", { message: rate.message });
      return;
    }

    const existingTokenId = passwordResetByUser.get(userKey);
    if (existingTokenId) dropPasswordResetTokenById(existingTokenId);

    const token = createResetToken();
    const salt = crypto.randomBytes(8).toString("hex");
    const tokenHash = createResetTokenHash(token, salt);
    const tokenId = createResetTokenId();
    const expiresAt = Date.now() + PASSWORD_RESET_CODE_TTL_MS;
    passwordResetTokens.set(tokenId, {
      userKey,
      salt,
      tokenHash,
      expiresAt,
      attemptsLeft: PASSWORD_RESET_MAX_ATTEMPTS,
    });
    passwordResetByUser.set(userKey, tokenId);
    markPasswordResetIssued(userKey, rate.state);
    const dispatched = await dispatchPasswordResetCode(user, token);
    if (!dispatched) {
      dropPasswordResetTokenById(tokenId);
      socket.emit("password_reset_sent", { message: genericSentMessage });
      return;
    }

    socket.emit("password_reset_sent", {
      message: genericSentMessage,
    });
  });

  socket.on("reset_password", (payload) => {
    pruneExpiredPasswordResetTokens();
    const identifier = toDisplayName(payload?.identifier || payload?.email || payload?.username || "");
    const token = toDisplayName(payload?.token || "");
    const newPassword = toDisplayName(payload?.newPassword || "");
    if (!identifier || !token || !newPassword) {
      socket.emit("password_reset_failed", { message: "Email/username, reset code, and new password are required." });
      return;
    }
    if (newPassword.length < MIN_PASSWORD_LENGTH) {
      socket.emit("password_reset_failed", {
        message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.`,
      });
      return;
    }
    const isEmail = identifier.includes("@");
    const user = isEmail ? findUserByEmail(identifier) : users.get(normalizeName(identifier));
    if (!user || !user.isRegistered) {
      socket.emit("password_reset_failed", { message: "Invalid or expired reset code." });
      return;
    }

    const userKey = normalizeName(user.username);
    const tokenId = passwordResetByUser.get(userKey);
    const entry = tokenId ? passwordResetTokens.get(tokenId) : null;
    if (!entry || entry.userKey !== userKey) {
      socket.emit("password_reset_failed", { message: "Invalid or expired reset code." });
      return;
    }

    if (Date.now() > Number(entry.expiresAt)) {
      dropPasswordResetTokenById(tokenId);
      socket.emit("password_reset_failed", { message: "Reset code expired. Request a new one." });
      return;
    }

    if (!Number.isFinite(Number(entry.attemptsLeft)) || Number(entry.attemptsLeft) <= 0) {
      dropPasswordResetTokenById(tokenId);
      socket.emit("password_reset_failed", { message: "Too many attempts. Request a new code." });
      return;
    }

    const expectedHash = createResetTokenHash(token, entry.salt);
    if (expectedHash !== entry.tokenHash) {
      entry.attemptsLeft = Math.max(0, Number(entry.attemptsLeft) - 1);
      if (entry.attemptsLeft <= 0) {
        dropPasswordResetTokenById(tokenId);
        socket.emit("password_reset_failed", { message: "Too many attempts. Request a new code." });
        return;
      }
      socket.emit("password_reset_failed", {
        message: `Invalid reset code. ${entry.attemptsLeft} attempt(s) left.`,
      });
      return;
    }

    const secret = createPasswordSecret(newPassword);
    user.passwordSalt = secret.passwordSalt;
    user.passwordHash = secret.passwordHash;
    user.isRegistered = true;
    revokeAllRefreshSessionsForUser(userKey);

    dropPasswordResetTokenById(tokenId);
    schedulePersist();

    socket.emit("password_reset_success", { message: "Password updated. Please sign in." });
  });

  socket.on("request_email_change_code", async (payload, respond) => {
    const reply = (data) => {
      if (typeof respond === "function") {
        try {
          respond(data);
        } catch (_) {}
        return true;
      }
      return false;
    };
    const fail = (message) => {
      const packet = { ok: false, message };
      if (!reply(packet)) {
        socket.emit("email_change_failed", { message });
      }
    };
    const success = (message, email) => {
      const packet = { ok: true, message, email: email || "" };
      if (!reply(packet)) {
        socket.emit("email_change_code_sent", { message, email: email || "" });
      }
    };

    const userKey = socket.data.userKey;
    if (!userKey) {
      fail("Sign in again to continue.");
      return;
    }
    if (!isPasswordResetDeliveryAvailable()) {
      fail("Email verification service is unavailable. Try again later.");
      return;
    }

    const user = users.get(userKey);
    if (!user || !user.isRegistered) {
      fail("Sign in again to continue.");
      return;
    }

    pruneExpiredEmailChangeTokens();
    const nextEmail = normalizeEmail(payload?.email || payload?.newEmail || "");
    const currentEmail = normalizeEmail(user.email || "");

    if (!nextEmail) {
      fail("Enter your new email address.");
      return;
    }
    if (!isPlausibleEmail(nextEmail)) {
      fail("Enter a valid email address.");
      return;
    }
    if (nextEmail === currentEmail) {
      fail("That email is already linked to your account.");
      return;
    }

    const existing = findUserByEmail(nextEmail);
    if (existing && normalizeName(existing.username) !== userKey) {
      fail("Email already linked to another account.");
      return;
    }

    const rate = canIssueEmailChangeCode(userKey);
    if (!rate.allowed) {
      fail(rate.message);
      return;
    }

    const previousTokenId = emailChangeByUser.get(userKey);
    if (previousTokenId) dropEmailChangeTokenById(previousTokenId);

    const token = createResetToken();
    const salt = crypto.randomBytes(8).toString("hex");
    const tokenHash = createResetTokenHash(token, salt);
    const tokenId = createResetTokenId();
    const expiresAt = Date.now() + EMAIL_CHANGE_CODE_TTL_MS;
    emailChangeTokens.set(tokenId, {
      userKey,
      pendingEmail: nextEmail,
      salt,
      tokenHash,
      expiresAt,
      attemptsLeft: EMAIL_CHANGE_MAX_ATTEMPTS,
    });
    emailChangeByUser.set(userKey, tokenId);
    markEmailChangeCodeIssued(userKey, rate.state);

    const dispatched = await dispatchEmailChangeCode(user, nextEmail, token);
    if (!dispatched) {
      dropEmailChangeTokenById(tokenId);
      fail("Email verification service is unavailable. Try again later.");
      return;
    }

    success(`Verification code sent to ${maskEmailAddress(nextEmail)}.`, nextEmail);
  });

  socket.on("verify_email_change_code", (payload, respond) => {
    const reply = (data) => {
      if (typeof respond === "function") {
        try {
          respond(data);
        } catch (_) {}
        return true;
      }
      return false;
    };
    const fail = (message) => {
      const packet = { ok: false, message };
      if (!reply(packet)) {
        socket.emit("email_change_failed", { message });
      }
    };
    const success = (message, email) => {
      const packet = { ok: true, message, email: email || "" };
      if (!reply(packet)) {
        socket.emit("email_change_verified", { message, email: email || "" });
      }
    };

    const userKey = socket.data.userKey;
    if (!userKey) {
      fail("Sign in again to continue.");
      return;
    }

    const user = users.get(userKey);
    if (!user || !user.isRegistered) {
      fail("Sign in again to continue.");
      return;
    }

    pruneExpiredEmailChangeTokens();
    const nextEmail = normalizeEmail(payload?.email || payload?.newEmail || "");
    const token = toDisplayName(payload?.token || payload?.code || "");
    if (!nextEmail || !token) {
      fail("Email and verification code are required.");
      return;
    }

    const tokenId = emailChangeByUser.get(userKey);
    const entry = tokenId ? emailChangeTokens.get(tokenId) : null;
    if (!entry || entry.userKey !== userKey) {
      fail("Invalid or expired verification code.");
      return;
    }

    if (normalizeEmail(entry.pendingEmail || "") !== nextEmail) {
      fail("This code was issued for a different email. Request a new code.");
      return;
    }

    if (Date.now() > Number(entry.expiresAt)) {
      dropEmailChangeTokenById(tokenId);
      fail("Verification code expired. Request a new one.");
      return;
    }

    if (!Number.isFinite(Number(entry.attemptsLeft)) || Number(entry.attemptsLeft) <= 0) {
      dropEmailChangeTokenById(tokenId);
      fail("Too many attempts. Request a new code.");
      return;
    }

    const existing = findUserByEmail(nextEmail);
    if (existing && normalizeName(existing.username) !== userKey) {
      dropEmailChangeTokenById(tokenId);
      fail("Email already linked to another account.");
      return;
    }

    const expectedHash = createResetTokenHash(token, entry.salt);
    if (expectedHash !== entry.tokenHash) {
      entry.attemptsLeft = Math.max(0, Number(entry.attemptsLeft) - 1);
      if (entry.attemptsLeft <= 0) {
        dropEmailChangeTokenById(tokenId);
        fail("Too many attempts. Request a new code.");
        return;
      }
      fail(`Invalid verification code. ${entry.attemptsLeft} attempt(s) left.`);
      return;
    }

    user.email = nextEmail;
    dropEmailChangeTokenById(tokenId);
    schedulePersist();

    socket.emit("profile_updated", {
      avatarId: user.avatarId,
      age: user.age,
      gender: user.gender,
      displayName: user.displayName,
      bio: user.bio,
      email: user.email || "",
    });
    success("Email linked successfully.", user.email || "");
  });

  socket.on("push_subscribe", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey || !pushEnabled) return;
    const subscription = payload?.subscription || payload;
    const endpoint = toDisplayName(subscription?.endpoint);
    if (!endpoint) return;
    const detached = detachSubscriptionFromAll(endpoint, userKey);
    const user = users.get(userKey);
    const updated = upsertPushSubscription(user, subscription);
    if (updated || detached) {
      schedulePersist();
    }
  });

  socket.on("push_unsubscribe", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const endpoint = toDisplayName(payload?.endpoint);
    if (!endpoint) return;
    const user = users.get(userKey);
    if (removePushSubscription(user, endpoint)) {
      schedulePersist();
    }
  });

  socket.on("friend_search", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const me = users.get(userKey);
    if (!me) return;
    const query = toDisplayName(payload?.query || payload);
    if (!query) {
      socket.emit("friend_suggestions", { query: "", suggestions: [] });
      return;
    }
    const suggestions = buildFriendSearchSuggestions(query, me, 8);
    socket.emit("friend_suggestions", { query, suggestions });
  });

  socket.on("update_profile", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) return;

    if (payload?.displayName !== undefined) {
      user.displayName = toDisplayName(payload.displayName).slice(0, 50);
    }
    if (payload?.bio !== undefined) {
      user.bio = toDisplayName(payload.bio).slice(0, 160);
    }
    if (payload?.avatarId !== undefined) {
      user.avatarId = toDisplayName(payload.avatarId);
    }
    if (payload?.presenceMode !== undefined || payload?.status !== undefined) {
      user.presenceMode = normalizePresenceMode(payload.presenceMode || payload.status);
    }

    schedulePersist();

    socket.emit("profile_updated", {
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatarId: user.avatarId,
      presenceMode: user.presenceMode,
      email: user.email || "",
    });

    emitFriendList(userKey);
    for (const friendKey of user.friends) {
      emitFriendList(friendKey);
      const friendSocket = onlineUsers.get(friendKey);
      if (friendSocket) {
        io.to(friendSocket).emit("user_profile_updated", {
          username: user.username,
          displayName: user.displayName,
          bio: user.bio,
          avatarId: user.avatarId,
        });
      }
    }
    emitDiscoverOnlineToAll();
  });

  socket.on("change_username", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("username_change_failed", { message: "User not found." });
      return;
    }

    const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
    const desired = toDisplayName(payload?.newUsername);

    if (!currentPassword || !verifyPassword(currentPassword, user.passwordSalt, user.passwordHash)) {
      socket.emit("username_change_failed", { message: "Incorrect password." });
      return;
    }

    const result = applyUsernameChange(userKey, desired);
    if (!result.ok) {
      socket.emit("username_change_failed", { message: result.message || "Unable to change username." });
      return;
    }

    socket.data.userKey = result.newKey;

    // Update any sockets that had the old key as active chat
    onlineUsers.forEach((socketId) => {
      const friendSocket = io.sockets.sockets.get(socketId);
      if (friendSocket?.data?.activeChatWith === result.oldKey) {
        friendSocket.data.activeChatWith = result.newKey;
      }
    });

    // Notify the user first
    socket.emit("username_changed", {
      oldUsername: result.oldUsername,
      newUsername: result.newUsername,
    });

    const impacted = new Set();
    users.forEach((other, otherKey) => {
      if (!other || otherKey === result.newKey) return;
      if (
        other.friends.has(result.newKey)
        || other.requests.has(result.newKey)
        || other.unread.has(result.newKey)
        || (other.blockedUsers instanceof Set && other.blockedUsers.has(result.newKey))
        || (other.mutedUsers instanceof Set && other.mutedUsers.has(result.newKey))
      ) {
        impacted.add(otherKey);
      }
    });

    impacted.forEach((key) => {
      const socketId = onlineUsers.get(key);
      if (socketId) {
        io.to(socketId).emit("friend_username_changed", {
          oldUsername: result.oldUsername,
          newUsername: result.newUsername,
        });
      }
    });

    impacted.forEach((key) => {
      emitFriendList(key);
      emitRequests(key);
    });

    emitFriendList(result.newKey);
    emitRequests(result.newKey);
    emitStatusToFriends(result.newKey);
    emitDiscoverOnlineToAll();
    schedulePersist();
  });

  socket.on("change_password", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("password_change_failed", { message: "User not found." });
      return;
    }

    const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
    const nextPassword = toDisplayName(payload?.newPassword);

    if (!currentPassword || !verifyPassword(currentPassword, user.passwordSalt, user.passwordHash)) {
      socket.emit("password_change_failed", { message: "Incorrect password." });
      return;
    }
    if (!nextPassword || nextPassword.length < MIN_PASSWORD_LENGTH) {
      socket.emit("password_change_failed", {
        message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.`,
      });
      return;
    }

    const secret = createPasswordSecret(nextPassword);
    user.passwordSalt = secret.passwordSalt;
    user.passwordHash = secret.passwordHash;
    revokeAllRefreshSessionsForUser(userKey);
    schedulePersist();

    socket.emit("password_changed");
  });

  socket.on("accept_friend", (rawFriendName) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    const friendName = toDisplayName(rawFriendName);
    const friendKey = normalizeName(friendName);

    const me = users.get(userKey);
    const friend = users.get(friendKey);

    if (!me || !friend || !me.requests.has(friendKey)) {
      socket.emit("error_message", { message: "No pending request from this user." });
      return;
    }
    if (usersAreBlocked(userKey, friendKey)) {
      socket.emit("error_message", { message: "Friend request cannot be accepted while one of you is blocked." });
      return;
    }

    me.requests.delete(friendKey);
    me.friends.add(friendKey);
    friend.friends.add(userKey);
    initializeUnreadPair(userKey, friendKey);

    emitRequests(userKey);
    emitFriendList(userKey);
    emitFriendList(friendKey);

    socket.emit("friend_request_accepted", { by: friend.username });

    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("friend_request_accepted", { by: me.username });
    }

    schedulePersist();
  });

  socket.on("remove_friend", (rawFriendName) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    const friendName = toDisplayName(rawFriendName);
    const friendKey = normalizeName(friendName);

    const me = users.get(userKey);
    const friend = users.get(friendKey);

    if (!me || !friend || !me.friends.has(friendKey)) {
      socket.emit("error_message", { message: "This user is not in your friends list." });
      return;
    }

    const removed = removeFriendship(userKey, friendKey);
    if (!removed) {
      socket.emit("error_message", { message: "Could not remove friend. Try again." });
      return;
    }

    if (socket.data.activeChatWith === friendKey) {
      socket.data.activeChatWith = null;
    }

    const friendSocketId = onlineUsers.get(friendKey);
    if (friendSocketId) {
      const friendSocket = io.sockets.sockets.get(friendSocketId);
      if (friendSocket && friendSocket.data.activeChatWith === userKey) {
        friendSocket.data.activeChatWith = null;
      }
    }

    socket.emit("typing", {
      from: friend.username,
      isTyping: false,
    });

    if (friendSocketId) {
      io.to(friendSocketId).emit("typing", {
        from: me.username,
        isTyping: false,
      });
    }

    emitFriendList(userKey);
    emitFriendList(friendKey);
    emitRequests(userKey);
    emitRequests(friendKey);

    socket.emit("friend_removed", {
      username: friend.username,
      by: me.username,
    });

    if (friendSocketId) {
      io.to(friendSocketId).emit("friend_removed", {
        username: me.username,
        by: me.username,
      });
    }

    schedulePersist();
  });

  socket.on("get_history", (rawTarget) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    let targetName = rawTarget;
    let targetType = "friend";
    if (rawTarget && typeof rawTarget === "object") {
      targetName = rawTarget.to || rawTarget.username || rawTarget.groupId || "";
      targetType = rawTarget.kind || rawTarget.type || rawTarget.toType || "friend";
    }
    const resolved = resolveChatTargetForUser(userKey, targetName, targetType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "Unable to open this chat." });
      return;
    }

    runRetentionMaintenance();
    socket.data.activeChatWith = resolved.targetKey;
    socket.data.activeChatKind = resolved.type;
    markConversationAsSeen(userKey, resolved.targetKey, resolved.type);

    const allMessages = conversations.get(resolved.conversationKey) || [];
    const requestedLimit = rawTarget && typeof rawTarget === "object"
      ? Number(rawTarget.limit)
      : NaN;
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(100, Math.max(1, Math.floor(requestedLimit)))
      : 50;
    const before = rawTarget && typeof rawTarget === "object"
      ? toDisplayName(rawTarget.before)
      : "";

    let endIndex = allMessages.length;
    if (before) {
      const beforeIndex = allMessages.findIndex(
        (message) =>
          String(message?.id || "") === before ||
          String(message?.clientTempId || "") === before
      );
      if (beforeIndex >= 0) endIndex = beforeIndex;
    }

    const startIndex = Math.max(0, endIndex - limit);
    const messages = allMessages.slice(startIndex, endIndex);
    const hasMore = startIndex > 0;
    const nextBefore = hasMore ? String(messages[0]?.id || messages[0]?.clientTempId || "") : null;
    const wallpaper = conversationWallpapers.get(resolved.conversationKey) || "";

    socket.emit("history", {
      with: resolved.targetKey,
      withLabel: resolved.targetLabel,
      messages,
      hasMore,
      nextBefore,
      kind: resolved.type,
      toType: resolved.type,
      to: resolved.targetKey,
      wallpaper,
      memberCount: resolved.type === "group" ? resolved.group.members.size : 2,
    });
  });

  socket.on("clear_chat", (rawTarget) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "clear_chat", 60, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Clear chat rate limit reached. Try again later." });
      return;
    }

    let targetName = rawTarget;
    let targetType = "friend";
    if (rawTarget && typeof rawTarget === "object") {
      targetName = rawTarget.to || rawTarget.username || rawTarget.groupId || "";
      targetType = rawTarget.kind || rawTarget.type || rawTarget.toType || "friend";
    }

    const resolved = resolveChatTargetForUser(userKey, targetName, targetType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "Unable to clear this chat." });
      return;
    }
    if (resolved.type === "group") {
      const role = getGroupMemberRole(resolved.group, userKey);
      if (role !== "owner" && role !== "admin") {
        socket.emit("error_message", { message: "Only group admins can clear group chat." });
        return;
      }
    }

    conversations.delete(resolved.conversationKey);

    const affectedUsers = new Set();
    if (resolved.type === "group") {
      const groupId = resolved.group.id;
      for (const memberKey of resolved.group.members) {
        const normalizedMemberKey = normalizeName(memberKey);
        const member = users.get(normalizedMemberKey);
        if (!member) continue;
        setUnreadCount(member, groupId, 0);
        affectedUsers.add(normalizedMemberKey);
      }
    } else {
      const me = users.get(userKey);
      const friend = users.get(resolved.targetKey);
      if (me) setUnreadCount(me, resolved.targetKey, 0);
      if (friend) setUnreadCount(friend, userKey, 0);
      affectedUsers.add(userKey);
      affectedUsers.add(resolved.targetKey);
    }

    const payload = {
      to: resolved.targetKey,
      with: resolved.targetKey,
      toType: resolved.type,
      kind: resolved.type,
      by: resolved.me?.username || userKey,
    };

    for (const targetKey of affectedUsers) {
      emitFriendList(targetKey);
      const targetSocketId = onlineUsers.get(targetKey);
      if (targetSocketId) {
        io.to(targetSocketId).emit("chat_cleared", payload);
      }
    }

    schedulePersist();
  });

  socket.on("set_active_chat", (rawTarget) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    let targetName = rawTarget;
    let targetType = "friend";
    if (rawTarget && typeof rawTarget === "object") {
      targetName = rawTarget.to || rawTarget.username || rawTarget.groupId || "";
      targetType = rawTarget.kind || rawTarget.type || rawTarget.toType || "friend";
    }
    const cleanTarget = toDisplayName(targetName);
    if (!cleanTarget) {
      socket.data.activeChatWith = null;
      socket.data.activeChatKind = "friend";
      return;
    }

    const resolved = resolveChatTargetForUser(userKey, cleanTarget, targetType, { inferGroup: true });
    if (!resolved.ok) {
      socket.data.activeChatWith = null;
      socket.data.activeChatKind = "friend";
      return;
    }

    socket.data.activeChatWith = resolved.targetKey;
    socket.data.activeChatKind = resolved.type;
  });

  socket.on("unsend_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    if (!list) return;
    const idx = list.findIndex((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
    if (idx === -1) return;
    const item = list[idx];
    if (normalizeName(item?.from) !== userKey) {
      socket.emit("error_message", { message: "You can only unsend your own messages." });
      return;
    }
    list.splice(idx, 1);
    schedulePersist();

    const packet = { messageId, to: to, from: userKey };
    socket.emit("message_unsent", packet);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("message_unsent", packet);
    }
  });

  socket.on("edit_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    const newText = withUploadToken(payload?.text || "").trim();
    if (!messageId || !to || !newText) return;

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    let editedAt = nowIso();
    if (list) {
      const idx = list.findIndex((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (idx !== -1) {
        const item = list[idx];
        if (normalizeName(item?.from) !== userKey) {
          socket.emit("error_message", { message: "You can only edit your own messages." });
          return;
        }
        if (item.isEncrypted) {
          socket.emit("error_message", { message: "Encrypted messages cannot be edited yet." });
          return;
        }
        item.text = newText;
        item.editedAt = editedAt;
        schedulePersist();
      }
    }

    const packet = { messageId, text: newText, editedAt, to: to, from: userKey };
    socket.emit("message_edited", packet);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("message_edited", packet);
    }
  });

  socket.on("add_reaction", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    const emoji = String(payload?.emoji || "").trim();
    if (!messageId || !to || !emoji) return;

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    let reactions = {};
    if (list) {
      const idx = list.findIndex((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (idx !== -1) {
        const item = list[idx];
        if (!item.reactions) item.reactions = {};
        if (!item.reactions[emoji]) item.reactions[emoji] = [];
        const userIdx = item.reactions[emoji].indexOf(userKey);
        if (userIdx !== -1) {
          item.reactions[emoji].splice(userIdx, 1);
          if (item.reactions[emoji].length === 0) delete item.reactions[emoji];
        } else {
          item.reactions[emoji].push(userKey);
        }
        reactions = item.reactions;
        schedulePersist();
      }
    }

    const packet = { messageId, reactions, to: to, from: userKey };
    socket.emit("reaction_updated", packet);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("reaction_updated", packet);
    }
  });

  socket.on("pin_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;
    const resolvedTarget = resolveChatTargetForUser(userKey, to, payload?.toType || payload?.kind || "friend", { inferGroup: true });
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: resolvedTarget.message || "You are not authorized for this chat." });
      return;
    }

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    let pinnedMessage = null;
    if (list) {
      const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (item) {
        item.pinnedAt = nowIso();
        item.pinnedBy = userKey;
        pinnedMessage = item;
        schedulePersist();
      }
    }

    const packet = { messageId, pinnedAt: pinnedMessage?.pinnedAt || nowIso(), pinnedBy: userKey, to: to, from: userKey };
    socket.emit("message_pinned", packet);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("message_pinned", packet);
    }
  });

  socket.on("unpin_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;
    const resolvedTarget = resolveChatTargetForUser(userKey, to, payload?.toType || payload?.kind || "friend", { inferGroup: true });
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: resolvedTarget.message || "You are not authorized for this chat." });
      return;
    }

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    if (list) {
      const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (item) {
        item.pinnedAt = null;
        item.pinnedBy = "";
        schedulePersist();
      }
    }

    const packet = { messageId, to: to, from: userKey };
    socket.emit("message_unpinned", packet);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("message_unpinned", packet);
    }
  });

  socket.on("create_poll", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const question = String(payload?.question || "").trim();
    const optionsRaw = Array.isArray(payload?.options) ? payload.options : [];
    if (!to || !question || optionsRaw.length < 2) return;
    if (!resolveChatTargetForUser(userKey, to, "friend", { inferGroup: true }).ok) {
      socket.emit("error_message", { message: "You are not authorized to create a poll here." });
      return;
    }

    const options = optionsRaw.slice(0, 8).map((opt, i) => ({
      id: `opt_${i}_${Date.now()}`,
      text: String(opt).trim(),
      votes: [],
    }));

    const poll = {
      id: `poll_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`,
      question,
      options,
      totalVotes: 0,
    };

    const clientTempId = payload?.clientTempId || `tmp_poll_${Date.now()}`;
    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    let list = conversations.get(convKey);
    if (!list) {
      list = [];
      conversations.set(convKey, list);
    }

    const msg = {
      id: poll.id,
      clientTempId,
      from: userKey,
      to: friendKey,
      text: `📊 Poll: ${question}`,
      timestamp: nowIso(),
      poll,
      status: "sent",
    };

    list.push(msg);
    schedulePersist();

    socket.emit("private_message", msg);
    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("private_message", msg);
    }
  });

  socket.on("poll_vote", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || "");
    const optionId = String(payload?.optionId || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !optionId || !to) return;

    const friendKey = normalizeName(to);
    const convKey = getConversationKey(userKey, friendKey);
    const list = conversations.get(convKey);
    let updatedPoll = null;

    if (list) {
      const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (item && item.poll) {
        let total = 0;
        item.poll.options.forEach((opt) => {
          const idx = opt.votes.indexOf(userKey);
          if (opt.id === optionId) {
            if (idx === -1) opt.votes.push(userKey);
            else opt.votes.splice(idx, 1);
          } else {
            if (idx !== -1) opt.votes.splice(idx, 1);
          }
          total += opt.votes.length;
        });
        item.poll.totalVotes = total;
        updatedPoll = item.poll;
        schedulePersist();
      }
    }

    if (updatedPoll) {
      const packet = { messageId, poll: updatedPoll, to, from: userKey };
      socket.emit("poll_updated", packet);
      const friendSocket = onlineUsers.get(friendKey);
      if (friendSocket) {
        io.to(friendSocket).emit("poll_updated", packet);
      }
    }
  });

  socket.on("game_move", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || "");
    const moveData = payload?.moveData || {};
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;

    const resolvedTarget = resolveChatTargetForUser(userKey, to, "friend", { inferGroup: true });
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: "You are not authorized to modify this game." });
      return;
    }

    const isGroup = resolvedTarget.type === "group";
    const convKey = isGroup ? getGroupConversationKey(to) : getConversationKey(userKey, to);
    const list = conversations.get(convKey);
    let updatedGame = null;

    if (list) {
      const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (item && item.game) {
        item.game = {
          ...item.game,
          state: moveData.state || item.game.state,
          turn: moveData.turn !== undefined ? moveData.turn : item.game.turn,
          winner: moveData.winner !== undefined ? moveData.winner : item.game.winner,
          data: {
            ...item.game.data,
            ...moveData,
          },
          lastMoveBy: userKey,
          updatedAt: Date.now(),
        };
        updatedGame = item.game;
        schedulePersist();
      }
    }

    if (updatedGame) {
      const packet = { messageId, moveData, updatedBy: userKey, to, from: userKey };
      socket.emit("game_move_updated", packet);
      if (isGroup) {
        const group = groups.get(normalizeGroupId(to));
        if (group) {
          for (const memberKey of group.members || []) {
            const memberSocketId = onlineUsers.get(normalizeName(memberKey));
            if (memberSocketId && normalizeName(memberKey) !== userKey) {
              io.to(memberSocketId).emit("game_move_updated", packet);
            }
          }
        }
      } else {
        const friendKey = normalizeName(to);
        const friendSocket = onlineUsers.get(friendKey);
        if (friendSocket) {
          io.to(friendSocket).emit("game_move_updated", packet);
        }
      }
    }
  });

  socket.on("set_chat_wallpaper", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const wallpaper = String(payload?.wallpaper || "").trim();
    if (!to) return;

    const isGroup = groups.has(normalizeGroupId(to)) || to.startsWith("grp_");
    const convKey = isGroup ? getGroupConversationKey(to) : getConversationKey(userKey, to);
    conversationWallpapers.set(convKey, wallpaper);
    schedulePersist();

    const packet = { to, from: userKey, wallpaper };
    socket.emit("chat_wallpaper_updated", packet);

    if (isGroup) {
      const group = groups.get(normalizeGroupId(to));
      if (group) {
        for (const memberKey of group.members || []) {
          for (const [_, s] of io.sockets.sockets) {
            if (s.data.userKey === memberKey) {
              s.emit("chat_wallpaper_updated", { to, from: userKey, wallpaper });
            }
          }
        }
      }
    } else {
      const friendKey = normalizeName(to);
      for (const [_, s] of io.sockets.sockets) {
        if (s.data.userKey === friendKey || s.data.userKey === userKey) {
          s.emit("chat_wallpaper_updated", { to: userKey, from: userKey, wallpaper });
        }
      }
    }
  });

  socket.on("get_chat_wallpaper", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    if (!to) return;

    const isGroup = groups.has(normalizeGroupId(to)) || to.startsWith("grp_");
    const convKey = isGroup ? getGroupConversationKey(to) : getConversationKey(userKey, to);
    const wallpaper = conversationWallpapers.get(convKey) || "";
    socket.emit("chat_wallpaper_updated", { to, from: userKey, wallpaper });
  });

  registerCallHandlers(socket, {
    resolveChatTargetForUser,
    toDisplayName,
    users,
    normalizeName,
    onlineUsers,
    activeCalls,
    setCallPair,
    clearCallPair,
    io
  });

  socket.on("private_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "private_message", 40, 60 * 1000)) {
      socket.emit("error_message", { message: "Message rate limit reached. Slow down a bit." });
      return;
    }

    const isEncrypted = Boolean(payload?.isEncrypted);
    const ciphertext = toDisplayName(payload?.ciphertext);
    const iv = toDisplayName(payload?.iv);
    if (isEncrypted && (!ciphertext || !iv)) {
      socket.emit("error_message", { message: "Invalid encrypted message payload." });
      return;
    }
    // Never store a client-supplied plaintext body for an encrypted message.
    const text = isEncrypted ? ENCRYPTED_MESSAGE_PLACEHOLDER : withUploadToken(payload?.text);
    const attachment = sanitizeMessageAttachment(payload?.attachment, text);
    const clientTempId = String(payload?.clientTempId || "").trim();
    const safeClientTempId = clientTempId.slice(0, 64);
    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const replyTo = normalizeReplyPayload(payload?.replyTo);
    if (isEncrypted && replyTo) replyTo.text = ENCRYPTED_MESSAGE_PLACEHOLDER;
    const game = payload?.game || null;
    const poll = payload?.poll || null;

    if (!text) return;
    if (text.length > MAX_MESSAGE_LENGTH) {
      socket.emit("error_message", { message: `Message too long. Limit is ${MAX_MESSAGE_LENGTH} characters.` });
      return;
    }

    if (toType === "group") {
      const result = deliverGroupMessage({
        fromKey: userKey,
        groupId: to,
        text,
        attachment,
        replyTo,
        game,
        poll,
        clientTempId: safeClientTempId,
      });
      if (!result.ok) {
        socket.emit("error_message", { message: result.message || "Unable to send message to this group." });
        return;
      }
      if (result.existing) {
        socket.emit("private_message", result.message);
      }
      return;
    }

    const result = deliverFriendMessage({
      fromKey: userKey,
      toKey: to,
      text,
      attachment,
      replyTo,
      game,
      poll,
      ciphertext,
      iv,
      isEncrypted,
      clientTempId: safeClientTempId,
    });
    if (!result.ok) {
      if (result.code === "blocked" && safeClientTempId) {
        socket.emit("delivery_blocked", {
          clientTempId: safeClientTempId,
          to: result.friend?.username || to,
          reason: "blocked",
        });
      }
      socket.emit("error_message", { message: result.message || "Unable to send message." });
      return;
    }
    if (result.existing) {
      socket.emit("private_message", result.message);
      emitMessageStatus(result.message);
    }
  });

  socket.on("register_public_key", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : (d) => socket.emit("public_key_registered", d);
    const userKey = socket.data.userKey;
    if (!userKey) {
      respond({ ok: false, message: "Unauthorized" });
      return;
    }
    const publicKey = toDisplayName(payload?.publicKey || payload);
    if (!publicKey) {
      respond({ ok: false, message: "Public key is required" });
      return;
    }
    const user = users.get(userKey);
    if (user) {
      user.publicKey = publicKey;
      schedulePersist();
      // Notify friends of updated public key
      for (const friendKey of user.friends || []) {
        const friendSocket = onlineUsers.get(friendKey);
        if (friendSocket) {
          io.to(friendSocket).emit("peer_public_key_updated", {
            username: user.username,
            publicKey,
          });
        }
      }
      respond({ ok: true, publicKey });
    }
  });

  socket.on("get_public_key", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : (d) => socket.emit("public_key_response", d);
    const targetName = toDisplayName(payload?.username || payload?.target || payload);
    const targetKey = normalizeName(targetName);
    const target = users.get(targetKey);
    const publicKey = target?.publicKey || "";
    respond({ username: target?.username || targetName, publicKey });
  });

  socket.on("schedule_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "schedule_message", 60, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Scheduling rate limit reached. Try again later." });
      return;
    }

    const to = toDisplayName(payload?.to);
    const requestedType = normalizeChatKind(payload?.toType || "friend");
    const text = withUploadToken(payload?.text);
    const attachment = sanitizeMessageAttachment(payload?.attachment, text);
    const replyTo = normalizeReplyPayload(payload?.replyTo);
    const sendAtValidation = normalizeScheduledSendAt(payload?.sendAt);
    if (!sendAtValidation.ok) {
      socket.emit("error_message", { message: sendAtValidation.message });
      return;
    }
    if (!text) {
      socket.emit("error_message", { message: "Cannot schedule an empty message." });
      return;
    }
    if (text.length > MAX_MESSAGE_LENGTH) {
      socket.emit("error_message", { message: `Message too long. Limit is ${MAX_MESSAGE_LENGTH} characters.` });
      return;
    }

    const resolved = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "Unable to schedule for this chat." });
      return;
    }
    if (resolved.type === "friend" && usersAreBlocked(userKey, resolved.targetKey)) {
      socket.emit("error_message", { message: "Messaging is blocked with this user." });
      return;
    }

    const entryId = createMessageId();
    const entry = {
      id: entryId,
      fromKey: userKey,
      toType: resolved.type,
      toKey: resolved.targetKey,
      text,
      attachment: attachment || null,
      replyTo: replyTo || null,
      sendAt: sendAtValidation.sendAt,
      createdAt: nowIso(),
      clientTempId: toDisplayName(payload?.clientTempId || ""),
    };
    scheduledMessages.set(entryId, entry);
    queueScheduledMessageDelivery(entryId);

    socket.emit("scheduled_message_created", {
      message: toScheduledMessageSummary(entry),
    });
    emitScheduledMessagesUpdated(userKey, { toType: entry.toType, to: entry.toKey });
    schedulePersist();
  });

  socket.on("list_scheduled_messages", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const toType = normalizeChatKind(payload?.toType || "friend");
    const to = toDisplayName(payload?.to || "");
    emitScheduledMessagesUpdated(userKey, {
      toType: to ? toType : "",
      to,
    });
  });

  socket.on("cancel_scheduled_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const id = toDisplayName(payload?.id || payload?.messageId || payload);
    if (!id) return;
    const entry = scheduledMessages.get(id);
    if (!entry || normalizeName(entry.fromKey) !== normalizeName(userKey)) {
      socket.emit("error_message", { message: "Scheduled message not found." });
      return;
    }
    scheduledMessages.delete(id);
    clearScheduledMessageTimer(id);
    socket.emit("scheduled_message_cancelled", { id });
    emitScheduledMessagesUpdated(userKey, { toType: entry.toType, to: entry.toKey });
    schedulePersist();
  });

  socket.on("typing", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "typing", 120, 60 * 1000)) return;

    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const isTyping = Boolean(payload?.isTyping);

    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      const me = users.get(userKey);
      if (!me || !group || !isGroupMember(group, userKey)) {
        return;
      }
      for (const memberKey of group.members) {
        if (memberKey === userKey) continue;
        const memberSocket = onlineUsers.get(memberKey);
        if (!memberSocket) continue;
        io.to(memberSocket).emit("typing", {
          from: me.username,
          isTyping,
          toType: "group",
          to: group.id,
        });
      }
      return;
    }

    const toKey = normalizeName(to);
    const me = users.get(userKey);
    if (!me || !me.friends.has(toKey)) {
      return;
    }
    if (usersAreBlocked(userKey, toKey)) {
      return;
    }

    const friendSocket = onlineUsers.get(toKey);
    if (friendSocket) {
      io.to(friendSocket).emit("typing", {
        from: me.username,
        isTyping,
        toType: "friend",
      });
    }
  });

  socket.on("voice_activity", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "voice_activity", 200, 60 * 1000)) return;

    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const isSpeaking = Boolean(payload?.isSpeaking);
    const me = users.get(userKey);
    if (!me) return;

    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) {
        return;
      }
      for (const memberKey of group.members) {
        if (memberKey === userKey) continue;
        const memberSocket = onlineUsers.get(memberKey);
        if (!memberSocket) continue;
        io.to(memberSocket).emit("voice_activity", {
          from: me.username,
          isSpeaking,
          toType: "group",
          to: group.id,
        });
      }
      return;
    }

    const toKey = normalizeName(to);
    if (!toKey || !me.friends.has(toKey)) {
      return;
    }
    if (usersAreBlocked(userKey, toKey)) {
      return;
    }

    const friendSocket = onlineUsers.get(toKey);
    if (friendSocket) {
      io.to(friendSocket).emit("voice_activity", {
        from: me.username,
        isSpeaking,
        toType: "friend",
        to: me.username,
      });
    }
  });

  socket.on("react", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "react", 120, 60 * 1000)) return;
    const messageId = toDisplayName(payload?.messageId);
    const emoji = toDisplayName(payload?.emoji);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const to = toDisplayName(payload?.to);
    if (!messageId || !emoji || !to) return;
    const me = users.get(userKey);
    if (!me) return;
    let convKey = "";
    let recipients = [];
    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) return;
      convKey = getGroupConversationKey(group.id);
      recipients = Array.from(group.members);
    } else {
      const toKey = normalizeName(to);
      if (!me.friends.has(toKey)) return;
      convKey = getConversationKey(userKey, toKey);
      recipients = [userKey, toKey];
    }
    const conv = conversations.get(convKey) || [];
    const message = conv.find((m) => m.id === messageId);
    if (!message) return;
    if (message.deletedAt) return;
    if (!message.reactions) message.reactions = {};
    if (!message.reactions[emoji]) message.reactions[emoji] = { count: 0, userKeys: [] };
    const entry = message.reactions[emoji];
    const alreadyIdx = entry.userKeys.indexOf(userKey);
    if (alreadyIdx >= 0) {
      entry.userKeys.splice(alreadyIdx, 1);
      entry.count = Math.max(0, entry.count - 1);
    } else {
      entry.userKeys.push(userKey);
      entry.count++;
    }
    function buildReactionPayload(forUserKey) {
      const out = {};
      for (const [em, data] of Object.entries(message.reactions)) {
        if (!data || data.count <= 0) continue;
        const userKeys = Array.isArray(data.userKeys) ? data.userKeys : [];
        const usersList = userKeys
          .map((key) => users.get(key)?.username || key)
          .map((name) => toDisplayName(name))
          .filter(Boolean);
        out[em] = {
          count: data.count,
          mine: userKeys.includes(forUserKey),
          userKeys,
          users: usersList,
        };
      }
      return out;
    }
    const uniqueRecipients = Array.from(new Set(recipients.map(normalizeName).filter(Boolean)));
    for (const targetKey of uniqueRecipients) {
      const targetSocket = onlineUsers.get(targetKey);
      if (!targetSocket) continue;
      io.to(targetSocket).emit("reaction_updated", {
        messageId,
        reactions: buildReactionPayload(targetKey),
      });
    }
    schedulePersist();
  });

  socket.on("get_group_info", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "get_group_info", 180, 60 * 1000)) return;
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload);
    const group = groups.get(groupId);
    if (!group || !isGroupMember(group, userKey)) {
      socket.emit("error_message", { message: "Group not found." });
      return;
    }
    const groupInfo = buildGroupInfoForViewer(group, userKey);
    if (!groupInfo) return;
    socket.emit("group_info", { group: groupInfo });
  });

  socket.on("create_group", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "create_group", 20, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Group creation rate limit reached. Try again later." });
      return;
    }
    const me = users.get(userKey);
    if (!me) return;

    const requestedName = toDisplayName(payload?.name || payload?.title || "").slice(0, MAX_GROUP_NAME_LENGTH);
    const name = requestedName || `${me.username}'s group`;
    const requestedMembers = Array.isArray(payload?.members) ? payload.members : [];
    const memberKeys = new Set([userKey]);
    for (const rawMember of requestedMembers) {
      const memberKey = normalizeName(rawMember);
      if (!memberKey || memberKey === userKey) continue;
      if (!me.friends.has(memberKey)) continue;
      if (!users.get(memberKey)?.isRegistered) continue;
      memberKeys.add(memberKey);
      if (memberKeys.size >= MAX_GROUP_MEMBERS) break;
    }

    if (memberKeys.size < 2) {
      socket.emit("error_message", { message: "Add at least one friend to create a group." });
      return;
    }

    let groupId = createGroupId(name);
    while (groups.has(groupId)) {
      groupId = createGroupId(name);
    }

    const group = createGroupRecord(name, userKey, Array.from(memberKeys));
    group.id = groupId;
    groups.set(group.id, group);

    for (const memberKey of group.members) {
      const member = users.get(memberKey);
      if (!member) continue;
      if (!(member.groups instanceof Set)) member.groups = new Set();
      member.groups.add(group.id);
      setUnreadCount(member, group.id, 0);
      emitFriendList(memberKey);
      emitGroupInfoToMember(memberKey, group);
      const memberSocket = onlineUsers.get(memberKey);
      if (memberSocket) {
        io.to(memberSocket).emit("group_created", {
          group: {
            id: group.id,
            name: group.name,
            owner: users.get(group.ownerKey)?.username || group.ownerKey,
            members: getGroupMemberUsernames(group),
            createdAt: group.createdAt,
          },
        });
      }
    }

    schedulePersist();
  });

  socket.on("add_group_members", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "add_group_members", 40, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Too many group updates. Try again later." });
      return;
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      socket.emit("error_message", { message: "Group not found." });
      return;
    }
    if (!(group.admins instanceof Set) || !group.admins.has(userKey)) {
      socket.emit("error_message", { message: "Only group admins can add members." });
      return;
    }

    const requestedMembers = Array.isArray(payload?.members) ? payload.members : [];
    const added = [];
    for (const rawMember of requestedMembers) {
      const memberKey = normalizeName(rawMember);
      if (!memberKey || group.members.has(memberKey)) continue;
      if (!me.friends.has(memberKey)) continue;
      const member = users.get(memberKey);
      if (!member?.isRegistered) continue;
      if (group.members.size >= MAX_GROUP_MEMBERS) break;
      group.members.add(memberKey);
      if (!(member.groups instanceof Set)) member.groups = new Set();
      member.groups.add(group.id);
      setUnreadCount(member, group.id, 0);
      added.push(member.username || memberKey);
    }

    if (!added.length) {
      socket.emit("error_message", { message: "No members were added." });
      return;
    }

    group.updatedAt = nowIso();
    const allMembers = Array.from(group.members);
    for (const memberKey of allMembers) {
      emitFriendList(memberKey);
      emitGroupInfoToMember(memberKey, group);
      const memberSocket = onlineUsers.get(memberKey);
      if (memberSocket) {
        io.to(memberSocket).emit("group_members_added", {
          groupId: group.id,
          groupName: group.name,
          added,
          by: me.username,
          members: getGroupMemberUsernames(group),
        });
      }
    }
    schedulePersist();
  });

  socket.on("remove_group_member", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "remove_group_member", 40, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Too many group updates. Try again later." });
      return;
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      socket.emit("error_message", { message: "Group not found." });
      return;
    }
    if (!(group.admins instanceof Set) || !group.admins.has(userKey)) {
      socket.emit("error_message", { message: "Only group admins can remove members." });
      return;
    }

    const targetName = toDisplayName(payload?.username || payload?.member || payload?.target).replace(/^@+/, "");
    const targetKey = normalizeName(targetName);
    const targetUser = users.get(targetKey);
    if (!targetKey || !targetUser || !group.members.has(targetKey)) {
      socket.emit("error_message", { message: "Member not found in this group." });
      return;
    }
    if (targetKey === userKey) {
      socket.emit("error_message", { message: "Use Leave to exit this group." });
      return;
    }
    if (normalizeName(group.ownerKey) === targetKey) {
      socket.emit("error_message", { message: "Group owner cannot be removed." });
      return;
    }
    const targetIsAdmin = group.admins instanceof Set && group.admins.has(targetKey);
    if (targetIsAdmin && normalizeName(group.ownerKey) !== userKey) {
      socket.emit("error_message", { message: "Only owner can remove another admin." });
      return;
    }

    group.members.delete(targetKey);
    if (group.admins instanceof Set) group.admins.delete(targetKey);
    targetUser.groups?.delete(group.id);
    targetUser.unread?.delete(group.id);
    group.updatedAt = nowIso();

    const remainingMembers = Array.from(group.members);
    const removedUsername = targetUser.username || targetKey;
    const actorName = me.username || userKey;

    emitFriendList(targetKey);
    for (const memberKey of remainingMembers) {
      emitFriendList(memberKey);
      emitGroupInfoToMember(memberKey, group);
      const memberSocket = onlineUsers.get(memberKey);
      if (memberSocket) {
        io.to(memberSocket).emit("group_member_removed", {
          groupId: group.id,
          groupName: group.name || group.id,
          username: removedUsername,
          by: actorName,
        });
      }
    }

    const targetSocketId = onlineUsers.get(targetKey);
    if (targetSocketId) {
      const targetSocket = io.sockets.sockets.get(targetSocketId);
      if (
        targetSocket &&
        targetSocket.data?.activeChatKind === "group" &&
        normalizeGroupId(targetSocket.data?.activeChatWith) === group.id
      ) {
        targetSocket.data.activeChatWith = null;
        targetSocket.data.activeChatKind = "friend";
        io.to(targetSocketId).emit("group_left", {
          groupId: group.id,
          groupName: group.name || group.id,
          reason: "removed",
        });
      }
      io.to(targetSocketId).emit("group_member_removed", {
        groupId: group.id,
        groupName: group.name || group.id,
        username: removedUsername,
        by: actorName,
      });
    }

    schedulePersist();
  });

  socket.on("set_group_member_role", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "set_group_member_role", 50, 60 * 60 * 1000)) {
      socket.emit("error_message", { message: "Too many role updates. Try again later." });
      return;
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      socket.emit("error_message", { message: "Group not found." });
      return;
    }
    if (normalizeName(group.ownerKey) !== userKey) {
      socket.emit("error_message", { message: "Only group owner can change roles." });
      return;
    }

    const targetName = toDisplayName(payload?.username || payload?.member || payload?.target).replace(/^@+/, "");
    const targetKey = normalizeName(targetName);
    if (!targetKey || !group.members.has(targetKey)) {
      socket.emit("error_message", { message: "Member not found in this group." });
      return;
    }
    if (targetKey === normalizeName(group.ownerKey)) {
      socket.emit("error_message", { message: "Owner role cannot be changed." });
      return;
    }

    const requestedRole = normalizeName(payload?.role || "");
    const makeAdmin = requestedRole === "admin";
    if (!(group.admins instanceof Set)) group.admins = new Set();
    const alreadyAdmin = group.admins.has(targetKey);
    if (makeAdmin === alreadyAdmin) {
      socket.emit("error_message", {
        message: makeAdmin ? "Member is already an admin." : "Member is already not an admin.",
      });
      return;
    }

    if (makeAdmin) group.admins.add(targetKey);
    else group.admins.delete(targetKey);
    group.updatedAt = nowIso();

    const role = makeAdmin ? "admin" : "member";
    const targetUser = users.get(targetKey);
    const changedUsername = targetUser?.username || targetKey;
    const actorName = me.username || userKey;

    for (const memberKey of group.members) {
      emitFriendList(memberKey);
      emitGroupInfoToMember(memberKey, group);
      const memberSocket = onlineUsers.get(memberKey);
      if (!memberSocket) continue;
      io.to(memberSocket).emit("group_member_role_updated", {
        groupId: group.id,
        groupName: group.name || group.id,
        username: changedUsername,
        role,
        by: actorName,
      });
    }

    schedulePersist();
  });

  socket.on("leave_group", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      socket.emit("error_message", { message: "Group not found." });
      return;
    }

    group.members.delete(userKey);
    if (group.admins instanceof Set) {
      group.admins.delete(userKey);
    }
    me.groups?.delete(group.id);
    me.unread?.delete(group.id);

    const memberName = me.username || userKey;
    const remainingMembers = Array.from(group.members);
    if (!remainingMembers.length) {
      groups.delete(group.id);
      conversations.delete(getGroupConversationKey(group.id));
      for (const [id, entry] of scheduledMessages.entries()) {
        if (entry.toType === "group" && normalizeGroupId(entry.toKey) === group.id) {
          scheduledMessages.delete(id);
          const timer = scheduledMessageTimers.get(id);
          if (timer) clearTimeout(timer);
          scheduledMessageTimers.delete(id);
        }
      }
    } else {
      if (group.ownerKey === userKey) {
        group.ownerKey = remainingMembers[0];
      }
      if (!(group.admins instanceof Set)) {
        group.admins = new Set();
      }
      if (!group.admins.size && group.ownerKey) {
        group.admins.add(group.ownerKey);
      }
      group.updatedAt = nowIso();
    }

    if (
      socket.data?.activeChatKind === "group" &&
      normalizeGroupId(socket.data?.activeChatWith) === groupId
    ) {
      socket.data.activeChatWith = null;
      socket.data.activeChatKind = "friend";
      socket.emit("group_left", { groupId, groupName: group.name || groupId, reason: "left" });
    }

    emitFriendList(userKey);
    for (const memberKey of remainingMembers) {
      emitFriendList(memberKey);
      emitGroupInfoToMember(memberKey, group);
      const memberSocket = onlineUsers.get(memberKey);
      if (memberSocket) {
        io.to(memberSocket).emit("group_member_left", {
          groupId,
          groupName: group.name || groupId,
          username: memberName,
        });
      }
    }
    schedulePersist();
  });

  registerMessageMutationHandlers(socket, {
    allowSocketAction,
    toDisplayName,
    normalizeChatKind,
    MAX_MESSAGE_LENGTH,
    users,
    groups,
    isGroupMember,
    getGroupConversationKey,
    getConversationKey,
    conversations,
    CALL_LOG_PREFIX,
    DELETED_MESSAGE_TEXT,
    nowIso,
    normalizeName,
    onlineUsers,
    io,
    emitFriendList,
    schedulePersist
  });

  socket.on("disconnect", () => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    const existingSocketId = onlineUsers.get(userKey);
    if (existingSocketId === socket.id) {
      const user = users.get(userKey);
      if (user) {
        for (const friendKey of user.friends) {
          const friendSocket = onlineUsers.get(friendKey);
          if (friendSocket) {
            io.to(friendSocket).emit("typing", {
              from: user.username,
              isTyping: false,
              toType: "friend",
            });
          }
        }
        for (const groupKey of user.groups || []) {
          const group = groups.get(normalizeGroupId(groupKey));
          if (!group) continue;
          for (const memberKey of group.members) {
            if (memberKey === userKey) continue;
            const memberSocket = onlineUsers.get(memberKey);
            if (!memberSocket) continue;
            io.to(memberSocket).emit("typing", {
              from: user.username,
              isTyping: false,
              toType: "group",
              to: group.id,
            });
          }
        }

        user.lastSeenAt = nowIso();
      }

      const activeCall = activeCalls.get(userKey);
      const callPeerKey = clearCallPair(userKey);
      if (callPeerKey) {
        const peerSocketId = onlineUsers.get(callPeerKey);
        if (peerSocketId) {
          io.to(peerSocketId).emit("call_ended", {
            from: user?.username || userKey,
            callId: activeCall?.callId,
            reason: "Connection lost",
          });
        }
      }

      onlineUsers.delete(userKey);
      emitStatusToFriends(userKey);
      emitGroupListUpdatesForUser(userKey);
      emitDiscoverOnlineToAll();
      schedulePersist();
    }
  });
});

async function closeStorage() {
  if (!mongoStorage) return;
  try {
    await mongoStorage.close();
  } catch (err) {
    console.error("Failed closing MongoDB connection:", err);
  } finally {
    mongoStorage = null;
    mongoClient = null;
    mongoLegacyCollection = null;
    mongoUsersCollection = null;
    mongoConversationsCollection = null;
    mongoMessagesCollection = null;
  }
}

async function shutdown() {
  if (persistTimer) {
    clearTimeout(persistTimer);
    persistTimer = null;
  }
  if (authPersistTimer) {
    clearTimeout(authPersistTimer);
    authPersistTimer = null;
  }
  for (const timer of scheduledMessageTimers.values()) {
    clearTimeout(timer);
  }
  scheduledMessageTimers.clear();

  try {
    await persistInFlight.catch(() => {});
    await authPersistInFlight.catch(() => {});
    await persistNow();
    await persistAuthStateNow();
  } catch (err) {
    console.error("Failed to persist state during shutdown:", err);
  } finally {
    await closeStorage();
    process.exit(0);
  }
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

function parsePort(value, fallback = 3000) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > 65535) {
    return fallback;
  }
  return parsed;
}

function listenWithPortFallback(preferredPort, options = {}) {
  const maxRetries = Number.isFinite(Number(options.maxRetries))
    ? Math.max(0, Math.floor(Number(options.maxRetries)))
    : 0;
  const startPort = parsePort(preferredPort, 3000);

  return new Promise((resolve, reject) => {
    const tryListen = (port, retriesLeft) => {
      const onError = (err) => {
        if (err?.code === "EADDRINUSE" && retriesLeft > 0) {
          const nextPort = port + 1;
          console.warn(`Port ${port} is already in use. Retrying on ${nextPort}...`);
          tryListen(nextPort, retriesLeft - 1);
          return;
        }
        reject(err);
      };

      server.once("error", onError);
      server.listen(port, () => {
        server.off("error", onError);
        resolve(port);
      });
    };

    tryListen(startPort, maxRetries);
  });
}

async function bootstrap() {
  await loadState();
  queueAllScheduledMessages();
  startRetentionMaintenanceLoop();

  const hasExplicitPort = typeof process.env.PORT === "string" && process.env.PORT.trim() !== "";
  const preferredPort = parsePort(process.env.PORT, 3000);
  const activePort = await listenWithPortFallback(preferredPort, {
    maxRetries: hasExplicitPort ? 0 : 20,
  });

  const usingMongo = hasMongoStorage();
  const mediaStorage = hasCloudinaryConfig ? "cloudinary" : `local(${uploadsDir})`;
  console.log(
    `Chat app running on http://localhost:${activePort} | retention=${CHAT_RETENTION_DAYS} day(s) | storage=${usingMongo ? "mongodb(collections)" : "file"} | media=${mediaStorage}`
  );
}

bootstrap().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
