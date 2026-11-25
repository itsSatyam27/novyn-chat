"use strict";

const fs = require("node:fs");
const { TextDecoder } = require("node:util");

const ALLOWED_VOICE_MIME = new Set([
  "audio/webm",
  "audio/wav",
  "audio/mpeg",
  "audio/ogg",
  "audio/mp4",
  "audio/aac",
]);

const ALLOWED_FILE_MIME = new Set([
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "video/mp4",
  "video/webm",
  "video/quicktime",
  "image/bmp",
  "image/heic",
  "audio/webm",
  "audio/wav",
  "audio/mpeg",
  "audio/ogg",
  "audio/mp4",
  "audio/aac",
  "application/pdf",
  "text/plain",
  "text/csv",
  "application/zip",
  "application/x-zip-compressed",
  "application/x-rar-compressed",
  "application/x-7z-compressed",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);

const MULTIPART_LIMITS = Object.freeze({
  files: 1,
  fields: 10,
  fieldSize: 16 * 1024,
  parts: 12,
});

function createUploadFileFilter(allowedMimeTypes) {
  return (_req, file, callback) => {
    const mime = String(file?.mimetype || "").trim().toLowerCase();
    if (!allowedMimeTypes.has(mime)) {
      const error = new Error("Unsupported upload type.");
      error.code = "NOVYN_UNSUPPORTED_FILE_TYPE";
      callback(error);
      return;
    }
    callback(null, true);
  };
}

function mapMultipartError(error) {
  if (error?.code === "LIMIT_FILE_SIZE") {
    return { status: 413, message: "File is too large." };
  }
  if (error?.code === "NOVYN_UNSUPPORTED_FILE_TYPE") {
    return { status: 415, message: "Unsupported file type." };
  }
  if (["LIMIT_FILE_COUNT", "LIMIT_FIELD_COUNT", "LIMIT_FIELD_VALUE", "LIMIT_PART_COUNT"].includes(error?.code)) {
    return { status: 413, message: "Upload request contains too much form data." };
  }
  return { status: 400, message: "Invalid upload payload." };
}


async function uploadCloudMediaWithMetadata({ upload, saveMetadata, cleanup, onCleanupError } = {}) {
  if (typeof upload !== "function" || typeof saveMetadata !== "function") {
    throw new TypeError("Cloud media upload and metadata persistence callbacks are required.");
  }
  const result = await upload();
  try {
    await saveMetadata(result);
    return result;
  } catch (error) {
    if (typeof cleanup === "function") {
      try {
        await cleanup(result);
      } catch (cleanupError) {
        if (typeof onCleanupError === "function") {
          try { onCleanupError(cleanupError, result); } catch (_) {}
        }
      }
    }
    throw error;
  }
}


const ZIP_MIME_TYPES = new Set([
  "application/zip",
  "application/x-zip-compressed",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);
const OLE_MIME_TYPES = new Set([
  "application/msword",
  "application/vnd.ms-powerpoint",
  "application/vnd.ms-excel",
]);

function startsWithBytes(buffer, hex) {
  const signature = Buffer.from(hex, "hex");
  return buffer.length >= signature.length && buffer.subarray(0, signature.length).equals(signature);
}

function hasIsoBaseMediaHeader(buffer) {
  return buffer.length >= 12 && buffer.toString("ascii", 4, 8) === "ftyp";
}

function hasZipHeader(buffer) {
  return ["504b0304", "504b0506", "504b0708"].some((signature) => startsWithBytes(buffer, signature));
}

function matchesUploadSignature(buffer, mime) {
  switch (mime) {
    case "image/jpeg": return startsWithBytes(buffer, "ffd8ff");
    case "image/png": return startsWithBytes(buffer, "89504e470d0a1a0a");
    case "image/gif": return buffer.toString("ascii", 0, 6) === "GIF87a" || buffer.toString("ascii", 0, 6) === "GIF89a";
    case "image/webp": return buffer.length >= 12 && buffer.toString("ascii", 0, 4) === "RIFF" && buffer.toString("ascii", 8, 12) === "WEBP";
    case "image/bmp": return startsWithBytes(buffer, "424d");
    case "image/heic": {
      if (!hasIsoBaseMediaHeader(buffer)) return false;
      const brands = [buffer.toString("ascii", 8, 12), buffer.toString("ascii", 16, 20)];
      return brands.some((brand) => ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].includes(brand));
    }
    case "video/mp4": return hasIsoBaseMediaHeader(buffer) && buffer.toString("ascii", 8, 12) !== "qt  ";
    case "video/quicktime": return hasIsoBaseMediaHeader(buffer) && buffer.toString("ascii", 8, 12) === "qt  ";
    case "video/webm":
    case "audio/webm": return startsWithBytes(buffer, "1a45dfa3");
    case "audio/wav": return buffer.length >= 12 && buffer.toString("ascii", 0, 4) === "RIFF" && buffer.toString("ascii", 8, 12) === "WAVE";
    case "audio/mpeg":
    case "audio/aac": return startsWithBytes(buffer, "494433") || (buffer.length >= 2 && buffer[0] === 0xff && (buffer[1] & 0xe0) === 0xe0);
    case "audio/ogg": return startsWithBytes(buffer, "4f676753");
    case "audio/mp4": return hasIsoBaseMediaHeader(buffer);
    case "application/pdf": return buffer.toString("ascii", 0, 5) === "%PDF-";
    case "application/zip":
    case "application/x-zip-compressed":
    case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
    case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
    case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
      return hasZipHeader(buffer);
    case "application/x-rar-compressed": return startsWithBytes(buffer, "5261721a07");
    case "application/x-7z-compressed": return startsWithBytes(buffer, "377abcaf271c");
    case "application/msword":
    case "application/vnd.ms-powerpoint":
    case "application/vnd.ms-excel":
      return startsWithBytes(buffer, "d0cf11e0a1b11ae1");
    default: return false;
  }
}

async function isUtf8TextFile(filePath) {
  const decoder = new TextDecoder("utf-8", { fatal: true });
  const stream = fs.createReadStream(filePath, { highWaterMark: 64 * 1024 });
  try {
    for await (const chunk of stream) {
      if (chunk.includes(0)) return false;
      decoder.decode(chunk, { stream: true });
    }
    decoder.decode();
    return true;
  } catch (_) {
    stream.destroy();
    return false;
  }
}

// Multipart Content-Type is client-controlled. Confirm the staged bytes match
// the declared allowlisted type before storing anything in Cloudinary or disk.
async function validateUploadFileContent(filePath, rawMime) {
  const mime = String(rawMime || "").trim().toLowerCase();
  if (!ALLOWED_FILE_MIME.has(mime) && !ALLOWED_VOICE_MIME.has(mime)) return false;
  const stat = await fs.promises.stat(filePath);
  if (!stat.isFile() || stat.size <= 0 || stat.size > 15 * 1024 * 1024) return false;
  if (mime === "text/plain" || mime === "text/csv") return isUtf8TextFile(filePath);

  const handle = await fs.promises.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(64);
    const { bytesRead } = await handle.read(buffer, 0, buffer.length, 0);
    return matchesUploadSignature(buffer.subarray(0, bytesRead), mime);
  } finally {
    await handle.close();
  }
}

module.exports = {
  ALLOWED_VOICE_MIME,
  ALLOWED_FILE_MIME,
  MULTIPART_LIMITS,
  createUploadFileFilter,
  mapMultipartError,
  uploadCloudMediaWithMetadata,
  matchesUploadSignature,
  validateUploadFileContent,
};
