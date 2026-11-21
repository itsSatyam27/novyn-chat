function registerHealthRoutes({ app, getMongoUri, getMongoStorage, hasMongoStorage }) {
  app.get("/health", (_req, res) => {
    res.set("Cache-Control", "no-store, max-age=0");
    res.status(200).json({ ok: true, status: "live" });
  });

  app.get("/health/ready", async (_req, res) => {
    res.set("Cache-Control", "no-store, max-age=0");
    const storage = hasMongoStorage() ? "mongodb" : "file";
    const mongoUri = getMongoUri();
    const mongoStorage = getMongoStorage();

    if (mongoUri) {
      if (!mongoStorage || !hasMongoStorage()) {
        return res.status(503).json({
          ok: false,
          ready: false,
          storage: "mongodb",
          message: "Database storage is not initialized.",
        });
      }
      try {
        await mongoStorage.ping();
      } catch (error) {
        console.warn("[NovynHealth] MongoDB readiness check failed:", error?.message || error);
        return res.status(503).json({
          ok: false,
          ready: false,
          storage: "mongodb",
          message: "Database is temporarily unavailable.",
        });
      }
    }

    return res.status(200).json({
      ok: true,
      ready: true,
      storage,
      persistentStorage: storage === "mongodb",
    });
  });
}

module.exports = { registerHealthRoutes };
