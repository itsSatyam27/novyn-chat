const test = require("node:test");
const assert = require("node:assert/strict");
const { validateProductionSecurityConfig } = require("../server/config/production-security");

test("non-production environments keep development secret fallbacks", () => {
  assert.deepEqual(validateProductionSecurityConfig({ NODE_ENV: "development" }), []);
  assert.deepEqual(validateProductionSecurityConfig({ NODE_ENV: "test" }), []);
});

test("production requires a strong non-placeholder authentication secret", () => {
  assert.match(
    validateProductionSecurityConfig({ NODE_ENV: "production", AUTH_SECRET: "short-secret" }).join(" "),
    /at least 32 bytes/,
  );
  assert.match(
    validateProductionSecurityConfig({ NODE_ENV: "production", AUTH_SECRET: "replace_with_a_long_random_secret_value" }).join(" "),
    /placeholder/,
  );
  assert.match(
    validateProductionSecurityConfig({ NODE_ENV: "production", AUTH_SECRET: "R".repeat(48) }).join(" "),
    /UPLOAD_TOKEN_SECRET must contain at least 32 bytes/,
  );
  assert.deepEqual(
    validateProductionSecurityConfig({
      NODE_ENV: "production",
      AUTH_SECRET: "R".repeat(48),
      UPLOAD_TOKEN_SECRET: "U".repeat(48),
      CLOUDINARY_API_SECRET: "C".repeat(40),
    }),
    [],
  );
  assert.match(
    validateProductionSecurityConfig({
      NODE_ENV: "production", AUTH_SECRET: "R".repeat(48), UPLOAD_TOKEN_SECRET: "R".repeat(48),
    }).join(" "),
    /must be unique/,
  );
  assert.match(
    validateProductionSecurityConfig({
      NODE_ENV: "production", AUTH_SECRET: "R".repeat(48), UPLOAD_TOKEN_SECRET: "your_upload_token_secret_value",
    }).join(" "),
    /placeholder value/,
  );
});
