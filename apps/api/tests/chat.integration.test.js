const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { io } = require('socket.io-client');

test('localhost discovery, requests, reconnect state, and private media', { timeout: 45000 }, async (t) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'novyn-test-'));
  const config = path.join(directory, 'empty.env');
  await fs.writeFile(config, '');
  await fs.mkdir(path.join(directory, 'data'));
  await fs.writeFile(path.join(directory, 'data', 'chat-state.json'), JSON.stringify({
    users: [{ key: 'legacy', username: 'legacy', email: 'legacy@example.test', isRegistered: true }],
  }));
  const probe = net.createServer();
  probe.listen(0, '127.0.0.1');
  await once(probe, 'listening');
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));
  const base = `http://127.0.0.1:${port}`;
  const origin = 'http://localhost:5173';
  const env = {
    ...process.env, NOVYN_ENV_FILE: config, NODE_ENV: 'development', PORT: String(port),
    DATA_DIR: path.join(directory, 'data'), UPLOADS_DIR: path.join(directory, 'uploads'),
    MONGODB_URI: '', MONGO_URL: '', MONGO_URI: '', ALLOWED_ORIGIN: '',
    CLOUDINARY_CLOUD_NAME: '', CLOUDINARY_API_KEY: '', CLOUDINARY_API_SECRET: '',
    FIREBASE_SERVICE_ACCOUNT_FILE: path.join(directory, 'absent.json'), FIREBASE_SERVICE_ACCOUNT_JSON: '',
    FIREBASE_PROJECT_ID: '', FIREBASE_CLIENT_EMAIL: '', FIREBASE_PRIVATE_KEY: '',
    VAPID_PUBLIC_KEY: '', VAPID_PRIVATE_KEY: '', SMTP_HOST: '', SMTP_USER: '', SMTP_PASS: '',
    AUTH_SECRET: 'integration-auth-only', UPLOAD_TOKEN_SECRET: 'integration-media-only',
  };
  const child = spawn(process.execPath, ['server.js'], { cwd: path.resolve(__dirname, '..'), env, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
  const sockets = [];
  let logs = '';
  child.stdout.on('data', (chunk) => { logs += chunk; });
  child.stderr.on('data', (chunk) => { logs += chunk; });
  t.after(async () => {
    for (const socket of sockets) socket.disconnect();
    if (child.exitCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      await exited;
    }
    // Only the unique directory created by this test is removed.
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('novyn-test-'));
    await fs.rm(directory, { recursive: true, force: true });
  });
  await new Promise((resolve, reject) => {
    const deadline = setTimeout(() => { clearInterval(poll); reject(new Error(`Server did not start: ${logs}`)); }, 15000);
    const poll = setInterval(() => {
      if (logs.includes('Chat app running')) { clearInterval(poll); clearTimeout(deadline); resolve(); }
      else if (child.exitCode !== null) { clearInterval(poll); clearTimeout(deadline); reject(new Error(logs)); }
    }, 50);
  });
  const event = (socket, name, matches = () => true) => new Promise((resolve, reject) => {
    const handler = (value) => {
      if (!matches(value)) return;
      clearTimeout(timer);
      socket.off(name, handler);
      resolve(value);
    };
    const timer = setTimeout(() => { socket.off(name, handler); reject(new Error(`Timed out: ${name}`)); }, 5000);
    socket.on(name, handler);
  });
  const connect = async (cookie, transport = 'websocket') => {
    const socket = io(base, { autoConnect: false, transports: [transport], extraHeaders: { Cookie: cookie, Origin: origin }, reconnection: false });
    sockets.push(socket);
    const ready = event(socket, 'register_success');
    socket.connect();
    const state = await ready;
    return { socket, state };
  };
  const signup = async (username) => {
    const response = await fetch(`${base}/api/auth/signup`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: username, username, email: `${username}@example.test`, password: 'Test-only-password-123!' }),
    });
    assert.equal(response.status, 200, await response.clone().text());
    const cookie = response.headers.getSetCookie().map((item) => item.split(';')[0]).join('; ');
    return { cookie, ...(await connect(cookie)) };
  };
  const alice = await signup('alice');
  const bob = await signup('bob');
  const eve = await signup('eve');
  const legacyLogin = await fetch(`${base}/api/auth/signin`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: 'legacy', password: 'arbitrary-password' }),
  });
  assert.equal(legacyLogin.status, 401, 'missing password hashes must never permit login');
  for (const identifier of ['alice', 'alice@example.test']) {
    for (const password of ['Test-only-password-123!', 'incorrect']) {
      const response = await fetch(`${base}/api/auth/signin`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, password }),
      });
      assert.equal(response.status, password === 'incorrect' ? 401 : 200);
    }
  }
  const discovered = event(alice.socket, 'discover_online');
  alice.socket.emit('discover_online');
  assert.ok((await discovered).users.some((user) => user.username === 'bob'));
  const request = (socket, target) => socket.timeout(3000).emitWithAck('add_friend', target);
  assert.equal((await request(alice.socket, 'missing')).ok, false);
  assert.equal((await request(alice.socket, 'alice')).ok, false);
  const incoming = event(bob.socket, 'friend_request_received');
  assert.equal((await request(alice.socket, '@bob')).ok, true);
  assert.equal((await incoming).from, 'alice');
  assert.equal((await request(alice.socket, 'bob')).ok, true);
  alice.socket.disconnect();
  const restored = await connect(alice.cookie, 'polling');
  alice.socket = restored.socket;
  assert.deepEqual(restored.state.sentRequests, ['bob']);
  assert.equal((await alice.socket.timeout(3000).emitWithAck('cancel_friend_request', 'bob')).ok, true);
  assert.equal((await alice.socket.timeout(3000).emitWithAck('cancel_friend_request', 'bob')).ok, false);
  assert.equal((await request(alice.socket, 'bob')).ok, true);
  const accepted = event(alice.socket, 'friend_request_accepted');
  bob.socket.emit('accept_friend', 'alice');
  assert.equal((await accepted).by, 'bob');

  // Visibility is independent of the connection used to receive messages.
  for (const mode of ['busy', 'invisible', 'away', 'online']) {
    const updated = event(bob.socket, 'profile_updated', value => value.presenceMode === mode);
    const statusChanged = event(alice.socket, 'user_status', value => value.username === 'bob' && value.presence === (mode === 'invisible' ? 'offline' : mode));
    const summary = event(alice.socket, 'friend_list_updated', value => value.friends.some(friend => friend.username === 'bob' && friend.presence === (mode === 'invisible' ? 'offline' : mode)));
    bob.socket.emit('update_profile', { presenceMode: mode });
    assert.equal((await updated).presenceMode, mode);
    const status = await statusChanged;
    assert.equal(status.online, mode !== 'invisible');
    const friend = (await summary).friends.find(friend => friend.username === 'bob');
    assert.equal(friend.online, mode !== 'invisible');
    assert.equal(friend.onlineCount, mode === 'invisible' ? 0 : 1);
    if (mode === 'invisible') {
      assert.equal(friend.lastSeenAt, '');
      const discovery = event(alice.socket, 'discover_online');
      alice.socket.emit('discover_online');
      assert.ok(!(await discovery).users.some(item => item.username === 'bob'));
      const received = event(bob.socket, 'private_message', message => message.text === 'Invisible delivery check');
      assert.equal((await alice.socket.timeout(3000).emitWithAck('private_message', { to: 'bob', text: 'Invisible delivery check' })).ok, true);
      assert.equal((await received).text, 'Invisible delivery check');
      const noTyping = event(alice.socket, 'typing', value => value.from === 'bob');
      bob.socket.emit('typing', { to: 'alice', isTyping: true });
      assert.equal((await noTyping).isTyping, false);
      bob.socket.disconnect();
      const invisibleReconnect = await connect(bob.cookie);
      bob.socket = invisibleReconnect.socket;
      assert.equal(invisibleReconnect.state.presenceMode, 'invisible');
      const session = await fetch(`${base}/api/auth/session`, { headers: { Cookie: bob.cookie } });
      assert.equal((await session.json()).presenceMode, 'invisible');
    }
  }

  // Both participants receive an encrypted preview envelope, including after a
  // reload. The relay keeps its legacy placeholder and never returns plaintext.
  const { webcrypto } = require('node:crypto');
  const previewKey = await webcrypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  const plaintext = 'This preview is decrypted only on the device';
  const ivBytes = webcrypto.getRandomValues(new Uint8Array(12));
  const ciphertext = Buffer.from(await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv: ivBytes }, previewKey, Buffer.from(plaintext))).toString('base64');
  const iv = Buffer.from(ivBytes).toString('base64');
  const isEncryptedSummary = ({ friends }) => friends.some((friend) => friend.lastMessageData?.ciphertext === ciphertext);
  const senderSummary = event(alice.socket, 'friend_list_updated', isEncryptedSummary);
  const receiverSummary = event(bob.socket, 'friend_list_updated', isEncryptedSummary);
  const encryptedPayload = { to: 'bob', text: plaintext, isEncrypted: true, ciphertext, iv, clientTempId: 'retry-test-1' };
  const sentAck = await alice.socket.timeout(3000).emitWithAck('private_message', encryptedPayload);
  assert.equal(sentAck.ok, true, 'sender receives an explicit successful delivery acknowledgement');
  const retryAck = await alice.socket.timeout(3000).emitWithAck('private_message', encryptedPayload);
  assert.equal(retryAck.id, sentAck.id, 'retrying the same client ID does not create another message');
  const failureAck = await alice.socket.timeout(3000).emitWithAck('private_message', { to: 'bob', text: '', clientTempId: 'empty-test' });
  assert.equal(failureAck.ok, false, 'invalid sends receive an actionable failure');
  for (const summary of await Promise.all([senderSummary, receiverSummary])) {
    const friend = summary.friends.find((entry) => entry.lastMessageData?.ciphertext === ciphertext);
    assert.equal(friend.lastMessage, '🔒 Encrypted message');
    assert.equal(friend.lastMessageData.isEncrypted, true);
    assert.ok(friend.lastMessageData.id);
    assert.equal(friend.lastMessageData.iv, iv);
    assert.ok(!JSON.stringify(friend).includes(plaintext));
    const decoded = await webcrypto.subtle.decrypt({ name: 'AES-GCM', iv: Buffer.from(friend.lastMessageData.iv, 'base64') }, previewKey, Buffer.from(friend.lastMessageData.ciphertext, 'base64'));
    assert.equal(Buffer.from(decoded).toString(), plaintext);
  }
  bob.socket.disconnect();
  const reconnectedBob = await connect(bob.cookie);
  bob.socket = reconnectedBob.socket;
  const restoredPreview = reconnectedBob.state.friends.find((friend) => friend.username === 'alice').lastMessageData;
  assert.equal(restoredPreview.ciphertext, ciphertext);
  assert.equal(restoredPreview.iv, iv);
  const deletedPreview = event(bob.socket, 'friend_list_updated', ({ friends }) => friends.some((friend) => friend.lastMessageData?.id === restoredPreview.id && !friend.lastMessageData.isEncrypted));
  alice.socket.emit('delete_message', { to: 'bob', messageId: restoredPreview.id });
  const deletedSummary = (await deletedPreview).friends.find((friend) => friend.username === 'alice').lastMessageData;
  assert.equal(deletedSummary.ciphertext, undefined, 'deleted previews cannot be decrypted again');
  assert.equal(deletedSummary.iv, undefined);

  const form = new FormData();
  form.append('file', new Blob(['private text'], { type: 'text/plain' }), 'private.txt');
  const upload = await fetch(`${base}/upload-file`, { method: 'POST', headers: { Cookie: alice.cookie }, body: form });
  assert.equal(upload.status, 200, await upload.clone().text());
  const media = await upload.json();
  assert.equal((await fetch(base + media.url)).status, 401);
  assert.equal((await fetch(base + media.url, { headers: { Cookie: eve.cookie } })).status, 403);
  assert.equal(await (await fetch(base + media.url, { headers: { Cookie: alice.cookie } })).text(), 'private text');
  const received = event(bob.socket, 'private_message');
  alice.socket.emit('private_message', { to: 'bob', text: 'file', attachment: { ...media, url: media.url, name: 'private.txt', mime: 'text/plain', size: 12, kind: 'file' } });
  await received;
  assert.equal((await fetch(base + media.url, { headers: { Cookie: bob.cookie } })).status, 200);
  const rejected = event(eve.socket, 'error_message');
  eve.socket.emit('private_message', { to: 'eve', text: media.url });
  assert.match((await rejected).message, /access/);
  assert.equal((await fetch(`${base}/api/push/public-key`)).status, 503);
  assert.ok(!logs.includes('VAPID_PRIVATE_KEY='));
  assert.equal((await fetch(`${base}/api/auth/logout`, { method: 'POST', headers: { Cookie: eve.cookie } })).status, 200);
  assert.equal((await fetch(`${base}/api/auth/session`, { headers: { Cookie: eve.cookie } })).status, 401);
  assert.equal((await fetch(`${base}/api/import-wallpaper-url`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ url: 'https://example.test/photo.png' }) })).status, 401);
  const resetSent = event(bob.socket, 'password_reset_sent');
  bob.socket.emit('request_password_reset', { identifier: 'legacy' });
  await resetSent;
  const code = logs.match(/\[Password reset code\] legacy@example\.test: (\S+)/)?.[1];
  assert.ok(code, 'test-only reset code should be logged in development');
  const resetDone = event(bob.socket, 'password_reset_success');
  bob.socket.emit('reset_password', { identifier: 'legacy', token: code, newPassword: 'Recovered-password-123!' });
  await resetDone;
  const recoveredLogin = await fetch(`${base}/api/auth/signin`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: 'legacy@example.test', password: 'Recovered-password-123!' }),
  });
  assert.equal(recoveredLogin.status, 200);
});
