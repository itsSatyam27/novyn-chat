"use strict";

const RESEND_EMAILS_URL = "https://api.resend.com/emails";

class EmailDeliveryError extends Error {
  constructor(message, { code = "EMAIL_DELIVERY_FAILED", statusCode = 0 } = {}) {
    super(message);
    this.name = "EmailDeliveryError";
    this.code = code;
    this.statusCode = statusCode;
  }
}

function createResendMailer({
  apiKey = process.env.RESEND_API_KEY,
  from = process.env.RESEND_FROM,
  replyTo = process.env.RESEND_REPLY_TO,
  timeoutMs = Number(process.env.EMAIL_API_TIMEOUT_MS) || 12000,
  fetchImpl = globalThis.fetch,
} = {}) {
  const normalizedApiKey = String(apiKey || "").trim();
  const normalizedFrom = String(from || "").trim();
  const normalizedReplyTo = String(replyTo || "").trim();
  const configured = Boolean(normalizedApiKey && normalizedFrom && typeof fetchImpl === "function");

  async function send({ to, subject, text, html, replyTo: messageReplyTo, idempotencyKey } = {}) {
    if (!configured) {
      throw new EmailDeliveryError(
        "Email API is not configured. Set RESEND_API_KEY and RESEND_FROM.",
        { code: "EMAIL_NOT_CONFIGURED" },
      );
    }

    const recipient = String(to || "").trim();
    const title = String(subject || "").trim();
    if (!recipient || !title || (!text && !html)) {
      throw new EmailDeliveryError("Email recipient, subject, and content are required.", {
        code: "EMAIL_INVALID_MESSAGE",
      });
    }

    const payload = {
      from: normalizedFrom,
      to: [recipient],
      subject: title,
      ...(text ? { text: String(text) } : {}),
      ...(html ? { html: String(html) } : {}),
    };
    const selectedReplyTo = String(messageReplyTo || normalizedReplyTo).trim();
    if (selectedReplyTo) payload.reply_to = selectedReplyTo;

    const headers = {
      Authorization: "Bearer " + normalizedApiKey,
      "Content-Type": "application/json",
      Accept: "application/json",
    };
    const requestKey = String(idempotencyKey || "").trim();
    if (requestKey) headers["Idempotency-Key"] = requestKey.slice(0, 256);

    const controller = new AbortController();
    let timeout;
    let timedOut = false;
    const timeoutPromise = new Promise((_, reject) => {
      timeout = setTimeout(() => {
        timedOut = true;
        controller.abort();
        reject(new EmailDeliveryError("Email API request timed out.", {
          code: "EMAIL_API_TIMEOUT",
        }));
      }, Math.max(1000, Number(timeoutMs) || 12000));
    });

    try {
      const request = (async () => {
        const response = await fetchImpl(RESEND_EMAILS_URL, {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        let result = {};
        try {
          result = await response.json();
        } catch (_) {
          result = {};
        }

        if (!response.ok) {
          const providerMessage = String(
            result?.message || result?.error || "Email provider rejected the request.",
          ).replace(/[\r\n]+/g, " ").slice(0, 220);
          throw new EmailDeliveryError(providerMessage, {
            code: String(result?.name || result?.code || ("RESEND_HTTP_" + response.status)).slice(0, 80),
            statusCode: Number(response.status) || 0,
          });
        }

        const emailId = String(result?.id || "").trim();
        if (!emailId) {
          throw new EmailDeliveryError("Email provider returned success without an email ID.", {
            code: "EMAIL_PROVIDER_INVALID_RESPONSE",
            statusCode: Number(response.status) || 0,
          });
        }
        return { id: emailId, provider: "resend" };
      })();

      return await Promise.race([request, timeoutPromise]);
    } catch (error) {
      if (error instanceof EmailDeliveryError) throw error;
      if (timedOut || error?.name === "AbortError") {
        throw new EmailDeliveryError("Email API request timed out.", { code: "EMAIL_API_TIMEOUT" });
      }
      const diagnostic = String(error?.message || "Email API network error.")
        .replace(/[\r\n]+/g, " ")
        .slice(0, 220);
      throw new EmailDeliveryError(diagnostic, {
        code: String(error?.code || "EMAIL_API_NETWORK_ERROR").slice(0, 80),
      });
    } finally {
      if (timeout) clearTimeout(timeout);
    }
  }

  return {
    configured,
    provider: "resend",
    send,
  };
}

module.exports = {
  RESEND_EMAILS_URL,
  EmailDeliveryError,
  createResendMailer,
};
