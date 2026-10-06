const dns = require("dns").promises;
const net = require("net");
const http = require('node:http');
const https = require('node:https');
const { Readable } = require('node:stream');

const ssrfBlockList = new net.BlockList();

[
  ["127.0.0.0", 8, "ipv4"], ["0.0.0.0", 8, "ipv4"], ["10.0.0.0", 8, "ipv4"],
  ["100.64.0.0", 10, "ipv4"], ["169.254.0.0", 16, "ipv4"], ["172.16.0.0", 12, "ipv4"],
  ["192.0.0.0", 24, "ipv4"], ["192.0.2.0", 24, "ipv4"], ["192.168.0.0", 16, "ipv4"],
  ["198.18.0.0", 15, "ipv4"], ["198.51.100.0", 24, "ipv4"], ["203.0.113.0", 24, "ipv4"],
  ["224.0.0.0", 4, "ipv4"], ["::", 128, "ipv6"], ["::1", 128, "ipv6"], ["fc00::", 7, "ipv6"],
  ["fe80::", 10, "ipv6"], ["ff00::", 8, "ipv6"]
].forEach(([address, prefix, type]) => ssrfBlockList.addSubnet(address, prefix, type));

function isBlockedSsrfIp(ip) {
  const version = net.isIP(ip);
  return version === 4
    ? ssrfBlockList.check(ip, "ipv4")
    : version === 6
      ? ssrfBlockList.check(ip, "ipv6")
      : true;
}

async function resolveSafeExternalUrl(rawUrl) {
  const parsed = new URL(String(rawUrl || ""));
  if (!["http:", "https:"].includes(parsed.protocol)) throw new Error("Unsupported URL scheme");
  if (parsed.username || parsed.password) throw new Error("URL credentials are not allowed");
  if ((parsed.protocol === "http:" && parsed.port && parsed.port !== "80") ||
      (parsed.protocol === "https:" && parsed.port && parsed.port !== "443")) {
    throw new Error("Unsupported URL port");
  }

  const host = parsed.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  const addresses = net.isIP(host)
    ? [{ address: host }]
    : await dns.lookup(host, { all: true, verbatim: true });

  if (!addresses.length || addresses.some((entry) => isBlockedSsrfIp(entry.address))) {
    throw new Error("Unsafe destination");
  }

  return { url: parsed, addresses };
}

async function assertSafeExternalUrl(rawUrl) {
  return (await resolveSafeExternalUrl(rawUrl)).url;
}

// Pin the validated DNS answer for the actual connection. A second independent
// DNS lookup by fetch would otherwise allow DNS rebinding into private networks.
async function fetchSafeExternalUrl(rawUrl, { headers = {}, timeoutMs = 5000 } = {}) {
  const { url, addresses } = await resolveSafeExternalUrl(rawUrl);
  return new Promise((resolve, reject) => {
    const address = addresses[0];
    const request = (url.protocol === 'https:' ? https : http).get(url, {
      headers,
      lookup: (_hostname, options, callback) => {
        const entry = { address: address.address, family: net.isIP(address.address) };
        if (options.all) callback(null, [entry]);
        else callback(null, entry.address, entry.family);
      },
    });
    const timer = setTimeout(() => request.destroy(new Error('External request timed out')), timeoutMs);
    request.on('error', (error) => { clearTimeout(timer); reject(error); });
    request.on('response', (incoming) => {
      incoming.once('close', () => clearTimeout(timer));
      const responseHeaders = new Headers();
      for (const [key, value] of Object.entries(incoming.headers)) {
        if (value !== undefined) responseHeaders.set(key, Array.isArray(value) ? value.join(', ') : value);
      }
      const status = incoming.statusCode || 502;
      // Redirects remain manual and are rejected by callers.
      if ([204, 205, 304].includes(status)) {
        incoming.resume();
        resolve(new Response(null, { status, headers: responseHeaders }));
      } else {
        resolve(new Response(Readable.toWeb(incoming), { status, headers: responseHeaders }));
      }
    });
  });
}

async function readResponseBufferWithLimit(response, maxBytes) {
  const length = Number(response.headers.get("content-length") || 0);
  if (length > maxBytes) throw new Error("Response too large");
  if (!response.body) return Buffer.alloc(0);

  const reader = response.body.getReader();
  const chunks = [];
  let total = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new Error("Response too large");
    }
    chunks.push(Buffer.from(value));
  }

  return Buffer.concat(chunks, total);
}

async function readResponseWithLimit(response, maxBytes) {
  const length = Number(response.headers.get("content-length") || 0);
  if (length > maxBytes) throw new Error("Response too large");
  if (!response.body) return "";

  const reader = response.body.getReader();
  const chunks = [];
  let total = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new Error("Response too large");
    }
    chunks.push(Buffer.from(value));
  }

  return Buffer.concat(chunks, total).toString("utf8");
}

module.exports = { assertSafeExternalUrl, fetchSafeExternalUrl, readResponseWithLimit, readResponseBufferWithLimit };
