"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createEmailMailer } = require("../services/email_mailer");

test("SMTP configuration activates SMTP provider for non-resend hosts", () => {
  const mailer = createEmailMailer({
    SMTP_HOST: "smtp.gmail.com",
    SMTP_PORT: "465",
    SMTP_USER: "user@gmail.com",
    SMTP_PASS: "secretapppassword",
    SMTP_FROM: "Novyn <user@gmail.com>",
  });

  assert.equal(mailer.configured, true);
  assert.equal(mailer.provider, "smtp");
});

test("Resend SMTP credentials fall back to resend provider", () => {
  const mailer = createEmailMailer({
    SMTP_HOST: "smtp.resend.com",
    SMTP_USER: "resend",
    SMTP_PASS: "re_test_key",
    SMTP_FROM: "Novyn <onboarding@resend.dev>",
  });

  assert.equal(mailer.configured, true);
  assert.equal(mailer.provider, "resend");
});

test("Missing credentials mark mailer as unconfigured", () => {
  const mailer = createEmailMailer({});
  assert.equal(mailer.configured, false);
});
