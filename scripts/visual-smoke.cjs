// Run after `npm run build`, with a disposable headless Chrome instance exposing
// CDP on port 9225. Uses isolated local data; never signs into a real account.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const { io } = require('socket.io-client');

(async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'novyn-visual-'));
  console.log('Visual artifacts:', directory);
  const envFile = path.join(directory, 'empty.env');
  await fs.writeFile(envFile, '');
  const probe = net.createServer().listen(0, '127.0.0.1');
  await once(probe, 'listening');
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));
  const base = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, ['apps/api/server.js'], {
    cwd: path.resolve(__dirname, '..'), windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...process.env, NOVYN_ENV_FILE: envFile, NODE_ENV: 'development', PORT: String(port),
      DATA_DIR: path.join(directory, 'data'), UPLOADS_DIR: path.join(directory, 'uploads'),
      MONGODB_URI: '', MONGO_URL: '', MONGO_URI: '', ALLOWED_ORIGIN: '',
      CLOUDINARY_CLOUD_NAME: '', CLOUDINARY_API_KEY: '', CLOUDINARY_API_SECRET: '',
      FIREBASE_SERVICE_ACCOUNT_FILE: path.join(directory, 'absent.json'), FIREBASE_SERVICE_ACCOUNT_JSON: '',
      FIREBASE_PROJECT_ID: '', FIREBASE_CLIENT_EMAIL: '', FIREBASE_PRIVATE_KEY: '',
      VAPID_PUBLIC_KEY: '', VAPID_PRIVATE_KEY: '', SMTP_HOST: '', SMTP_USER: '', SMTP_PASS: '',
      AUTH_SECRET: 'visual-test-only', UPLOAD_TOKEN_SECRET: 'visual-test-only',
    },
  });
  const sockets = [];
  let browser;
  try {
    let logs = '';
    child.stdout.on('data', (chunk) => { logs += chunk; });
    child.stderr.on('data', (chunk) => { logs += chunk; });
    const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    for (let i = 0; i < 100 && !logs.includes('Chat app running'); i++) await wait(100);
    assert.ok(logs.includes('Chat app running'), 'isolated backend started');
    const socketEvent = (socket, name) => new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Missing socket event ${name}`)), 8000);
      socket.once(name, (data) => { clearTimeout(timer); resolve(data); });
    });
    async function signup(username) {
      const response = await fetch(`${base}/api/auth/signup`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: username === 'alice' ? 'Alice' : 'Hii', username, email: `${username}@example.test`, password: 'Visual-test-password-123!' }) });
      assert.equal(response.status, 200);
      const cookies = response.headers.getSetCookie().map((value) => value.split(';')[0]);
      const socket = io(base, { autoConnect: false, transports: ['websocket'], extraHeaders: { Cookie: cookies.join('; '), Origin: base } });
      sockets.push(socket);
      const ready = socketEvent(socket, 'register_success');
      socket.connect();
      await ready;
      return { socket, cookies };
    }
    const alice = await signup('alice');
    const bob = await signup('hii');
    const { webcrypto } = require('node:crypto');
    const bobIdentity = await webcrypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveKey']);
    const bobPublicKey = JSON.stringify(await webcrypto.subtle.exportKey('jwk', bobIdentity.publicKey));
    await bob.socket.timeout(5000).emitWithAck('register_public_key', { publicKey: bobPublicKey });
    assert.equal((await alice.socket.timeout(5000).emitWithAck('add_friend', 'hii')).ok, true);
    const accepted = socketEvent(alice.socket, 'friend_request_accepted');
    bob.socket.emit('accept_friend', 'alice');
    await accepted;
    const received = socketEvent(alice.socket, 'private_message');
    bob.socket.emit('private_message', { to: 'alice', text: 'Hey! Ready for a quick game?' });
    await received;
    alice.socket.disconnect();
    const alicePublicKeyReady = socketEvent(bob.socket, 'peer_public_key_updated');

    const targets = await (await fetch('http://127.0.0.1:9225/json')).json();
    browser = new WebSocket(targets.find((target) => target.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve) => browser.addEventListener('open', resolve, { once: true }));
    let id = 0;
    const pending = new Map();
    const errors = [];
    browser.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data);
      if (message.id) {
        const item = pending.get(message.id);
        pending.delete(message.id);
        message.error ? item.reject(message.error) : item.resolve(message.result);
      }
      if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails);
    });
    const call = (method, params = {}) => new Promise((resolve, reject) => {
      const key = ++id; pending.set(key, { resolve, reject }); browser.send(JSON.stringify({ id: key, method, params }));
    });
    const evaluate = async (expression) => {
      const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
      return result.result.value;
    };
    const waitFor = async (expression) => {
      for (let i = 0; i < 80; i++) { if (await evaluate(expression)) return; await wait(100); }
      console.error('Browser exceptions:', JSON.stringify(errors));
      console.error('Page:', await evaluate('document.body.innerText.slice(0,1000)'));
      throw new Error(`UI did not become ready: ${expression}`);
    };
    const click = (selector) => evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`);
    const clickText = (text) => evaluate(`Array.from(document.querySelectorAll('button')).find(button => button.getClientRects().length && button.textContent.includes(${JSON.stringify(text)})).click()`);
    const screenshot = async (name) => {
      await wait(350);
      const { data } = await call('Page.captureScreenshot', { format: 'png' });
      await fs.writeFile(path.join(directory, `${name}.png`), Buffer.from(data, 'base64'));
      const overflow = await evaluate('document.documentElement.scrollWidth > innerWidth');
      assert.equal(overflow, false, `${name}: no page overflow`);
      console.log('Captured', name);
    };
    const checkDockAnimation = async (selector) => {
      await click(`${selector} .dock-reveal`);
      await click(`${selector} [aria-label="Chats"]`);
      await wait(550);
      const result = await evaluate(`(async () => {
        const dock = document.querySelector(${JSON.stringify(selector)});
        const pill = dock.querySelector('.dock-active-pill');
        const sample = () => ({ x: pill.getBoundingClientRect().x, width: dock.getBoundingClientRect().width });
        const start = sample();
        dock.querySelector('[aria-label="Settings"]').click();
        await new Promise(resolve => setTimeout(resolve, 90));
        const middle = sample();
        await new Promise(resolve => setTimeout(resolve, 500));
        const end = sample();
        const active = dock.querySelector('[aria-current="page"]').getBoundingClientRect();
        const target = pill.getBoundingClientRect();
        return { start, middle, end, error: Math.abs(target.x - active.x) + Math.abs(target.width - active.width) };
      })()`);
      assert.ok(result.middle.x > result.start.x && result.middle.x < result.end.x, `${selector}: pill slides through intermediate positions ${JSON.stringify(result)}`);
      assert.ok(Math.abs(result.middle.width - result.start.width) < 1, `${selector}: dock stays the same width`);
      assert.ok(result.error < 1, `${selector}: pill aligns with selected item`);
      for (const tab of ['Calls', 'Contacts', 'Discover', 'Chats']) {
        await click(`${selector} [aria-label="${tab}"]`);
        await wait(45);
      }
      await wait(550);
      assert.equal(await evaluate(`document.querySelector(${JSON.stringify(selector)}).querySelector('[aria-current="page"]').getAttribute('aria-label')`), 'Chats', 'rapid switches end on the last selection');
      await call('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
      const duration = await evaluate(`parseFloat(getComputedStyle(document.querySelector(${JSON.stringify(selector)}).querySelector('.dock-active-pill')).transitionDuration)`);
      assert.ok(duration < 0.001, 'reduced-motion preference disables sliding');
      await call('Emulation.setEmulatedMedia', { features: [] });
      console.log('Dock animation checks passed:', selector);
    };
    const checkFocusDock = async (selector, mobile = false) => {
      const phase = () => evaluate(`document.querySelector(${JSON.stringify(selector)}).dataset.phase`);
      await click(`${selector} .dock-reveal`);
      await wait(2650);
      assert.equal(await phase(), 'compact', 'idle dock folds to the selected tab');
      await screenshot(mobile ? 'mobile-dock-compact' : 'desktop-dock-compact');
      await wait(650);
      assert.equal(await phase(), 'tucked', 'idle dock tucks away');
      assert.equal(await evaluate(`Array.from(document.querySelectorAll(${JSON.stringify(`${selector} .dock-item`)})).every(item => item.tabIndex === -1)`), true, 'hidden tabs are not keyboard stops');
      await screenshot(mobile ? 'mobile-dock-tucked' : 'desktop-dock-tucked');
      const handle = await evaluate(`(() => { const r = document.querySelector(${JSON.stringify(`${selector} .dock-reveal`)}).getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
      if (mobile) {
        await call('Emulation.setTouchEmulationEnabled', { enabled: true });
        await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [handle] });
        await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await wait(100);
        assert.equal(await phase(), 'expanded', 'touch reveals navigation without selecting a tab');
        await wait(3450);
        assert.equal(await phase(), 'tucked', 'touch focus does not prevent auto-hide');
        await call('Emulation.setTouchEmulationEnabled', { enabled: false });
      } else {
        await call('Input.dispatchMouseEvent', { type: 'mouseMoved', ...handle });
        await wait(100);
        assert.equal(await phase(), 'expanded', 'hover reveals navigation');
        // Move into the expanded surface and keep it open beyond the idle timeout.
        await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: handle.x, y: handle.y - 20 });
        await wait(3450);
        assert.equal(await phase(), 'expanded', 'hover keeps the dock open');
        await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 0, y: 0 });
        await wait(3450);
        assert.equal(await phase(), 'tucked', 'leaving restarts the idle timer');
      }
      await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
      await call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
      await evaluate(`document.querySelector(${JSON.stringify(`${selector} .dock-reveal`)}).focus()`);
      await wait(3450);
      assert.equal(await phase(), 'expanded', 'keyboard focus reveals the dock and holds it open');
      await evaluate('document.activeElement.blur()');
      await evaluate("localStorage.setItem('novyn_dock_always_visible', 'true'); window.dispatchEvent(new Event('novyn:dock-preference'))");
      await wait(3450);
      assert.equal(await phase(), 'expanded', 'always-show preference keeps navigation visible');
      await evaluate("localStorage.removeItem('novyn_dock_always_visible'); window.dispatchEvent(new Event('novyn:dock-preference'))");
      console.log('Focus dock checks passed:', selector);
    };
    await call('Runtime.enable');
    await call('Network.enable');
    await call('Network.clearBrowserCookies');
    for (const cookie of alice.cookies) {
      const split = cookie.indexOf('=');
      await call('Network.setCookie', { name: cookie.slice(0, split), value: cookie.slice(split + 1), url: base });
    }
    await call('Emulation.setDeviceMetricsOverride', { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });
    await call('Page.navigate', { url: base });
    await waitFor("!!document.querySelector('.chat-list-item')");
    const { publicKey } = await alicePublicKeyReady;
    const alicePublicKey = await webcrypto.subtle.importKey('jwk', JSON.parse(publicKey), { name: 'ECDH', namedCurve: 'P-256' }, false, []);
    const sharedKey = await webcrypto.subtle.deriveKey({ name: 'ECDH', public: alicePublicKey }, bobIdentity.privateKey, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
    const iv = webcrypto.getRandomValues(new Uint8Array(12));
    const cipher = await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv }, sharedKey, Buffer.from('Encrypted previews work here'));
    bob.socket.emit('private_message', { to: 'alice', text: '🔒 Encrypted message', isEncrypted: true, ciphertext: Buffer.from(cipher).toString('base64'), iv: Buffer.from(iv).toString('base64') });
    await waitFor("document.querySelector('.chat-item-preview')?.textContent.includes('Encrypted previews work here')");
    console.log('Received message preview decrypted without opening the chat.');
    await evaluate('document.fonts.ready');
    await checkDockAnimation('.desktop-sidebar');
    await checkFocusDock('.desktop-sidebar');
    await screenshot('desktop-chats');
    for (const tab of ['Calls', 'Discover', 'Contacts', 'Settings']) {
      await click(`.desktop-sidebar [aria-label="${tab}"]`);
      await wait(400);
      await screenshot(`desktop-${tab.toLowerCase()}`);
    }
    for (const category of ['Profile & Account', 'Notifications', 'Appearance', 'Storage & Data', 'Feedback']) {
      await clickText(category);
      await screenshot(`desktop-settings-${category.split(' ')[0].toLowerCase()}`);
    }
    await click('.desktop-sidebar [aria-label="Contacts"]');
    await evaluate("Array.from(document.querySelectorAll('.contact-card')).find(card => card.textContent.includes('Hii')).querySelector(':scope > div').click()");
    await waitFor("!!document.querySelector('.message-textarea')");
    await waitFor("Array.from(document.querySelectorAll('.bubble')).some(bubble => bubble.textContent.includes('Encrypted previews work here'))");
    await evaluate("(() => {const input = document.querySelector('.message-textarea'); Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(input, 'My encrypted reply'); input.dispatchEvent(new Event('input', {bubbles:true}));})()");
    await waitFor("!!document.querySelector('.send-btn')");
    const sentEncrypted = socketEvent(bob.socket, 'private_message');
    await click('.send-btn');
    const outgoing = await sentEncrypted;
    assert.equal(outgoing.isEncrypted, true);
    assert.equal(outgoing.text, '🔒 Encrypted message');
    const decoded = await webcrypto.subtle.decrypt({ name: 'AES-GCM', iv: Buffer.from(outgoing.iv, 'base64') }, sharedKey, Buffer.from(outgoing.ciphertext, 'base64'));
    assert.equal(Buffer.from(decoded).toString(), 'My encrypted reply');
    await waitFor("document.querySelector('.chat-item-preview')?.textContent.includes('My encrypted reply')");
    await call('Page.reload');
    await waitFor("document.querySelector('.chat-item-preview')?.textContent.includes('My encrypted reply')");
    console.log('Sent message preview decrypted and restored after reload.');
    await click('.chat-list-item');
    await waitFor("!!document.querySelector('.message-textarea')");
    await screenshot('desktop-conversation');
    await call('Network.emulateNetworkConditions', { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 });
    await waitFor("!!document.querySelector('.connection-notice')");
    await evaluate("(() => {const input = document.querySelector('.message-textarea'); Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(input, 'Retry this encrypted message'); input.dispatchEvent(new Event('input', {bubbles:true}));})()");
    await waitFor("!!document.querySelector('.send-btn')");
    await click('.send-btn');
    await waitFor("!!document.querySelector('.message-retry')");
    await screenshot('desktop-send-failed');
    await call('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
    await waitFor("!document.querySelector('.connection-notice')");
    await waitFor("!!document.querySelector('.message-retry')");
    const retriedMessage = socketEvent(bob.socket, 'private_message');
    await click('.message-retry');
    const retried = await retriedMessage;
    assert.equal(retried.isEncrypted, true);
    await waitFor("!document.querySelector('.message-retry') && !document.querySelector('.message-send-state')");
    await waitFor("Array.from(document.querySelectorAll('.bubble')).some(bubble => bubble.textContent.includes('Retry this encrypted message'))");
    assert.equal(await evaluate("Array.from(document.querySelectorAll('.bubble')).filter(bubble => bubble.textContent.includes('Retry this encrypted message')).length"), 1, 'retry replaces the failed bubble without duplicating it');
    console.log('Offline feedback and encrypted retry passed.');
    await click('[title="Contact Info & Media"]');
    await screenshot('desktop-contact-details');
    await click('[title="Contact Info & Media"]');
    await click('[title="Attach..."]');
    await clickText('Mini Games');
    await screenshot('desktop-games');
    await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, modifiers: 8 });
    await call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, modifiers: 8 });
    assert.equal(await evaluate("!!document.activeElement.closest('[role=dialog]')"), true, 'keyboard focus remains inside the game dialog');
    await click('[aria-label="Play Tic-Tac-Toe"]');
    await waitFor("!!document.querySelector('.tic-tac-toe-board')");
    await wait(600);
    const cells = () => evaluate("Array.from(document.querySelectorAll('.tic-tac-toe-board button')).map(button => ({width: button.offsetWidth, height: button.offsetHeight}))");
    const before = await cells();
    await click('.tic-tac-toe-board button');
    await wait(400);
    assert.deepEqual(await cells(), before, 'Tic-tac-toe cells do not resize after a move');
    await screenshot('desktop-game-move');
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    await screenshot('mobile-conversation');
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 430, deviceScaleFactor: 1, mobile: true });
    await wait(250);
    assert.equal(await evaluate("document.querySelector('.message-textarea').getBoundingClientRect().bottom <= visualViewport.height"), true, 'composer fits a keyboard-sized viewport');
    await screenshot('mobile-keyboard-viewport');
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    await click('[title="Back to chats"]');
    await checkDockAnimation('.mobile-bottom-nav');
    await checkFocusDock('.mobile-bottom-nav', true);
    await call('Emulation.setDeviceMetricsOverride', { width: 320, height: 568, deviceScaleFactor: 1, mobile: true });
    await checkDockAnimation('.mobile-bottom-nav');
    await screenshot('small-mobile-dock');
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    await screenshot('mobile-chats');
    for (const tab of ['Calls', 'Discover', 'Contacts', 'Settings']) {
      await click(`.mobile-bottom-nav [aria-label="${tab}"]`);
      await screenshot(`mobile-${tab.toLowerCase()}`);
    }
    await click('.mobile-bottom-nav [aria-label="Contacts"]');
    await evaluate("Array.from(document.querySelectorAll('.contact-card')).find(card => card.textContent.includes('Hii')).querySelector(':scope > div').click()");
    await waitFor("getComputedStyle(document.querySelector('.workspace-pane')).display === 'flex'");
    await click('[title="Attach..."]');
    await clickText('Mini Games');
    await screenshot('mobile-games');
    await call('Network.clearBrowserCookies');
    await call('Page.navigate', { url: base });
    await waitFor("!!document.querySelector('.landing-navbar')");
    await wait(2800);
    await screenshot('mobile-landing');
    await clickText('Sign In');
    await waitFor("!!document.querySelector('.auth-forgot-password')");
    await screenshot('mobile-signin');
    await click('.auth-forgot-password');
    await screenshot('mobile-recovery');
    await call('Emulation.setDeviceMetricsOverride', { width: 320, height: 568, deviceScaleFactor: 1, mobile: true });
    await screenshot('small-mobile-recovery');
    assert.equal(errors.length, 0, JSON.stringify(errors));
    console.log('Visual smoke checks passed.');
  } finally {
    browser?.close();
    for (const socket of sockets) socket.disconnect();
    if (child.exitCode === null) child.kill();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
