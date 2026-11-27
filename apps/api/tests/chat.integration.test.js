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
  const refreshTokenId = (cookie) => {
    const token = cookie.split(';').map((part) => part.trim())
      .find((part) => part.startsWith('novyn_rt='))?.slice('novyn_rt='.length);
    assert.ok(token, 'refresh cookie must be present');
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    assert.ok(payload.jti, 'refresh token must contain a session id');
    return payload.jti;
  };
  const assertRefreshSessionPersisted = async (cookie, username) => {
    const jti = refreshTokenId(cookie);
    const accountState = JSON.parse(await fs.readFile(path.join(directory, 'data', 'chat-state.json'), 'utf8'));
    assert.ok(
      accountState.users.some((entry) =>
        (entry.key || entry.username || '').toLowerCase() === username.toLowerCase()),
      'account data must be durably persisted before its cookie is returned',
    );
    const persisted = JSON.parse(await fs.readFile(path.join(directory, 'data', 'auth-state.json'), 'utf8'));
    assert.ok(
      persisted.refreshSessions.some((entry) => entry.tokenId === jti),
      'refresh session must be durably persisted before its cookie is returned',
    );
    return { jti, persisted };
  };
  const signup = async (username) => {
    const response = await fetch(`${base}/api/auth/signup`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: username, username, email: `${username}@example.test`, password: 'Test-only-password-123!' }),
    });
    assert.equal(response.status, 200, await response.clone().text());
    const cookie = response.headers.getSetCookie().map((item) => item.split(';')[0]).join('; ');
    await assertRefreshSessionPersisted(cookie, username);
    return { cookie, ...(await connect(cookie)) };
  };
  const alice = await signup('alice');
  const bob = await signup('bob');
  const eve = await signup('eve');

  // Account Info reset requests must be authenticated and tied to the
  // currently signed-in account, not an editable email supplied by the client.
  const aliceCsrfCookie = alice.cookie.split('; ').find((part) => part.startsWith('novyn_csrf='));
  assert.ok(aliceCsrfCookie, 'signup must issue the CSRF cookie');
  const aliceCsrf = decodeURIComponent(aliceCsrfCookie.slice('novyn_csrf='.length));
  const accountResetResponse = await fetch(`${base}/api/account/password-reset/request`, {
    method: 'POST',
    headers: {
      Cookie: alice.cookie,
      Origin: origin,
      'x-novyn-csrf': aliceCsrf,
    },
  });
  assert.equal(accountResetResponse.status, 200, await accountResetResponse.clone().text());
  const accountResetBody = await accountResetResponse.json();
  assert.equal(accountResetBody.ok, true);
  assert.ok(accountResetBody.message.includes('@example.test'));
  assert.ok(logs.includes('[Password reset code] a***e@example.test:'), 'development recovery logs must mask the recipient email');


  // A refresh response must not expose the rotated cookie until its new
  // allow-list entry is durably persisted and the old one is revoked.
  const oldRefreshJti = refreshTokenId(alice.cookie);
  const refreshResponse = await fetch(`${base}/api/auth/refresh`, {
    method: 'POST',
    headers: { Cookie: alice.cookie, Origin: origin },
  });
  assert.equal(refreshResponse.status, 200, await refreshResponse.clone().text());
  const rotatedCookie = refreshResponse.headers.getSetCookie()
    .map((item) => item.split(';')[0]).join('; ');
  const rotated = await assertRefreshSessionPersisted(rotatedCookie, 'alice');
  assert.notEqual(rotated.jti, oldRefreshJti);
  assert.ok(
    !rotated.persisted.refreshSessions.some((entry) => entry.tokenId === oldRefreshJti),
    'rotated refresh token must be removed from the persisted allow-list',
  );
  alice.cookie = rotatedCookie;
  // Refresh rotation revokes the previous session id. Reconnect the test
  // socket with the newly issued cookie before exercising authenticated events.
  alice.socket.disconnect();
  const rotatedAlice = await connect(alice.cookie);
  alice.socket = rotatedAlice.socket;
  const restoredSession = await fetch(`${base}/api/auth/session`, {
    headers: { Cookie: alice.cookie },
  });
  assert.equal(restoredSession.status, 200, await restoredSession.clone().text());
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
  // Deleted chats are an account-level preference, not only a device cache.
  const hiddenResult = await alice.socket.timeout(3000).emitWithAck(
    'set_chat_hidden', { username: 'bob', hidden: true },
  );
  assert.equal(hiddenResult.ok, true);
  assert.deepEqual(hiddenResult.hiddenChats, ['bob']);
  const persistedHiddenState = JSON.parse(
    await fs.readFile(path.join(directory, 'data', 'chat-state.json'), 'utf8'),
  );
  assert.deepEqual(
    persistedHiddenState.users.find((entry) => entry.key === 'alice').hiddenChats,
    ['bob'],
    'hidden chat preference must be persisted with its owning account',
  );

  alice.socket.disconnect();
  const restoredAliceHidden = await connect(alice.cookie, 'polling');
  alice.socket = restoredAliceHidden.socket;
  assert.deepEqual(
    restoredAliceHidden.state.hiddenChats,
    ['bob'],
    'hidden chat preference must be returned during authenticated session restore',
  );
  const unhiddenResult = await alice.socket.timeout(3000).emitWithAck(
    'set_chat_hidden', { username: 'bob', hidden: false },
  );
  assert.equal(unhiddenResult.ok, true);
  assert.deepEqual(unhiddenResult.hiddenChats, []);


  // The server stores only the client-encrypted identity envelope, scoped
  // to the authenticated account, and retains it across a socket reconnect.
  const recoveryWebCrypto = require('node:crypto').webcrypto;
  const aliceE2ee = await recoveryWebCrypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveKey']
  );
  const aliceE2eePublicKey = JSON.stringify(
    await recoveryWebCrypto.subtle.exportKey('jwk', aliceE2ee.publicKey)
  );
  assert.equal(
    (await alice.socket.timeout(3000).emitWithAck(
      'register_public_key', { publicKey: aliceE2eePublicKey },
    )).ok,
    true,
  );
  const identityRecoveryEnvelope = {
    format: 'novyn-e2ee-identity',
    version: 1,
    iterations: 210000,
    username: 'alice',
    publicKey: aliceE2eePublicKey,
    salt: Buffer.alloc(16, 1).toString('base64'),
    iv: Buffer.alloc(12, 2).toString('base64'),
    ciphertext: Buffer.alloc(48, 3).toString('base64'),
  };
  const savedIdentityBackup = await alice.socket.timeout(3000).emitWithAck(
    'save_e2ee_identity_backup',
    { publicKey: aliceE2eePublicKey, backup: identityRecoveryEnvelope },
  );
  assert.equal(savedIdentityBackup.ok, true);
  const ownIdentityBackup = await alice.socket.timeout(3000).emitWithAck(
    'get_e2ee_identity_backup', {},
  );
  assert.equal(ownIdentityBackup.ok, true);
  assert.deepEqual(ownIdentityBackup.backup, identityRecoveryEnvelope);
  assert.equal(ownIdentityBackup.publicKey, aliceE2eePublicKey);
  const bobIdentityBackup = await bob.socket.timeout(3000).emitWithAck(
    'get_e2ee_identity_backup', {},
  );
  assert.equal(bobIdentityBackup.ok, true);
  assert.equal(bobIdentityBackup.backup, null, 'a user cannot read another account?s recovery envelope');
  await new Promise((resolve) => setTimeout(resolve, 250));
  const persistedIdentityState = JSON.parse(
    await fs.readFile(path.join(directory, 'data', 'chat-state.json'), 'utf8'),
  );
  const alicePersistedIdentity = persistedIdentityState.users.find((entry) => entry.key === 'alice');
  assert.equal(alicePersistedIdentity.e2eeIdentityBackup, JSON.stringify(identityRecoveryEnvelope));
  assert.equal(alicePersistedIdentity.e2eeIdentityBackupPublicKey, aliceE2eePublicKey);
  alice.socket.disconnect();
  const restoredAliceIdentitySocket = await connect(alice.cookie);
  alice.socket = restoredAliceIdentitySocket.socket;
  const identityBackupAfterReconnect = await alice.socket.timeout(3000).emitWithAck(
    'get_e2ee_identity_backup', {},
  );
  assert.deepEqual(identityBackupAfterReconnect.backup, identityRecoveryEnvelope);

  // Profile photos are private media too: Everyone must be viewable by a
  // non-friend, while Friends must allow Bob but deny Eve.
  const avatarForm = new FormData();
  avatarForm.append('file', new Blob(['alice avatar bytes'], { type: 'image/png' }), 'avatar.png');
  const avatarUpload = await fetch(`${base}/upload-file`, {
    method: 'POST', headers: { Cookie: alice.cookie }, body: avatarForm,
  });
  assert.equal(avatarUpload.status, 200, await avatarUpload.clone().text());
  const avatarMedia = await avatarUpload.json();

  const bobAvatarUpdated = event(
    bob.socket,
    'user_profile_updated',
    (profile) => profile.username === 'alice' && profile.avatarId === avatarMedia.url,
  );
  const saveAvatar = await fetch(`${base}/api/profile/update`, {
    method: 'POST',
    headers: { Cookie: alice.cookie, 'Content-Type': 'application/json' },
    body: JSON.stringify({ displayName: 'alice', bio: '', avatarId: avatarMedia.url }),
  });
  assert.equal(saveAvatar.status, 200, await saveAvatar.clone().text());
  assert.equal((await bobAvatarUpdated).avatarId, avatarMedia.url);
  const bobAvatar = await fetch(base + avatarMedia.url, { headers: { Cookie: bob.cookie } });
  assert.equal(bobAvatar.status, 200, await bobAvatar.clone().text());
  assert.equal(await bobAvatar.text(), 'alice avatar bytes');

  const ownFriendsPrivacy = event(
    alice.socket,
    'profile_updated',
    (profile) => profile.profilePhotoPrivacy === 'friends',
  );
  const bobStillSeesAvatar = event(
    bob.socket,
    'user_profile_updated',
    (profile) => profile.username === 'alice' && profile.avatarId === avatarMedia.url,
  );
  const friendsPrivacy = await alice.socket.timeout(3000).emitWithAck(
    'update_profile',
    { profilePhotoPrivacy: 'friends' },
  );
  assert.equal(friendsPrivacy.ok, true);
  assert.equal((await ownFriendsPrivacy).profilePhotoPrivacy, 'friends');
  assert.equal((await bobStillSeesAvatar).avatarId, avatarMedia.url);
  assert.equal(
    (await fetch(base + avatarMedia.url, { headers: { Cookie: bob.cookie } })).status,
    200,
  );
  assert.equal(
    (await fetch(base + avatarMedia.url, { headers: { Cookie: eve.cookie } })).status,
    403,
    'a non-friend must not read a Friends-only profile photo',
  );

  const ownEveryonePrivacy = event(
    alice.socket,
    'profile_updated',
    (profile) => profile.profilePhotoPrivacy === 'everyone',
  );
  const everyonePrivacy = await alice.socket.timeout(3000).emitWithAck(
    'update_profile',
    { profilePhotoPrivacy: 'everyone' },
  );
  assert.equal(everyonePrivacy.ok, true);
  assert.equal((await ownEveryonePrivacy).profilePhotoPrivacy, 'everyone');
  assert.equal(
    (await fetch(base + avatarMedia.url, { headers: { Cookie: eve.cookie } })).status,
    200,
    'Everyone must allow a non-friend to read the profile photo',
  );

  // Visibility is independent of the connection used to receive messages.
  for (const mode of ['busy', 'invisible', 'away', 'online']) {
    const updated = event(bob.socket, 'profile_updated', value => value.presenceMode === mode);
    const statusChanged = event(alice.socket, 'user_status', value => value.username === 'bob' && value.presence === (mode === 'invisible' ? 'offline' : mode));
    const summary = event(alice.socket, 'friend_list_updated', value => value.friends.some(friend => friend.username === 'bob' && friend.presence === (mode === 'invisible' ? 'offline' : mode)));
    bob.socket.emit('update_profile', {
      presenceMode: mode,
      // Exercise the actual Smart Presence payload: Invisible defaults to
      // hidden typing, while the other modes keep typing enabled.
      typingIndicatorsEnabled: mode !== 'invisible',
    });
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

  const voiceStarted = event(
    alice.socket,
    'voice_activity',
    value => value.from === 'bob' && value.isSpeaking === true,
  );
  bob.socket.emit('voice_activity', {
    to: 'alice',
    toType: 'friend',
    isSpeaking: true,
  });
  assert.equal((await voiceStarted).toType, 'friend');
  const voiceStopped = event(
    alice.socket,
    'voice_activity',
    value => value.from === 'bob' && value.isSpeaking === false,
  );
  bob.socket.emit('voice_activity', {
    to: 'alice',
    toType: 'friend',
    isSpeaking: false,
  });
  await voiceStopped;

  const voiceStoppedOnDisconnect = event(
    alice.socket,
    'voice_activity',
    value => value.from === 'bob' && value.isSpeaking === false,
  );
  bob.socket.emit('voice_activity', {
    to: 'alice',
    toType: 'friend',
    isSpeaking: true,
  });
  await event(
    alice.socket,
    'voice_activity',
    value => value.from === 'bob' && value.isSpeaking === true,
  );
  bob.socket.disconnect();
  await voiceStoppedOnDisconnect;
  const voiceActivityReconnect = await connect(bob.cookie);
  bob.socket = voiceActivityReconnect.socket;

  // Both participants receive an encrypted preview envelope, including after a
  // reload. The relay keeps its legacy placeholder and never returns plaintext.
  const { webcrypto } = require('node:crypto');
  const previewKey = await webcrypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  const plaintext = 'This preview is decrypted only on the device';
  const ivBytes = webcrypto.getRandomValues(new Uint8Array(12));
  const ciphertext = Buffer.from(await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv: ivBytes }, previewKey, Buffer.from(plaintext))).toString('base64');
  const iv = Buffer.from(ivBytes).toString('base64');
  const senderIdentity = await webcrypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveKey']
  );
  const senderPublicKey = JSON.stringify(
    await webcrypto.subtle.exportKey('jwk', senderIdentity.publicKey)
  );
  const isEncryptedSummary = ({ friends }) => friends.some((friend) => friend.lastMessageData?.ciphertext === ciphertext);
  const senderSummary = event(alice.socket, 'friend_list_updated', isEncryptedSummary);
  const receiverSummary = event(bob.socket, 'friend_list_updated', isEncryptedSummary);
  const encryptedPayload = {
    to: 'bob', text: plaintext, isEncrypted: true, ciphertext, iv,
    senderPublicKey, clientTempId: 'retry-test-1'
  };
  const sentAck = await alice.socket.timeout(3000).emitWithAck('private_message', encryptedPayload);
  assert.equal(sentAck.ok, true, 'sender receives an explicit successful delivery acknowledgement');
  const retryAck = await alice.socket.timeout(3000).emitWithAck('private_message', encryptedPayload);
  assert.equal(retryAck.id, sentAck.id, 'retrying the same client ID does not create another message');
  const failureAck = await alice.socket.timeout(3000).emitWithAck('private_message', { to: 'bob', text: '', clientTempId: 'empty-test' });
  assert.equal(failureAck.ok, false, 'invalid sends receive an actionable failure');
  for (const summary of await Promise.all([senderSummary, receiverSummary])) {
    const friend = summary.friends.find((entry) => entry.lastMessageData?.ciphertext === ciphertext);
    assert.equal(friend.lastMessage, '\u{1F512} Encrypted message');
    assert.equal(friend.lastMessageData.isEncrypted, true);
    assert.ok(friend.lastMessageData.id);
    assert.equal(friend.lastMessageData.iv, iv);
    assert.equal(friend.lastMessageData.senderPublicKey, senderPublicKey);
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
  assert.equal(await (await fetch(base + media.url + '&inline=1', { headers: { Cookie: alice.cookie } })).text(), 'private text');
  const received = event(bob.socket, 'private_message');
  alice.socket.emit('private_message', { to: 'bob', text: 'file', attachment: { ...media, url: media.url, name: 'private.txt', mime: 'text/plain', size: 12, kind: 'file' } });
  await received;
  assert.equal((await fetch(base + media.url, { headers: { Cookie: bob.cookie } })).status, 200);

  // Voice notes uploaded through the shared file endpoint must accept supported audio MIME types.
  const audioForm = new FormData();
  audioForm.append('file', new Blob([Buffer.from([1, 2, 3, 4])], { type: 'audio/mp4' }), 'voice_note.m4a');
  const audioUpload = await fetch(`${base}/upload-file`, { method: 'POST', headers: { Cookie: alice.cookie }, body: audioForm });
  assert.equal(audioUpload.status, 200, await audioUpload.clone().text());
  const audioMedia = await audioUpload.json();
  assert.equal(audioMedia.kind, 'audio');
  assert.equal(audioMedia.mime, 'audio/mp4');

  // Direct-message media envelopes must retain only validated E2EE metadata.
  const encryptedForm = new FormData();
  encryptedForm.append('file', new Blob([Buffer.from([9, 8, 7, 6, 5])], { type: 'text/plain' }), 'cipher.bin');
  const encryptedUpload = await fetch(`${base}/upload-file`, { method: 'POST', headers: { Cookie: alice.cookie }, body: encryptedForm });
  assert.equal(encryptedUpload.status, 200, await encryptedUpload.clone().text());
  const encryptedMedia = await encryptedUpload.json();
  const alicePublicKey = JSON.stringify({ kty: 'EC', crv: 'P-256', x: 'A'.repeat(43), y: 'B'.repeat(43) });
  const bobPublicKey = JSON.stringify({ kty: 'EC', crv: 'P-256', x: 'C'.repeat(43), y: 'D'.repeat(43) });
  const encryptedReceived = event(bob.socket, 'private_message', (message) => message.attachment?.encrypted === true);
  alice.socket.emit('private_message', {
    to: 'bob', text: '🔒 Encrypted message', isEncrypted: true,
    ciphertext: Buffer.from('encrypted message').toString('base64'), iv: Buffer.alloc(12, 4).toString('base64'),
    senderPublicKey: alicePublicKey,
    attachment: {
      ...encryptedMedia, name: 'private.pdf', mime: 'application/pdf', size: 5, kind: 'file',
      encrypted: true, encryptionVersion: 1, iv: Buffer.alloc(12, 5).toString('base64'),
      senderPublicKey: alicePublicKey, peerPublicKey: bobPublicKey,
    },
  });
  const encryptedMessage = await encryptedReceived;
  assert.equal(encryptedMessage.attachment.encrypted, true);
  assert.equal(encryptedMessage.attachment.encryptionVersion, 1);
  assert.equal(encryptedMessage.attachment.name, 'private.pdf');
  assert.equal(encryptedMessage.attachment.senderPublicKey, alicePublicKey);
  assert.equal(encryptedMessage.attachment.peerPublicKey, bobPublicKey);

  const invalidEnvelope = event(alice.socket, 'error_message');
  alice.socket.emit('private_message', {
    to: 'bob', text: '🔒 Encrypted message', isEncrypted: true,
    ciphertext: Buffer.from('encrypted message').toString('base64'), iv: Buffer.alloc(12, 4).toString('base64'),
    senderPublicKey: alicePublicKey,
    attachment: { ...encryptedMedia, encrypted: true, encryptionVersion: 1, iv: Buffer.alloc(12, 5).toString('base64'), senderPublicKey: alicePublicKey },
  });
  assert.match((await invalidEnvelope).message, /encrypted attachment metadata/i);

  const rejected = event(eve.socket, 'error_message');
  eve.socket.emit('private_message', { to: 'eve', text: media.url });
  assert.match((await rejected).message, /access/);
  assert.equal((await fetch(`${base}/api/push/public-key`)).status, 503);
  assert.ok(!logs.includes('VAPID_PRIVATE_KEY='));

  // A stale refresh cookie may let the WebSocket transport connect, but the
  // socket must remain unauthenticated and reject message actions until the
  // client reconnects using the rotated cookie pair.
  const staleEveCookie = eve.cookie;
  const csrfCookie = staleEveCookie.split('; ')
    .find((part) => part.startsWith('novyn_csrf='))
    ?.slice('novyn_csrf='.length);
  assert.ok(csrfCookie, 'signup must issue the CSRF cookie');
  // Keep this response name distinct from the earlier Alice token-rotation check.
  const staleRefreshResponse = await fetch(`${base}/api/auth/refresh`, {
    method: 'POST',
    headers: {
      Cookie: staleEveCookie,
      'x-novyn-csrf': decodeURIComponent(csrfCookie),
    },
  });
  assert.equal(staleRefreshResponse.status, 200, await staleRefreshResponse.clone().text());
  const refreshedEveCookie = staleRefreshResponse.headers.getSetCookie()
    .map((item) => item.split(';')[0]).join('; ');
  assert.ok(refreshedEveCookie.includes('novyn_at='));
  assert.ok(refreshedEveCookie.includes('novyn_rt='));

  const staleSocket = io(base, {
    autoConnect: false,
    transports: ['websocket'],
    extraHeaders: { Cookie: staleEveCookie, Origin: origin },
    reconnection: false,
  });
  sockets.push(staleSocket);
  const staleConnected = event(staleSocket, 'connect');
  staleSocket.connect();
  await staleConnected;
  const staleAuthFailed = event(staleSocket, 'auth_failed');
  staleSocket.emit('resume_session');
  assert.match((await staleAuthFailed).message, /Session expired/);
  const rejectedStaleMessage = await staleSocket.timeout(3000).emitWithAck(
    'private_message',
    { to: 'eve', text: 'must not send from an unauthenticated socket' },
  );
  assert.equal(rejectedStaleMessage.ok, false);
  assert.match(rejectedStaleMessage.message, /sign in again/i);
  staleSocket.disconnect();

  const refreshedEve = await connect(refreshedEveCookie);
  eve.cookie = refreshedEveCookie;
  eve.socket = refreshedEve.socket;
  const settingsAfterRefresh = await eve.socket.timeout(3000).emitWithAck(
    'get_account_settings',
    {},
  );
  assert.equal(settingsAfterRefresh.ok, true);

  assert.equal((await fetch(`${base}/api/auth/logout`, { method: 'POST', headers: { Cookie: eve.cookie } })).status, 200);
  assert.equal((await fetch(`${base}/api/auth/session`, { headers: { Cookie: eve.cookie } })).status, 401);
  assert.equal((await fetch(`${base}/api/import-wallpaper-url`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ url: 'https://example.test/photo.png' }) })).status, 401);
  const resetSent = event(bob.socket, 'password_reset_sent');
  bob.socket.emit('request_password_reset', { identifier: 'legacy' });
  await resetSent;
  const code = logs.match(/\\[Password reset code\\] l\\*{4}y@example\\.test: (\\S+)/)?.[1];
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
