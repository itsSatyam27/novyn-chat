"use strict";

// The API is a single-process runtime today. Reserve identity fields before
// password hashing yields to the event loop so concurrent signups cannot
// register the same email or username twice in that process.
function createRegistrationReservations() {
  const pendingEmails = new Set();
  const pendingUsernames = new Set();

  function normalize(value) {
    return String(value || "").trim().toLowerCase();
  }

  function reserve(email, username) {
    const emailKey = normalize(email);
    const usernameKey = normalize(username);
    if (!emailKey || !usernameKey) return false;
    if (pendingEmails.has(emailKey) || pendingUsernames.has(usernameKey)) return false;
    pendingEmails.add(emailKey);
    pendingUsernames.add(usernameKey);
    return true;
  }

  function release(email, username) {
    const emailKey = normalize(email);
    const usernameKey = normalize(username);
    if (emailKey) pendingEmails.delete(emailKey);
    if (usernameKey) pendingUsernames.delete(usernameKey);
  }

  return { reserve, release };
}

module.exports = { createRegistrationReservations };
