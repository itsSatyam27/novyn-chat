(() => {
  if (!("serviceWorker" in navigator)) return;
  const host = window.location.hostname || "";
  const isLocalHost =
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "::1";
  if (isLocalHost) {
    navigator.serviceWorker.getRegistrations().then((registrations) => {
      registrations.forEach((registration) => {
        registration.unregister();
      });
    }).catch(() => {});
    return;
  }

  let refreshing = false;

  const showUpdatePrompt = (registration) => {
    if (document.getElementById("swUpdatePrompt")) return;

    const prompt = document.createElement("div");
    prompt.id = "swUpdatePrompt";
    prompt.className = "update-toast";
    prompt.setAttribute("role", "status");
    prompt.setAttribute("aria-live", "polite");
    prompt.innerHTML = `
      <div class="update-toast-text">
        Update available. Refresh (or hard refresh) to apply the latest version.
      </div>
      <div class="update-toast-actions">
        <button type="button" class="update-toast-btn primary">Refresh</button>
        <button type="button" class="update-toast-btn secondary">Later</button>
      </div>
    `;

    document.body.appendChild(prompt);

    const refreshBtn = prompt.querySelector(".update-toast-btn.primary");
    const laterBtn = prompt.querySelector(".update-toast-btn.secondary");
    const removePrompt = () => prompt.remove();

    refreshBtn?.addEventListener("click", () => {
      if (registration?.waiting) {
        registration.waiting.postMessage({ type: "SKIP_WAITING" });
      }
      removePrompt();
      setTimeout(() => window.location.reload(), 250);
    });

    laterBtn?.addEventListener("click", removePrompt);
  };

  const watchForUpdates = (registration) => {
    if (!registration) return;

    if (registration.waiting && navigator.serviceWorker.controller) {
      showUpdatePrompt(registration);
    }

    registration.addEventListener("updatefound", () => {
      const worker = registration.installing;
      if (!worker) return;
      worker.addEventListener("statechange", () => {
        if (worker.state === "installed" && navigator.serviceWorker.controller) {
          showUpdatePrompt(registration);
        }
      });
    });
  };

  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (refreshing) return;
    refreshing = true;
    window.location.reload();
  });

  window.addEventListener("load", async () => {
    try {
      const registration = await navigator.serviceWorker.register("/sw.js");
      watchForUpdates(registration);
    } catch (err) {
      console.warn("Service worker registration failed:", err);
    }
  });
})();
