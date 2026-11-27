"use strict";

let nodemailer = null;
try {
  nodemailer = require("nodemailer");
} catch (_) {
  nodemailer = null;
}

const { createResendMailer, resolveResendConfig } = require("./resend_mailer");

const BREVO_EMAILS_URL = "https://api.brevo.com/v3/smtp/email";

function createBrevoMailer({ apiKey, from, replyTo, timeoutMs = 12000 }) {
  const normalizedKey = String(apiKey || "").trim();
  const configured = Boolean(normalizedKey);

  // Parse "Novyn <email@domain.com>" or "email@domain.com"
  const fromMatch = String(from || "").trim().match(/^(?:(?<name>[^<]+)<)?(?<email>[^>]+)>?$/);
  const senderName = fromMatch?.groups?.name?.trim() || "Novyn";
  const senderEmail = fromMatch?.groups?.email?.trim() || String(from || "").trim();

  return {
    configured,
    provider: "brevo",
    send: async ({ to, subject, text, html, replyTo: msgReplyTo } = {}) => {
      if (!configured) {
        const err = new Error("Brevo is not configured. Set BREVO_API_KEY.");
        err.code = "EMAIL_NOT_CONFIGURED";
        throw err;
      }
      const recipient = String(to || "").trim();
      const title = String(subject || "").trim();
      if (!recipient || !title || (!text && !html)) {
        const err = new Error("Email recipient, subject, and content are required.");
        err.code = "EMAIL_INVALID_MESSAGE";
        throw err;
      }

      const payload = {
        sender: { name: senderName, email: senderEmail },
        to: [{ email: recipient }],
        subject: title,
        ...(text ? { textContent: String(text) } : {}),
        ...(html ? { htmlContent: String(html) } : {}),
        ...(msgReplyTo || replyTo ? { replyTo: { email: String(msgReplyTo || replyTo).trim() } } : {}),
      };

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const response = await fetch(BREVO_EMAILS_URL, {
          method: "POST",
          headers: {
            "api-key": normalizedKey,
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok) {
          const message = data?.message || "Brevo email rejected the request.";
          const err = new Error(message);
          err.code = data?.code || ("BREVO_HTTP_" + response.status);
          err.statusCode = response.status;
          throw err;
        }

        return { id: String(data?.messageId || "brevo_" + Date.now()), provider: "brevo" };
      } finally {
        clearTimeout(timer);
      }
    },
  };
}

function createEmailMailer(env = process.env) {
  // 1. If Brevo API key is set, use Brevo via HTTPS (Port 443 - works everywhere including Render Free Tier)
  const brevoApiKey = String(env.BREVO_API_KEY || "").trim();
  if (brevoApiKey) {
    const from = String(env.BREVO_FROM || env.SMTP_FROM || env.SMTP_USER || "Novyn <novynchat.app@gmail.com>").trim();
    const replyTo = String(env.BREVO_REPLY_TO || env.SMTP_REPLY_TO || env.SMTP_USER || "").trim();
    const timeoutMs = Number(env.EMAIL_API_TIMEOUT_MS) || 12000;
    return createBrevoMailer({ apiKey: brevoApiKey, from, replyTo, timeoutMs });
  }

  // 2. Generic SMTP (ports 465/587 - works on localhost, VPS, and Render Paid instances)
  const smtpHost = String(env.SMTP_HOST || "").trim().toLowerCase();
  const isResendSmtp = smtpHost === "smtp.resend.com";
  const isGenericSmtp = Boolean(smtpHost && !isResendSmtp);

  if (isGenericSmtp) {
    const host = String(env.SMTP_HOST || "").trim();
    const port = Number(env.SMTP_PORT) || 465;
    const secure = env.SMTP_SECURE === "true" || port === 465;
    const user = String(env.SMTP_USER || "").trim();
    const pass = String(env.SMTP_PASS || "").trim();
    const from = String(env.SMTP_FROM || user || "").trim();
    const replyTo = String(env.SMTP_REPLY_TO || user || "").trim();
    const timeoutMs = Number(env.EMAIL_API_TIMEOUT_MS) || 12000;

    const configured = Boolean(host && user && pass && from && nodemailer);

    let transporter = null;
    if (configured) {
      transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        connectionTimeout: timeoutMs,
        greetingTimeout: timeoutMs,
        socketTimeout: timeoutMs,
      });
    }

    return {
      configured,
      provider: "smtp",
      send: async ({ to, subject, text, html, replyTo: msgReplyTo } = {}) => {
        if (!nodemailer) {
          const err = new Error("nodemailer module is not installed.");
          err.code = "MODULE_NOT_FOUND";
          throw err;
        }
        if (!configured || !transporter) {
          const err = new Error("SMTP is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM.");
          err.code = "EMAIL_NOT_CONFIGURED";
          throw err;
        }
        const recipient = String(to || "").trim();
        const title = String(subject || "").trim();
        if (!recipient || !title || (!text && !html)) {
          const err = new Error("Email recipient, subject, and content are required.");
          err.code = "EMAIL_INVALID_MESSAGE";
          throw err;
        }

        const info = await transporter.sendMail({
          from,
          to: recipient,
          subject: title,
          ...(text ? { text: String(text) } : {}),
          ...(html ? { html: String(html) } : {}),
          ...(msgReplyTo || replyTo ? { replyTo: msgReplyTo || replyTo } : {}),
        });

        return { id: info.messageId, provider: "smtp" };
      },
    };
  }

  // 3. Resend HTTPS API
  const resendCfg = resolveResendConfig(env);
  return createResendMailer({
    apiKey: resendCfg.apiKey,
    from: resendCfg.from,
    replyTo: resendCfg.replyTo,
    timeoutMs: Number(env.EMAIL_API_TIMEOUT_MS) || 12000,
  });
}

module.exports = {
  createEmailMailer,
  createBrevoMailer,
};
