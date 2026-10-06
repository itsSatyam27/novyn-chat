// Uses disposable accounts, data and a headless browser; no production writes.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { io } = require('socket.io-client');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'novyn-settings-'));
  const listener = net.createServer();
  await new Promise(resolve => listener.listen(0, '127.0.0.1', resolve));
  const port = listener.address().port;
  await new Promise(resolve => listener.close(resolve));
  const base = `http://127.0.0.1:${port}`;
  const server = spawn(process.execPath, ['apps/api/server.js'], {
    windowsHide: true, env: { ...process.env, NOVYN_ENV_FILE: path.join(directory, 'absent.env'),
      PORT: String(port), NODE_ENV: 'development', DATA_DIR: path.join(directory, 'data'),
      UPLOADS_DIR: path.join(directory, 'uploads'), MONGODB_URI: '', MONGO_URL: '', MONGO_URI: '',
      FIREBASE_SERVICE_ACCOUNT_FILE: path.join(directory, 'absent.json'), FIREBASE_SERVICE_ACCOUNT_JSON: '',
      FIREBASE_PROJECT_ID: '', FIREBASE_CLIENT_EMAIL: '', FIREBASE_PRIVATE_KEY: '',
      VAPID_PUBLIC_KEY: '', VAPID_PRIVATE_KEY: '', SMTP_HOST: '', SMTP_USER: '', SMTP_PASS: '',
      AUTH_SECRET: 'settings-test-only', UPLOAD_TOKEN_SECRET: 'settings-test-only',
    },
  });
  let chrome, websocket, peer, setupSocket;
  try {
    let logs = '';
    server.stdout.on('data', data => { logs += data; });
    server.stderr.on('data', data => { logs += data; });
    for (let i = 0; i < 100 && !logs.includes('Chat app running'); i++) await delay(100);
    assert.ok(logs.includes('Chat app running'), logs);
    const signup = await fetch(`${base}/api/auth/signup`, { method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Harsh', username: 'settingsuser', email: 'settings@example.test', password: 'Settings-test-password-123!' }),
    });
    assert.equal(signup.status, 200);
    const cookies = signup.headers.getSetCookie().map(value => value.split(';')[0]);
    const socketEvent = (socket, name) => new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Missing socket event: ${name}`)), 10000);
      socket.once(name, value => { clearTimeout(timer); resolve(value); });
    });
    const connect = async cookie => {
      const socket = io(base, { autoConnect: false, transports: ['websocket'], extraHeaders: { Cookie: cookie }, reconnection: false });
      const ready = socketEvent(socket, 'register_success'); socket.connect(); await ready; return socket;
    };
    const peerSignup = await fetch(`${base}/api/auth/signup`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Status Peer', username: 'statuspeer', email: 'peer@example.test', password: 'Settings-test-password-123!' }),
    });
    assert.equal(peerSignup.status, 200);
    peer = await connect(peerSignup.headers.getSetCookie().map(value => value.split(';')[0]).join('; '));
    setupSocket = await connect(cookies.join('; '));
    assert.equal((await setupSocket.timeout(3000).emitWithAck('add_friend', 'statuspeer')).ok, true);
    const accepted = socketEvent(setupSocket, 'friend_request_accepted'); peer.emit('accept_friend', 'settingsuser'); await accepted;
    setupSocket.disconnect();
    const profile = path.join(directory, 'chrome');
    chrome = spawn(process.env.SETTINGS_CHROME || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      ['--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
        '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true });
    let debugPort;
    for (let i = 0; i < 100; i++) {
      try { debugPort = Number((await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); break; }
      catch { await delay(100); }
    }
    assert.ok(debugPort, 'headless Chrome started');
    const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
    websocket = new WebSocket(targets.find(target => target.type === 'page').webSocketDebuggerUrl);
    await new Promise(resolve => websocket.addEventListener('open', resolve, { once: true }));
    let id = 0;
    const pending = new Map();
    const errors = [];
    websocket.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data);
      if (message.id) {
        const item = pending.get(message.id); pending.delete(message.id);
        message.error ? item.reject(message.error) : item.resolve(message.result);
      }
      if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails);
    });
    const call = (method, params = {}) => new Promise((resolve, reject) => {
      const key = ++id; pending.set(key, { resolve, reject }); websocket.send(JSON.stringify({ id: key, method, params }));
    });
    const evaluate = async expression => {
      const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails));
      return result.result.value;
    };
    const waitFor = async expression => {
      for (let i = 0; i < 100; i++) { if (await evaluate(`Boolean(${expression})`)) return; await delay(100); }
      throw new Error(`Not ready: ${expression}\n${await evaluate('document.body.innerText')}`);
    };
    const clickText = text => evaluate(`Array.from(document.querySelectorAll('.android-settings-row')).find(button => button.textContent.includes(${JSON.stringify(text)})).click()`);
    await call('Runtime.enable');
    await call('Page.enable');
    await call('Page.addScriptToEvaluateOnNewDocument', { source: `
      window.__playedAudio = []; window.__notifications = []; window.__vibrations = [];
      HTMLMediaElement.prototype.play = function() { window.__playedAudio.push(this.src); return Promise.resolve(); };
      navigator.vibrate = function(value) { window.__vibrations.push(value); return true; };
      window.Notification = class {
        static permission = 'granted';
        constructor(title, options) { window.__notifications.push({title, ...options}); }
        close() {}
      };
    ` });
    await call('Network.enable');
    for (const cookie of cookies) {
      const separator = cookie.indexOf('=');
      await call('Network.setCookie', { name: cookie.slice(0, separator), value: cookie.slice(separator + 1), url: base });
    }
    await call('Emulation.setDeviceMetricsOverride', { width: 1365, height: 900, deviceScaleFactor: 1, mobile: false });
    await call('Page.navigate', { url: base });
    await waitFor("document.querySelector('[aria-label=\"Settings\"] button') || document.querySelector('button[aria-label=\"Settings\"]')");
    await evaluate("document.querySelector('button[aria-label=\"Settings\"]').click()");
    await waitFor("document.querySelector('.android-profile-card')");
    assert.equal(await evaluate("document.querySelector('.android-profile-card h2').textContent"), 'Harsh');
    assert.deepEqual(await evaluate("Array.from(document.querySelectorAll('.android-settings-section')).map(el => el.textContent.trim())"), ['PREFERENCES', 'ACCOUNT', 'SUPPORT', 'DANGER']);
    assert.equal(await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).animationDuration"), '10s');
    const orbitStart = await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).transform");
    await delay(200);
    assert.notEqual(await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).transform"), orbitStart, 'avatar comet rotates');
    await waitFor("document.querySelector('.settings-detail')");
    await delay(500);
    const desktopCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-settings.png'), Buffer.from(desktopCapture.data, 'base64'));
    assert.equal(await evaluate("document.querySelectorAll('.android-presence button').length"), 1);
    const profileHeight = await evaluate("document.querySelector('.android-profile-card').getBoundingClientRect().height");
    await evaluate("document.querySelector('.android-presence button').click()");
    await waitFor("document.querySelectorAll('.android-presence-menu button').length === 4");
    assert.equal(await evaluate("document.querySelector('.android-profile-card').getBoundingClientRect().height"), profileHeight);
    assert.equal(await evaluate("document.querySelectorAll('.android-presence-menu [aria-checked=true]').length"), 1);
    await evaluate("document.querySelector('.android-presence-menu button:nth-child(3)').click()");
    await waitFor("document.querySelectorAll('.android-presence button').length === 1 && document.querySelector('.android-presence button').textContent.includes('Busy')");
    await delay(300);
    const session = await fetch(`${base}/api/auth/session`, { headers: { Cookie: cookies.join('; ') } });
    assert.equal((await session.json()).presenceMode, 'busy', 'presence persisted on backend');
    await evaluate("window.__playedAudio = []; window.__notifications = []; window.__vibrations = []");
    assert.equal(await evaluate('Notification.permission'), 'granted');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Busy notification test' })).ok, true);
    await delay(600);
    assert.equal(await evaluate('window.__notifications.length'), 1, JSON.stringify(await evaluate('({played: window.__playedAudio, notifications: window.__notifications, vibrations: window.__vibrations, permission: Notification.permission})')));
    assert.equal(await evaluate('window.__notifications[0].silent'), true);
    assert.deepEqual(await evaluate('window.__playedAudio'), []);
    assert.deepEqual(await evaluate('window.__vibrations'), []);
    await evaluate("document.querySelector('.android-presence-badge').click()");
    await evaluate("document.querySelector('.android-presence-menu button:first-child').click()");
    await waitFor("document.querySelector('.android-presence-badge').textContent.includes('Online')");
    await delay(200);
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Online notification test' })).ok, true);
    await waitFor('window.__notifications.length === 2');
    assert.equal(await evaluate('window.__notifications[1].silent'), false);
    assert.ok(await evaluate("window.__playedAudio.some(src => src.includes('notification.mp3'))"));
    await evaluate("document.querySelector('button[aria-label=\"Chats\"]').click()");
    for (const [mode, label, color] of [
      ['busy', 'Busy', 'rgb(236, 72, 153)'],
      ['away', 'Away', 'rgb(245, 158, 11)'],
      ['online', 'Online', 'rgb(16, 185, 129)'],
      ['invisible', 'Offline', 'rgb(100, 116, 139)'],
    ]) {
      const updated = socketEvent(peer, 'profile_updated'); peer.emit('update_profile', { presenceMode: mode }); await updated;
      await waitFor(`document.querySelector('span[role="img"][aria-label="${label}"]')`);
      assert.equal(await evaluate(`getComputedStyle(document.querySelector('span[role="img"][aria-label="${label}"]')).backgroundColor`), color);
      await evaluate("document.querySelector('button[aria-label=\"Contacts\"]').click()");
      await waitFor(`document.querySelector('span[role="img"][aria-label="${label}"]')`);
      assert.equal(await evaluate(`getComputedStyle(document.querySelector('span[role="img"][aria-label="${label}"]')).backgroundColor`), color);
      await evaluate("document.querySelector('button[aria-label=\"Chats\"]').click()");
    }
    await evaluate("document.querySelector('button[aria-label=\"Settings\"]').click()");
    await waitFor("document.querySelector('.android-profile-card')");
    await clickText('QR Code');
    await waitFor("document.querySelector('.android-qr img')?.src.startsWith('data:image/png')");
    assert.ok(await evaluate("document.querySelector('.android-qr a').hasAttribute('download')"));
    await evaluate("document.querySelector('dialog button[aria-label=\"Close\"]').click()");
    await clickText('Sound & Vibration');
    await waitFor("document.querySelector('[aria-label=\"Toggle message sounds\"]')");
    await evaluate("document.querySelector('[aria-label=\"Toggle message sounds\"]').click()");
    assert.equal(await evaluate("localStorage.getItem('novyn_sound')"), 'false');
    await clickText('Language & Region');
    await waitFor("document.querySelector('dialog[open] select')");
    await evaluate("{ const language = document.querySelector('dialog select'); language.value='hi'; language.dispatchEvent(new Event('change', {bubbles:true})); }");
    await waitFor("document.querySelector('.android-settings h1').textContent === 'सेटिंग्स'");
    assert.equal(await evaluate("localStorage.getItem('novyn_settings_language')"), 'hi');
    await evaluate("{ const region = document.querySelectorAll('dialog select')[1]; region.value='GB'; region.dispatchEvent(new Event('change', {bubbles:true})); }");
    assert.equal(await evaluate("localStorage.getItem('novyn_region')"), 'GB');
    await evaluate("{ const language = document.querySelector('dialog select'); language.value='en'; language.dispatchEvent(new Event('change', {bubbles:true})); document.querySelector('dialog button[aria-label=\"Close\"]').click(); }");
    await delay(200);
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    await waitFor("document.querySelector('[aria-label=\"Back to Settings\"]')");
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await waitFor("document.querySelector('.android-settings').getBoundingClientRect().width > 300");
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false);
    const { data } = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-settings.png'), Buffer.from(data, 'base64'));
    await clickText('Appearance');
    await waitFor("document.querySelector('.settings-detail')?.getClientRects().length > 0");
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Log Out');
    await waitFor("document.querySelector('dialog[open]')");
    await evaluate("document.querySelector('.android-dialog-actions button').click()");
    assert.ok(await evaluate("document.querySelector('.android-profile-card') !== null"));
    assert.equal(errors.length, 0, JSON.stringify(errors));
    console.log('Settings checks passed: profile, backend presence, QR, saved preferences, mobile navigation, logout cancellation.');
    console.log('Screenshot:', path.join(directory, 'mobile-settings.png'));
  } finally {
    peer?.disconnect(); setupSocket?.disconnect();
    websocket?.close();
    chrome?.kill();
    server.kill();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
