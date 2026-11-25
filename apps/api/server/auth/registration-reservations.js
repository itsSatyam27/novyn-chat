"use strict";

// The API is a single-process runtime today. Reserve identity fields before
// password hashing yields to the event loop so concurrent signups cannot
// register the same email or username twice in that process.
function createRegistrationReservations() {
  const pendingEmails = new Set();
  const pendingUsernames = new Set();
  const pendingExternalIds = new Set();

  function normalize(value) {
    return String(value || "").trim().toLowerCase();
  }

  function reserve(email, username, externalId = "") {
    const emailKey = normalize(email);
    const usernameKey = normalize(username);
    const externalKey = String(externalId || "").trim();
    if (!emailKey || !usernameKey) return false;
    if (
      pendingEmails.has(emailKey) ||
      pendingUsernames.has(usernameKey) ||
      (externalKey && pendingExternalIds.has(externalKey))
    ) return false;
    pendingEmails.add(emailKey);
    pendingUsernames.add(usernameKey);
    if (externalKey) pendingExternalIds.add(externalKey);
    return true;
  }

  function release(email, username, externalId = "") {
    const emailKey = normalize(email);
    const usernameKey = normalize(username);
    const externalKey = normalize(externalId);
    if (emailKey) pendingEmails.delete(emailKey);
    if (usernameKey) pendingUsernames.delete(usernameKey);
    if (externalKey) pendingExternalIds.delete(externalKey);
  }

  return { reserve, release };
}

module.exports = { createRegistrationReservations };
