const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');
const exported = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(require('node:path').join(__dirname, '../src/services/messageGrouping.ts'), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, { exports: exported });
const { groupsWithPrevious } = exported;
const first = { sender: 'Alice', timestamp: '2026-10-01T12:00:00' };
test('messages group only for the same sender within five minutes', () => {
  assert.equal(groupsWithPrevious(first, { sender: 'alice', timestamp: '2026-10-01T12:04:59' }), true);
  assert.equal(groupsWithPrevious(first, { sender: 'bob', timestamp: first.timestamp }), false);
  assert.equal(groupsWithPrevious(first, { sender: 'alice', timestamp: '2026-10-01T12:05:00' }), false);
  assert.equal(groupsWithPrevious(undefined, first), false);
});
test('grouping respects day boundaries, replies, games, polls and invalid timestamps', () => {
  assert.equal(groupsWithPrevious({ sender: 'alice', timestamp: '2026-10-01T23:59:00' }, { sender: 'alice', timestamp: '2026-10-02T00:00:00' }), false);
  for (const extra of [{ replyTo: {} }, { game: {} }, { poll: {} }, { timestamp: 'bad date' }]) assert.equal(groupsWithPrevious(first, { ...first, ...extra }), false);
});
