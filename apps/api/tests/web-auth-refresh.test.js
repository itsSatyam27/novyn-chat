const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const ts = require("typescript");

function loadSingleFlight() {
  const source = fs.readFileSync(
    path.join(__dirname, "../../web/src/services/single-flight.ts"),
    "utf8",
  );
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const module = { exports: {} };
  vm.runInNewContext(compiled, { module, exports: module.exports, Promise });
  return module.exports.singleFlight;
}

test("web single-flight shares concurrent work and permits a later refresh", async () => {
  const singleFlight = loadSingleFlight();
  let calls = 0;
  let release;
  const refresh = singleFlight(() => {
    calls += 1;
    return new Promise((resolve) => {
      release = resolve;
    });
  });

  const first = refresh();
  const second = refresh();
  assert.equal(first, second);
  assert.equal(calls, 0, "operation begins in the next microtask");
  await Promise.resolve();
  assert.equal(calls, 1);
  release(200);
  assert.equal(await first, 200);
  const later = refresh();
  assert.notEqual(later, first);
  await Promise.resolve();
  assert.equal(calls, 2);
  release(201);
  assert.equal(await later, 201);
});

test("web single-flight clears a rejected request so refresh can be retried", async () => {
  const singleFlight = loadSingleFlight();
  let calls = 0;
  const refresh = singleFlight(async () => {
    calls += 1;
    if (calls === 1) throw new Error("temporary failure");
    return 200;
  });

  await assert.rejects(refresh(), /temporary failure/);
  assert.equal(await refresh(), 200);
  assert.equal(calls, 2);
});

test("legacy browser auth shares concurrent refresh requests", async () => {
  const source = fs.readFileSync(
    path.join(__dirname, "../../web/public/auth-session.js"),
    "utf8",
  );
  const window = {};
  let calls = 0;
  let release;
  const context = {
    window,
    document: { cookie: "novyn_csrf=test-csrf" },
    fetch: () => {
      calls += 1;
      return new Promise((resolve) => {
        release = () => resolve({
          ok: true,
          status: 200,
          headers: { get: () => "application/json" },
          json: async () => ({ ok: true }),
        });
      });
    },
  };
  vm.runInNewContext(source, context);

  const first = window._novynAuth.refreshSession();
  const second = window._novynAuth.refreshSession();
  assert.equal(first, second);
  await Promise.resolve();
  assert.equal(calls, 1);
  release();
  const firstResult = await first;
  assert.equal(firstResult.ok, true);
  assert.equal(firstResult.status, 200);
  assert.equal(firstResult.data.ok, true);
  const retry = window._novynAuth.refreshSession();
  assert.notEqual(retry, first);
  await Promise.resolve();
  assert.equal(calls, 2);
  release();
  await retry;
});
