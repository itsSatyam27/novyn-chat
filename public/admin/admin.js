(() => {
  "use strict";

  const config = window.NOVYN_ADMIN_CONFIG;
  const elements = {
    signedOut: document.getElementById("signed-out"),
    dashboard: document.getElementById("dashboard"),
    accountActions: document.getElementById("account-actions"),
    adminEmail: document.getElementById("admin-email"),
    signIn: document.getElementById("signin-button"),
    signOut: document.getElementById("signout-button"),
    refresh: document.getElementById("refresh-button"),
    authError: document.getElementById("auth-error"),
    dashboardError: document.getElementById("dashboard-error"),
    search: document.getElementById("user-search"),
    usersBody: document.getElementById("users-body"),
    feedbackList: document.getElementById("feedback-list"),
  };
  let currentUsers = [];
  let currentUser = null;
  let refreshTimer = null;
  let requestInFlight = false;

  const auth = firebase.initializeApp(config.firebase).auth();
  const formatDate = (value) => {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? "Not available"
      : new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(date);
  };

  function showError(element, message) {
    element.textContent = message;
    element.hidden = false;
  }

  function clearError(element) {
    element.textContent = "";
    element.hidden = true;
  }

  function setSignedIn(user) {
    currentUser = user;
    elements.signedOut.hidden = Boolean(user);
    elements.dashboard.hidden = !user;
    elements.accountActions.hidden = !user;
    elements.adminEmail.textContent = user?.email || "";
    if (refreshTimer) window.clearInterval(refreshTimer);
    refreshTimer = user ? window.setInterval(() => void loadDashboard(), 30_000) : null;
    if (user) void loadDashboard();
  }

  function renderUsers(users) {
    currentUsers = users;
    const query = elements.search.value.trim().toLowerCase();
    const filtered = users.filter((user) =>
      `${user.username} ${user.displayName} ${user.email}`.toLowerCase().includes(query)
    );
    elements.usersBody.replaceChildren();
    if (!filtered.length) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.className = "empty";
      cell.colSpan = 5;
      cell.textContent = "No users match that search.";
      row.append(cell);
      elements.usersBody.append(row);
      return;
    }

    for (const user of filtered) {
      const row = document.createElement("tr");
      const identity = document.createElement("td");
      const name = document.createElement("strong");
      const username = document.createElement("small");
      name.textContent = user.displayName;
      username.textContent = `@${user.username}`;
      identity.append(name, username);
      row.append(identity);
      for (const value of [
        user.email || "—",
        formatDate(user.createdAt),
        formatDate(user.lastSeenAt),
      ]) {
        const cell = document.createElement("td");
        cell.textContent = value;
        row.append(cell);
      }
      const status = document.createElement("td");
      const pill = document.createElement("span");
      pill.className = `pill${user.isOnline ? " online" : ""}`;
      pill.textContent = user.isOnline ? "Online" : user.isGoogleUser ? "Google" : "Offline";
      status.append(pill);
      row.append(status);
      elements.usersBody.append(row);
    }
  }

  function renderFeedback(entries) {
    elements.feedbackList.replaceChildren();
    if (!entries.length) {
      const empty = document.createElement("p");
      empty.className = "empty";
      empty.textContent = "No feedback submissions yet.";
      elements.feedbackList.append(empty);
      return;
    }
    for (const entry of entries) {
      const item = document.createElement("article");
      item.className = "feedback-item";
      const meta = document.createElement("div");
      meta.className = "feedback-meta";
      const type = document.createElement("span");
      type.className = `feedback-type ${entry.type}`;
      type.textContent = entry.type;
      meta.append(type);
      if (entry.rating !== null) {
        const rating = document.createElement("span");
        rating.className = "rating";
        rating.textContent = `${"★".repeat(Math.max(0, Math.min(5, entry.rating)))}`;
        meta.append(rating);
      }
      const time = document.createElement("time");
      time.textContent = formatDate(entry.createdAt);
      meta.append(time);
      const message = document.createElement("p");
      message.textContent = entry.message;
      const sender = document.createElement("small");
      sender.textContent = `${entry.fromUser}${entry.email ? ` · ${entry.email}` : ""}`;
      item.append(meta, message, sender);
      elements.feedbackList.append(item);
    }
  }

  async function loadDashboard() {
    if (!currentUser || requestInFlight) return;
    requestInFlight = true;
    elements.refresh.disabled = true;
    try {
      const token = await currentUser.getIdToken();
      const response = await fetch(`${config.apiBaseUrl}/api/admin/dashboard`, {
        method: "GET",
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.error || "Could not load dashboard data.");
      }

      const metrics = data.metrics;
      document.getElementById("metric-users").textContent = metrics.registeredUsers.toLocaleString();
      document.getElementById("metric-new-users").textContent = `+${metrics.newUsersLast7Days} in the last 7 days`;
      document.getElementById("metric-online").textContent = metrics.onlineUsers.toLocaleString();
      document.getElementById("metric-conversations").textContent = metrics.conversations.toLocaleString();
      document.getElementById("metric-messages").textContent = metrics.messages.toLocaleString();
      document.getElementById("metric-groups").textContent = metrics.groups.toLocaleString();
      document.getElementById("metric-feedback").textContent = metrics.feedback.toLocaleString();
      document.getElementById("user-total").textContent = `${metrics.registeredUsers.toLocaleString()} total`;
      document.getElementById("feedback-total").textContent = `${metrics.feedback.toLocaleString()} total`;
      document.getElementById("updated-at").textContent = `Updated ${formatDate(data.generatedAt)}`;
      renderUsers(data.users);
      renderFeedback(data.feedback);
      clearError(elements.dashboardError);
    } catch (error) {
      showError(elements.dashboardError, error.message || "Could not load dashboard data.");
    } finally {
      requestInFlight = false;
      elements.refresh.disabled = false;
    }
  }

  elements.signIn.addEventListener("click", async () => {
    clearError(elements.authError);
    elements.signIn.disabled = true;
    try {
      const provider = new firebase.auth.GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      await auth.signInWithPopup(provider);
    } catch (error) {
      showError(elements.authError, error.message || "Google sign-in failed.");
    } finally {
      elements.signIn.disabled = false;
    }
  });

  elements.signOut.addEventListener("click", () => auth.signOut());
  elements.refresh.addEventListener("click", () => void loadDashboard());
  elements.search.addEventListener("input", () => renderUsers(currentUsers));
  auth.onAuthStateChanged(setSignedIn, (error) => {
    showError(elements.authError, error.message || "Could not check Firebase sign-in.");
  });
})();
