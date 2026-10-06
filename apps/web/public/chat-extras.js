/* ─── Novyn Chat Extras ─────────────────────────────────────────────────────
   Handles: theme, logout, mobile panels, scroll FAB, char counter,
            snap typing, emoji reactions + server sync, reply UI, profile modal
   ─────────────────────────────────────────────────────────────────────────── */

/* ── Theme toggle ───────────────────────────────────────────────────────────── */
(function () {
  var root = document.documentElement;
  var btn = document.getElementById('themeToggle');
  var settingsMenu = document.getElementById('settingsMenu');
  var settingsPanel = document.getElementById('settingsPanel');
  var themeItems = settingsMenu
    ? settingsMenu.querySelectorAll('[data-settings-action="theme"][data-theme]')
    : [];
  var themePanelItems = settingsPanel
    ? settingsPanel.querySelectorAll('[data-settings-action="theme"][data-theme]')
    : [];
  var THEME_KEY = 'novyn-theme';
  var media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: light)') : null;
  var currentMode = 'dark';

  function readStoredTheme() {
    try {
      return localStorage.getItem(THEME_KEY);
    } catch (e) {
      return null;
    }
  }

  function storeTheme(mode) {
    try {
      localStorage.setItem(THEME_KEY, mode);
    } catch (e) {}
  }

  function resolveTheme(mode) {
    if (mode === 'system') {
      return media && media.matches ? 'light' : 'dark';
    }
    return mode;
  }

  function syncThemeItemState(item, isActive) {
    if (!item) return;
    item.setAttribute('aria-checked', isActive ? 'true' : 'false');
    if (item.classList) item.classList.toggle('active', isActive);
  }

  function updateMenuState() {
    if (themeItems && themeItems.length) {
      for (var i = 0; i < themeItems.length; i++) {
        var item = themeItems[i];
        var isActive = item && item.dataset.theme === currentMode;
        syncThemeItemState(item, isActive);
      }
    }
    if (themePanelItems && themePanelItems.length) {
      for (var j = 0; j < themePanelItems.length; j++) {
        var panelItem = themePanelItems[j];
        var panelActive = panelItem && panelItem.dataset.theme === currentMode;
        syncThemeItemState(panelItem, panelActive);
      }
    }
  }

  function syncNativeStatusBar(resolvedTheme) {
    try {
      var statusBar = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.StatusBar;
      if (!statusBar) return;
      var styleValue = statusBar.Style
        ? (resolvedTheme === 'light' ? statusBar.Style.Dark : statusBar.Style.Light)
        : (resolvedTheme === 'light' ? 'DARK' : 'LIGHT');
      if (typeof statusBar.setOverlaysWebView === 'function') {
        statusBar.setOverlaysWebView({ overlay: false });
      }
      if (typeof statusBar.setStyle === 'function') {
        statusBar.setStyle({ style: styleValue });
      }
      if (typeof statusBar.setBackgroundColor === 'function') {
        statusBar.setBackgroundColor({ color: resolvedTheme === 'light' ? '#F7F9FC' : '#0C0E14' });
      }
    } catch (e) {}
  }

  function applyTheme(mode) {
    currentMode = mode;
    var resolved = resolveTheme(mode);
    root.classList.toggle('light', resolved === 'light');
    if (btn) {
      btn.setAttribute('aria-pressed', resolved === 'light' ? 'true' : 'false');
    }
    updateMenuState();
    syncNativeStatusBar(resolved);
  }

  var savedTheme = readStoredTheme();
  if (savedTheme === 'light' || savedTheme === 'dark' || savedTheme === 'system') {
    applyTheme(savedTheme);
  } else {
    applyTheme('system');
  }

  if (media) {
    var mediaHandler = function () {
      if (currentMode === 'system') applyTheme('system');
    };
    if (typeof media.addEventListener === 'function') {
      media.addEventListener('change', mediaHandler);
    } else if (typeof media.addListener === 'function') {
      media.addListener(mediaHandler);
    }
  }

  function setTheme(mode) {
    if (mode !== 'light' && mode !== 'dark' && mode !== 'system') return;
    applyTheme(mode);
    storeTheme(mode);
  }

  function toggleTheme() {
    var resolved = resolveTheme(currentMode);
    var next = resolved === 'light' ? 'dark' : 'light';
    setTheme(next);
  }

  if (btn) {
    btn.addEventListener('click', function () {
      toggleTheme();
    });
  }

  window._novynToggleTheme = toggleTheme;
  window._novynSetTheme = setTheme;
  window._novynGetTheme = function () { return currentMode; };
  window._novynGetResolvedTheme = function () { return resolveTheme(currentMode); };
})();

/* ── Logout ─────────────────────────────────────────────────────────────────── */
(function () {
  var logoutPending = false;

  function clearLegacySessionStorage() {
    try { sessionStorage.removeItem('novyn-session'); } catch (e) {}
    try {
      localStorage.removeItem('novyn-session');
      localStorage.removeItem('novyn-remember');
    } catch (e) {}
  }

  function redirectToLogin() {
    window.location.replace('/login.html?logout=1');
  }

  function logoutAndRedirect() {
    if (logoutPending) return;
    logoutPending = true;
    if (typeof window._novynPrepareLogout === 'function') {
      try {
        window._novynPrepareLogout();
      } catch (e) {}
    }
    clearLegacySessionStorage();
    var fallbackTimer = setTimeout(function () {
      redirectToLogin();
    }, 1200);
    var csrfToken = '';
    try {
      var match = String(document.cookie || '').match(/(?:^|;\s*)novyn_csrf=([^;]+)/);
      csrfToken = match && match[1] ? decodeURIComponent(match[1]) : '';
    } catch (e) {}
    var logoutRequest = (window._novynAuth && typeof window._novynAuth.logout === 'function')
      ? window._novynAuth.logout()
      : fetch('/api/auth/logout', {
          method: 'POST',
          headers: csrfToken ? { 'x-novyn-csrf': csrfToken } : undefined,
          credentials: 'same-origin',
          cache: 'no-store',
          keepalive: true
        });
    Promise.resolve(logoutRequest)
      .catch(function () {})
      .finally(function () {
        clearTimeout(fallbackTimer);
        redirectToLogin();
      });
  }
  window._novynLogoutAndRedirect = logoutAndRedirect;
  var btn = document.getElementById('logoutBtn');
  if (!btn) return;
  btn.addEventListener('click', function () {
    logoutAndRedirect();
  });
})();

/* ─── Settings Menu + Account Actions ───────────────────────────────────────── */
(function () {
  var settingsBtn = document.getElementById('settingsBtn');
  var settingsMenu = document.getElementById('settingsMenu');
  var settingsPanel = document.getElementById('settingsPanel');
  if (!settingsBtn && !settingsMenu && !settingsPanel) return;

  var disableSettingsMenu = true;

  if (settingsBtn) {
    settingsBtn.disabled = true;
    settingsBtn.setAttribute('aria-disabled', 'true');
    settingsBtn.setAttribute('tabindex', '-1');
    settingsBtn.classList.add('is-disabled');
  }
  if (settingsMenu) settingsMenu.classList.add('hidden');



  var usernameModal = document.getElementById('usernameModal');
  var passwordModal = document.getElementById('passwordModal');
  var usernameCancel = document.getElementById('usernameCancel');
  var usernameSave = document.getElementById('usernameSave');
  var usernameCurrentPassword = document.getElementById('usernameCurrentPassword');
  var usernameNew = document.getElementById('usernameNew');
  var passwordCancel = document.getElementById('passwordCancel');
  var passwordSave = document.getElementById('passwordSave');
  var passwordCurrent = document.getElementById('passwordCurrent');
  var passwordNew = document.getElementById('passwordNew');
  var passwordConfirm = document.getElementById('passwordConfirm');
  var blockedSearchInput = document.getElementById('settingsBlockedSearch');
  var blockedList = document.getElementById('settingsBlockedList');
  var blockedCount = document.getElementById('settingsBlockedCount');
  var blockedConfirmModal = document.getElementById('blockedConfirmModal');
  var blockedConfirmDesc = document.getElementById('blockedConfirmDesc');
  var blockedConfirmCancel = document.getElementById('blockedConfirmCancel');
  var blockedConfirmOk = document.getElementById('blockedConfirmOk');

  var pendingUsername = false;
  var pendingPassword = false;
  var lastPasswordValue = '';
  var pendingUnblocks = Object.create(null);
  var blockedSearchQuery = '';
  var pendingUnblockUsername = '';
  var lastModalFocus = null;
  var modalTrapCleanup = null;

  function getFocusable(modal) {
    if (!modal) return [];
    var nodes = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
    return Array.prototype.slice.call(nodes).filter(function (el) {
      return !el.disabled && el.offsetParent !== null;
    });
  }

  function trapFocus(modal) {
    function onKey(e) {
      if (e.key !== 'Tab') return;
      var focusable = getFocusable(modal);
      if (!focusable.length) return;
      var first = focusable[0];
      var last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
    modal.addEventListener('keydown', onKey);
    return function () { modal.removeEventListener('keydown', onKey); };
  }

  function openModal(modal) {
    if (!modal) return;
    lastModalFocus = document.activeElement;
    modal.style.display = 'flex';
    if (modalTrapCleanup) modalTrapCleanup();
    modalTrapCleanup = trapFocus(modal);
    var focusable = getFocusable(modal);
    if (focusable.length) focusable[0].focus();
  }

  function closeModal(modal) {
    if (!modal) return;
    modal.style.display = 'none';
    if (modalTrapCleanup) {
      modalTrapCleanup();
      modalTrapCleanup = null;
    }
    if (lastModalFocus && typeof lastModalFocus.focus === 'function') {
      lastModalFocus.focus();
    }
    lastModalFocus = null;
  }

  function toast(msg, type) {
    if (window._novynToast) {
      window._novynToast(msg, type);
    } else {
      alert(msg);
    }
  }

  function openMenu() {
    if (!settingsMenu || !settingsBtn) return;
    settingsMenu.classList.remove('hidden');
    settingsBtn.setAttribute('aria-expanded', 'true');
  }
  function closeMenu() {
    if (!settingsMenu || !settingsBtn) return;
    settingsMenu.classList.add('hidden');
    settingsBtn.setAttribute('aria-expanded', 'false');
  }

  function openSettingsPanel() {
    if (window._novynOpenSettingsPanel) {
      window._novynOpenSettingsPanel();
      return true;
    }
    return false;
  }

  function closeSettingsPanel() {
    if (window._novynCloseSettingsPanel) {
      window._novynCloseSettingsPanel();
    }
  }

  function showModal(modal) {
    openModal(modal);
  }
  function hideModal(modal) {
    closeModal(modal);
  }

  function resetUsernameForm() {
    pendingUsername = false;
    if (usernameSave) usernameSave.disabled = false;
    if (usernameCurrentPassword) usernameCurrentPassword.value = '';
    if (usernameNew) usernameNew.value = '';
  }
  function resetPasswordForm() {
    pendingPassword = false;
    if (passwordSave) passwordSave.disabled = false;
    if (passwordCurrent) passwordCurrent.value = '';
    if (passwordNew) passwordNew.value = '';
    if (passwordConfirm) passwordConfirm.value = '';
    lastPasswordValue = '';
  }

  function normalizeUserKey(value) {
    return String(value || '').trim().toLowerCase();
  }

  function normalizeSearchQuery(value) {
    return String(value || '').trim().toLowerCase();
  }

  function getBlockedUsers() {
    if (typeof window._novynGetBlockedUsers !== 'function') return [];
    var users = window._novynGetBlockedUsers();
    return Array.isArray(users) ? users : [];
  }

  function prunePendingUnblocks(users) {
    var valid = Object.create(null);
    users.forEach(function (user) {
      var key = normalizeUserKey(user && user.username);
      if (key) valid[key] = true;
    });
    Object.keys(pendingUnblocks).forEach(function (key) {
      if (!valid[key]) delete pendingUnblocks[key];
    });
  }

  function renderBlockedUsers() {
    if (!blockedList) return;
    var users = getBlockedUsers();
    var query = normalizeSearchQuery(blockedSearchQuery);
    var visibleUsers = query
      ? users.filter(function (user) {
          var username = String((user && user.username) || '').toLowerCase();
          var displayName = String((user && user.displayName) || '').toLowerCase();
          return username.indexOf(query) !== -1 || displayName.indexOf(query) !== -1;
        })
      : users;
    prunePendingUnblocks(users);
    if (blockedCount) blockedCount.textContent = String(users.length);

    blockedList.innerHTML = '';
    if (!visibleUsers.length) {
      var empty = document.createElement('div');
      empty.className = 'settings-blocked-empty';
      empty.textContent = users.length ? ('No blocked users match "' + blockedSearchQuery + '".') : 'No blocked users.';
      blockedList.appendChild(empty);
      return;
    }

    visibleUsers.forEach(function (user) {
      var username = String((user && user.username) || '').trim();
      if (!username) return;
      var key = normalizeUserKey(username);
      var row = document.createElement('div');
      row.className = 'settings-blocked-item';
      row.setAttribute('role', 'listitem');

      var avatar = document.createElement('div');
      avatar.className = 'settings-blocked-avatar';
      var displayName = String((user && user.displayName) || username).trim() || username;
      var initials = displayName.slice(0, 2).toUpperCase();
      if (window._novynAvatarUtils && typeof window._novynAvatarUtils.applyAvatarToEl === 'function' && user.avatarId) {
        window._novynAvatarUtils.applyAvatarToEl(avatar, user.avatarId, initials);
      } else {
        avatar.textContent = initials;
      }

      var meta = document.createElement('div');
      meta.className = 'settings-blocked-meta';
      var name = document.createElement('div');
      name.className = 'settings-blocked-name';
      name.textContent = displayName;
      var handle = document.createElement('div');
      handle.className = 'settings-blocked-handle';
      handle.textContent = '@' + username;
      meta.appendChild(name);
      meta.appendChild(handle);

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'settings-unblock-btn';
      btn.dataset.blockedAction = 'unblock';
      btn.dataset.unblockUsername = username;
      btn.dataset.unblockDisplay = displayName;
      var isPending = Boolean(pendingUnblocks[key]);
      btn.disabled = isPending;
      btn.textContent = isPending ? 'Unblocking...' : 'Unblock';

      row.appendChild(avatar);
      row.appendChild(meta);
      row.appendChild(btn);
      blockedList.appendChild(row);
    });
  }

  function requestUnblock(username) {
    var value = String(username || '').trim();
    if (!value) return;
    if (!window._novynSocket) {
      toast('Realtime connection not available.', 'error');
      return;
    }
    pendingUnblocks[normalizeUserKey(value)] = true;
    renderBlockedUsers();
    window._novynSocket.emit('set_block', {
      username: value,
      blocked: false
    });
  }

  function showUnblockConfirm(username, displayName) {
    var value = String(username || '').trim();
    if (!value || !blockedConfirmModal) {
      requestUnblock(value);
      return;
    }
    pendingUnblockUsername = value;
    if (blockedConfirmDesc) {
      var name = String(displayName || value).trim() || value;
      blockedConfirmDesc.textContent = 'Unblock @' + value + ' (' + name + ')? You can block them again anytime from profile info.';
    }
    showModal(blockedConfirmModal);
  }

  function hideUnblockConfirm() {
    pendingUnblockUsername = '';
    hideModal(blockedConfirmModal);
  }

  function handleSettingsAction(actionBtn) {
    if (!actionBtn) return;
    var action = actionBtn.dataset.settingsAction;

    if (action === 'profile') {
      if (window._novynOpenProfileModal) {
        window._novynOpenProfileModal();
      } else {
        var openBtn = document.querySelector('[data-profile-open]') || document.getElementById('profileBtn');
        if (openBtn) openBtn.click();
      }
      return;
    }
    if (action === 'theme') {
      var mode = actionBtn.dataset.theme || '';
      if (mode && window._novynSetTheme) {
        window._novynSetTheme(mode);
      } else if (window._novynToggleTheme) {
        window._novynToggleTheme();
      }
      return;
    }
    if (action === 'username') {
      showModal(usernameModal);
      return;
    }
    if (action === 'password') {
      showModal(passwordModal);
      return;
    }
    if (action === 'blocked') {
      renderBlockedUsers();
      return;
    }
    if (action === 'logout') {
      if (typeof window._novynLogoutAndRedirect === 'function') {
        window._novynLogoutAndRedirect();
      }
    }
  }

  if (settingsBtn && !disableSettingsMenu) {
    settingsBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      if (!settingsMenu) return;
      settingsMenu.classList.contains('hidden') ? openMenu() : closeMenu();
    });
  }

  document.addEventListener('click', function (e) {
    if (disableSettingsMenu) return;
    if (!settingsMenu || !settingsBtn) return;
    if (!settingsMenu.contains(e.target) && !settingsBtn.contains(e.target)) {
      closeMenu();
    }
  });

  if (settingsMenu && !disableSettingsMenu) {
    settingsMenu.addEventListener('click', function (e) {
      var actionBtn = e.target.closest('[data-settings-action]');
      if (!actionBtn) return;
      closeMenu();
      handleSettingsAction(actionBtn);
    });
  }

  if (settingsPanel) {
    settingsPanel.addEventListener('click', function (e) {
      var unblockBtn = e.target.closest('[data-blocked-action="unblock"]');
      if (unblockBtn) {
        showUnblockConfirm(
          unblockBtn.dataset.unblockUsername || '',
          unblockBtn.dataset.unblockDisplay || ''
        );
        return;
      }
      var actionBtn = e.target.closest('[data-settings-action]');
      if (!actionBtn) return;
      handleSettingsAction(actionBtn);
      if (actionBtn.dataset.settingsAction !== 'theme') {
        closeSettingsPanel();
      }
    });
  }

  usernameCancel && usernameCancel.addEventListener('click', function () {
    hideModal(usernameModal);
    resetUsernameForm();
  });
  passwordCancel && passwordCancel.addEventListener('click', function () {
    hideModal(passwordModal);
    resetPasswordForm();
  });

  if (usernameModal) {
    var back = usernameModal.querySelector('.confirm-modal-backdrop');
    back && back.addEventListener('click', function () {
      hideModal(usernameModal);
      resetUsernameForm();
    });
  }
  if (passwordModal) {
    var back2 = passwordModal.querySelector('.confirm-modal-backdrop');
    back2 && back2.addEventListener('click', function () {
      hideModal(passwordModal);
      resetPasswordForm();
    });
  }
  if (blockedConfirmModal) {
    var back3 = blockedConfirmModal.querySelector('.confirm-modal-backdrop');
    back3 && back3.addEventListener('click', hideUnblockConfirm);
  }

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    if (blockedConfirmModal && blockedConfirmModal.style.display !== 'none') {
      hideUnblockConfirm();
    }
    if (usernameModal && usernameModal.style.display !== 'none') {
      hideModal(usernameModal);
      resetUsernameForm();
    }
    if (passwordModal && passwordModal.style.display !== 'none') {
      hideModal(passwordModal);
      resetPasswordForm();
    }
  });

  usernameSave && usernameSave.addEventListener('click', function () {
    if (pendingUsername) return;
    var current = usernameCurrentPassword ? usernameCurrentPassword.value : '';
    var next = usernameNew ? usernameNew.value.trim() : '';
    if (!current || !next) {
      toast('Enter your current password and a new username.', 'error');
      return;
    }
    if (!window._novynSocket) {
      toast('Realtime connection not available.', 'error');
      return;
    }
    pendingUsername = true;
    usernameSave.disabled = true;
    window._novynSocket.emit('change_username', {
      currentPassword: current,
      newUsername: next
    });
  });

  passwordSave && passwordSave.addEventListener('click', function () {
    if (pendingPassword) return;
    var current = passwordCurrent ? passwordCurrent.value : '';
    var next = passwordNew ? passwordNew.value : '';
    var confirm = passwordConfirm ? passwordConfirm.value : '';
    if (!current || !next || !confirm) {
      toast('Fill in all password fields.', 'error');
      return;
    }
    if (next.length < 4) {
      toast('Password must be at least 4 characters.', 'error');
      return;
    }
    if (next !== confirm) {
      toast('New passwords do not match.', 'error');
      return;
    }
    if (!window._novynSocket) {
      toast('Realtime connection not available.', 'error');
      return;
    }
    pendingPassword = true;
    passwordSave.disabled = true;
    lastPasswordValue = next;
    window._novynSocket.emit('change_password', {
      currentPassword: current,
      newPassword: next
    });
  });

  function bindSocketHandlers() {
    var socket = window._novynSocket;
    if (!socket || bindSocketHandlers._bound) return;
    bindSocketHandlers._bound = true;

    socket.on('username_changed', function () {
      hideModal(usernameModal);
      resetUsernameForm();
    });
    socket.on('password_changed', function () {
      if (lastPasswordValue && window._novynUpdateSession) {
        window._novynUpdateSession(null, lastPasswordValue);
      }
      hideModal(passwordModal);
      resetPasswordForm();
    });
    socket.on('username_change_failed', function (data) {
      pendingUsername = false;
      if (usernameSave) usernameSave.disabled = false;
      toast(data && data.message ? data.message : 'Could not update username.', 'error');
    });
    socket.on('password_change_failed', function (data) {
      pendingPassword = false;
      if (passwordSave) passwordSave.disabled = false;
      toast(data && data.message ? data.message : 'Could not update password.', 'error');
    });
    socket.on('block_updated', function (data) {
      var key = normalizeUserKey(data && data.username);
      if (key) delete pendingUnblocks[key];
      if (key && normalizeUserKey(pendingUnblockUsername) === key) {
        hideUnblockConfirm();
      }
      renderBlockedUsers();
    });
    socket.on('safety_state_updated', function () {
      renderBlockedUsers();
    });
    socket.on('friends_updated', function () {
      renderBlockedUsers();
    });
    socket.on('welcome', function () {
      pendingUnblocks = Object.create(null);
      renderBlockedUsers();
    });
  }
  bindSocketHandlers();

  if (settingsPanel && typeof MutationObserver === 'function') {
    var panelObserver = new MutationObserver(function () {
      if (document.body.classList.contains('settings-open')) {
        renderBlockedUsers();
      }
    });
    panelObserver.observe(document.body, { attributes: true, attributeFilter: ['class'] });
  }
  if (blockedSearchInput) {
    blockedSearchInput.addEventListener('input', function () {
      blockedSearchQuery = blockedSearchInput.value || '';
      renderBlockedUsers();
    });
  }
  blockedConfirmCancel && blockedConfirmCancel.addEventListener('click', hideUnblockConfirm);
  blockedConfirmOk && blockedConfirmOk.addEventListener('click', function () {
    if (!pendingUnblockUsername) return;
    requestUnblock(pendingUnblockUsername);
    hideUnblockConfirm();
  });
  renderBlockedUsers();
})();

/* ── Mobile panel switching ─────────────────────────────────────────────────── */
(function () {
  // Shared mobile breakpoints for panel behavior and theme optimizations.
  var BP      = 979;
  var THEME_BP = 979;
  var sidebar = document.getElementById('mobileSidebar');
  var chat    = document.getElementById('mobileChat');
  var backBtn = document.getElementById('mobBackBtn');
  var SWIPE_EDGE_PX = 28;
  var SWIPE_TRIGGER_PX = 74;
  var SWIPE_MAX_DRAG_PX = 280;
  var panelGesture = {
    active: false,
    mode: '',
    startX: 0,
    startY: 0,
    dragX: 0,
    locked: false,
    horizontal: false
  };
  function isMobile() { return window.innerWidth <= BP; }
  function isThemeMobile() { return window.innerWidth <= THEME_BP; }
  function isLowPower() {
    var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var lowMemory = typeof navigator !== 'undefined' && navigator.deviceMemory && navigator.deviceMemory <= 4;
    var saveData = typeof navigator !== 'undefined' && navigator.connection && navigator.connection.saveData;
    return !!(reduceMotion || lowMemory || saveData);
  }
  function syncMobileTheme() {
    document.body.classList.toggle('mobile-theme', isThemeMobile());
  }
  function syncMobilePerf() {
    document.body.classList.toggle('mobile-lite', isMobile() || isLowPower());
  }
  function replaceState(view) {
    if (!isMobile()) return;
    if (history.state && history.state.novynView === view) return;
    history.replaceState({ novynView: view }, '');
  }
  function pushState(view) {
    if (!isMobile()) return;
    if (history.state && history.state.novynView === view) return;
    history.pushState({ novynView: view }, '');
  }
  function clearGestureStyles() {
    document.body.classList.remove('panel-gesture-active');
    if (sidebar) sidebar.style.removeProperty('transform');
    if (chat) chat.style.removeProperty('transform');
  }
  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }
  function triggerPanelGestureHaptic() {
    try {
      var cap = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Haptics;
      if (cap && typeof cap.impact === 'function') {
        cap.impact({ style: 'light' });
        return;
      }
    } catch (e) {}
    if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
      navigator.vibrate(8);
    }
  }
  function setGestureTransforms(mode, deltaX) {
    if (!sidebar || !chat) return;
    var width = Math.max(window.innerWidth || 0, 1);
    document.body.classList.add('panel-gesture-active');
    if (mode === 'to-friends') {
      var drag = clamp(deltaX, 0, Math.min(width, SWIPE_MAX_DRAG_PX));
      var progress = clamp(drag / width, 0, 1);
      var sidebarShift = -100 + (progress * 100);
      chat.style.setProperty('transform', 'translateX(' + drag + 'px)', 'important');
      sidebar.style.setProperty('transform', 'translateX(' + sidebarShift + '%)', 'important');
      return;
    }
    if (mode === 'to-chat') {
      var dragLeft = clamp(deltaX, -Math.min(width, SWIPE_MAX_DRAG_PX), 0);
      var chatShift = width + dragLeft;
      var sidebarShiftPx = dragLeft * 0.34;
      chat.style.setProperty('transform', 'translateX(' + chatShift + 'px)', 'important');
      sidebar.style.setProperty('transform', 'translateX(' + sidebarShiftPx + 'px)', 'important');
    }
  }
  function resetPanelGesture() {
    panelGesture.active = false;
    panelGesture.mode = '';
    panelGesture.startX = 0;
    panelGesture.startY = 0;
    panelGesture.dragX = 0;
    panelGesture.locked = false;
    panelGesture.horizontal = false;
  }
  function finishPanelGesture(cancelled) {
    var mode = panelGesture.mode;
    var dragX = panelGesture.dragX;
    var shouldOpenFriends = mode === 'to-friends' && dragX >= SWIPE_TRIGGER_PX;
    var shouldOpenChat = mode === 'to-chat' && Math.abs(dragX) >= SWIPE_TRIGGER_PX;
    clearGestureStyles();
    resetPanelGesture();
    if (cancelled) return;
    if (shouldOpenFriends) {
      triggerPanelGestureHaptic();
      showPanel('friends');
      return;
    }
    if (shouldOpenChat) {
      triggerPanelGestureHaptic();
      showPanel('chat');
    }
  }
  function getPanelGestureMode(target, startX) {
    if (!isMobile()) return '';
    if (!sidebar || !chat) return '';
    if (document.body.classList.contains('settings-open')) return '';
    if (document.body.classList.contains('info-open')) return '';
    if (document.body.classList.contains('call-open')) return '';
    if (target && target.closest && target.closest('#scheduleMenu, #messageSearchPanel, .call-modal, .call-mini')) return '';
    if (document.body.classList.contains('mob-chat-open') && startX <= SWIPE_EDGE_PX) {
      return 'to-friends';
    }
    if (
      document.body.classList.contains('mob-list-open')
      && document.body.classList.contains('friend-selected')
      && startX >= (window.innerWidth - SWIPE_EDGE_PX)
    ) {
      return 'to-chat';
    }
    return '';
  }
  function onPanelTouchStart(e) {
    if (!e.touches || e.touches.length !== 1) return;
    var touch = e.touches[0];
    var mode = getPanelGestureMode(e.target, touch.clientX);
    if (!mode) return;
    panelGesture.active = true;
    panelGesture.mode = mode;
    panelGesture.startX = touch.clientX;
    panelGesture.startY = touch.clientY;
    panelGesture.dragX = 0;
    panelGesture.locked = false;
    panelGesture.horizontal = false;
  }
  function onPanelTouchMove(e) {
    if (!panelGesture.active) return;
    if (!e.touches || e.touches.length !== 1) return;
    var touch = e.touches[0];
    var deltaX = touch.clientX - panelGesture.startX;
    var deltaY = touch.clientY - panelGesture.startY;
    if (!panelGesture.locked) {
      if (Math.abs(deltaX) < 6 && Math.abs(deltaY) < 6) return;
      panelGesture.locked = true;
      panelGesture.horizontal = Math.abs(deltaX) > (Math.abs(deltaY) * 1.1);
      if (!panelGesture.horizontal) {
        finishPanelGesture(true);
        return;
      }
    }
    if (!panelGesture.horizontal) return;
    if (panelGesture.mode === 'to-friends' && deltaX < 0) deltaX = 0;
    if (panelGesture.mode === 'to-chat' && deltaX > 0) deltaX = 0;
    panelGesture.dragX = deltaX;
    setGestureTransforms(panelGesture.mode, deltaX);
    e.preventDefault();
  }
  function showPanel(panel, opts) {
    if (!sidebar || !chat) return;
    clearGestureStyles();
    var silent = opts && opts.silent;
    if (panel === 'chat') {
      sidebar.setAttribute('data-mob-hidden', 'true');
      chat.removeAttribute('data-mob-hidden');
      document.body.classList.add('mob-chat-open');
      document.body.classList.remove('mob-list-open');
      if (backBtn) backBtn.setAttribute('data-visible', 'true');
      if (!silent) pushState('chat');
    } else {
      chat.setAttribute('data-mob-hidden', 'true');
      sidebar.removeAttribute('data-mob-hidden');
      document.body.classList.remove('mob-chat-open');
      document.body.classList.add('mob-list-open');
      if (backBtn) backBtn.removeAttribute('data-visible');
      if (!silent) replaceState('friends');
    }
  }
  window._novynPanels = {
    show: showPanel,
    isMobile: isMobile
  };
  document.addEventListener('click', function (e) {
    if (!isMobile()) return;
    if (e.target.closest('.friend-btn')) showPanel('chat');
  });
  document.addEventListener('touchstart', onPanelTouchStart, { passive: true });
  document.addEventListener('touchmove', onPanelTouchMove, { passive: false });
  document.addEventListener('touchend', function () {
    if (!panelGesture.active) return;
    finishPanelGesture(false);
  }, { passive: true });
  document.addEventListener('touchcancel', function () {
    if (!panelGesture.active) return;
    finishPanelGesture(true);
  }, { passive: true });
  backBtn && backBtn.addEventListener('click', function () {
    if (isMobile()) showPanel('friends');
  });
  window.addEventListener('popstate', function (e) {
    if (!isMobile()) return;
    var view = e.state && e.state.novynView;
    if (view === 'chat') {
      showPanel('chat', { silent: true });
      return;
    }
    showPanel('friends', { silent: true });
    document.body.classList.remove('info-open');
  });
  (function bindNativeBack() {
    var cap = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.App;
    if (!cap || !cap.addListener) return;
    cap.addListener('backButton', function (data) {
      if (document.body.classList.contains('info-open')) {
        document.body.classList.remove('info-open');
        return;
      }
      if (isMobile() && document.body.classList.contains('mob-chat-open')) {
        showPanel('friends', { silent: true });
        return;
      }
      if (data && data.canGoBack) {
        window.history.back();
      } else if (cap.exitApp) {
        cap.exitApp();
      }
    });
  })();
  window.addEventListener('resize', function () {
    if (!isMobile()) {
      clearGestureStyles();
      resetPanelGesture();
      if (sidebar) sidebar.removeAttribute('data-mob-hidden');
      if (chat)    chat.removeAttribute('data-mob-hidden');
      document.body.classList.remove('mob-chat-open');
      document.body.classList.remove('mob-list-open');
    }
    syncMobileTheme();
    syncMobilePerf();
  });
  if (isMobile()) {
    document.body.classList.add('mob-list-open');
    replaceState('friends');
    showPanel('friends', { silent: true });
  }
  syncMobileTheme();
  syncMobilePerf();
  new MutationObserver(function () {
    var layout = document.getElementById('chatLayout');
    if (layout && !layout.classList.contains('hidden') && isMobile()) showPanel('friends');
  }).observe(document.getElementById('chatLayout') || document.body, { attributes: true, attributeFilter: ['class'] });
})();

/* ── Info panel toggle (chat header) ───────────────────────────── */
/* Pull to refresh (messages) */
(function () {
  var wrap = document.querySelector('.messages-wrap');
  var messages = document.getElementById('messages');
  if (!wrap || !messages) return;

  var MAX_PULL_PX = 112;
  var TRIGGER_PX = 74;
  var active = false;
  var refreshing = false;
  var startX = 0;
  var startY = 0;
  var pullOffset = 0;
  var lockSet = false;
  var verticalGesture = false;

  var indicator = document.createElement('div');
  indicator.id = 'pullRefreshIndicator';
  indicator.className = 'pull-refresh-indicator';
  indicator.setAttribute('aria-hidden', 'true');
  indicator.innerHTML = '<span class="pull-refresh-icon" aria-hidden="true"></span><span class="pull-refresh-label">Pull to refresh</span>';
  wrap.appendChild(indicator);
  var label = indicator.querySelector('.pull-refresh-label');

  function isMobileView() {
    if (window._novynPanels && typeof window._novynPanels.isMobile === 'function') {
      return window._novynPanels.isMobile();
    }
    return window.innerWidth <= 979;
  }

  function setPullOffset(px) {
    wrap.style.setProperty('--pull-refresh-offset', Math.max(0, Math.round(px)) + 'px');
  }

  function resetPullVisual() {
    wrap.classList.remove('pull-refresh-active', 'pull-refresh-ready', 'pull-refresh-refreshing');
    setPullOffset(0);
    if (label) label.textContent = 'Pull to refresh';
  }

  function triggerRefreshHaptic() {
    try {
      var capHaptics = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Haptics;
      if (capHaptics && typeof capHaptics.impact === 'function') {
        capHaptics.impact({ style: 'medium' });
        return;
      }
    } catch (e) {}
    if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
      navigator.vibrate(12);
    }
  }

  function canStartPull(target) {
    if (!isMobileView()) return false;
    if (refreshing) return false;
    if (!document.body.classList.contains('mob-chat-open')) return false;
    if (!window._novynActiveFriend || !window._novynActiveFriend()) return false;
    if (messages.scrollTop > 0) return false;
    if (!(target instanceof Element)) return true;
    if (target.closest('.message-context-menu, .reaction-picker')) return false;
    if (target.closest('.image-viewer-modal, .file-viewer-modal, .thread-modal')) return false;
    return true;
  }

  function clearPullState() {
    active = false;
    startX = 0;
    startY = 0;
    pullOffset = 0;
    lockSet = false;
    verticalGesture = false;
  }

  function cancelPull() {
    clearPullState();
    if (!refreshing) resetPullVisual();
  }

  function requestActiveRefresh() {
    if (refreshing) return;
    refreshing = true;
    wrap.classList.remove('pull-refresh-ready');
    wrap.classList.add('pull-refresh-active', 'pull-refresh-refreshing');
    setPullOffset(TRIGGER_PX - 8);
    if (label) label.textContent = 'Refreshing...';

    var requested = false;
    if (typeof window._novynRequestHistoryRefresh === 'function') {
      requested = Boolean(window._novynRequestHistoryRefresh());
    } else if (window._novynSocket && window._novynActiveFriend) {
      var friend = window._novynActiveFriend();
      var kind = window._novynActiveChatKind ? window._novynActiveChatKind() : 'friend';
      if (friend) {
        window._novynSocket.emit('get_history', { to: friend, toType: kind || 'friend' });
        requested = true;
      }
    }
    if (!requested) {
      refreshing = false;
      resetPullVisual();
      return;
    }

    triggerRefreshHaptic();
    setTimeout(function () {
      refreshing = false;
      resetPullVisual();
    }, 900);
  }

  wrap.addEventListener('touchstart', function (e) {
    if (!e.touches || e.touches.length !== 1) return;
    if (!canStartPull(e.target)) return;
    var t = e.touches[0];
    active = true;
    startX = t.clientX;
    startY = t.clientY;
    pullOffset = 0;
    lockSet = false;
    verticalGesture = false;
  }, { passive: true });

  wrap.addEventListener('touchmove', function (e) {
    if (!active || refreshing) return;
    if (!e.touches || e.touches.length !== 1) return;

    var t = e.touches[0];
    var dx = t.clientX - startX;
    var dy = t.clientY - startY;

    if (!lockSet) {
      if (Math.abs(dx) < 4 && Math.abs(dy) < 4) return;
      lockSet = true;
      verticalGesture = Math.abs(dy) > (Math.abs(dx) * 1.05);
      if (!verticalGesture) {
        cancelPull();
        return;
      }
    }

    if (!verticalGesture || dy <= 0) {
      cancelPull();
      return;
    }
    if (messages.scrollTop > 0) {
      cancelPull();
      return;
    }

    e.preventDefault();
    pullOffset = Math.min(MAX_PULL_PX, dy * 0.52);
    wrap.classList.add('pull-refresh-active');
    setPullOffset(pullOffset);
    var ready = pullOffset >= TRIGGER_PX;
    wrap.classList.toggle('pull-refresh-ready', ready);
    if (label) label.textContent = ready ? 'Release to refresh' : 'Pull to refresh';
  }, { passive: false });

  wrap.addEventListener('touchend', function () {
    if (!active || refreshing) return;
    var shouldRefresh = pullOffset >= TRIGGER_PX;
    clearPullState();
    if (shouldRefresh) {
      requestActiveRefresh();
      return;
    }
    resetPullVisual();
  }, { passive: true });

  wrap.addEventListener('touchcancel', function () {
    if (!active || refreshing) return;
    cancelPull();
  }, { passive: true });
})();
(function () {
  var infoPanel = document.getElementById('infoPanel');
  var scrim = document.getElementById('infoScrim');
  var toggleBtn = document.getElementById('infoToggleBtn');
  var closeBtn = document.getElementById('infoCloseBtn');
  if (!infoPanel || !toggleBtn) return;

  function resetInfoScroll() {
    var inner = infoPanel.querySelector('.info-inner');
    if (!inner) return;
    inner.scrollTop = 0;
    if (inner.scrollTo) inner.scrollTo({ top: 0, behavior: 'auto' });
    infoPanel.scrollTop = 0;
    requestAnimationFrame(function () {
      inner.scrollTop = 0;
      if (inner.scrollTo) inner.scrollTo({ top: 0, behavior: 'auto' });
    });
    setTimeout(function () {
      inner.scrollTop = 0;
      if (inner.scrollTo) inner.scrollTo({ top: 0, behavior: 'auto' });
    }, 350);
  }

  var lastInfoOpen = document.body.classList.contains('info-open');
  if (lastInfoOpen) resetInfoScroll();
  var infoObserver = new MutationObserver(function () {
    var nowOpen = document.body.classList.contains('info-open');
    if (nowOpen && !lastInfoOpen) resetInfoScroll();
    lastInfoOpen = nowOpen;
  });
  infoObserver.observe(document.body, { attributes: true, attributeFilter: ['class'] });

  function canOpenInfo() {
    return document.body.classList.contains('friend-selected');
  }
  function openPanel() {
    if (!canOpenInfo()) return;
    document.body.classList.add('info-open');
    toggleBtn.setAttribute('aria-expanded', 'true');
    resetInfoScroll();
  }
  function closePanel() {
    document.body.classList.remove('info-open');
    toggleBtn.setAttribute('aria-expanded', 'false');
  }
  function togglePanel() {
    if (!canOpenInfo()) return;
    document.body.classList.toggle('info-open');
    var isOpen = document.body.classList.contains('info-open');
    toggleBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    if (isOpen) {
      resetInfoScroll();
    }
  }

  toggleBtn.addEventListener('click', function (e) {
    e.preventDefault();
    togglePanel();
  });
  scrim && scrim.addEventListener('click', closePanel);
  closeBtn && closeBtn.addEventListener('click', closePanel);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') closePanel();
  });
  closePanel();
})();

/* ── Scroll-to-bottom FAB ───────────────────────────────────────────────────── */
(function () {
  var messagesEl = document.getElementById('messages');
  var scrollBtn  = document.getElementById('scrollBtn');
  var badge      = document.getElementById('scrollBadge');
  var unread     = 0;
  function hasNewerWindow() {
    return window._novynMessageWindow &&
      typeof window._novynMessageWindow.hasNewer === 'function' &&
      window._novynMessageWindow.hasNewer();
  }
  function atBottom() {
    if (!messagesEl) return true;
    return messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight <= 150;
  }
  function checkFAB() {
    if (!scrollBtn) return;
    var show = !atBottom() || hasNewerWindow();
    scrollBtn.classList.toggle('visible', show);
    scrollBtn.classList.toggle('hidden', !show);
    if (atBottom() && !hasNewerWindow()) {
      unread = 0;
      if (badge) { badge.textContent = ''; badge.classList.add('hidden'); }
    }
  }
  messagesEl && messagesEl.addEventListener('scroll', checkFAB, { passive: true });
  scrollBtn && scrollBtn.addEventListener('click', function () {
    if (hasNewerWindow() && window._novynMessageWindow.showLatest) {
      window._novynMessageWindow.showLatest();
    }
    if (messagesEl) {
      setTimeout(function () {
        messagesEl.scrollTo({ top: messagesEl.scrollHeight, behavior: 'smooth' });
      }, 0);
    }
    unread = 0;
    if (badge) { badge.textContent = ''; badge.classList.add('hidden'); }
    checkFAB();
  });
  window._novynFAB = {
    bump: function () {
      if (!atBottom()) {
        unread++;
        if (badge) { badge.textContent = unread > 9 ? '9+' : String(unread); badge.classList.remove('hidden'); }
      }
      checkFAB();
    },
    reset: function () {
      unread = 0;
      if (badge) { badge.textContent = ''; badge.classList.add('hidden'); }
      checkFAB();
    }
  };
})();

/* ── Character counter ──────────────────────────────────────────────────────── */
(function () {
  var input   = document.getElementById('messageInput');
  var counter = document.getElementById('charCounter');
  var maxAttr = Number(input && input.maxLength);
  var MAX = Number.isFinite(maxAttr) && maxAttr > 0 ? Math.floor(maxAttr) : 1000;
  var WARN = Math.floor(MAX * 0.8);
  var SHOW_AT = WARN;
  if (!input || !counter) return;
  input.addEventListener('input', function () {
    var len = input.value.length;
    if (len < SHOW_AT) { counter.classList.add('hidden'); return; }
    counter.classList.remove('hidden', 'warn', 'limit');
    counter.textContent = len + '/' + MAX;
    if (len >= MAX) counter.classList.add('limit');
    else if (len >= WARN) counter.classList.add('warn');
  });
  input.dispatchEvent(new Event('input', { bubbles: true }));
})();

/* ── Composer emoji picker ─────────────────────────────────────────────────── */
(function () {
  var form = document.getElementById('messageForm');
  var input = document.getElementById('messageInput');
  if (!form || !input) return;

  var emojiBtn = form.querySelector('.tool-btn[aria-label="Emoji"]');
  if (!emojiBtn) return;

  var EMOJIS = [
    "\u{1F600}", "\u{1F603}", "\u{1F604}", "\u{1F601}", "\u{1F606}", "\u{1F60D}",
    "\u{1F618}", "\u{1F61C}", "\u{1F923}", "\u{1F602}", "\u{1F622}", "\u{1F62D}",
    "\u{1F389}", "\u{1F525}", "\u{1F44D}", "\u{1F44F}", "\u{1F64C}", "\u{1F680}",
    "\u2764\uFE0F", "\u{1F48E}", "\u{1F31F}", "\u{1F4AF}", "\u{1F381}", "\u{1F60E}"
  ];

  var picker = null;

  function insertEmoji(emoji) {
    var start = input.selectionStart;
    var end = input.selectionEnd;
    if (typeof start !== 'number' || typeof end !== 'number') {
      start = input.value.length;
      end = input.value.length;
    }
    var max = Number(input.maxLength);
    if (!Number.isFinite(max) || max <= 0) max = Infinity;
    var nextLen = input.value.length - (end - start) + emoji.length;
    if (nextLen > max) return;

    var before = input.value.slice(0, start);
    var after = input.value.slice(end);
    input.value = before + emoji + after;
    var cursor = start + emoji.length;
    if (input.setSelectionRange) input.setSelectionRange(cursor, cursor);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.focus();
  }

  function closePicker() {
    if (!picker) return;
    picker.remove();
    picker = null;
    emojiBtn.setAttribute('aria-expanded', 'false');
  }

  function positionPicker() {
    if (!picker) return;
    var rect = emojiBtn.getBoundingClientRect();
    var pickerRect = picker.getBoundingClientRect();
    var margin = 8;
    var left = rect.left;
    var top = rect.top - pickerRect.height - 8;
    if (top < margin) top = rect.bottom + 8;
    if (left + pickerRect.width > window.innerWidth - margin) {
      left = window.innerWidth - pickerRect.width - margin;
    }
    if (left < margin) left = margin;
    picker.style.left = left + 'px';
    picker.style.top = top + 'px';
  }

  function openPicker() {
    closePicker();
    picker = document.createElement('div');
    picker.className = 'emoji-picker';
    picker.setAttribute('role', 'dialog');
    picker.setAttribute('aria-label', 'Emoji picker');

    EMOJIS.forEach(function (emoji) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = emoji;
      btn.title = emoji;
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        insertEmoji(emoji);
        closePicker();
      });
      picker.appendChild(btn);
    });

    picker.style.position = 'fixed';
    picker.style.zIndex = '9999';
    document.body.appendChild(picker);
    emojiBtn.setAttribute('aria-expanded', 'true');
    requestAnimationFrame(positionPicker);
  }

  emojiBtn.setAttribute('aria-expanded', 'false');
  emojiBtn.addEventListener('click', function (e) {
    e.preventDefault();
    e.stopPropagation();
    if (picker) { closePicker(); return; }
    openPicker();
  });

  form.addEventListener('submit', closePicker);
  document.addEventListener('click', function (e) {
    if (!picker) return;
    if (emojiBtn.contains(e.target) || picker.contains(e.target)) return;
    closePicker();
  });
  window.addEventListener('resize', closePicker);
  window.addEventListener('scroll', closePicker, true);
})();

/* ── Emoji Reactions + Reply button ─────────────────────────────────────────── */
(function () {
    var EMOJIS     = [
    "\u{1F44D}", "\u2764\uFE0F", "\u{1F602}", "\u{1F62E}", "\u{1F622}", "\u{1F525}",
    "\u{1F44F}", "\u{1F60D}", "\u{1F61C}", "\u{1F914}", "\u{1F389}", "\u{1F44C}",
    "\u{1F44E}", "\u{1F64C}", "\u{1F92F}", "\u{1F680}", "\u{1F3AF}", "\u{1F31F}",
    "\u{1F4AF}", "\u{1F937}", "\u{1F60E}", "\u{1F49A}", "\u{1F49B}", "\u{1F499}"
  ];
  var messagesEl = document.getElementById('messages');
  if (!messagesEl) return;

  var reactionStore    = {};
  var activePickerMsgEl = null;

  function getStore(id) {
    if (!reactionStore[id]) reactionStore[id] = {};
    return reactionStore[id];
  }

  function normalizePayloadReactions(raw) {
    var meKey = '';
    if (window._novynMe) {
      meKey = String(window._novynMe() || '').trim().toLowerCase();
    }
    var input = raw && typeof raw === 'object' ? raw : {};
    var normalized = {};
    Object.keys(input).forEach(function (emoji) {
      var entry = input[emoji];
      if (!entry || typeof entry !== 'object') return;

      var count = 0;
      var mine = false;

      if (Array.isArray(entry.userKeys)) {
        count = Number.isFinite(Number(entry.count))
          ? Math.max(0, Math.floor(Number(entry.count)))
          : entry.userKeys.length;
        mine = entry.userKeys.some(function (userKey) {
          return String(userKey || '').trim().toLowerCase() === meKey;
        });
      } else {
        count = Number.isFinite(Number(entry.count))
          ? Math.max(0, Math.floor(Number(entry.count)))
          : 0;
        mine = Boolean(entry.mine);
      }

      if (count > 0) {
        normalized[emoji] = { count: count, mine: mine };
      }
    });
    return normalized;
  }

  function closePicker() {
    var open = document.querySelector('.reaction-picker');
    if (open) open.remove();
    activePickerMsgEl = null;
  }

  document.addEventListener('click', function (e) {
    if (!e.target.closest('.reaction-picker') && !e.target.closest('.msg-action-btn')) {
      closePicker();
    }
  });

  function renderReactions(msgEl, msgId) {
    var wrap = msgEl.querySelector('.message-reactions');
    if (!wrap) return;
    wrap.innerHTML = '';
    var store = getStore(msgId);
    Object.keys(store).forEach(function (emoji) {
      var entry = store[emoji];
      if (!entry || entry.count <= 0) return;
      var btn = document.createElement('button');
      btn.className = 'reaction-btn' + (entry.mine ? ' mine' : '');
      btn.dataset.emoji = emoji;
      btn.innerHTML = emoji + '<span class="r-count">' + entry.count + '</span>';
      btn.addEventListener('click', function () { sendReaction(msgEl, msgId, emoji); });
      wrap.appendChild(btn);
    });
  }

  function sendReaction(msgEl, msgId, emoji) {
    var toUser = msgEl.dataset.messageFrom;
    if (window._novynMe && window._novynMe() && toUser === window._novynMe()) {
      toUser = window._novynActiveFriend && window._novynActiveFriend();
    }
    if (!toUser) return;

    // Optimistic update
    var store = getStore(msgId);
    if (!store[emoji]) store[emoji] = { count: 0, mine: false };
    if (store[emoji].mine) {
      store[emoji].count = Math.max(0, store[emoji].count - 1);
      store[emoji].mine  = false;
    } else {
      store[emoji].count++;
      store[emoji].mine = true;
    }
    renderReactions(msgEl, msgId);
    closePicker();

    if (window._novynSocket) {
      window._novynSocket.emit('react', { messageId: msgId, emoji: emoji, to: toUser });
    }
  }

  function applyServerReactions(msgId, reactions) {
    reactionStore[msgId] = normalizePayloadReactions(reactions);
    var msgEl = messagesEl.querySelector('[data-message-id="' + msgId + '"]');
    if (msgEl) renderReactions(msgEl, msgId);
  }

  function addActionsUI(msgEl) {
    if (msgEl.classList.contains('message-deleted')) return;
    var msgId = msgEl.dataset.messageId || ('tmp-' + Date.now() + '-' + Math.random());
    if (!msgEl.dataset.messageId) msgEl.dataset.messageId = msgId;
    if ((!reactionStore[msgId] || !Object.keys(reactionStore[msgId]).length) && msgEl.dataset.messageReactions) {
      try {
        reactionStore[msgId] = normalizePayloadReactions(JSON.parse(msgEl.dataset.messageReactions));
      } catch (e) {}
    }

    var actions = document.createElement('div');
    actions.className = 'msg-actions';

    // Reply button
    var replyBtn = document.createElement('button');
    replyBtn.className = 'msg-action-btn';
    replyBtn.dataset.msgAction = 'reply';
    replyBtn.title     = 'Reply';
    replyBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 17 4 12 9 7"/><path d="M20 18v-2a4 4 0 0 0-4-4H4"/></svg>';
    replyBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      if (window._novynReply) {
        window._novynReply.setReply({
          id: msgEl.dataset.messageId,
          from: msgEl.dataset.messageFrom || '',
          text: msgEl.dataset.messageText || '',
        });
      }
    });

    // Emoji button
    var emojiBtn = document.createElement('button');
    emojiBtn.className = 'msg-action-btn';
    emojiBtn.dataset.msgAction = 'react';
    emojiBtn.title     = 'React';
    emojiBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>';
    emojiBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      if (activePickerMsgEl === msgEl) { closePicker(); return; }
      closePicker();
      activePickerMsgEl = msgEl;

      var picker = document.createElement('div');
      picker.className = 'reaction-picker';
      var expanded = false;
      function renderPickerEmojiButtons() {
        picker.innerHTML = '';
        var visible = expanded ? EMOJIS : EMOJIS.slice(0, 10);
        visible.forEach(function (emoji) {
          var b = document.createElement('button');
          b.textContent = emoji;
          b.title = emoji;
          b.addEventListener('click', function (ev) {
            ev.stopPropagation();
            sendReaction(msgEl, msgId, emoji);
          });
          picker.appendChild(b);
        });
        if (!expanded && EMOJIS.length > 10) {
          var moreBtn = document.createElement('button');
          moreBtn.className = 'reaction-picker-more';
          moreBtn.textContent = '+';
          moreBtn.title = 'More reactions';
          moreBtn.addEventListener('click', function (ev) {
            ev.stopPropagation();
            expanded = true;
            renderPickerEmojiButtons();
          });
          picker.appendChild(moreBtn);
        }
      }
      renderPickerEmojiButtons();

      picker.style.position = 'fixed';
      picker.style.left = '0';
      picker.style.top = '0';
      picker.style.zIndex = '9999';
      document.body.appendChild(picker);

      var rect = emojiBtn.getBoundingClientRect();
      var pickerRect = picker.getBoundingClientRect();
      var margin = 8;
      var left = rect.left;
      if (left + pickerRect.width > window.innerWidth - margin) {
        left = window.innerWidth - pickerRect.width - margin;
      }
      if (left < margin) left = margin;

      var top = rect.top - pickerRect.height - 8;
      if (top < margin) top = rect.bottom + 8;
      if (top + pickerRect.height > window.innerHeight - margin) {
        top = Math.max(margin, window.innerHeight - pickerRect.height - margin);
      }

      picker.style.left = left + 'px';
      picker.style.top = top + 'px';
    });

    actions.append(replyBtn, emojiBtn);
    msgEl.appendChild(actions);

    var reactWrap = document.createElement('div');
    reactWrap.className = 'message-reactions';
    msgEl.appendChild(reactWrap);

    renderReactions(msgEl, msgId);
  }

  var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (m) {
      m.addedNodes.forEach(function (node) {
        if (node.nodeType === 1 && node.tagName === 'ARTICLE' && node.classList.contains('message')) {
          addActionsUI(node);
        }
      });
    });
  });
  observer.observe(messagesEl, { childList: true });

  window._novynReactions = {
    store: reactionStore,
    applyServerReactions: applyServerReactions,
  };
})();

/* ── Profile Modal ──────────────────────────────────────────────────────────── */
(function () {
  var AVATARS = [
    { id: 'av-ghost',     bg: 'linear-gradient(135deg,#667eea,#764ba2)', emoji: '👻' },
    { id: 'av-alien',     bg: 'linear-gradient(135deg,#11998e,#38ef7d)', emoji: '👽' },
    { id: 'av-robot',     bg: 'linear-gradient(135deg,#fc4a1a,#f7b733)', emoji: '🤖' },
    { id: 'av-cat',       bg: 'linear-gradient(135deg,#f953c6,#b91d73)', emoji: '🐱' },
    { id: 'av-fox',       bg: 'linear-gradient(135deg,#f7971e,#ffd200)', emoji: '🦊' },
    { id: 'av-bear',      bg: 'linear-gradient(135deg,#8B5E3C,#d4a96a)', emoji: '🐻' },
    { id: 'av-panda',     bg: 'linear-gradient(135deg,#2c3e50,#bdc3c7)', emoji: '🐼' },
    { id: 'av-wolf',      bg: 'linear-gradient(135deg,#4b6cb7,#182848)', emoji: '🐺' },
    { id: 'av-dragon',    bg: 'linear-gradient(135deg,#00c6ff,#0072ff)', emoji: '🐲' },
    { id: 'av-ninja',     bg: 'linear-gradient(135deg,#1a1a2e,#16213e)', emoji: '🥷' },
    { id: 'av-wizard',    bg: 'linear-gradient(135deg,#6a11cb,#2575fc)', emoji: '🧙' },
    { id: 'av-astronaut', bg: 'linear-gradient(135deg,#0f0c29,#302b63)', emoji: '👨‍🚀' },
    { id: 'av-angel',     bg: 'linear-gradient(135deg,#f0c27f,#fc67fa)', emoji: '😇' },
    { id: 'av-demon',     bg: 'linear-gradient(135deg,#870000,#190a05)', emoji: '😈' },
    { id: 'av-cool',      bg: 'linear-gradient(135deg,#00b09b,#96c93d)', emoji: '😎' },
    { id: 'av-fire',      bg: 'linear-gradient(135deg,#f12711,#f5af19)', emoji: '🔥' },
    { id: 'av-snow',      bg: 'linear-gradient(135deg,#a1c4fd,#c2e9fb)', emoji: '❄️' },
    { id: 'av-star',      bg: 'linear-gradient(135deg,#f7971e,#ffd200)', emoji: '⭐' },
    { id: 'av-diamond',   bg: 'linear-gradient(135deg,#00c6ff,#0072ff)', emoji: '💎' },
    { id: 'av-crown',     bg: 'linear-gradient(135deg,#f7971e,#ffd200)', emoji: '👑' },
    { id: 'av-skull',     bg: 'linear-gradient(135deg,#232526,#414345)', emoji: '💀' },
    { id: 'av-clown',     bg: 'linear-gradient(135deg,#fc4a1a,#f7b733)', emoji: '🤡' },
    { id: 'av-sunflower', bg: 'linear-gradient(135deg,#f9d423,#ff4e50)', emoji: '🌻' },
    { id: 'av-planet',    bg: 'linear-gradient(135deg,#141e30,#243b55)', emoji: '🪐' },
  ];

  var modal       = document.getElementById('profileModal');
  var backdrop    = modal && modal.querySelector('.profile-modal-backdrop');
  var closeBtn    = document.getElementById('profileModalClose');
  var openButtons = Array.prototype.slice.call(document.querySelectorAll('[data-profile-open]'));
  if (!openButtons.length) {
    var fallbackOpenBtn = document.getElementById('profileBtn');
    if (fallbackOpenBtn) openButtons.push(fallbackOpenBtn);
  }
  var saveBtn     = document.getElementById('profileSaveBtn');
  var avatarBig   = document.getElementById('profileAvatarBig');
  var avatarGrid  = document.getElementById('profileAvatarGrid');
  var inputName   = document.getElementById('profileDisplayName');
  var inputBio    = document.getElementById('profileBio');
  var inputEmail  = document.getElementById('profileEmail');
  var emailCodeInput = document.getElementById('profileEmailCode');
  var emailSendBtn = document.getElementById('profileEmailSendCodeBtn');
  var emailVerifyBtn = document.getElementById('profileEmailVerifyBtn');
  var emailStatusEl = document.getElementById('profileEmailStatus');
  var inputAge    = document.getElementById('profileAge');
  var inputGender = document.getElementById('profileGender');

  var currentAvatarId = '';
  var pendingEmailCodeRequest = false;
  var pendingEmailCodeVerify = false;
  var EMAIL_CHANGE_RESPONSE_TIMEOUT_MS = 12000;
  var emailRequestTimeoutId = null;
  var emailVerifyTimeoutId = null;

  function getAvatarById(id) {
    return AVATARS.find(function(a){ return a.id === id; }) || null;
  }

  function applyAvatarToEl(el, avatarId, fallbackText) {
    var av = getAvatarById(avatarId);
    if (av) {
      el.style.background = av.bg;
      el.textContent = av.emoji;
    } else {
      el.style.background = '';
      el.textContent = fallbackText || '?';
    }
  }

  function normalizeEmail(value) {
    return String(value || '').trim().toLowerCase();
  }

  function toast(msg, type) {
    if (window._novynToast) {
      window._novynToast(msg, type || 'info');
      return;
    }
    alert(msg);
  }

  function setEmailStatus(message, type) {
    if (!emailStatusEl) return;
    emailStatusEl.textContent = message || '';
    emailStatusEl.classList.remove('success', 'error');
    if (type) emailStatusEl.classList.add(type);
  }

  function setEmailBusy(isBusy) {
    var disabled = Boolean(isBusy);
    if (emailSendBtn) emailSendBtn.disabled = disabled || pendingEmailCodeVerify;
    if (emailVerifyBtn) emailVerifyBtn.disabled = disabled || pendingEmailCodeRequest;
  }

  function getLinkedEmail() {
    return normalizeEmail(window._novynProfile && window._novynProfile.email);
  }

  function isProfileSocketUsable(socket) {
    return Boolean(
      socket
      && typeof socket.emit === 'function'
      && typeof socket.on === 'function'
      && (socket.io || typeof socket.connect === 'function' || typeof socket.id === 'string')
    );
  }

  function getProfileSocket() {
    var socket = window._novynSocket;
    return isProfileSocketUsable(socket) ? socket : null;
  }

  function ensureConnectedProfileSocket(socket) {
    if (!socket) return false;
    if (socket.connected === true) return true;
    if (typeof socket.connect === 'function') {
      try {
        socket.connect();
      } catch (_) {}
    }
    return socket.connected === true;
  }

  function clearEmailTimeout(kind) {
    if ((kind === 'request' || kind === 'all') && emailRequestTimeoutId) {
      clearTimeout(emailRequestTimeoutId);
      emailRequestTimeoutId = null;
    }
    if ((kind === 'verify' || kind === 'all') && emailVerifyTimeoutId) {
      clearTimeout(emailVerifyTimeoutId);
      emailVerifyTimeoutId = null;
    }
  }

  function startEmailTimeout(kind) {
    clearEmailTimeout(kind);
    var timeoutMessage = 'No response from server. Refresh once and try again.';
    if (kind === 'request') {
      emailRequestTimeoutId = setTimeout(function () {
        emailRequestTimeoutId = null;
        pendingEmailCodeRequest = false;
        setEmailBusy(false);
        setEmailStatus(timeoutMessage, 'error');
        toast(timeoutMessage, 'error');
      }, EMAIL_CHANGE_RESPONSE_TIMEOUT_MS);
      return;
    }
    if (kind === 'verify') {
      emailVerifyTimeoutId = setTimeout(function () {
        emailVerifyTimeoutId = null;
        pendingEmailCodeVerify = false;
        setEmailBusy(false);
        setEmailStatus(timeoutMessage, 'error');
        toast(timeoutMessage, 'error');
      }, EMAIL_CHANGE_RESPONSE_TIMEOUT_MS);
    }
  }

  // Build avatar grid
  if (avatarGrid) {
    AVATARS.forEach(function(av) {
      var btn = document.createElement('button');
      btn.className = 'av-grid-btn';
      btn.type = 'button';
      btn.title = av.emoji;
      btn.dataset.avId = av.id;
      btn.style.background = av.bg;
      btn.textContent = av.emoji;
      btn.addEventListener('click', function() {
        currentAvatarId = av.id;
        if (avatarBig) {
          avatarBig.style.background = av.bg;
          avatarBig.textContent = av.emoji;
        }
        document.querySelectorAll('.av-grid-btn').forEach(function(b){ b.classList.remove('selected'); });
        btn.classList.add('selected');
      });
      avatarGrid.appendChild(btn);
    });
  }

  var lastProfileFocus = null;
  var profileTrapCleanup = null;

  function getProfileFocusable() {
    if (!modal) return [];
    var nodes = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
    return Array.prototype.slice.call(nodes).filter(function (el) {
      return !el.disabled && el.offsetParent !== null;
    });
  }

  function trapProfileFocus() {
    function onKey(e) {
      if (e.key !== 'Tab') return;
      var focusable = getProfileFocusable();
      if (!focusable.length) return;
      var first = focusable[0];
      var last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
    modal.addEventListener('keydown', onKey);
    return function () { modal.removeEventListener('keydown', onKey); };
  }

  function showModal() {
    if (!modal) return;
    lastProfileFocus = document.activeElement;
    modal.style.display = 'flex';
    clearEmailTimeout('all');
    if (profileTrapCleanup) profileTrapCleanup();
    profileTrapCleanup = trapProfileFocus();
    var p = window._novynProfile || {};
    currentAvatarId = p.avatarId || '';
    if (inputName)   inputName.value   = p.displayName || '';
    if (inputBio)    inputBio.value    = p.bio || '';
    if (inputEmail)  inputEmail.value  = p.email || '';
    if (emailCodeInput) emailCodeInput.value = '';
    if (inputAge)    inputAge.value    = p.age || '';
    if (inputGender) inputGender.value = p.gender || '';
    pendingEmailCodeRequest = false;
    pendingEmailCodeVerify = false;
    setEmailBusy(false);
    if (p.email) {
      setEmailStatus('Current linked email: ' + p.email, '');
    } else {
      setEmailStatus('Add an email, send code, then verify to link it.', '');
    }
    if (avatarBig) {
      var me = window._novynMe ? window._novynMe() : '';
      applyAvatarToEl(avatarBig, currentAvatarId, (me || '?').slice(0,2).toUpperCase());
    }
    document.querySelectorAll('.av-grid-btn').forEach(function(b) {
      b.classList.toggle('selected', b.dataset.avId === currentAvatarId);
    });
    var focusable = getProfileFocusable();
    if (focusable.length) focusable[0].focus();
  }

  function hideModal() {
    if (!modal) return;
    modal.style.display = 'none';
    clearEmailTimeout('all');
    if (profileTrapCleanup) {
      profileTrapCleanup();
      profileTrapCleanup = null;
    }
    if (lastProfileFocus && typeof lastProfileFocus.focus === 'function') {
      lastProfileFocus.focus();
    }
    lastProfileFocus = null;
  }

  window._novynOpenProfileModal = showModal;
  window._novynCloseProfileModal = hideModal;

  openButtons.forEach(function(btn) {
    btn.addEventListener('click', showModal);
  });
  closeBtn && closeBtn.addEventListener('click', hideModal);
  backdrop && backdrop.addEventListener('click', hideModal);
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && modal && modal.style.display !== 'none') hideModal();
  });

  function bindProfileSocketHandlers() {
    var socket = getProfileSocket();
    if (!socket || bindProfileSocketHandlers._bound) return;
    bindProfileSocketHandlers._bound = true;

    socket.on('email_change_code_sent', function (data) {
      clearEmailTimeout('request');
      pendingEmailCodeRequest = false;
      setEmailBusy(false);
      var message = data && data.message ? data.message : 'Verification code sent.';
      setEmailStatus(message, 'success');
      toast(message, 'success');
      if (emailCodeInput) emailCodeInput.focus();
    });

    socket.on('email_change_failed', function (data) {
      clearEmailTimeout('all');
      pendingEmailCodeRequest = false;
      pendingEmailCodeVerify = false;
      setEmailBusy(false);
      var message = data && data.message ? data.message : 'Unable to verify email.';
      setEmailStatus(message, 'error');
      toast(message, 'error');
    });

    socket.on('email_change_verified', function (data) {
      clearEmailTimeout('verify');
      pendingEmailCodeRequest = false;
      pendingEmailCodeVerify = false;
      setEmailBusy(false);
      var nextEmail = normalizeEmail(data && data.email);
      if (inputEmail && nextEmail) inputEmail.value = nextEmail;
      if (emailCodeInput) emailCodeInput.value = '';
      var message = data && data.message ? data.message : 'Email linked successfully.';
      setEmailStatus(message, 'success');
    });
  }
  bindProfileSocketHandlers();
  var profileSocketBindTimer = null;
  function ensureProfileSocketHandlers() {
    bindProfileSocketHandlers();
    if (bindProfileSocketHandlers._bound) {
      if (profileSocketBindTimer) {
        clearInterval(profileSocketBindTimer);
        profileSocketBindTimer = null;
      }
      return;
    }
    if (!profileSocketBindTimer) {
      profileSocketBindTimer = setInterval(function () {
        bindProfileSocketHandlers();
        if (bindProfileSocketHandlers._bound) {
          clearInterval(profileSocketBindTimer);
          profileSocketBindTimer = null;
        }
      }, 600);
    }
  }
  ensureProfileSocketHandlers();

  emailSendBtn && emailSendBtn.addEventListener('click', function () {
    if (pendingEmailCodeRequest || pendingEmailCodeVerify) return;
    ensureProfileSocketHandlers();
    var socket = getProfileSocket();
    if (!socket) {
      setEmailStatus('Realtime connection not available.', 'error');
      toast('Realtime connection not available.', 'error');
      return;
    }
    if (!ensureConnectedProfileSocket(socket)) {
      setEmailStatus('Connecting to server. Please tap Send code again.', 'error');
      return;
    }
    var nextEmail = normalizeEmail(inputEmail ? inputEmail.value : '');
    var linkedEmail = getLinkedEmail();
    if (!nextEmail) {
      setEmailStatus('Enter your new email address first.', 'error');
      return;
    }
    if (nextEmail === linkedEmail) {
      setEmailStatus('That email is already linked to your account.', 'error');
      return;
    }
    pendingEmailCodeRequest = true;
    setEmailBusy(true);
    setEmailStatus('Sending verification code...', '');
    startEmailTimeout('request');
    socket.emit('request_email_change_code', { email: nextEmail }, function (response) {
      if (!response || typeof response !== 'object') return;
      clearEmailTimeout('request');
      if (!response.ok) {
        pendingEmailCodeRequest = false;
        setEmailBusy(false);
        var failMsg = response.message || 'Unable to send verification code.';
        setEmailStatus(failMsg, 'error');
        toast(failMsg, 'error');
        return;
      }
      pendingEmailCodeRequest = false;
      setEmailBusy(false);
      var okMsg = response.message || 'Verification code sent.';
      setEmailStatus(okMsg, 'success');
      toast(okMsg, 'success');
      if (emailCodeInput) emailCodeInput.focus();
    });
  });

  emailVerifyBtn && emailVerifyBtn.addEventListener('click', function () {
    if (pendingEmailCodeRequest || pendingEmailCodeVerify) return;
    ensureProfileSocketHandlers();
    var socket = getProfileSocket();
    if (!socket) {
      setEmailStatus('Realtime connection not available.', 'error');
      toast('Realtime connection not available.', 'error');
      return;
    }
    if (!ensureConnectedProfileSocket(socket)) {
      setEmailStatus('Connecting to server. Please tap Verify email again.', 'error');
      return;
    }
    var nextEmail = normalizeEmail(inputEmail ? inputEmail.value : '');
    var code = String(emailCodeInput ? emailCodeInput.value : '').trim();
    if (!nextEmail) {
      setEmailStatus('Enter your new email first.', 'error');
      return;
    }
    if (!code) {
      setEmailStatus('Enter the verification code sent to your email.', 'error');
      return;
    }
    pendingEmailCodeVerify = true;
    setEmailBusy(true);
    setEmailStatus('Verifying code...', '');
    startEmailTimeout('verify');
    socket.emit('verify_email_change_code', { email: nextEmail, code: code }, function (response) {
      if (!response || typeof response !== 'object') return;
      clearEmailTimeout('verify');
      if (!response.ok) {
        pendingEmailCodeVerify = false;
        setEmailBusy(false);
        var failMsg = response.message || 'Unable to verify code.';
        setEmailStatus(failMsg, 'error');
        toast(failMsg, 'error');
        return;
      }
      pendingEmailCodeVerify = false;
      setEmailBusy(false);
      var linkedEmail = normalizeEmail(response.email || nextEmail);
      if (inputEmail && linkedEmail) inputEmail.value = linkedEmail;
      if (emailCodeInput) emailCodeInput.value = '';
      var okMsg = response.message || 'Email linked successfully.';
      setEmailStatus(okMsg, 'success');
      toast(okMsg, 'success');
    });
  });

  inputEmail && inputEmail.addEventListener('input', function () {
    if (!emailStatusEl) return;
    setEmailStatus('', '');
  });
  emailCodeInput && emailCodeInput.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter') return;
    e.preventDefault();
    if (emailVerifyBtn) emailVerifyBtn.click();
  });

  saveBtn && saveBtn.addEventListener('click', function() {
    var linkedEmail = getLinkedEmail();
    var enteredEmail = normalizeEmail(inputEmail ? inputEmail.value : '');
    if (enteredEmail !== linkedEmail) {
      setEmailStatus('Verify your new email with code before saving profile changes.', 'error');
      if (enteredEmail && !pendingEmailCodeRequest && !pendingEmailCodeVerify && emailCodeInput) {
        emailCodeInput.focus();
      }
      return;
    }
    var payload = {
      avatarId: currentAvatarId,
      displayName: inputName   ? inputName.value.trim()   : '',
      bio:         inputBio    ? inputBio.value.trim()    : '',
      age:         inputAge    ? inputAge.value.trim()    : '',
      gender:      inputGender ? inputGender.value        : '',
    };
    if (window._novynSocket) window._novynSocket.emit('update_profile', payload);
    hideModal();
  });

  // Expose helpers for settings + app.js
  window._novynAvatarUtils = { getAvatarById: getAvatarById, applyAvatarToEl: applyAvatarToEl, AVATARS: AVATARS };
  window._novynOpenProfileModal = showModal;
  window._novynCloseProfileModal = hideModal;
})();
