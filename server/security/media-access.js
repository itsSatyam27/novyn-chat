// Match the server-generated filename, never the bearer token in a copied URL.
function mediaNames(value) {
  const text = typeof value === 'string' ? value : JSON.stringify(value ?? '');
  return [...new Set(Array.from(text.matchAll(/\/uploads\/([a-zA-Z0-9._-]+)/g), (match) => match[1]))];
}

function canReadMedia({ filename, userKey, ownerKey, conversations, wallpapers, canReadConversation }) {
  if (!userKey) return false;
  if (ownerKey && ownerKey === userKey) return true;
  for (const [key, messages] of conversations) {
    if (!canReadConversation(key, userKey)) continue;
    if (messages.some((message) => !message.deletedAt &&
      mediaNames([message.text, message.attachment?.url]).includes(filename))) return true;
  }
  for (const [key, wallpaper] of wallpapers) {
    if (canReadConversation(key, userKey) && mediaNames(wallpaper).includes(filename)) return true;
  }
  return false;
}

module.exports = { mediaNames, canReadMedia };
