const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');

test('newly issued auth session survives an immediate backend process restart', { timeout: 45000 }, async (t) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'novyn-auth-restart-'));
  const dataDirectory = path.join(directory, 'data');
  await fs.mkdir(dataDirectory, { recursive: true });
  const envFile = path.join(directory, 'empty.env');
  await fs.writeFile(envFile, '');

  const probe = net.createServer();
  probe.listen(0, '127.0.0.1');
  await once(probe, 'listening');
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));

  const base = `http://127.0.0.1:${port}`;
  const env = {
    ...process.env,
    RENDER: '',
    NOVYN_ENV_FILE: envFile,
    NODE_ENV: 'development',
    PORT: String(port),
    DATA_DIR: dataDirectory,
    UPLOADS_DIR: path.join(directory, 'uploads'),
    MONGODB_URI: '',
    MONGO_URL: '',
    MONGO_URI: '',
    ALLOWED_ORIGIN: '',
    CLOUDINARY_CLOUD_NAME: '',
    CLOUDINARY_API_KEY: '',
    CLOUDINARY_API_SECRET: '',
    FIREBASE_SERVICE_ACCOUNT_FILE: path.join(directory, 'absent.json'),
    FIREBASE_SERVICE_ACCOUNT_JSON: '',
    FIREBASE_PROJECT_ID: '',
    FIREBASE_CLIENT_EMAIL: '',
    FIREBASE_PRIVATE_KEY: '',
    VAPID_PUBLIC_KEY: '',
    VAPID_PRIVATE_KEY: '',
    SMTP_HOST: '',
    SMTP_USER: '',
    SMTP_PASS: '',
    AUTH_SECRET: 'auth-restart-integration-secret',
    UPLOAD_TOKEN_SECRET: 'auth-restart-integration-upload-secret',
  };

  const startBackend = async () => {
    const child = spawn(process.execPath, ['server.js'], {
      cwd: path.resolve(__dirname, '..'),
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
    let logs = '';
    child.stdout.on('data', (chunk) => { logs += chunk; });
    child.stderr.on('data', (chunk) => { logs += chunk; });

    await new Promise((resolve, reject) => {
      const deadline = setTimeout(() => {
        clearInterval(poll);
        reject(new Error(`Server did not start: ${logs}`));
      }, 15000);
      const poll = setInterval(() => {
        if (logs.includes('Chat app running')) {
          clearInterval(poll);
          clearTimeout(deadline);
          resolve();
        } else if (child.exitCode !== null) {
          clearInterval(poll);
          clearTimeout(deadline);
          reject(new Error(`Server exited before startup: ${logs}`));
        }
      }, 50);
    });

    return child;
  };

  const stopBackend = async (child) => {
    if (!child || child.exitCode !== null) return;
    const exited = once(child, 'exit');
    child.kill('SIGTERM');
    await exited;
  };

  let backend = await startBackend();
  t.after(async () => {
    await stopBackend(backend);
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('novyn-auth-restart-'));
    await fs.rm(directory, { recursive: true, force: true });
  });

  const signup = await fetch(`${base}/api/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'restart-user',
      username: 'restart_user',
      email: 'restart_user@example.test',
      password: 'Persistent-session-test-123!',
    }),
  });
  assert.equal(signup.status, 200, await signup.clone().text());

  const cookie = signup.headers.getSetCookie()
    .map((item) => item.split(';')[0])
    .join('; ');
  const refreshToken = cookie.split(';').map((part) => part.trim())
    .find((part) => part.startsWith('novyn_rt='))?.slice('novyn_rt='.length);
  assert.ok(refreshToken, 'sign-up must return a refresh cookie');
  const refreshPayload = JSON.parse(
    Buffer.from(refreshToken.split('.')[1], 'base64url').toString('utf8'),
  );

  const accountState = JSON.parse(
    await fs.readFile(path.join(dataDirectory, 'chat-state.json'), 'utf8'),
  );
  assert.ok(
    accountState.users.some((entry) => entry.key === 'restart_user'),
    'new account must be persisted before sign-up returns',
  );
  const authState = JSON.parse(
    await fs.readFile(path.join(dataDirectory, 'auth-state.json'), 'utf8'),
  );
  assert.ok(
    authState.refreshSessions.some((entry) => entry.tokenId === refreshPayload.jti),
    'refresh allow-list entry must be persisted before its cookie is returned',
  );

  // Simulate Render/container restart after the client has received cookies.
  await stopBackend(backend);
  backend = await startBackend();

  const restored = await fetch(`${base}/api/auth/session`, {
    headers: { Cookie: cookie },
  });
  assert.equal(restored.status, 200, await restored.clone().text());
  const restoredBody = await restored.json();
  assert.equal(restoredBody.authenticated, true);
  assert.equal(restoredBody.username, 'restart_user');

  const persistedStatePath = path.join(dataDirectory, 'chat-state.json');
  const persistedState = JSON.parse(await fs.readFile(persistedStatePath, 'utf8'));
  const persistedUser = persistedState.users.find((entry) => entry.key === 'restart_user');
  assert.ok(persistedUser, 'registered user must be present in persisted state');
  persistedUser.isSuspended = true;
  await fs.writeFile(persistedStatePath, JSON.stringify(persistedState));

  await stopBackend(backend);
  backend = await startBackend();

  const suspendedSession = await fetch(`${base}/api/auth/session`, {
    headers: { Cookie: cookie },
  });
  assert.equal(suspendedSession.status, 401, await suspendedSession.clone().text());

  const suspendedSignin = await fetch(`${base}/api/auth/signin`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: 'restart_user',
      password: 'Persistent-session-test-123!',
    }),
  });
  assert.equal(suspendedSignin.status, 403, await suspendedSignin.clone().text());
});
