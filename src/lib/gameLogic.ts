import type { Card, CardSuit, CardRank, Player, GameState } from '@/types/game';
import { CARD_VALUES } from '@/types/game';

// Einzigartige ID generieren
export function generateId(): string {
  return Math.random().toString(36).substring(2, 9);
}

// Karte erstellen
export function createCard(suit: CardSuit, rank: CardRank): Card {
  return {
    id: generateId(),
    suit,
    rank,
    value: CARD_VALUES[rank],
    isVisible: false,
  };
}

// Komplettes Deck erstellen
export function createDeck(): Card[] {
  const suits: CardSuit[] = ['hearts', 'diamonds', 'clubs', 'spades'];
  const ranks: CardRank[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  
  const deck: Card[] = [];
  for (const suit of suits) {
    for (const rank of ranks) {
      deck.push(createCard(suit, rank));
    }
  }
  return deck;
}

// Deck mischen (Fisher-Yates)
export function shuffleDeck(deck: Card[]): Card[] {
  const shuffled = [...deck];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

// Punkte einer Hand berechnen
export function calculateHandScore(cards: Card[]): number {
  return cards.reduce((sum, card) => sum + card.value, 0);
}

// Spieler erstellen
export function createPlayer(id: string, name: string): Player {
  return {
    id,
    name,
    hand: [],
    visibleCardIndices: [],
    score: 0,
    totalScore: 0,
    isActive: true,
    isEliminated: false,
    hasCalledDame: false,
    penaltyCards: [],
  };
}

// Neues Spiel initialisieren
export function initializeGame(playerNames: string[]): GameState {
  let deck = createDeck();
  deck = shuffleDeck(deck);
  
  const players = playerNames.map((name) => {
    const player = createPlayer(generateId(), name);
    // Jeder Spieler bekommt 4 Karten
    player.hand = deck.splice(0, 4);
    // Jeder darf 2 Karten sehen
    player.visibleCardIndices = [0, 1];
    return player;
  });
  
  return {
    players,
    currentPlayerIndex: 0,
    deck,
    discardPile: [],
    phase: 'SETUP',
    round: 1,
    turnInRound: 1,
    dameCallerId: null,
    cardsLogged: false,
    safePhase: true,
    lastAction: null,
    roundStartPlayerIndex: 0,
    dameCallTurnsRemaining: null,
  };
}

// Karte ziehen vom Deck
export function drawFromDeck(gameState: GameState): { card: Card | null; newState: GameState } {
  const newState = { ...gameState };
  
  if (newState.deck.length === 0) {
    // Deck ist leer - Ablagestapel neu mischen
    if (newState.discardPile.length > 1) {
      const topCard = newState.discardPile[newState.discardPile.length - 1];
      newState.deck = shuffleDeck(newState.discardPile.slice(0, -1));
      newState.discardPile = [topCard];
    } else {
      return { card: null, newState };
    }
  }
  
  const card = newState.deck.pop()!;
  card.isVisible = true;
  
  return { card, newState };
}

// Karte vom Ablagestapel nehmen
export function drawFromDiscard(gameState: GameState): { card: Card | null; newState: GameState } {
  const newState = { ...gameState };
  
  if (newState.discardPile.length === 0) {
    return { card: null, newState };
  }
  
  const card = newState.discardPile.pop()!;
  card.isVisible = true;
  
  return { card, newState };
}

// Karte mit Hand tauschen
export function swapCard(
  gameState: GameState, 
  playerId: string, 
  handIndex: number, 
  newCard: Card
): { discardedCard: Card; newState: GameState } {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  
  // Alte Karte wird abgelegt
  const discardedCard = player.hand[handIndex];
  discardedCard.isVisible = true;
  
  // Neue Karte kommt in die Hand
  player.hand[handIndex] = { ...newCard, isVisible: false };
  
  // Abgelegte Karte auf den Ablagestapel
  newState.discardPile.push(discardedCard);
  
  return { discardedCard, newState };
}

// Karte direkt ablegen (nur für ersten Spieler)
export function discardCard(gameState: GameState, card: Card): GameState {
  const newState = { ...gameState };
  card.isVisible = true;
  newState.discardPile.push(card);
  return newState;
}

// Bube-Effekt: Eigene Karte anschauen
export function applyJackEffect(gameState: GameState, playerId: string, handIndex: number): GameState {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  
  if (!player.visibleCardIndices.includes(handIndex)) {
    player.visibleCardIndices.push(handIndex);
  }
  
  newState.lastAction = `${player.name} hat sich eine Karte angeschaut`;
  return newState;
}

// König-Effekt: Karten tauschen
export function applyKingEffect(
  gameState: GameState,
  playerId: string,
  targetPlayerId: string,
  myHandIndex: number,
  targetHandIndex: number
): GameState {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  const targetPlayer = newState.players.find(p => p.id === targetPlayerId)!;
  
  // Karten tauschen
  const myCard = player.hand[myHandIndex];
  const targetCard = targetPlayer.hand[targetHandIndex];
  
  player.hand[myHandIndex] = targetCard;
  targetPlayer.hand[targetHandIndex] = myCard;
  
  // Beide Karten bleiben verdeckt
  player.hand[myHandIndex].isVisible = false;
  targetPlayer.hand[targetHandIndex].isVisible = false;
  
  newState.lastAction = `${player.name} hat eine Karte mit ${targetPlayer.name} getauscht`;
  return newState;
}

// Dame-Effekt: Strafkarte ziehen
export function applyQueenEffect(gameState: GameState, playerId: string): GameState {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  
  const { card, newState: updatedState } = drawFromDeck(newState);
  if (card) {
    card.isVisible = false;
    player.penaltyCards.push(card);
    updatedState.lastAction = `${player.name} hat eine Strafkarte gezogen!`;
  }
  
  return updatedState;
}

// Dame Call ausführen
export function callDame(gameState: GameState, playerId: string): GameState {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  const activePlayers = newState.players.filter(p => !p.isEliminated).length;

  player.hasCalledDame = true;
  newState.dameCallerId = playerId;
  newState.phase = 'DAME_CALLED';
  newState.cardsLogged = true;
  newState.dameCallTurnsRemaining = activePlayers;
  newState.lastAction = `${player.name} hat "Dame" gerufen!`;

  return newState;
}

// Prüfen, ob Dame Call erlaubt ist
export function canCallDame(gameState: GameState): boolean {
  return (
    !gameState.safePhase &&
    gameState.phase === 'REGULAR_PLAY' &&
    gameState.dameCallerId === null
  );
}

// Zug beenden und zum nächsten Spieler
export function endTurn(gameState: GameState): GameState {
  const newState = { ...gameState };

  // Nächster Spieler (überspringe Eliminierte)
  do {
    newState.currentPlayerIndex = (newState.currentPlayerIndex + 1) % newState.players.length;
  } while (newState.players[newState.currentPlayerIndex].isEliminated);

  newState.turnInRound++;

  // Dame Call: verbleibende Züge herunterzählen
  if (newState.phase === 'DAME_CALLED' && newState.dameCallTurnsRemaining !== null) {
    newState.dameCallTurnsRemaining--;
    if (newState.dameCallTurnsRemaining <= 0) {
      // Runde sofort beenden — endRound wird vom Hook aufgerufen
      newState.turnInRound = 1;
      newState.round++;
      newState.roundStartPlayerIndex = newState.currentPlayerIndex;
      return newState;
    }
  }

  // Normales Rundenende prüfen: wenn wir beim Startspieler der Runde ankommen
  if (newState.currentPlayerIndex === newState.roundStartPlayerIndex && newState.turnInRound > 1) {
    newState.turnInRound = 1;
    newState.round++;
    newState.roundStartPlayerIndex = newState.currentPlayerIndex;

    // Nach 2 Runden ist die Safe Phase vorbei
    if (newState.round > 2) {
      newState.safePhase = false;
      newState.phase = 'REGULAR_PLAY';
    }
  }

  return newState;
}

// Runde beenden und Punkte berechnen
export function endRound(gameState: GameState): GameState {
  const newState = { ...gameState };

  // --- Dame Call Auswertung — Teil 1: Gewinner bestimmen ---
  let callerWins = false;
  const dameCallerId = newState.dameCallerId;
  if (dameCallerId) {
    // Alle Karten aufdecken
    for (const player of newState.players) {
      if (!player.isEliminated) {
        player.visibleCardIndices = [0, 1, 2, 3];
      }
    }

    const caller = newState.players.find(p => p.id === dameCallerId);
    if (caller && !caller.isEliminated) {
      const callerScore = calculateHandScore([...caller.hand, ...caller.penaltyCards]);
      const otherScores = newState.players
        .filter(p => !p.isEliminated && p.id !== dameCallerId)
        .map(p => calculateHandScore([...p.hand, ...p.penaltyCards]));
      const lowestScore = otherScores.length > 0 ? Math.min(...otherScores) : Infinity;

      callerWins = callerScore <= lowestScore;
      if (callerWins) {
        // Caller gewinnt die Runde → 0 Punkte
        caller.score = 0;
        newState.lastAction = `${caller.name} hat "Dame" richtig gerufen! Runde gewonnen.`;
      } else {
        newState.lastAction = `${caller.name} lag mit "Dame" falsch! Strafkarte.`;
      }
    }
  }

  // Punkte für jeden Spieler berechnen
  for (const player of newState.players) {
    if (player.isEliminated) continue;

    // Bei Dame Call wurde score evtl. schon gesetzt (caller)
    if (dameCallerId === player.id && player.score === 0) {
      // score bereits 0, nichts zu tun
    } else {
      const allCards = [...player.hand, ...player.penaltyCards];
      player.score = calculateHandScore(allCards);
    }

    player.totalScore += player.score;

    // 50-Punkte-Reset prüfen
    if (player.totalScore === 50) {
      player.totalScore = 0;
      newState.lastAction = `${player.name} hat genau 50 Punkte erreicht - RESET!`;
    } else if (player.totalScore > 50) {
      player.isEliminated = true;
      newState.lastAction = `${player.name} ist ausgeschieden!`;
    }

    // Strafkarten zurücksetzen
    player.penaltyCards = [];
    player.hasCalledDame = false;
  }

  // --- Dame Call Auswertung — Teil 2: Strafkarte nach Punkteberechnung ---
  if (!callerWins && dameCallerId) {
    const caller = newState.players.find(p => p.id === dameCallerId);
    if (caller) {
      const { card: penaltyCard, newState: updatedState } = drawFromDeck(newState);
      if (penaltyCard) {
        penaltyCard.isVisible = false;
        caller.penaltyCards.push(penaltyCard);
      }
      if (updatedState) {
        newState.deck = updatedState.deck;
        newState.discardPile = updatedState.discardPile;
      }
    }
  }

  // Prüfen, ob nur noch ein Spieler übrig ist
  const remainingPlayers = newState.players.filter(p => !p.isEliminated);
  if (remainingPlayers.length <= 1) {
    newState.phase = 'GAME_OVER';
    return newState;
  }

  // Alle Karten aufdecken für die Übersicht
  for (const player of newState.players) {
    if (!player.isEliminated) {
      player.visibleCardIndices = [0, 1, 2, 3];
    }
  }

  newState.phase = 'ROUND_END';
  return newState;
}

// Nächste Runde starten (nach ROUND_END Übersicht)
export function startNextRound(gameState: GameState): GameState {
  const newState = { ...gameState };

  newState.turnInRound = 1;
  newState.dameCallerId = null;
  newState.cardsLogged = false;
  newState.dameCallTurnsRemaining = null;

  // Startspieler rotieren
  const activePlayerIndices = newState.players
    .map((p, i) => (!p.isEliminated ? i : -1))
    .filter(i => i !== -1);
  const currentStartIdx = activePlayerIndices.indexOf(newState.roundStartPlayerIndex);
  const nextStartIdx = activePlayerIndices[(currentStartIdx + 1) % activePlayerIndices.length];
  newState.roundStartPlayerIndex = nextStartIdx;
  newState.currentPlayerIndex = nextStartIdx;

  // Neue Karten verteilen
  let deck = createDeck();
  deck = shuffleDeck(deck);

  for (const player of newState.players) {
    if (player.isEliminated) continue;

    player.hand = deck.splice(0, 4);
    player.visibleCardIndices = [0, 1];
    player.score = 0;
  }

  newState.deck = deck;
  newState.discardPile = [];
  newState.phase = newState.round > 2 ? 'REGULAR_PLAY' : 'SETUP';
  newState.safePhase = newState.round <= 2;

  return newState;
}

// Gewinner ermitteln
export function getWinner(gameState: GameState): Player | null {
  const remainingPlayers = gameState.players.filter(p => !p.isEliminated);
  if (remainingPlayers.length === 1) {
    return remainingPlayers[0];
  }
  
  // Bei mehreren verbleibenden Spielern: Wer hat die wenigsten Punkte?
  if (gameState.phase === 'GAME_OVER') {
    return remainingPlayers.reduce((min, player) => 
      player.totalScore < min.totalScore ? player : min
    );
  }
  
  return null;
}

// Extra Karten ablegen (nach Ablegen einer Karte)
export function canDiscardExtraCard(
  gameState: GameState, 
  playerId: string, 
  rank: CardRank
): boolean {
  if (gameState.safePhase) return false;
  
  const player = gameState.players.find(p => p.id === playerId);
  if (!player || player.isEliminated) return false;
  
  // Prüfen, ob Spieler eine Karte mit gleichem Wert hat
  return player.hand.some(card => card.rank === rank);
}

// Extra Karte ablegen
export function discardExtraCard(
  gameState: GameState, 
  playerId: string, 
  cardId: string
): { success: boolean; newState: GameState } {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  
  const cardIndex = player.hand.findIndex(c => c.id === cardId);
  if (cardIndex === -1) {
    return { success: false, newState };
  }
  
  const card = player.hand[cardIndex];
  
  // Prüfen, ob die Karte passt
  if (newState.discardPile.length === 0) {
    return { success: false, newState };
  }
  
  const topCard = newState.discardPile[newState.discardPile.length - 1];
  if (card.rank !== topCard.rank) {
    // Falsche Karte - Strafkarte!
    const { card: penaltyCard, newState: updatedState } = drawFromDeck(newState);
    if (penaltyCard) {
      penaltyCard.isVisible = false;
      player.penaltyCards.push(penaltyCard);
      updatedState.lastAction = `${player.name} hat falsch abgelegt - Strafkarte!`;
    }
    return { success: false, newState: updatedState };
  }
  
  // Karte ablegen
  card.isVisible = true;
  newState.discardPile.push(card);
  player.hand.splice(cardIndex, 1);
  
  // Neue Karte vom Deck ziehen
  const { card: newCard, newState: finalState } = drawFromDeck(newState);
  if (newCard) {
    newCard.isVisible = false;
    player.hand.push(newCard);
  }
  
  finalState.lastAction = `${player.name} hat eine Extra-Karte abgelegt`;
  return { success: true, newState: finalState };
}
