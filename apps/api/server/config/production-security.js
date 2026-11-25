"use strict";

function validateProductionSecurityConfig(env = process.env) {
  if (String(env.NODE_ENV || "").trim().toLowerCase() !== "production") return [];
  const issues = [];
  const authSecret = String(env.AUTH_SECRET || "");
  if (Buffer.byteLength(authSecret, "utf8") < 32) {
    issues.push("AUTH_SECRET must contain at least 32 bytes of high-entropy random data in production.");
  }
  if (/^(change_me|replace_with|your_|secret|password)/i.test(authSecret.trim())) {
    issues.push("AUTH_SECRET must not use a sample or placeholder value in production.");
  }
  return issues;
}

module.exports = { validateProductionSecurityConfig };
