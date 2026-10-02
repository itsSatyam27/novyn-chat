const test = require('node:test');
const assert = require('node:assert/strict');
const { assertSafeExternalUrl, fetchSafeExternalUrl, readResponseWithLimit } = require('../server/security/ssrf');

test('external fetch rejects local destinations and unsafe schemes', async () => {
  for (const url of ['http://127.0.0.1', 'http://169.254.169.254', 'http://[::]', 'http://[::1]', 'http://[::ffff:127.0.0.1]', 'file:///etc/passwd', 'https://user:password@example.com']) {
    await assert.rejects(assertSafeExternalUrl(url));
  }
});

test('external fetch pins the checked IP while preserving the HTTPS hostname', async (t) => {
  const dns = require('node:dns').promises;
  const https = require('node:https');
  const { EventEmitter } = require('node:events');
  const { PassThrough } = require('node:stream');
  let lookups = 0;
  t.mock.method(dns, 'lookup', async () => {
    lookups++;
    return [{ address: '93.184.216.34', family: 4 }];
  });
  t.mock.method(https, 'get', (url, options) => {
    assert.equal(url.hostname, 'example.test');
    options.lookup(url.hostname, { all: true }, (error, addresses) => {
      assert.equal(error, null);
      assert.deepEqual(addresses, [{ address: '93.184.216.34', family: 4 }]);
    });
    const request = new EventEmitter();
    request.destroy = (error) => request.emit('error', error);
    process.nextTick(() => {
      const incoming = new PassThrough();
      incoming.statusCode = 200;
      incoming.headers = { 'content-type': 'text/html' };
      request.emit('response', incoming);
      incoming.end('<title>Example</title>');
    });
    return request;
  });
  const response = await fetchSafeExternalUrl('https://example.test');
  assert.equal(await readResponseWithLimit(response, 1024), '<title>Example</title>');
  assert.equal(lookups, 1);
});

test('oversized response bodies are rejected', async () => {
  await assert.rejects(readResponseWithLimit(new Response('oversized'), 3), /too large/);
});

test('external response timeout remains active while the body is streaming', async (t) => {
  const https = require('node:https');
  const { EventEmitter } = require('node:events');
  const { PassThrough } = require('node:stream');
  t.mock.method(https, 'get', () => {
    const request = new EventEmitter();
    const incoming = new PassThrough();
    request.destroy = (error) => { incoming.destroy(error); request.emit('error', error); };
    process.nextTick(() => {
      incoming.statusCode = 200;
      incoming.headers = {};
      request.emit('response', incoming);
      incoming.write('partial');
    });
    return request;
  });
  const response = await fetchSafeExternalUrl('https://93.184.216.34', { timeoutMs: 30 });
  await assert.rejects(readResponseWithLimit(response, 1024), /timed out/);
});
