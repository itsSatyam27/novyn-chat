const test = require('node:test');
const assert = require('node:assert/strict');
const {
  compareHistoryMessages,
  paginateHistoryMessages,
} = require('../server/chat/history-pagination');

test('history pages are chronological when offline messages arrive late', () => {
  const rows = [
    { id: 'new', timestamp: '2026-11-15T12:00:00.000Z' },
    { id: 'old', timestamp: '2026-11-15T09:00:00.000Z' },
    { id: 'middle', timestamp: '2026-11-15T10:00:00.000Z' },
  ];
  const page = paginateHistoryMessages(rows, { limit: 2 });
  assert.deepEqual(page.messages.map((message) => message.id), ['middle', 'new']);
  assert.equal(page.hasMore, true);
  assert.equal(page.nextBefore, 'middle');
});

test('equal timestamps use message ID as a stable tiebreaker', () => {
  const rows = [
    { id: 'c', timestamp: '2026-11-15T10:00:00.000Z' },
    { id: 'a', timestamp: '2026-11-15T10:00:00.000Z' },
    { id: 'b', timestamp: '2026-11-15T10:00:00.000Z' },
  ];
  assert.deepEqual(rows.slice().sort(compareHistoryMessages).map((m) => m.id), ['a', 'b', 'c']);
  const page = paginateHistoryMessages(rows, { limit: 2 });
  assert.deepEqual(page.messages.map((m) => m.id), ['b', 'c']);
  assert.equal(page.nextBefore, 'b');
});

test('before cursor excludes the cursor but includes same-time earlier IDs', () => {
  const rows = [
    { id: 'c', timestamp: '2026-11-15T10:00:00.000Z' },
    { id: 'a', timestamp: '2026-11-15T10:00:00.000Z' },
    { id: 'd', timestamp: '2026-11-15T11:00:00.000Z' },
    { id: 'b', timestamp: '2026-11-15T10:00:00.000Z' },
    { id: 'older', timestamp: '2026-11-15T09:00:00.000Z' },
  ];
  const page = paginateHistoryMessages(rows, { limit: 10, before: 'c' });
  assert.deepEqual(page.messages.map((m) => m.id), ['older', 'a', 'b']);
  assert.equal(page.hasMore, false);
});

test('unknown cursors return an empty terminal page instead of replaying latest rows', () => {
  const page = paginateHistoryMessages([{ id: 'a', timestamp: '2026-11-15T10:00:00.000Z' }], { before: 'stale' });
  assert.deepEqual(page.messages, []);
  assert.equal(page.hasMore, false);
  assert.equal(page.nextBefore, null);
});

test('invalid timestamps sort deterministically and page limits stay bounded', () => {
  const rows = [
    { id: 'b', timestamp: 'not-a-date' },
    { id: 'a', timestamp: 'not-a-date' },
    { id: 'later', timestamp: '2026-11-15T10:00:00.000Z' },
  ];
  assert.deepEqual(paginateHistoryMessages(rows, { limit: 1000 }).messages.map((m) => m.id), ['a', 'b', 'later']);
});
