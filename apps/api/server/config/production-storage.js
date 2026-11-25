"use strict";

const path = require("path");

function validateProductionStorageConfig(env = process.env) {
  if (String(env.NODE_ENV || "").trim().toLowerCase() !== "production") return [];

  const issues = [];
  const mongoUri = String(env.MONGODB_URI || "").trim();
  const dataDir = String(env.DATA_DIR || "").trim();
  const cloudinaryReady = Boolean(
    String(env.CLOUDINARY_CLOUD_NAME || "").trim() &&
    String(env.CLOUDINARY_API_KEY || "").trim() &&
    String(env.CLOUDINARY_API_SECRET || "").trim()
  );
  const uploadsDir = String(env.UPLOADS_DIR || "").trim();

  if (!mongoUri && (!dataDir || !path.isAbsolute(dataDir))) {
    issues.push("Set MONGODB_URI or an absolute DATA_DIR on persistent storage.");
  }
  if (!cloudinaryReady && (!uploadsDir || !path.isAbsolute(uploadsDir))) {
    issues.push("Configure Cloudinary or set an absolute UPLOADS_DIR on persistent storage.");
  }

  return issues;
}

module.exports = { validateProductionStorageConfig };
