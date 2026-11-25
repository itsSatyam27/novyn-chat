const crypto = require("crypto");

const PBKDF2_ITERATIONS = 310000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_DIGEST = "sha256";
const DUMMY_SALT = crypto.randomBytes(16).toString("hex");
const DUMMY_HASH = crypto.pbkdf2Sync(
  crypto.randomBytes(32).toString("hex"),
  DUMMY_SALT,
  PBKDF2_ITERATIONS,
  PBKDF2_KEYLEN,
  PBKDF2_DIGEST,
).toString("hex");

function derivePasswordKey(password, salt, iterations) {
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(
      password,
      salt,
      iterations,
      PBKDF2_KEYLEN,
      PBKDF2_DIGEST,
      (error, key) => (error ? reject(error) : resolve(key)),
    );
  });
}

async function createPasswordSecret(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = (await derivePasswordKey(
    String(password || ""),
    salt,
    PBKDF2_ITERATIONS,
  )).toString("hex");
  return { passwordSalt: salt, passwordHash: hash, iterations: PBKDF2_ITERATIONS };
}

async function verifyPassword(password, salt, hash, iterations = PBKDF2_ITERATIONS) {
  // Even missing users or accounts without a password hash execute one PBKDF2
  // derivation. This makes credential failures materially harder to enumerate
  // by comparing response timing.
  const hasStoredSecret = Boolean(salt && hash);
  const candidate = (await derivePasswordKey(
    String(password || ""),
    hasStoredSecret ? String(salt) : DUMMY_SALT,
    hasStoredSecret ? (Number(iterations) || PBKDF2_ITERATIONS) : PBKDF2_ITERATIONS,
  )).toString("hex");
  const left = Buffer.from(candidate, "hex");
  const right = Buffer.from(hasStoredSecret ? String(hash) : DUMMY_HASH, "hex");
  const matches = left.length === right.length && crypto.timingSafeEqual(left, right);
  return hasStoredSecret && matches;
}

module.exports = { createPasswordSecret, verifyPassword };
