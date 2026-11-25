function parseAllowedSocketOrigins(rawOrigins, { isProduction = false } = {}) {
  const origins = String(rawOrigins || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (!isProduction) return origins;
  if (!origins.length) {
    throw new Error("ALLOWED_ORIGIN must contain at least one exact HTTPS browser origin in production.");
  }

  const invalidOrigins = origins.filter((origin) => {
    try {
      const url = new URL(origin);
      return url.protocol !== "https:" ||
        !url.hostname ||
        Boolean(url.username || url.password) ||
        url.origin !== origin;
    } catch {
      return true;
    }
  });

  if (invalidOrigins.length) {
    throw new Error(
      "ALLOWED_ORIGIN must contain only exact HTTPS origins without paths, query strings, or trailing slashes. Invalid: " +
      invalidOrigins.join(", ")
    );
  }

  return [...new Set(origins)];
}

function isAllowedSocketOrigin(origin, { isProduction, allowedOrigins }) {
  // Native Socket.IO clients (Flutter, desktop) do not send a browser Origin
  // header. CORS is a browser boundary; authentication still protects every
  // socket action after this transport-level check.
  if (!origin) return true;
  if (allowedOrigins.includes(origin)) return true;
  if (isProduction) return false;
  try {
    const url = new URL(origin);
    return ['http:', 'https:'].includes(url.protocol) &&
      ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) &&
      !url.username && !url.password && url.origin === origin;
  } catch {
    return false;
  }
}

module.exports = { isAllowedSocketOrigin, parseAllowedSocketOrigins };
