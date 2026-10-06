const crypto = require("crypto");

const PBKDF2_ITERATIONS = 310000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_DIGEST = "sha256";

function createPasswordSecret(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto
    .pbkdf2Sync(String(password || ""), salt, PBKDF2_ITERATIONS, PBKDF2_KEYLEN, PBKDF2_DIGEST)
    .toString("hex");
  return { passwordSalt: salt, passwordHash: hash, iterations: PBKDF2_ITERATIONS };
}

function verifyPassword(password, salt, hash, iterations = PBKDF2_ITERATIONS) {
  if (!salt || !hash) return false;
  const candidate = crypto
    .pbkdf2Sync(String(password || ""), String(salt), Number(iterations) || PBKDF2_ITERATIONS, PBKDF2_KEYLEN, PBKDF2_DIGEST)
    .toString("hex");
  const left = Buffer.from(candidate, "hex");
  const right = Buffer.from(String(hash), "hex");
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

module.exports = { createPasswordSecret, verifyPassword };
