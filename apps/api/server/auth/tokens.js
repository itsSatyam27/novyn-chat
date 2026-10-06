const crypto = require("crypto");
const { normalizeName, toDisplayName } = require("../core/normalization");

function toBase64Url(value) {
  return Buffer.from(value).toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function fromBase64Url(value) {
  const normalized = String(value || "").replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + padding, "base64");
}

function createAuthToken({ secret, kind, userKey, ttlMs, extra = {} }) {
  if (!secret) throw new Error("Auth secret is required.");
  const now = Date.now();
  const payload = {
    sub: normalizeName(userKey),
    kind: toDisplayName(kind),
    iat: now,
    exp: now + Math.max(1000, Number(ttlMs) || 0),
    ...extra,
  };
  const headerPart = toBase64Url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payloadPart = toBase64Url(JSON.stringify(payload));
  const body = headerPart + "." + payloadPart;
  const signature = crypto.createHmac("sha256", secret).update(body).digest();
  return body + "." + toBase64Url(signature);
}

function verifyAuthToken({ secret, rawToken, expectedKind }) {
  if (!secret) return null;
  const token = String(rawToken || "");
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const [headerPart, payloadPart, sigPart] = parts;
  if (!headerPart || !payloadPart || !sigPart) return null;

  const body = headerPart + "." + payloadPart;
  const expectedSig = crypto.createHmac("sha256", secret).update(body).digest();

  let actualSig;
  try {
    actualSig = fromBase64Url(sigPart);
  } catch (_) {
    return null;
  }
  if (actualSig.length !== expectedSig.length) return null;
  if (!crypto.timingSafeEqual(actualSig, expectedSig)) return null;

  let payload;
  try {
    payload = JSON.parse(fromBase64Url(payloadPart).toString("utf8"));
  } catch (_) {
    return null;
  }

  if (!payload || typeof payload !== "object") return null;
  if (expectedKind && payload.kind !== expectedKind) return null;

  const subjectKey = normalizeName(payload.sub);
  if (!subjectKey) return null;

  const exp = Number(payload.exp);
  if (!Number.isFinite(exp) || exp <= Date.now()) return null;
  return payload;
}

module.exports = {
  createAuthToken,
  verifyAuthToken,
};
