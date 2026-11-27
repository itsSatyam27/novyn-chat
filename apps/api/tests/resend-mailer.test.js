"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  RESEND_EMAILS_URL,
  createResendMailer,
} = require("../services/resend_mailer");

test("legacy Resend SMTP credentials are reused only for the official Resend host", () => {
  const { resolveResendConfig } = require("../services/resend_mailer");
  const legacy = resolveResendConfig({
    SMTP_HOST: "smtp.resend.com",
    SMTP_USER: "resend",
    SMTP_PASS: "re_existing_resend_api_key",
    SMTP_FROM: "Novyn <onboarding@resend.dev>",
    SMTP_REPLY_TO: "support@example.com",
  });
  assert.equal(legacy.apiKey, "re_existing_resend_api_key");
  assert.equal(legacy.from, "Novyn <onboarding@resend.dev>");
  assert.equal(legacy.replyTo, "support@example.com");
  assert.equal(legacy.usedLegacyResendConfig, true);

  const unrelatedSmtp = resolveResendConfig({
    SMTP_HOST: "smtp.example.com",
    SMTP_USER: "user",
    SMTP_PASS: "must-not-be-used",
    SMTP_FROM: "Legacy <sender@example.com>",
  });
  assert.equal(unrelatedSmtp.apiKey, "");
  assert.equal(unrelatedSmtp.from, "");
  assert.equal(unrelatedSmtp.usedLegacyResendConfig, false);
});

test("explicit Resend API configuration takes precedence over legacy SMTP values", () => {
  const { resolveResendConfig } = require("../services/resend_mailer");
  const config = resolveResendConfig({
    RESEND_API_KEY: "re_new_api_key",
    RESEND_FROM: "Novyn <no-reply@example.com>",
    SMTP_HOST: "smtp.resend.com",
    SMTP_USER: "resend",
    SMTP_PASS: "re_old_api_key",
    SMTP_FROM: "Old <onboarding@resend.dev>",
  });
  assert.equal(config.apiKey, "re_new_api_key");
  assert.equal(config.from, "Novyn <no-reply@example.com>");
  assert.equal(config.usedLegacyResendConfig, false);
});

test("Resend mailer sends through HTTPS with provider auth and configured sender", async () => {
  let request;
  const mailer = createResendMailer({
    apiKey: "re_test_key",
    from: "Novyn <no-reply@example.com>",
    replyTo: "support@example.com",
    fetchImpl: async (url, options) => {
      request = { url, options };
      return { ok: true, status: 200, json: async () => ({ id: "email_123" }) };
    },
  });

  const result = await mailer.send({
    to: "person@example.com",
    subject: "Your Novyn password reset code",
    text: "Your code is 123456.",
    idempotencyKey: "password-reset/token-123",
  });

  assert.equal(mailer.configured, true);
  assert.deepEqual(result, { id: "email_123", provider: "resend" });
  assert.equal(request.url, RESEND_EMAILS_URL);
  assert.equal(request.options.method, "POST");
  assert.equal(request.options.headers.Authorization, "Bearer re_test_key");
  assert.equal(request.options.headers["Idempotency-Key"], "password-reset/token-123");
  assert.deepEqual(JSON.parse(request.options.body), {
    from: "Novyn <no-reply@example.com>",
    to: ["person@example.com"],
    subject: "Your Novyn password reset code",
    text: "Your code is 123456.",
    reply_to: "support@example.com",
  });
});

test("Resend mailer reports provider rejections without claiming delivery", async () => {
  const mailer = createResendMailer({
    apiKey: "re_test_key",
    from: "Novyn <no-reply@example.com>",
    fetchImpl: async () => ({
      ok: false,
      status: 401,
      json: async () => ({ name: "validation_error", message: "API key is invalid" }),
    }),
  });

  await assert.rejects(
    mailer.send({ to: "person@example.com", subject: "Test", text: "Test" }),
    (error) => error.code === "validation_error" && error.statusCode === 401,
  );
});

test("Resend mailer requires API key and a verified sender configuration", async () => {
  const mailer = createResendMailer({ apiKey: "", from: "", fetchImpl: async () => {} });
  assert.equal(mailer.configured, false);
  await assert.rejects(
    mailer.send({ to: "person@example.com", subject: "Test", text: "Test" }),
    (error) => error.code === "EMAIL_NOT_CONFIGURED",
  );
});

test("Resend mailer surfaces HTTPS request timeouts", async () => {
  const mailer = createResendMailer({
    apiKey: "re_test_key",
    from: "Novyn <no-reply@example.com>",
    timeoutMs: 1000,
    fetchImpl: (_url, { signal }) => new Promise((resolve, reject) => {
      signal.addEventListener("abort", () => {
        const error = new Error("aborted");
        error.name = "AbortError";
        reject(error);
      }, { once: true });
    }),
  });

  await assert.rejects(
    mailer.send({ to: "person@example.com", subject: "Test", text: "Test" }),
    (error) => error.code === "EMAIL_API_TIMEOUT",
  );
});
