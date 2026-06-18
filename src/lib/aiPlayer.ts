import type { GameState, Player, Card } from '@/types/game';

export type AIDifficulty = 'easy' | 'medium' | 'hard';

export type AIActionType =
  | 'WAIT'
  | 'DRAW_FROM_DECK'
  | 'DRAW_FROM_DISCARD'
  | 'SWAP_CARD'
  | 'DISCARD_DRAWN_CARD'
  | 'DISCARD_EXTRA_CARD'
  | 'USE_JACK'
  | 'USE_KING'
  | 'CALL_DAME'
  | 'END_TURN';

export type AIDecision =
  | { action: 'WAIT' }
  | { action: 'DRAW_FROM_DECK' }
  | { action: 'DRAW_FROM_DISCARD' }
  | { action: 'SWAP_CARD'; payload: { handIndex: number } }
  | { action: 'DISCARD_DRAWN_CARD' }
  | { action: 'DISCARD_EXTRA_CARD'; payload: { cardId: string } }
  | { action: 'USE_JACK'; payload: { targetPlayerId: string; handIndex: number } }
  | { action: 'USE_KING'; payload: { targetPlayerId: string; myHandIndex: number; targetHandIndex: number } }
  | { action: 'CALL_DAME' }
  | { action: 'END_TURN' };

export type AIDecisionWithDelay = AIDecision & { delay: number };

// Hilfsfunktion: Prüft, ob eine Karte "gut" ist (niedriger Punktewert)
function isGoodCard(card: Card): boolean {
  return card.value <= 3; // Ass, 2, 3 sind gut
}

// Hilfsfunktion: Bewertet eine Hand (niedriger ist besser)
function evaluateHand(player: Player): number {
  // Nur sichtbare Karten berücksichtigen + geschätzte Werte für verdeckte
  let estimatedScore = 0;
  player.hand.forEach((card, index) => {
    if (player.visibleCardIndices.includes(index)) {
      estimatedScore += card.value;
    } else {
      // Schätze verdeckte Karten als Durchschnitt (5.5 Punkte)
      estimatedScore += 5.5;
    }
  });
  return estimatedScore;
}

// Hilfsfunktion: Findet eine passende Extra-Ablegen-Karte (gleicher Rank wie Ablage)
function findExtraDiscardCardId(player: Player, topCardRank: string, minEstimatedValue = 0): string | null {
  const matchingIndices = player.hand
    .map((card, index) => (card.rank === topCardRank ? index : -1))
    .filter((index) => index !== -1);

  if (matchingIndices.length === 0) return null;

  // Wähle die schlechteste passende Karte (höchster geschätzter Wert)
  let worstIndex = matchingIndices[0];
  let worstValue = -1;

  for (const index of matchingIndices) {
    const isVisible = player.visibleCardIndices.includes(index);
    const estimatedValue = isVisible ? player.hand[index].value : 5;
    if (estimatedValue > worstValue) {
      worstValue = estimatedValue;
      worstIndex = index;
    }
  }

  if (worstValue < minEstimatedValue) return null;

  return player.hand[worstIndex].id;
}

// Hilfsfunktion: Finde den Index der schlechtesten Karte in der Hand
function findWorstCardIndex(player: Player): number {
  let worstIndex = 0;
  let worstValue = -1;
  
  player.hand.forEach((card, index) => {
    const isVisible = player.visibleCardIndices.includes(index);
    // Für sichtbare Karten: nutze tatsächlichen Wert
    // Für verdeckte Karten: schätze als mittel (5)
    const estimatedValue = isVisible ? card.value : 5;
    
    if (estimatedValue > worstValue) {
      worstValue = estimatedValue;
      worstIndex = index;
    }
  });
  
  return worstIndex;
}

// EINFACHE KI: Zufällige Entscheidungen
function makeEasyMove(
  gameState: GameState,
  playerId: string
): AIDecision {
  const currentPlayerIndex = gameState.players.findIndex(p => p.id === playerId);
  const player = gameState.players[currentPlayerIndex];

  // Prüfe, ob wir dran sind
  if (gameState.currentPlayerIndex !== currentPlayerIndex) {
    return { action: 'WAIT' };
  }

  // Extra-Ablegen: Einfache KI nutzt es manchmal, wenn eine passende Karte vorhanden ist
  if (gameState.discardPile.length > 0 && Math.random() > 0.5) {
    const topCard = gameState.discardPile[gameState.discardPile.length - 1];
    const extraCardId = findExtraDiscardCardId(player, topCard.rank, 0);
    if (extraCardId) {
      return { action: 'DISCARD_EXTRA_CARD', payload: { cardId: extraCardId } };
    }
  }

  // Phase 1: Karte ziehen
  // Einfache KI: 50/50 zwischen Deck und Ablagestapel (wenn verfügbar)
  if (gameState.discardPile.length > 0 && Math.random() > 0.5) {
    return { action: 'DRAW_FROM_DISCARD' };
  }
  return { action: 'DRAW_FROM_DECK' };
}

// EINFACHE KI: Nach dem Ziehen
function makeEasyPostDrawMove(
  gameState: GameState,
  playerId: string,
  drawnCard: Card
): AIDecision {
  const player = gameState.players.find(p => p.id === playerId)!;

  // Dame niemals direkt ablegen – immer mit einer Handkarte tauschen
  if (drawnCard.rank === 'Q') {
    const randomIndex = Math.floor(Math.random() * player.hand.length);
    return { action: 'SWAP_CARD', payload: { handIndex: randomIndex } };
  }

  // Zufällig entscheiden: Tauschen oder direkt ablegen
  if (Math.random() > 0.3) {
    // Tauschen - wähle zufällige Karte
    const randomIndex = Math.floor(Math.random() * player.hand.length);
    return { action: 'SWAP_CARD', payload: { handIndex: randomIndex } };
  } else {
    // Direkt ablegen
    return { action: 'DISCARD_DRAWN_CARD' };
  }
}

// MITTLERE KI: Grundlegende Strategie
function makeMediumMove(
  gameState: GameState,
  playerId: string
): AIDecision {
  const currentPlayerIndex = gameState.players.findIndex(p => p.id === playerId);
  const player = gameState.players[currentPlayerIndex];

  if (gameState.currentPlayerIndex !== currentPlayerIndex) {
    return { action: 'WAIT' };
  }

  // Prüfe Ablagestapel
  if (gameState.discardPile.length > 0) {
    const topCard = gameState.discardPile[gameState.discardPile.length - 1];

    // Extra-Ablegen: Wenn wir eine passende Karte haben, nutze die Gelegenheit
    const extraCardId = findExtraDiscardCardId(player, topCard.rank, 3);
    if (extraCardId && topCard.rank !== 'Q') {
      return { action: 'DISCARD_EXTRA_CARD', payload: { cardId: extraCardId } };
    }

    // Nimm von Ablagestapel wenn:
    // 1. Karte ist gut (niedriger Wert) UND nicht Dame
    // 2. Oder wir haben eine sehr schlechte Karte zum Tauschen
    if ((isGoodCard(topCard) && topCard.rank !== 'Q') ||
        (topCard.value <= 5 && topCard.rank !== 'Q')) {
      return { action: 'DRAW_FROM_DISCARD' };
    }
  }

  return { action: 'DRAW_FROM_DECK' };
}

// MITTLERE KI: Nach dem Ziehen
function makeMediumPostDrawMove(
  gameState: GameState,
  playerId: string,
  drawnCard: Card
): AIDecision {
  const player = gameState.players.find(p => p.id === playerId)!;
  
  // Spezialeffekte ausführen
  if (drawnCard.rank === 'J') {
    // Bube: Schau dir eine eigene verdeckte Karte an
    const hiddenIndex = player.hand.findIndex((_, i) =>
      !player.visibleCardIndices.includes(i)
    );
    if (hiddenIndex !== -1) {
      return { action: 'USE_JACK', payload: { targetPlayerId: playerId, handIndex: hiddenIndex } };
    }
  }
  
  if (drawnCard.rank === 'K') {
    // König: Tausche mit Gegner (wähle zufälligen Gegner und deine schlechteste Karte)
    const otherPlayers = gameState.players.filter(p => p.id !== playerId && !p.isEliminated);
    if (otherPlayers.length > 0) {
      const targetPlayer = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
      const myWorstCard = findWorstCardIndex(player);
      return { 
        action: 'USE_KING', 
        payload: { 
          targetPlayerId: targetPlayer.id, 
          myHandIndex: myWorstCard,
          targetHandIndex: Math.floor(Math.random() * 4) // Zufällige Karte des Gegners
        } 
      };
    }
  }
  
  // Dame niemals direkt ablegen - immer tauschen!
  if (drawnCard.rank === 'Q') {
    // Versuche, die Dame an den nächsten Spieler weiterzugeben
    const worstIndex = findWorstCardIndex(player);
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Normale Karte: Bewerte ob Tauschen sinnvoll ist
  const worstIndex = findWorstCardIndex(player);
  const worstCard = player.hand[worstIndex];
  
  // Tauschen wenn gezogene Karte besser ist als unsere schlechteste
  if (drawnCard.value < worstCard.value || 
      (!player.visibleCardIndices.includes(worstIndex) && drawnCard.value <= 5)) {
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Sonst direkt ablegen
  return { action: 'DISCARD_DRAWN_CARD' };
}

// SCHWERE KI: Fortgeschrittene Strategie mit Bluff und Risikobewertung
function makeHardMove(
  gameState: GameState,
  playerId: string
): AIDecision {
  const player = gameState.players.find(p => p.id === playerId)!;
  const currentPlayerIndex = gameState.players.findIndex(p => p.id === playerId);

  if (gameState.currentPlayerIndex !== currentPlayerIndex) {
    return { action: 'WAIT' };
  }

  // Berechne aktuellen geschätzten Punktestand
  const estimatedScore = evaluateHand(player);

  // Prüfe Ablagestapel sehr sorgfältig
  if (gameState.discardPile.length > 0) {
    const topCard = gameState.discardPile[gameState.discardPile.length - 1];

    // Extra-Ablegen: Strategisch nutzen, wenn eine passende Karte schlecht ist
    const extraCardId = findExtraDiscardCardId(player, topCard.rank, 4);
    if (extraCardId && topCard.rank !== 'Q') {
      return { action: 'DISCARD_EXTRA_CARD', payload: { cardId: extraCardId } };
    }

    // Strategie: Nimm von Ablagestapel wenn...
    // 1. Sehr gute Karte (Ass, 2, 3) und nicht Dame
    if (topCard.value <= 3 && topCard.rank !== 'Q') {
      return { action: 'DRAW_FROM_DISCARD' };
    }

    // 2. Unsere Hand ist schlecht und die Karte ist okay
    if (estimatedScore > 20 && topCard.value <= 6 && topCard.rank !== 'Q') {
      return { action: 'DRAW_FROM_DISCARD' };
    }

    // 3. Es ist ein Bube oder König (Spezialkarten sind wertvoll)
    if (topCard.rank === 'J' || topCard.rank === 'K') {
      return { action: 'DRAW_FROM_DISCARD' };
    }
  }

  // Standard: Ziehe vom Deck
  return { action: 'DRAW_FROM_DECK' };
}

// SCHWERE KI: Nach dem Ziehen
function makeHardPostDrawMove(
  gameState: GameState,
  playerId: string,
  drawnCard: Card
): AIDecision {
  const player = gameState.players.find(p => p.id === playerId)!;
  
  // BUBE: Strategisch einsetzen
  if (drawnCard.rank === 'J') {
    // Schau dir die eigene verdeckte Karte mit dem höchsten geschätzten Wert an
    // (wir vermuten, dass verdeckte Karten oft schlecht sind)
    const hiddenIndices = player.hand
      .map((_, i) => i)
      .filter(i => !player.visibleCardIndices.includes(i));

    if (hiddenIndices.length > 0) {
      // Priorisiere Positionen, die oft schlechte Karten haben
      return { action: 'USE_JACK', payload: { targetPlayerId: playerId, handIndex: hiddenIndices[0] } };
    }
  }
  
  // KÖNIG: Strategisch tauschen
  if (drawnCard.rank === 'K') {
    const otherPlayers = gameState.players.filter(p => p.id !== playerId && !p.isEliminated);
    if (otherPlayers.length > 0) {
      // Wähle den Spieler mit den wenigsten Punkten (führt wahrscheinlich)
      const targetPlayer = otherPlayers.reduce((best, p) => 
        p.totalScore < best.totalScore ? p : best
      );
      
      // Tausche unsere schlechteste Karte
      const myWorstCard = findWorstCardIndex(player);
      
      return { 
        action: 'USE_KING', 
        payload: { 
          targetPlayerId: targetPlayer.id, 
          myHandIndex: myWorstCard,
          targetHandIndex: Math.floor(Math.random() * 4) // Wir wissen nicht was der Gegner hat
        } 
      };
    }
  }
  
  // DAME: NIEMALS ablegen! Immer tauschen!
  if (drawnCard.rank === 'Q') {
    const worstIndex = findWorstCardIndex(player);
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Normale Karte: Komplexe Entscheidung
  const worstIndex = findWorstCardIndex(player);
  const worstCard = player.hand[worstIndex];
  
  // Wenn gezogene Karte sehr gut ist (Ass, 2, 3) -> immer tauschen
  if (drawnCard.value <= 3) {
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Wenn gezogene Karte besser als unsere schlechteste -> tauschen
  if (drawnCard.value < worstCard.value) {
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Wenn wir eine verdeckte Karte haben und die gezogene okay ist -> tauschen
  if (!player.visibleCardIndices.includes(worstIndex) && drawnCard.value <= 6) {
    return { action: 'SWAP_CARD', payload: { handIndex: worstIndex } };
  }
  
  // Sonst direkt ablegen
  return { action: 'DISCARD_DRAWN_CARD' };
}

// Entscheidung: Soll "Dame" gerufen werden?
function shouldCallDame(gameState: GameState, playerId: string, difficulty: AIDifficulty): boolean {
  const player = gameState.players.find(p => p.id === playerId)!;
  const estimatedScore = evaluateHand(player);
  
  // Einfach: Nie rufen
  if (difficulty === 'easy') return false;
  
  // Mittel: Rufen wenn geschätzter Score < 15
  if (difficulty === 'medium') {
    return estimatedScore < 15 && Math.random() > 0.3; // 70% Chance wenn Bedingung erfüllt
  }
  
  // Schwer: Rufen wenn geschätzter Score < 20 und wir führen wahrscheinlich
  if (difficulty === 'hard') {
    // Prüfe ob wir wahrscheinlich führen
    const otherPlayers = gameState.players.filter(p => p.id !== playerId && !p.isEliminated);
    const probablyLeading = otherPlayers.every(p => {
      const theirEstimatedScore = evaluateHand(p);
      return estimatedScore <= theirEstimatedScore;
    });
    
    return probablyLeading && estimatedScore < 20;
  }
  
  return false;
}

// Hauptfunktion: KI-Zug entscheiden
export function decideAIMove(
  gameState: GameState,
  playerId: string,
  difficulty: AIDifficulty,
  drawnCard: Card | null = null
): AIDecisionWithDelay {
  const reactionDelay = difficulty === 'easy' ? 1500 : difficulty === 'medium' ? 1000 : 800;
  
  // Prüfe ob "Dame" gerufen werden sollte
  if (!drawnCard && !gameState.safePhase && gameState.phase === 'REGULAR_PLAY') {
    if (shouldCallDame(gameState, playerId, difficulty)) {
      return { action: 'CALL_DAME', delay: reactionDelay };
    }
  }
  
  // Wenn noch keine Karte gezogen wurde
  if (!drawnCard) {
    let decision;
    switch (difficulty) {
      case 'easy':
        decision = makeEasyMove(gameState, playerId);
        break;
      case 'medium':
        decision = makeMediumMove(gameState, playerId);
        break;
      case 'hard':
        decision = makeHardMove(gameState, playerId);
        break;
    }
    return { ...decision, delay: reactionDelay };
  }
  
  // Wenn bereits eine Karte gezogen wurde
  let decision;
  switch (difficulty) {
    case 'easy':
      decision = makeEasyPostDrawMove(gameState, playerId, drawnCard);
      break;
    case 'medium':
      decision = makeMediumPostDrawMove(gameState, playerId, drawnCard);
      break;
    case 'hard':
      decision = makeHardPostDrawMove(gameState, playerId, drawnCard);
      break;
  }
  return { ...decision, delay: reactionDelay };
}

// KI-Spieler erstellen
export function createAIPlayer(name: string, difficulty: AIDifficulty): { name: string; isAI: true; difficulty: AIDifficulty } {
  return { name, isAI: true, difficulty };
}
