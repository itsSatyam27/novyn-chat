const VALID_GAME_TYPES = new Set([
  "tictactoe",
  "rps",
  "rockpaperscissors",
  "rajamantri",
  "ludo",
  "uno",
  "connect4",
  "doodle",
  "numberclash",
  "updown",
]);

function normalizeLeaderboardGame(value) {
  const normalized = String(value || "overall")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
  if (normalized === "overall" || normalized === "all") return "overall";
  if (normalized === "rockpaperscissors") return "rps";
  return VALID_GAME_TYPES.has(normalized) ? normalized : null;
}

function createStats() {
  return {
    matches: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    score: 0,
    lastPlayedAt: "",
  };
}

function addResult(stats, result, playedAt) {
  stats.matches += 1;
  stats.score += 10;
  if (result === "win") {
    stats.wins += 1;
    stats.score += 25;
  } else if (result === "loss") {
    stats.losses += 1;
  } else {
    stats.draws += 1;
  }
  if (!stats.lastPlayedAt || playedAt > stats.lastPlayedAt) {
    stats.lastPlayedAt = playedAt;
  }
}

function buildGameLeaderboard({
  matches,
  users,
  viewerKey,
  selectedGame = "overall",
}) {
  const gameFilter = normalizeLeaderboardGame(selectedGame);
  if (!gameFilter || !(users instanceof Map)) return [];

  const eligibleMatches = (Array.isArray(matches) ? matches : [])
    .filter((match) => {
      if (!match || match.isBotMatch === true || match.opponentType === "bot") return false;
      if (!["win", "loss", "draw"].includes(match.result)) return false;
      const userKey = String(match.userKey || "").trim().toLowerCase();
      const user = users.get(userKey);
      if (!user?.isRegistered || user.isSuspended === true) return false;
      return normalizeLeaderboardGame(match.gameType) !== null &&
        normalizeLeaderboardGame(match.gameType) !== "overall";
    })
    .map((match) => ({
      ...match,
      userKey: String(match.userKey).trim().toLowerCase(),
      gameType: normalizeLeaderboardGame(match.gameType),
      playedAt: new Date(match.playedAt),
    }))
    .filter((match) => Number.isFinite(match.playedAt.getTime()))
    .sort((a, b) =>
      a.userKey.localeCompare(b.userKey) ||
      a.playedAt.getTime() - b.playedAt.getTime()
    );

  const aggregates = new Map();
  const getAggregate = (userKey) => {
    let aggregate = aggregates.get(userKey);
    if (!aggregate) {
      aggregate = {
        overall: createStats(),
        games: new Map(),
        streaks: new Map(),
      };
      aggregates.set(userKey, aggregate);
    }
    return aggregate;
  };

  for (const match of eligibleMatches) {
    const aggregate = getAggregate(match.userKey);
    let gameStats = aggregate.games.get(match.gameType);
    if (!gameStats) {
      gameStats = createStats();
      aggregate.games.set(match.gameType, gameStats);
    }

    const timestamp = match.playedAt.toISOString();
    addResult(aggregate.overall, match.result, timestamp);
    addResult(gameStats, match.result, timestamp);

    const streak = match.result === "win"
      ? (aggregate.streaks.get(match.gameType) || 0) + 1
      : 0;
    aggregate.streaks.set(match.gameType, streak);
    if (match.result === "win" && streak > 0 && streak % 3 === 0) {
      aggregate.overall.score += 15;
      gameStats.score += 15;
    }
  }

  const safeViewerKey = String(viewerKey || "").trim().toLowerCase();
  if (safeViewerKey && users.get(safeViewerKey)?.isRegistered &&
      !aggregates.has(safeViewerKey)) {
    getAggregate(safeViewerKey);
  }

  const rows = [];
  for (const [userKey, aggregate] of aggregates.entries()) {
    const user = users.get(userKey);
    if (!user?.isRegistered || user.isSuspended === true) continue;
    const stats = gameFilter === "overall"
      ? aggregate.overall
      : aggregate.games.get(gameFilter);
    if (!stats && userKey !== safeViewerKey) continue;
    const selected = stats || createStats();
    const winRate = selected.matches > 0
      ? Math.round((selected.wins / selected.matches) * 100)
      : 0;
    rows.push({
      username: String(user.username || userKey),
      displayName: String(user.displayName || user.username || userKey),
      score: selected.score,
      matches: selected.matches,
      wins: selected.wins,
      losses: selected.losses,
      draws: selected.draws,
      winRate,
      lastPlayedAt: selected.lastPlayedAt,
      isSelf: userKey === safeViewerKey,
    });
  }

  rows.sort((a, b) =>
    b.score - a.score ||
    b.wins - a.wins ||
    b.winRate - a.winRate ||
    b.matches - a.matches ||
    a.username.localeCompare(b.username)
  );

  return rows.map((row, index) => ({ rank: index + 1, ...row }));
}


function buildMongoGameLeaderboardPipeline(userKeys = null, selectedGame = "overall") {
  const match = {
    isBotMatch: { $ne: true },
    opponentType: { $ne: "bot" },
    userKey: { $type: "string", $ne: "" },
    playedAt: { $type: "string", $ne: "" },
    result: { $in: ["win", "loss", "draw"] },
  };
  if (Array.isArray(userKeys)) match.userKey = { $in: userKeys };

  const rawGameType = { $toLower: { $ifNull: ["$gameType", ""] } };
  return [
    { $match: match },
    {
      $addFields: {
        normalizedGameType: {
          $cond: [
            { $eq: [rawGameType, "rockpaperscissors"] },
            "rps",
            rawGameType,
          ],
        },
        parsedPlayedAt: {
          $dateFromString: {
            dateString: "$playedAt",
            onError: null,
            onNull: null,
          },
        },
      },
    },
    {
      $match: {
        normalizedGameType: (() => {
          const selected = normalizeLeaderboardGame(selectedGame);
          return selected && selected !== "overall"
            ? selected
            : { $in: [...VALID_GAME_TYPES].filter((game) => game !== "rockpaperscissors") };
        })(),
        parsedPlayedAt: { $ne: null },
      },
    },
    // userKey + playedAt matches the storage compound index. The window stage
    // partitions by game so a loss/draw resets only that game's win streak.
    { $sort: { userKey: 1, playedAt: 1, _id: 1 } },
    {
      $setWindowFields: {
        partitionBy: { userKey: "$userKey", gameType: "$normalizedGameType" },
        sortBy: { parsedPlayedAt: 1, _id: 1 },
        output: {
          streakSegment: {
            $sum: {
              $cond: [{ $eq: ["$result", "win"] }, 0, 1],
            },
            window: { documents: ["unbounded", "current"] },
          },
        },
      },
    },
    {
      $group: {
        _id: {
          userKey: "$userKey",
          gameType: "$normalizedGameType",
          streakSegment: "$streakSegment",
        },
        matches: { $sum: 1 },
        wins: { $sum: { $cond: [{ $eq: ["$result", "win"] }, 1, 0] } },
        losses: { $sum: { $cond: [{ $eq: ["$result", "loss"] }, 1, 0] } },
        draws: { $sum: { $cond: [{ $eq: ["$result", "draw"] }, 1, 0] } },
        runWins: { $sum: { $cond: [{ $eq: ["$result", "win"] }, 1, 0] } },
        lastPlayedAt: { $max: "$parsedPlayedAt" },
      },
    },
    {
      $group: {
        _id: { userKey: "$_id.userKey", gameType: "$_id.gameType" },
        matches: { $sum: "$matches" },
        wins: { $sum: "$wins" },
        losses: { $sum: "$losses" },
        draws: { $sum: "$draws" },
        streakBonus: {
          $sum: {
            $multiply: [{ $floor: { $divide: ["$runWins", 3] } }, 15],
          },
        },
        lastPlayedAt: { $max: "$lastPlayedAt" },
      },
    },
    {
      $addFields: {
        score: {
          $add: [
            { $multiply: ["$matches", 10] },
            { $multiply: ["$wins", 25] },
            "$streakBonus",
          ],
        },
      },
    },
    {
      $group: {
        _id: "$_id.userKey",
        overallMatches: { $sum: "$matches" },
        overallWins: { $sum: "$wins" },
        overallLosses: { $sum: "$losses" },
        overallDraws: { $sum: "$draws" },
        overallScore: { $sum: "$score" },
        overallLastPlayedAt: { $max: "$lastPlayedAt" },
        games: {
          $push: {
            gameType: "$_id.gameType",
            matches: "$matches",
            wins: "$wins",
            losses: "$losses",
            draws: "$draws",
            score: "$score",
            lastPlayedAt: "$lastPlayedAt",
          },
        },
      },
    },
    {
      $project: {
        _id: 0,
        userKey: "$_id",
        overall: {
          matches: "$overallMatches",
          wins: "$overallWins",
          losses: "$overallLosses",
          draws: "$overallDraws",
          score: "$overallScore",
          lastPlayedAt: {
            $dateToString: {
              date: "$overallLastPlayedAt",
              format: "%Y-%m-%dT%H:%M:%S.%LZ",
              timezone: "UTC",
            },
          },
        },
        games: {
          $map: {
            input: "$games",
            as: "game",
            in: {
              gameType: "$game.gameType",
              matches: "$game.matches",
              wins: "$game.wins",
              losses: "$game.losses",
              draws: "$game.draws",
              score: "$game.score",
              lastPlayedAt: {
                $dateToString: {
                  date: "$game.lastPlayedAt",
                  format: "%Y-%m-%dT%H:%M:%S.%LZ",
                  timezone: "UTC",
                },
              },
            },
          },
        },
      },
    },
  ];
}

function buildGameLeaderboardFromAggregates({
  aggregates,
  users,
  viewerKey,
  selectedGame = "overall",
} = {}) {
  const gameFilter = normalizeLeaderboardGame(selectedGame);
  if (!gameFilter || !(users instanceof Map)) return [];
  const safeViewerKey = String(viewerKey || "").trim().toLowerCase();
  const rows = [];

  for (const aggregate of Array.isArray(aggregates) ? aggregates : []) {
    const userKey = String(aggregate?.userKey || "").trim().toLowerCase();
    const user = users.get(userKey);
    if (!userKey || !user?.isRegistered || user.isSuspended === true) continue;
    const selected = gameFilter === "overall"
      ? aggregate.overall
      : (Array.isArray(aggregate.games)
        ? aggregate.games.find((entry) => normalizeLeaderboardGame(entry?.gameType) === gameFilter)
        : null);
    if (!selected && userKey !== safeViewerKey) continue;

    const stats = selected || createStats();
    const matches = Math.max(0, Number(stats.matches) || 0);
    const wins = Math.max(0, Number(stats.wins) || 0);
    const losses = Math.max(0, Number(stats.losses) || 0);
    const draws = Math.max(0, Number(stats.draws) || 0);
    rows.push({
      username: String(user.username || userKey),
      displayName: String(user.displayName || user.username || userKey),
      score: Math.max(0, Number(stats.score) || 0),
      matches,
      wins,
      losses,
      draws,
      winRate: matches > 0 ? Math.round((wins / matches) * 100) : 0,
      lastPlayedAt: String(stats.lastPlayedAt || ""),
      isSelf: userKey === safeViewerKey,
    });
  }

  if (safeViewerKey && users.get(safeViewerKey)?.isRegistered &&
      !rows.some((entry) => entry.isSelf)) {
    const user = users.get(safeViewerKey);
    rows.push({
      username: String(user.username || safeViewerKey),
      displayName: String(user.displayName || user.username || safeViewerKey),
      score: 0,
      matches: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      winRate: 0,
      lastPlayedAt: "",
      isSelf: true,
    });
  }

  rows.sort((a, b) =>
    b.score - a.score ||
    b.wins - a.wins ||
    b.winRate - a.winRate ||
    b.matches - a.matches ||
    a.username.localeCompare(b.username)
  );
  return rows.map((row, index) => ({ rank: index + 1, ...row }));
}


function isMongoWindowStageUnsupportedError(error) {
  if (Number(error?.code) === 40324) return true;
  const message = String(error?.message || "");
  return /unrecognized pipeline stage name:\s*['"]?\$setWindowFields['"]?/i.test(message);
}

module.exports = {
  buildGameLeaderboard,
  buildGameLeaderboardFromAggregates,
  isMongoWindowStageUnsupportedError,
  buildMongoGameLeaderboardPipeline,
  normalizeLeaderboardGame,
};
