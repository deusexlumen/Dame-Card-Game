import { describe, it, expect } from 'vitest';
import type { Card } from '@/types/game';
import {
  createDeck,
  shuffleDeck,
  calculateHandScore,
  initializeGame,
  drawFromDeck,
  drawFromDiscard,
  swapCard,
  endTurn,
  endRound,
  startNextRound,
  callDame,
  canCallDame,
  applyJackEffect,
  applyKingEffect,
  applyQueenEffect,
  peekCard,
  getWinner,
  canDiscardExtraCard,
  discardExtraCard,
} from './gameLogic';

function makeCard(overrides: Partial<Card> = {}): Card {
  return {
    id: 'test-card',
    suit: 'hearts',
    rank: '2',
    value: 2,
    isVisible: false,
    ...overrides,
  };
}

describe('createDeck', () => {
  it('erzeugt 52 Karten', () => {
    const deck = createDeck();
    expect(deck).toHaveLength(52);
  });

  it('enthält alle Farben und Werte', () => {
    const deck = createDeck();
    const suits = new Set(deck.map((c) => c.suit));
    const ranks = new Set(deck.map((c) => c.rank));
    expect(suits.size).toBe(4);
    expect(ranks.size).toBe(13);
  });
});

describe('shuffleDeck', () => {
  it('behält alle Karten bei', () => {
    const deck = createDeck();
    const shuffled = shuffleDeck(deck);
    expect(shuffled).toHaveLength(52);
    expect(shuffled).not.toEqual(deck); // fast immer unterschiedlich
  });
});

describe('calculateHandScore', () => {
  it('summiert Kartenwerte korrekt', () => {
    const cards = [
      makeCard({ value: 5 }),
      makeCard({ value: 10 }),
      makeCard({ value: 0 }),
    ];
    expect(calculateHandScore(cards)).toBe(15);
  });
});

describe('initializeGame', () => {
  it('verteilt 4 Karten pro Spieler', () => {
    const state = initializeGame(['A', 'B']);
    expect(state.players).toHaveLength(2);
    state.players.forEach((p) => {
      expect(p.hand).toHaveLength(4);
      expect(p.visibleCardIndices).toEqual([0, 1]);
    });
  });

  it('setzt Phase auf SETUP und safePhase auf true', () => {
    const state = initializeGame(['A']);
    expect(state.phase).toBe('SETUP');
    expect(state.safePhase).toBe(true);
    expect(state.round).toBe(1);
    expect(state.roundStartPlayerIndex).toBe(0);
  });
});

describe('drawFromDeck', () => {
  it('zieht die oberste Karte', () => {
    const state = initializeGame(['A', 'B']);
    const deckBefore = state.deck.length;
    const { card, newState } = drawFromDeck(state);
    expect(card).not.toBeNull();
    expect(newState.deck).toHaveLength(deckBefore - 1);
    expect(card!.isVisible).toBe(true);
  });

  it('mischt Ablagestapel um wenn Deck leer', () => {
    const state = initializeGame(['A', 'B']);
    // Ablagestapel füllen
    state.discardPile = state.deck.splice(0, 10);
    state.deck = []; // Deck leer
    const { card, newState } = drawFromDeck(state);
    expect(card).not.toBeNull();
    expect(newState.deck.length).toBeGreaterThan(0);
  });

  it('verändert den übergebenen Zustand nicht', () => {
    const state = initializeGame(['A', 'B']);
    const deckBefore = state.deck.length;
    const { newState } = drawFromDeck(state);
    expect(state.deck).toHaveLength(deckBefore);
    expect(newState.deck).toHaveLength(deckBefore - 1);
  });
});

describe('drawFromDiscard', () => {
  it('nimmt die oberste Karte vom Ablagestapel', () => {
    const state = initializeGame(['A', 'B']);
    const top = state.deck[0];
    state.discardPile = [top];
    const { card, newState } = drawFromDiscard(state);
    expect(card).not.toBeNull();
    expect(newState.discardPile).toHaveLength(0);
  });

  it('gibt null bei leerem Ablagestapel', () => {
    const state = initializeGame(['A', 'B']);
    const { card } = drawFromDiscard(state);
    expect(card).toBeNull();
  });
});

describe('swapCard', () => {
  it('tauscht Karte und legt alte ab', () => {
    const state = initializeGame(['A', 'B']);
    const player = state.players[0];
    const oldCard = player.hand[0];
    const newCard: Card = { id: 'test', suit: 'hearts', rank: '2', value: 2, isVisible: true };
    const { discardedCard, newState } = swapCard(state, player.id, 0, newCard);
    expect(discardedCard.id).toBe(oldCard.id);
    expect(discardedCard.isVisible).toBe(true);
    expect(newState.discardPile).toContainEqual(expect.objectContaining({ id: oldCard.id }));
    expect(newState.players[0].hand[0].isVisible).toBe(false);
  });

  it('ändert nichts bei ungültigem Index', () => {
    const state = initializeGame(['A', 'B']);
    const player = state.players[0];
    const newCard = makeCard({ id: 'test', isVisible: true });
    const handBefore = [...player.hand];
    const { newState } = swapCard(state, player.id, 10, newCard);
    expect(newState.players[0].hand).toEqual(handBefore);
    expect(newState.lastAction).toBe('Ungültiger Kartenindex');
  });
});

describe('endTurn', () => {
  it('wechselt zum nächsten Spieler', () => {
    const state = initializeGame(['A', 'B']);
    const newState = endTurn(state);
    expect(newState.currentPlayerIndex).toBe(1);
  });

  it('erkennt Rundenende korrekt', () => {
    const state = initializeGame(['A', 'B']);
    // Spieler 0 war dran, jetzt Spieler 1
    let s = endTurn(state);
    expect(s.currentPlayerIndex).toBe(1);
    expect(s.turnInRound).toBe(2);
    // Spieler 1 beendet, zurück zu Spieler 0 = Rundenende
    s = endTurn(s);
    expect(s.turnInRound).toBe(1);
    expect(s.round).toBe(2);
  });

  it('überspringt eliminierte Spieler', () => {
    const state = initializeGame(['A', 'B', 'C']);
    state.players[1].isEliminated = true;
    const s = endTurn(state);
    expect(s.currentPlayerIndex).toBe(2); // überspringt B
  });

  it('setzt GAME_OVER wenn alle Spieler eliminiert sind', () => {
    const state = initializeGame(['A', 'B']);
    state.players[0].isEliminated = true;
    state.players[1].isEliminated = true;
    const s = endTurn(state);
    expect(s.phase).toBe('GAME_OVER');
  });
});

describe('applyJackEffect', () => {
  it('macht eigene Karte sichtbar und speichert sie im Gedächtnis', () => {
    const state = initializeGame(['A', 'B']);
    const player = state.players[0];
    player.visibleCardIndices = [0];
    const newState = applyJackEffect(state, player.id, player.id, 2);
    expect(newState.players[0].visibleCardIndices).toContain(2);
    expect(newState.players[0].memory).toHaveLength(1);
    expect(newState.players[0].memory[0]).toMatchObject({
      targetPlayerId: player.id,
      index: 2,
      rank: player.hand[2].rank,
      suit: player.hand[2].suit,
    });
  });

  it('speichert gegnerische Karte nur im eigenen Gedächtnis, nicht im gegnerischen', () => {
    const state = initializeGame(['A', 'B']);
    const viewer = state.players[0];
    const target = state.players[1];
    const newState = applyJackEffect(state, viewer.id, target.id, 2);
    expect(newState.players[0].memory).toHaveLength(1);
    expect(newState.players[0].memory[0]).toMatchObject({
      targetPlayerId: target.id,
      index: 2,
      rank: target.hand[2].rank,
      suit: target.hand[2].suit,
    });
    expect(newState.players[1].visibleCardIndices).toEqual([0, 1]);
  });
});

describe('applyKingEffect', () => {
  it('tauscht Karten zwischen Spielern', () => {
    const state = initializeGame(['A', 'B']);
    const aCard = state.players[0].hand[0];
    const bCard = state.players[1].hand[0];
    const newState = applyKingEffect(state, state.players[0].id, state.players[1].id, 0, 0);
    expect(newState.players[0].hand[0]).toEqual(bCard);
    expect(newState.players[1].hand[0]).toEqual(aCard);
    expect(newState.players[0].hand[0].isVisible).toBe(false);
  });
});

describe('peekCard', () => {
  it('zeigt eine gegnerische Karte kurz an, ohne sie dauerhaft aufzudecken', () => {
    const state = initializeGame(['A', 'B']);
    const viewer = state.players[0];
    const target = state.players[1];
    const { card, newState } = peekCard(state, viewer.id, target.id, 2);
    expect(card.isVisible).toBe(true);
    expect(card.rank).toBe(target.hand[2].rank);
    expect(card.suit).toBe(target.hand[2].suit);
    // Die eigentliche Handkarte bleibt verdeckt
    expect(newState.players[1].hand[2].isVisible).toBe(false);
    // Der Betrachter merkt sich die Karte
    expect(newState.players[0].memory).toHaveLength(1);
    expect(newState.players[0].memory[0]).toMatchObject({
      targetPlayerId: target.id,
      index: 2,
      rank: target.hand[2].rank,
      suit: target.hand[2].suit,
    });
  });
});

describe('applyQueenEffect', () => {
  it('zieht Strafkarte', () => {
    const state = initializeGame(['A', 'B']);
    const deckBefore = state.deck.length;
    const newState = applyQueenEffect(state, state.players[0].id);
    expect(newState.players[0].penaltyCards).toHaveLength(1);
    expect(newState.deck).toHaveLength(deckBefore - 1);
  });
});

describe('callDame', () => {
  it('setzt Phase auf DAME_CALLED und dameCallTurnsRemaining', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    state.phase = 'REGULAR_PLAY';
    const newState = callDame(state, state.players[0].id);
    expect(newState.phase).toBe('DAME_CALLED');
    expect(newState.dameCallerId).toBe(state.players[0].id);
    expect(newState.dameCallTurnsRemaining).toBe(2); // 2 aktive Spieler
  });
});

describe('canCallDame', () => {
  it('erlaubt Call nur in REGULAR_PLAY und wenn niemand gerufen hat', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    state.phase = 'REGULAR_PLAY';
    expect(canCallDame(state)).toBe(true);
  });

  it('verbietet Call wenn schon gerufen', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    state.phase = 'REGULAR_PLAY';
    state.dameCallerId = 'someone';
    expect(canCallDame(state)).toBe(false);
  });
});

describe('endRound', () => {
  it('berechnet Punkte und eliminiert bei >50', () => {
    const state = initializeGame(['A', 'B']);
    state.players[0].totalScore = 45;
    state.players[0].hand = [
      makeCard({ value: 5 }),
      makeCard({ value: 5 }),
      makeCard({ value: 5 }),
      makeCard({ value: 5 }),
    ]; // 20 Punkte
    state.players[1].totalScore = 30;
    state.players[1].hand = [
      makeCard({ value: 2 }),
      makeCard({ value: 2 }),
      makeCard({ value: 2 }),
      makeCard({ value: 2 }),
    ]; // 8 Punkte

    const newState = endRound(state);
    expect(newState.players[0].totalScore).toBe(65); // 45 + 20, eliminiert
    expect(newState.players[0].isEliminated).toBe(true);
    expect(newState.players[1].totalScore).toBe(38);
  });

  it('reset bei genau 50 Punkten', () => {
    const state = initializeGame(['A', 'B']);
    state.players[0].totalScore = 30;
    state.players[0].hand = [
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
    ]; // 20 Punkte -> 50 gesamt

    const newState = endRound(state);
    expect(newState.players[0].totalScore).toBe(0);
  });

  it('setzt GAME_OVER bei nur einem verbleibenden Spieler', () => {
    const state = initializeGame(['A', 'B']);
    state.players[0].isEliminated = true;
    const newState = endRound(state);
    expect(newState.phase).toBe('GAME_OVER');
  });

  it('verteilt neue Karten nach ROUND_END', () => {
    const state = initializeGame(['A', 'B']);
    const oldHand = state.players[0].hand.map((c) => c.id);
    const endState = endRound(state);
    expect(endState.phase).toBe('ROUND_END');
    const newState = startNextRound(endState);
    const newHand = newState.players[0].hand.map((c) => c.id);
    expect(newHand).not.toEqual(oldHand);
    expect(newState.players[0].hand).toHaveLength(4);
  });

  it('bewertet Dame Call korrekt (Caller gewinnt)', () => {
    const state = initializeGame(['A', 'B']);
    state.dameCallerId = state.players[0].id;
    state.players[0].hand = [
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
    ]; // 4 Punkte
    state.players[1].hand = [
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
    ]; // 40 Punkte
    const newState = endRound(state);
    expect(newState.players[0].score).toBe(0); // gewinnt
    expect(newState.players[0].totalScore).toBe(0);
  });

  it('bestraft falschen Dame Call mit Strafkarte', () => {
    const state = initializeGame(['A', 'B']);
    state.dameCallerId = state.players[0].id;
    state.players[0].hand = [
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
    ]; // 40 Punkte
    state.players[1].hand = [
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
    ]; // 4 Punkte
    const newState = endRound(state);
    expect(newState.players[0].penaltyCards).toHaveLength(1);
  });

  it('falscher Dame-Call hinterlässt genau eine Strafkarte für die nächste Runde', () => {
    const state = initializeGame(['A', 'B']);
    state.dameCallerId = state.players[0].id;
    state.players[0].hand = [
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
    ]; // 40 Punkte
    state.players[1].hand = [
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
    ]; // 4 Punkte
    const endState = endRound(state);
    expect(endState.players[0].penaltyCards.length).toBe(1);
  });

  it('gibt einem falschen Caller in der nächsten Runde 5 Karten', () => {
    const state = initializeGame(['A', 'B']);
    state.dameCallerId = state.players[0].id;
    state.players[0].hand = [
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
      makeCard({ value: 10 }),
    ]; // 40 Punkte
    state.players[1].hand = [
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
      makeCard({ value: 1 }),
    ]; // 4 Punkte
    const endState = endRound(state);
    expect(endState.players[0].penaltyCards.length).toBe(1);
    const nextState = startNextRound(endState);
    expect(nextState.players[0].hand).toHaveLength(5);
    expect(nextState.players[0].penaltyCards).toHaveLength(0);
    expect(nextState.players[0].visibleCardIndices).toEqual([0, 1]);
    expect(nextState.players[1].hand).toHaveLength(4);
  });
});

describe('getWinner', () => {
  it('gibt den letzten verbleibenden Spieler zurück', () => {
    const state = initializeGame(['A', 'B']);
    state.players[0].isEliminated = true;
    state.phase = 'GAME_OVER';
    const winner = getWinner(state);
    expect(winner).not.toBeNull();
    expect(winner!.id).toBe(state.players[1].id);
  });
});

describe('canDiscardExtraCard', () => {
  it('erlaubt ablegen wenn passender Rank in Hand', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    state.discardPile = [makeCard({ rank: '7', value: 7 })];
    state.players[0].hand = [
      makeCard({ rank: '7', value: 7 }),
      makeCard({ rank: 'A', value: 1 }),
      makeCard({ rank: '2', value: 2 }),
      makeCard({ rank: '3', value: 3 }),
    ];
    expect(canDiscardExtraCard(state, state.players[0].id, '7')).toBe(true);
    expect(canDiscardExtraCard(state, state.players[0].id, 'K')).toBe(false);
  });
});

describe('discardExtraCard', () => {
  it('legt passende Karte ab und zieht neue', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    const matchingCard = state.players[0].hand[0];
    state.discardPile = [makeCard({ rank: matchingCard.rank, value: matchingCard.value })];
    const handBefore = state.players[0].hand.length;
    const deckBefore = state.deck.length;
    const { success, newState } = discardExtraCard(state, state.players[0].id, matchingCard.id);
    expect(success).toBe(true);
    expect(newState.players[0].hand).toHaveLength(handBefore);
    expect(newState.deck).toHaveLength(deckBefore - 1);
  });

  it('bestraft falsches Ablegen mit Strafkarte', () => {
    const state = initializeGame(['A', 'B']);
    state.safePhase = false;
    state.discardPile = [makeCard({ rank: '7', value: 7 })];
    // Sicherstellen, dass die gewählte Karte wirklich nicht zum Ablagestapel passt
    const wrongCard = state.players[0].hand.find((c) => c.rank !== '7')!;
    const { success, newState } = discardExtraCard(state, state.players[0].id, wrongCard.id);
    expect(success).toBe(false);
    expect(newState.players[0].penaltyCards.length).toBeGreaterThan(0);
  });
});