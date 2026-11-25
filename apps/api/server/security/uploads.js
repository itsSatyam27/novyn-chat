"use strict";

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

module.exports = {
  ALLOWED_VOICE_MIME,
  ALLOWED_FILE_MIME,
  MULTIPART_LIMITS,
  createUploadFileFilter,
  mapMultipartError,
  uploadCloudMediaWithMetadata,
};
