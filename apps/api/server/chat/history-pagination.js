'use strict';

function timestampValue(message) {
  const raw = message?.timestamp ?? message?.createdAt;
  const value = typeof raw === 'number' ? raw : Date.parse(String(raw ?? ''));
  return Number.isFinite(value) ? value : 0;
}

function messageCursorId(message) {
  return String(message?.id || message?.clientTempId || '');
}

function compareHistoryMessages(left, right) {
  const timeDifference = timestampValue(left) - timestampValue(right);
  if (timeDifference !== 0) return timeDifference;
  const leftId = messageCursorId(left);
  const rightId = messageCursorId(right);
  if (leftId < rightId) return -1;
  if (leftId > rightId) return 1;
  return 0;
}

/** Apply a stable chronological cursor to append-only conversation storage. */
function paginateHistoryMessages(source, { limit = 50, before = '' } = {}) {
  const boundedLimit = Number.isFinite(limit)
    ? Math.min(100, Math.max(1, Math.floor(limit)))
    : 50;
  const ordered = (Array.isArray(source) ? source : [])
    .slice()
    .sort(compareHistoryMessages);

  let endIndex = ordered.length;
  if (before) {
    const cursorIndex = ordered.findIndex(
      (message) =>
        String(message?.id || '') === before ||
        String(message?.clientTempId || '') === before
    );
    // An unknown/stale cursor is terminal: do not replay the latest page.
    endIndex = cursorIndex >= 0 ? cursorIndex : 0;
  }

  const startIndex = Math.max(0, endIndex - boundedLimit);
  const messages = ordered.slice(startIndex, endIndex);
  const hasMore = startIndex > 0;
  return {
    messages,
    hasMore,
    nextBefore: hasMore ? messageCursorId(messages[0]) || null : null,
  };
}

module.exports = { compareHistoryMessages, paginateHistoryMessages };
