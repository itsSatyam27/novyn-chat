const crypto = require("crypto");

const PBKDF2_ITERATIONS = 310000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_DIGEST = "sha256";

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
  if (!salt || !hash) return false;
  const candidate = (await derivePasswordKey(
    String(password || ""),
    String(salt),
    Number(iterations) || PBKDF2_ITERATIONS,
  )).toString("hex");
  const left = Buffer.from(candidate, "hex");
  const right = Buffer.from(String(hash), "hex");
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

module.exports = { createPasswordSecret, verifyPassword };
