import { describe, it, expect } from 'vitest';
import { decideAIMove, createAIPlayer } from './aiPlayer';
import type { GameState, Card } from '@/types/game';

// Hilfsfunktion: Minimaler GameState für Tests
function makeState(overrides?: Partial<GameState>): GameState {
  const state: GameState = {
    players: [
      {
        id: 'p1',
        name: 'KI',
        hand: [
          { id: 'c1', suit: 'hearts', rank: 'A', value: 1, isVisible: false },
          { id: 'c2', suit: 'diamonds', rank: '10', value: 10, isVisible: false },
          { id: 'c3', suit: 'clubs', rank: '5', value: 5, isVisible: false },
          { id: 'c4', suit: 'spades', rank: 'K', value: 10, isVisible: false },
        ],
        visibleCardIndices: [0, 1],
        score: 0,
        totalScore: 0,
        isActive: true,
        isEliminated: false,
        hasCalledDame: false,
        penaltyCards: [],
        memory: [],
      },
      {
        id: 'p2',
        name: 'Mensch',
        hand: [
          { id: 'c5', suit: 'hearts', rank: '2', value: 2, isVisible: false },
          { id: 'c6', suit: 'diamonds', rank: '3', value: 3, isVisible: false },
          { id: 'c7', suit: 'clubs', rank: '4', value: 4, isVisible: false },
          { id: 'c8', suit: 'spades', rank: '6', value: 6, isVisible: false },
        ],
        visibleCardIndices: [0, 1],
        score: 0,
        totalScore: 0,
        isActive: true,
        isEliminated: false,
        hasCalledDame: false,
        penaltyCards: [],
        memory: [],
      },
    ],
    currentPlayerIndex: 0,
    deck: [],
    discardPile: [],
    phase: 'REGULAR_PLAY',
    round: 3,
    turnInRound: 1,
    dameCallerId: null,
    cardsLogged: false,
    safePhase: false,
    lastAction: null,
    roundStartPlayerIndex: 0,
    dameCallTurnsRemaining: null,
  };
  return overrides ? Object.assign(state, overrides) : state;
}

describe('createAIPlayer', () => {
  it('erzeugt KI-Spieler-Info', () => {
    const ai = createAIPlayer('Bot-1', 'medium');
    expect(ai).toEqual({ name: 'Bot-1', isAI: true, difficulty: 'medium' });
  });
});

describe('decideAIMove — Pre-Draw', () => {
  it('easy: zieht vom Deck oder Ablagestapel', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
    });
    const move = decideAIMove(state, 'p1', 'easy');
    expect(['DRAW_FROM_DECK', 'DRAW_FROM_DISCARD']).toContain(move.action);
    expect(move.delay).toBe(1500);
  });

  it('medium: zieht vom Ablagestapel bei guter Karte', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
    });
    // Mehrfach ausführen, um Stabilität zu prüfen
    let discardCount = 0;
    for (let i = 0; i < 20; i++) {
      const move = decideAIMove(state, 'p1', 'medium');
      if (move.action === 'DRAW_FROM_DISCARD') discardCount++;
    }
    expect(discardCount).toBeGreaterThan(10); // sollte meistens vom Ablagestapel ziehen
  });

  it('medium: zieht vom Deck bei schlechter Ablagekarte', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: 'Q', value: 0, isVisible: true }],
    });
    const move = decideAIMove(state, 'p1', 'medium');
    expect(move.action).toBe('DRAW_FROM_DECK');
  });

  it('hard: zieht vom Ablagestapel bei sehr guter Karte', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: 'A', value: 1, isVisible: true }],
    });
    const move = decideAIMove(state, 'p1', 'hard');
    expect(move.action).toBe('DRAW_FROM_DISCARD');
  });

  it('medium/hard: nutzt Extra-Ablegen bei passender Karte', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '10', value: 10, isVisible: true }],
    });
    const moveMedium = decideAIMove(state, 'p1', 'medium');
    expect(moveMedium.action).toBe('DISCARD_EXTRA_CARD');
    if (moveMedium.action === 'DISCARD_EXTRA_CARD') {
      expect(moveMedium.payload.cardId).toBe('c2'); // passende 10 in der Hand
    }

    const moveHard = decideAIMove(state, 'p1', 'hard');
    expect(moveHard.action).toBe('DISCARD_EXTRA_CARD');
  });

  it('easy KI extra-discardiert auch niedrige passende Karten', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
    });
    state.players[0].hand = [
      { id: 'h1', suit: 'clubs', rank: '2', value: 2, isVisible: false },
      { id: 'h2', suit: 'diamonds', rank: '5', value: 5, isVisible: false },
      { id: 'h3', suit: 'spades', rank: '8', value: 8, isVisible: false },
      { id: 'h4', suit: 'hearts', rank: '3', value: 3, isVisible: false },
    ];
    expect(decideAIMove(state, 'p1', 'easy').action).toBe('DISCARD_EXTRA_CARD');
  });

  it('hard KI extra-discardiert nur hochwertige passende Karten', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '10', value: 10, isVisible: true }],
    });
    state.players[0].hand = [
      { id: 'h1', suit: 'clubs', rank: '10', value: 10, isVisible: false },
      { id: 'h2', suit: 'diamonds', rank: '5', value: 5, isVisible: false },
      { id: 'h3', suit: 'spades', rank: '8', value: 8, isVisible: false },
      { id: 'h4', suit: 'hearts', rank: '3', value: 3, isVisible: false },
    ];
    const move = decideAIMove(state, 'p1', 'hard');
    expect(move.action).toBe('DISCARD_EXTRA_CARD');
    if (move.action === 'DISCARD_EXTRA_CARD') {
      expect(move.payload.cardId).toBe('h1');
    }
  });

  it('hard KI extra-discardiert keine niedrigwertige passende Karte', () => {
    const state = makeState({
      discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
    });
    state.players[0].hand = [
      { id: 'h1', suit: 'clubs', rank: '2', value: 2, isVisible: false },
      { id: 'h2', suit: 'diamonds', rank: 'A', value: 1, isVisible: false },
      { id: 'h3', suit: 'spades', rank: 'A', value: 1, isVisible: false },
      { id: 'h4', suit: 'hearts', rank: 'A', value: 1, isVisible: false },
    ];
    const move = decideAIMove(state, 'p1', 'hard');
    expect(move.action).not.toBe('DISCARD_EXTRA_CARD');
  });
});

describe('decideAIMove — Post-Draw', () => {
  it('easy: tauscht oder legt ab', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: '3', value: 3, isVisible: true };
    const move = decideAIMove(state, 'p1', 'easy', drawnCard);
    expect(['SWAP_CARD', 'DISCARD_DRAWN_CARD']).toContain(move.action);
  });

  it('medium: tauscht wenn gezogene Karte besser als schlechteste', () => {
    const state = makeState();
    // Hand hat 10 und K als schlechte Karten; gezogene 3 ist gut
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: '3', value: 3, isVisible: true };
    const move = decideAIMove(state, 'p1', 'medium', drawnCard);
    expect(move.action).toBe('SWAP_CARD');
  });

  it('medium: legt direkt ab wenn gezogene Karte schlecht', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: '10', value: 10, isVisible: true };
    const move = decideAIMove(state, 'p1', 'medium', drawnCard);
    expect(move.action).toBe('DISCARD_DRAWN_CARD');
  });

  it('medium: Dame immer tauschen', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: 'Q', value: 0, isVisible: true };
    const move = decideAIMove(state, 'p1', 'medium', drawnCard);
    expect(move.action).toBe('SWAP_CARD');
  });

  it('medium: Bube-Effekt nutzen', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: 'J', value: 10, isVisible: true };
    const move = decideAIMove(state, 'p1', 'medium', drawnCard);
    expect(move.action).toBe('USE_JACK');
  });

  it('medium: König-Effekt nutzen', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: 'K', value: 10, isVisible: true };
    const move = decideAIMove(state, 'p1', 'medium', drawnCard);
    expect(move.action).toBe('USE_KING');
    if (move.action === 'USE_KING') {
      expect(move.payload).toHaveProperty('targetPlayerId');
      expect(move.payload).toHaveProperty('myHandIndex');
      expect(move.payload).toHaveProperty('targetHandIndex');
    }
  });

  it('hard: Ass sofort tauschen', () => {
    const state = makeState();
    const drawnCard: Card = { id: 'drawn', suit: 'hearts', rank: 'A', value: 1, isVisible: true };
    const move = decideAIMove(state, 'p1', 'hard', drawnCard);
    expect(move.action).toBe('SWAP_CARD');
  });
});

describe('decideAIMove — Dame Call', () => {
  it('easy: ruft nie', () => {
    const state = makeState();
    const move = decideAIMove(state, 'p1', 'easy');
    expect(move.action).not.toBe('CALL_DAME');
  });

  it('medium: ruft bei guter Hand', () => {
    const state = makeState({
      players: [
        {
          id: 'p1',
          name: 'KI',
          hand: [
            { id: 'c1', suit: 'hearts', rank: 'A', value: 1, isVisible: false },
            { id: 'c2', suit: 'diamonds', rank: 'A', value: 1, isVisible: false },
            { id: 'c3', suit: 'clubs', rank: '2', value: 2, isVisible: false },
            { id: 'c4', suit: 'spades', rank: '2', value: 2, isVisible: false },
          ],
          visibleCardIndices: [0, 1, 2, 3],
          score: 0,
          totalScore: 0,
          isActive: true,
          isEliminated: false,
          hasCalledDame: false,
          penaltyCards: [],
          memory: [],
        },
        {
          id: 'p2',
          name: 'Mensch',
          hand: [
            { id: 'c5', suit: 'hearts', rank: '10', value: 10, isVisible: false },
            { id: 'c6', suit: 'diamonds', rank: '10', value: 10, isVisible: false },
            { id: 'c7', suit: 'clubs', rank: '10', value: 10, isVisible: false },
            { id: 'c8', suit: 'spades', rank: '10', value: 10, isVisible: false },
          ],
          visibleCardIndices: [0, 1],
          score: 0,
          totalScore: 0,
          isActive: true,
          isEliminated: false,
          hasCalledDame: false,
          penaltyCards: [],
          memory: [],
        },
      ],
    });
    let callCount = 0;
    for (let i = 0; i < 20; i++) {
      const move = decideAIMove(state, 'p1', 'medium');
      if (move.action === 'CALL_DAME') callCount++;
    }
    expect(callCount).toBeGreaterThan(5); // 85% Chance bei Score < 15
  });

  it('verbietet Dame Call in Safe Phase', () => {
    const state = makeState({ safePhase: true, phase: 'SETUP' });
    const move = decideAIMove(state, 'p1', 'medium');
    expect(move.action).not.toBe('CALL_DAME');
  });

  it('verbietet Dame Call wenn schon gerufen', () => {
    const state = makeState({ dameCallerId: 'p2' });
    const move = decideAIMove(state, 'p1', 'hard');
    expect(move.action).not.toBe('CALL_DAME');
  });
});