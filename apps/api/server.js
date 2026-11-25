const fs = require("fs");
const fsp = require("fs/promises");
const crypto = require("crypto");
const path = require("path");
const http = require("http");
const express = require("express");
const multer = require("multer");
const { createMongoStorage } = require("./server/db/mongo");
const { registerHealthRoutes } = require("./server/routes/health");
const { createSocketAuthMiddleware } = require("./server/realtime/socket-auth");
const { isAllowedSocketOrigin } = require("./server/security/origins");
const { mediaNames, canReadMedia } = require("./server/security/media-access");
const { registerMessageMutationHandlers } = require("./server/realtime/message-mutations");
const { registerCallHandlers, cancelCallForUser } = require("./server/realtime/call-handlers");
const { applyGameMove, createGameChallenge } = require("./server/realtime/game-rules");
const { PublicGameMatchmaking } = require("./server/realtime/game-matchmaking");
const { buildGameLeaderboard, normalizeLeaderboardGame } = require("./game-leaderboard");
const { RajaMantriMatchmaking } = require("./server/realtime/raja-mantri-matchmaking");
const {
  createRajaMantriGameSession,
  pickRajaMantriChit,
  autoPickRajaMantriChit,
  setRajaMantriPlayerConnected,
  guessRajaMantriChor,
  advanceRajaMantriRound,
  getRajaMantriGameView,
} = require("./server/realtime/raja-mantri-game");
const { Server } = require("socket.io");
const webpush = require("web-push");
const { cloudinary, hasCloudinaryConfig } = require("./cloudinary");
const { createChatAuthorization } = require("./server/chat/authorization");
const { createIpRateLimiter, pruneHttpRateLimits } = require("./server/auth/rate-limit");
const { createAuthToken: signAuthToken, verifyAuthToken: verifySignedAuthToken } = require("./server/auth/tokens");
const { createAuthSessions } = require("./server/auth/sessions");
const { parseCookies, safeTimingEqual: csrfSafeTimingEqual, createCsrf } = require("./server/auth/csrf");
const runtimeState = require("./server/core/state");
const { buildUserSearchResults } = require("./server/users/search");
const { isQuietHoursActive, shouldDeliverNotification } = require("./server/notification-policy");
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
require("dotenv").config({ path: process.env.NOVYN_ENV_FILE || path.resolve(__dirname, '../../.env') });
const { admin, firebaseAdmin, firebaseLegacyAdmin, verifyFirebaseIdToken } = require("./server/config/firebase-admin");
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
  req.novynCsrfToken = ensureCsrfCookie(req, res);
  next();
});

registerHealthRoutes({
  app,
  getMongoUri: () => MONGODB_URI,
  getMongoStorage: () => mongoStorage,
  hasMongoStorage,
});

const defaultUploadsDir = path.join(__dirname, "runtime", "uploads");
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
const GIPHY_API_KEY = toDisplayName(process.env.GIPHY_API_KEY);

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
  console.warn("Push notifications disabled: configure both VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY with stable keys.");
}

const pushEnabled = Boolean(vapidKeys?.publicKey && vapidKeys?.privateKey);
if (pushEnabled) {
  webpush.setVapidDetails(VAPID_SUBJECT, vapidKeys.publicKey, vapidKeys.privateKey);
}

function signUploadToken(filename) {
  return crypto.createHmac("sha256", uploadTokenSecret).update(filename).digest("hex");
}

function requireUser(req, res, next) {
  const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), { allowRefreshFallback: true });
  if (!auth.userKey || !users.get(auth.userKey)?.isRegistered || users.get(auth.userKey)?.isSuspended) {
    return res.status(401).json({ error: 'Sign in required.' });
  }
  req.userKey = auth.userKey;
  next();
}

const ADMIN_EMAILS = new Set(
  String(process.env.ADMIN_EMAILS || "")
    .split(",")
    .map(normalizeEmail)
    .filter(Boolean)
);
const ADMIN_ALLOWED_ORIGINS = new Set(
  String(process.env.ADMIN_ALLOWED_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim().replace(/\/+$/, ""))
    .filter(Boolean)
);

function setAdminCors(req, res) {
  const origin = String(req.get("origin") || "").replace(/\/+$/, "");
  if (!origin || !ADMIN_ALLOWED_ORIGINS.has(origin)) return false;
  res.set("Access-Control-Allow-Origin", origin);
  res.set("Access-Control-Allow-Methods", "GET, PATCH, DELETE, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Max-Age", "600");
  res.vary("Origin");
  return true;
}

async function requireAdmin(req, res, next) {
  if (!setAdminCors(req, res)) {
    res.status(403).json({ error: "Admin dashboard origin is not allowed." });
    return;
  }
  res.set("Cache-Control", "no-store, max-age=0");
  const tokenMatch = String(req.get("authorization") || "").match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) {
    res.status(401).json({ error: "Firebase sign-in required." });
    return;
  }
  if (!ADMIN_EMAILS.size) {
    res.status(503).json({ error: "Admin access is not configured on the API." });
    return;
  }
  if (!firebaseAdmin) {
    res.status(503).json({ error: "Firebase Admin authentication is unavailable." });
    return;
  }

  try {
    const decoded = await admin.auth(firebaseAdmin).verifyIdToken(tokenMatch[1], true);
    const email = normalizeEmail(decoded.email || "");
    if (
      !email ||
      decoded.email_verified !== true ||
      decoded.firebase?.sign_in_provider !== "google.com" ||
      !ADMIN_EMAILS.has(email)
    ) {
      res.status(403).json({ error: "This verified Google account is not an administrator." });
      return;
    }
    req.adminEmail = email;
    next();
  } catch {
    res.status(401).json({ error: "Firebase sign-in has expired or is invalid." });
  }
}

function mediaMetadata(filename) {
  if (!/^[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+$/.test(filename)) return null;
  const cached = mediaMetadataCache.get(filename);
  if (cached) return cached;
  try {
    const metadata = JSON.parse(fs.readFileSync(path.join(uploadsDir, `${filename}.metadata.json`), 'utf8'));
    mediaMetadataCache.set(filename, metadata);
    return metadata;
  } catch { return null; }
}

async function saveMediaMetadata(filename, ownerKey, remote = null) {
  const metadata = { ownerKey, remote };
  if (mongoMediaCollection) {
    await mongoMediaCollection.updateOne(
      { _id: filename },
      { $set: { ownerKey, remote, updatedAt: new Date() } },
      { upsert: true }
    );
    mediaMetadataCache.set(filename, metadata);
    return;
  }
  fs.writeFileSync(path.join(uploadsDir, `${filename}.metadata.json`), JSON.stringify(metadata), { flag: 'wx' });
  mediaMetadataCache.set(filename, metadata);
}

function userCanReadMedia(filename, userKey) {
  const metadata = mediaMetadata(filename);
  const ownerKey = resolveCurrentUserKey(metadata?.ownerKey);
  if (ownerKey && ownerKey !== userKey) {
    const owner = users.get(ownerKey);
    if (
      owner &&
      mediaNames(owner.avatarId).includes(filename) &&
      privacyAllows(owner, userKey, "profilePhotoPrivacy") &&
      !usersAreBlocked(ownerKey, userKey)
    ) {
      return true;
    }
  }
  return canReadMedia({
    filename, userKey, ownerKey,
    conversations, wallpapers: conversationWallpapers,
    canReadConversation: (key, viewer) => isGroupConversationKey(key)
      ? Boolean(groups.get(key.slice(GROUP_CONVERSATION_PREFIX.length))?.members.has(viewer))
      : key.split('::').includes(viewer),
  });
}

async function storeCloudMedia(file, ownerKey, folder) {
  const result = await cloudinary.uploader.upload(file.path, {
    resource_type: 'auto', type: 'authenticated', folder,
  });
  const filename = `cloud-${crypto.randomBytes(16).toString('hex')}.bin`;
  await saveMediaMetadata(filename, ownerKey, {
    publicId: result.public_id, format: result.format || '', resourceType: result.resource_type,
  });
  return `/uploads/${filename}?token=${signUploadToken(filename)}`;
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
  if (lower.startsWith("image/")) return "image";
  if (lower.startsWith("video/")) return "video";
  if (lower.startsWith("audio/")) return "audio";
  return "file";
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
    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
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
  const declaredKind = String(attachment.kind || "").toLowerCase();
  const kind = declaredKind === "image" || mime.startsWith("image/")
    || /\.(?:png|jpe?g|gif|webp|bmp|svg)(?:[?#].*)?$/i.test(String(url || ""))
    ? "image"
    : declaredKind === "audio" || mime.startsWith("audio/")
      ? "audio"
      : declaredKind === "video" || mime.startsWith("video/")
        ? "video"
        : "file";
  const numericSize = Number(attachment.size);
  const size = Number.isFinite(numericSize) ? Math.max(0, Math.floor(numericSize)) : 0;
  const numericDuration = Number(attachment.duration);
  const duration = Number.isFinite(numericDuration)
    ? Math.max(0, Math.min(86400, Math.floor(numericDuration)))
    : null;

  const encrypted = attachment.encrypted === true;
  const encryptionIv = toDisplayName(attachment.iv).slice(0, 64);
  const senderPublicKey = encrypted ? normalizePushPublicKey(attachment.senderPublicKey) : "";
  const peerPublicKey = encrypted ? normalizePushPublicKey(attachment.peerPublicKey) : "";
  // Only persist the E2EE envelope fields needed by the two endpoints.
  // Never trust or store arbitrary client-provided attachment metadata.
  if (encrypted && (!encryptionIv || !senderPublicKey || !peerPublicKey || Number(attachment.encryptionVersion) !== 1)) {
    return null;
  }

  return {
    url,
    name,
    mime,
    size,
    kind,
    ...(duration !== null ? { duration } : {}),
    ...(encrypted ? {
      encrypted: true,
      encryptionVersion: 1,
      iv: encryptionIv,
      senderPublicKey,
      peerPublicKey,
    } : {}),
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
  const filePath = path.join(__dirname, "../web/public", "downloads", filename);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: "APK not found. Check back soon." });
    return;
  }
  res.setHeader("Content-Type", "application/vnd.android.package-archive");
  res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.sendFile(filePath);
});

app.options("/api/admin/dashboard", (req, res) => {
  if (!setAdminCors(req, res)) {
    return res.status(403).end();
  }
  return res.status(204).end();
});

app.get(
  "/api/admin/dashboard",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "admin-dashboard", 60, 60 * 1000),
  requireAdmin,
  async (req, res) => {
    const registeredUsers = Array.from(users.values()).filter((user) => user?.isRegistered);
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const feedbackCollection = mongoStorage?.getCollection("feedback");

    try {
      let feedback;
      let feedbackCount;
      if (feedbackCollection) {
        [feedback, feedbackCount] = await Promise.all([
          feedbackCollection.find({}, {
            projection: {
              id: 1,
              type: 1,
              message: 1,
              rating: 1,
              email: 1,
              fromUser: 1,
              createdAt: 1,
            },
          }).sort({ createdAt: -1 }).limit(100).toArray(),
          feedbackCollection.countDocuments(),
        ]);
      } else {
        let rawFeedback = "";
        try {
          rawFeedback = await fsp.readFile(path.join(DATA_DIR, "feedback.log"), "utf8");
        } catch (error) {
          if (error?.code !== "ENOENT") throw error;
        }
        const entries = rawFeedback
          .split(/\r?\n/)
          .filter(Boolean)
          .map((line) => JSON.parse(line));
        feedbackCount = entries.length;
        feedback = entries.slice(-100).reverse();
      }

      res.json({
        generatedAt: nowIso(),
        admin: { email: req.adminEmail },
        metrics: {
          registeredUsers: registeredUsers.length,
          onlineUsers: registeredUsers.reduce(
            (count, user) => count + (onlineUsers.has(normalizeName(user.username)) ? 1 : 0),
            0
          ),
          newUsersLast7Days: registeredUsers.filter((user) => {
            const createdAt = Date.parse(user.createdAt || "");
            return Number.isFinite(createdAt) && createdAt >= weekAgo;
          }).length,
          conversations: conversations.size,
          messages: Array.from(conversations.values()).reduce(
            (count, messages) => count + (Array.isArray(messages) ? messages.length : 0),
            0
          ),
          groups: groups.size,
          feedback: feedbackCount,
        },
        users: registeredUsers
          .map((user) => ({
            username: toDisplayName(user.username),
            displayName: toDisplayName(user.displayName || user.username),
            email: normalizeEmail(user.email || ""),
            createdAt: toDisplayName(user.createdAt),
            lastSeenAt: toDisplayName(user.lastSeenAt),
            isGoogleUser: Boolean(user.googleUid),
            isOnline: onlineUsers.has(normalizeName(user.username)),
            isSuspended: user.isSuspended === true,
          }))
          .sort((a, b) => Date.parse(b.createdAt || "") - Date.parse(a.createdAt || ""))
          .slice(0, 100),
        feedback: feedback.map((entry) => ({
          id: toDisplayName(entry.id || entry._id),
          type: toDisplayName(entry.type || "general"),
          message: toDisplayName(entry.message),
          rating: entry.rating != null && Number.isFinite(Number(entry.rating))
            ? Number(entry.rating)
            : null,
          email: normalizeEmail(entry.email || ""),
          fromUser: toDisplayName(entry.fromUser || "anonymous"),
          createdAt: toDisplayName(entry.createdAt),
        })),
      });
    } catch (error) {
      console.warn("[NovynAdmin] Failed to load dashboard data:", error?.message || error);
      res.status(503).json({ error: "Admin dashboard data is temporarily unavailable." });
    }
  }
);

function handleAdminOptions(req, res) {
  if (!setAdminCors(req, res)) return res.status(403).end();
  return res.status(204).end();
}

app.options("/api/admin/users/:username", handleAdminOptions);
app.options("/api/admin/users/:username/suspension", handleAdminOptions);

app.patch(
  "/api/admin/users/:username",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "admin-user-edit", 30, 60 * 1000),
  requireAdmin,
  async (req, res) => {
    const userKey = normalizeName(req.params.username);
    const user = users.get(userKey);
    if (!user?.isRegistered) return res.status(404).json({ error: "User not found." });
    if (ADMIN_EMAILS.has(normalizeEmail(user.email || ""))) {
      return res.status(403).json({ error: "Admin accounts cannot be changed here." });
    }

    const requestedUsername = normalizeHandleInput(req.body?.username);
    if (!/^[a-z0-9_]{3,24}$/.test(requestedUsername)) {
      return res.status(400).json({ error: "Use 3–24 lowercase letters, numbers, or underscores." });
    }

    let result;
    try {
      result = applyUsernameChange(userKey, requestedUsername);
      if (!result.ok) return res.status(409).json({ error: result.message });
      await flushStatePersistNow();
      await flushAuthStatePersistNow();
      console.info(`[NovynAdmin] ${req.adminEmail} changed username ${userKey} -> ${result.newKey}`);
      res.json({ ok: true, username: result.newUsername });
    } catch (error) {
      if (result?.ok) {
        result.rollback();
        try {
          await flushStatePersistNow();
          await flushAuthStatePersistNow();
        } catch (rollbackError) {
          console.error("[NovynAdmin] Failed to persist username rollback:", rollbackError?.message || rollbackError);
        }
      }
      console.error("[NovynAdmin] Failed to update username:", error?.message || error);
      res.status(503).json({ error: "Username could not be saved. Please refresh and retry." });
    }
  }
);

app.patch(
  "/api/admin/users/:username/suspension",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "admin-user-suspension", 30, 60 * 1000),
  requireAdmin,
  async (req, res) => {
    const userKey = normalizeName(req.params.username);
    const user = users.get(userKey);
    if (!user?.isRegistered) return res.status(404).json({ error: "User not found." });
    if (ADMIN_EMAILS.has(normalizeEmail(user.email || ""))) {
      return res.status(403).json({ error: "Admin accounts cannot be suspended here." });
    }
    if (typeof req.body?.suspended !== "boolean") {
      return res.status(400).json({ error: "A boolean suspended value is required." });
    }

    try {
      await setUserSuspended(userKey, req.body.suspended);
      console.info(`[NovynAdmin] ${req.adminEmail} ${req.body.suspended ? "suspended" : "restored"} ${userKey}`);
      res.json({ ok: true, isSuspended: user.isSuspended === true });
    } catch (error) {
      console.error("[NovynAdmin] Failed to change account suspension:", error?.message || error);
      res.status(503).json({ error: "Account status could not be saved. Please refresh and retry." });
    }
  }
);

app.delete(
  "/api/admin/users/:username",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "admin-user-delete", 5, 60 * 60 * 1000),
  requireAdmin,
  async (req, res) => {
    const userKey = normalizeName(req.params.username);
    const user = users.get(userKey);
    if (!user?.isRegistered) return res.status(404).json({ error: "User not found." });
    if (ADMIN_EMAILS.has(normalizeEmail(user.email || ""))) {
      return res.status(403).json({ error: "Admin accounts cannot be deleted here." });
    }
    const confirmation = normalizeHandleInput(req.body?.confirmation);
    if (confirmation !== userKey) {
      return res.status(400).json({ error: `Type @${user.username} to confirm permanent deletion.` });
    }

    try {
      await removeUserAccount(userKey);
      console.info(`[NovynAdmin] ${req.adminEmail} permanently deleted ${userKey} and associated chat data`);
      res.json({ ok: true });
    } catch (error) {
      console.error("[NovynAdmin] Failed to delete account:", error?.message || error);
      res.status(503).json({ error: error?.publicMessage || "Account deletion could not be completed. Please retry." });
    }
  }
);

// ── Feedback Endpoint ─────────────────────────────────────────────────────

app.get("/api/giphy", requireUser, async (req, res) => {
  if (!GIPHY_API_KEY) {
    res.status(503).json({ error: "GIF search is not configured.", code: "GIPHY_NOT_CONFIGURED" });
    return;
  }

  const type = req.query.type === "stickers" ? "stickers" : "gifs";
  const query = toDisplayName(req.query.q).slice(0, 120);
  const limit = Math.max(1, Math.min(Number.parseInt(String(req.query.limit || "24"), 10) || 24, 36));
  const offset = Math.max(0, Math.min(Number.parseInt(String(req.query.offset || "0"), 10) || 0, 5000));
  const endpoint = query ? "search" : "trending";
  const url = new URL(`https://api.giphy.com/v1/${type}/${endpoint}`);
  url.searchParams.set("api_key", GIPHY_API_KEY);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("offset", String(offset));
  url.searchParams.set("rating", "g");
  if (query) url.searchParams.set("q", query);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, { signal: controller.signal, headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`GIPHY returned ${response.status}`);
    const payload = await response.json();
    const items = Array.isArray(payload?.data) ? payload.data.map((item) => ({
      id: toDisplayName(item?.id),
      title: toDisplayName(item?.title || item?.alt_text) || "GIF",
      previewUrl: toDisplayName(item?.images?.fixed_width_small?.url || item?.images?.fixed_width?.url),
      url: toDisplayName(item?.images?.fixed_width?.url || item?.images?.original?.url),
    })).filter((item) => item.id && item.previewUrl && item.url) : [];
    res.set("Cache-Control", "private, max-age=120");
    res.json({ items, nextOffset: Number(payload?.pagination?.offset || offset) + items.length });
  } catch (error) {
    console.error("GIPHY request failed:", error.message);
    res.status(502).json({ error: "GIF search is temporarily unavailable." });
  } finally {
    clearTimeout(timeout);
  }
});

app.get("/uploads/:file", requireUser, async (req, res) => {
  const filename = path.basename(req.params.file || "");
  const token = String(req.query.token || "");
  if (!/^[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+$/.test(filename) || !safeTimingEqual(token, signUploadToken(filename)) || !userCanReadMedia(filename, req.userKey)) {
    res.status(403).json({ error: "Unauthorized" });
    return;
  }
  const metadata = mediaMetadata(filename);
  if (metadata?.remote) {
    res.set('Cache-Control', 'private, no-store');
    res.set('Referrer-Policy', 'no-referrer');
    const signedUrl = cloudinary.utils.private_download_url(metadata.remote.publicId, metadata.remote.format, {
      resource_type: metadata.remote.resourceType, type: 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 60,
      attachment: String(req.query.download || '') === '1',
    });
    // Browser E2EE clients need same-origin bytes so the browser can decrypt
    // the ciphertext without relying on cross-origin CDN CORS configuration.
    if (String(req.query.inline || '') === '1') {
      try {
        const remoteResponse = await fetch(signedUrl, { headers: { Accept: '*/*' } });
        if (!remoteResponse.ok) throw new Error(`Cloud media returned ${remoteResponse.status}`);
        const bytes = Buffer.from(await remoteResponse.arrayBuffer());
        res.set('Content-Type', remoteResponse.headers.get('content-type') || 'application/octet-stream');
        res.set('Content-Length', String(bytes.length));
        res.set('X-Content-Type-Options', 'nosniff');
        return res.status(200).send(bytes);
      } catch (error) {
        console.error('[NovynMedia] Inline cloud download failed:', error?.message || error);
        return res.status(502).json({ error: 'Media download is temporarily unavailable.' });
      }
    }
    return res.redirect(302, signedUrl);
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
  requireUser,
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
        const url = await storeCloudMedia(req.file, auth.userKey, 'novyn_voice');

        fs.unlink(req.file.path, () => {});
        res.json({ url });
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
      await saveMediaMetadata(filename, auth.userKey);
      const token = signUploadToken(filename);
      res.json({ url: `/uploads/${filename}?token=${token}` });
    } catch (error) {
      fs.unlink(req.file.path, () => {});
      console.error(error);
      res.status(500).json({ error: "Upload failed" });
    }
  }
);

app.post(
  "/upload-file",
  requireCsrf,
  requireUser,
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
        const url = await storeCloudMedia(req.file, auth.userKey, kind === 'image' ? 'novyn_images' : 'novyn_files');
        fs.unlink(req.file.path, () => {});
        res.json({
          url,
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
      await saveMediaMetadata(filename, auth.userKey);
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
  if (isAllowedSocketOrigin(origin, {
    isProduction: process.env.NODE_ENV === "production",
    allowedOrigins: allowedSocketOrigins,
  })) {
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

// Game history is account-scoped in MongoDB. Bot matches are deliberately never stored.
app.get("/api/games/history", requireUser, async (req, res) => {
  if (!mongoGameHistoryCollection) {
    return res.status(503).json({ error: "Cloud game history is temporarily unavailable." });
  }
  try {
    const matches = await mongoGameHistoryCollection
      .find({ userKey: req.userKey }, { projection: { _id: 0, userKey: 0 } })
      .sort({ playedAt: -1 })
      .limit(2000)
      .toArray();
    return res.json({ ok: true, matches });
  } catch (error) {
    console.warn("[NovynGames] History read failed:", error?.message || error);
    return res.status(503).json({ error: "Cloud game history could not be loaded." });
  }
});

app.post("/api/games/history", requireUser, requireCsrf, async (req, res) => {
  if (!mongoGameHistoryCollection) {
    return res.status(503).json({ error: "Cloud game history is temporarily unavailable." });
  }
  const incoming = Array.isArray(req.body?.matches) ? req.body.matches : [req.body];
  if (!incoming.length || incoming.length > 100) {
    return res.status(400).json({ error: "Submit between 1 and 100 completed matches." });
  }
  const allowedGames = new Set(["tictactoe", "rps", "rockpaperscissors", "rajamantri", "ludo", "uno", "connect4", "doodle", "numberclash", "updown"]);
  const docs = [];
  for (const item of incoming) {
    // Ignore bot records entirely: they neither award XP nor reset a human streak.
    if (item?.isBotMatch === true || item?.opponentType === "bot") continue;
    const matchId = toDisplayName(item?.id || item?.matchId).slice(0, 160);
    const gameType = toDisplayName(item?.gameType).toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 40);
    const opponent = toDisplayName(item?.opponent).slice(0, 192);
    const opponentNames = opponent.split(",").map((name) => name.trim()).filter(Boolean);
    const opponentKeys = opponentNames.map(normalizeName);
    const allOpponentsRegistered = opponentKeys.length > 0 &&
      new Set(opponentKeys).size === opponentKeys.length &&
      opponentKeys.every((opponentKey) =>
        opponentKey !== req.userKey && users.get(opponentKey)?.isRegistered
      );
    const result = ["win", "loss", "draw"].includes(item?.result) ? item.result : "";
    const playedAt = new Date(item?.playedAt);
    // A client flag is not proof that a match was human-vs-human. Require every
    // recorded opponent (including multiplayer opponents) to be a registered account.
    if (!matchId || !allowedGames.has(gameType) || !opponent ||
        !allOpponentsRegistered || !result ||
        opponentNames.some((name) => /^(ai|bot)(\b|[_ -])/i.test(name)) ||
        !Number.isFinite(playedAt.getTime()) ||
        playedAt.getTime() > Date.now() + 5 * 60 * 1000 ||
        playedAt.getTime() < Date.now() - 5 * 365 * 24 * 60 * 60 * 1000) {
      return res.status(400).json({ error: "A completed human match must include registered, different Novyn opponent accounts and valid match details." });
    }
    docs.push({
      _id: req.userKey + ":" + matchId,
      userKey: req.userKey,
      id: matchId,
      gameType,
      opponent,
      result,
      playedAt: playedAt.toISOString(),
      isBotMatch: false,
    });
  }
  try {
    if (docs.length) {
      await mongoGameHistoryCollection.bulkWrite(
        docs.map((doc) => ({ updateOne: {
          filter: { _id: doc._id, userKey: req.userKey },
          update: { $setOnInsert: doc },
          upsert: true,
        }})),
        { ordered: false }
      );
    }
    return res.json({ ok: true, saved: docs.length });
  } catch (error) {
    console.warn("[NovynGames] History write failed:", error?.message || error);
    return res.status(503).json({ error: "Cloud game history could not be saved." });
  }
});

// Leaderboards aggregate persisted non-bot match records for registered accounts.
app.get("/api/games/leaderboard", requireUser, async (req, res) => {
  if (!mongoGameHistoryCollection) {
    return res.status(503).json({ error: "Cloud game history is temporarily unavailable." });
  }

  const scope = String(req.query.scope || "friends").toLowerCase();
  if (!["friends", "global"].includes(scope)) {
    return res.status(400).json({ error: "Choose Friends or Global leaderboard." });
  }

  const game = normalizeLeaderboardGame(req.query.game || "overall");
  if (!game || !["overall", "tictactoe", "rps", "rajamantri"].includes(game)) {
    return res.status(400).json({ error: "Choose a supported game leaderboard." });
  }

  const viewer = users.get(req.userKey);
  if (!viewer?.isRegistered || viewer.isSuspended === true) {
    return res.status(403).json({ error: "A registered account is required for leaderboards." });
  }

  try {
    const eligibleUsers = new Map([[req.userKey, viewer]]);
    if (scope === "friends") {
      for (const rawFriendKey of viewer.friends || []) {
        const friendKey = normalizeName(rawFriendKey);
        const friend = users.get(friendKey);
        if (!friendKey || !friend?.isRegistered || friend.isSuspended === true ||
            usersAreBlocked(req.userKey, friendKey)) {
          continue;
        }
        eligibleUsers.set(friendKey, friend);
      }
    } else {
      for (const [userKey, user] of users.entries()) {
        if (!user?.isRegistered || user.isSuspended === true) continue;
        if (userKey !== req.userKey && usersAreBlocked(req.userKey, userKey)) continue;
        eligibleUsers.set(userKey, user);
      }
    }

    const historyQuery = { isBotMatch: { $ne: true } };
    if (scope === "friends") {
      historyQuery.userKey = { $in: Array.from(eligibleUsers.keys()) };
    }
    const matches = await mongoGameHistoryCollection
      .find(historyQuery, {
        projection: {
          _id: 0,
          userKey: 1,
          gameType: 1,
          result: 1,
          playedAt: 1,
          isBotMatch: 1,
        },
      })
      .sort({ userKey: 1, playedAt: 1 })
      .toArray();

    const rankings = buildGameLeaderboard({
      matches,
      users: eligibleUsers,
      viewerKey: req.userKey,
      selectedGame: game,
    });
    return res.json({
      ok: true,
      scope,
      game,
      totalPlayers: rankings.length,
      rankings: rankings.slice(0, 100),
      myEntry: rankings.find((entry) => entry.isSelf) || null,
    });
  } catch (error) {
    console.warn("[NovynGames] Leaderboard read failed:", error?.message || error);
    return res.status(503).json({ error: "Leaderboard is temporarily unavailable." });
  }
});

// Call history is scoped to the authenticated account. callId makes retries idempotent.
app.get("/api/calls", requireUser, (req, res) => {
  const user = users.get(req.userKey);
  const logs = Array.isArray(user?.callLogs) ? user.callLogs : [];
  res.json(logs.slice(0, 500));
});

app.post("/api/calls", requireUser, requireCsrf, (req, res) => {
  const callerId = toDisplayName(req.body?.callerId).slice(0, 64);
  const receiverId = toDisplayName(req.body?.receiverId).slice(0, 64);
  const callId = toDisplayName(req.body?.callId).slice(0, 128);
  const type = req.body?.type === "video" ? "video" : "voice";
  const status = ["missed", "incoming", "outgoing"].includes(req.body?.status) ? req.body.status : "";
  const duration = Math.max(0, Math.min(86400, Math.floor(Number(req.body?.duration) || 0)));
  const callerKey = normalizeName(callerId);
  const receiverKey = normalizeName(receiverId);
  if (!callerKey || !receiverKey || callerKey === receiverKey || !status ||
      ![callerKey, receiverKey].includes(req.userKey)) {
    res.status(400).json({ error: "Invalid call log entry." });
    return;
  }
  const user = users.get(req.userKey);
  if (!Array.isArray(user.callLogs)) user.callLogs = [];
  const entry = {
    callId: callId || createMessageId(),
    callerId,
    receiverId,
    type,
    status,
    duration,
    createdAt: nowIso(),
  };
  const existingIndex = user.callLogs.findIndex((item) => item?.callId === entry.callId);
  if (existingIndex >= 0) user.callLogs[existingIndex] = { ...user.callLogs[existingIndex], ...entry };
  else user.callLogs.unshift(entry);
  user.callLogs = user.callLogs.slice(0, 500);
  schedulePersist();
  res.json({ ok: true });
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

// Public profile previews intentionally expose only profile fields that the
// account owner has made visible to everyone. No email, presence, contacts,
// relationship graph, or account/security data is returned here.
// No public profile website is configured. In-app profile QR codes use
// the novyn:// scheme, so no website origin is allowed here.
const PUBLIC_PROFILE_ORIGINS = new Set();
const PUBLIC_PROFILE_API_ORIGIN = "https://novyn-live.onrender.com";

function setPublicProfileCors(req, res) {
  const origin = String(req.headers.origin || "");
  if (PUBLIC_PROFILE_ORIGINS.has(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Accept, Content-Type");
}

function findPublicProfileUser(username) {
  const key = normalizeName(toDisplayName(username).replace(/^@/, ""));
  const user = key ? users.get(key) : null;
  return user?.isRegistered ? { key, user } : null;
}

app.options("/api/public/profile/:username", (req, res) => {
  setPublicProfileCors(req, res);
  res.sendStatus(204);
});

app.options("/api/public/profile/:username/avatar", (req, res) => {
  setPublicProfileCors(req, res);
  res.sendStatus(204);
});

app.get(
  "/api/public/profile/:username",
  (req, res, next) => { setPublicProfileCors(req, res); next(); },
  createIpRateLimiter({ getStore: () => httpRateLimits }, "public-profile", 60, 60 * 1000),
  (req, res) => {
    setPublicProfileCors(req, res);
    res.set("Cache-Control", "public, max-age=60, stale-while-revalidate=120");

    const found = findPublicProfileUser(req.params.username);
    if (!found) {
      res.status(404).json({ error: "Profile not found." });
      return;
    }

    const { key, user } = found;
    const profile = {
      username: user.username,
      displayName: user.displayName || user.username,
      bio: String(user.bio || "").slice(0, 160),
      avatarUrl: "",
      canReceiveRequests: (user.friendRequestPrivacy || "everyone") !== "nobody",
    };

    // Only expose a photo when the owner explicitly allows public visibility.
    // The avatar endpoint independently verifies media ownership on every read.
    if ((user.profilePhotoPrivacy || "everyone") === "everyone" &&
        mediaNames(user.avatarId || "").length) {
      profile.avatarUrl = `${PUBLIC_PROFILE_API_ORIGIN}/api/public/profile/${encodeURIComponent(user.username)}/avatar`;
    }

    res.json(profile);
  },
);

app.get(
  "/api/public/profile/:username/avatar",
  (req, res, next) => { setPublicProfileCors(req, res); next(); },
  createIpRateLimiter({ getStore: () => httpRateLimits }, "public-profile-avatar", 90, 60 * 1000),
  (req, res) => {
    setPublicProfileCors(req, res);
    res.set("Cache-Control", "private, no-store");
    res.set("Referrer-Policy", "no-referrer");

    const found = findPublicProfileUser(req.params.username);
    if (!found) {
      res.status(404).end();
      return;
    }

    const { key, user } = found;
    if ((user.profilePhotoPrivacy || "everyone") !== "everyone") {
      res.status(404).end();
      return;
    }

    const filename = mediaNames(user.avatarId || "")[0];
    if (!filename) {
      res.status(404).end();
      return;
    }

    const metadata = mediaMetadata(filename);
    if (!metadata || resolveCurrentUserKey(metadata.ownerKey) !== key) {
      res.status(404).end();
      return;
    }

    if (metadata.remote) {
      try {
        return res.redirect(302, cloudinary.utils.private_download_url(
          metadata.remote.publicId,
          metadata.remote.format,
          {
            resource_type: metadata.remote.resourceType,
            type: "authenticated",
            expires_at: Math.floor(Date.now() / 1000) + 60,
          },
        ));
      } catch (_) {
        res.status(404).end();
        return;
      }
    }

    const filePath = path.join(uploadsDir, filename);
    if (!fs.existsSync(filePath)) {
      res.status(404).end();
      return;
    }
    res.sendFile(filePath);
  },
);

app.get(
  "/api/users/check-username",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "username-check", 60, 60 * 1000),
  (req, res) => {
    const username = normalizeHandleInput(toDisplayName(req.query?.username || ""));
    const valid = username.length >= 3 && username.length <= 24 &&
      !/[^a-z0-9_]/.test(username);
    res.set("Cache-Control", "no-store, max-age=0");
    res.json({ available: valid && !isUsernameTaken(username) });
  },
);
app.get(
  "/api/users/search",
  requireUser,
  createIpRateLimiter({ getStore: () => httpRateLimits }, "user-search", 60, 60 * 1000),
  (req, res) => {
    const query = normalizeName(
      toDisplayName(req.query?.q || "").replace(/^@/, ""),
    );
    if (!query) {
      res.json([]);
      return;
    }
    if (query.length > 40) {
      res.status(400).json({ error: "Username search is too long." });
      return;
    }

    const me = users.get(req.userKey);
    if (!me?.isRegistered) {
      res.status(401).json({ error: "Sign in required." });
      return;
    }

    const results = buildUserSearchResults({
      users,
      userKey: req.userKey,
      query,
      usersAreBlocked,
      privacyAllows,
      getEffectivePresence,
      getVisibleLastSeen,
      limit: 8,
    });

    res.set("Cache-Control", "no-store, max-age=0");
    res.json(results);
  },
);


const conversationWallpapers = new Map();

const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, "runtime", "data"));
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
const MIN_PASSWORD_LENGTH = 12;
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
const MAX_MESSAGE_LENGTH = 250;
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
  "video/mp4",
  "video/webm",
  "video/quicktime",
  "image/bmp",
  "image/heic",
  "audio/webm",
  "audio/wav",
  "audio/mpeg",
  "audio/ogg",
  "audio/mp4",
  "audio/aac",
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

if (process.env.RENDER && !MONGODB_URI) {
  console.warn(
    `Render deployment is using file-based chat and auth storage in "${DATA_DIR}". ` +
      "Mount a persistent disk at this path or configure MONGODB_URI; otherwise deploys/restarts can lose chat history and log users out."
  );
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
      disableFileAccess: true,
      disableUrlAccess: true,
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

const publicGameMatchmaking = new PublicGameMatchmaking({
  timeoutMs: 60_000,
  onExpired: ({ socketId, gameType }) => io.to(socketId).emit("random_match_timeout", {
    gameType, message: "No player available right now. Please try again.",
  }),
});

const rajaMantriMatchmaking = new RajaMantriMatchmaking({
  timeoutMs: 60_000,
  onExpired: ({ socketId, playerCount }) => io.to(socketId).emit("rajamantri_match_timeout", {
    playerCount,
    message: "No full group found right now. Please try again.",
  }),
  onProgress: ({ socketId, playerCount, playersFound, waitingPlayers }) => io.to(socketId).emit("rajamantri_match_progress", {
    playerCount,
    playersFound,
    players: waitingPlayers,
  }),
});

const rajaMantriSessions = new Map();
const RAJA_MANTRI_SESSION_TTL_MS = 60 * 60 * 1000;
const RAJA_MANTRI_RESPONSE_TIMEOUT_MS = 15_000;

function scheduleRajaMantriPhaseTimer(entry) {
  if (!entry?.game) return;
  const game = entry.game;
  if (!["picking", "guessing"].includes(game.phase)) {
    clearTimeout(entry.responseTimer);
    entry.responseTimer = null;
    entry.responseTimerDeadline = 0;
    return;
  }
  const deadline = Number(game.responseDeadlineAt) || (Date.now() + RAJA_MANTRI_RESPONSE_TIMEOUT_MS);
  game.responseDeadlineAt = deadline;
  if (entry.responseTimer && entry.responseTimerDeadline === deadline) return;
  clearTimeout(entry.responseTimer);
  entry.responseTimerDeadline = deadline;
  entry.responseTimer = setTimeout(() => {
    entry.responseTimer = null;
    entry.responseTimerDeadline = 0;
    if (!rajaMantriSessions.has(game.sessionId) || rajaMantriSessions.get(game.sessionId) !== entry) return;

    if (game.phase === "picking") {
      for (const player of game.players) {
        if (!player.isBot && !player.picked) {
          autoPickRajaMantriChit(game, player.username);
        }
      }
    } else if (game.phase === "guessing") {
      const sipahi = game.players.find((player) => player.username === game.sipahiUsername);
      if (sipahi && !sipahi.isBot) {
        const roles = game.playerCount === 3 ? new Set(["raja", "chor"]) : new Set(["chor", "mantri"]);
        const suspects = game.players.filter((player) => roles.has(player.role));
        if (suspects.length) {
          const suspect = suspects[Math.floor(Math.random() * suspects.length)];
          guessRajaMantriChor(game, sipahi.username, suspect.username, { autoPlayed: true });
        }
      }
    }

    emitRajaMantriGameUpdate(game);
    scheduleRajaMantriPhaseTimer(entry);
  }, Math.max(0, deadline - Date.now()));
  if (typeof entry.responseTimer.unref === "function") entry.responseTimer.unref();
}

function emitRajaMantriGameUpdate(session) {
  if (!session) return;
  for (const player of session.players) {
    if (player.isBot) continue;
    const socketId = onlineUsers.get(player.username);
    if (!socketId) continue;
    io.to(socketId).emit("rajamantri_game_updated", {
      sessionId: session.sessionId,
      game: getRajaMantriGameView(session, player.username),
    });
  }
}

function expireRajaMantriSession(sessionId) {
  const entry = rajaMantriSessions.get(sessionId);
  if (!entry) return;
  clearTimeout(entry.expiryTimer);
  clearTimeout(entry.responseTimer);
  rajaMantriSessions.delete(sessionId);
}

// Random matches are short-lived, server-authoritative sessions. They do not
// depend on a friendship or a chat thread, and are discarded after 30 minutes.
const randomGameSessions = new Map();
const RANDOM_GAME_SESSION_TTL_MS = 30 * 60 * 1000;
const pendingGameInvites = new Map();

let mongoStorage = null;
let mongoLegacyCollection = null;
let mongoUsersCollection = null;
let mongoConversationsCollection = null;
let mongoMessagesCollection = null;
let mongoAuthSessionsCollection = null;
let mongoMediaCollection = null;
let mongoGameHistoryCollection = null;
const mediaMetadataCache = new Map();

let persistTimer = null;
let persistInFlight = Promise.resolve();
let authPersistTimer = null;
let authPersistInFlight = Promise.resolve();

const authSessions = createAuthSessions({
  refreshSessions,
  refreshByUser,
  authUserAliases,
  schedulePersist: () => scheduleAuthStatePersist(),
  aliasTtlMs: AUTH_ALIAS_TTL_MS,
});

const {
  revokeRefreshSession,
  moveRefreshSessionsToUser,
  linkAuthAlias,
  pruneExpiredAuthState,
} = authSessions;

function createAuthToken(kind, userKey, ttlMs, extra = {}) {
  return signAuthToken({
    secret: AUTH_SECRET,
    kind,
    userKey,
    ttlMs,
    extra,
  });
}

function verifyAuthToken(rawToken, expectedKind) {
  return verifySignedAuthToken({
    secret: AUTH_SECRET,
    rawToken,
    expectedKind,
  });
}

function encryptTotpSecret(secret) {
  const key = crypto.createHash("sha256").update(AUTH_SECRET).digest();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(String(secret), "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return "enc:v1:" + Buffer.concat([iv, tag, encrypted]).toString("base64");
}

function decryptTotpSecret(value) {
  const stored = toDisplayName(value);
  if (!stored.startsWith("enc:v1:")) return stored; // migrate legacy plaintext on next successful settings update
  try {
    const payload = Buffer.from(stored.slice(7), "base64");
    if (payload.length < 29) return "";
    const key = crypto.createHash("sha256").update(AUTH_SECRET).digest();
    const iv = payload.subarray(0, 12);
    const tag = payload.subarray(12, 28);
    const encrypted = payload.subarray(28);
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
  } catch (_) {
    return "";
  }
}

function resolveCurrentUserKey(rawKey) {
  let key = normalizeName(rawKey);
  const seen = new Set();
  while (key && !seen.has(key)) {
    seen.add(key);
    if (users.has(key)) return key;
    const alias = authUserAliases.get(key);
    if (!alias) break;
    if (Date.now() > Number(alias.expiresAt)) {
      authUserAliases.delete(key);
      break;
    }
    key = normalizeName(alias.newKey);
  }
  return "";
}

function getAuthCookiesFromHeader(rawCookieHeader) {
  const cookies = parseCookies(rawCookieHeader);
  return {
    accessToken: toDisplayName(cookies[AUTH_ACCESS_COOKIE]),
    refreshToken: toDisplayName(cookies[AUTH_REFRESH_COOKIE]),
  };
}

function resolveUserFromAuthCookies(authCookies, options = {}) {
  pruneExpiredAuthState();
  const allowRefreshFallback = options.allowRefreshFallback !== false;

  const accessPayload = verifyAuthToken(authCookies?.accessToken, "access");
  const accessSession = accessPayload?.sid && refreshSessions.get(accessPayload.sid);
  if (accessSession && Number(accessSession.expiresAt) > Date.now()) {
    const resolved = resolveCurrentUserKey(accessPayload.sub);
    if (
      resolved &&
      resolved === resolveCurrentUserKey(accessSession.userKey) &&
      users.get(resolved)?.isSuspended !== true
    ) {
      accessSession.lastActiveAt = Date.now();
      return { userKey: resolved, via: "access", sessionId: accessPayload.sid };
    }
  }

  if (!allowRefreshFallback) return { userKey: "" };

  const refreshPayload = verifyAuthToken(authCookies?.refreshToken, "refresh");
  if (!refreshPayload?.jti) return { userKey: "" };
  const session = refreshSessions.get(refreshPayload.jti);
  if (!session || Date.now() > Number(session.expiresAt)) {
    revokeRefreshSession(refreshPayload.jti);
    return { userKey: "" };
  }

  const resolved = resolveCurrentUserKey(session.userKey || refreshPayload.sub);
  if (!resolved || users.get(resolved)?.isSuspended === true) {
    revokeRefreshSession(refreshPayload.jti);
    return { userKey: "" };
  }
  session.userKey = resolved;
  session.lastActiveAt = Date.now();
  return {
    userKey: resolved,
    via: "refresh",
    remember: Boolean(session.remember),
    refreshTokenId: toDisplayName(refreshPayload.jti),
    sessionId: toDisplayName(refreshPayload.jti),
  };
}

function readRememberFlag(value) {
  if (typeof value === "boolean") return value;
  return ["1", "true", "yes", "on"].includes(toDisplayName(value).toLowerCase());
}

function describeAuthDevice(req) {
  const userAgent = toDisplayName(req?.headers?.["user-agent"]);
  const client = toDisplayName(req?.headers?.["x-novyn-client"]).toLowerCase() || "web";
  let deviceName = "Web browser";
  if (client === "mobile") deviceName = /android/i.test(userAgent) ? "Android app" : "Novyn mobile app";
  else if (/android/i.test(userAgent)) deviceName = "Android device";
  else if (/iphone|ipad|ipod/i.test(userAgent)) deviceName = "Apple device";
  else if (/windows/i.test(userAgent)) deviceName = "Windows browser";
  else if (/macintosh|mac os/i.test(userAgent)) deviceName = "Mac browser";
  else if (/linux/i.test(userAgent)) deviceName = "Linux browser";
  if (client === "web") {
    const browser = /edg\//i.test(userAgent) ? "Edge" : /firefox\//i.test(userAgent) ? "Firefox" : /chrome\//i.test(userAgent) ? "Chrome" : /safari\//i.test(userAgent) ? "Safari" : "Browser";
    deviceName = `${browser} · ${deviceName}`;
  }
  return { deviceName, client, createdAt: Date.now() };
}

async function issueAuthTokensForUser(userKey, remember, req, options = {}) {
  const key = normalizeName(userKey);
  if (!key || users.get(key)?.isSuspended === true) return null;
  const persistent = Boolean(remember);
  const refreshTtl = persistent ? AUTH_REFRESH_REMEMBER_TTL_MS : AUTH_REFRESH_SESSION_TTL_MS;
  const refreshTokenId = crypto.randomBytes(16).toString("hex");
  const accessToken = createAuthToken("access", key, AUTH_ACCESS_TTL_MS, { sid: refreshTokenId });
  const refreshToken = createAuthToken("refresh", key, refreshTtl, {
    jti: refreshTokenId,
    remember: persistent ? 1 : 0,
  });
  authSessions.trackRefreshSession(key, refreshTokenId, Date.now() + refreshTtl, persistent, describeAuthDevice(req));

  // Persist the server-side allow-list entry before exposing its refresh cookie.
  // A process restart during the debounce window must not invalidate a newly
  // issued token pair on the next app launch.
  try {
    // Existing-user sign-in only changes the auth-session record. Persisting
    // the complete chat snapshot for every login is expensive and can block
    // authentication as conversations grow. Persist user data only when the
    // auth flow actually created/changed the account or consumed a backup code.
    if (options.persistUserState === true) {
      await flushStatePersistNow();
    }
    await flushAuthStatePersistNow();
  } catch (error) {
    revokeRefreshSession(refreshTokenId);
    try {
      await flushAuthStatePersistNow();
    } catch (rollbackError) {
      console.error("[NovynAuth] Could not persist session rollback:", rollbackError);
    }
    console.error("[NovynAuth] Could not persist a newly issued session:", error);
    return null;
  }

  return { accessToken, refreshToken, remember: persistent };
}

function applyAuthCookies(res, issuedTokens) {
  if (!res || !issuedTokens?.accessToken || !issuedTokens?.refreshToken) return;
  const shared = {
    httpOnly: true,
    sameSite: "lax",
    secure: AUTH_COOKIE_SECURE,
    path: "/",
  };
  res.cookie(AUTH_ACCESS_COOKIE, issuedTokens.accessToken, { ...shared, maxAge: AUTH_ACCESS_TTL_MS });
  const refreshTtlMs = issuedTokens.remember
    ? AUTH_REFRESH_REMEMBER_TTL_MS
    : AUTH_REFRESH_SESSION_TTL_MS;
  res.cookie(AUTH_REFRESH_COOKIE, issuedTokens.refreshToken, { ...shared, maxAge: refreshTtlMs });
  res.cookie(AUTH_CSRF_COOKIE, createCsrfToken(), {
    sameSite: "lax",
    secure: AUTH_COOKIE_SECURE,
    path: "/",
    maxAge: refreshTtlMs,
  });
}

function clearAuthCookies(res) {
  if (!res) return;
  const shared = { httpOnly: true, sameSite: "lax", secure: AUTH_COOKIE_SECURE, path: "/" };
  res.clearCookie(AUTH_ACCESS_COOKIE, shared);
  res.clearCookie(AUTH_REFRESH_COOKIE, shared);
  res.clearCookie(AUTH_CSRF_COOKIE, { sameSite: "lax", secure: AUTH_COOKIE_SECURE, path: "/" });
}

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
const { verifyTotpCode } = require("./server/auth/totp");

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
    hiddenChats: new Set(),
    pushSubs: [],
    fcmToken: "",
    isRegistered: false,
    isSuspended: false,
    passwordSalt: "",
    passwordHash: "",
    stealthModeEnabled: false,
    twoFactorEnabled: false,
    twoFactorSecret: "",
    twoFactorBackupCodes: [],
    notificationsEnabled: true,
    messagePreviewEnabled: true,
    hideNotificationContent: false,
    doNotDisturbEnabled: false,
    favoriteChatIds: [],
    groupNotificationsEnabled: true,
    directMessagesEnabled: true,
    groupMessagesEnabled: true,
    mentionsRepliesEnabled: true,
    friendRequestsEnabled: true,
    friendRequestAcceptedEnabled: true,
    groupInvitationsEnabled: true,
    voiceCallsEnabled: true,
    videoCallsEnabled: true,
    missedCallsEnabled: true,
    gameInvitationsEnabled: true,
    gameTurnEnabled: true,
    gameResultsEnabled: true,
    quietHoursEnabled: false,
    quietHoursStart: "22:00",
    quietHoursEnd: "07:00",
    quietHoursOffsetMinutes: 0,
    notificationSoundEnabled: true,
    notificationVibrationEnabled: true,
    avatarId: "",
    age: "",
    gender: "",
    displayName: "",
    bio: "",
    createdAt: "",
    lastSeenAt: "",
    presenceMode: "online",
    publicKey: "",
    e2eeIdentityBackup: "",
    e2eeIdentityBackupPublicKey: "",
    retentionDays: 0,
    callsEnabled: true,
    callPrivacy: "friends",
    messagePrivacy: "friends",
    profilePhotoPrivacy: "everyone",
    presencePrivacy: "everyone",
    discoverPrivacy: "everyone",
    readReceiptsEnabled: true,
    typingIndicatorsEnabled: true,
    groupInvitePrivacy: "friends",
    friendRequestPrivacy: "everyone",
    callLogs: [],
  };
}

function serializeState() {
  return {
    wallpapers: Array.from(conversationWallpapers.entries()),
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
      hiddenChats: Array.from(user.hiddenChats || []),
      pushSubs: Array.isArray(user.pushSubs) ? user.pushSubs : [],
      fcmToken: toDisplayName(user.fcmToken),
      notificationsEnabled: user.notificationsEnabled !== false,
      messagePreviewEnabled: user.messagePreviewEnabled !== false,
      hideNotificationContent: user.hideNotificationContent === true,
      doNotDisturbEnabled: user.doNotDisturbEnabled === true,
      favoriteChatIds: Array.isArray(user.favoriteChatIds) ? user.favoriteChatIds : [],
      groupNotificationsEnabled: user.groupNotificationsEnabled !== false,
      directMessagesEnabled: user.directMessagesEnabled !== false,
      groupMessagesEnabled: user.groupMessagesEnabled !== false,
      mentionsRepliesEnabled: user.mentionsRepliesEnabled !== false,
      friendRequestsEnabled: user.friendRequestsEnabled !== false,
      friendRequestAcceptedEnabled: user.friendRequestAcceptedEnabled !== false,
      groupInvitationsEnabled: user.groupInvitationsEnabled !== false,
      voiceCallsEnabled: user.voiceCallsEnabled !== false,
      videoCallsEnabled: user.videoCallsEnabled !== false,
      missedCallsEnabled: user.missedCallsEnabled !== false,
      gameInvitationsEnabled: user.gameInvitationsEnabled !== false,
      gameTurnEnabled: user.gameTurnEnabled !== false,
      gameResultsEnabled: user.gameResultsEnabled !== false,
      quietHoursEnabled: user.quietHoursEnabled === true,
      quietHoursStart: user.quietHoursStart || "22:00",
      quietHoursEnd: user.quietHoursEnd || "07:00",
      quietHoursOffsetMinutes: Number.isFinite(Number(user.quietHoursOffsetMinutes)) ? Number(user.quietHoursOffsetMinutes) : 0,
      notificationSoundEnabled: user.notificationSoundEnabled !== false,
      notificationVibrationEnabled: user.notificationVibrationEnabled !== false,
      isRegistered: Boolean(user.isRegistered),
      isSuspended: user.isSuspended === true,
      passwordSalt: toDisplayName(user.passwordSalt),
      passwordHash: toDisplayName(user.passwordHash),
      stealthModeEnabled: user.stealthModeEnabled === true,
      twoFactorEnabled: Boolean(user.twoFactorEnabled),
      twoFactorSecret: toDisplayName(user.twoFactorSecret),
      twoFactorBackupCodes: Array.isArray(user.twoFactorBackupCodes) ? user.twoFactorBackupCodes : [],
      avatarId: toDisplayName(user.avatarId),
      age: toDisplayName(user.age),
      gender: toDisplayName(user.gender),
      displayName: toDisplayName(user.displayName),
      bio: toDisplayName(user.bio),
      createdAt: toDisplayName(user.createdAt),
      lastSeenAt: toDisplayName(user.lastSeenAt),
      presenceMode: normalizePresenceMode(user.presenceMode),
      publicKey: toDisplayName(user.publicKey),
      e2eeIdentityBackup: toDisplayName(user.e2eeIdentityBackup),
      e2eeIdentityBackupPublicKey: toDisplayName(user.e2eeIdentityBackupPublicKey),
      retentionDays: 0,
      callsEnabled: user.callsEnabled !== false,
        callPrivacy: user.callPrivacy || "friends", messagePrivacy: user.messagePrivacy || "friends",
      profilePhotoPrivacy: user.profilePhotoPrivacy || "everyone", presencePrivacy: user.presencePrivacy || "everyone", discoverPrivacy: user.discoverPrivacy || "everyone",
      readReceiptsEnabled: user.readReceiptsEnabled !== false, typingIndicatorsEnabled: user.typingIndicatorsEnabled !== false,
      groupInvitePrivacy: user.groupInvitePrivacy || "friends", friendRequestPrivacy: user.friendRequestPrivacy || "everyone",
      callLogs: Array.isArray(user.callLogs) ? user.callLogs.slice(0, 500) : [],
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
      deviceName: toDisplayName(entry?.deviceName),
      client: toDisplayName(entry?.client),
      createdAt: Number(entry?.createdAt) || 0,
      lastActiveAt: Number(entry?.lastActiveAt) || 0,
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
      deviceName: toDisplayName(rawEntry?.deviceName || "Unknown device"),
      client: toDisplayName(rawEntry?.client || "web"),
      createdAt: Number(rawEntry?.createdAt) || 0,
      lastActiveAt: Number(rawEntry?.lastActiveAt) || Number(rawEntry?.createdAt) || 0,
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
  await fsp.writeFile(`${DATA_FILE}.tmp`, payload, "utf8");
  await fsp.rename(`${DATA_FILE}.tmp`, DATA_FILE);
}

async function persistAuthStateNow() {
  const state = serializeAuthRuntimeState();
  if (mongoAuthSessionsCollection) {
    await mongoAuthSessionsCollection.updateOne(
      { _id: "runtime" },
      { $set: { state, updatedAt: new Date() } },
      { upsert: true }
    );
    return;
  }

  const payload = JSON.stringify(state, null, 2);
  await fsp.mkdir(DATA_DIR, { recursive: true });
  await fsp.writeFile(`${AUTH_STATE_FILE}.tmp`, payload, "utf8");
  await fsp.rename(`${AUTH_STATE_FILE}.tmp`, AUTH_STATE_FILE);
}

function hasMongoStorage() {
  return Boolean(mongoUsersCollection && mongoConversationsCollection && mongoMessagesCollection);
}

async function bulkWriteInChunks(collection, operations, session = null, chunkSize = 500) {
  if (!collection || !Array.isArray(operations) || operations.length === 0) return;
  for (let i = 0; i < operations.length; i += chunkSize) {
    const chunk = operations.slice(i, i + chunkSize);
    // Keep unordered writes to tolerate individual bad docs without aborting the batch.
    await collection.bulkWrite(chunk, { ordered: false, ...(session ? { session } : {}) });
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
  const session = mongoStorage.client.startSession();

  try {
    await session.withTransaction(async () => {

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
              hiddenChats: Array.isArray(entry.hiddenChats) ? entry.hiddenChats : [],
              pushSubs: Array.isArray(entry.pushSubs) ? entry.pushSubs : [],
              fcmToken: toDisplayName(entry.fcmToken),
              notificationsEnabled: entry.notificationsEnabled !== false,
              messagePreviewEnabled: entry.messagePreviewEnabled !== false,
              hideNotificationContent: entry.hideNotificationContent === true,
              doNotDisturbEnabled: entry.doNotDisturbEnabled === true,
              favoriteChatIds: Array.isArray(entry.favoriteChatIds) ? entry.favoriteChatIds : [],
              groupNotificationsEnabled: entry.groupNotificationsEnabled !== false,
              isRegistered: Boolean(entry.isRegistered),
              isSuspended: entry.isSuspended === true,
              passwordSalt: toDisplayName(entry.passwordSalt),
              passwordHash: toDisplayName(entry.passwordHash),
              stealthModeEnabled: entry.stealthModeEnabled === true,
              twoFactorEnabled: Boolean(entry.twoFactorEnabled),
              twoFactorSecret: toDisplayName(entry.twoFactorSecret),
              twoFactorBackupCodes: Array.isArray(entry.twoFactorBackupCodes) ? entry.twoFactorBackupCodes : [],
              avatarId: toDisplayName(entry.avatarId),
              age: toDisplayName(entry.age),
              gender: toDisplayName(entry.gender),
              displayName: toDisplayName(entry.displayName),
              bio: toDisplayName(entry.bio),
              createdAt: toDisplayName(entry.createdAt),
              lastSeenAt: toDisplayName(entry.lastSeenAt),
              presenceMode: normalizePresenceMode(entry.presenceMode),
              publicKey: toDisplayName(entry.publicKey),
              e2eeIdentityBackup: toDisplayName(entry.e2eeIdentityBackup),
              e2eeIdentityBackupPublicKey: toDisplayName(entry.e2eeIdentityBackupPublicKey),
              callsEnabled: entry.callsEnabled !== false,
              callPrivacy: entry.callPrivacy || "friends",
              messagePrivacy: entry.messagePrivacy || "friends",
              profilePhotoPrivacy: entry.profilePhotoPrivacy || "everyone",
              presencePrivacy: entry.presencePrivacy || "everyone",
              discoverPrivacy: entry.discoverPrivacy || "everyone",
              readReceiptsEnabled: entry.readReceiptsEnabled !== false,
              typingIndicatorsEnabled: entry.typingIndicatorsEnabled !== false,
              groupInvitePrivacy: entry.groupInvitePrivacy || "friends",
              friendRequestPrivacy: entry.friendRequestPrivacy || "everyone",

              callLogs: Array.isArray(entry.callLogs) ? entry.callLogs.slice(0, 500) : [],
              snapshotId,
              updatedAt,
            },
          },
          upsert: true,
        },
      };
    });
  await bulkWriteInChunks(mongoUsersCollection, userOps, session);
  await mongoUsersCollection.deleteMany({ snapshotId: { $ne: snapshotId } }, { session });

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
        await bulkWriteInChunks(mongoMessagesCollection, pendingMessageOps, session);
        pendingMessageOps = [];
      }
    }
  }

  await bulkWriteInChunks(mongoConversationsCollection, conversationOps, session);
  await mongoConversationsCollection.deleteMany({ snapshotId: { $ne: snapshotId } }, { session });
  if (pendingMessageOps.length) {
    await bulkWriteInChunks(mongoMessagesCollection, pendingMessageOps, session);
  }
  await mongoMessagesCollection.deleteMany({ snapshotId: { $ne: snapshotId } }, { session });

  if (mongoLegacyCollection) {
    await mongoLegacyCollection.updateOne(
      { _id: "main" },
      {
        $set: {
          _id: "main",
          migratedToCollections: true,
          updatedAt,
          retentionDays: 0,
          groups: state.groups || [],
          wallpapers: state.wallpapers || [],
          scheduledMessages: state.scheduledMessages || [],
        },
      },
      { upsert: true, session }
    );
    // Count the exact documents written in this transaction, then publish
    // the manifest atomically with them. Startup validates these counts.
    const [userCount, conversationCount, messageCount] = await Promise.all([
      mongoUsersCollection.countDocuments({ snapshotId }, { session }),
      mongoConversationsCollection.countDocuments({ snapshotId }, { session }),
      mongoMessagesCollection.countDocuments({ snapshotId }, { session }),
    ]);
    await mongoLegacyCollection.updateOne(
      { _id: "snapshot_manifest" },
      {
        $set: {
          snapshotId,
          userCount,
          conversationCount,
          messageCount,
          committedAt: updatedAt,
        },
      },
      { upsert: true, session }
    );
  }
    }, {
      readConcern: { level: "snapshot" },
      writeConcern: { w: "majority" },
      readPreference: "primary",
      maxCommitTimeMS: 15000,
    });
  } finally {
    await session.endSession();
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
  if (persistTimer) return;

  persistTimer = setTimeout(() => {
    persistTimer = null;
    persistInFlight = persistInFlight
      .then(() => persistNow())
      .catch((err) => {
        console.error("Failed to persist chat state:", err);
      });
  }, 180);
}

async function flushStatePersistNow() {
  if (persistTimer) {
    clearTimeout(persistTimer);
    persistTimer = null;
  }

  const write = persistInFlight.then(() => persistNow());
  persistInFlight = write.catch((error) => {
    console.error("Failed to persist chat state:", error);
  });
  await write;
}

function scheduleAuthStatePersist() {
  if (authPersistTimer) return;

  authPersistTimer = setTimeout(() => {
    authPersistTimer = null;
    authPersistInFlight = authPersistInFlight
      .then(() => persistAuthStateNow())
      .catch((err) => {
        console.error("Failed to persist auth session state:", err);
      });
  }, 120);
}

// Flush pending auth persistence through the same promise chain as the
// debounced writer, avoiding concurrent file/database writes.
async function flushAuthStatePersistNow() {
  if (authPersistTimer) {
    clearTimeout(authPersistTimer);
    authPersistTimer = null;
  }

  const write = authPersistInFlight.then(() => persistAuthStateNow());
  authPersistInFlight = write.catch((error) => {
    console.error("Failed to persist auth session state:", error);
  });
  await write;
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

function normalizePushPublicKey(value) {
  const raw = typeof value === "string" ? value.trim() : "";
  if (!raw || raw.length > 2048) return "";
  try {
    const key = JSON.parse(raw);
    if (key?.kty === "EC" && key?.crv === "P-256" &&
        typeof key.x === "string" && typeof key.y === "string" &&
        key.x.length >= 40 && key.y.length >= 40) return raw;
  } catch (_) {}
  return "";
}

function formatPushBody(text, fallback = "New message") {
  const cleaned = String(text || "").replace(/\s+/g, " ").trim();
  if (!cleaned) return fallback;
  if (cleaned.length <= 120) return cleaned;
  return `${cleaned.slice(0, 117)}...`;
}

async function sendPushToUser(userKey, payload) {
  if (!userKey) return;
  const user = users.get(userKey);
  if (!user || user.notificationsEnabled === false) return;
  if (!shouldDeliverNotification(user, payload)) return;
  if (["message", "game_invitation", "game_turn", "game_result"].includes(String(payload?.type || ""))) {
    const conversationKey = payload?.group === true
      ? normalizeGroupId(payload?.groupId || payload?.chat)
      : normalizeName(payload?.chat || payload?.from);
    if (conversationKey) {
      const hiddenChats = user.hiddenChats instanceof Set
        ? user.hiddenChats
        : new Set(Array.isArray(user.hiddenChats) ? user.hiddenChats : []);
      if (hiddenChats.has(conversationKey) || isMutedBy(user, conversationKey)) return;
    }
  }
  const previewEnabled = user.messagePreviewEnabled !== false &&
    user.hideNotificationContent !== true;
  const safePayload = {
    ...payload,
    soundEnabled: user.notificationSoundEnabled !== false,
    vibrationEnabled: user.notificationVibrationEnabled !== false,
    ...(payload?.type === "message" && !previewEnabled
      ? { body: payload?.group === true ? "New group message" : "You have a new message" }
      : {}),
    silent: payload?.silent === true,
  };
  const body = JSON.stringify(safePayload);

  // Browser push subscriptions (web app).
  if (pushEnabled && Array.isArray(user.pushSubs) && user.pushSubs.length > 0) {
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

  // Firebase Cloud Messaging (Android/iOS app). The mobile client stores its
  // current token in Firestore at users/<username>. A missing token is normal.
  if (firebaseAdmin) {
    try {
      const token = toDisplayName(user.fcmToken);
      if (token) {
        const isEncryptedDirectMessage =
          safePayload.type === "message" &&
          safePayload.group !== true &&
          typeof safePayload.ciphertext === "string" &&
          typeof safePayload.iv === "string" &&
          typeof safePayload.senderPublicKey === "string";
        // Encrypted direct messages use data-only delivery. The recipient app
        // decrypts locally and creates the visible notification; plaintext
        // never passes through FCM or this server.
        const isCallPush = safePayload.type === "call";
        // The mobile app renders data-only notifications so category,
        // quiet-hours, mute, preview, sound and vibration preferences are
        // applied consistently in foreground and background states.
        // Visible alerts carry a notification + data payload. Android can
        // render them from the system tray even when Flutter is not running.
        // Only explicit silent events and calls remain data-only.
        const isManagedDataPush = safePayload.silent === true;
        const notificationChannelBase =
          safePayload.type === "message" ? "novyn_messages" :
          String(safePayload.type || "").startsWith("game_") ? "novyn_games" :
          safePayload.type === "app_update" ? "novyn_app_updates" : "novyn_social";
        const notificationChannelId = notificationChannelBase + "_" +
          (safePayload.soundEnabled ? "sound" : "silent") + "_" +
          (safePayload.vibrationEnabled ? "vibrate" : "no_vibrate");
        const data = {
          type: toDisplayName(safePayload.type) || "message",
          url: toDisplayName(safePayload.url),
          tag: toDisplayName(safePayload.tag),
          recipient: toDisplayName(user.username) || userKey,
          eventId: toDisplayName(safePayload.eventId) ||
            (String(safePayload.type || "notification") + ":" + String(Date.now())),
          chat: toDisplayName(payload?.group === true ? payload?.groupId : payload?.chat) || "",
          kind: payload?.group === true ? "group" : "friend",
          from: toDisplayName(safePayload.from),
          ...(safePayload.gameId ? { gameId: toDisplayName(safePayload.gameId) } : {}),
          ...(safePayload.gameType ? { gameType: toDisplayName(safePayload.gameType) } : {}),
          mentionOrReply: safePayload.mentionOrReply ? "1" : "0",
          soundEnabled: safePayload.soundEnabled === false ? "0" : "1",
          vibrationEnabled: safePayload.vibrationEnabled === false ? "0" : "1",
          // Keep a data-payload copy so Flutter can honor local preview/privacy
          // preferences and show plaintext previews when the app is backgrounded.
          ...(!isCallPush ? {
            title: toDisplayName(safePayload.title) || "Novyn",
            body: toDisplayName(safePayload.body) || "You have a new message",
            previewEnabled: previewEnabled ? "1" : "0",
          } : {}),
          ...(isCallPush ? {
            // Bind every call alert to the account whose token received it.
            recipient: toDisplayName(user.username) || userKey,
            callStatus: toDisplayName(safePayload.callStatus) || "missed",
            callId: toDisplayName(safePayload.callId),
            isVideo: safePayload.isVideo ? "1" : "0",
            title: toDisplayName(safePayload.title) || "Incoming call",
            body: toDisplayName(safePayload.body) || "You have an incoming call",
          } : {}),
        };
        if (isEncryptedDirectMessage) {
          data.title = toDisplayName(safePayload.title) || "Novyn";
          data.ciphertext = safePayload.ciphertext;
          data.iv = safePayload.iv;
          data.senderPublicKey = safePayload.senderPublicKey;
          data.messageId = toDisplayName(safePayload.messageId);
          data.previewEnabled = previewEnabled ? "1" : "0";
        }
        const message = {
          token,
          ...(!isManagedDataPush && !isCallPush ? {
            notification: {
              title: toDisplayName(safePayload.title) || "Novyn",
              body: toDisplayName(safePayload.body) || "You have a new message",
            },
          } : {}),
          data,
          android: {
            priority: safePayload.silent ? "normal" : "high",
            ...(isCallPush ? { ttl: 45000 } : {}),
            ...(!isManagedDataPush && !isCallPush ? {
              notification: {
                channelId: notificationChannelId,
                tag: toDisplayName(safePayload.tag) || undefined,
                ...(safePayload.soundEnabled === false ? {} : { sound: "default" }),
              },
            } : {}),
          },
          apns: {
            headers: (isManagedDataPush || isCallPush) ? {
              "apns-push-type": "background",
              "apns-priority": "5",
              ...(isCallPush ? { "apns-expiration": String(Math.floor(Date.now() / 1000) + 45) } : {}),
            } : {
              "apns-push-type": "alert",
              "apns-priority": "10",
            },
            payload: {
              aps: (isManagedDataPush || isCallPush)
                ? { "content-available": 1 }
                : {
                    alert: {
                      title: toDisplayName(safePayload.title) || "Novyn",
                      body: toDisplayName(safePayload.body) || "You have a new message",
                    },
                    ...(safePayload.soundEnabled === false ? {} : { sound: "default" }),
                  },
            },
          },
        };
        try {
          await admin.messaging(firebaseAdmin).send(message);
        } catch (error) {
          const code = error?.code || error?.errorInfo?.code;
          if (code !== "messaging/mismatched-credential" || !firebaseLegacyAdmin) {
            throw error;
          }
          await admin.messaging(firebaseLegacyAdmin).send(message);
        }
      }
    } catch (err) {
      const code = err?.code || err?.errorInfo?.code;
      if (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token") {
        try {
          user.fcmToken = "";
          schedulePersist();
        } catch (_) {}
      } else {
        console.warn("Firebase push notification failed:", code || err?.message || err);
      }
    }
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
  if (message.riddle && typeof message.riddle === "object") {
    hydrated.riddle = {
      question: toDisplayName(message.riddle.question).slice(0, 160),
      hint: toDisplayName(message.riddle.hint).slice(0, 160),
      secret: toDisplayName(message.riddle.secret).slice(0, MAX_MESSAGE_LENGTH),
      answerSalt: toDisplayName(message.riddle.answerSalt),
      answerHash: toDisplayName(message.riddle.answerHash),
      maxTries: Number(message.riddle.maxTries) === 5 ? 5 : 3,
      attemptsBy: message.riddle.attemptsBy && typeof message.riddle.attemptsBy === "object" ? message.riddle.attemptsBy : {},
      unlockedBy: Array.isArray(message.riddle.unlockedBy) ? message.riddle.unlockedBy.map(normalizeName).filter(Boolean) : [],
    };
  }
  return hydrated;
}

function applyLoadedState(parsed) {
  conversationWallpapers.clear();
  for (const entry of parsed?.wallpapers || []) {
    if (Array.isArray(entry) && typeof entry[0] === 'string' && typeof entry[1] === 'string') {
      conversationWallpapers.set(entry[0], entry[1]);
    }
  }
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
    user.hiddenChats = new Set((entry.hiddenChats || []).map(normalizeName).filter(Boolean));
    user.isRegistered = Boolean(entry.isRegistered);
    user.isSuspended = entry.isSuspended === true;
    user.passwordSalt = toDisplayName(entry.passwordSalt);
    user.passwordHash = toDisplayName(entry.passwordHash);
    user.stealthModeEnabled = entry.stealthModeEnabled === true;
    user.twoFactorEnabled = Boolean(entry.twoFactorEnabled);
    user.twoFactorSecret = toDisplayName(entry.twoFactorSecret);
    user.twoFactorBackupCodes = Array.isArray(entry.twoFactorBackupCodes) ? entry.twoFactorBackupCodes : [];
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
    user.e2eeIdentityBackup = toDisplayName(entry.e2eeIdentityBackup);
    user.e2eeIdentityBackupPublicKey = toDisplayName(entry.e2eeIdentityBackupPublicKey);
    user.retentionDays = 0;
    user.callPrivacy = ["everyone", "friends", "nobody"].includes(entry.callPrivacy) ? entry.callPrivacy : "friends";
    user.messagePrivacy = ["everyone", "friends", "nobody"].includes(entry.messagePrivacy) ? entry.messagePrivacy : "friends";
    user.profilePhotoPrivacy = ["everyone", "friends", "nobody"].includes(entry.profilePhotoPrivacy) ? entry.profilePhotoPrivacy : "everyone";
    user.presencePrivacy = ["everyone", "friends", "nobody"].includes(entry.presencePrivacy) ? entry.presencePrivacy : "everyone";
    user.discoverPrivacy = ["everyone", "friends", "nobody"].includes(entry.discoverPrivacy) ? entry.discoverPrivacy : "everyone";
    user.readReceiptsEnabled = entry.readReceiptsEnabled !== false;
    user.typingIndicatorsEnabled = entry.typingIndicatorsEnabled !== false;
    user.groupInvitePrivacy = ["everyone", "friends", "nobody"].includes(entry.groupInvitePrivacy) ? entry.groupInvitePrivacy : "friends";
    user.friendRequestPrivacy = ["everyone", "mutuals", "nobody"].includes(entry.friendRequestPrivacy) ? entry.friendRequestPrivacy : "everyone";
    user.callLogs = Array.isArray(entry.callLogs) ? entry.callLogs.slice(0, 500) : [];
    user.pushSubs = Array.isArray(entry.pushSubs)
      ? entry.pushSubs.filter((sub) => sub && sub.endpoint && sub.keys)
      : [];
    user.fcmToken = toDisplayName(entry.fcmToken);
    user.notificationsEnabled = entry.notificationsEnabled !== false;
    user.messagePreviewEnabled = entry.messagePreviewEnabled !== false;
    user.hideNotificationContent = entry.hideNotificationContent === true;
    user.doNotDisturbEnabled = entry.doNotDisturbEnabled === true;
    user.favoriteChatIds = Array.isArray(entry.favoriteChatIds)
      ? entry.favoriteChatIds.map(normalizeName).filter(Boolean).slice(0, 250)
      : [];
    user.groupNotificationsEnabled = entry.groupNotificationsEnabled !== false;
    user.directMessagesEnabled = entry.directMessagesEnabled !== false;
    // Migrate users who only had the legacy groupNotificationsEnabled field.
    user.groupMessagesEnabled = typeof entry.groupMessagesEnabled === "boolean"
      ? entry.groupMessagesEnabled
      : user.groupNotificationsEnabled;
    user.mentionsRepliesEnabled = entry.mentionsRepliesEnabled !== false;
    user.friendRequestsEnabled = entry.friendRequestsEnabled !== false;
    user.friendRequestAcceptedEnabled = entry.friendRequestAcceptedEnabled !== false;
    user.groupInvitationsEnabled = entry.groupInvitationsEnabled !== false;
    user.voiceCallsEnabled = entry.voiceCallsEnabled !== false;
    user.videoCallsEnabled = entry.videoCallsEnabled !== false;
    user.missedCallsEnabled = entry.missedCallsEnabled !== false;
    user.gameInvitationsEnabled = entry.gameInvitationsEnabled !== false;
    user.gameTurnEnabled = entry.gameTurnEnabled !== false;
    user.gameResultsEnabled = entry.gameResultsEnabled !== false;
    user.quietHoursEnabled = entry.quietHoursEnabled === true;
    user.quietHoursStart = /^([01]\d|2[0-3]):[0-5]\d$/.test(entry.quietHoursStart || "") ? entry.quietHoursStart : "22:00";
    user.quietHoursEnd = /^([01]\d|2[0-3]):[0-5]\d$/.test(entry.quietHoursEnd || "") ? entry.quietHoursEnd : "07:00";
    user.quietHoursOffsetMinutes = Number.isFinite(Number(entry.quietHoursOffsetMinutes))
      ? Math.max(-840, Math.min(840, Number(entry.quietHoursOffsetMinutes))) : 0;
    user.notificationSoundEnabled = entry.notificationSoundEnabled !== false;
    user.notificationVibrationEnabled = entry.notificationVibrationEnabled !== false;

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

async function loadAuthState() {
  if (mongoAuthSessionsCollection) {
    const stored = await mongoAuthSessionsCollection.findOne(
      { _id: "runtime" },
      { projection: { state: 1 } }
    );
    if (stored?.state) {
      applyLoadedAuthRuntimeState(stored.state);
      return true;
    }
  }

  const loadedFromFile = await loadAuthStateFromFile();
  if (loadedFromFile && mongoAuthSessionsCollection) {
    await persistAuthStateNow();
    console.log("Migrated local auth session state into MongoDB.");
  }
  return loadedFromFile;
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
    hiddenChats: Array.isArray(doc?.hiddenChats) ? doc.hiddenChats : [],
    pushSubs: Array.isArray(doc?.pushSubs) ? doc.pushSubs : [],
    fcmToken: toDisplayName(doc?.fcmToken),
    notificationsEnabled: doc?.notificationsEnabled !== false,
    messagePreviewEnabled: doc?.messagePreviewEnabled !== false,
    hideNotificationContent: doc?.hideNotificationContent === true,
    doNotDisturbEnabled: doc?.doNotDisturbEnabled === true,
    favoriteChatIds: Array.isArray(doc?.favoriteChatIds) ? doc.favoriteChatIds : [],
    groupNotificationsEnabled: doc?.groupNotificationsEnabled !== false,
    directMessagesEnabled: doc?.directMessagesEnabled !== false,
    groupMessagesEnabled: typeof doc?.groupMessagesEnabled === "boolean"
      ? doc.groupMessagesEnabled
      : doc?.groupNotificationsEnabled !== false,
    mentionsRepliesEnabled: doc?.mentionsRepliesEnabled !== false,
    friendRequestsEnabled: doc?.friendRequestsEnabled !== false,
    friendRequestAcceptedEnabled: doc?.friendRequestAcceptedEnabled !== false,
    groupInvitationsEnabled: doc?.groupInvitationsEnabled !== false,
    voiceCallsEnabled: doc?.voiceCallsEnabled !== false,
    videoCallsEnabled: doc?.videoCallsEnabled !== false,
    missedCallsEnabled: doc?.missedCallsEnabled !== false,
    gameInvitationsEnabled: doc?.gameInvitationsEnabled !== false,
    gameTurnEnabled: doc?.gameTurnEnabled !== false,
    gameResultsEnabled: doc?.gameResultsEnabled !== false,
    quietHoursEnabled: doc?.quietHoursEnabled === true,
    quietHoursStart: doc?.quietHoursStart || "22:00",
    quietHoursEnd: doc?.quietHoursEnd || "07:00",
    quietHoursOffsetMinutes: Number.isFinite(Number(doc?.quietHoursOffsetMinutes)) ? Number(doc.quietHoursOffsetMinutes) : 0,
    notificationSoundEnabled: doc?.notificationSoundEnabled !== false,
    notificationVibrationEnabled: doc?.notificationVibrationEnabled !== false,
    isRegistered: Boolean(doc?.isRegistered),
    isSuspended: doc?.isSuspended === true,
    passwordSalt: toDisplayName(doc?.passwordSalt),
    passwordHash: toDisplayName(doc?.passwordHash),
    stealthModeEnabled: doc?.stealthModeEnabled === true,
    twoFactorEnabled: Boolean(doc?.twoFactorEnabled),
    twoFactorSecret: toDisplayName(doc?.twoFactorSecret),
    twoFactorBackupCodes: Array.isArray(doc?.twoFactorBackupCodes) ? doc.twoFactorBackupCodes : [],
    avatarId: toDisplayName(doc?.avatarId),
    age: toDisplayName(doc?.age),
    gender: toDisplayName(doc?.gender),
    displayName: toDisplayName(doc?.displayName),
    bio: toDisplayName(doc?.bio),
    createdAt: toDisplayName(doc?.createdAt),
    lastSeenAt: toDisplayName(doc?.lastSeenAt),
    presenceMode: normalizePresenceMode(doc?.presenceMode),
    publicKey: toDisplayName(doc?.publicKey),
    e2eeIdentityBackup: toDisplayName(doc?.e2eeIdentityBackup),
    e2eeIdentityBackupPublicKey: toDisplayName(doc?.e2eeIdentityBackupPublicKey),
    callsEnabled: doc?.callsEnabled !== false,
    callPrivacy: doc?.callPrivacy || "friends", messagePrivacy: doc?.messagePrivacy || "friends",
    profilePhotoPrivacy: doc?.profilePhotoPrivacy || "everyone", presencePrivacy: doc?.presencePrivacy || "everyone", discoverPrivacy: doc?.discoverPrivacy || "everyone",
    readReceiptsEnabled: doc?.readReceiptsEnabled !== false, typingIndicatorsEnabled: doc?.typingIndicatorsEnabled !== false,
    groupInvitePrivacy: doc?.groupInvitePrivacy || "friends", friendRequestPrivacy: doc?.friendRequestPrivacy || "everyone",
    callLogs: Array.isArray(doc?.callLogs) ? doc.callLogs.slice(0, 500) : [],
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
    senderPublicKey: normalizePushPublicKey(doc?.senderPublicKey) || undefined,
    isEncrypted: Boolean(doc?.isEncrypted),
    seenBy: Array.isArray(doc?.seenBy) ? doc.seenBy : undefined,
    riddle: doc?.riddle || undefined,
  };
}

async function loadStateFromMongoCollections() {
  if (!hasMongoStorage()) return false;

  // A snapshot write spans multiple collections. Load one complete snapshot,
  // rather than accidentally mixing old/new documents after a crash.
  const manifest = mongoLegacyCollection
    ? await mongoLegacyCollection.findOne({ _id: "snapshot_manifest" })
    : null;
  let snapshotId = toDisplayName(manifest?.snapshotId);
  if (!snapshotId) {
    // Compatibility path for snapshots written before the manifest was introduced.
    const latestCandidates = await Promise.all([
      mongoUsersCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
      mongoConversationsCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
      mongoMessagesCollection.findOne({}, { projection: { snapshotId: 1, updatedAt: 1 }, sort: { updatedAt: -1 } }),
    ]);
    const latest = latestCandidates
      .filter(Boolean)
      .sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")))[0];
    snapshotId = toDisplayName(latest?.snapshotId);
    if (snapshotId) {
      const [staleUsers, staleConversations, staleMessages] = await Promise.all([
        mongoUsersCollection.countDocuments({ snapshotId: { $ne: snapshotId } }),
        mongoConversationsCollection.countDocuments({ snapshotId: { $ne: snapshotId } }),
        mongoMessagesCollection.countDocuments({ snapshotId: { $ne: snapshotId } }),
      ]);
      if (staleUsers || staleConversations || staleMessages) {
        throw new Error("Legacy MongoDB snapshot is mixed or incomplete; refusing to overwrite existing chat data.");
      }
    }
  }
  const snapshotFilter = snapshotId ? { snapshotId } : {};
  if (manifest && snapshotId) {
    const [actualUsers, actualConversations, actualMessages] = await Promise.all([
      mongoUsersCollection.countDocuments(snapshotFilter),
      mongoConversationsCollection.countDocuments(snapshotFilter),
      mongoMessagesCollection.countDocuments(snapshotFilter),
    ]);
    if (
      actualUsers !== Number(manifest.userCount) ||
      actualConversations !== Number(manifest.conversationCount) ||
      actualMessages !== Number(manifest.messageCount)
    ) {
      throw new Error(
        `MongoDB snapshot ${snapshotId} is incomplete; refusing to load or overwrite chat data.`
      );
    }
  }

  const [userDocs, conversationDocs, messageDocs, legacyDoc] = await Promise.all([
    mongoUsersCollection.find(snapshotFilter, { projection: { snapshotId: 0, updatedAt: 0 } }).toArray(),
    mongoConversationsCollection.find(snapshotFilter, { projection: { _id: 1, messageCount: 1 } }).toArray(),
    mongoMessagesCollection
      .find(snapshotFilter, { projection: { _id: 0, snapshotId: 0, updatedAt: 0 } })
      .sort({ conversationKey: 1, timestamp: 1, messageId: 1 })
      .toArray(),
    mongoLegacyCollection
      ? mongoLegacyCollection.findOne(
          { _id: "main" },
          { projection: { groups: 1, scheduledMessages: 1, wallpapers: 1 } }
        )
      : null,
  ]);

  if (!userDocs.length && !conversationDocs.length && !messageDocs.length) return false;
  const expectedMessageCount = conversationDocs.reduce(
    (total, conversation) => total + Math.max(0, Number(conversation.messageCount) || 0),
    0
  );
  if (expectedMessageCount !== messageDocs.length) {
    throw new Error(
      `MongoDB snapshot ${snapshotId || "(legacy)"} has ${messageDocs.length} messages but conversations expect ${expectedMessageCount}; refusing to overwrite existing chat data.`
    );
  }

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
    wallpapers: Array.isArray(legacyDoc?.wallpapers) ? legacyDoc.wallpapers : [],
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

    mongoLegacyCollection = mongoStorage.getCollection("legacy");
    mongoUsersCollection = mongoStorage.getCollection("users");
    mongoConversationsCollection = mongoStorage.getCollection("conversations");
    mongoMessagesCollection = mongoStorage.getCollection("messages");
    mongoAuthSessionsCollection = mongoStorage.getCollection("auth_sessions");
    mongoMediaCollection = mongoStorage.getCollection("media");
    mongoGameHistoryCollection = mongoStorage.getCollection("game_history");
    if (mongoGameHistoryCollection?.createIndex) {
      try {
        await mongoGameHistoryCollection.createIndex(
          { userKey: 1, playedAt: 1 },
          { name: "game_history_user_played_at" }
        );
      } catch (error) {
        console.warn("[NovynGames] Leaderboard index setup deferred:", error?.message || error);
      }
    }
    if (mongoMediaCollection) {
      const storedMedia = await mongoMediaCollection.find({}).toArray();
      for (const item of storedMedia) {
        if (item?._id && item?.ownerKey) {
          mediaMetadataCache.set(String(item._id), { ownerKey: item.ownerKey, remote: item.remote || null });
        }
      }
      // Migrate legacy metadata files when an earlier deployment used a persistent uploads volume.
      const legacyFiles = await fsp.readdir(uploadsDir).catch(() => []);
      for (const name of legacyFiles.filter((entry) => entry.endsWith(".metadata.json"))) {
        const filename = name.slice(0, -".metadata.json".length);
        if (mediaMetadataCache.has(filename)) continue;
        try {
          const legacy = JSON.parse(await fsp.readFile(path.join(uploadsDir, name), "utf8"));
          if (!legacy?.ownerKey) continue;
          await mongoMediaCollection.updateOne(
            { _id: filename },
            { $setOnInsert: { ownerKey: legacy.ownerKey, remote: legacy.remote || null, updatedAt: new Date() } },
            { upsert: true }
          );
          mediaMetadataCache.set(filename, { ownerKey: legacy.ownerKey, remote: legacy.remote || null });
        } catch (error) {
          console.warn("[NovynMedia] Legacy media metadata migration skipped:", name, error?.message || error);
        }
      }
    }

    console.log(`Connected to MongoDB database: ${MONGODB_DB}`);
  } catch (err) {
    mongoStorage = null;
    mongoLegacyCollection = null;
    mongoUsersCollection = null;
    mongoConversationsCollection = null;
    mongoMessagesCollection = null;
    mongoAuthSessionsCollection = null;
    mongoMediaCollection = null;
    mongoGameHistoryCollection = null;
    mediaMetadataCache.clear();
    if (process.env.NODE_ENV === 'production') throw err;
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
      if (process.env.NODE_ENV === 'production') throw err;
      console.error("Failed to load chat state from MongoDB collections, trying local file:", err);
    }
  }

  if (!loaded) {
    loaded = await loadStateFromFile();
  }

  if (loaded) {
    const scrubbed = scrubEncryptedMessagePlaintext();
    if (scrubbed) {
      await persistNow();
      console.log(`Removed plaintext from ${scrubbed} encrypted message field(s).`);
    }
  }

  await loadAuthState();
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

function buildGoogleUsernameSuggestion(seed) {
  let base = normalizeName(seed).replace(/[^a-z0-9_]/g, "").slice(0, 24);
  if (base.length < 3) base = `${base}user`.slice(0, 24);
  if (!base) base = "novynuser";
  if (!isUsernameTaken(base)) return base;
  return buildUsernameSuggestions(base, 1)[0] || `novyn${Date.now().toString().slice(-6)}`;
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
  const normalizedName = normalizeName(otherKey);
  if (normalizedName && user.mutedUsers.has(normalizedName)) return true;
  const groupId = normalizeGroupId(otherKey);
  return Boolean(groupId && user.mutedUsers.has(groupId));
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
  return mode === "invisible" ? "offline" : mode;
}

// Keep a user's explicitly selected Busy state visible while disconnected,
// without falsely marking them online. This separates preference from socket
// reachability so friends do not see Busy turn into Offline in the background.
function getDisplayPresence(userKey) {
  const key = normalizeName(userKey);
  const user = users.get(key);
  if (!user) return "offline";
  const mode = normalizePresenceMode(user.presenceMode);
  if (mode === "invisible") return "offline";
  if (mode === "busy" && !isSocketOnline(key)) return "busy";
  return getEffectivePresence(key);
}

function isUserAvailable(userKey) {
  return getEffectivePresence(userKey) !== "offline";
}

function getVisibleLastSeen(user) {
  return normalizePresenceMode(user?.presenceMode) === "invisible" || user?.presencePrivacy === "nobody" ? "" : user?.lastSeenAt || "";
}

function privacyAllows(owner, viewerKey, privacyKey) {
  const viewer = normalizeName(viewerKey);
  if (!owner || !viewer) return false;
  if (normalizeName(owner.username) === viewer) return true;
  const setting = owner[privacyKey] || "everyone";
  if (setting === "nobody") return false;
  if (setting === "friends") return owner.friends instanceof Set && owner.friends.has(viewer);
  return true;
}

function buildGroupInfoForViewer(group, viewerKey) {
  const viewer = normalizeName(viewerKey);
  if (!group || !viewer || !isGroupMember(group, viewer)) return null;
  const members = [];
  for (const memberKey of group.members || []) {
    const user = users.get(memberKey);
    const username = user?.username || memberKey;
    const role = getGroupMemberRole(group, memberKey);
    const presenceAllowed = privacyAllows(user, viewer, "presencePrivacy");
    const photoAllowed = privacyAllows(user, viewer, "profilePhotoPrivacy");
    const presence = presenceAllowed ? getDisplayPresence(memberKey) : "offline";
    members.push({
      username,
      displayName: user?.displayName || "",
      avatarId: photoAllowed ? (user?.avatarId || "") : "",
      online: isSocketOnline(memberKey) && presence !== "offline",
      presence,
      lastSeenAt: presenceAllowed ? getVisibleLastSeen(user) : "",
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
    from: toDisplayName(rawReply.from || rawReply.sender),
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
  conversations,
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
  if (params.riddle) message.riddle = params.riddle;
  if (params.ciphertext) message.ciphertext = toDisplayName(params.ciphertext);
  if (params.iv) message.iv = toDisplayName(params.iv);
  if (params.isEncrypted) message.isEncrypted = Boolean(params.isEncrypted);
  if (params.senderPublicKey) message.senderPublicKey = normalizePushPublicKey(params.senderPublicKey);
  const temp = toDisplayName(params.clientTempId).slice(0, 64);
  if (temp) message.clientTempId = temp;
  return message;
}

function riddleForViewer(message, viewerKey) {
  if (!message?.riddle) return message;
  const key = normalizeName(viewerKey);
  const isSender = key === normalizeName(message.fromKey);
  const unlocked = isSender || Boolean(message.riddle.unlockedBy?.includes(key));
  const used = Math.max(0, Number(message.riddle.attemptsBy?.[key]) || 0);
  return { ...message, riddle: {
    question: message.riddle.question,
    hint: message.riddle.hint || "",
    maxTries: message.riddle.maxTries,
    triesLeft: Math.max(0, message.riddle.maxTries - used),
    unlocked,
    secret: unlocked ? message.riddle.secret : "",
  } };
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
  const isSelf = fromKey === toKey;
  const canReceiveMessage = isSelf || friend?.messagePrivacy === "everyone" || (friend?.messagePrivacy === "friends" && me?.friends?.has(toKey));
  if (!me || !friend || (!isSelf && !canReceiveMessage)) {
    return { ok: false, code: "privacy", message: "This user only accepts messages from friends." };
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
    recipientSocket.data?.appForeground !== false &&
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
    seenAt: recipientViewing && friend.readReceiptsEnabled !== false ? timestamp : null,
    attachment: params.attachment,
    replyTo: params.replyTo,
    poll: params.poll,
    game: params.game,
    riddle: params.riddle,
    ciphertext: params.ciphertext,
    iv: params.iv,
    isEncrypted: params.isEncrypted,
    senderPublicKey: params.senderPublicKey,
    clientTempId,
  });

  const conversation = conversations.get(conversationKey) || [];
  conversation.push(message);
  conversations.set(conversationKey, conversation);
  runRetentionMaintenance();

  if (!isSelf) {
    recipientViewing ? setUnreadCount(friend, fromKey, 0) : incrementUnread(friend, fromKey);
  }

  const senderSocketId = onlineUsers.get(fromKey);
  if (senderSocketId) {
    io.to(senderSocketId).emit("private_message", riddleForViewer(message, fromKey));
  }
  if (recipientSocketId && recipientSocketId !== senderSocketId) {
    io.to(recipientSocketId).emit("private_message", riddleForViewer(message, toKey));
  }
  if (!isSelf && !recipientViewing && !isMutedBy(friend, fromKey)) {
    const bodyText = params.isEncrypted === true
      ? "You have a new message"
      : formatPushBody(text);
    const isGameChallenge = Boolean(message.game);
    const mentionOrReply = Boolean(params.replyTo) ||
      (!params.isEncrypted && String(text).toLowerCase().includes("@" + String(friend.username || toKey).toLowerCase()));
    void sendPushToUser(toKey, {
      type: isGameChallenge ? "game_invitation" : "message",
      ...(isGameChallenge ? { gameId: message.game.id, gameType: message.game.gameType } : {}),
      mentionOrReply,
      title: `New message from ${me.username}`,
      body: bodyText,
      ...(params.isEncrypted === true ? {
        ciphertext: params.ciphertext,
        iv: params.iv,
        // Multi-device accounts can have different private ECDH identities.
        // Use the sender device's key for this message, not the last account
        // key registered on the server.
        senderPublicKey: normalizePushPublicKey(params.senderPublicKey) || normalizePushPublicKey(me.publicKey),
        messageId: message.id || message.messageId || "",
      } : {}),
      tag: `msg-${fromKey}`,
      chat: me.username,
      url: `/?source=push&chat=${encodeURIComponent(me.username)}`,
      icon: "/icons/icon-192.png",
      badge: "/icons/novyn-badge.svg",
    });
  }

  emitMessageStatus(message);
  emitFriendList(fromKey);
  if (!isSelf) emitFriendList(toKey);
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
    riddle: params.riddle,
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
      memberSocket.data?.appForeground !== false &&
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
      io.to(memberSocketId).emit("private_message", riddleForViewer(message, memberKey));
    }
    if (memberKey !== fromKey && !viewingSameGroup &&
        !isMutedBy(users.get(memberKey), group.id)) {
      const bodyText = formatPushBody(text);
      const isGameChallenge = Boolean(message.game);
      const recipient = users.get(memberKey);
      const mentionOrReply = Boolean(params.replyTo) ||
        String(text).toLowerCase().includes("@" + String(recipient?.username || memberKey).toLowerCase());
      void sendPushToUser(memberKey, {
        type: isGameChallenge ? "game_invitation" : "message",
        ...(isGameChallenge ? { gameId: message.game.id, gameType: message.game.gameType } : {}),
        mentionOrReply,
        group: true,
        title: `New message in ${group.name}`,
        body: `${me.username}: ${bodyText}`,
        tag: `grp-${group.id}`,
        groupId: group.id,
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

function setCallPair(userKey, peerKey, status, callId, metadata = {}) {
  const previous = activeCalls.get(userKey) || {};
  const details = { ...previous, ...metadata };
  activeCalls.set(userKey, { ...details, peerKey, status, callId });
  activeCalls.set(peerKey, { ...details, peerKey: userKey, status, callId });
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

  // Keep an in-memory rollback point because a username touches several related
  // indexes. A failure must never leave only part of the account renamed.
  const snapshot = {
    users: structuredClone(Array.from(users.entries())),
    conversations: structuredClone(Array.from(conversations.entries())),
    groups: structuredClone(Array.from(groups.entries())),
    scheduledMessages: structuredClone(Array.from(scheduledMessages.entries())),
    onlineUsers: structuredClone(Array.from(onlineUsers.entries())),
    refreshSessions: structuredClone(Array.from(refreshSessions.entries())),
    refreshByUser: structuredClone(Array.from(refreshByUser.entries())),
    authUserAliases: structuredClone(Array.from(authUserAliases.entries())),
  };

  const restoreMap = (target, entries) => {
    target.clear();
    for (const [key, value] of entries) target.set(key, value);
  };
  const rollback = () => {
    restoreMap(users, snapshot.users);
    restoreMap(conversations, snapshot.conversations);
    restoreMap(groups, snapshot.groups);
    restoreMap(scheduledMessages, snapshot.scheduledMessages);
    restoreMap(onlineUsers, snapshot.onlineUsers);
    restoreMap(refreshSessions, snapshot.refreshSessions);
    restoreMap(refreshByUser, snapshot.refreshByUser);
    restoreMap(authUserAliases, snapshot.authUserAliases);
  };

  try {

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

    // Group conversation keys do not contain usernames, so message references
    // must be migrated for every conversation rather than direct chats only.
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
    rollback,
  };
  } catch (error) {
    rollback();
    throw error;
  }
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

function runRetentionMaintenance() {
  pruneExpiredAuthState();
  pruneHttpRateLimits(httpRateLimits);
  pruneExpiredPasswordResetTokens();
  pruneExpiredEmailChangeTokens();
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

  const message = [...messages].reverse().find((candidate) => {
    const game = candidate?.game;
    return !(game && game.state === "in_progress" && game.lastMoveBy == null);
  });
  if (!message) {
    return {
      lastMessage: "",
      lastTimestamp: null,
      lastFrom: "",
    };
  }
  const text = message.deletedAt ? DELETED_MESSAGE_TEXT : toDisplayName(message.text);
  const compact = text.length > 52 ? `${text.slice(0, 49)}...` : text;

  return {
    lastMessage: compact,
    lastMessageData: {
      id: message.id,
      from: message.from,
      to: message.to,
      text: message.isEncrypted && !message.deletedAt ? ENCRYPTED_MESSAGE_PLACEHOLDER : compact,
      timestamp: message.timestamp,
      isEncrypted: Boolean(message.isEncrypted && !message.deletedAt),
      ciphertext: !message.deletedAt ? message.ciphertext : undefined,
      iv: !message.deletedAt ? message.iv : undefined,
      senderPublicKey: !message.deletedAt ? message.senderPublicKey : undefined,
      attachment: !message.deletedAt ? message.attachment : undefined,
      isVoice: !message.deletedAt && Boolean(message.isVoice || message.attachment?.kind === 'audio'),
    },
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

  const knownDirectKeys = new Set(validFriendKeys);
  for (const [otherKey, other] of users.entries()) {
    if (otherKey === userKey || !other?.isRegistered || knownDirectKeys.has(otherKey)) continue;
    if (!conversations.get(getConversationKey(userKey, otherKey))?.length) continue;
    if (usersAreBlocked(userKey, otherKey)) continue;
    knownDirectKeys.add(otherKey);
  }
  const directList = Array.from(knownDirectKeys).map((friendKey) => {
    const friend = users.get(friendKey);
    const summary = getConversationSummary(userKey, friendKey);
    const blocked = usersAreBlocked(userKey, friendKey);
    const presenceAllowed = privacyAllows(friend, userKey, "presencePrivacy");
    const photoAllowed = privacyAllows(friend, userKey, "profilePhotoPrivacy");
    const presence = blocked || !presenceAllowed ? "offline" : getDisplayPresence(friendKey);
    const isOnline = !blocked && presenceAllowed &&
      isSocketOnline(friendKey) && presence !== "offline";

    return {
      username: friend?.username || friendKey,
      kind: "friend",
      isFriend: user.friends.has(friendKey),
      groupId: "",
      online: isOnline,
      presence,
      unreadCount: getUnreadCount(user, friendKey),
      lastMessage: summary.lastMessage,
      lastMessageData: summary.lastMessageData,
      lastTimestamp: summary.lastTimestamp,
      lastFrom: summary.lastFrom,
      avatarId: photoAllowed ? (friend?.avatarId || "") : "",
      displayName: friend?.displayName || "",
      bio: friend?.bio || "",
      lastSeenAt: blocked || !presenceAllowed ? null : getVisibleLastSeen(friend),
      publicKey: friend?.publicKey || "",
      muted: isMutedBy(user, friendKey),
      memberCount: 2,
      onlineCount: isOnline ? 1 : 0,
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
        const member = users.get(memberKey);
        if (privacyAllows(member, userKey, "presencePrivacy") && isUserAvailable(memberKey)) onlineCount += 1;
      }
      return {
        username: group.id,
        kind: "group",
        groupId: group.id,
        online: onlineCount > 0,
        unreadCount: getUnreadCount(user, group.id),
        lastMessage: summary.lastMessage,
        lastMessageData: summary.lastMessageData,
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

function buildDiscoverOnlineList(forUser, limit = 100) {
  const userKey = normalizeName(forUser);
  const me = users.get(userKey);
  if (!me) return [];

  // Exclude people with either direction of pending request. Incoming
  // requests are in me.requests; outgoing requests live on the target user.
  const outgoingRequests = [];
  for (const [candidateKey, candidate] of users.entries()) {
    if (candidate?.requests?.has(userKey)) outgoingRequests.push(candidateKey);
  }
  const exclude = new Set([userKey, ...me.friends, ...me.requests, ...outgoingRequests]);
  const list = [];

  for (const onlineKey of onlineUsers.keys()) {
    if (exclude.has(onlineKey)) continue;
    const user = users.get(onlineKey);
    if (!user || !user.isRegistered) continue;
    if (isBlockedBy(me, onlineKey) || isBlockedBy(user, userKey)) continue;
    if (!privacyAllows(user, userKey, "discoverPrivacy")) continue;
    const presenceAllowed = privacyAllows(user, userKey, "presencePrivacy");
    if (!presenceAllowed) continue;
    const presence = getEffectivePresence(onlineKey);
    if (presence === "offline") continue;
    list.push({
      username: user.username || onlineKey,
      displayName: user.displayName || "",
      avatarId: privacyAllows(user, userKey, "profilePhotoPrivacy") ? (user.avatarId || "") : "",
      bio: user.bio || "",
      lastSeenAt: getVisibleLastSeen(user),
      online: true,
      presence,
      canMessage: user.messagePrivacy === "everyone",
    });
  }

  list.sort((a, b) => a.username.localeCompare(b.username));
  return list.slice(0, limit);
}

function emitDiscoverOnlineToAll(limit = 100) {
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

  const user = users.get(userKey);
  io.to(socketId).emit("friend_list_updated", {
    friends: buildFriendList(userKey),
    hiddenChats: Array.from(user?.hiddenChats || []),
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

    const blocked = usersAreBlocked(userKey, friendKey);
    const presenceAllowed = privacyAllows(user, friendKey, "presencePrivacy");
    io.to(friendSocket).emit("user_status", {
      username: user.username,
      online: !blocked && presenceAllowed && online,
      presence: blocked || !presenceAllowed ? "offline" : getDisplayPresence(userKey),
      lastSeenAt: blocked || !presenceAllowed ? null : getVisibleLastSeen(user) || null,
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
    const canSendReceipts = viewer.readReceiptsEnabled !== false;
    const touchedMessages = [];
    for (const message of conversation) {
      if (!message || normalizeName(message.fromKey) === viewerKey) continue;
      if (!canSendReceipts) continue;
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
  const canSendReceipts = viewer?.readReceiptsEnabled !== false;

  for (const message of conversation) {
    if (message.toKey === viewerKey && message.fromKey === friendKey && !message.seenAt) {
      const seenAt = nowIso();
      if (!message.deliveredAt) {
        message.deliveredAt = seenAt;
      }
      if (canSendReceipts) message.seenAt = seenAt;
      statusChanged = true;
      if (canSendReceipts) emitMessageStatus(message);
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

async function setUserSuspended(rawUserKey, suspended, { disconnectSockets = true } = {}) {
  const userKey = normalizeName(rawUserKey);
  const user = users.get(userKey);
  if (!user?.isRegistered) throw new Error("User not found.");

  if (user.isSuspended !== suspended) {
    const previousSuspended = user.isSuspended === true;
    user.isSuspended = suspended;
    try {
      await flushStatePersistNow();
    } catch (error) {
      user.isSuspended = previousSuspended;
      throw error;
    }
  }

  if (!suspended) return;

  revokeAllRefreshSessionsForUser(userKey);
  const peerKey = clearCallPair(userKey);
  if (peerKey && onlineUsers.has(peerKey)) {
    io.to(onlineUsers.get(peerKey)).emit("call_ended", {
      by: userKey,
      reason: "ended",
    });
  }
  if (disconnectSockets) {
    for (const socket of io.sockets.sockets.values()) {
      if (normalizeName(socket.data?.userKey) === userKey) socket.disconnect(true);
    }
    onlineUsers.delete(userKey);
    emitStatusToFriends(userKey);
    emitDiscoverOnlineToAll();
  }
  await flushAuthStatePersistNow();
}

async function removeUserMedia(rawUserKey) {
  const userKey = normalizeName(rawUserKey);
  let filenames;
  try {
    filenames = await fsp.readdir(uploadsDir);
  } catch (error) {
    if (error?.code === "ENOENT") return;
    throw error;
  }

  for (const metadataFilename of filenames.filter((name) => name.endsWith(".metadata.json"))) {
    const filename = metadataFilename.slice(0, -".metadata.json".length);
    const metadata = mediaMetadata(filename);
    if (resolveCurrentUserKey(normalizeName(metadata?.ownerKey)) !== userKey) continue;

    if (metadata.remote?.publicId) {
      if (!cloudinary?.uploader?.destroy) {
        throw new Error("Cloud media storage is unavailable.");
      }
      const result = await cloudinary.uploader.destroy(metadata.remote.publicId, {
        resource_type: metadata.remote.resourceType || "image",
        type: "authenticated",
        invalidate: true,
      });
      if (result?.result === "error") throw new Error("Cloud media could not be removed.");
    }

    for (const ownedFilename of [filename, metadataFilename]) {
      try {
        await fsp.unlink(path.join(uploadsDir, ownedFilename));
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
    }
  }
}

async function removeUserAccount(rawUserKey, { disconnectSockets = true } = {}) {
  const userKey = normalizeName(rawUserKey);
  const user = users.get(userKey);
  if (!user?.isRegistered) throw new Error("User not found.");

  await setUserSuspended(userKey, true, { disconnectSockets });

  if (user.googleUid) {
    if (!firebaseAdmin) {
      const error = new Error("Firebase Admin authentication is unavailable.");
      error.publicMessage = "The account remains suspended because its linked Google identity could not be removed.";
      throw error;
    }
    for (const firebaseApp of [firebaseAdmin, firebaseLegacyAdmin].filter(Boolean)) {
      try {
        await admin.auth(firebaseApp).deleteUser(user.googleUid);
      } catch (error) {
        if (error?.code !== "auth/user-not-found") {
          const deletionError = new Error("Could not delete the linked Firebase identity.");
          deletionError.publicMessage = "The account remains suspended because its linked Google identity could not be removed.";
          throw deletionError;
        }
      }
    }
  }

  try {
    await removeUserMedia(userKey);
  } catch (error) {
    const cleanupError = new Error("Could not remove the account's uploaded media.");
    cleanupError.cause = error;
    cleanupError.publicMessage = "The account remains suspended because its uploaded media could not be fully removed.";
    throw cleanupError;
  }

  const callPeerKey = clearCallPair(userKey);
  if (callPeerKey && onlineUsers.has(callPeerKey)) {
    io.to(onlineUsers.get(callPeerKey)).emit("call_ended", { by: userKey, reason: "ended" });
  }

  const impacted = new Set();
  for (const [otherKey, other] of users) {
    if (!other || otherKey === userKey) continue;
    let touched = false;
    for (const set of [other.friends, other.requests, other.blockedUsers, other.mutedUsers]) {
      if (set instanceof Set && set.delete(userKey)) touched = true;
    }
    if (other.unread instanceof Map && other.unread.delete(userKey)) touched = true;
    if (touched) impacted.add(otherKey);
  }

  for (const [groupId, group] of groups) {
    if (!(group.members instanceof Set) || !group.members.delete(userKey)) continue;
    if (group.admins instanceof Set) group.admins.delete(userKey);
    if (group.ownerKey === userKey) {
      const nextOwner = [...(group.admins || [])][0] || [...group.members][0];
      if (!nextOwner) {
        groups.delete(groupId);
        const groupConversationKey = getGroupConversationKey(groupId);
        conversations.delete(groupConversationKey);
        conversationWallpapers.delete(groupConversationKey);
        continue;
      }
      group.ownerKey = nextOwner;
      if (group.admins instanceof Set) group.admins.add(nextOwner);
    }
    group.updatedAt = nowIso();
    for (const memberKey of group.members) {
      impacted.add(memberKey);
      emitGroupInfoToMember(memberKey, group);
    }
  }

  for (const [conversationKey, history] of conversations) {
    if (!isGroupConversationKey(conversationKey) &&
        conversationKey.split("::").includes(userKey)) {
      conversations.delete(conversationKey);
      conversationWallpapers.delete(conversationKey);
      continue;
    }
    if (isGroupConversationKey(conversationKey) && Array.isArray(history)) {
      const retained = history.filter((message) =>
        normalizeName(message?.fromKey || message?.from || "") !== userKey
      );
      if (retained.length !== history.length) conversations.set(conversationKey, retained);
    }
  }

  for (const [scheduledId, scheduled] of scheduledMessages) {
    if (normalizeName(scheduled.fromKey) !== userKey && normalizeName(scheduled.toKey) !== userKey) continue;
    const timer = scheduledMessageTimers.get(scheduledId);
    if (timer) clearTimeout(timer);
    scheduledMessageTimers.delete(scheduledId);
    scheduledMessages.delete(scheduledId);
  }

  revokeAllRefreshSessionsForUser(userKey);
  for (const [oldKey, alias] of authUserAliases) {
    if (oldKey === userKey || normalizeName(alias?.newKey) === userKey) authUserAliases.delete(oldKey);
  }
  passwordResetTokens.forEach((entry, id) => {
    if (normalizeName(entry?.userKey) === userKey) passwordResetTokens.delete(id);
  });
  emailChangeTokens.forEach((entry, id) => {
    if (normalizeName(entry?.userKey) === userKey) emailChangeTokens.delete(id);
  });
  passwordResetByUser.delete(userKey);
  emailChangeByUser.delete(userKey);
  onlineUsers.delete(userKey);
  users.delete(userKey);

  try {
    await flushStatePersistNow();
    await flushAuthStatePersistNow();
  } catch (error) {
    error.publicMessage = "Account cleanup could not be fully saved. Contact support before retrying.";
    throw error;
  }

  impacted.forEach((key) => {
    emitFriendList(key);
    emitRequests(key);
  });
  emitDiscoverOnlineToAll();
  if (disconnectSockets) {
    for (const socket of io.sockets.sockets.values()) {
      if (normalizeName(socket.data?.userKey) === userKey) socket.disconnect(true);
    }
  }
  return true;
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
    callsEnabled: user.callsEnabled !== false,
        callPrivacy: user.callPrivacy || "friends", messagePrivacy: user.messagePrivacy || "friends",
    profilePhotoPrivacy: user.profilePhotoPrivacy || "everyone", presencePrivacy: user.presencePrivacy || "everyone", discoverPrivacy: user.discoverPrivacy || "everyone",
    readReceiptsEnabled: user.readReceiptsEnabled !== false, typingIndicatorsEnabled: user.typingIndicatorsEnabled !== false,
    groupInvitePrivacy: user.groupInvitePrivacy || "friends", friendRequestPrivacy: user.friendRequestPrivacy || "everyone",
    friends: buildFriendList(userKey),
    hiddenChats: Array.from(user.hiddenChats || []),
    requests: Array.from(user.requests).map((requesterKey) => {
      const requester = users.get(requesterKey);
      return requester?.username || requesterKey;
    }),
    sentRequests: Array.from(users.values())
      .filter((candidate) => candidate.requests.has(userKey))
      .map((candidate) => candidate.username),
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
  socket.data.passwordHashSnapshot = user.passwordHash;
  socket.data.activeChatWith = null;
  socket.data.activeChatKind = "friend";

  const previousSocketId = onlineUsers.get(userKey);
  onlineUsers.set(userKey, socket.id);

  // Rejoining users resume their human turns in any active Raja Mantri room.
  for (const entry of rajaMantriSessions.values()) {
    const connection = setRajaMantriPlayerConnected(entry.game, userKey, true);
    if (connection.ok) {
      scheduleRajaMantriPhaseTimer(entry);
      emitRajaMantriGameUpdate(entry.game);
    }
  }

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
  const now = Date.now();
  const userKey = normalizeName(socket.data?.userKey || "");
  const globalKey = userKey ? `${userKey}:${key}` : `anonymous:${socket.handshake?.address || "unknown"}:${key}`;
  const globalStore = runtimeState.socketRateLimits;

  // Prune expired global buckets opportunistically so long-lived servers do
  // not retain one Map entry forever for every user/action combination.
  for (const [storedKey, storedBucket] of globalStore) {
    if (!storedBucket || now >= storedBucket.expiresAt) {
      globalStore.delete(storedKey);
    }
  }

  // Enforce limits across all simultaneous sockets for the same account.
  // Otherwise a client could bypass a per-socket limit by opening connections.
  const existing = globalStore.get(globalKey);
  if (!existing || now >= existing.expiresAt) {
    globalStore.set(globalKey, { count: 1, windowStartedAt: now, expiresAt: now + windowDuration });
  } else {
    existing.count += 1;
  }

  const globalBucket = globalStore.get(globalKey);
  if (globalBucket.count > max) return false;

  // Keep a lightweight per-socket bucket as an additional burst guard.
  if (!socket.data.rateBuckets) socket.data.rateBuckets = {};
  const bucket = socket.data.rateBuckets[key] || { count: 0, windowStartedAt: now };
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

async function authenticateSigninPayload(payload) {
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
    if (user.isSuspended === true) {
      return { ok: false, status: 403, message: "This account is suspended. Contact support.", suggestions: [] };
    }
    if (!(await verifyPassword(password, user.passwordSalt, user.passwordHash))) {
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
  if (user.isSuspended === true) {
    return { ok: false, status: 403, message: "This account is suspended. Contact support.", suggestions: [] };
  }

  if (!user.passwordSalt || !user.passwordHash) {
    return { ok: false, status: 401, message: 'Password sign-in is unavailable for this account. Use Google sign-in or reset your password.', suggestions: [] };
  } else if (!(await verifyPassword(password, user.passwordSalt, user.passwordHash))) {
    return { ok: false, status: 401, message: "Incorrect password.", suggestions };
  }

  return { ok: true, user };
}

async function authenticateSignupPayload(payload) {
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
  const secret = await createPasswordSecret(password);
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

function generateBase32Secret(byteLength = 20) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const bytes = crypto.randomBytes(byteLength);
  let bits = "";
  for (const byte of bytes) bits += byte.toString(2).padStart(8, "0");
  let encoded = "";
  for (let index = 0; index < bits.length; index += 5) {
    encoded += alphabet[parseInt(bits.slice(index, index + 5).padEnd(5, "0"), 2)];
  }
  return encoded;
}

function hashBackupCode(code) {
  return "sha256:" + crypto.createHash("sha256").update(String(code).toUpperCase()).digest("hex");
}

function createBackupCodes() {
  return Array.from({ length: 10 }, () =>
    crypto.randomBytes(5).toString("hex").toUpperCase()
  );
}

app.get("/api/auth/2fa/status", requireUser, (req, res) => {
  const user = users.get(req.userKey);
  res.json({
    enabled: Boolean(user?.twoFactorEnabled && user?.twoFactorSecret),
    backupCodesCount: Array.isArray(user?.twoFactorBackupCodes) ? user.twoFactorBackupCodes.length : 0,
  });
});

app.post("/api/auth/2fa/setup", requireUser, requireCsrf, (req, res) => {
  const user = users.get(req.userKey);
  if (!user) return res.status(401).json({ message: "Sign in required." });
  if (user.twoFactorEnabled) {
    return res.status(409).json({ message: "Two-factor authentication is already enabled." });
  }
  // Keep the encrypted authenticator secret when 2FA is temporarily disabled.
  // Re-enabling can then verify the same authenticator without exposing its secret.
  let existingSecret = "";
  if (user.twoFactorSecret) {
    try {
      existingSecret = toDisplayName(decryptTotpSecret(user.twoFactorSecret));
    } catch (_) {
      existingSecret = "";
    }
  }
  const reuseExisting = Boolean(existingSecret);
  const secret = reuseExisting ? existingSecret : generateBase32Secret();
  const setupToken = createAuthToken("2fa_setup", req.userKey, 10 * 60 * 1000, { secret });
  if (reuseExisting) {
    return res.json({ reuseExisting: true, setupToken });
  }
  const issuer = "Novyn";
  const label = encodeURIComponent(`${issuer}:${user.email || user.username}`);
  const otpauthUri = `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
  res.json({ reuseExisting: false, secret, setupToken, otpauthUri });
});

app.post("/api/auth/2fa/enable", requireUser, requireCsrf, (req, res) => {
  const setupToken = verifyAuthToken(toDisplayName(req.body?.setupToken), "2fa_setup");
  if (!setupToken || resolveCurrentUserKey(setupToken.sub) !== req.userKey) {
    return res.status(401).json({ message: "Your setup session expired. Start again." });
  }
  const user = users.get(req.userKey);
  const secret = toDisplayName(setupToken.secret);
  const code = toDisplayName(req.body?.code).replace(/\s+/g, "");
  if (!user || user.twoFactorEnabled) {
    return res.status(409).json({ message: "Two-factor authentication is already enabled." });
  }
  if (!verifyTotpCode(secret, code)) {
    return res.status(400).json({ message: "Invalid 6-digit code. Check your authenticator app and device time." });
  }

  const backupCodes = createBackupCodes();
  user.twoFactorEnabled = true;
  user.twoFactorSecret = encryptTotpSecret(secret);
  user.twoFactorBackupCodes = backupCodes.map(hashBackupCode);
  schedulePersist();
  res.json({ enabled: true, backupCodes });
});

app.post("/api/auth/2fa/disable", requireUser, requireCsrf, async (req, res) => {
  const user = users.get(req.userKey);
  if (!user || !user.twoFactorEnabled || !user.twoFactorSecret) {
    return res.status(409).json({ message: "Two-factor authentication is not enabled." });
  }
  const currentPassword = toDisplayName(req.body?.currentPassword);
  const code = toDisplayName(req.body?.code).replace(/\s+/g, "");
  if (user.passwordHash && user.passwordSalt) {
    if (!currentPassword || !(await verifyPassword(currentPassword, user.passwordSalt, user.passwordHash))) {
      return res.status(401).json({ message: "Incorrect current password." });
    }
  } else if (!verifyTotpCode(decryptTotpSecret(user.twoFactorSecret), code)) {
    return res.status(401).json({ message: "Enter a valid authenticator code to disable 2FA." });
  }

  user.twoFactorEnabled = false;
  // Retain the encrypted authenticator secret so the same authenticator can
  // be reused if the account owner enables 2FA again. Backup codes are one-time
  // credentials and are invalidated whenever 2FA is disabled.
  user.twoFactorBackupCodes = [];
  schedulePersist();
  res.json({ enabled: false, backupCodesCount: 0 });
});

app.post(
  "/api/profile/update",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "profile-update", 40, 15 * 60 * 1000),
  requireCsrf,
  requireUser,
  async (req, res) => {
    const userKey = req.userKey;
    const user = users.get(userKey);
    if (!user || !user.isRegistered) {
      res.status(401).json({ error: "Sign in again before updating your profile." });
      return;
    }

    const body = req.body || {};
    if (Object.prototype.hasOwnProperty.call(body, "username")) {
      res.status(400).json({ error: "Use the dedicated username-change flow to update your username." });
      return;
    }

    if (body.displayName !== undefined) {
      const displayName = toDisplayName(body.displayName).slice(0, 50);
      if (!displayName) {
        res.status(400).json({ error: "Display name cannot be empty." });
        return;
      }
      user.displayName = displayName;
    }
    if (body.bio !== undefined) {
      user.bio = toDisplayName(body.bio).slice(0, 160);
    }
    if (body.avatarId !== undefined) {
      const avatarId = toDisplayName(body.avatarId);
      if (avatarId.length > 2048) {
        res.status(400).json({ error: "Profile photo reference is too long." });
        return;
      }
      user.avatarId = avatarId;
    }

    schedulePersist();
    const profile = {
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || "",
      avatarId: user.avatarId || "",
      email: user.email || "",
      emailVerified: user.emailVerified === true || Boolean(user.googleUid),
      presenceMode: user.presenceMode || "online",
    };

    const socketId = onlineUsers.get(userKey);
    if (socketId) io.to(socketId).emit("profile_updated", profile);
    emitFriendList(userKey);
    emitStatusToFriends(userKey);
    emitGroupListUpdatesForUser(userKey);
    for (const friendKey of user.friends) {
      if (usersAreBlocked(userKey, friendKey)) continue;
      const friendSocket = onlineUsers.get(friendKey);
      if (friendSocket) {
        io.to(friendSocket).emit("user_profile_updated", {
          username: user.username,
          displayName: user.displayName || user.username,
          bio: user.bio || "",
          avatarId: privacyAllows(user, friendKey, "profilePhotoPrivacy") ? user.avatarId || "" : "",
          presenceMode: privacyAllows(user, friendKey, "presencePrivacy") ? getDisplayPresence(userKey) : "offline",
        });
      }
    }
    emitDiscoverOnlineToAll();
    res.json({ ok: true, ...profile });
  }
);

app.post("/api/auth/signin", createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-signin", 25, 15 * 60 * 1000), requireCsrf, async (req, res) => {
  try {
    const result = await authenticateSigninPayload(req.body || {});
    if (!result.ok) {
      res.status(result.status || 401).json({
        message: result.message || "Authentication failed.",
        suggestions: result.suggestions || [],
      });
      return;
    }
    const remember = readRememberFlag(req.body?.remember);
    const userKey = normalizeName(result.user.username);
    if (result.user.twoFactorEnabled) {
      const challengeToken = createAuthToken("2fa_challenge", userKey, 5 * 60 * 1000, {
        remember: remember ? 1 : 0,
        nonce: crypto.randomBytes(16).toString("hex"),
      });
      res.json({
        requiresTwoFactor: true,
        challengeToken,
        username: result.user.username,
        message: "Enter the 6-digit code from your authenticator app.",
      });
      return;
    }
    const tokens = await issueAuthTokensForUser(userKey, remember, req);
    if (!tokens) {
      res.status(503).json({
        message: "Login service is temporarily unavailable. Please try again shortly.",
        code: "AUTH_SESSION_PERSISTENCE_UNAVAILABLE",
      });
      return;
    }
    applyAuthCookies(res, tokens);
    res.json({
      username: result.user.username,
      email: result.user.email || "",
    });
  } catch (error) {
    console.error("[NovynAuth] Sign-in request failed:", error?.message || error);
    if (!res.headersSent) {
      res.status(503).json({
        message: "Login service is temporarily unavailable. Please try again shortly.",
        code: "AUTH_SERVICE_UNAVAILABLE",
      });
    }
  }
});

app.post(
  "/api/auth/signup",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-signup", 20, 15 * 60 * 1000),
  requireCsrf,
  async (req, res) => {
    const result = await authenticateSignupPayload(req.body || {});
    if (!result.ok) {
      res.status(result.status || 400).json({ message: result.message || "Unable to sign up." });
      return;
    }
    const remember = readRememberFlag(req.body?.remember);
    const userKey = normalizeName(result.user.username);
    const tokens = await issueAuthTokensForUser(userKey, remember, req, {
      persistUserState: true,
    });
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
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-google", 25, 15 * 60 * 1000),
  requireCsrf,
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
      decoded = await verifyFirebaseIdToken(idToken);
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
    if (decoded.email_verified !== true || decoded.firebase?.sign_in_provider !== 'google.com') {
      return res.status(401).json({ message: 'A verified Google sign-in is required.' });
    }
    if (!email) {
      res.status(400).json({ message: "Google account email is required." });
      return;
    }
    const googleDisplayName = toDisplayName(decoded.name || decoded.displayName || email.split("@")[0] || "");
    const linkIdentifier = toDisplayName(req.body?.identifier || "");
    const linkPassword = toDisplayName(req.body?.password || "");

    let user = findUserByGoogleUid(googleUid) || findUserByEmail(email);
    let linkedExisting = Boolean(user);
    if (user?.isSuspended === true) {
      res.status(403).json({ message: "This account is suspended. Contact support." });
      return;
    }

    if (!user && linkIdentifier && linkPassword) {
      const linkedAuth = await authenticateSigninPayload({
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
      const requestedUsername = normalizeHandleInput(req.body?.username || "");
      if (!requestedUsername) {
        res.json({
          requiresUsername: true,
          usernameSuggestion: buildGoogleUsernameSuggestion(
            googleDisplayName || email.split("@")[0] || "novynuser",
          ),
        });
        return;
      }
      if (!/^[a-z0-9_]{3,24}$/.test(requestedUsername)) {
        res.status(400).json({
          message: "Choose a username with 3–24 lowercase letters, numbers, or underscores.",
        });
        return;
      }
      if (isUsernameTaken(requestedUsername)) {
        res.status(409).json({
          message: "That username is already taken. Choose another one.",
        });
        return;
      }
      user = getOrCreateUser(requestedUsername);
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

    if (user.twoFactorEnabled) {
      const challengeToken = createAuthToken("2fa_challenge", user.username, 5 * 60 * 1000, {
        remember: remember ? 1 : 0,
        nonce: crypto.randomBytes(16).toString("hex"),
      });
      res.json({
        requiresTwoFactor: true,
        challengeToken,
        username: user.username,
        email: user.email || "",
        message: "Enter the 6-digit code from your authenticator app.",
      });
      return;
    }

    const tokens = await issueAuthTokensForUser(user.username, remember, req, {
      persistUserState: userChanged,
    });
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

app.post(
  "/api/auth/2fa/verify",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-2fa-verify", 10, 5 * 60 * 1000),
  requireCsrf,
  async (req, res) => {
    const challengeToken = toDisplayName(req.body?.challengeToken);
    const code = toDisplayName(req.body?.code).replace(/\s+/g, "");
    const challenge = verifyAuthToken(challengeToken, "2fa_challenge");
    if (!challenge) {
      res.status(401).json({ message: "Your verification session expired. Sign in again." });
      return;
    }

    const userKey = resolveCurrentUserKey(challenge.sub);
    const user = users.get(userKey);
    if (!user || !user.isRegistered || !user.twoFactorEnabled || !user.twoFactorSecret) {
      res.status(401).json({ message: "Two-factor authentication is no longer enabled for this account." });
      return;
    }

    let verified = verifyTotpCode(decryptTotpSecret(user.twoFactorSecret), code);
    let backupCodeConsumed = false;
    if (!verified && Array.isArray(user.twoFactorBackupCodes)) {
      const candidateHash = hashBackupCode(code);
      const backupIndex = user.twoFactorBackupCodes.findIndex((saved) => {
        const value = toDisplayName(saved);
        // Accept legacy plaintext codes once, then migrate by consuming them.
        return value.startsWith("sha256:")
          ? safeTimingEqual(value, candidateHash)
          : safeTimingEqual(value.toUpperCase(), code.toUpperCase());
      });
      if (backupIndex >= 0) {
        user.twoFactorBackupCodes.splice(backupIndex, 1);
        verified = true;
        backupCodeConsumed = true;
        schedulePersist();
      }
    }
    if (!verified) {
      res.status(401).json({ message: "Invalid verification code. Check the code and try again." });
      return;
    }

    const remember = challenge.remember === 1;
    const tokens = await issueAuthTokensForUser(userKey, remember, req, {
      persistUserState: backupCodeConsumed,
    });
    if (!tokens) {
      res.status(503).json({ message: "Unable to create session." });
      return;
    }
    applyAuthCookies(res, tokens);
    res.json({
      username: user.username,
      email: user.email || "",
      twoFactorVerified: true,
    });
  }
);

// Account-wide preferences are stored in Firestore through the authenticated
// Novyn session. The Admin SDK bypasses client rules, so users can only access
// the document selected from the server-verified req.userKey.
const ACCOUNT_SETTINGS_ALLOWED_KEYS = new Set([
    "onlineStatus", "themeMode", "chatEnterToSend",
  "autoDownloadWifi",
  "autoDownloadMobile", "photoQuality", "language", "timeFormat",
  "fontSize", "chatLabelSize", "accentColorValue", "accentColorEnabled",
  "dockStyle", "alertStyle", "notificationTone", "callRingtone",
  "vibrationPattern", "hapticIntensity", "hapticNavigation", "hapticTyping",
  "hapticChat", "hapticButtons", "hapticNotifications", "hapticCalls",
  "messageVolume", "callVolume", "region", "highContrast", "reduceMotion",
  "doNotDisturbEnabled", "quickToggleIds",
]);

app.get("/api/settings/account", requireUser, async (req, res) => {
  if (!firebaseAdmin) {
    return res.status(503).json({ ok: false, message: "Cloud settings are temporarily unavailable." });
  }
  try {
    const db = admin.firestore(firebaseAdmin);
    const snapshot = await db.collection("accountSettings").doc(req.userKey).get();
    const data = snapshot.exists ? (snapshot.data() || {}) : {};
    return res.json({
      ok: true,
      exists: snapshot.exists,
      settings: data.settings && typeof data.settings === "object" && !Array.isArray(data.settings)
        ? data.settings
        : {},
      updatedAt: Number(data.updatedAt) || 0,
    });
  } catch (error) {
    console.warn("[NovynSettings] Firestore read failed:", error?.message || error);
    return res.status(503).json({ ok: false, message: "Cloud settings could not be loaded." });
  }
});

app.put("/api/settings/account", requireUser, requireCsrf, async (req, res) => {
  if (!firebaseAdmin) {
    return res.status(503).json({ ok: false, message: "Cloud settings are temporarily unavailable." });
  }
  const incoming = req.body?.settings;
  if (!incoming || typeof incoming !== "object" || Array.isArray(incoming)) {
    return res.status(400).json({ ok: false, message: "A settings object is required." });
  }
  let encodedSize = 0;
  try {
    encodedSize = Buffer.byteLength(JSON.stringify(incoming), "utf8");
  } catch (_) {
    return res.status(400).json({ ok: false, message: "Settings payload is invalid." });
  }
  if (encodedSize > 16 * 1024) {
    return res.status(413).json({ ok: false, message: "Settings payload is too large." });
  }

  const settings = {};
  for (const [key, value] of Object.entries(incoming)) {
    if (!ACCOUNT_SETTINGS_ALLOWED_KEYS.has(key)) continue;
    if (key === "quickToggleIds") {
      if (Array.isArray(value)) {
        settings[key] = [...new Set(value.filter((id) =>
          typeof id === "string" && [
            "app_lock", "do_not_disturb", "dark_mode", "stealth_mode",
            "read_receipts", "in_app_sounds", "in_app_vibration",
            "group_notifications",
          ].includes(id)
        ))].slice(0, 4);
      }
      continue;
    }
    if (typeof value === "boolean" || typeof value === "string" ||
        (typeof value === "number" && Number.isFinite(value))) {
      settings[key] = value;
    }
  }

  try {
    const updatedAt = Date.now();
    const db = admin.firestore(firebaseAdmin);
    const ref = db.collection("accountSettings").doc(req.userKey);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const existing = snapshot.exists ? (snapshot.data() || {}) : {};
      const previousSettings = existing.settings &&
        typeof existing.settings === "object" &&
        !Array.isArray(existing.settings)
          ? existing.settings
          : {};
      // Merge only changed preference keys so simultaneous edits to different
      // settings on separate devices do not overwrite each other.
      transaction.set(ref, {
        settings: { ...previousSettings, ...settings },
        updatedAt,
      });
    });
    return res.json({ ok: true, updatedAt });
  } catch (error) {
    console.warn("[NovynSettings] Firestore write failed:", error?.message || error);
    return res.status(503).json({ ok: false, message: "Cloud settings could not be saved." });
  }
});

app.get("/api/auth/csrf", (req, res) => {
  const token = toDisplayName(req.novynCsrfToken);
  if (!token) {
    return res.status(503).json({ message: "Could not initialize the security token." });
  }
  res.set("Cache-Control", "no-store, max-age=0");
  return res.json({ ok: true, csrfToken: token });
});

app.get("/api/auth/session", async (req, res) => {
  const auth = resolveUserFromAuthCookies(getAuthCookiesFromHeader(req.headers.cookie), {
    allowRefreshFallback: true,
  });
  if (!auth.userKey) {
    res.status(401).json({ message: "Not signed in." });
    return;
  }
  const user = users.get(auth.userKey);
  if (!user || !user.isRegistered || user.isSuspended === true) {
    clearAuthCookies(res);
    res.status(401).json({ message: "Session expired." });
    return;
  }
  if (auth.via === "refresh") {
    const tokens = await issueAuthTokensForUser(
      auth.userKey,
      Boolean(auth.remember),
      req,
    );
    if (!tokens) {
      res.status(503).json({ message: "Session service is temporarily unavailable." });
      return;
    }
    applyAuthCookies(res, tokens);
  }
  res.json({
    authenticated: true,
    username: user.username,
    displayName: user.displayName || user.username,
    email: user.email || "",
    emailVerified: user.emailVerified === true || Boolean(user.googleUid),
    avatarId: user.avatarId || "",
    bio: user.bio || "",
    presenceMode: user.presenceMode || "online",
    hasPassword: Boolean(user.passwordHash && user.passwordSalt),
    isGoogleUser: Boolean(user.googleUid),
    twoFactorEnabled: Boolean(user.twoFactorEnabled),
    retentionDays: 0,
    callsEnabled: user.callsEnabled !== false,
        callPrivacy: user.callPrivacy || "friends", messagePrivacy: user.messagePrivacy || "friends",
    profilePhotoPrivacy: user.profilePhotoPrivacy || "everyone", presencePrivacy: user.presencePrivacy || "everyone", discoverPrivacy: user.discoverPrivacy || "everyone",
    readReceiptsEnabled: user.readReceiptsEnabled !== false, typingIndicatorsEnabled: user.typingIndicatorsEnabled !== false,
    groupInvitePrivacy: user.groupInvitePrivacy || "friends", friendRequestPrivacy: user.friendRequestPrivacy || "everyone",
  });
});

// QR-linked web sessions are short-lived, single-use and approved from the
// authenticated primary phone. E2EE material stays inside the encrypted
// envelope and is only ever returned to the browser presenting the secret.
app.post("/api/device-pairing/start",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "device-pair-start", 12, 15 * 60 * 1000),
  requireCsrf,
  (req, res) => {
    const publicKey = req.body?.publicKey;
    let jwk;
    try { jwk = typeof publicKey === "string" ? JSON.parse(publicKey) : publicKey; } catch (_) { jwk = null; }
    if (!jwk || jwk.kty !== "EC" || jwk.crv !== "P-256" ||
        typeof jwk.x !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(jwk.x) ||
        typeof jwk.y !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(jwk.y)) {
      return res.status(400).json({ ok: false, message: "A valid temporary browser key is required." });
    }
    const now = Date.now();
    for (const [id, pairing] of runtimeState.devicePairings) {
      if (!pairing || pairing.expiresAt <= now || pairing.status === "complete") runtimeState.devicePairings.delete(id);
    }
    const id = crypto.randomBytes(18).toString("base64url");
    const secret = crypto.randomBytes(32).toString("base64url");
    const origin = toDisplayName(req.get("origin") || `${req.protocol}://${req.get("host")}`);
    runtimeState.devicePairings.set(id, {
      secretHash: crypto.createHash("sha256").update(secret).digest("hex"),
      browserPublicKey: JSON.stringify(jwk),
      origin,
      createdAt: now,
      expiresAt: now + 2 * 60 * 1000,
      status: "waiting",
    });
    return res.json({ ok: true, id, secret, origin, expiresAt: now + 2 * 60 * 1000 });
  });

app.get("/api/device-pairing/status", (req, res) => {
  const id = toDisplayName(req.query?.id);
  const secret = toDisplayName(req.query?.secret);
  const pairing = runtimeState.devicePairings.get(id);
  const secretHash = crypto.createHash("sha256").update(secret).digest("hex");
  if (!pairing || pairing.expiresAt <= Date.now() ||
      !csrfSafeTimingEqual(pairing.secretHash, secretHash)) {
    return res.status(404).json({ ok: false, message: "This pairing request expired. Refresh to try again." });
  }
  return res.json({ ok: true, status: pairing.status });
});

app.post("/api/device-pairing/complete",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "device-pair-complete", 12, 15 * 60 * 1000),
  requireCsrf,
  async (req, res) => {
    const id = toDisplayName(req.body?.id);
    const secret = toDisplayName(req.body?.secret);
    const pairing = runtimeState.devicePairings.get(id);
    const secretHash = crypto.createHash("sha256").update(secret).digest("hex");
    if (!pairing || pairing.expiresAt <= Date.now() || pairing.status !== "approved" ||
        pairing.completing || !csrfSafeTimingEqual(pairing.secretHash, secretHash)) {
      return res.status(409).json({ ok: false, message: "Pairing is not approved or has expired." });
    }
    const user = users.get(pairing.userKey);
    if (!user?.isRegistered) {
      runtimeState.devicePairings.delete(id);
      return res.status(410).json({ ok: false, message: "The primary account is no longer available." });
    }
    pairing.completing = true;
    const tokens = await issueAuthTokensForUser(pairing.userKey, true, req);
    if (!tokens) {
      pairing.completing = false;
      return res.status(503).json({ ok: false, message: "Could not create the linked session. Retry." });
    }
    applyAuthCookies(res, tokens);
    pairing.status = "complete";
    res.json({
      ok: true,
      username: user.username,
      displayName: user.displayName || user.username,
      email: user.email || "",
      encryptedIdentity: pairing.encryptedIdentity,
    });
    runtimeState.devicePairings.delete(id);
  });

app.post("/api/auth/refresh", createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-refresh", 120, 15 * 60 * 1000), requireCsrf, async (req, res) => {
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
  const previousSession = { ...session };
  revokeRefreshSession(refreshPayload.jti);
  const tokens = await issueAuthTokensForUser(userKey, remember, req);
  if (!tokens) {
    // Do not strand the user on a failed persistence write: restore the
    // previous refresh entry and keep the existing client cookie pair valid.
    authSessions.trackRefreshSession(
      userKey,
      refreshPayload.jti,
      previousSession.expiresAt,
      previousSession.remember,
      previousSession,
    );
    try {
      await flushAuthStatePersistNow();
    } catch (error) {
      console.error("[NovynAuth] Could not restore previous refresh session:", error);
    }
    res.status(503).json({ message: "Session refresh is temporarily unavailable. Please retry." });
    return;
  }
  applyAuthCookies(res, tokens);
  res.json({ ok: true });
});

app.post("/api/auth/logout", createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-logout", 120, 15 * 60 * 1000), requireCsrf, (req, res) => {
  const cookies = getAuthCookiesFromHeader(req.headers.cookie);
  const refreshPayload = verifyAuthToken(cookies.refreshToken, "refresh");
  if (refreshPayload?.jti) {
    revokeRefreshSession(refreshPayload.jti);
    for (const client of io.sockets.sockets.values()) {
      if (client.data.sessionId === refreshPayload.jti) client.disconnect(true);
    }
  }
  clearAuthCookies(res);
  res.json({ ok: true });
});


app.post("/api/auth/password-reset/request",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-password-reset-request", 10, 15 * 60 * 1000),
  requireCsrf,
  async (req, res) => {
    pruneExpiredPasswordResetTokens();
    const identifier = toDisplayName(req.body?.identifier || req.body?.email || "");
    const genericMessage = "If an account exists, a reset code has been sent.";
    if (!isPasswordResetDeliveryAvailable()) {
      res.status(503).json({ ok: false, message: "Password reset email service is unavailable. Try again later." });
      return;
    }
    if (!identifier) {
      res.json({ ok: true, message: genericMessage });
      return;
    }
    const user = identifier.includes("@")
      ? findUserByEmail(identifier)
      : users.get(normalizeName(identifier));
    if (!user || !user.isRegistered) {
      res.json({ ok: true, message: genericMessage });
      return;
    }
    const userKey = normalizeName(user.username);
    const rate = canIssuePasswordReset(userKey);
    if (!rate.allowed) {
      res.status(429).json({ ok: false, message: rate.message });
      return;
    }
    const previousTokenId = passwordResetByUser.get(userKey);
    if (previousTokenId) dropPasswordResetTokenById(previousTokenId);
    const token = createResetToken();
    const salt = crypto.randomBytes(8).toString("hex");
    const tokenHash = createResetTokenHash(token, salt);
    const tokenId = createResetTokenId();
    const expiresAt = Date.now() + PASSWORD_RESET_CODE_TTL_MS;
    passwordResetTokens.set(tokenId, {
      userKey, salt, tokenHash, expiresAt,
      attemptsLeft: PASSWORD_RESET_MAX_ATTEMPTS,
    });
    passwordResetByUser.set(userKey, tokenId);
    markPasswordResetIssued(userKey, rate.state);
    const dispatched = await dispatchPasswordResetCode(user, token);
    if (!dispatched) dropPasswordResetTokenById(tokenId);
    res.json({ ok: true, message: genericMessage });
  }
);

app.post("/api/auth/password-reset/confirm",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-password-reset-confirm", 30, 15 * 60 * 1000),
  requireCsrf,
  async (req, res) => {
    pruneExpiredPasswordResetTokens();
    const identifier = toDisplayName(req.body?.identifier || req.body?.email || req.body?.username || "");
    const token = toDisplayName(req.body?.code || req.body?.token || "");
    const newPassword = toDisplayName(req.body?.newPassword || "");
    if (!identifier || !token || !newPassword) {
      res.status(400).json({ ok: false, message: "Email/username, reset code, and new password are required." });
      return;
    }
    if (newPassword.length < MIN_PASSWORD_LENGTH) {
      res.status(400).json({ ok: false, message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.` });
      return;
    }
    const user = identifier.includes("@")
      ? findUserByEmail(identifier)
      : users.get(normalizeName(identifier));
    if (!user || !user.isRegistered) {
      res.status(400).json({ ok: false, message: "Invalid or expired reset code." });
      return;
    }
    const userKey = normalizeName(user.username);
    const tokenId = passwordResetByUser.get(userKey);
    const entry = tokenId ? passwordResetTokens.get(tokenId) : null;
    if (!entry || entry.userKey !== userKey) {
      res.status(400).json({ ok: false, message: "Invalid or expired reset code." });
      return;
    }
    if (Date.now() > Number(entry.expiresAt)) {
      dropPasswordResetTokenById(tokenId);
      res.status(400).json({ ok: false, message: "Reset code expired. Request a new one." });
      return;
    }
    if (!Number.isFinite(Number(entry.attemptsLeft)) || Number(entry.attemptsLeft) <= 0) {
      dropPasswordResetTokenById(tokenId);
      res.status(429).json({ ok: false, message: "Too many attempts. Request a new code." });
      return;
    }
    const expectedHash = createResetTokenHash(token, entry.salt);
    if (expectedHash !== entry.tokenHash) {
      entry.attemptsLeft = Math.max(0, Number(entry.attemptsLeft) - 1);
      if (entry.attemptsLeft <= 0) dropPasswordResetTokenById(tokenId);
      res.status(400).json({
        ok: false,
        message: entry.attemptsLeft > 0
          ? `Invalid reset code. ${entry.attemptsLeft} attempt(s) left.`
          : "Too many attempts. Request a new code.",
      });
      return;
    }
    const secret = await createPasswordSecret(newPassword);
    user.passwordSalt = secret.passwordSalt;
    user.passwordHash = secret.passwordHash;
    user.isRegistered = true;
    revokeAllRefreshSessionsForUser(userKey);
    dropPasswordResetTokenById(tokenId);
    schedulePersist();
    res.json({ ok: true, message: "Password updated. Please sign in." });
  }
);


// Revoke every other login session while keeping the device making this request.
app.get("/api/auth/sessions", requireUser, (req, res) => {
  const cookies = getAuthCookiesFromHeader(req.headers.cookie);
  const access = verifyAuthToken(cookies.accessToken, "access");
  const refresh = verifyAuthToken(cookies.refreshToken, "refresh");
  const currentSessionId = toDisplayName(refresh?.jti || access?.sid);
  const userKey = normalizeName(req.userKey);
  const sessions = Array.from(refreshByUser.get(userKey) || [])
    .map((id) => ({ id, entry: refreshSessions.get(id) }))
    .filter(({ entry }) => entry && Number(entry.expiresAt) > Date.now())
    .map(({ id, entry }) => ({
      id,
      deviceName: toDisplayName(entry.deviceName || "Unknown device"),
      client: toDisplayName(entry.client || "web"),
      createdAt: Number(entry.createdAt) || 0,
      lastActiveAt: Number(entry.lastActiveAt) || 0,
      current: id === currentSessionId,
    }))
    .sort((a, b) => Number(b.current) - Number(a.current) || b.lastActiveAt - a.lastActiveAt);
  res.json({ ok: true, sessions });
});

app.post("/api/auth/revoke-session",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-revoke-session", 30, 15 * 60 * 1000),
  requireCsrf,
  requireUser,
  (req, res) => {
    const targetId = toDisplayName(req.body?.sessionId);
    const cookies = getAuthCookiesFromHeader(req.headers.cookie);
    const access = verifyAuthToken(cookies.accessToken, "access");
    const refresh = verifyAuthToken(cookies.refreshToken, "refresh");
    const currentSessionId = toDisplayName(refresh?.jti || access?.sid);
    const target = refreshSessions.get(targetId);
    if (!targetId || !target || normalizeName(target.userKey) !== normalizeName(req.userKey)) {
      res.status(404).json({ ok: false, message: "That session is no longer active." });
      return;
    }
    if (targetId === currentSessionId) {
      res.status(400).json({ ok: false, message: "Use Sign out to end the current session." });
      return;
    }
    revokeRefreshSession(targetId);
    for (const client of io.sockets.sockets.values()) {
      if (client.data.sessionId === targetId) client.disconnect(true);
    }
    res.json({ ok: true });
  }
);

app.post("/api/auth/revoke-sessions",
  createIpRateLimiter({ getStore: () => httpRateLimits }, "auth-revoke-sessions", 20, 15 * 60 * 1000),
  requireCsrf,
  requireUser,
  (req, res) => {
    const cookies = getAuthCookiesFromHeader(req.headers.cookie);
    const refreshPayload = verifyAuthToken(cookies.refreshToken, "refresh");
    const currentSessionId = toDisplayName(refreshPayload?.jti);
    if (!currentSessionId || !refreshSessions.has(currentSessionId)) {
      res.status(401).json({ ok: false, message: "Your current session could not be verified. Please sign in again." });
      return;
    }

    const userKey = normalizeName(req.userKey);
    const tokenIds = Array.from(refreshByUser.get(userKey) || []);
    let revoked = 0;
    for (const tokenId of tokenIds) {
      if (tokenId === currentSessionId) continue;
      if (revokeRefreshSession(tokenId)) revoked += 1;
      for (const client of io.sockets.sockets.values()) {
        if (client.data.sessionId === tokenId) client.disconnect(true);
      }
    }
    res.json({ ok: true, revoked });
  }
);

const { fetchSafeExternalUrl, readResponseWithLimit, readResponseBufferWithLimit } = require("./server/security/ssrf");
const { createLinkPreviewData } = require("./server/chat/link-preview");

const linkPreviewCache = new Map();
const LINK_PREVIEW_CACHE_TTL_MS = 10 * 60 * 1000;
const LINK_PREVIEW_CACHE_LIMIT = 500;

app.get(
  "/api/link-preview",
  requireUser,
  createIpRateLimiter({ getStore: () => httpRateLimits }, "link-preview", 60, 60 * 1000),
  async (req, res) => {
    const targetUrl = String(req.query?.url || "").trim();
    if (!targetUrl || targetUrl.length > 2048) {
      res.status(400).json({ error: "Invalid URL" });
      return;
    }

    try {
      // fetchSafeExternalUrl validates DNS/IP ranges and pins the vetted
      // address for the actual request, preventing private-network SSRF and DNS rebinding.
      const safeUrl = new URL(targetUrl);
      if (!["http:", "https:"].includes(safeUrl.protocol) || safeUrl.username || safeUrl.password) {
        res.status(400).json({ error: "URL is not allowed." });
        return;
      }

      const cacheKey = safeUrl.href;
      const cached = linkPreviewCache.get(cacheKey);
      if (cached && cached.expiresAt > Date.now()) {
        res.set("Cache-Control", "private, max-age=600");
        res.json(cached.data);
        return;
      }
      if (cached) linkPreviewCache.delete(cacheKey);

      const response = await fetchSafeExternalUrl(safeUrl.href, {
        timeoutMs: 4000,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; NovynLinkPreview/1.0)",
          Accept: "text/html,application/xhtml+xml;q=0.9",
        },
      });

      if (response.status >= 300 && response.status < 400) {
        await response.body?.cancel();
        res.status(400).json({ error: "Redirects are not allowed." });
        return;
      }
      if (!response.ok) {
        await response.body?.cancel();
        res.status(400).json({ error: "Failed to fetch URL" });
        return;
      }

      const contentType = String(response.headers.get("content-type") || "").toLowerCase();
      if (contentType && !/(^|;)\s*(text\/html|application\/xhtml\+xml)(?:\s*;|$)/i.test(contentType)) {
        await response.body?.cancel();
        res.status(415).json({ error: "URL does not return an HTML page." });
        return;
      }

      const html = await readResponseWithLimit(response, 1024 * 1024);
      const preview = createLinkPreviewData(html, safeUrl.href);

      if (linkPreviewCache.size >= LINK_PREVIEW_CACHE_LIMIT) {
        const oldestKey = linkPreviewCache.keys().next().value;
        if (oldestKey) linkPreviewCache.delete(oldestKey);
      }
      linkPreviewCache.set(cacheKey, {
        data: preview,
        expiresAt: Date.now() + LINK_PREVIEW_CACHE_TTL_MS,
      });

      res.set("Cache-Control", "private, max-age=600");
      res.json(preview);
    } catch (error) {
      const message = String(error?.message || "");
      const clientError = /Unsafe destination|Unsupported URL|credentials|Redirects|Response too large|Invalid URL/i.test(message);
      res.status(clientError ? 400 : 502).json({
        error: clientError ? "URL is not allowed." : "Failed to load link preview.",
      });
    }
  }
);

app.post(
  "/api/import-wallpaper-url",
  requireCsrf,
  requireUser,
  createIpRateLimiter({ getStore: () => httpRateLimits }, "wallpaper-import", 10, 15 * 60 * 1000),
  async (req, res) => {
    const targetUrl = String(req.body?.url || "").trim();
    if (!targetUrl || !/^https?:\/\//i.test(targetUrl)) {
      return res.status(400).json({ error: "Invalid URL" });
    }

    const fetchExternal = async (rawUrl, headers = {}) => {
        const response = await fetchSafeExternalUrl(rawUrl, { headers });
        if (response.status >= 300 && response.status < 400) {
          await response.body?.cancel();
          throw new Error("Redirects are not allowed.");
        }
        return { response, safeUrl: new URL(rawUrl) };
    };

    try {
      let directImageUrl = targetUrl;

      // Pinterest oEmbed destination is fixed; the user URL is only a query parameter.
      if (targetUrl.includes("pinterest.com/pin/") || targetUrl.includes("pin.it/")) {
        try {
            const oembedRes = await fetchSafeExternalUrl(
              `https://www.pinterest.com/oembed.json?url=${encodeURIComponent(targetUrl)}`,
              { timeoutMs: 4000 }
            );
            if (oembedRes.ok) {
              const oembedText = await readResponseWithLimit(oembedRes, 128 * 1024);
              const oembedData = JSON.parse(oembedText);
              if (oembedData.url || oembedData.thumbnail_url) {
                directImageUrl = oembedData.url || oembedData.thumbnail_url;
              }
            }
        } catch (_) {}
      }

      // Resolve OpenGraph metadata through the same SSRF and response-size controls.
      if (!/\.(jpeg|jpg|gif|png|webp)(\?.*)?$/i.test(directImageUrl)) {
        try {
          const { response } = await fetchExternal(directImageUrl, {
            "User-Agent": "Novyn/1.0",
            Accept: "text/html,application/xhtml+xml",
          });
          if (response.ok) {
            const html = await readResponseWithLimit(response, 512 * 1024);
            const ogImage = html.match(
              /<meta\s+(?:property|name)=["'](?:og:image|twitter:image)["']\s+content=["'](.*?)["']/i
            );
            if (ogImage?.[1]) {
              directImageUrl = ogImage[1];
            }
          }
        } catch (_) {}
      }

      const { response: imgRes, safeUrl: finalUrl } = await fetchExternal(directImageUrl, {
        "User-Agent": "Novyn/1.0",
        Accept: "image/jpeg,image/png,image/gif,image/webp",
      });

      if (!imgRes.ok) {
        return res.status(400).json({ error: "Unable to fetch image." });
      }

      const contentType = String(imgRes.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
      const extensionByMime = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/gif": ".gif",
        "image/webp": ".webp",
      };
      const ext = extensionByMime[contentType];
      if (!ext) {
        return res.status(415).json({ error: "Only JPEG, PNG, GIF, and WebP wallpapers are supported." });
      }

      const buffer = await readResponseBufferWithLimit(imgRes, 8 * 1024 * 1024);
      if (!buffer.length) {
        return res.status(400).json({ error: "Empty image response." });
      }

      const filename = `wallpaper-${Date.now()}-${crypto.randomBytes(3).toString("hex")}${ext}`;
      const destPath = path.join(uploadsDir, filename);
      fs.writeFileSync(destPath, buffer);
      await saveMediaMetadata(filename, req.userKey);
      const token = signUploadToken(filename);
      return res.json({ url: `/uploads/${filename}?token=${token}`, source: finalUrl.href });
    } catch (err) {
      const message = String(err?.message || "");
      const clientError = /Unsafe destination|Unsupported URL|credentials|Redirects|Response too large|Unsupported URL port/.test(message);
      return res.status(clientError ? 400 : 500).json({
        error: clientError ? "URL is not allowed." : "Failed to import wallpaper.",
      });
    }
  }
);

// ── Feedback Endpoint ─────────────────────────────────────────────────────
// Persist every accepted submission and report email delivery separately.
// Email is sent to the configured Novyn inbox and, when supplied, a receipt is
// sent to the submitter. The optional reply address is never treated as a
// delivery destination unless the user explicitly supplied it.
{
  const FEEDBACK_TO_EMAIL = toDisplayName(process.env.FEEDBACK_TO_EMAIL || "");
  const allowedTypes = new Set(["general", "bug", "feature", "praise"]);
  const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]);

  app.post(
    "/api/feedback",
    createIpRateLimiter({ getStore: () => httpRateLimits }, "feedback", 5, 60 * 60 * 1000),
    async (req, res) => {
      const requestedType = toDisplayName(req.body?.type || "general").toLowerCase();
      const type = allowedTypes.has(requestedType) ? requestedType : "general";
      const message = toDisplayName(req.body?.message || "").slice(0, 2000);
      const suppliedEmail = toDisplayName(req.body?.email || "").slice(0, 200).toLowerCase();
      const ratingValue = Number(req.body?.rating);
      const rating = Number.isFinite(ratingValue) && ratingValue > 0
        ? Math.min(5, Math.max(1, Math.floor(ratingValue)))
        : null;

      if (!message || message.length < 5) {
        return res.status(400).json({ ok: false, error: "Please write at least 5 characters." });
      }
      if (suppliedEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(suppliedEmail)) {
        return res.status(400).json({ ok: false, error: "Enter a valid email address or leave it blank." });
      }

      const cookieAuth = resolveUserFromAuthCookies(
        getAuthCookiesFromHeader(req.headers.cookie),
        { allowRefreshFallback: true }
      );
      const userKey = cookieAuth.userKey || null;
      const user = userKey ? users.get(userKey) : null;
      const fromUser = user ? (user.username || userKey) : "anonymous";
      const replyEmail = suppliedEmail || normalizeEmail(user?.email || "");

      const entry = {
        id: `fb_${Date.now().toString(36)}_${crypto.randomBytes(3).toString("hex")}`,
        type,
        message,
        rating,
        email: replyEmail,
        fromUser,
        userKey,
        ip: req.ip || "",
        createdAt: nowIso(),
      };

      // Do not report success unless the submission has actually been stored.
      try {
        const feedbackCollection = mongoStorage?.getCollection("feedback");
        if (hasMongoStorage() && feedbackCollection) {
          await feedbackCollection.insertOne(entry);
        } else {
          const feedbackFile = path.join(DATA_DIR, "feedback.log");
          await fsp.mkdir(DATA_DIR, { recursive: true });
          await fsp.appendFile(feedbackFile, `${JSON.stringify(entry)}\n`, "utf8");
        }
      } catch (err) {
        console.warn("[NovynFeedback] Failed to persist submission:", err?.message || err);
        return res.status(503).json({
          ok: false,
          error: "Your feedback could not be saved right now. Please try again.",
        });
      }

      const mailConfigured = Boolean(passwordResetMailer);
      const adminRecipientConfigured = Boolean(FEEDBACK_TO_EMAIL);
      const typeLabels = {
        general: "General",
        bug: "Bug report",
        feature: "Feature request",
        praise: "Praise",
      };
      const typeLabel = typeLabels[type];
      const stars = rating
        ? `${"★".repeat(rating)}${"☆".repeat(5 - rating)} (${rating}/5)`
        : "Not rated";
      const safeMessage = escapeHtml(message).replace(/\r?\n/g, "<br>");
      const safeUser = escapeHtml(fromUser);
      const safeEmail = escapeHtml(replyEmail);
      const safeTime = escapeHtml(entry.createdAt);
      const safeId = escapeHtml(entry.id);

      let adminEmailSent = false;
      let receiptEmailSent = false;

      // A feedback submission is successful once it is durably stored.
      // Do not make the mobile request wait for slow SMTP round trips.
      res.json({
        ok: true,
        id: entry.id,
        saved: true,
        email: {
          configured: mailConfigured,
          adminRecipientConfigured,
          adminSent: false,
          receiptSent: false,
          receiptAddress: replyEmail || null,
          deliveryPending: Boolean(passwordResetMailer && (FEEDBACK_TO_EMAIL || replyEmail)),
        },
      });

      if (passwordResetMailer && FEEDBACK_TO_EMAIL) {
        try {
          await passwordResetMailer.sendMail({
            from: process.env.SMTP_FROM,
            to: FEEDBACK_TO_EMAIL,
            ...(replyEmail ? { replyTo: replyEmail } : {}),
            subject: `[Novyn Feedback] ${typeLabel} from ${fromUser}`,
            text: [
              "New feedback for Novyn",
              `Type: ${typeLabel}`,
              `From: ${fromUser}`,
              `Reply email: ${replyEmail || "Not provided"}`,
              `Rating: ${stars}`,
              `Submitted: ${entry.createdAt}`,
              "",
              message,
              "",
              `Feedback ID: ${entry.id}`,
            ].join("\n"),
            html: `
              <div style="font-family:Arial,sans-serif;max-width:620px;margin:0 auto;padding:28px;background:#f5f3ff;color:#171936;border-radius:20px;">
                <div style="padding:22px;background:#ffffff;border-radius:16px;">
                  <h2 style="margin:0 0 18px;color:#6048e8;">New feedback - Novyn</h2>
                  <table style="width:100%;border-collapse:collapse;font-size:14px;">
                    <tr><td style="padding:8px 0;color:#68708a;">Type</td><td style="padding:8px 0;font-weight:700;">${escapeHtml(typeLabel)}</td></tr>
                    <tr><td style="padding:8px 0;color:#68708a;">From</td><td style="padding:8px 0;">${safeUser}</td></tr>
                    <tr><td style="padding:8px 0;color:#68708a;">Reply email</td><td style="padding:8px 0;">${safeEmail || "Not provided"}</td></tr>
                    <tr><td style="padding:8px 0;color:#68708a;">Rating</td><td style="padding:8px 0;">${escapeHtml(stars)}</td></tr>
                    <tr><td style="padding:8px 0;color:#68708a;">Submitted</td><td style="padding:8px 0;">${safeTime}</td></tr>
                  </table>
                  <div style="margin-top:18px;padding:18px;background:#f4f1ff;border-radius:12px;line-height:1.7;">${safeMessage}</div>
                  <p style="margin:18px 0 0;color:#8790a8;font-size:11px;">Feedback ID: ${safeId}</p>
                </div>
              </div>
            `,
          });
          adminEmailSent = true;
        } catch (err) {
          console.warn("[NovynFeedback] Admin email delivery failed:", err?.message || err);
        }
      }

      if (passwordResetMailer && replyEmail) {
        try {
          await passwordResetMailer.sendMail({
            from: process.env.SMTP_FROM,
            to: replyEmail,
            ...(SMTP_REPLY_TO ? { replyTo: SMTP_REPLY_TO } : {}),
            subject: "We received your feedback - Novyn",
            text: [
              `Hi ${fromUser === "anonymous" ? "there" : fromUser},`,
              "",
              "Thanks for taking the time to share feedback with Novyn.",
              "Your submission has been received by our team. If we need more details, we may reply to this email.",
              "",
              `Category: ${typeLabel}`,
              `Rating: ${stars}`,
              "",
              "Your message:",
              message,
              "",
              `Reference: ${entry.id}`,
              "",
              "The Novyn team",
            ].join("\n"),
            html: `
              <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:28px;background:#f5f3ff;color:#171936;border-radius:20px;">
                <div style="padding:26px;background:#ffffff;border-radius:16px;">
                  <div style="width:46px;height:46px;border-radius:14px;background:#eee9ff;color:#6048e8;display:flex;align-items:center;justify-content:center;font-size:24px;">✓</div>
                  <h2 style="margin:18px 0 8px;color:#171936;">Thanks for helping us improve Novyn.</h2>
                  <p style="color:#66708a;line-height:1.6;">We have received your feedback and it has been recorded for the Novyn team.</p>
                  <div style="margin:18px 0;padding:16px;background:#f5f2ff;border-radius:12px;">
                    <p style="margin:0 0 8px;color:#6048e8;font-weight:700;">${escapeHtml(typeLabel)} · ${escapeHtml(stars)}</p>
                    <div style="line-height:1.7;white-space:normal;">${safeMessage}</div>
                  </div>
                  <p style="color:#8991a6;font-size:12px;">Reference: ${safeId}</p>
                  <p style="color:#66708a;font-size:13px;">- The Novyn team</p>
                </div>
              </div>
            `,
          });
          receiptEmailSent = true;
        } catch (err) {
          console.warn("[NovynFeedback] Submitter receipt email failed:", err?.message || err);
        }
      }

      // SMTP delivery is best-effort after the saved response has been sent.
      // Delivery failures are logged above and do not turn a saved submission into a timeout.
    }
  );
}

const distDir = path.resolve(__dirname, "../web/dist");
const publicDir = path.resolve(__dirname, "../web/public");

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
    res.sendFile(path.join(publicDir, "404.html"));
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
  socket.on("join_random_game", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey || onlineUsers.get(userKey) !== socket.id) return respond({ ok: false, message: "Please sign in again before matchmaking." });
    if (!allowSocketAction(socket, "join_random_game", 4, 60_000)) return respond({ ok: false, message: "Please wait before trying matchmaking again." });
    const user = users.get(userKey);
    const excludedUsers = Array.from(new Set([
      ...Array.from(user?.friends || []),
      ...Array.from(user?.blockedUsers || []),
    ].map(normalizeName).filter(Boolean)));
    const result = publicGameMatchmaking.join({
      userKey, displayName: toDisplayName(user?.displayName || user?.username || userKey),
      socketId: socket.id, gameType: payload?.gameType,
      level: payload?.playerLevel, excludedUsers,
    });
    if (!result.ok) return respond(result);
    if (!result.matched) return respond({ ok: true, queued: true, timeoutMs: 60_000 });

    const [first, second] = result.players;
    const challenge = createGameChallenge({
      userKey: first.userKey,
      userDisplayName: first.userKey,
      to: second.userKey,
      toType: "friend",
      game: { id: "random_" + result.sessionId, gameType: result.gameType },
    });
    if (!challenge.ok) {
      io.to(first.socketId).emit("random_match_timeout", { gameType: result.gameType, message: challenge.reason || "This game is unavailable right now." });
      return respond({ ok: false, message: challenge.reason || "This game is unavailable right now." });
    }

    const game = challenge.game;
    const expiryTimer = setTimeout(() => randomGameSessions.delete(result.sessionId), RANDOM_GAME_SESSION_TTL_MS);
    if (typeof expiryTimer.unref === "function") expiryTimer.unref();
    randomGameSessions.set(result.sessionId, {
      game,
      players: [first.userKey, second.userKey],
      expiresAt: Date.now() + RANDOM_GAME_SESSION_TTL_MS,
      expiryTimer,
    });

    const packet = (opponent) => ({
      sessionId: result.sessionId,
      gameType: result.gameType,
      game,
      opponent: {
        username: opponent.userKey,
        displayName: opponent.displayName,
        ...(Number.isInteger(opponent.level) ? { level: opponent.level } : {}),
      },
    });
    io.to(first.socketId).emit("random_match_found", packet(second));
    io.to(second.socketId).emit("random_match_found", packet(first));
    return respond({ ok: true, matched: true, sessionId: result.sessionId, game });
  });

  socket.on("cancel_random_game", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    return respond({ ok: true, cancelled: publicGameMatchmaking.cancel(userKey) });
  });

  socket.on("join_rajamantri_matchmaking", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey || onlineUsers.get(userKey) !== socket.id) {
      return respond({ ok: false, message: "Please sign in again before matchmaking." });
    }
    if (!allowSocketAction(socket, "join_rajamantri_matchmaking", 3, 60_000)) {
      return respond({ ok: false, message: "Please wait before trying matchmaking again." });
    }
    const user = users.get(userKey);
    const excludedUsers = Array.from(new Set([
      ...Array.from(user?.friends || []),
      ...Array.from(user?.blockedUsers || []),
    ].map(normalizeName).filter(Boolean)));
    const result = rajaMantriMatchmaking.join({
      userKey,
      displayName: toDisplayName(user?.displayName || user?.username || userKey),
      socketId: socket.id,
      playerCount: payload?.playerCount,
      excludedUsers,
    });
    if (!result.ok) return respond(result);
    if (!result.matched) {
      return respond({
        ok: true,
        queued: true,
        playerCount: result.playerCount,
        playersFound: result.playersFound,
        timeoutMs: result.timeoutMs,
      });
    }
    let gameSession;
    try {
      gameSession = createRajaMantriGameSession({
        sessionId: result.matchId,
        playerCount: result.playerCount,
        players: result.players.map((player) => ({
          username: player.username,
          displayName: player.displayName,
        })),
      });
    } catch (error) {
      for (const player of result.players) {
        io.to(player.socketId).emit("rajamantri_match_timeout", {
          playerCount: result.playerCount,
          message: "A complete room could not be created. Please search again.",
        });
      }
      return respond({ ok: false, message: "A complete room could not be created. Please search again." });
    }
    const expiryTimer = setTimeout(
      () => expireRajaMantriSession(result.matchId),
      RAJA_MANTRI_SESSION_TTL_MS,
    );
    if (typeof expiryTimer.unref === "function") expiryTimer.unref();
    const sessionEntry = { game: gameSession, expiryTimer, responseTimer: null, responseTimerDeadline: 0 };
    rajaMantriSessions.set(result.matchId, sessionEntry);
    scheduleRajaMantriPhaseTimer(sessionEntry);
    const packet = {
      matchId: result.matchId,
      sessionId: result.matchId,
      playerCount: result.playerCount,
      players: result.players.map((player, index) => ({
        username: player.username,
        displayName: player.displayName,
        seat: index,
      })),
    };
    for (const player of result.players) {
      io.to(player.socketId).emit("rajamantri_match_found", packet);
    }
    return respond({ ok: true, matched: true, ...packet });
  });

  socket.on("cancel_rajamantri_matchmaking", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey || onlineUsers.get(userKey) !== socket.id) {
      return respond({ ok: false, message: "Please sign in again." });
    }
    return respond({ ok: true, cancelled: rajaMantriMatchmaking.cancel(userKey) });
  });

  socket.on("leave_rajamantri_game", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim().slice(0, 128);
    const entry = rajaMantriSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !entry) {
      return respond({ ok: false, message: "This Raja Mantri match is no longer available." });
    }
    const leavingPlayer = entry.game.players.find((player) => player.username === userKey && !player.isBot);
    if (!leavingPlayer) {
      return respond({ ok: false, message: "You are not a player in this match." });
    }
    const connection = setRajaMantriPlayerConnected(entry.game, userKey, false);
    if (!connection.ok) return respond({ ok: false, message: connection.reason });
    scheduleRajaMantriPhaseTimer(entry);
    emitRajaMantriGameUpdate(entry.game);
    for (const player of entry.game.players) {
      if (player.isBot || player.username === userKey) continue;
      const targetSocket = onlineUsers.get(player.username);
      if (targetSocket) {
        io.to(targetSocket).emit("rajamantri_player_connection", {
          sessionId,
          username: userKey,
          displayName: leavingPlayer.displayName,
          connected: false,
          autoPlay: true,
        });
      }
    }
    return respond({ ok: true, autoPlay: true });
  });

  socket.on("get_rajamantri_game", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim().slice(0, 128);
    const entry = rajaMantriSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !entry) {
      return respond({ ok: false, message: "This Raja Mantri match is no longer available." });
    }
    const game = getRajaMantriGameView(entry.game, userKey);
    if (!game) return respond({ ok: false, message: "You are not a player in this match." });
    return respond({ ok: true, game });
  });

  socket.on("pick_rajamantri_chit", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim().slice(0, 128);
    const entry = rajaMantriSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !entry) {
      return respond({ ok: false, message: "This Raja Mantri match is no longer available." });
    }
    if (!allowSocketAction(socket, "pick_rajamantri_chit", 8, 10_000)) {
      return respond({ ok: false, message: "Please wait before picking again." });
    }
    const result = pickRajaMantriChit(entry.game, userKey);
    if (!result.ok) return respond({ ok: false, message: result.reason });
    scheduleRajaMantriPhaseTimer(entry);
    emitRajaMantriGameUpdate(entry.game);
    return respond({ ok: true, game: getRajaMantriGameView(entry.game, userKey) });
  });

  socket.on("guess_rajamantri_chor", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim().slice(0, 128);
    const suspectUsername = normalizeName(payload?.suspectUsername || "");
    const entry = rajaMantriSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !entry) {
      return respond({ ok: false, message: "This Raja Mantri match is no longer available." });
    }
    if (!allowSocketAction(socket, "guess_rajamantri_chor", 6, 10_000)) {
      return respond({ ok: false, message: "Please wait before guessing again." });
    }
    const result = guessRajaMantriChor(entry.game, userKey, suspectUsername);
    if (!result.ok) return respond({ ok: false, message: result.reason });
    scheduleRajaMantriPhaseTimer(entry);
    emitRajaMantriGameUpdate(entry.game);
    return respond({ ok: true, game: getRajaMantriGameView(entry.game, userKey) });
  });

  socket.on("advance_rajamantri_round", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim().slice(0, 128);
    const entry = rajaMantriSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !entry) {
      return respond({ ok: false, message: "This Raja Mantri match is no longer available." });
    }
    if (!allowSocketAction(socket, "advance_rajamantri_round", 5, 30_000)) {
      return respond({ ok: false, message: "Please wait before continuing the round." });
    }
    const result = advanceRajaMantriRound(entry.game, userKey);
    if (!result.ok) return respond({ ok: false, message: result.reason });
    scheduleRajaMantriPhaseTimer(entry);
    emitRajaMantriGameUpdate(entry.game);
    return respond({ ok: true, game: getRajaMantriGameView(entry.game, userKey) });
  });

  socket.on("get_pending_game_invites", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey || onlineUsers.get(userKey) !== socket.id) {
      return respond({ ok: false, message: "Reconnect to load game invitations." });
    }
    const invitations = [];
    for (const [messageId, invite] of pendingGameInvites.entries()) {
      if (invite.toKey !== userKey || invite.accepted === true || invite.expiresAt <= Date.now()) continue;
      const inviter = users.get(invite.fromKey);
      if (!inviter || usersAreBlocked(invite.fromKey, userKey)) continue;
      invitations.push({
        messageId,
        from: inviter.username || invite.fromKey,
        displayName: inviter.displayName || inviter.username || invite.fromKey,
        avatarId: inviter.avatarId || "",
        gameType: invite.gameType,
        game: invite.game || null,
        expiresAt: invite.expiresAt,
      });
    }
    invitations.sort((a, b) => a.expiresAt - b.expiresAt);
    return respond({ ok: true, invitations });
  });

  socket.on("accept_game_invite", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const messageId = toDisplayName(payload?.messageId).slice(0, 128);
    const invite = pendingGameInvites.get(messageId);
    if (!userKey || !invite || invite.toKey !== userKey || invite.expiresAt <= Date.now()) {
      pendingGameInvites.delete(messageId);
      return respond({ ok: false, message: "This game invite has expired." });
    }
    clearTimeout(invite.timer);
    if (invite.gameType === "rajamantri") {
      // RMCS invitations stay reserved after acceptance until the host starts
      // the complete 3P/4P room. This keeps a joined player addressable.
      invite.accepted = true;
      invite.acceptedAt = Date.now();
      invite.acceptedSocketId = socket.id;
      invite.expiresAt = Date.now() + 5 * 60 * 1000;
      invite.timer = setTimeout(() => {
        if (pendingGameInvites.get(messageId) !== invite) return;
        pendingGameInvites.delete(messageId);
        const hostSocketId = onlineUsers.get(invite.fromKey);
        if (hostSocketId) {
          io.to(hostSocketId).emit("game_invite_timeout", { messageId, gameType: invite.gameType });
        }
        if (invite.acceptedSocketId) {
          io.to(invite.acceptedSocketId).emit("game_invite_timeout", { messageId, gameType: invite.gameType });
        }
      }, 5 * 60 * 1000);
      if (typeof invite.timer.unref === "function") invite.timer.unref();
    } else {
      pendingGameInvites.delete(messageId);
    }
    const senderSocketId = onlineUsers.get(invite.fromKey);
    if (senderSocketId) {
      io.to(senderSocketId).emit("game_invite_accepted", {
        messageId,
        gameType: invite.gameType,
        from: userKey,
      });
    }
    return respond({ ok: true, waitingForHost: invite.gameType === "rajamantri" });
  });

  socket.on("reject_game_invite", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const messageId = toDisplayName(payload?.messageId).slice(0, 128);
    const invite = pendingGameInvites.get(messageId);
    if (!userKey || !invite || invite.toKey !== userKey || invite.expiresAt <= Date.now()) {
      return respond({ ok: false, message: "This game invite is no longer active." });
    }
    clearTimeout(invite.timer);
    pendingGameInvites.delete(messageId);
    const senderSocketId = onlineUsers.get(invite.fromKey);
    if (senderSocketId) {
      io.to(senderSocketId).emit("game_invite_rejected", {
        messageId,
        gameType: invite.gameType,
        by: userKey,
      });
    }
    return respond({ ok: true });
  });

  socket.on("cancel_game_invite", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const messageId = toDisplayName(payload?.messageId).slice(0, 128);
    const invite = pendingGameInvites.get(messageId);
    if (!userKey || !invite || invite.fromKey !== userKey) {
      return respond({ ok: false, message: "This invite is no longer active." });
    }
    clearTimeout(invite.timer);
    pendingGameInvites.delete(messageId);
    if (invite.acceptedSocketId) {
      io.to(invite.acceptedSocketId).emit("game_invite_timeout", {
        messageId,
        gameType: invite.gameType,
        reason: "cancelled",
      });
    }
    return respond({ ok: true });
  });

  socket.on("leave_rajamantri_invite", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const messageId = toDisplayName(payload?.messageId).slice(0, 128);
    const invite = pendingGameInvites.get(messageId);
    if (!userKey || !invite || invite.gameType !== "rajamantri" ||
        invite.toKey !== userKey || invite.acceptedSocketId !== socket.id || !invite.accepted) {
      return respond({ ok: false, message: "This room invitation is no longer active." });
    }
    clearTimeout(invite.timer);
    pendingGameInvites.delete(messageId);
    const hostSocketId = onlineUsers.get(invite.fromKey);
    if (hostSocketId) {
      io.to(hostSocketId).emit("game_invite_timeout", {
        messageId,
        gameType: invite.gameType,
        reason: "left",
      });
    }
    return respond({ ok: true });
  });

  socket.on("start_rajamantri_friend_room", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey || onlineUsers.get(userKey) !== socket.id) {
      return respond({ ok: false, message: "Please sign in again before starting this room." });
    }
    if (!allowSocketAction(socket, "start_rajamantri_friend_room", 3, 60_000)) {
      return respond({ ok: false, message: "Please wait before starting another room." });
    }
    const playerCount = Number(payload?.playerCount);
    const inviteIds = Array.isArray(payload?.inviteMessageIds)
      ? payload.inviteMessageIds.map((value) => String(value || "").trim().slice(0, 128)).filter(Boolean)
      : [];
    const botCount = Number(payload?.botCount);
    if (![3, 4].includes(playerCount) || !Number.isInteger(botCount) ||
        botCount < 0 || inviteIds.length + botCount !== playerCount - 1) {
      return respond({ ok: false, message: "Every seat must be filled by a joined friend or a bot." });
    }
    if (new Set(inviteIds).size !== inviteIds.length) {
      return respond({ ok: false, message: "Duplicate friend invitations were supplied." });
    }
    const invites = [];
    for (const messageId of inviteIds) {
      const invite = pendingGameInvites.get(messageId);
      if (!invite || invite.fromKey !== userKey || invite.gameType !== "rajamantri" ||
          invite.accepted !== true || invite.expiresAt <= Date.now() ||
          onlineUsers.get(invite.toKey) !== invite.acceptedSocketId) {
        return respond({ ok: false, message: "One of the invited friends is no longer ready. Refresh the room." });
      }
      invites.push({ messageId, invite });
    }
    const host = users.get(userKey);
    const players = [{
      username: userKey,
      displayName: toDisplayName(host?.displayName || host?.username || userKey),
      isBot: false,
    }];
    for (const { invite } of invites) {
      const friend = users.get(invite.toKey);
      players.push({
        username: invite.toKey,
        displayName: toDisplayName(friend?.displayName || friend?.username || invite.toKey),
        isBot: false,
      });
    }
    const matchId = crypto.randomUUID();
    for (let index = 0; index < botCount; index += 1) {
      players.push({
        username: "bot_" + matchId.replace(/-/g, "").slice(0, 12) + "_" + (index + 1),
        displayName: "Bot " + (index + 1),
        isBot: true,
      });
    }
    let game;
    try {
      game = createRajaMantriGameSession({ sessionId: matchId, playerCount, players });
    } catch (_) {
      return respond({ ok: false, message: "Could not create the Raja Mantri room." });
    }
    const expiryTimer = setTimeout(() => expireRajaMantriSession(matchId), RAJA_MANTRI_SESSION_TTL_MS);
    if (typeof expiryTimer.unref === "function") expiryTimer.unref();
    const sessionEntry = { game, expiryTimer, responseTimer: null, responseTimerDeadline: 0 };
    rajaMantriSessions.set(matchId, sessionEntry);
    scheduleRajaMantriPhaseTimer(sessionEntry);
    for (const { messageId, invite } of invites) {
      clearTimeout(invite.timer);
      pendingGameInvites.delete(messageId);
    }
    const packet = {
      sessionId: matchId,
      playerCount,
      players: players.map((player, seat) => ({
        username: player.username,
        displayName: player.displayName,
        seat,
        isBot: player.isBot,
      })),
    };
    for (const { messageId, invite } of invites) {
      const targetSocket = onlineUsers.get(invite.toKey);
      if (targetSocket) {
        io.to(targetSocket).emit("rajamantri_room_started", {
          ...packet,
          messageId,
        });
      }
    }
    return respond({
      ok: true,
      sessionId: matchId,
      playerCount,
      players: packet.players,
    });
  });

  socket.on("random_game_move", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const sessionId = String(payload?.sessionId || "").trim();
    const session = randomGameSessions.get(sessionId);
    if (!userKey || onlineUsers.get(userKey) !== socket.id || !session) {
      return respond({ ok: false, message: "This random game session is no longer available." });
    }
    if (session.expiresAt <= Date.now()) {
      clearTimeout(session.expiryTimer);
      randomGameSessions.delete(sessionId);
      return respond({ ok: false, message: "This random game has expired. Start a new match." });
    }
    if (!session.players.includes(userKey)) {
      return respond({ ok: false, message: "You are not a player in this game." });
    }

    const result = applyGameMove(session.game, userKey, payload?.moveData);
    if (!result.ok) {
      return respond({ ok: false, message: result.reason || "Invalid game move." });
    }

    session.game = result.game;
    const packet = {
      sessionId,
      game: session.game,
      updatedBy: userKey,
    };
    respond({ ok: true, game: session.game });
    for (const playerKey of session.players) {
      const playerSocketId = onlineUsers.get(playerKey);
      if (playerSocketId) io.to(playerSocketId).emit("random_game_updated", packet);
    }
  });
  // Prevent a copied private URL from being laundered into another conversation
  // through sending, forwarding, editing, or wallpaper/profile updates.
  socket.use((packet, next) => {
    const userKey = normalizeName(socket.data.userKey || '');
    const session = socket.data.sessionId && refreshSessions.get(socket.data.sessionId);
    if (userKey && (users.get(userKey)?.isSuspended === true ||
      (socket.data.sessionId && (!session || session.expiresAt <= Date.now())) ||
      socket.data.passwordHashSnapshot !== users.get(userKey)?.passwordHash)) {
      socket.emit('auth_failed', { message: 'Session expired. Please sign in again.' });
      socket.disconnect(true);
      return;
    }
    const names = mediaNames(packet.slice(1).filter((item) => typeof item !== 'function'));
    if (names.some((filename) => !userCanReadMedia(filename, userKey))) {
      const result = { ok: false, message: 'You do not have access to this media.' };
      const callback = packet[packet.length - 1];
      if (typeof callback === 'function') callback(result);
      else socket.emit('error_message', result);
      return;
    }
    next();
  });
  const authenticatedUser = users.get(normalizeName(socket.data.userKey || ""));
  if (authenticatedUser?.isRegistered) {
    finalizeSocketAuthentication(socket, authenticatedUser);
  }

  socket.on("discover_online", () => {
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return;
    socket.emit("discover_online", {
      users: buildDiscoverOnlineList(userKey),
    });
  });

  socket.on("resume_session", () => {
    const userKey = resolveCurrentUserKey(socket.data.userKey);
    if (!userKey) {
      socket.emit("auth_failed", { message: "Session expired. Please sign in again." });
      return;
    }
    const user = users.get(userKey);
    if (!user || !user.isRegistered || user.isSuspended === true) {
      socket.emit("auth_failed", { message: "Session expired. Please sign in again." });
      return;
    }
    finalizeSocketAuthentication(socket, user);
  });
  socket.on("register", async (payload) => {
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
        if (!(await verifyPassword(password, existingByEmail.passwordSalt, existingByEmail.passwordHash))) {
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
        const secret = await createPasswordSecret(password);
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
        socket.emit('auth_failed', { message: 'Use Google sign-in or reset your password for this account.' });
        return;
      } else if (!(await verifyPassword(password, existing.passwordSalt, existing.passwordHash))) {
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
    if (!allowSocketAction(socket, 'request_password_reset', 10, 15 * 60 * 1000)) {
      return socket.emit('password_reset_failed', { message: 'Too many requests. Try again later.' });
    }
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

  socket.on("reset_password", async (payload) => {
    if (!allowSocketAction(socket, 'reset_password', 30, 15 * 60 * 1000)) {
      return socket.emit('password_reset_failed', { message: 'Too many attempts. Try again later.' });
    }
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

    const secret = await createPasswordSecret(newPassword);
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
    user.emailVerified = true;
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

  socket.on("register_fcm_token", (payload, callback) => {
    const respond = (result) => { if (typeof callback === "function") callback(result); };
    const userKey = socket.data.userKey;
    const user = userKey ? users.get(userKey) : null;
    const token = toDisplayName(payload?.token);
    if (!user) { respond({ ok: false, message: "Sign in again before registering this device." }); return; }
    if (token.length < 40 || token.length > 4096) {
      respond({ ok: false, message: "Invalid device notification token." });
      return;
    }
    user.fcmToken = token;
    schedulePersist();
    respond({ ok: true });
  });

  socket.on("clear_fcm_token", (callback) => {
    const respond = (result) => { if (typeof callback === "function") callback(result); };
    const userKey = socket.data.userKey;
    const user = userKey ? users.get(userKey) : null;
    if (!user) { respond({ ok: false, message: "Sign in again before clearing this device." }); return; }
    user.fcmToken = "";
    schedulePersist();
    respond({ ok: true });
  });

  socket.on("get_account_settings", (payload, callback) => {
    const respond = (result) => { if (typeof callback === "function") callback(result); };
    const userKey = socket.data.userKey;
    if (!userKey) { respond({ ok: false, message: "Sign in again to load privacy settings." }); return; }
    const user = users.get(userKey);
    if (!user) { respond({ ok: false, message: "Account not found." }); return; }
    respond({
      ok: true,
      settings: {
        callsEnabled: user.callsEnabled !== false,
        callPrivacy: user.callPrivacy || "friends",
        messagePrivacy: user.messagePrivacy || "friends",
        profilePhotoPrivacy: user.profilePhotoPrivacy || "everyone",
        presencePrivacy: user.presencePrivacy || "everyone", discoverPrivacy: user.discoverPrivacy || "everyone",
        groupInvitePrivacy: user.groupInvitePrivacy || "friends",
        friendRequestPrivacy: user.friendRequestPrivacy || "everyone",
        readReceiptsEnabled: user.readReceiptsEnabled !== false,
        typingIndicatorsEnabled: user.typingIndicatorsEnabled !== false,
        notificationsEnabled: user.notificationsEnabled !== false,
        messagePreviewEnabled: user.messagePreviewEnabled !== false,
        hideNotificationContent: user.hideNotificationContent === true,
        doNotDisturbEnabled: user.doNotDisturbEnabled === true,
        favoriteChatIds: Array.isArray(user.favoriteChatIds) ? user.favoriteChatIds : [],
        groupNotificationsEnabled: user.groupNotificationsEnabled !== false,
        directMessagesEnabled: user.directMessagesEnabled !== false,
        groupMessagesEnabled: typeof user.groupMessagesEnabled === "boolean"
          ? user.groupMessagesEnabled
          : user.groupNotificationsEnabled !== false,
        mentionsRepliesEnabled: user.mentionsRepliesEnabled !== false,
        friendRequestsEnabled: user.friendRequestsEnabled !== false,
        friendRequestAcceptedEnabled: user.friendRequestAcceptedEnabled !== false,
        groupInvitationsEnabled: user.groupInvitationsEnabled !== false,
        voiceCallsEnabled: user.voiceCallsEnabled !== false,
        videoCallsEnabled: user.videoCallsEnabled !== false,
        missedCallsEnabled: user.missedCallsEnabled !== false,
        gameInvitationsEnabled: user.gameInvitationsEnabled !== false,
        gameTurnEnabled: user.gameTurnEnabled !== false,
        gameResultsEnabled: user.gameResultsEnabled !== false,
        quietHoursEnabled: user.quietHoursEnabled === true,
        quietHoursStart: user.quietHoursStart || "22:00",
        quietHoursEnd: user.quietHoursEnd || "07:00",
        quietHoursOffsetMinutes: Number(user.quietHoursOffsetMinutes) || 0,
        notificationSoundEnabled: user.notificationSoundEnabled !== false,
        notificationVibrationEnabled: user.notificationVibrationEnabled !== false,
        mutedChats: Array.from(user.mutedUsers || []),
      },
    });
  });

  socket.on("update_profile", (payload, callback) => {
    const respond = (result) => { if (typeof callback === "function") callback(result); };
    const userKey = socket.data.userKey;
    if (!userKey) { respond({ ok: false, message: "Sign in again before changing account settings." }); return; }
    const user = users.get(userKey);
    if (!user) { respond({ ok: false, message: "Account not found." }); return; }

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
    if (payload?.retentionDays !== undefined) {
      const days = Number(payload.retentionDays);
      if (days === 0) user.retentionDays = 0;
    }
    const privacyChoices = { callPrivacy: ["everyone", "friends", "nobody"], messagePrivacy: ["everyone", "friends", "nobody"], profilePhotoPrivacy: ["everyone", "friends", "nobody"], presencePrivacy: ["everyone", "friends", "nobody"], discoverPrivacy: ["everyone", "friends", "nobody"], groupInvitePrivacy: ["everyone", "friends", "nobody"], friendRequestPrivacy: ["everyone", "mutuals", "nobody"] };
    for (const [key, choices] of Object.entries(privacyChoices)) if (choices.includes(payload?.[key])) user[key] = payload[key];
    if (typeof payload?.callsEnabled === "boolean") user.callsEnabled = payload.callsEnabled;
    if (typeof payload?.notificationsEnabled === "boolean") user.notificationsEnabled = payload.notificationsEnabled;
    if (typeof payload?.messagePreviewEnabled === "boolean") user.messagePreviewEnabled = payload.messagePreviewEnabled;
    if (typeof payload?.hideNotificationContent === "boolean") user.hideNotificationContent = payload.hideNotificationContent;
    if (typeof payload?.doNotDisturbEnabled === "boolean") user.doNotDisturbEnabled = payload.doNotDisturbEnabled;
    if (Array.isArray(payload?.favoriteChatIds)) {
      user.favoriteChatIds = Array.from(new Set(
        payload.favoriteChatIds.map(normalizeName).filter(Boolean)
      )).slice(0, 250);
    }
    if (typeof payload?.groupNotificationsEnabled === "boolean") user.groupNotificationsEnabled = payload.groupNotificationsEnabled;
    const notificationBooleanKeys = [
      "directMessagesEnabled", "groupMessagesEnabled", "mentionsRepliesEnabled",
      "friendRequestsEnabled", "friendRequestAcceptedEnabled", "groupInvitationsEnabled",
      "voiceCallsEnabled", "videoCallsEnabled", "missedCallsEnabled",
      "gameInvitationsEnabled", "gameTurnEnabled", "gameResultsEnabled",
      "quietHoursEnabled", "notificationSoundEnabled", "notificationVibrationEnabled",
    ];
    for (const key of notificationBooleanKeys) {
      if (typeof payload?.[key] === "boolean") user[key] = payload[key];
    }
    if (typeof payload?.quietHoursStart === "string" &&
        /^([01]\d|2[0-3]):[0-5]\d$/.test(payload.quietHoursStart)) user.quietHoursStart = payload.quietHoursStart;
    if (typeof payload?.quietHoursEnd === "string" &&
        /^([01]\d|2[0-3]):[0-5]\d$/.test(payload.quietHoursEnd)) user.quietHoursEnd = payload.quietHoursEnd;
    if (Number.isFinite(Number(payload?.quietHoursOffsetMinutes))) {
      user.quietHoursOffsetMinutes = Math.max(-840, Math.min(840, Number(payload.quietHoursOffsetMinutes)));
    }
    if (typeof payload?.groupMessagesEnabled === "boolean") {
      user.groupNotificationsEnabled = payload.groupMessagesEnabled;
    }
    if (payload?.callsEnabled === false) {
      cancelCallForUser(userKey, { activeCalls, clearCallPair, onlineUsers, io, users },
        "Calls were disabled in your status mode.");
    }
    if (typeof payload?.readReceiptsEnabled === "boolean") user.readReceiptsEnabled = payload.readReceiptsEnabled;
    if (typeof payload?.typingIndicatorsEnabled === "boolean") user.typingIndicatorsEnabled = payload.typingIndicatorsEnabled;
    if (typeof payload?.stealthModeEnabled === "boolean") user.stealthModeEnabled = payload.stealthModeEnabled;

    schedulePersist();

    socket.emit("profile_updated", {
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatarId: user.avatarId,
      presenceMode: user.presenceMode,
      email: user.email || "",
      retentionDays: 0,
      callsEnabled: user.callsEnabled !== false,
        callPrivacy: user.callPrivacy || "friends", messagePrivacy: user.messagePrivacy || "friends",
      profilePhotoPrivacy: user.profilePhotoPrivacy || "everyone", presencePrivacy: user.presencePrivacy || "everyone", discoverPrivacy: user.discoverPrivacy || "everyone",
      readReceiptsEnabled: user.readReceiptsEnabled !== false, typingIndicatorsEnabled: user.typingIndicatorsEnabled !== false,
      groupInvitePrivacy: user.groupInvitePrivacy || "friends", friendRequestPrivacy: user.friendRequestPrivacy || "everyone",
      stealthModeEnabled: user.stealthModeEnabled === true,
      twoFactorEnabled: Boolean(user.twoFactorEnabled),
    });
    respond({ ok: true });

    emitFriendList(userKey);
    emitStatusToFriends(userKey);
    emitGroupListUpdatesForUser(userKey);
    for (const friendKey of user.friends) {
      if (usersAreBlocked(userKey, friendKey)) continue;
      emitFriendList(friendKey);
      const friendSocket = onlineUsers.get(friendKey);
      if (friendSocket) {
        io.to(friendSocket).emit("user_profile_updated", {
          username: user.username,
          displayName: user.displayName,
          bio: user.bio,
          avatarId: privacyAllows(user, friendKey, "profilePhotoPrivacy") ? user.avatarId : "",
          presenceMode: privacyAllows(user, friendKey, "presencePrivacy") ? getDisplayPresence(userKey) : "offline",
        });
      }
    }
    if (typeof payload?.stealthModeEnabled === "boolean") {
      for (const friendKey of user.friends) {
        if (usersAreBlocked(userKey, friendKey)) continue;
        const friendSocketId = onlineUsers.get(friendKey);
        if (!friendSocketId) continue;
        const friendSocket = io.sockets.sockets.get(friendSocketId);
        if (friendSocket?.data?.activeChatWith === userKey && friendSocket?.data?.activeChatKind === "friend") {
          io.to(friendSocketId).emit("chat_protection_updated", {
            username: user.username,
            protected: user.stealthModeEnabled === true,
          });
        }
      }
    }
    emitDiscoverOnlineToAll();
  });

  socket.on("change_username", async (payload) => {
    try {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("username_change_failed", { message: "User not found." });
      return;
    }

    const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
    const desired = normalizeHandleInput(payload?.newUsername);
    if (!/^[a-z0-9_]{3,24}$/.test(desired)) {
      socket.emit("username_change_failed", {
        message: "Username must be 3–24 characters using lowercase letters, numbers, or underscores.",
      });
      return;
    }

    const hasExistingPassword = Boolean(user.passwordHash && user.passwordSalt);
    if (hasExistingPassword) {
      if (!currentPassword || !(await verifyPassword(currentPassword, user.passwordSalt, user.passwordHash))) {
        socket.emit("username_change_failed", { message: "Incorrect password." });
        return;
      }
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
    } catch (err) {
      console.error("Username change failed unexpectedly:", err);
      socket.emit("username_change_failed", {
        message: "Could not change username. Your account remains available; please try again.",
      });
    }
  });

  socket.on("change_password", async (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("password_change_failed", { message: "User not found." });
      return;
    }

    const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
    const nextPassword = toDisplayName(payload?.newPassword);

    const hasExistingPassword = Boolean(user.passwordHash && user.passwordSalt);
    if (hasExistingPassword) {
      if (!currentPassword || !(await verifyPassword(currentPassword, user.passwordSalt, user.passwordHash))) {
        socket.emit("password_change_failed", { message: "Incorrect current password." });
        return;
      }
    }
    if (!nextPassword || nextPassword.length < MIN_PASSWORD_LENGTH) {
      socket.emit("password_change_failed", {
        message: `Use at least ${MIN_PASSWORD_LENGTH} characters in password.`,
      });
      return;
    }

    const secret = await createPasswordSecret(nextPassword);
    user.passwordSalt = secret.passwordSalt;
    user.passwordHash = secret.passwordHash;
    revokeAllRefreshSessionsForUser(userKey);
    schedulePersist();

    socket.emit("password_changed", { hasPassword: true });
  });

  socket.on("delete_account", async (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("account_deletion_failed", { message: "User not found." });
      return;
    }

    const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
    const confirmationText = toDisplayName(payload?.confirmationText || payload?.confirm);
    const isHandleMatch =
      confirmationText.toLowerCase() === `@${user.username}`.toLowerCase() ||
      confirmationText.toLowerCase() === user.username.toLowerCase();
    const hasExistingPassword = Boolean(user.passwordHash && user.passwordSalt);

    // Always require the explicit handle confirmation. A client-supplied
    // "confirmed" flag must never bypass this server-side check.
    if (!isHandleMatch) {
      socket.emit("account_deletion_failed", {
        message: `Please type @${user.username} to confirm account deletion.`,
      });
      return;
    }
    if (hasExistingPassword &&
        (!currentPassword || !(await verifyPassword(currentPassword, user.passwordSalt, user.passwordHash)))) {
      socket.emit("account_deletion_failed", { message: "Incorrect password." });
      return;
    }

    try {
      await removeUserAccount(userKey, { disconnectSockets: false });
    } catch (error) {
      socket.emit("account_deletion_failed", {
        message: error?.publicMessage || "Could not delete the account. Please try again later.",
      });
      return;
    }

    socket.emit("account_deleted", { success: true });
    setTimeout(() => {
      try { socket.disconnect(true); } catch (_) {}
    }, 500);
  });

  socket.on("enable_2fa", async (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("2fa_error", { message: "User not found." });
      return;
    }

    const secret = toDisplayName(payload?.secret);
    const code = toDisplayName(payload?.code);
    const backupCodes = Array.isArray(payload?.backupCodes) ? payload.backupCodes.map(toDisplayName).filter(Boolean) : [];

    if (!verifyTotpCode(secret, code)) {
      socket.emit("2fa_error", { message: "Invalid 6-digit verification code. Please check your authenticator app and device time." });
      return;
    }

    user.twoFactorEnabled = true;
    user.twoFactorSecret = encryptTotpSecret(secret);
    user.twoFactorBackupCodes = backupCodes;
    schedulePersist();

    socket.emit("2fa_status", { enabled: true, backupCodesCount: backupCodes.length, backupCodes });
  });

  socket.on("disable_2fa", async (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) {
      socket.emit("2fa_error", { message: "User not found." });
      return;
    }

    const hasExistingPassword = Boolean(user.passwordHash && user.passwordSalt);
    if (hasExistingPassword) {
      const currentPassword = toDisplayName(payload?.currentPassword || payload?.password);
      if (!currentPassword || !(await verifyPassword(currentPassword, user.passwordSalt, user.passwordHash))) {
        socket.emit("2fa_error", { message: "Incorrect password." });
        return;
      }
    }

    user.twoFactorEnabled = false;
    user.twoFactorSecret = "";
    user.twoFactorBackupCodes = [];
    schedulePersist();

    socket.emit("2fa_status", { enabled: false, backupCodesCount: 0, backupCodes: [] });
  });

  socket.on("get_2fa_status", () => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const user = users.get(userKey);
    if (!user) return;
    socket.emit("2fa_status", {
      enabled: Boolean(user.twoFactorEnabled),
      backupCodesCount: Array.isArray(user.twoFactorBackupCodes) ? user.twoFactorBackupCodes.length : 0,
      backupCodes: Boolean(user.twoFactorEnabled) && Array.isArray(user.twoFactorBackupCodes) ? user.twoFactorBackupCodes : [],
    });
  });

  socket.on("add_friend", (rawTarget, callback) => {
    const reply = (result) => {
      if (typeof callback === 'function') callback(result);
      else if (!result.ok) socket.emit('error_message', result);
    };
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return reply({ ok: false, message: "Sign in required." });
    if (!allowSocketAction(socket, 'add_friend', 30, 60 * 1000)) {
      return reply({ ok: false, message: "Too many friend requests. Please wait a minute." });
    }

    const targetText = toDisplayName(rawTarget).replace(/^@/, '');
    const target = targetText.includes("@")
      ? findUserByEmail(targetText)
      : users.get(normalizeName(targetText));
    const me = users.get(userKey);
    const targetKey = normalizeName(target?.username || targetText);

    if (!me || !target || !target.isRegistered || !targetKey) {
      reply({ ok: false, message: "User not found." });
      return;
    }
    if (targetKey === userKey) {
      reply({ ok: false, message: "You cannot add yourself." });
      return;
    }
    if (target.friendRequestPrivacy === "nobody" || (target.friendRequestPrivacy === "mutuals" && !Array.from(me.friends || []).some(friendKey => target.friends.has(friendKey)))) {
      reply({ ok: false, message: target.friendRequestPrivacy === "nobody" ? "This user is not accepting friend requests." : "Friend requests are limited to people with mutual friends." });
      return;
    }
    if (usersAreBlocked(userKey, targetKey)) {
      reply({ ok: false, message: "Friend request cannot be sent while one of you is blocked." });
      return;
    }
    if (me.friends.has(targetKey)) {
      reply({ ok: false, message: "You are already friends." });
      return;
    }
    if (target.requests.has(userKey)) {
      reply({ ok: true, username: target.username });
      return;
    }
    if (me.requests.has(targetKey)) {
      reply({ ok: false, message: "This user has already requested you. Accept their request in Contacts." });
      return;
    }

    target.requests.add(userKey);
    void sendPushToUser(targetKey, {
      type: "friend_request",
      title: "New friend request",
      body: (me.displayName || me.username) + " sent you a friend request",
      chat: me.username,
      from: me.username,
      eventId: "friend-request:" + userKey + ":" + Date.now(),
      tag: "friend-request-" + userKey,
    });
    reply({ ok: true, username: target.username });
    socket.emit("friend_request_sent", { to: target.username });
    emitRequests(targetKey);
    const targetSocket = onlineUsers.get(targetKey);
    if (targetSocket) {
      io.to(targetSocket).emit("friend_request_received", {
        from: me.username,
        displayName: me.displayName || me.username,
      });
    }
    emitDiscoverOnlineToAll();
    schedulePersist();
  });

  socket.on("cancel_friend_request", (rawTarget, callback) => {
    const reply = (result) => {
      if (typeof callback === 'function') callback(result);
      else if (!result.ok) socket.emit('error_message', result);
    };
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return reply({ ok: false, message: 'Sign in required.' });
    const targetKey = normalizeName(rawTarget);
    const me = users.get(userKey);
    const target = users.get(targetKey);
    if (!me || !target || !target.requests.has(userKey)) {
      reply({ ok: false, message: "No pending friend request found." });
      return;
    }

    target.requests.delete(userKey);
    reply({ ok: true });
    socket.emit("friend_request_cancelled", { to: target.username });
    emitRequests(targetKey);
    emitDiscoverOnlineToAll();
    schedulePersist();
  });

  socket.on("reject_friend", (rawRequester, callback) => {
    const reply = (result) => {
      if (typeof callback === "function") callback(result);
      else if (!result.ok) socket.emit("error_message", result);
    };
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return reply({ ok: false, message: "Sign in required." });
    const requesterKey = normalizeName(rawRequester);
    const me = users.get(userKey);
    const requester = users.get(requesterKey);
    if (!me || !requester || !me.requests.has(requesterKey)) {
      return reply({ ok: false, message: "No pending friend request found." });
    }

    me.requests.delete(requesterKey);
    emitRequests(userKey);
    const requesterSocket = onlineUsers.get(requesterKey);
    if (requesterSocket) {
      io.to(requesterSocket).emit("friend_request_cancelled", { to: me.username });
    }
    emitDiscoverOnlineToAll();
    schedulePersist();
    reply({ ok: true });
  });

  socket.on("accept_friend", (rawFriendName, callback) => {
    const reply = (result) => {
      if (typeof callback === "function") callback(result);
      else if (!result.ok) socket.emit("error_message", result);
    };
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return reply({ ok: false, message: "Sign in required." });

    const friendName = toDisplayName(rawFriendName);
    const friendKey = normalizeName(friendName);
    const me = users.get(userKey);
    const friend = users.get(friendKey);

    if (!me || !friend || !me.requests.has(friendKey)) {
      return reply({ ok: false, message: "No pending request from this user." });
    }
    if (usersAreBlocked(userKey, friendKey)) {
      return reply({ ok: false, message: "Friend request cannot be accepted while one of you is blocked." });
    }

    me.requests.delete(friendKey);
    me.friends.add(friendKey);
    friend.friends.add(userKey);
    initializeUnreadPair(userKey, friendKey);
    void sendPushToUser(friendKey, {
      type: "friend_request_accepted",
      title: "Request accepted",
      body: (me.displayName || me.username) + " accepted your friend request",
      chat: me.username,
      from: me.username,
      eventId: "friend-request-accepted:" + userKey + ":" + Date.now(),
      tag: "friend-request-accepted-" + userKey,
    });

    emitRequests(userKey);
    emitFriendList(userKey);
    emitFriendList(friendKey);
    socket.emit("friend_request_accepted", { by: friend.username });

    const friendSocket = onlineUsers.get(friendKey);
    if (friendSocket) {
      io.to(friendSocket).emit("friend_request_accepted", { by: me.username });
    }

    schedulePersist();
    reply({ ok: true, username: friend.username });
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

  socket.on("get_storage_inventory", (callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) { respond({ ok: false, message: "Please sign in again." }); return; }
    if (!allowSocketAction(socket, "get_storage_inventory", 6, 60 * 1000)) {
      respond({ ok: false, message: "Please wait before refreshing storage details." });
      return;
    }
    const me = users.get(userKey);
    if (!me) { respond({ ok: false, message: "Account not found." }); return; }
    const files = [];
    const addConversationFiles = (conversationKey, chatKey, chatName, chatType) => {
      const history = conversations.get(conversationKey) || [];
      for (const message of history) {
        if (!message || message.deletedAt || !message.attachment) continue;
        const attachment = sanitizeMessageAttachment(message.attachment, message.text);
        if (!attachment) continue;
        files.push({
          chatKey,
          chatName,
          chatType,
          isMine: normalizeName(message.fromKey || message.from || "") === userKey,
          messageId: String(message.id || message.clientTempId || ""),
          name: attachment.name || "File",
          url: attachment.url || "",
          mime: attachment.mime || "",
          size: Math.max(0, Number(attachment.size) || 0),
          kind: message.isVoice || attachment.kind === "audio" ? "audio" : attachment.kind,
          timestamp: message.timestamp || null,
        });
      }
    };
    for (const friendKey of me.friends instanceof Set ? me.friends : []) {
      const friend = users.get(friendKey);
      if (friend) addConversationFiles(getConversationKey(userKey, friendKey), friendKey, friend.username || friendKey, "friend");
    }
    for (const groupId of me.groups instanceof Set ? me.groups : []) {
      const group = groups.get(normalizeGroupId(groupId));
      if (group?.members?.has(userKey)) addConversationFiles(getGroupConversationKey(group.id), group.id, group.name || group.id, "group");
    }
    respond({ ok: true, files });
  });

  socket.on("mark_all_read", (payload, ack) => {
    const userKey = socket.data.userKey;
    const respond = typeof ack === "function" ? ack : () => {};
    if (!userKey || !users.has(userKey)) {
      respond({ ok: false, message: "Sign in to mark chats as read." });
      return;
    }
    if (!allowSocketAction(socket, "mark_all_read", 8, 60 * 1000)) {
      respond({ ok: false, message: "Please wait before marking all chats as read again." });
      return;
    }

    const account = users.get(userKey);
    let conversationsProcessed = 0;
    const friendKeys = account?.friends
      ? Array.from(account.friends)
      : [];
    for (const friendKey of friendKeys) {
      const normalizedFriend = normalizeName(friendKey);
      if (!normalizedFriend || !users.has(normalizedFriend)) continue;
      markConversationAsSeen(userKey, normalizedFriend, "friend");
      conversationsProcessed += 1;
    }
    for (const group of groups.values()) {
      if (!group || !isGroupMember(group, userKey)) continue;
      markConversationAsSeen(userKey, group.id, "group");
      conversationsProcessed += 1;
    }

    respond({ ok: true, conversationsProcessed });
  });

  socket.on("mark_chat_read", (payload, ack) => {
    const userKey = socket.data.userKey;
    const respond = typeof ack === "function" ? ack : () => {};
    if (!userKey || !users.has(userKey)) {
      respond({ ok: false, message: "Sign in to mark this chat as read." });
      return;
    }
    if (!allowSocketAction(socket, "mark_chat_read", 30, 60 * 1000)) {
      respond({ ok: false, message: "Please wait before updating read status again." });
      return;
    }

    const targetName = payload?.to || payload?.username || payload?.groupId || "";
    const targetType = payload?.kind || payload?.type || payload?.toType || "friend";
    const resolved = resolveChatTargetForUser(userKey, targetName, targetType, { inferGroup: true });
    if (!resolved.ok) {
      respond({ ok: false, message: resolved.message || "This conversation is unavailable." });
      return;
    }

    markConversationAsSeen(userKey, resolved.targetKey, resolved.type);
    respond({ ok: true });
  });

  socket.on("get_history", (rawTarget) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "get_history", 120, 60 * 1000)) {
      socket.emit("error_message", { message: "Too many history requests. Slow down a bit." });
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
    const messages = allMessages.slice(startIndex, endIndex).map((message) => riddleForViewer(message, userKey));
    const hasMore = startIndex > 0;
    const nextBefore = hasMore ? String(messages[0]?.id || messages[0]?.clientTempId || "") : null;
    const wallpaper = conversationWallpapers.get(resolved.conversationKey) || "";

    socket.emit("history", {
      with: resolved.targetKey,
      withLabel: resolved.targetLabel,
      messages,
      hasMore,
      nextBefore,
      before: before || null,
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

  socket.on("get_chat_protection", (payload, callback) => {
    const respond = (result) => { if (typeof callback === "function") callback(result); };
    const userKey = socket.data.userKey;
    if (!userKey) { respond({ ok: false, protected: false }); return; }
    const target = toDisplayName(payload?.to);
    const resolved = resolveChatTargetForUser(userKey, target, "friend", { inferGroup: false });
    if (!resolved.ok || resolved.type !== "friend") {
      respond({ ok: false, protected: false });
      return;
    }
    const peer = users.get(resolved.targetKey);
    respond({ ok: true, protected: peer?.stealthModeEnabled === true });
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
    if (!allowSocketAction(socket, "add_reaction", 120, 60 * 1000)) return;

    const messageId = String(payload?.messageId || payload?.id || "").slice(0, 128);
    const to = toDisplayName(payload?.to);
    const emoji = String(payload?.emoji || "").trim().slice(0, 16);
    if (!messageId || !to || !emoji) return;

    const resolvedTarget = resolveChatTargetForUser(userKey, to, "friend", { inferGroup: true });
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: "You are not authorized to react in this chat." });
      return;
    }

    const convKey = resolvedTarget.conversationKey;
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

    const packet = {
      messageId,
      reactions,
      to,
      toType: resolvedTarget.type,
      from: userKey,
    };
    socket.emit("reaction_updated", packet);

    if (resolvedTarget.type === "group") {
      const group = groups.get(resolvedTarget.targetKey);
      if (group) {
        for (const memberKey of group.members || []) {
          const memberSocket = onlineUsers.get(normalizeName(memberKey));
          if (memberSocket && normalizeName(memberKey) !== userKey) {
            io.to(memberSocket).emit("reaction_updated", packet);
          }
        }
      }
    } else {
      const friendSocket = onlineUsers.get(normalizeName(resolvedTarget.targetKey));
      if (friendSocket) {
        io.to(friendSocket).emit("reaction_updated", packet);
      }
    }
  });

  socket.on("pin_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;

    const resolvedTarget = resolveChatTargetForUser(
      userKey, to, payload?.toType || payload?.kind || "friend", { inferGroup: true }
    );
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: resolvedTarget.message || "You are not authorized for this chat." });
      return;
    }

    const list = conversations.get(resolvedTarget.conversationKey);
    if (!list) return;
    const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
    if (!item) return;

    item.pinnedAt = nowIso();
    item.pinnedBy = userKey;
    schedulePersist();

    const packet = {
      messageId,
      pinnedAt: item.pinnedAt,
      pinnedBy: userKey,
      to: resolvedTarget.targetKey,
      from: userKey,
      toType: resolvedTarget.type,
    };
    socket.emit("message_pinned", packet);

    if (resolvedTarget.type === "group") {
      for (const memberKey of resolvedTarget.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId && normalizeName(memberKey) !== normalizeName(userKey)) {
          io.to(memberSocketId).emit("message_pinned", packet);
        }
      }
    } else {
      const friendSocketId = onlineUsers.get(normalizeName(resolvedTarget.targetKey));
      if (friendSocketId) io.to(friendSocketId).emit("message_pinned", packet);
    }
  });

  socket.on("unpin_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const messageId = String(payload?.messageId || payload?.id || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !to) return;

    const resolvedTarget = resolveChatTargetForUser(
      userKey, to, payload?.toType || payload?.kind || "friend", { inferGroup: true }
    );
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: resolvedTarget.message || "You are not authorized for this chat." });
      return;
    }

    const list = conversations.get(resolvedTarget.conversationKey);
    if (!list) return;
    const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
    if (!item) return;

    item.pinnedAt = null;
    item.pinnedBy = "";
    schedulePersist();

    const packet = { messageId, to: resolvedTarget.targetKey, from: userKey, toType: resolvedTarget.type };
    socket.emit("message_unpinned", packet);

    if (resolvedTarget.type === "group") {
      for (const memberKey of resolvedTarget.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId && normalizeName(memberKey) !== normalizeName(userKey)) {
          io.to(memberSocketId).emit("message_unpinned", packet);
        }
      }
    } else {
      const friendSocketId = onlineUsers.get(normalizeName(resolvedTarget.targetKey));
      if (friendSocketId) io.to(friendSocketId).emit("message_unpinned", packet);
    }
  });

  socket.on("create_poll", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "create_poll", 20, 60 * 1000)) {
      socket.emit("error_message", { message: "Poll rate limit reached. Slow down a bit." });
      return;
    }

    const to = toDisplayName(payload?.to);
    const requestedType = payload?.toType || payload?.kind || "friend";
    const question = String(payload?.question || "").trim().slice(0, 500);
    const optionsRaw = Array.isArray(payload?.options) ? payload.options : [];
    if (!to || !question || optionsRaw.length < 2 || optionsRaw.length > 8) {
      socket.emit("error_message", { message: "A poll needs 2 to 8 options." });
      return;
    }

    const resolved = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "You are not authorized to create a poll here." });
      return;
    }

    const options = optionsRaw.map((opt, i) => ({
      id: `opt_${i}_${Date.now()}_${crypto.randomBytes(2).toString("hex")}`,
      text: String(opt || "").trim().slice(0, 200),
      votes: [],
    })).filter((opt) => opt.text);

    if (options.length < 2) {
      socket.emit("error_message", { message: "A poll needs at least 2 non-empty options." });
      return;
    }

    const poll = {
      id: `poll_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`,
      question,
      options,
      totalVotes: 0,
    };

    const clientTempId = String(payload?.clientTempId || `tmp_poll_${Date.now()}`).slice(0, 64);
    const convKey = resolved.conversationKey;
    const list = conversations.get(convKey) || [];
    const msg = {
      id: poll.id,
      clientTempId,
      from: users.get(userKey)?.username || userKey,
      to: resolved.targetLabel,
      fromKey: userKey,
      toKey: resolved.targetKey,
      toType: resolved.type,
      groupId: resolved.type === "group" ? resolved.targetKey : undefined,
      text: `📊 Poll: ${question}`,
      timestamp: nowIso(),
      poll,
      status: "sent",
    };

    list.push(msg);
    conversations.set(convKey, list);
    schedulePersist();

    if (resolved.type === "group") {
      for (const memberKey of resolved.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId) io.to(memberSocketId).emit("private_message", msg);
      }
    } else {
      socket.emit("private_message", msg);
      const friendSocket = onlineUsers.get(normalizeName(resolved.targetKey));
      if (friendSocket) io.to(friendSocket).emit("private_message", msg);
    }
  });

  socket.on("poll_vote", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;

    const messageId = String(payload?.messageId || "");
    const optionId = String(payload?.optionId || "");
    const to = toDisplayName(payload?.to);
    if (!messageId || !optionId || !to) return;

    const resolvedTarget = resolveChatTargetForUser(userKey, to, "friend", { inferGroup: true });
    if (!resolvedTarget.ok) {
      socket.emit("error_message", { message: "You are not authorized to vote in this poll." });
      return;
    }
    if (resolvedTarget.type === "friend" && usersAreBlocked(userKey, resolvedTarget.targetKey)) {
      socket.emit("error_message", { message: "Poll interaction is unavailable because this contact is blocked." });
      return;
    }

    const isGroup = resolvedTarget.type === "group";
    const convKey = isGroup ? getGroupConversationKey(to) : getConversationKey(userKey, to);
    const list = conversations.get(convKey);
    let updatedPoll = null;

    if (list) {
      const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
      if (item?.poll && Array.isArray(item.poll.options)) {
        const selectedOption = item.poll.options.find((opt) => String(opt.id) === optionId);
        if (!selectedOption) {
          socket.emit("error_message", { message: "That poll option does not exist." });
          return;
        }

        let total = 0;
        item.poll.options.forEach((opt) => {
          if (!Array.isArray(opt.votes)) opt.votes = [];
          const idx = opt.votes.indexOf(userKey);
          if (opt.id === optionId) {
            if (idx === -1) opt.votes.push(userKey);
            else opt.votes.splice(idx, 1);
          } else if (idx !== -1) {
            opt.votes.splice(idx, 1);
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

      if (isGroup) {
        const group = groups.get(normalizeGroupId(to));
        if (group) {
          for (const memberKey of group.members || []) {
            const memberSocketId = onlineUsers.get(normalizeName(memberKey));
            if (memberSocketId && normalizeName(memberKey) !== userKey) {
              io.to(memberSocketId).emit("poll_updated", packet);
            }
          }
        }
      } else {
        const friendSocket = onlineUsers.get(normalizeName(to));
        if (friendSocket) {
          io.to(friendSocket).emit("poll_updated", packet);
        }
      }
    }
  });

  socket.on("game_move", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });

    const messageId = String(payload?.messageId || "");
    const to = toDisplayName(payload?.to);
    const moveData = payload?.moveData;
    if (!messageId || !to) return respond({ ok: false, message: "Game or chat not found." });

    const requestedType = normalizeChatKind(payload?.toType || "friend");
    const resolvedTarget = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    if (!resolvedTarget.ok) {
      const message = "You are not authorized to modify this game.";
      socket.emit("error_message", { message });
      return respond({ ok: false, message });
    }
    if (resolvedTarget.type === "friend" && usersAreBlocked(userKey, resolvedTarget.targetKey)) {
      const message = "Game interaction is unavailable because this contact is blocked.";
      socket.emit("error_message", { message });
      return respond({ ok: false, message });
    }

    const isGroup = resolvedTarget.type === "group";
    const list = conversations.get(resolvedTarget.conversationKey);
    if (!list) return respond({ ok: false, message: "Game conversation not found." });

    const item = list.find((m) => String(m.id) === messageId || String(m.clientTempId) === messageId);
    if (!item?.game) return respond({ ok: false, message: "This game is no longer available." });

    const result = applyGameMove(item.game, userKey, moveData);
    if (!result.ok) {
      const message = result.reason || "Invalid game move.";
      socket.emit("error_message", { message });
      return respond({ ok: false, message });
    }

    item.game = result.game;
    const updatedGame = item.game;
    schedulePersist();
    respond({ ok: true, game: updatedGame });

    const packet = {
      messageId,
      game: updatedGame,
      moveData: {
        ...updatedGame.data,
        state: updatedGame.state,
        turn: updatedGame.turn,
        winner: updatedGame.winner,
      },
      updatedBy: userKey,
      to: resolvedTarget.targetKey,
      from: userKey,
    };

    socket.emit("game_move_updated", packet);

    if (isGroup) {
      for (const memberKey of resolvedTarget.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId && normalizeName(memberKey) !== userKey) {
          io.to(memberSocketId).emit("game_move_updated", packet);
        }
      }
    } else {
      const friendSocket = onlineUsers.get(resolvedTarget.targetKey);
      if (friendSocket) io.to(friendSocket).emit("game_move_updated", packet);
    }

    const gameTitle = updatedGame.title || "Novyn game";
    const eventSuffix = String(updatedGame.updatedAt || Date.now());
    const gameData = updatedGame.data && typeof updatedGame.data === "object"
      ? updatedGame.data
      : {};
    const playerKeys = Array.from(new Set([
      updatedGame.createdBy,
      updatedGame.opponent,
      gameData.playerX,
      gameData.playerO,
      gameData.player1,
      gameData.player2,
    ].map(normalizeName).filter(Boolean)));
    const recipients = playerKeys.filter((key) =>
      key !== userKey &&
      users.has(key) &&
      (!isGroup || resolvedTarget.group.members.has(key))
    );
    if (updatedGame.state === "finished") {
      for (const recipientKey of recipients) {
        if (!users.has(normalizeName(recipientKey))) continue;
        void sendPushToUser(recipientKey, {
          type: "game_result",
          title: "Game finished",
          body: updatedGame.winner ? updatedGame.winner + " won " + gameTitle : "The game ended in a draw: " + gameTitle,
          chat: isGroup ? resolvedTarget.group.id : (users.get(userKey)?.username || userKey),
          group: isGroup,
          groupId: isGroup ? resolvedTarget.group.id : undefined,
          gameId: updatedGame.id,
          gameType: updatedGame.gameType,
          eventId: String(updatedGame.id) + ":result:" + eventSuffix,
        });
      }
    } else if (updatedGame.turn) {
      const turnKey = normalizeName(updatedGame.turn);
      if (turnKey && turnKey !== userKey && users.has(turnKey) &&
          playerKeys.includes(turnKey) &&
          (!isGroup || resolvedTarget.group.members.has(turnKey))) {
        void sendPushToUser(turnKey, {
          type: "game_turn",
          title: "Your turn",
          body: "It's your turn in " + gameTitle,
          chat: isGroup ? resolvedTarget.group.id : (users.get(userKey)?.username || userKey),
          group: isGroup,
          groupId: isGroup ? resolvedTarget.group.id : undefined,
          gameId: updatedGame.id,
          gameType: updatedGame.gameType,
          eventId: String(updatedGame.id) + ":turn:" + turnKey + ":" + eventSuffix,
        });
      }
    }
  });

  socket.on("set_chat_wallpaper", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const wallpaper = String(payload?.wallpaper || "").trim().slice(0, 2048);
    const requestedType = payload?.toType || payload?.kind || "friend";
    if (!to) return;

    const resolved = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "You are not authorized for this chat." });
      return;
    }

    conversationWallpapers.set(resolved.conversationKey, wallpaper);
    schedulePersist();

    const packet = { to: resolved.targetKey, from: userKey, wallpaper, toType: resolved.type };
    socket.emit("chat_wallpaper_updated", packet);

    if (resolved.type === "group") {
      for (const memberKey of resolved.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId && normalizeName(memberKey) !== normalizeName(userKey)) {
          io.to(memberSocketId).emit("chat_wallpaper_updated", packet);
        }
      }
    } else {
      const friendSocketId = onlineUsers.get(normalizeName(resolved.targetKey));
      if (friendSocketId) io.to(friendSocketId).emit("chat_wallpaper_updated", packet);
    }
  });

  socket.on("get_chat_wallpaper", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    const to = toDisplayName(payload?.to);
    const requestedType = payload?.toType || payload?.kind || "friend";
    if (!to) return;

    const resolved = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    if (!resolved.ok) {
      socket.emit("error_message", { message: resolved.message || "You are not authorized for this chat." });
      return;
    }

    const wallpaper = conversationWallpapers.get(resolved.conversationKey) || "";
    socket.emit("chat_wallpaper_updated", {
      to: resolved.targetKey,
      from: userKey,
      wallpaper,
      toType: resolved.type,
    });
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
    io,
    allowSocketAction,
    usersAreBlocked,
    sendPushToUser,
    recordCallLog: (userKey, entry) => {
      const user = users.get(normalizeName(userKey));
      if (!user) return;
      if (!Array.isArray(user.callLogs)) user.callLogs = [];
      const existingIndex = user.callLogs.findIndex((item) => item?.callId === entry.callId);
      if (existingIndex >= 0) user.callLogs[existingIndex] = { ...user.callLogs[existingIndex], ...entry };
      else user.callLogs.unshift(entry);
      user.callLogs = user.callLogs.slice(0, 500);
      schedulePersist();
    }
  });

  socket.on("private_message", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const rejectMessage = (message) => {
      if (typeof callback === "function") respond({ ok: false, message });
      else socket.emit("error_message", { message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) { rejectMessage("Please sign in again."); return; }
    if (!allowSocketAction(socket, "private_message", 40, 60 * 1000)) {
      rejectMessage("Message rate limit reached. Slow down a bit.");
      return;
    }

    const isEncrypted = Boolean(payload?.isEncrypted);
    const ciphertext = toDisplayName(payload?.ciphertext);
    const iv = toDisplayName(payload?.iv);
    const senderPublicKey = normalizePushPublicKey(payload?.senderPublicKey);
    if (isEncrypted && (!ciphertext || !iv || !senderPublicKey)) {
      rejectMessage("Invalid encrypted message payload.");
      return;
    }
    // Never store a client-supplied plaintext body for an encrypted message.
    const text = isEncrypted
      ? ENCRYPTED_MESSAGE_PLACEHOLDER
      : withUploadToken(payload?.text || (payload?.attachment ? '[Attachment]' : ''));
    const attachment = sanitizeMessageAttachment(payload?.attachment, text);
    if (isEncrypted && payload?.attachment && !attachment?.encrypted) {
      rejectMessage("Invalid encrypted attachment metadata.");
      return;
    }
    const clientTempId = String(payload?.clientTempId || "").trim();
    const safeClientTempId = clientTempId.slice(0, 64);
    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const replyTo = normalizeReplyPayload(payload?.replyTo);
    if (isEncrypted && replyTo) replyTo.text = ENCRYPTED_MESSAGE_PLACEHOLDER;
    const rawGame = payload?.game || null;
    let game = null;
    if (rawGame) {
      const challenge = createGameChallenge({
        userKey,
        userDisplayName: users.get(userKey)?.username || userKey,
        to,
        toType,
        game: rawGame,
      });
      if (!challenge.ok) {
        rejectMessage(challenge.reason || "Invalid game challenge.");
        return;
      }
      game = challenge.game;
    }
    const poll = payload?.poll || null;

    if (!text) { rejectMessage("Message is empty."); return; }
    if (text.length > MAX_MESSAGE_LENGTH) {
      rejectMessage(`Message too long. Limit is ${MAX_MESSAGE_LENGTH} characters.`);
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
        rejectMessage(result.message || "Unable to send message to this group.");
        return;
      }
      respond({ ok: true, id: result.message.id });
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
      senderPublicKey,
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
      rejectMessage(result.message || "Unable to send message.");
      return;
    }
    if (game && toType === "friend") {
      const inviteId = String(result.message.id || "").slice(0, 128);
      const oldInvite = pendingGameInvites.get(inviteId);
      if (oldInvite) clearTimeout(oldInvite.timer);
      const invite = {
        fromKey: normalizeName(userKey),
        toKey: normalizeName(to),
        gameType: game.gameType,
        game: result.message.game || game,
        messageId: inviteId,
        expiresAt: Date.now() + 60_000,
        timer: null,
      };
      invite.timer = setTimeout(() => {
        if (pendingGameInvites.get(inviteId) !== invite) return;
        pendingGameInvites.delete(inviteId);
        const senderSocketId = onlineUsers.get(invite.fromKey);
        if (senderSocketId) io.to(senderSocketId).emit("game_invite_timeout", { messageId: inviteId, gameType: invite.gameType });
      }, 60_000);
      if (typeof invite.timer.unref === "function") invite.timer.unref();
      pendingGameInvites.set(inviteId, invite);
      const recipientSocketId = onlineUsers.get(invite.toKey);
      const inviter = users.get(invite.fromKey);
      if (recipientSocketId && inviter) {
        io.to(recipientSocketId).emit("game_invitation_received", {
          messageId: inviteId,
          from: inviter.username || invite.fromKey,
          displayName: inviter.displayName || inviter.username || invite.fromKey,
          avatarId: inviter.avatarId || "",
          gameType: invite.gameType,
          game: invite.game,
          expiresAt: invite.expiresAt,
        });
      }
    }
    respond({ ok: true, id: result.message.id });
    if (result.existing) {
      socket.emit("private_message", result.message);
      emitMessageStatus(result.message);
    }
  });

  socket.on("riddle_message", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "riddle_message", 20, 60 * 1000)) return respond({ ok: false, message: "Too many riddles. Try again shortly." });
    const to = toDisplayName(payload?.to);
    const requestedType = normalizeChatKind(payload?.toType || "friend");
    const resolved = resolveChatTargetForUser(userKey, to, requestedType, { inferGroup: true });
    const secret = toDisplayName(payload?.secret).slice(0, MAX_MESSAGE_LENGTH);
    const question = toDisplayName(payload?.question).slice(0, 160);
    const hint = toDisplayName(payload?.hint).slice(0, 160);
    const answer = toDisplayName(payload?.answer).trim().toLowerCase().replace(/\s+/g, " ").slice(0, 80);
    const maxTries = Number(payload?.maxTries) === 5 ? 5 : 3;
    if (!to || !secret || !question || !answer) return respond({ ok: false, message: "Recipient, secret message, question, and answer are required." });
    if (!resolved.ok) return respond({ ok: false, message: resolved.message || "Could not send riddle to this chat." });
    const answerSalt = crypto.randomBytes(16).toString("hex");
    const answerHash = crypto.scryptSync(answer, answerSalt, 32).toString("hex");
    const riddle = { question, hint, secret, answerSalt, answerHash, maxTries, attemptsBy: {}, unlockedBy: [] };
    const clientTempId = toDisplayName(payload?.clientTempId).slice(0, 64);
    const result = resolved.type === "group"
      ? deliverGroupMessage({ fromKey: userKey, groupId: resolved.targetKey, text: "[Riddle Lock]", clientTempId, riddle })
      : deliverFriendMessage({ fromKey: userKey, toKey: resolved.targetKey, text: "[Riddle Lock]", clientTempId, riddle });
    if (!result.ok) return respond({ ok: false, message: result.message || "Could not send riddle." });
    respond({ ok: true, id: result.message.id });
  });

  socket.on("unlock_riddle", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "unlock_riddle", 20, 60 * 1000)) return respond({ ok: false, message: "Too many attempts. Try again later." });
    const chatTarget = toDisplayName(payload?.to || payload?.from);
    const requestedType = normalizeChatKind(payload?.toType || "friend");
    const resolved = resolveChatTargetForUser(userKey, chatTarget, requestedType, { inferGroup: true });
    const messageId = toDisplayName(payload?.messageId);
    const answer = toDisplayName(payload?.answer).trim().toLowerCase().replace(/\s+/g, " ").slice(0, 80);
    if (!resolved.ok) return respond({ ok: false, message: "Riddle not found." });
    const conversation = conversations.get(resolved.conversationKey) || [];
    const message = conversation.find((entry) => entry.id === messageId);
    const isGroup = resolved.type === "group";
    const validRecipient = isGroup
      ? Boolean(message?.groupId === resolved.targetKey && message.fromKey !== userKey && isGroupMember(resolved.group, userKey))
      : Boolean(message?.fromKey === resolved.targetKey && message.toKey === userKey);
    if (!message?.riddle || !validRecipient) return respond({ ok: false, message: "Riddle not found." });
    if (!Array.isArray(message.riddle.unlockedBy)) message.riddle.unlockedBy = [];
    if (!message.riddle.attemptsBy || typeof message.riddle.attemptsBy !== "object") message.riddle.attemptsBy = {};
    if (message.riddle.unlockedBy.includes(userKey)) return respond({ ok: true, riddle: riddleForViewer(message, userKey).riddle });
    const used = Math.max(0, Number(message.riddle.attemptsBy[userKey]) || 0);
    if (used >= message.riddle.maxTries) return respond({ ok: false, locked: true, triesLeft: 0, message: "No tries left." });
    const candidate = crypto.scryptSync(answer, message.riddle.answerSalt, 32).toString("hex");
    if (!safeTimingEqual(candidate, message.riddle.answerHash)) {
      message.riddle.attemptsBy[userKey] = used + 1;
      schedulePersist();
      const triesLeft = Math.max(0, message.riddle.maxTries - used - 1);
      return respond({ ok: false, locked: triesLeft === 0, triesLeft, message: triesLeft ? "That answer is not right." : "No tries left." });
    }
    message.riddle.unlockedBy.push(userKey);
    schedulePersist();
    const recipientView = riddleForViewer(message, userKey);
    if (isGroup) {
      for (const memberKey of resolved.group.members || []) {
        const memberSocketId = onlineUsers.get(normalizeName(memberKey));
        if (memberSocketId) io.to(memberSocketId).emit("riddle_updated", riddleForViewer(message, memberKey));
      }
    } else {
      socket.emit("riddle_updated", recipientView);
      const senderSocketId = onlineUsers.get(resolved.targetKey);
      if (senderSocketId) io.to(senderSocketId).emit("riddle_updated", riddleForViewer(message, resolved.targetKey));
    }
    respond({ ok: true, riddle: recipientView.riddle });
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

  socket.on("approve_device_pairing", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : () => {};
    const userKey = normalizeName(socket.data.userKey || "");
    const id = toDisplayName(payload?.id);
    const secret = toDisplayName(payload?.secret);
    const pairing = runtimeState.devicePairings.get(id);
    const secretHash = crypto.createHash("sha256").update(secret).digest("hex");
    if (!userKey || !users.get(userKey)?.isRegistered) {
      return respond({ ok: false, message: "Sign in on your primary phone first." });
    }
    if (!pairing || pairing.expiresAt <= Date.now() || pairing.status !== "waiting" ||
        !csrfSafeTimingEqual(pairing.secretHash, secretHash)) {
      return respond({ ok: false, message: "This QR request expired or was already used." });
    }
    let requestedBrowserKey;
    try { requestedBrowserKey = JSON.parse(toDisplayName(payload?.browserPublicKey)); } catch (_) { requestedBrowserKey = null; }
    let expectedBrowserKey;
    try { expectedBrowserKey = JSON.parse(pairing.browserPublicKey); } catch (_) { expectedBrowserKey = null; }
    if (!requestedBrowserKey || !expectedBrowserKey ||
        requestedBrowserKey.kty !== "EC" || requestedBrowserKey.crv !== "P-256" ||
        requestedBrowserKey.x !== expectedBrowserKey.x || requestedBrowserKey.y !== expectedBrowserKey.y) {
      return respond({ ok: false, message: "The browser key did not match the original QR request." });
    }
    const encryptedIdentity = payload?.encryptedIdentity;
    if (!encryptedIdentity || typeof encryptedIdentity !== "object" ||
        typeof encryptedIdentity.senderPublicKey !== "string" ||
        typeof encryptedIdentity.iv !== "string" || typeof encryptedIdentity.ciphertext !== "string" ||
        encryptedIdentity.ciphertext.length > 8192 || encryptedIdentity.iv.length > 64 ||
        encryptedIdentity.senderPublicKey.length > 2048) {
      return respond({ ok: false, message: "The encrypted device key envelope is invalid." });
    }
    let senderKey;
    try { senderKey = JSON.parse(encryptedIdentity.senderPublicKey); } catch (_) { senderKey = null; }
    if (!senderKey || senderKey.kty !== "EC" || senderKey.crv !== "P-256" ||
        !senderKey.x || !senderKey.y) {
      return respond({ ok: false, message: "The primary phone encryption key is invalid." });
    }
    pairing.userKey = userKey;
    pairing.encryptedIdentity = encryptedIdentity;
    pairing.status = "approved";
    pairing.approvedAt = Date.now();
    respond({ ok: true });
  });

  socket.on("get_public_key", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : (d) => socket.emit("public_key_response", d);
    const targetName = toDisplayName(payload?.username || payload?.target || payload);
    const targetKey = normalizeName(targetName);
    const target = users.get(targetKey);
    const publicKey = target?.publicKey || "";
    respond({ username: target?.username || targetName, publicKey });
  });

  socket.on("save_e2ee_identity_backup", (payload, callback) => {
    const respond = typeof callback === "function" ? callback : (data) => socket.emit("e2ee_identity_backup_saved", data);
    const userKey = socket.data.userKey;
    const user = userKey ? users.get(userKey) : null;
    if (!user) {
      respond({ ok: false, message: "Unauthorized" });
      return;
    }
    const backup = payload?.backup;
    const publicKey = toDisplayName(payload?.publicKey);
    if (!backup || typeof backup !== "object" || Array.isArray(backup)) {
      respond({ ok: false, message: "A valid encrypted identity backup is required." });
      return;
    }
    if (
      backup.format !== "novyn-e2ee-identity" ||
      backup.version !== 1 ||
      normalizeName(backup.username) !== userKey ||
      backup.publicKey !== publicKey ||
      !publicKey ||
      user.publicKey !== publicKey
    ) {
      respond({ ok: false, message: "The backup does not match this account's active encryption identity." });
      return;
    }
    let serialized = "";
    try {
      serialized = JSON.stringify(backup);
    } catch (_) {
      respond({ ok: false, message: "The encrypted identity backup is invalid." });
      return;
    }
    if (serialized.length > 12000) {
      respond({ ok: false, message: "The encrypted identity backup is too large." });
      return;
    }
    user.e2eeIdentityBackup = serialized;
    user.e2eeIdentityBackupPublicKey = publicKey;
    schedulePersist();
    respond({ ok: true });
  });

  socket.on("get_e2ee_identity_backup", (_payload, callback) => {
    const respond = typeof callback === "function" ? callback : (data) => socket.emit("e2ee_identity_backup", data);
    const userKey = socket.data.userKey;
    const user = userKey ? users.get(userKey) : null;
    if (!user) {
      respond({ ok: false, message: "Unauthorized" });
      return;
    }
    let backup = null;
    if (user.e2eeIdentityBackup) {
      try {
        const parsed = JSON.parse(user.e2eeIdentityBackup);
        if (parsed && parsed.format === "novyn-e2ee-identity" && normalizeName(parsed.username) === userKey) {
          backup = parsed;
        }
      } catch (_) {
        backup = null;
      }
    }
    respond({
      ok: true,
      backup,
      publicKey: backup ? toDisplayName(user.e2eeIdentityBackupPublicKey) : "",
    });
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
    if (!allowSocketAction(socket, "list_scheduled_messages", 60, 60 * 1000)) return;

    const toType = normalizeChatKind(payload?.toType || "friend");
    const to = toDisplayName(payload?.to || "").slice(0, 128);
    if (to) {
      const resolved = resolveChatTargetForUser(userKey, to, toType, { inferGroup: true });
      if (!resolved.ok) {
        socket.emit("error_message", { message: "You are not authorized to view scheduled messages for this chat." });
        return;
      }
      emitScheduledMessagesUpdated(userKey, { toType: resolved.type, to: resolved.targetKey });
      return;
    }

    emitScheduledMessagesUpdated(userKey);
  });

  socket.on("cancel_scheduled_message", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "cancel_scheduled_message", 60, 60 * 1000)) return;

    const id = toDisplayName(payload?.id || payload?.messageId || payload).slice(0, 128);
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

  socket.on("app_visibility", (payload) => {
    // Mobile clients report foreground/background state so pushes still arrive
    // when Android keeps the Socket.IO connection alive in the background.
    socket.data.appForeground = payload?.foreground === true;
  });

  socket.on("typing", (payload) => {
    const userKey = socket.data.userKey;
    if (!userKey) return;
    if (!allowSocketAction(socket, "typing", 120, 60 * 1000)) return;

    const to = toDisplayName(payload?.to);
    const toType = normalizeChatKind(payload?.toType || "friend");
    const me = users.get(userKey);
    if (!me) return;

    // The sender's setting controls whether they broadcast typing; each
    // recipient's setting independently controls whether they receive it.
    const isTyping = Boolean(payload?.isTyping) &&
      me.typingIndicatorsEnabled !== false;

    if (toType === "group") {
      const groupId = normalizeGroupId(to);
      const group = groups.get(groupId);
      if (!group || !isGroupMember(group, userKey)) return;

      for (const memberKey of group.members) {
        if (memberKey === userKey) continue;
        const recipient = users.get(memberKey);
        if (!recipient || recipient.typingIndicatorsEnabled === false) continue;
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
    const recipient = users.get(toKey);
    if (!recipient || (!me.friends.has(toKey) && !conversations.get(getConversationKey(userKey, toKey))?.length)) {
      return;
    }
    if (usersAreBlocked(userKey, toKey) || recipient.typingIndicatorsEnabled === false) {
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
      if (!me.friends.has(toKey) || usersAreBlocked(userKey, toKey)) return;
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

  socket.on("get_group_info", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) {
      respond({ ok: false, message: "Please sign in again." });
      return;
    }
    if (!allowSocketAction(socket, "get_group_info", 180, 60 * 1000)) {
      respond({ ok: false, message: "Too many group info requests. Try again shortly." });
      return;
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload);
    const group = groups.get(groupId);
    if (!group || !isGroupMember(group, userKey)) {
      respond({ ok: false, message: "Group not found." });
      return;
    }
    const groupInfo = buildGroupInfoForViewer(group, userKey);
    if (!groupInfo) {
      respond({ ok: false, message: "Group information is unavailable." });
      return;
    }
    socket.emit("group_info", { group: groupInfo });
    respond({ ok: true, group: groupInfo });
  });

  socket.on("create_group", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) {
      respond({ ok: false, message: "Please sign in again." });
      return;
    }
    if (!allowSocketAction(socket, "create_group", 20, 60 * 60 * 1000)) {
      respond({ ok: false, message: "Group creation rate limit reached. Try again later." });
      return;
    }
    const me = users.get(userKey);
    if (!me) {
      respond({ ok: false, message: "Account not found. Please sign in again." });
      return;
    }

    const requestedName = toDisplayName(payload?.name || payload?.title || "").slice(0, MAX_GROUP_NAME_LENGTH);
    const name = requestedName || `${me.username}'s group`;
    const requestedMembers = Array.isArray(payload?.members) ? payload.members : [];
    const memberKeys = new Set([userKey]);
    for (const rawMember of requestedMembers) {
      const memberKey = normalizeName(rawMember);
      if (!memberKey || memberKey === userKey) continue;
      const invitee = users.get(memberKey);
      if (!invitee?.isRegistered) continue;
      if (usersAreBlocked(userKey, memberKey)) continue;
      if (!me.friends.has(memberKey) && invitee.groupInvitePrivacy !== "everyone") continue;
      if (invitee.groupInvitePrivacy === "nobody" || (invitee.groupInvitePrivacy === "friends" && !invitee.friends.has(userKey))) continue;
      memberKeys.add(memberKey);
      if (memberKeys.size >= MAX_GROUP_MEMBERS) break;
    }

    if (memberKeys.size < 2) {
      respond({ ok: false, message: "Add at least one eligible friend to create a group." });
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
      if (memberKey !== userKey) {
        void sendPushToUser(memberKey, {
          type: "group_invite",
          title: "Group invitation",
          body: (me.displayName || me.username) + " added you to " + group.name,
          chat: group.id,
          group: true,
          groupId: group.id,
          from: me.username,
          eventId: "group-invite:" + group.id + ":" + memberKey,
          tag: "group-invite-" + group.id,
        });
      }
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
    const groupInfo = buildGroupInfoForViewer(group, userKey);
    respond({ ok: true, group: groupInfo, groupId: group.id });
  });

  socket.on("add_group_members", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "add_group_members", 40, 60 * 60 * 1000)) {
      return respond({ ok: false, message: "Too many group updates. Try again later." });
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      return respond({ ok: false, message: "Group not found." });
    }
    if (!(group.admins instanceof Set) || !group.admins.has(userKey)) {
      return respond({ ok: false, message: "Only group admins can add members." });
    }

    const requestedMembers = Array.isArray(payload?.members) ? payload.members : [];
    const added = [];
    for (const rawMember of requestedMembers) {
      const memberKey = normalizeName(rawMember);
      if (!memberKey || group.members.has(memberKey)) continue;
      const member = users.get(memberKey);
      if (!member?.isRegistered) continue;
      if (usersAreBlocked(userKey, memberKey)) continue;
      if (!me.friends.has(memberKey) && member.groupInvitePrivacy !== "everyone") continue;
      if (member.groupInvitePrivacy === "nobody" || (member.groupInvitePrivacy === "friends" && !member.friends.has(userKey))) continue;
      if (group.members.size >= MAX_GROUP_MEMBERS) break;
      group.members.add(memberKey);
      if (!(member.groups instanceof Set)) member.groups = new Set();
      member.groups.add(group.id);
      setUnreadCount(member, group.id, 0);
      added.push(member.username || memberKey);
      void sendPushToUser(memberKey, {
        type: "group_invite",
        title: "Group invitation",
        body: (me.displayName || me.username) + " added you to " + group.name,
        chat: group.id,
        group: true,
        groupId: group.id,
        from: me.username,
        eventId: "group-invite:" + group.id + ":" + memberKey,
        tag: "group-invite-" + group.id,
      });
    }

    if (!added.length) {
      return respond({ ok: false, message: "No members were added." });
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
    respond({ ok: true, added, group: buildGroupInfoForViewer(group, userKey) });
  });

  socket.on("remove_group_member", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "remove_group_member", 40, 60 * 60 * 1000)) {
      return respond({ ok: false, message: "Too many group updates. Try again later." });
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      return respond({ ok: false, message: "Group not found." });
    }
    if (!(group.admins instanceof Set) || !group.admins.has(userKey)) {
      return respond({ ok: false, message: "Only group admins can remove members." });
    }

    const targetName = toDisplayName(payload?.username || payload?.member || payload?.target).replace(/^@+/, "");
    const targetKey = normalizeName(targetName);
    const targetUser = users.get(targetKey);
    if (!targetKey || !targetUser || !group.members.has(targetKey)) {
      return respond({ ok: false, message: "Member not found in this group." });
    }
    if (targetKey === userKey) {
      return respond({ ok: false, message: "Use Leave to exit this group." });
    }
    if (normalizeName(group.ownerKey) === targetKey) {
      return respond({ ok: false, message: "Group owner cannot be removed." });
    }
    const targetIsAdmin = group.admins instanceof Set && group.admins.has(targetKey);
    if (targetIsAdmin && normalizeName(group.ownerKey) !== userKey) {
      return respond({ ok: false, message: "Only owner can remove another admin." });
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
    respond({ ok: true, username: removedUsername });
  });

  socket.on("set_group_member_role", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "set_group_member_role", 50, 60 * 60 * 1000)) {
      return respond({ ok: false, message: "Too many role updates. Try again later." });
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload?.group);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      return respond({ ok: false, message: "Group not found." });
    }
    if (normalizeName(group.ownerKey) !== userKey) {
      return respond({ ok: false, message: "Only group owner can change roles." });
    }

    const targetName = toDisplayName(payload?.username || payload?.member || payload?.target).replace(/^@+/, "");
    const targetKey = normalizeName(targetName);
    if (!targetKey || !group.members.has(targetKey)) {
      return respond({ ok: false, message: "Member not found in this group." });
    }
    if (targetKey === normalizeName(group.ownerKey)) {
      return respond({ ok: false, message: "Owner role cannot be changed." });
    }

    const requestedRole = normalizeName(payload?.role || "");
    const makeAdmin = requestedRole === "admin";
    if (!(group.admins instanceof Set)) group.admins = new Set();
    const alreadyAdmin = group.admins.has(targetKey);
    if (makeAdmin === alreadyAdmin) {
      return respond({ ok: false, message: makeAdmin ? "Member is already an admin." : "Member is already not an admin." });
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
    respond({ ok: true, username: changedUsername, role });
  });

  socket.on("leave_group", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "leave_group", 20, 60 * 60 * 1000)) {
      return respond({ ok: false, message: "Too many group updates. Try again later." });
    }
    const groupId = normalizeGroupId(payload?.groupId || payload?.to || payload);
    const group = groups.get(groupId);
    const me = users.get(userKey);
    if (!group || !me || !isGroupMember(group, userKey)) {
      return respond({ ok: false, message: "Group not found." });
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
      // The new owner must always retain admin privileges. Otherwise an owner
      // hand-off can leave the group with an owner who cannot manage members.
      if (group.ownerKey) {
        group.admins.add(normalizeName(group.ownerKey));
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
    respond({ ok: true, groupId, left: true });
  });

  socket.on("set_block", (payload, callback) => {
    const reply = (result) => {
      if (typeof callback === "function") callback(result);
      else if (!result.ok) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return reply({ ok: false, message: "Please sign in first." });
    if (!allowSocketAction(socket, "set_block", 80, 60 * 1000)) {
      return reply({ ok: false, message: "Too many contact updates. Please try again shortly." });
    }
    const targetKey = normalizeName(payload?.username);
    const user = users.get(userKey);
    const target = users.get(targetKey);
    if (!user || !target || targetKey === userKey || typeof payload?.blocked !== "boolean") {
      return reply({ ok: false, message: "Choose a valid contact to block or unblock." });
    }
    if (!(user.blockedUsers instanceof Set)) user.blockedUsers = new Set();
    if (payload.blocked) user.blockedUsers.add(targetKey);
    else user.blockedUsers.delete(targetKey);
    if (payload.blocked) {
      const active = activeCalls.get(userKey);
      if (active?.peerKey === targetKey) {
        clearCallPair(userKey);
        socket.emit("call_ended", { callId: active.callId, reason: "Contact blocked" });
        const targetSocket = onlineUsers.get(targetKey);
        if (targetSocket) io.to(targetSocket).emit("call_ended", { callId: active.callId, reason: "Call ended" });
      }
    }
    schedulePersist();
    socket.emit("block_updated", { username: target.username || targetKey, blocked: payload.blocked });
    emitSafetyState(userKey);
    emitFriendList(userKey);
    emitFriendList(targetKey);
    emitStatusToFriends(userKey);
    emitStatusToFriends(targetKey);
    reply({ ok: true });
  });

  socket.on("set_chat_hidden", async (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = normalizeName(socket.data.userKey || "");
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "set_chat_hidden", 80, 60 * 1000)) {
      return respond({ ok: false, message: "Too many chat updates. Try again shortly." });
    }

    const user = users.get(userKey);
    const rawPeer = toDisplayName(payload?.username || "");
    const peerKey = normalizeName(rawPeer);
    const groupKey = normalizeGroupId(rawPeer);
    const group = groups.get(groupKey);
    const isGroup = Boolean(group);
    const hiddenKey = isGroup ? groupKey : peerKey;
    const alreadyHidden = user?.hiddenChats instanceof Set &&
      user.hiddenChats.has(hiddenKey);
    const hasDirectChat = Boolean(
      user?.friends?.has(peerKey) ||
      conversations.get(getConversationKey(userKey, peerKey))?.length
    );
    const canUpdateGroup = isGroup && isGroupMember(group, userKey);
    if (!user || !hiddenKey || hiddenKey === userKey ||
        (!hasDirectChat && !canUpdateGroup &&
          !(payload?.hidden === false && alreadyHidden)) ||
        typeof payload?.hidden !== "boolean") {
      return respond({ ok: false, message: "Choose a valid chat to update." });
    }

    if (!(user.hiddenChats instanceof Set)) user.hiddenChats = new Set();
    const previous = new Set(user.hiddenChats);
    if (payload.hidden) user.hiddenChats.add(hiddenKey);
    else user.hiddenChats.delete(hiddenKey);

    try {
      // Persist this small privacy action before acknowledging it. The normal
      // debounced writer is still used for other chat activity.
      await flushStatePersistNow();
    } catch (error) {
      user.hiddenChats = previous;
      console.error("Failed to persist hidden chat state:", error);
      return respond({ ok: false, message: "Could not save this chat update. Please try again." });
    }

    const hiddenChats = Array.from(user.hiddenChats);
    socket.emit("hidden_chats_updated", { hiddenChats });
    emitFriendList(userKey);
    respond({
      ok: true,
      username: isGroup ? (groups.get(groupKey)?.name || groupKey) : (users.get(peerKey)?.username || peerKey),
      hidden: payload.hidden,
      hiddenChats,
    });
  });

  socket.on("set_mute", (payload, callback) => {
    const respond = (result) => {
      if (typeof callback === "function") callback(result);
      else if (result?.ok === false) socket.emit("error_message", { message: result.message });
    };
    const userKey = socket.data.userKey;
    if (!userKey) return respond({ ok: false, message: "Please sign in again." });
    if (!allowSocketAction(socket, "set_mute", 80, 60 * 1000)) {
      return respond({ ok: false, message: "Too many notification updates. Try again shortly." });
    }

    const isGroup = payload?.kind === "group" || payload?.group === true;
    const user = users.get(userKey);
    const muted = Boolean(payload?.muted);
    let muteKey = "";
    let targetLabel = "";
    if (isGroup) {
      const groupId = normalizeGroupId(payload?.groupId || payload?.username);
      const group = groups.get(groupId);
      const alreadyMuted = user?.mutedUsers instanceof Set &&
        user.mutedUsers.has(groupId);
      if (!user || ((!group || !isGroupMember(group, userKey)) &&
          !(muted === false && alreadyMuted))) {
        respond({ ok: false, message: "You can only mute notifications for a group you belong to." });
        return;
      }
      muteKey = groupId;
      targetLabel = group?.name || groupId;
    } else {
      const targetKey = normalizeName(payload?.username);
      const target = users.get(targetKey);
      const alreadyMuted = user?.mutedUsers instanceof Set &&
        user.mutedUsers.has(targetKey);
      if (!user || targetKey === userKey ||
          ((!target || !user.friends.has(targetKey)) &&
              !(muted === false && alreadyMuted))) {
        respond({ ok: false, message: "You can only update notifications for a contact." });
        return;
      }
      muteKey = targetKey;
      targetLabel = target?.username || targetKey;
    }
    if (!(user.mutedUsers instanceof Set)) user.mutedUsers = new Set();
    if (muted) user.mutedUsers.add(muteKey);
    else user.mutedUsers.delete(muteKey);
    socket.emit("mute_updated", { username: targetLabel, kind: isGroup ? "group" : "friend", muted });
    emitFriendList(userKey);
    schedulePersist();
    respond({ ok: true, username: targetLabel, kind: isGroup ? "group" : "friend", muted });
  });

  registerMessageMutationHandlers(socket, {
    allowSocketAction,
    toDisplayName,
    withUploadToken,
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
    publicGameMatchmaking.disconnect(userKey, socket.id);
    rajaMantriMatchmaking.disconnect(userKey, socket.id);

    const existingSocketId = onlineUsers.get(userKey);
    if (existingSocketId === socket.id) {
      // Keep the room alive while a disconnected participant is driven by
      // server-side bot turns. A returning account can resume human control.
      for (const [sessionId, entry] of rajaMantriSessions) {
        const connection = setRajaMantriPlayerConnected(entry.game, userKey, false);
        if (!connection.ok) continue;
        scheduleRajaMantriPhaseTimer(entry);
        emitRajaMantriGameUpdate(entry.game);
        for (const player of entry.game.players) {
          if (player.isBot || player.username === userKey) continue;
          const targetSocket = onlineUsers.get(player.username);
          if (targetSocket) {
            io.to(targetSocket).emit("rajamantri_player_connection", {
              sessionId,
              username: userKey,
              displayName: player.displayName,
              connected: false,
              autoPlay: true,
              reason: "disconnected",
            });
          }
        }
      }

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
            io.to(friendSocket).emit("voice_activity", {
              from: user.username,
              isSpeaking: false,
              toType: "friend",
              to: user.username,
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
            io.to(memberSocket).emit("voice_activity", {
              from: user.username,
              isSpeaking: false,
              toType: "group",
              to: group.id,
            });
          }
        }

        user.lastSeenAt = nowIso();
      }

      const activeCall = activeCalls.get(userKey);
      // Keep ringing pairs alive until their server-owned 45-second timeout.
      // This lets the timeout replace a stale incoming-call alert with "Missed call".
      if (activeCall?.status !== "ringing") {
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
    mongoLegacyCollection = null;
    mongoUsersCollection = null;
    mongoConversationsCollection = null;
    mongoMessagesCollection = null;
    mongoAuthSessionsCollection = null;
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

  const preferredPort = parsePort(process.env.PORT, 3000);
  const activePort = await listenWithPortFallback(preferredPort, {
    maxRetries: 0,
  });

  const usingMongo = hasMongoStorage();
  const mediaStorage = hasCloudinaryConfig ? "cloudinary" : `local(${uploadsDir})`;
  console.log(
    `Chat app running on http://localhost:${activePort} | retention=forever (until explicitly deleted) | storage=${usingMongo ? "mongodb(collections)" : "file"} | media=${mediaStorage}`
  );
}

bootstrap().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
