import { describe, expect, it } from 'vitest';
import type { Player } from './game';

describe('Player type', () => {
  it('accepts isHuman flag', () => {
    const player: Player = {
      id: '1',
      name: 'Test',
      hand: [],
      visibleCardIndices: [],
      score: 0,
      totalScore: 0,
      isActive: true,
      isEliminated: false,
      hasCalledDame: false,
      penaltyCards: [],
      memory: [],
      isHuman: true,
    };
    expect(player.isHuman).toBe(true);
  });
});
