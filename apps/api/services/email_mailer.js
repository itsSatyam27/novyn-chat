"use strict";

const nodemailer = require("nodemailer");
const { createResendMailer, resolveResendConfig } = require("./resend_mailer");

function createEmailMailer(env = process.env) {
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

    const configured = Boolean(host && user && pass && from);

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
};
