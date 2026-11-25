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

  const uploadSecret = String(env.UPLOAD_TOKEN_SECRET || "");
  if (Buffer.byteLength(uploadSecret, "utf8") < 32) {
    issues.push("UPLOAD_TOKEN_SECRET must contain at least 32 bytes of random data in production.");
  }
  if (/^(change_me|replace_with|your_|secret|password)/i.test(uploadSecret.trim())) {
    issues.push("UPLOAD_TOKEN_SECRET must not use a sample or placeholder value in production.");
  }
  if (uploadSecret && (uploadSecret === authSecret || uploadSecret === String(env.CLOUDINARY_API_SECRET || ""))) {
    issues.push("UPLOAD_TOKEN_SECRET must be unique and must not reuse AUTH_SECRET or CLOUDINARY_API_SECRET.");
  }
  return issues;
}

module.exports = { validateProductionSecurityConfig };
