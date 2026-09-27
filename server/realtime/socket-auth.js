"use strict";

function createSocketAuthMiddleware({ isProduction, allowedOrigins, resolveUserFromAuthCookies, getAuthCookiesFromHeader, normalizeText }) {
  return function socketAuthMiddleware(socket, next) {
    const origin = normalizeText(socket.handshake?.headers?.origin);
    if (isProduction && (!origin || !allowedOrigins.includes(origin))) {
      return next(new Error("Origin not allowed"));
    }

    const auth = resolveUserFromAuthCookies(
      getAuthCookiesFromHeader(socket.handshake?.headers?.cookie),
      { allowRefreshFallback: true }
    );

    if (auth.userKey) {
      socket.data.userKey = auth.userKey;
    }

    next();
  };
}

module.exports = { createSocketAuthMiddleware };
