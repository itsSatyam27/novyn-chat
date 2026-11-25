const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ALLOWED_VOICE_MIME,
  ALLOWED_FILE_MIME,
  MULTIPART_LIMITS,
  createUploadFileFilter,
  mapMultipartError,
  uploadCloudMediaWithMetadata,
} = require("../server/security/uploads");

function runFilter(filter, mime) {
  return new Promise((resolve, reject) => {
    filter({}, { mimetype: mime }, (error, accepted) => {
      if (error) reject(error);
      else resolve(accepted);
    });
  });
}

test("upload MIME filters accept known supported formats case-insensitively", async () => {
  assert.equal(await runFilter(createUploadFileFilter(ALLOWED_VOICE_MIME), "Audio/WebM"), true);
  assert.equal(await runFilter(createUploadFileFilter(ALLOWED_FILE_MIME), "image/png"), true);
  assert.equal(await runFilter(createUploadFileFilter(ALLOWED_FILE_MIME), "application/pdf"), true);
});

test("upload MIME filters reject unsupported formats before staging", async () => {
  await assert.rejects(
    runFilter(createUploadFileFilter(ALLOWED_FILE_MIME), "text/html"),
    (error) => error.code === "NOVYN_UNSUPPORTED_FILE_TYPE",
  );
  await assert.rejects(
    runFilter(createUploadFileFilter(ALLOWED_VOICE_MIME), "application/octet-stream"),
    (error) => error.code === "NOVYN_UNSUPPORTED_FILE_TYPE",
  );
});

test("multipart request limits cap files, fields, field bytes, and total parts", () => {
  assert.equal(MULTIPART_LIMITS.files, 1);
  assert.equal(MULTIPART_LIMITS.fields, 10);
  assert.equal(MULTIPART_LIMITS.fieldSize, 16 * 1024);
  assert.equal(MULTIPART_LIMITS.parts, 12);
});

test("multipart errors map size and MIME failures to safe client responses", () => {
  assert.deepEqual(mapMultipartError({ code: "LIMIT_FILE_SIZE" }), {
    status: 413, message: "File is too large.",
  });
  assert.deepEqual(mapMultipartError({ code: "NOVYN_UNSUPPORTED_FILE_TYPE" }), {
    status: 415, message: "Unsupported file type.",
  });
  assert.deepEqual(mapMultipartError({ code: "LIMIT_FIELD_COUNT" }), {
    status: 413, message: "Upload request contains too much form data.",
  });
});


test("Cloudinary media is removed if ownership metadata cannot be persisted", async () => {
  const uploaded = { public_id: "novyn/test-object", resource_type: "video" };
  const calls = [];
  const expectedError = new Error("MongoDB metadata write failed");

  await assert.rejects(
    uploadCloudMediaWithMetadata({
      upload: async () => uploaded,
      saveMetadata: async () => { calls.push("metadata"); throw expectedError; },
      cleanup: async (result) => { calls.push(["cleanup", result]); },
    }),
    (error) => error === expectedError,
  );
  assert.deepEqual(calls, ["metadata", ["cleanup", uploaded]]);
});

test("Cloudinary cleanup failure is reported without hiding the metadata error", async () => {
  const uploaded = { public_id: "novyn/test-object", resource_type: "image" };
  const metadataError = new Error("MongoDB metadata write failed");
  const cleanupError = new Error("Cloudinary destroy failed");
  let observedCleanupError;

  await assert.rejects(
    uploadCloudMediaWithMetadata({
      upload: async () => uploaded,
      saveMetadata: async () => { throw metadataError; },
      cleanup: async () => { throw cleanupError; },
      onCleanupError: (error, result) => {
        observedCleanupError = { error, result };
      },
    }),
    (error) => error === metadataError,
  );
  assert.deepEqual(observedCleanupError, { error: cleanupError, result: uploaded });
});

test("Cloudinary upload metadata success keeps the uploaded object", async () => {
  const uploaded = { public_id: "novyn/test-object", resource_type: "raw" };
  let persisted = false;
  let cleanupCalled = false;

  const result = await uploadCloudMediaWithMetadata({
    upload: async () => uploaded,
    saveMetadata: async (value) => { persisted = value === uploaded; },
    cleanup: async () => { cleanupCalled = true; },
  });

  assert.equal(result, uploaded);
  assert.equal(persisted, true);
  assert.equal(cleanupCalled, false);
});
