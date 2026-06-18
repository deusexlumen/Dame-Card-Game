export interface GameStats {
  gamesPlayed: number;
  gamesWon: number;
  roundsPlayed: number;
  dameCalls: number;
  successfulDameCalls: number;
  totalPenaltyCards: number;
  bestRoundScore: number | null;
  lastPlayedAt: string | null;
}

const STORAGE_KEY = 'dame-game-stats';

export function getDefaultStats(): GameStats {
  return {
    gamesPlayed: 0,
    gamesWon: 0,
    roundsPlayed: 0,
    dameCalls: 0,
    successfulDameCalls: 0,
    totalPenaltyCards: 0,
    bestRoundScore: null,
    lastPlayedAt: null,
  };
}

export function loadStats(): GameStats {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return getDefaultStats();
    const parsed = JSON.parse(raw) as Partial<GameStats>;
    return { ...getDefaultStats(), ...parsed };
  } catch {
    return getDefaultStats();
  }
}

export function saveStats(stats: GameStats): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
  } catch {
    // ignore
  }
}

export function recordGameFinished(won: boolean): GameStats {
  const stats = loadStats();
  stats.gamesPlayed += 1;
  if (won) stats.gamesWon += 1;
  stats.lastPlayedAt = new Date().toISOString();
  saveStats(stats);
  return stats;
}

export function recordRoundFinished(
  dameCalled: boolean,
  dameSuccessful: boolean,
  penaltyCards: number,
  bestScore: number
): GameStats {
  const stats = loadStats();
  stats.roundsPlayed += 1;
  if (dameCalled) stats.dameCalls += 1;
  if (dameSuccessful) stats.successfulDameCalls += 1;
  stats.totalPenaltyCards += penaltyCards;
  if (stats.bestRoundScore === null || bestScore < stats.bestRoundScore) {
    stats.bestRoundScore = bestScore;
  }
  stats.lastPlayedAt = new Date().toISOString();
  saveStats(stats);
  return stats;
}

export function resetStats(): GameStats {
  const stats = getDefaultStats();
  saveStats(stats);
  return stats;
}
