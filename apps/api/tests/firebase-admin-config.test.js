const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

test("Firebase Admin loads service-account credentials from a configured file", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "novyn-firebase-admin-"));
  try {
    const { privateKey } = crypto.generateKeyPairSync("rsa", {
      modulusLength: 2048,
      publicExponent: 0x10001,
    });
    const serviceAccountPath = path.join(directory, "service-account.json");
    fs.writeFileSync(serviceAccountPath, JSON.stringify({
      type: "service_account",
      project_id: "novyn-file-config-test",
      private_key_id: "test-key-id",
      private_key: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
      client_email: "novyn-test@novyn-file-config-test.iam.gserviceaccount.com",
      client_id: "1234567890",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
    }));

    const script = [
      'const { firebaseAdmin } = require("./apps/api/server/config/firebase-admin");',
      'if (!firebaseAdmin || firebaseAdmin.options.projectId !== "novyn-file-config-test") process.exit(2);',
    ].join("\n");
    const result = spawnSync(process.execPath, ["-e", script], {
      cwd: path.resolve(__dirname, "../../.."),
      env: {
        ...process.env,
        FIREBASE_SERVICE_ACCOUNT_JSON: "",
        FIREBASE_SERVICE_ACCOUNT_FILE: serviceAccountPath,
        FIREBASE_PROJECT_ID: "",
        FIREBASE_CLIENT_EMAIL: "",
        FIREBASE_PRIVATE_KEY: "",
      },
      encoding: "utf8",
      timeout: 10_000,
    });

    assert.equal(result.error, undefined, result.error?.message);
    assert.equal(result.status, 0, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
