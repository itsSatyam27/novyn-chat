const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { validateProductionStorageConfig } = require("../server/config/production-storage");

test("non-production storage configuration remains permissive", () => {
  assert.deepEqual(validateProductionStorageConfig({ NODE_ENV: "development" }), []);
  assert.deepEqual(validateProductionStorageConfig({ NODE_ENV: "test" }), []);
});

test("production requires MongoDB or an explicit absolute persistent data directory", () => {
  assert.match(
    validateProductionStorageConfig({
      NODE_ENV: "production",
      CLOUDINARY_CLOUD_NAME: "cloud",
      CLOUDINARY_API_KEY: "key",
      CLOUDINARY_API_SECRET: "secret",
    }).join(" "),
    /MONGODB_URI or an absolute DATA_DIR/,
  );

  assert.doesNotMatch(
    validateProductionStorageConfig({
      NODE_ENV: "production",
      DATA_DIR: path.resolve("/var/data/novyn"),
      CLOUDINARY_CLOUD_NAME: "cloud",
      CLOUDINARY_API_KEY: "key",
      CLOUDINARY_API_SECRET: "secret",
    }).join(" "),
    /DATA_DIR/,
  );
});

test("production requires Cloudinary or an explicit absolute persistent uploads directory", () => {
  assert.match(
    validateProductionStorageConfig({
      NODE_ENV: "production",
      MONGODB_URI: "mongodb://example.test/novyn",
    }).join(" "),
    /Cloudinary or set an absolute UPLOADS_DIR/,
  );

  assert.doesNotMatch(
    validateProductionStorageConfig({
      NODE_ENV: "production",
      MONGODB_URI: "mongodb://example.test/novyn",
      UPLOADS_DIR: path.resolve("/var/data/novyn-uploads"),
    }).join(" "),
    /UPLOADS_DIR/,
  );
});

test("relative paths do not count as explicit persistent production storage", () => {
  const issues = validateProductionStorageConfig({
    NODE_ENV: "production",
    DATA_DIR: "./runtime/data",
    UPLOADS_DIR: "./runtime/uploads",
  });
  assert.equal(issues.length, 2);
});
