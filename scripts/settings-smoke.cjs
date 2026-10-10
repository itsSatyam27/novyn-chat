// Uses disposable accounts, data and a headless browser; no production writes.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { io } = require('socket.io-client');
const { webcrypto } = require('node:crypto');
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
    const peerKeys = await webcrypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey', 'deriveBits']);
    const peerPublicKey = JSON.stringify(await webcrypto.subtle.exportKey('jwk', peerKeys.publicKey));
    assert.equal((await peer.timeout(3000).emitWithAck('register_public_key', { publicKey: peerPublicKey })).ok, true);
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
    await call('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: directory });
    await call('Page.addScriptToEvaluateOnNewDocument', { source: `
      window.__playedAudio = []; window.__notifications = []; window.__vibrations = [];
      window.__audioEvents = []; window.__pausedAudio = [];
      HTMLMediaElement.prototype.play = function() { window.__playedAudio.push(this.src); window.__audioEvents.push({src:this.src, volume:this.volume}); return Promise.resolve(); };
      HTMLMediaElement.prototype.pause = function() { window.__pausedAudio.push(this.src); };
      navigator.vibrate = function(value) { window.__vibrations.push(value); return true; };
      window.Notification = class {
        static permission = 'granted';
        static async requestPermission() { window.__permissionRequests++; this.permission = window.__permissionResponse; return this.permission; }
        constructor(title, options) { window.__notifications.push({title, ...options}); }
        close() {}
      };
      window.__permissionRequests = 0; window.__permissionResponse = 'granted';
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
    assert.deepEqual(await evaluate("Array.from(document.querySelectorAll('.android-settings-section')).map(el => el.textContent.trim())"), ['PREFERENCES', 'ACCOUNT', 'SUPPORT']);
    assert.equal(await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).animationDuration"), '10s');
    const orbitStart = await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).transform");
    await delay(200);
    assert.notEqual(await evaluate("getComputedStyle(document.querySelector('.android-profile-comet')).transform"), orbitStart, 'avatar comet rotates');
    await waitFor("document.querySelector('.settings-detail')");
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".settings-workspace")).flexDirection'), 'row');
    assert.equal(await evaluate('document.querySelectorAll(".android-settings-logout").length'), 1, 'one main logout action');
    assert.equal(await evaluate('document.querySelector(".android-browser-signout")'), null, 'no duplicate footer action');
    await waitFor('document.querySelector(".profile-dashboard-grid")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'profile dashboard has one sidebar');
    assert.equal(await evaluate('document.querySelector(".settings-sidebar .android-settings-icon")'), null, 'navigation uses icons without square tiles');
    assert.equal(await evaluate('Array.from(document.querySelectorAll(".settings-menu-scroll button")).some(button => ["Presence & Status", "QR Code"].includes(button.title))'), false, 'presence and QR are available only in the profile cards');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false);
    const logoutTop = await evaluate('document.querySelector(".settings-sidebar-footer").getBoundingClientRect().top');
    await evaluate('document.querySelector(".settings-menu-scroll").scrollTop = 10000');
    assert.equal(await evaluate('document.querySelector(".settings-sidebar-footer").getBoundingClientRect().top'), logoutTop, 'logout stays fixed when menu scrolls');
    await evaluate('document.querySelector(".settings-menu-scroll").scrollTop = 0');
    await delay(500);
    const desktopCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-settings.png'), Buffer.from(desktopCapture.data, 'base64'));
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
    const selectSection = label => evaluate(`(() => {
      const label = ${JSON.stringify(label)};
      const dashboard = document.querySelector('.security-dashboard');
      if (dashboard) {
        const summary = Array.from(dashboard.querySelectorAll('summary')).find(item => item.textContent === label);
        if (summary) { if (!summary.parentElement.open) summary.click(); summary.scrollIntoView({block:'center'}); }
        else Array.from(dashboard.querySelectorAll('h3')).find(item => item.textContent === label)?.scrollIntoView({block:'center'});
        return;
      }
      const picker = document.querySelector('.settings-section-picker select');
      if (picker?.getClientRects().length) {
        const option = Array.from(picker.options).find(option => option.text === label);
        Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(picker, option.value);
        picker.dispatchEvent(new Event('change', {bubbles:true}));
      } else {
        Array.from(document.querySelectorAll('.settings-section-tabs button')).find(button => button.textContent.startsWith(label)).click();
      }
    })()`);
    const clickControl = text => evaluate('Array.from(document.querySelectorAll(".settings-detail-body button")).find(button => button.textContent.trim() === ' + JSON.stringify(text) + ').click()');
    const toggle = label => evaluate('document.querySelector(\'button[role="switch"][aria-label=' + JSON.stringify(label) + ']\').click()');
    const field = async (label, value) => {
      await evaluate('{ const field = Array.from(document.querySelectorAll(".web-settings-field")).find(el => el.textContent.startsWith(' + JSON.stringify(label) + ')).querySelector("input, select, textarea"); const proto = field instanceof HTMLSelectElement ? HTMLSelectElement.prototype : field instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype; Object.getOwnPropertyDescriptor(proto, "value").set.call(field, ' + JSON.stringify(value) + '); field.dispatchEvent(new Event(field instanceof HTMLSelectElement ? "change" : "input", {bubbles:true})); }');
    };
    await field('Display name', 'Unsaved preview'); await field('Bio', 'Draft bio');
    assert.equal(await evaluate('document.querySelector(".profile-hero h2").textContent'), 'Unsaved preview');
    const heroTop = await evaluate('document.querySelector(".profile-hero").getBoundingClientRect().top');
    await clickControl('Busy');
    await waitFor('document.querySelector(".settings-sidebar-user-status").textContent.includes("Busy")');
    await waitFor('document.querySelector(".settings-toast[role=status]")?.textContent === "Status updated."');
    assert.equal(await evaluate('document.querySelector(".profile-hero").getBoundingClientRect().top'), heroTop, 'toast does not shift profile cards');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".settings-toast-position")).position'), 'fixed');
    assert.equal(await evaluate('document.querySelector(".profile-dashboard .web-settings-result")'), null, 'inline status banner is removed');
    await delay(250);
    const popupCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'profile-status-popup.png'), Buffer.from(popupCapture.data, 'base64'));
    assert.equal(await evaluate('document.querySelector(".profile-hero h2").textContent'), 'Unsaved preview', 'presence changes preserve profile drafts');
    assert.equal((await (await fetch(base + '/api/auth/session', { headers: { Cookie: cookies.join('; ') } })).json()).displayName, 'Harsh', 'status does not save unfinished profile edits');
    await delay(1900);
    await clickControl('Online'); await waitFor('document.querySelector(".settings-sidebar-user-status").textContent.includes("Online")');
    await waitFor('document.querySelector(".settings-toast[role=status]")?.textContent === "Status updated."');
    const toastStarted = Date.now();
    await delay(1700);
    assert.ok(await evaluate('Boolean(document.querySelector(".settings-toast"))'), 'a repeated update restarts the popup timer');
    await waitFor('!document.querySelector(".settings-toast")');
    assert.ok(Date.now() - toastStarted >= 3200 && Date.now() - toastStarted < 4500, 'popup disappears after 3–4 seconds');
    await clickControl('Discard');
    assert.equal(await evaluate('document.querySelector(".profile-hero h2").textContent'), 'Harsh');
    assert.equal(await evaluate('document.querySelector(".profile-dashboard-header button[type=submit]").disabled'), true);
    await clickControl('Change');
    await waitFor('document.querySelector(".mobile-managed-setting")');
    assert.equal(await evaluate('document.querySelector(".settings-detail-title h2").textContent'), 'Change Username');
    await clickText('Profile'); await clickControl('Manage');
    await waitFor('document.querySelector(".mobile-managed-setting")');
    assert.equal(await evaluate('document.querySelector(".settings-detail-title h2").textContent'), 'Linked Email');
    await clickText('Profile');
    await waitFor('document.querySelector(".profile-qr-card img")');
    assert.ok(await evaluate('Boolean(document.querySelector(".profile-qr-card a[download]"))'), 'dashboard provides a real downloadable QR code');
    await clickText('Appearance');
    await waitFor('document.querySelector(".appearance-dashboard")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'Appearance opens a dashboard with one sidebar');
    assert.equal(await evaluate('document.querySelector(".appearance-shortcuts")'), null, 'language and accessibility stay in their sidebar sections');
    await clickControl('Dark');
    assert.equal(await evaluate('document.documentElement.dataset.colorMode'), 'dark');
    await delay(200);
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".appearance-theme-option[aria-pressed=true]")).boxShadow'), 'none', 'theme selection has one border without a second ring');
    const appearanceCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-appearance-dark.png'), Buffer.from(appearanceCapture.data, 'base64'));
    await evaluate('document.querySelector(".font-select-trigger").focus(); document.querySelector(".font-select-trigger").click()');
    await waitFor('document.querySelector(".font-select-menu")');
    assert.equal(await evaluate('document.querySelectorAll(".font-select-menu [role=option]").length'), 6);
    await delay(200);
    const fontMenuCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'font-dropdown-dark.png'), Buffer.from(fontMenuCapture.data, 'base64'));
    await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape' });
    await waitFor('!document.querySelector(".font-select-menu")');
    await clickControl('System');
    await call('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'light' }] });
    await waitFor('document.documentElement.dataset.colorMode === "light"');
    await call('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'dark' }] });
    await waitFor('document.documentElement.dataset.colorMode === "dark"');
    await clickControl('Light');
    await delay(200);
    const appearanceLightCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-appearance-light.png'), Buffer.from(appearanceLightCapture.data, 'base64'));
    await toggle('Always show navigation dock');
    assert.equal(await evaluate('localStorage.getItem("novyn_dock_always_visible")'), 'true');
    await evaluate('document.querySelector(".font-select-trigger").focus()');
    for (let i = 0; i < 3; i++) await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'ArrowDown', code: 'ArrowDown' });
    await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter' });
    await waitFor('!document.querySelector(".font-select-menu")');
    assert.equal(await evaluate('document.querySelector(".font-select-trigger").textContent'), 'Outfit Geometric');
    assert.match(await evaluate('document.documentElement.style.getPropertyValue("--app-font-family")'), /Outfit/);
    await evaluate('document.querySelector(".font-select-trigger").click()');
    await call('Input.dispatchMouseEvent', { type: 'mousePressed', x: 900, y: 90, button: 'left', clickCount: 1 });
    await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 900, y: 90, button: 'left', clickCount: 1 });
    await waitFor('!document.querySelector(".font-select-menu")');
    await evaluate('document.querySelector(\'input[aria-label="Message text size"]\').focus()');
    for (const key of ['Home', 'End']) {
      await call('Input.dispatchKeyEvent', { type: 'keyDown', key, code: key, windowsVirtualKeyCode: key === 'Home' ? 36 : 35 });
      await call('Input.dispatchKeyEvent', { type: 'keyUp', key, code: key, windowsVirtualKeyCode: key === 'Home' ? 36 : 35 });
    }
    assert.equal(await evaluate('document.documentElement.style.getPropertyValue("--message-font-size")'), '16.5px');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".appearance-chat-preview")).fontSize'), '16.5px');
    const previousSize = await evaluate('localStorage.getItem("novyn_font_size")');
    const slider = await evaluate('{ const r = document.querySelector(\'input[aria-label="Message text size"]\').getBoundingClientRect(); ({left:r.left, width:r.width, y:r.top+r.height/2}); }');
    const sliderX = percent => slider.left + 9 + (slider.width - 18) * percent / 100;
    await call('Input.dispatchMouseEvent', { type: 'mousePressed', x: sliderX(20), y: slider.y, button: 'left', clickCount: 1 });
    for (const percent of [23, 31, 44, 67, 73]) await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: sliderX(percent), y: slider.y, button: 'left', buttons: 1 });
    const chosenPercent = Number(await evaluate('document.querySelector(\'input[aria-label="Message text size"]\').value'));
    assert.ok(chosenPercent > 50 && chosenPercent < 100, 'slider accepts values between the old three steps');
    const configuredMessageSize = String(Math.round((13.5 + chosenPercent * .03) * 100) / 100);
    assert.equal(await evaluate('document.documentElement.style.getPropertyValue("--message-font-size")'), configuredMessageSize + 'px', 'drag updates live text size');
    assert.equal(await evaluate('localStorage.getItem("novyn_font_size")'), previousSize, 'drag avoids saving preferences on every move');
    await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: sliderX(73), y: slider.y, button: 'left', clickCount: 1 });
    assert.equal(await evaluate('localStorage.getItem("novyn_font_size")'), configuredMessageSize, 'release saves the exact chosen size');
    await clickControl('Emerald Aurora');
    assert.equal(await evaluate('localStorage.getItem("novyn_wallpaper")'), 'aurora');
    assert.match(await evaluate('document.documentElement.style.getPropertyValue("--chat-wallpaper")'), /radial-gradient/);
    assert.ok(await evaluate('Array.from(document.querySelectorAll(".appearance-wallpaper-options button")).every(button => button.title && button.textContent.trim())'), 'wallpapers have visible names and descriptions');
    await clickControl('Misty Mountains');
    assert.equal(await evaluate('localStorage.getItem("novyn_wallpaper")'), 'mountains');
    assert.ok(await evaluate('Boolean(document.querySelector(".appearance-wallpaper-options button[aria-pressed=true] .appearance-wallpaper-swatch").style.backgroundImage)'), 'vector wallpaper preview is a valid CSS image');
    await clickText('Accessibility');
    await waitFor('document.querySelector(".accessibility-dashboard")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'accessibility has one sidebar');
    await clickControl('Try transition');
    assert.equal(await evaluate('document.querySelector(".accessibility-motion-track > span").dataset.end'), 'true');
    await toggle('Reduce motion'); await toggle('High contrast');
    assert.equal(await evaluate('document.documentElement.dataset.reduceMotion'), 'true');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".android-profile-comet")).animationDuration'), '1e-05s');
    assert.equal(await evaluate('document.documentElement.dataset.highContrast'), 'true');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".accessibility-motion-track > span")).transitionDuration'), '1e-05s', 'preview respects reduced motion');
    await toggle('Reduce motion'); await toggle('High contrast');
    await clickText('Appearance');
    await clickText('Language & Region');
    await waitFor('document.querySelector(".language-dashboard")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'language settings have one sidebar');
    const chooseRegionalOption = async (label, index) => {
      await evaluate(`Array.from(document.querySelectorAll('.language-dashboard .web-settings-field')).find(field => field.textContent.startsWith(${JSON.stringify(label)})).querySelector('button').click()`);
      await waitFor('document.querySelector(".font-select-menu")');
      await evaluate(`document.querySelectorAll('.font-select-menu [role=option]')[${index}].click()`);
      await waitFor('!document.querySelector(".font-select-menu")');
    };
    const chooseTimeZone = async zone => {
      await evaluate(`{ const button = Array.from(document.querySelectorAll('.language-dashboard .web-settings-field')).find(field => field.textContent.startsWith('Choose time zone')).querySelector('button'); button.scrollIntoView({block:'center'}); button.focus(); button.click(); }`);
      await waitFor('document.querySelector(".settings-select-search")');
      await evaluate(`{ const input = document.querySelector('.settings-select-search'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, ${JSON.stringify(zone)}); input.dispatchEvent(new Event('input', {bubbles:true})); }`);
      await waitFor('document.querySelectorAll(".font-select-menu [role=option]").length === 1');
      await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
      await waitFor('!document.querySelector(".font-select-menu")');
      assert.equal(await evaluate('localStorage.getItem("novyn_time_zone")'), zone);
    };
    assert.equal(await evaluate('document.querySelector(".language-zone-modes button[aria-pressed=true]").textContent'), 'Automatic', 'device time is the default');
    await waitFor('document.querySelector(".region-globe canvas")');
    await delay(1200);
    const indiaGlobe = await evaluate('document.querySelector(".region-globe canvas").toDataURL()');
    assert.equal(await evaluate('document.querySelector(".region-globe canvas").getAttribute("aria-label")'), '3D globe highlighting India');
    assert.equal(await evaluate('document.querySelector(".language-time-preview output").textContent'), await evaluate('new Intl.DateTimeFormat("en-IN", {hour:"numeric",minute:"2-digit",timeZoneName:"short"}).format(new Date())'));
    const indiaCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'globe-india.png'), Buffer.from(indiaCapture.data, 'base64'));
    await chooseRegionalOption('Region', 1);
    await delay(1200);
    const usaGlobe = await evaluate('document.querySelector(".region-globe canvas").toDataURL()');
    assert.notEqual(usaGlobe, indiaGlobe, 'region selection changes the rendered globe');
    assert.equal(await evaluate('document.querySelector(".region-globe canvas").getAttribute("aria-label")'), '3D globe highlighting United States');
    assert.equal(await evaluate('document.querySelector(".language-time-preview output").textContent'), await evaluate('new Intl.DateTimeFormat("en-US", {hour:"numeric",minute:"2-digit",timeZoneName:"short"}).format(new Date())'));
    const usaCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'globe-us.png'), Buffer.from(usaCapture.data, 'base64'));
    await delay(150);
    assert.equal(await evaluate('document.querySelector(".region-globe canvas").toDataURL()'), usaGlobe, 'globe stops animating once the selected region is in view');
    await chooseRegionalOption('Region', 0);
    await chooseRegionalOption('Settings language', 1);
    await waitFor('document.querySelector(".android-settings h1").textContent !== "Settings"');
    assert.equal(await evaluate('document.documentElement.lang'), 'hi');
    assert.equal(await evaluate('document.querySelector(".language-date-preview output").textContent'), await evaluate('new Intl.DateTimeFormat("hi-IN", {dateStyle:"long"}).format(new Date())'));
    await chooseRegionalOption('Region', 2); await chooseRegionalOption('Settings language', 0);
    await waitFor('document.querySelector(".android-settings h1").textContent === "Settings"');
    assert.equal(await evaluate('localStorage.getItem("novyn_region")'), 'GB');
    await delay(1200);
    assert.equal(await evaluate('document.querySelector(".region-globe canvas").getAttribute("aria-label")'), '3D globe highlighting United Kingdom');
    assert.equal(await evaluate('document.querySelector(".language-time-preview output").textContent'), await evaluate('new Intl.DateTimeFormat("en-GB", {hour:"numeric",minute:"2-digit",timeZoneName:"short"}).format(new Date())'));
    const languageCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'language-desktop.png'), Buffer.from(languageCapture.data, 'base64'));
    // Check midnight rollover and daylight-saving offsets independently of the device zone.
    await call('Emulation.setTimezoneOverride', { timezoneId: 'Pacific/Honolulu' });
    await evaluate('document.dispatchEvent(new Event("visibilitychange"))');
    await waitFor('document.querySelector(".language-time-preview").dataset.timeZone === "Pacific/Honolulu"');
    await clickControl('Manual');
    await evaluate(`window.__RealDate = Date; window.__regionalNow = '2026-01-15T00:15:00Z';
      window.Date = class extends window.__RealDate { constructor(...args) { if (!args.length) super(window.__regionalNow); else super(...args); } };`);
    for (const instant of ['2026-01-15T00:15:00Z', '2026-07-15T00:15:00Z']) {
      await evaluate(`window.__regionalNow = ${JSON.stringify(instant)}; document.dispatchEvent(new Event('visibilitychange'));`);
      for (const [index, locale, timeZone] of [[0, 'en-IN', 'Asia/Kolkata'], [1, 'en-US', 'America/New_York'], [1, 'en-US', 'America/Los_Angeles'], [2, 'en-GB', 'Europe/London']]) {
        await chooseRegionalOption('Region', index);
        await chooseTimeZone(timeZone);
        const expected = await evaluate(`({ date: new Intl.DateTimeFormat('${locale}', {dateStyle:'long',timeZone:'${timeZone}'}).format(new Date()), time: new Intl.DateTimeFormat('${locale}', {hour:'numeric',minute:'2-digit',timeZone:'${timeZone}',timeZoneName:'short'}).format(new Date()), weekday: new Intl.DateTimeFormat('${locale}', {weekday:'long',timeZone:'${timeZone}'}).format(new Date()) })`);
        await waitFor(`document.querySelector('.language-time-preview output').textContent === ${JSON.stringify(expected.time)}`);
        assert.equal(await evaluate('document.querySelector(".language-date-preview output").textContent'), expected.date, 'date follows selected time zone at midnight');
        assert.equal(await evaluate('document.querySelector(".language-date-preview > span").textContent'), expected.weekday, 'weekday follows selected time zone');
      }
    }
    await chooseRegionalOption('Region', 1);
    await chooseTimeZone('America/Los_Angeles');
    await chooseRegionalOption('Region', 2);
    assert.equal(await evaluate('document.querySelector(".language-time-preview").dataset.timeZone'), 'America/Los_Angeles', 'region changes do not override a manual time zone');
    await clickControl('Automatic');
    await waitFor('document.querySelector(".language-time-preview").dataset.timeZone === "Pacific/Honolulu"');
    await clickControl('Manual');
    await waitFor('document.querySelector(".language-time-preview").dataset.timeZone === "America/Los_Angeles"');
    await evaluate('window.Date = window.__RealDate; delete window.__RealDate; delete window.__regionalNow; document.dispatchEvent(new Event("visibilitychange"));');
    await call('Emulation.setTimezoneOverride', { timezoneId: '' });
    await clickText('Appearance'); await clickText('Language & Region');
    await waitFor('document.querySelector(".language-dashboard")');
    assert.equal(await evaluate('document.querySelector(".language-time-preview").dataset.timeZone'), 'America/Los_Angeles', 'manual time zone persists across navigation');
    const manualZoneCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'language-manual.png'), Buffer.from(manualZoneCapture.data, 'base64'));
    await clickText('Sounds & Notifications');
    await waitFor('document.querySelector(".sound-dashboard")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'sound controls share one dashboard');
    assert.equal(await evaluate('document.querySelector(".sound-busy-state").textContent'), 'Off');
    assert.equal(await evaluate('document.querySelector(\'.settings-sidebar button[title="Notifications"]\')'), null, 'one combined sidebar entry');
    assert.ok(await evaluate('Boolean(document.querySelector(".notification-settings"))'), 'notifications are included in the sound dashboard');
    assert.equal(await evaluate('document.querySelector(".sound-dashboard").textContent.toLowerCase().includes("vibration")'), false, 'vibration is absent from web settings even if the browser exposes the API');
    const soundCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-sounds-light.png'), Buffer.from(soundCapture.data, 'base64'));
    await evaluate('document.querySelector(".notification-settings").scrollIntoView({block:"center"})');
    const notificationsCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'notifications-light.png'), Buffer.from(notificationsCapture.data, 'base64'));
    await toggle('Message previews');
    assert.equal(await evaluate('document.querySelector(".notification-sample p").textContent'), 'New message');
    await toggle('Message previews');
    await evaluate('Notification.permission = "denied"; window.dispatchEvent(new Event("focus"));');
    await waitFor('document.querySelector(\'[data-permission="denied"]\')');
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Browser notifications"]\').disabled'), true);
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Browser notifications"]\').getAttribute("aria-checked")'), 'false');
    await evaluate('Notification.permission = "default"; window.__permissionResponse = "default"; window.dispatchEvent(new Event("focus"));');
    await waitFor('document.querySelector(\'[data-permission="default"]\')');
    assert.equal(await evaluate('window.__permissionRequests'), 0, 'permission is requested only after a user action');
    await clickControl('Enable browser notifications');
    await waitFor('window.__permissionRequests === 1 && !document.querySelector(".notification-permission button").disabled');
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Browser notifications"]\').getAttribute("aria-checked")'), 'false');
    await evaluate('window.__permissionResponse = "granted";');
    await toggle('Browser notifications');
    await waitFor('document.querySelector(\'[data-permission="granted"]\')');
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Browser notifications"]\').getAttribute("aria-checked")'), 'true');
    await evaluate('window.__notificationMock = Notification; window.Notification = undefined; window.dispatchEvent(new Event("focus"));');
    await waitFor('document.querySelector(\'[data-permission="unsupported"]\')');
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Browser notifications"]\').disabled'), true);
    await evaluate('window.Notification = window.__notificationMock; window.dispatchEvent(new Event("focus")); document.querySelector(".settings-detail-body").scrollTop = 0;');
    const volume = async (kind, value) => {
      await field(kind + ' volume', String(value));
      await evaluate('document.querySelector(\'input[aria-label="' + kind + ' volume"]\').dispatchEvent(new KeyboardEvent("keyup", {key:"ArrowRight", bubbles:true}))');
    };
    await volume('Message', 37); await volume('Call', 42);
    for (const name of ['Pulse', 'Glass', 'Echo']) {
      await clickControl(name);
      const event = await evaluate('window.__audioEvents.at(-1)');
      assert.ok(event.src.endsWith('/audio/chime-' + name.toLowerCase() + '.wav'));
      assert.equal(event.volume, .37);
      await evaluate('document.querySelector(\'button[aria-label="Stop message preview"]\').click()');
    }
    assert.ok(await evaluate(`(async () => {
      const context = new AudioContext();
      try {
        for (const name of ['pulse', 'glass', 'echo']) {
          const response = await fetch('/audio/chime-' + name + '.wav');
          const buffer = await context.decodeAudioData(await response.arrayBuffer());
          if (!(buffer.duration > .3 && buffer.duration < 2)) return false;
        }
        return true;
      } finally { await context.close(); }
    })()`), 'new chime assets decode successfully');
    for (const kind of ['ringtone', 'ringback']) {
      await clickControl(kind === 'ringtone' ? 'Ringtone' : 'Ringback');
      assert.equal(await evaluate('window.__audioEvents.at(-1).volume'), .42);
      assert.ok(await evaluate('window.__audioEvents.at(-1).src.endsWith(' + JSON.stringify(kind === 'ringtone' ? '/audio/ringtone.mp3' : '/audio/call_ring.mp3') + ')'));
      assert.ok(await evaluate('Boolean(document.querySelector(".sound-calls-card .sound-waveform.is-playing"))'));
      await evaluate('document.querySelector(\'button[aria-label="Stop ' + kind + ' preview"]\').click()');
      assert.equal(await evaluate('document.querySelector(".sound-calls-card .sound-waveform.is-playing")'), null);
      await evaluate('document.querySelector(\'button[aria-label="Play ' + kind + ' preview"]\').click()');
      await toggle('Call sounds');
      await waitFor('!document.querySelector(".sound-calls-card .sound-waveform.is-playing")');
      assert.equal(await evaluate('document.querySelector(\'button[aria-label="Play ' + kind + ' preview"]\').disabled'), true);
      await toggle('Call sounds');
    }
    await evaluate('window.__audioEvents = [];');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Selected chime and volume test' })).ok, true);
    await waitFor('window.__audioEvents.some(event => event.src.endsWith("chime-echo.wav"))');
    assert.equal(await evaluate('window.__audioEvents.at(-1).volume'), .37);
    await volume('Message', 0);
    await evaluate('window.__notifications = []; window.__playedAudio = [];');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Zero volume test' })).ok, true);
    await waitFor('window.__notifications.length === 1');
    assert.equal(await evaluate('window.__notifications[0].silent'), true);
    assert.deepEqual(await evaluate('window.__playedAudio'), []);
    await volume('Message', 37);
    await evaluate('document.querySelector(\'button[aria-label="Play message sound"]\').click()');
    await toggle('Message sounds');
    assert.equal(await evaluate('document.querySelector(\'button[aria-label="Play message sound"]\').disabled'), true);
    assert.ok(await evaluate('window.__pausedAudio.at(-1).endsWith("chime-echo.wav")'), 'mute stops the current preview');
    await clickText('Sounds & Notifications');
    await toggle('Message previews');
    await evaluate('window.__notifications = []; window.__playedAudio = [];');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Private browser preview test' })).ok, true);
    await waitFor('window.__notifications.length === 1');
    assert.equal(await evaluate('window.__notifications[0].body'), 'New message');
    assert.equal(await evaluate('window.__notifications[0].silent'), true);
    assert.deepEqual(await evaluate('window.__playedAudio'), []);
    await toggle('Browser notifications');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Disabled desktop notification test' })).ok, true);
    await delay(250);
    assert.equal(await evaluate('window.__notifications.length'), 1);
    await toggle('Browser notifications');
    await toggle('Message previews');
    await clickText('Sounds & Notifications'); await toggle('Message sounds');
    await toggle('Call sounds');
    await evaluate('window.__playedAudio = []; window.__vibrations = [];');
    peer.emit('call_start', { to: 'settingsuser', callId: 'browser-silent-call', isVideo: false });
    await waitFor('document.querySelector(".call-incoming-controls")');
    assert.deepEqual(await evaluate('window.__playedAudio'), []);
    assert.deepEqual(await evaluate('window.__vibrations'), []);
    peer.emit('call_end', { to: 'settingsuser', callId: 'browser-silent-call', reason: 'Test finished' });
    await waitFor('!document.querySelector(".call-modal-card")');
    await toggle('Call sounds');
    await evaluate('window.__audioEvents = [];');
    peer.emit('call_start', { to: 'settingsuser', callId: 'browser-volume-call', isVideo: false });
    await waitFor('document.querySelector(".call-incoming-controls")');
    assert.equal(await evaluate('window.__audioEvents.find(event => event.src.endsWith("ringtone.mp3"))?.volume'), .42);
    peer.emit('call_end', { to: 'settingsuser', callId: 'browser-volume-call', reason: 'Test finished' });
    await waitFor('!document.querySelector(".call-modal-card")');
    await clickText('Profile');
    await clickControl('Busy');
    await waitFor('document.querySelector(".settings-sidebar-user-status").textContent.includes("Busy")');
    assert.equal((await (await fetch(base + '/api/auth/session', { headers: { Cookie: cookies.join('; ') } })).json()).presenceMode, 'busy');
    await evaluate('window.__notifications = []; window.__playedAudio = [];');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Busy browser test' })).ok, true);
    await waitFor('window.__notifications.length === 1');
    assert.equal(await evaluate('window.__notifications[0].silent'), true);
    assert.deepEqual(await evaluate('window.__playedAudio'), []);
    await clickText('Sounds & Notifications');
    assert.equal(await evaluate('document.querySelector(".sound-busy-state").textContent'), 'Active');
    await clickText('Profile');
    await clickControl('Invisible');
    await waitFor('document.querySelector(".settings-sidebar-user-status").textContent.includes("Invisible")');
    await clickControl('Online');
    await waitFor('document.querySelector(".settings-sidebar-user-status").textContent.includes("Online")');
    await evaluate(`document.querySelector('button[aria-label="Contacts"]').click()`);
    await waitFor('document.querySelector(".contacts-dashboard")');
    assert.ok(await evaluate('Boolean(document.querySelector(".contacts-panel .contacts-filters"))'), 'left contacts list stays available');
    await evaluate('document.querySelector(".contacts-pin-add").click()');
    await waitFor(`document.querySelector('button[aria-label="Pin statuspeer"]')`);
    await evaluate(`document.querySelector('button[aria-label="Pin statuspeer"]').click()`);
    await waitFor(`document.querySelector('button[aria-label="Message statuspeer"]')`);
    assert.ok(await evaluate('JSON.parse(localStorage.getItem("novyn_pinned_settingsuser")).includes("statuspeer")'));
    const contactsCapture = await call('Page.captureScreenshot', {format:'png'});
    await fs.writeFile(path.join(directory, 'contacts-dashboard.png'), Buffer.from(contactsCapture.data, 'base64'));
    await evaluate(`document.querySelector('button[aria-label="Unpin statuspeer"]').click()`);
    await evaluate(`document.querySelector('button[aria-label="Settings"]').click()`);
    await clickText('Security & Privacy');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'security has one sidebar');
    assert.equal(await evaluate('Array.from(document.querySelectorAll(".settings-section-tabs button")).some(button => button.textContent.startsWith("Log Out"))'), false, 'no logout tab');
    await field('Username', 'settingsuser'); await clickControl('Block contact');
    await waitFor('document.querySelector(".web-settings [role=alert]")');
    await field('Username', 'statuspeer'); await clickControl('Block contact');
    await waitFor('Array.from(document.querySelectorAll(".web-settings button")).some(button => button.textContent === "Unblock")');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Must be blocked' })).ok, false);
    let safety = socketEvent(peer, 'register_success'); peer.emit('resume_session');
    let blockedFriend = (await safety).friends.find(item => item.username === 'settingsuser');
    assert.equal(blockedFriend.presence, 'offline');
    assert.equal(blockedFriend.lastSeenAt, null);
    await call('Page.reload');
    await waitFor('document.querySelector(\'button[aria-label="Settings"]\')');
    await evaluate('document.querySelector(\'button[aria-label="Settings"]\').click()');
    await waitFor('document.querySelector(".android-profile-card")');
    assert.equal(await evaluate('document.documentElement.style.getPropertyValue("--message-font-size")'), configuredMessageSize + 'px', 'intermediate size survives reload');
    assert.match(await evaluate('document.documentElement.style.getPropertyValue("--app-font-family")'), /Outfit/);
    assert.equal(await evaluate('localStorage.getItem("novyn_wallpaper")'), 'mountains', 'wallpaper preference survives reload');
    assert.equal(await evaluate('localStorage.getItem("novyn_message_chime")'), 'echo');
    assert.equal(await evaluate('localStorage.getItem("novyn_message_volume")'), '37');
    assert.equal(await evaluate('localStorage.getItem("novyn_call_volume")'), '42');
    await clickText('Security & Privacy');
    await waitFor('Array.from(document.querySelectorAll(".web-settings button")).some(button => button.textContent === "Unblock")');
    await clickControl('Unblock');
    await waitFor('document.querySelector(".web-settings").textContent.includes("No blocked contacts.")');
    assert.equal((await peer.timeout(3000).emitWithAck('private_message', { to: 'settingsuser', text: 'Unblocked browser test' })).ok, true);
    peer.emit('call_start', { to: 'settingsuser', callId: 'browser-blocked-call', isVideo: false });
    await waitFor('document.querySelector(".call-incoming-controls")');
    assert.equal((await peer.timeout(3000).emitWithAck('set_block', { username: 'settingsuser', blocked: true })).ok, true);
    await waitFor('!document.querySelector(".call-modal-card")');
    assert.equal((await peer.timeout(3000).emitWithAck('set_block', { username: 'settingsuser', blocked: 'false' })).ok, false);
    assert.equal((await peer.timeout(3000).emitWithAck('set_block', { username: 'settingsuser', blocked: false })).ok, true);
    await selectSection('Message Retention'); await clickControl('15 days');
    await waitFor('document.querySelector(".security-retention [role=status]")?.textContent === "Message retention updated."');
    assert.equal((await (await fetch(base + '/api/auth/session', { headers: { Cookie: cookies.join('; ') } })).json()).retentionDays, 15);
    for (const label of ['Change Password', 'App Lock', 'Last Seen & Profile Photo', 'Stealth Mode', 'Read Receipts & Activity', 'Two-Factor Authentication', 'Active Sessions', 'Linked Devices', 'Account Actions']) {
      await selectSection(label);
      await waitFor('document.querySelector(".security-card details[open]")');
      assert.equal(await evaluate('document.querySelector(".security-phone input, .security-phone select, .security-phone button")'), null);
      assert.ok(await evaluate('document.querySelector(".security-card details[open] .security-guidance").textContent.length > 0'));
    }
    await evaluate('document.querySelector(".android-profile-edit").click()');
    await field('Display name', 'Harsh Web'); await field('Bio', 'Shared browser profile'); await clickControl('Save profile');
    await waitFor('document.querySelector(".android-profile-card h2").textContent === "Harsh Web"');
    await evaluate('document.querySelector(\'.profile-avatar-grid button[aria-label="Avatar 1"]\').click()');
    await clickControl('Save profile');
    await waitFor('document.querySelector(".settings-toast[role=status]")?.textContent === "Profile updated."');
    assert.match((await (await fetch(base + '/api/auth/session', { headers: { Cookie: cookies.join('; ') } })).json()).avatarId, /seed=Felix|avatar-1/);
    await evaluate('document.querySelector(\'.profile-avatar-grid button[aria-label="Initials"]\').click()');
    await clickControl('Save profile');
    await waitFor('document.querySelector(".settings-toast[role=status]")?.textContent === "Profile updated."');
    assert.equal((await (await fetch(base + '/api/auth/session', { headers: { Cookie: cookies.join('; ') } })).json()).avatarId, '');
    await clickText('Appearance'); await clickControl('Dark');
    await clickText('Sounds & Notifications');
    const darkSoundCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-sounds-dark.png'), Buffer.from(darkSoundCapture.data, 'base64'));
    await evaluate('document.querySelector(".notification-settings").scrollIntoView({block:"center"})');
    const darkNotificationsCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'notifications-dark.png'), Buffer.from(darkNotificationsCapture.data, 'base64'));
    await clickText('Profile');
    const profileCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-profile-dark.png'), Buffer.from(profileCapture.data, 'base64'));
    await clickText('Security & Privacy'); await selectSection('Stealth Mode');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false);
    const privacyCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'desktop-privacy-dark.png'), Buffer.from(privacyCapture.data, 'base64'));
    await clickText('Appearance'); await clickControl('Light');
    await clickText('Profile');
    await waitFor('document.querySelector(".profile-qr-card img")?.src.startsWith("data:image/png")');
    assert.ok(await evaluate('Boolean(document.querySelector(".profile-qr-card a[download]"))'));
    await clickText('Data & Storage');
    await waitFor('document.querySelector(".storage-dashboard")');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'storage dashboard has one sidebar');
    await waitFor('!document.querySelector(".storage-donut").textContent.includes("Checking storage")');
    const storageCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'storage-desktop.png'), Buffer.from(storageCapture.data, 'base64'));
    await evaluate('document.querySelector(".storage-sync-card button").click()');
    await waitFor('document.querySelector("dialog[open] #message-key-password")');
    assert.ok(await evaluate('document.querySelector("dialog[open]").matches(":modal")'), 'key transfer opens as a modal');
    const transferCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'storage-transfer-popup.png'), Buffer.from(transferCapture.data, 'base64'));
    await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
    await waitFor('!document.querySelector("dialog[open]")');
    await evaluate('localStorage.setItem("novyn_saved_messages_settingsuser", "[]"); localStorage.setItem("novyn_cache_test", "temporary");');
    await clickControl('Clear temporary files');
    await waitFor('document.querySelector(".settings-toast")?.textContent.includes("Temporary web files cleared")');
    assert.equal(await evaluate('localStorage.getItem("novyn_cache_test")'), null);
    assert.equal(await evaluate('localStorage.getItem("novyn_saved_messages_settingsuser")'), '[]');
    await clickControl('Download chat data');
    let chatExport;
    for (let attempt = 0; attempt < 100; attempt++) {
      try { chatExport = JSON.parse(await fs.readFile(path.join(directory, 'novyn-chat-data.json'), 'utf8')); break; }
      catch { await delay(50); }
    }
    assert.equal(chatExport.format, 'novyn-chat-export');
    assert.equal(chatExport.profile.username, 'settingsuser');
    assert.ok(chatExport.conversations.some(item => item.username === 'statuspeer'));
    await clickText('Help & Support');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'feedback has one sidebar');
    assert.equal(await evaluate('document.querySelectorAll(".feedback-faqs details").length'), 5);
    await evaluate('document.querySelector(".feedback-faqs summary").click()');
    assert.equal(await evaluate('document.querySelector(".feedback-faqs details").open'), true);
    await clickControl('Report a bug');
    await clickControl('General feedback');
    await field('Message', 'Disposable local browser settings test.'); await clickControl('Send feedback');
    await waitFor('document.querySelector(".settings-toast[role=status]")?.textContent === "Feedback sent."');
    assert.match(await fs.readFile(path.join(directory, 'data', 'feedback.log'), 'utf8'), /Disposable local browser settings test/);
    await evaluate("document.querySelector('button[aria-label=\"Chats\"]').click()");
    await waitFor('document.querySelector(".chat-list-item")');
    await evaluate('document.querySelector(".chat-list-item").click()');
    await waitFor('document.querySelector(".messages-container")');
    assert.match(await evaluate('getComputedStyle(document.querySelector(".chat-window")).backgroundImage'), /data:image\/svg\+xml/, 'saved wallpaper renders behind real chat messages');
    const chatWallpaperCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'chat-wallpaper.png'), Buffer.from(chatWallpaperCapture.data, 'base64'));
    await waitFor("document.querySelector('button[aria-label=\"Transfer message keys\"]')");
    await evaluate("document.querySelector('button[aria-label=\"Transfer message keys\"]').click()");
    await waitFor('document.querySelector("dialog[open] #message-key-password")');
    assert.equal(await evaluate('document.querySelector("#message-key-password").nextElementSibling.disabled'), true);
    await evaluate('{ const input = document.querySelector("#message-key-password"); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, "browser-test-transfer-password"); input.dispatchEvent(new Event("input", {bubbles:true})); }');
    await waitFor('!document.querySelector("#message-key-password").nextElementSibling.disabled');
    await evaluate('document.querySelector("#message-key-password").nextElementSibling.click()');
    await waitFor('document.querySelector("dialog[open] [role=status]")?.textContent.startsWith("Downloaded.")');
    let downloaded;
    for (let attempt = 0; attempt < 100; attempt++) {
      try { downloaded = JSON.parse(await fs.readFile(path.join(directory, 'novyn-message-keys.json'), 'utf8')); break; }
      catch { await delay(100); }
    }
    assert.equal(downloaded?.format, 'novyn-message-keys');
    assert.equal(downloaded?.username, undefined, 'account and conversation keys are inside the encrypted payload');
    await evaluate("document.querySelector('dialog[open] button[aria-label=\"Close\"]').click()");
    await evaluate("document.querySelector('button[aria-label=\"Settings\"]').click()");
    await waitFor("document.querySelector('.android-profile-card')");
    await clickText('Appearance');
    await call('Emulation.setDeviceMetricsOverride', { width: 900, height: 844, deviceScaleFactor: 1, mobile: false });
    await waitFor('document.querySelector(".appearance-dashboard")?.getClientRects().length > 0');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'tablet layout fits');
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    await waitFor("document.querySelector('[aria-label=\"Back to Settings\"]')");
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'mobile Appearance fits');
    const mobileAppearanceCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-appearance.png'), Buffer.from(mobileAppearanceCapture.data, 'base64'));
    await evaluate('document.querySelector(".font-select-trigger").scrollIntoView({block: "center"}); document.querySelector(".font-select-trigger").focus(); document.querySelector(".font-select-trigger").click()');
    await waitFor('document.querySelector(".font-select-menu")');
    assert.ok(await evaluate('{ const r = document.querySelector(".font-select-menu").getBoundingClientRect(); r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight; }'), 'font menu fits inside mobile viewport');
    await delay(200);
    const mobileFontMenuCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'font-dropdown-mobile.png'), Buffer.from(mobileFontMenuCapture.data, 'base64'));
    const fontOption = await evaluate('{ const r = document.querySelectorAll(".font-select-menu [role=option]")[3].getBoundingClientRect(); ({x:r.left+r.width/2, y:r.top+r.height/2}); }');
    await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: fontOption.x, y: fontOption.y }] });
    await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await waitFor('!document.querySelector(".font-select-menu")');
    assert.equal(await evaluate('localStorage.getItem("novyn_font_family")'), 'outfit', 'mobile tap selects a font');
    await evaluate('document.querySelector(".appearance-wallpaper-card").scrollIntoView({block: "start"})');
    await clickControl('Ocean Drift');
    await delay(200);
    assert.equal(await evaluate('localStorage.getItem("novyn_wallpaper")'), 'ocean');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'wallpaper grid fits on mobile');
    await evaluate('document.querySelector(".appearance-wallpaper-options button[aria-pressed=true]").scrollIntoView({block: "center"})');
    const mobileWallpapersCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-wallpapers.png'), Buffer.from(mobileWallpapersCapture.data, 'base64'));
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await waitFor("document.querySelector('.android-settings').getBoundingClientRect().width > 300");
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false);
    const { data } = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-settings.png'), Buffer.from(data, 'base64'));
    await clickText('Data & Storage');
    await waitFor('document.querySelector(".storage-dashboard")?.getClientRects().length > 0');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'storage dashboard fits mobile');
    const mobileStorageCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'storage-mobile.png'), Buffer.from(mobileStorageCapture.data, 'base64'));
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Language & Region');
    await waitFor('document.querySelector(".language-dashboard")?.getClientRects().length > 0');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'language cards fit mobile');
    assert.equal(await evaluate('document.querySelectorAll(".language-dashboard [role=combobox]")[1].textContent'), 'United Kingdom', 'regional selection persists across navigation');
    await evaluate('document.querySelector(".language-dashboard [role=combobox]").focus(); document.querySelector(".language-dashboard [role=combobox]").click()');
    await waitFor('document.querySelector(".font-select-menu")');
    assert.ok(await evaluate('{ const r = document.querySelector(".font-select-menu").getBoundingClientRect(); r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight; }'), 'language dropdown fits mobile');
    const languageMobileCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'language-mobile.png'), Buffer.from(languageMobileCapture.data, 'base64'));
    await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
    await waitFor('!document.querySelector(".font-select-menu")');
    await evaluate('document.querySelector(".region-globe").scrollIntoView({block:"center"})');
    assert.ok(await evaluate('{ const r = document.querySelector(".region-globe canvas").getBoundingClientRect(); r.left >= 0 && r.right <= innerWidth; }'), 'globe fits mobile');
    await delay(1200);
    const mobileGlobeCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'globe-mobile.png'), Buffer.from(mobileGlobeCapture.data, 'base64'));
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Sounds & Notifications');
    await waitFor('document.querySelector(".sound-dashboard")');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'sound cards fit mobile');
    const mobileSoundCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-sounds.png'), Buffer.from(mobileSoundCapture.data, 'base64'));
    await evaluate('document.querySelector(".sound-calls-card").scrollIntoView({block:"center"})');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'call preview fits mobile');
    const mobileCallPreview = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-call-preview.png'), Buffer.from(mobileCallPreview.data, 'base64'));
    await evaluate('document.querySelector(".notification-settings").scrollIntoView({block:"start"})');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'notification cards fit mobile');
    const mobileNotificationsCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'notifications-mobile.png'), Buffer.from(mobileNotificationsCapture.data, 'base64'));
    await evaluate('document.querySelector(\'button[aria-label="Play message sound"]\').click()');
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    assert.ok(await evaluate('window.__pausedAudio.at(-1).endsWith("chime-echo.wav")'), 'leaving sound settings stops its preview');
    assert.deepEqual(await evaluate('window.__vibrations'), [], 'web navigation never requests phone vibration');
    await clickText('Profile');
    await waitFor('document.querySelector(".profile-dashboard-grid")?.getClientRects().length > 0');
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false, 'mobile profile cards fit');
    await field('Display name', 'Mobile preview');
    assert.equal(await evaluate('document.querySelector(".profile-hero h2").textContent'), 'Mobile preview');
    await evaluate('document.querySelector(".settings-detail-body").scrollTop = 600');
    await delay(50);
    assert.ok(await evaluate('document.querySelector(".profile-dashboard-header button[type=submit]").getBoundingClientRect().top >= 0'), 'save action remains visible when mobile form scrolls');
    const toolbarCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'profile-toolbar-scrolled.png'), Buffer.from(toolbarCapture.data, 'base64'));
    await clickControl('Discard');
    await evaluate('document.querySelector(".settings-detail-body").scrollTop = 0');
    const mobileProfileCapture = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-profile.png'), Buffer.from(mobileProfileCapture.data, 'base64'));
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Appearance');
    await waitFor("document.querySelector('.settings-detail')?.getClientRects().length > 0");
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Security & Privacy');
    await selectSection('Change Password');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".settings-workspace")).flexDirection'), 'column');
    assert.equal(await evaluate('document.querySelector(".settings-section-nav")'), null, 'security uses one sidebar');
    await waitFor("document.querySelector('.security-phone details[open]')?.getClientRects().length > 0");
    assert.equal(await evaluate('document.documentElement.scrollWidth > innerWidth'), false);
    const mobileNotice = await call('Page.captureScreenshot', { format: 'png' });
    await fs.writeFile(path.join(directory, 'mobile-managed-setting.png'), Buffer.from(mobileNotice.data, 'base64'));
    await evaluate("document.querySelector('[aria-label=\"Back to Settings\"]').click()");
    await clickText('Log Out');
    await waitFor("document.querySelector('dialog[open]')");
    await evaluate("document.querySelector('.android-dialog-actions button').click()");
    assert.ok(await evaluate("document.querySelector('.android-profile-card') !== null"));
    assert.equal(errors.length, 0, JSON.stringify(errors));
    // The mobile password transport uses this existing shared-account protocol.
    setupSocket = await connect(cookies.join('; '));
    let changed = socketEvent(setupSocket, 'password_change_failed');
    setupSocket.emit('change_password', { currentPassword: 'wrong-password', newPassword: 'Updated-password-456!' });
    assert.match((await changed).message, /Incorrect password/i);
    changed = socketEvent(setupSocket, 'password_change_failed');
    setupSocket.emit('change_password', { currentPassword: 'Settings-test-password-123!', newPassword: 'short' });
    assert.match((await changed).message, /12 characters/i);
    changed = socketEvent(setupSocket, 'password_changed');
    setupSocket.emit('change_password', { currentPassword: 'Settings-test-password-123!', newPassword: 'Updated-password-456!' });
    await changed;
    for (const [password, expected] of [['Settings-test-password-123!', 401], ['Updated-password-456!', 200]]) {
      const response = await fetch(`${base}/api/auth/signin`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: 'settingsuser', password }) });
      assert.equal(response.status, expected, 'changed credentials apply to the shared account');
    }
    await clickText('Log Out');
    await waitFor('document.querySelector("dialog[open]")');
    await evaluate('document.querySelector(".android-dialog-actions .is-danger").click()');
    await waitFor('!document.querySelector(".android-profile-card")');
    console.log('Settings checks passed: browser preferences, notification privacy and mute, silent calls, confirmed presence and retention, block enforcement and reload, profile, QR, safe cache clearing, chat export, feedback, mobile-only security, key transfer and logout.');
    console.log('Screenshot:', path.join(directory, 'mobile-settings.png'));
  } finally {
    peer?.disconnect(); setupSocket?.disconnect();
    websocket?.close();
    chrome?.kill();
    server.kill();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
