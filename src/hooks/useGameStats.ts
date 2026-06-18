import { useState, useEffect, useCallback } from 'react';
import {
  type GameStats,
  loadStats,
  saveStats,
  resetStats,
} from '@/lib/stats';

export function useGameStats() {
  const [stats, setStats] = useState<GameStats>(() => loadStats());

  useEffect(() => {
    saveStats(stats);
  }, [stats]);

  const refresh = useCallback(() => {
    setStats(loadStats());
  }, []);

  const clear = useCallback(() => {
    setStats(resetStats());
  }, []);

  const recordRound = useCallback(
    (dameCalled: boolean, dameSuccessful: boolean, penaltyCards: number, bestScore: number) => {
      setStats((prev) => {
        const next = { ...prev };
        next.roundsPlayed += 1;
        if (dameCalled) next.dameCalls += 1;
        if (dameSuccessful) next.successfulDameCalls += 1;
        next.totalPenaltyCards += penaltyCards;
        if (next.bestRoundScore === null || bestScore < next.bestRoundScore) {
          next.bestRoundScore = bestScore;
        }
        next.lastPlayedAt = new Date().toISOString();
        saveStats(next);
        return next;
      });
    },
    []
  );

  const recordGame = useCallback((won: boolean) => {
    setStats((prev) => {
      const next = { ...prev };
      next.gamesPlayed += 1;
      if (won) next.gamesWon += 1;
      next.lastPlayedAt = new Date().toISOString();
      saveStats(next);
      return next;
    });
  }, []);

  return { stats, setStats, refresh, clear, recordRound, recordGame };
}
