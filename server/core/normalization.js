function normalizeName(name) {
  return String(name || "").trim().toLowerCase();
}

function toDisplayName(name) {
  return String(name || "").trim();
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function isPlausibleEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
}

function parseEnvBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === "") return fallback;
  return ["1", "true", "yes", "on"].includes(String(value).trim().toLowerCase());
}

function normalizeHandleInput(handle) {
  return normalizeName(handle).replace(/^@+/, "");
}

function normalizeChatKind(value) {
  return String(value || "").trim().toLowerCase() === "group" ? "group" : "friend";
}

function normalizePresenceMode(value, fallback = "online") {
  const mode = String(value || "").trim().toLowerCase();
  return ["online", "away", "busy", "invisible"].includes(mode) ? mode : fallback;
}

function normalizeGroupId(value) {
  const raw = toDisplayName(value);
  return raw.startsWith("grp_") ? raw : "";
}

module.exports = {
  normalizeName,
  toDisplayName,
  normalizeEmail,
  isPlausibleEmail,
  parseEnvBoolean,
  normalizeHandleInput,
  normalizeChatKind,
  normalizePresenceMode,
  normalizeGroupId,
};
