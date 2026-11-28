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
  "chess",
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
        bestStreaks: new Map(),
        overallStreak: 0,
        bestOverallStreak: 0,
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

    // Overall streaks span all games; each game's competitive bonus
    // streak remains isolated in aggregate.streaks below.
    aggregate.overallStreak = match.result === "win"
      ? aggregate.overallStreak + 1
      : 0;
    aggregate.bestOverallStreak = Math.max(
      aggregate.bestOverallStreak,
      aggregate.overallStreak,
    );

    const streak = match.result === "win"
      ? (aggregate.streaks.get(match.gameType) || 0) + 1
      : 0;
    aggregate.streaks.set(match.gameType, streak);
    const bestStreak = Math.max(
      aggregate.bestStreaks.get(match.gameType) || 0,
      streak,
    );
    aggregate.bestStreaks.set(match.gameType, bestStreak);
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
    const currentStreak = gameFilter === "overall"
      ? aggregate.overallStreak
      : aggregate.streaks.get(gameFilter) || 0;
    const bestStreak = gameFilter === "overall"
      ? aggregate.bestOverallStreak
      : aggregate.bestStreaks.get(gameFilter) || 0;
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
      currentStreak,
      bestStreak,
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

module.exports = {
  buildGameLeaderboard,
  normalizeLeaderboardGame,
};
