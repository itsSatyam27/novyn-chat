"use strict";
const { isAllowedSocketOrigin } = require('../security/origins');

function createSocketAuthMiddleware({ isProduction, allowedOrigins, resolveUserFromAuthCookies, getAuthCookiesFromHeader, normalizeText }) {
  return function socketAuthMiddleware(socket, next) {
    const origin = normalizeText(socket.handshake?.headers?.origin);
    if (!isAllowedSocketOrigin(origin, { isProduction, allowedOrigins })) {
      return next(new Error("Origin not allowed"));
    }

    const auth = resolveUserFromAuthCookies(
      getAuthCookiesFromHeader(socket.handshake?.headers?.cookie),
      { allowRefreshFallback: true }
    );

    if (auth.userKey) {
      socket.data.userKey = auth.userKey;
      socket.data.sessionId = auth.sessionId;
    }

    next();
  };
}

module.exports = { createSocketAuthMiddleware };
