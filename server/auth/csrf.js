const crypto = require("crypto");
const { toDisplayName } = require("../core/normalization");

function parseCookies(rawCookieHeader) {
  const header = String(rawCookieHeader || "");
  const out = {};
  if (!header) return out;
  for (const part of header.split(";")) {
    const idx = part.indexOf("=");
    if (idx <= 0) continue;
    const key = part.slice(0, idx).trim();
    const value = part.slice(idx + 1).trim();
    if (!key) continue;
    try { out[key] = decodeURIComponent(value); } catch (_) { out[key] = value; }
  }
  return out;
}

function safeTimingEqual(left, right) {
  const leftBuffer = Buffer.from(String(left || ""));
  const rightBuffer = Buffer.from(String(right || ""));
  if (!leftBuffer.length || leftBuffer.length !== rightBuffer.length) return false;
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function createCsrf({ cookieName, headerName, secure, tokenBytes = 24 }) {
  const createToken = () => crypto.randomBytes(tokenBytes).toString("hex");

  function ensureCookie(req, res) {
    if (!res || typeof res.cookie !== "function") return "";
    const cookies = parseCookies(req?.headers?.cookie);
    const existing = toDisplayName(cookies[cookieName]);
    const token = existing || createToken();
    if (!existing) {
      res.cookie(cookieName, token, {
        httpOnly: false,
        sameSite: "lax",
        secure,
        path: "/",
      });
    }
    return token;
  }

  function isSameOriginRequest(req) {
    const host = toDisplayName(req?.headers?.host).toLowerCase();
    if (!host) return false;
    const source = toDisplayName(req?.headers?.origin || req?.headers?.referer).toLowerCase();
    if (!source) {
      const fetchSite = toDisplayName(req?.headers?.["sec-fetch-site"]).toLowerCase();
      if (!fetchSite) return true;
      return fetchSite === "same-origin" || fetchSite === "same-site";
    }
    try {
      const parsed = new URL(source);
      if (parsed.host.toLowerCase() === host) return true;
      const isLocalhost = (value) =>
        ['localhost', '127.0.0.1', '[::1]'].includes(new URL(`http://${value}`).hostname);
      return process.env.NODE_ENV !== 'production' && isLocalhost(parsed.host) && isLocalhost(host);
    } catch (_) {
      return false;
    }
  }

  function middleware(req, res, next) {
    if (req.method === "GET" || req.method === "HEAD" || req.method === "OPTIONS") {
      next();
      return;
    }
    const token = ensureCookie(req, res);
    const cookies = parseCookies(req?.headers?.cookie);
    const cookieToken = toDisplayName(cookies[cookieName]) || token;
    const headerToken = toDisplayName(req?.headers?.[headerName]) || toDisplayName(req?.body?.csrfToken);
    if (!(cookieToken && headerToken && safeTimingEqual(cookieToken, headerToken)) &&
        process.env.NODE_ENV === "production") {
      res.status(403).json({ message: "Invalid CSRF token.", error: "Invalid CSRF token." });
      return;
    }
    if (!isSameOriginRequest(req)) {
      res.status(403).json({ message: "Cross-site request blocked.", error: "Cross-site request blocked." });
      return;
    }
    next();
  }

  return { createToken, ensureCookie, isSameOriginRequest, middleware };
}

module.exports = { parseCookies, safeTimingEqual, createCsrf };
