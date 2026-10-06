const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('background push keeps messages visible while honoring Busy silent delivery', async () => {
  const handlers = new Map();
  const notifications = [];
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../../web/public/sw.js'), 'utf8'), {
    self: {
      addEventListener: (name, handler) => handlers.set(name, handler),
      registration: { showNotification: async (title, options) => notifications.push({ title, options }) },
    },
  });
  for (const silent of [true, false]) {
    let pending;
    handlers.get('push')({
      data: { json: () => ({ title: 'Friend', body: 'A new message', silent }) },
      waitUntil: promise => { pending = promise; },
    });
    await pending;
    const notification = notifications.at(-1);
    assert.equal(notification.title, 'Friend');
    assert.equal(notification.options.body, 'A new message');
    assert.equal(notification.options.silent, silent);
  }
});
