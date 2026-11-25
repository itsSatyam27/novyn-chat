const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const { Server } = require("socket.io");
const { io: createSocketClient } = require("socket.io-client");
const { createShutdownHandler } = require("../server/core/shutdown");

test("graceful shutdown drains startup, transport, timers, persistence, and storage in order", async () => {
  const calls = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => calls.push("startup"),
    closeTransport: async () => calls.push("transport"),
    stopBackgroundWork: async () => calls.push("timers"),
    flushState: async () => calls.push("persist"),
    closeStorage: async () => calls.push("storage"),
    timeoutMs: 1000,
    logger: { error() {} },
  });

  const first = shutdown("SIGTERM");
  const repeated = shutdown("SIGINT");
  assert.equal(first, repeated);
  assert.equal(await first, 0);
  assert.deepEqual(calls, ["startup", "transport", "timers", "persist", "storage"]);
});

test("graceful shutdown continues cleanup after a persistence failure and returns a failure code", async () => {
  const calls = [];
  const shutdown = createShutdownHandler({
    waitForStartup: async () => calls.push("startup"),
    closeTransport: async () => calls.push("transport"),
    stopBackgroundWork: async () => calls.push("timers"),
    flushState: async () => {
      calls.push("persist");
      throw new Error("disk unavailable");
    },
    closeStorage: async () => calls.push("storage"),
    timeoutMs: 1000,
    logger: { error() {} },
  });

  assert.equal(await shutdown("SIGTERM"), 1);
  assert.deepEqual(calls, ["startup", "transport", "timers", "persist", "storage"]);
});

test("graceful shutdown invokes the hard-timeout handler when a drain step stalls", async () => {
  let releaseTransport;
  let timedOut = false;
  const shutdown = createShutdownHandler({
    closeTransport: () => new Promise((resolve) => {
      releaseTransport = resolve;
    }),
    timeoutMs: 10,
    onTimeout: () => {
      timedOut = true;
    },
    logger: { error() {} },
  });

  const completion = shutdown("SIGTERM");
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.equal(timedOut, true);
  releaseTransport();
  assert.equal(await completion, 1);
});

test("graceful shutdown closes real Socket.IO clients and the HTTP listener before persistence", async (t) => {
  const httpServer = http.createServer((req, res) => res.end("ok"));
  const socketServer = new Server(httpServer);
  await new Promise((resolve, reject) => {
    httpServer.once("error", reject);
    httpServer.listen(0, "127.0.0.1", resolve);
  });

  const client = createSocketClient(
    `http://127.0.0.1:${httpServer.address().port}`,
    { transports: ["websocket"], reconnection: false }
  );
  t.after(async () => {
    client.close();
    if (httpServer.listening) {
      await new Promise((resolve) => socketServer.close(resolve));
    }
  });

  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Socket.IO client connection timed out.")), 3000);
    client.once("connect", () => {
      clearTimeout(timeout);
      resolve();
    });
    client.once("connect_error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });

  let clientDisconnected = false;
  client.once("disconnect", () => {
    clientDisconnected = true;
  });

  const shutdown = createShutdownHandler({
    closeTransport: () => new Promise((resolve, reject) => {
      socketServer.close((error) => error ? reject(error) : resolve());
    }),
    flushState: async () => {
      assert.equal(httpServer.listening, false);
      assert.equal(client.connected, false);
      assert.equal(clientDisconnected, true);
    },
    timeoutMs: 3000,
    logger: { error() {} },
  });

  assert.equal(await shutdown("SIGTERM"), 0);
  assert.equal(httpServer.listening, false);
});
