function isAllowedSocketOrigin(origin, { isProduction, allowedOrigins }) {
  if (!origin) return !isProduction;
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

module.exports = { isAllowedSocketOrigin };
