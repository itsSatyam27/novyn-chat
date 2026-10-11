const crypto = require("crypto");

function base32Decode(base32) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  const cleaned = String(base32 || "").toUpperCase().replace(/=+$/, "").replace(/\s+/g, "");
  for (const char of cleaned) {
    const val = alphabet.indexOf(char);
    if (val === -1) return null;
    bits += val.toString(2).padStart(5, "0");
  }
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    bytes.push(parseInt(bits.substr(i, 8), 2));
  }
  return Buffer.from(bytes);
}

function generateTOTP(secretBase32, timeStepOffset = 0) {
  const epoch = Math.floor(Date.now() / 1000);
  const counter = Math.floor(epoch / 30) + timeStepOffset;
  const buf = Buffer.alloc(8);
  buf.writeBigInt64BE(BigInt(counter));
  const key = base32Decode(secretBase32);
  if (!key || key.length === 0) return "";
  const hmac = crypto.createHmac("sha1", key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code =
    ((hmac[offset] & 0x7f) << 24 |
      (hmac[offset + 1] & 0xff) << 16 |
      (hmac[offset + 2] & 0xff) << 8 |
      (hmac[offset + 3] & 0xff)) %
    1000000;
  return String(code).padStart(6, "0");
}

function verifyTotpCode(secretBase32, code) {
  if (!secretBase32 || !code) return false;
  const cleanedCode = String(code).trim().replace(/\s+/g, "");
  if (!/^\d{6}$/.test(cleanedCode)) return false;

  for (let offset = -1; offset <= 1; offset++) {
    const calculated = generateTOTP(secretBase32, offset);
    if (calculated && calculated === cleanedCode) {
      return true;
    }
  }
  return false;
}

module.exports = { base32Decode, generateTOTP, verifyTotpCode };
