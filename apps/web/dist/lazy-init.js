(function () {
  var ASSET_VERSION = "20260408a";
  var loaded = Object.create(null);

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var key = String(src || "");
      if (!key) {
        resolve();
        return;
      }
      if (loaded[key] === "done") {
        resolve();
        return;
      }
      if (loaded[key] && typeof loaded[key].then === "function") {
        loaded[key].then(resolve, reject);
        return;
      }

      loaded[key] = new Promise(function (res, rej) {
        var script = document.createElement("script");
        script.src = key;
        script.async = true;
        script.onload = function () {
          loaded[key] = "done";
          res();
        };
        script.onerror = function (err) {
          loaded[key] = null;
          rej(err);
        };
        document.head.appendChild(script);
      });

      loaded[key].then(resolve, reject);
    });
  }

  function runIdle(task, timeout) {
    if (typeof task !== "function") return;
    if (typeof window.requestIdleCallback === "function") {
      window.requestIdleCallback(function () { task(); }, { timeout: timeout || 1000 });
      return;
    }
    setTimeout(task, Math.max(1, Number(timeout) || 1));
  }

  function shouldLoadVisuals() {
    try {
      if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        return false;
      }
      var connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
      if (connection && connection.saveData) return false;
    } catch (_) {
      // Ignore capability checks.
    }
    return true;
  }

  function startLazyBoot() {
    setTimeout(function () {
      loadScript("chat-extras.js?v=" + ASSET_VERSION).catch(function () {});
    }, 0);

    runIdle(function () {
      if (!shouldLoadVisuals()) return;
      var threeReady = window.THREE
        ? Promise.resolve()
        : loadScript("https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.min.js");
      threeReady
        .then(function () { return loadScript("visuals.js?v=" + ASSET_VERSION); })
        .catch(function () {});
    }, 1800);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startLazyBoot, { once: true });
  } else {
    startLazyBoot();
  }
})();
