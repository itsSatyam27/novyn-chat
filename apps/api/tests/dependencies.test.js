const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

test('patched tar works with Capacitor template extraction', async () => {
  const { extractTemplate } = require('@capacitor/cli/dist/util/template');
  const root = path.dirname(require.resolve('@capacitor/cli/package.json'));
  const archive = path.join(root, 'assets', 'android-template.tar.gz');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'novyn-template-test-'));
  try {
    await extractTemplate(archive, directory);
    assert.ok((await fs.readdir(directory)).includes('app'));
  } finally {
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('novyn-template-test-'));
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test('password recovery uses the Resend HTTPS mailer without SMTP dependencies', async () => {
  const { createResendMailer } = require('../services/resend_mailer');
  let requestBody;
  const mailer = createResendMailer({
    apiKey: 're_test_key',
    from: 'Novyn <no-reply@example.test>',
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return { ok: true, status: 200, json: async () => ({ id: 'email_test_123' }) };
    },
  });
  const result = await mailer.send({
    to: 'user@example.test',
    subject: 'Reset code',
    text: 'Test code: 123456',
    idempotencyKey: 'password-reset/test-123',
  });
  assert.equal(result.provider, 'resend');
  assert.equal(requestBody.subject, 'Reset code');
  assert.deepEqual(requestBody.to, ['user@example.test']);
});

test('Google client UUID consumers retain their CommonJS v4 API', () => {
  const { createRequire } = require('node:module');
  for (const name of ['google-gax', 'teeny-request']) {
    const dependencyRequire = createRequire(require.resolve(name));
    assert.match(dependencyRequire('uuid').v4(), /^[0-9a-f-]{36}$/);
  }
});
