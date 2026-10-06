(() => {
  const CSRF_COOKIE_NAME = "novyn_csrf";
  const CSRF_HEADER_NAME = "x-novyn-csrf";

  function normalizeText(value) {
    return String(value || "").trim();
  }

  function readCookie(name) {
    const needle = `${String(name || "").trim()}=`;
    if (!needle || typeof document === "undefined") return "";
    const parts = String(document.cookie || "").split(";");
    for (const part of parts) {
      const item = part.trim();
      if (!item.startsWith(needle)) continue;
      try {
        return decodeURIComponent(item.slice(needle.length));
      } catch (_) {
        return item.slice(needle.length);
      }
    }
    return "";
  }

  async function request(path, options = {}) {
    const method = String(options.method || "GET").toUpperCase();
    const headers = { ...(options.headers || (options.body ? { "Content-Type": "application/json" } : {})) };
    if (method !== "GET" && method !== "HEAD" && method !== "OPTIONS") {
      const csrfToken = readCookie(CSRF_COOKIE_NAME);
      if (csrfToken) {
        headers[CSRF_HEADER_NAME] = csrfToken;
      }
      if (options.body && !headers["Content-Type"]) {
        headers["Content-Type"] = "application/json";
      }
    }
    try {
      const response = await fetch(path, {
        method,
        cache: options.cache || "no-store",
        credentials: options.credentials || "same-origin",
        headers: Object.keys(headers).length ? headers : undefined,
        body: options.body ? JSON.stringify(options.body) : undefined,
      });
      const data = await response.json().catch(() => ({}));
      return { ok: response.ok, status: response.status, data };
    } catch (error) {
      return { ok: false, status: 0, data: { message: "Connection issue. Try again." }, error };
    }
  }

  async function signIn(payload) {
    const identifier = normalizeText(payload?.identifier);
    const password = String(payload?.password || "");
    const remember = Boolean(payload?.remember);
    return request("/api/auth/signin", {
      method: "POST",
      body: { identifier, password, remember },
    });
  }

  async function signUp(payload) {
    const email = normalizeText(payload?.email);
    const password = String(payload?.password || "");
    const name = normalizeText(payload?.name);
    const username = normalizeText(payload?.username);
    const remember = Boolean(payload?.remember);
    return request("/api/auth/signup", {
      method: "POST",
      body: { email, password, name, username, remember },
    });
  }

  async function getSession() {
    return request("/api/auth/session", { method: "GET" });
  }

  async function refreshSession() {
    return request("/api/auth/refresh", {
      method: "POST",
      cache: "no-store",
    });
  }

  async function logout() {
    return request("/api/auth/logout", {
      method: "POST",
      cache: "no-store",
    });
  }

  async function hasValidSession() {
    const first = await getSession();
    if (first.ok) return { ok: true, data: first.data };
    if (first.status !== 401) return first;

    const refreshed = await refreshSession();
    if (!refreshed.ok) return refreshed;
    return getSession();
  }

  window._novynAuth = {
    request,
    signIn,
    signUp,
    getSession,
    refreshSession,
    logout,
    hasValidSession,
  };
})();
