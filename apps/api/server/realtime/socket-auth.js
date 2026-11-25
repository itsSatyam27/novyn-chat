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

    // Socket connections must be authenticated before any event handlers can run.
    // Individual events still perform authorization for their specific resources.
    if (!auth?.userKey) {
      return next(new Error("Authentication required"));
    }

    socket.data.userKey = auth.userKey;
    socket.data.sessionId = auth.sessionId || null;
    next();
  };
}

module.exports = { createSocketAuthMiddleware };
