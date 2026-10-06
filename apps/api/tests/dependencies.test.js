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

test('updated mailer builds password-recovery mail without a network connection', async () => {
  const mailer = require('nodemailer').createTransport({ jsonTransport: true, disableFileAccess: true, disableUrlAccess: true });
  const result = await mailer.sendMail({ from: 'test@example.test', to: 'user@example.test', subject: 'Reset code', text: 'Test code: 123456' });
  assert.equal(JSON.parse(result.message).subject, 'Reset code');
  mailer.close();
});

test('Google client UUID consumers retain their CommonJS v4 API', () => {
  const { createRequire } = require('node:module');
  for (const name of ['google-gax', 'teeny-request']) {
    const dependencyRequire = createRequire(require.resolve(name));
    assert.match(dependencyRequire('uuid').v4(), /^[0-9a-f-]{36}$/);
  }
});
