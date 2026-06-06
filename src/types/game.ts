// Kartentypen
export type CardSuit = 'hearts' | 'diamonds' | 'clubs' | 'spades';
export type CardRank = 'A' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '10' | 'J' | 'Q' | 'K';

export interface Card {
  id: string;
  suit: CardSuit;
  rank: CardRank;
  value: number;
  isVisible: boolean;
}

// Spieler
export interface Player {
  id: string;
  name: string;
  hand: Card[]; // 4 verdeckte Karten
  visibleCardIndices: number[]; // Indices der sichtbaren Karten (max 2)
  score: number;
  totalScore: number;
  isActive: boolean;
  isEliminated: boolean;
  hasCalledDame: boolean;
  penaltyCards: Card[]; // Strafkarten für die nächste Runde
}

// Spielphasen
export type GamePhase = 
  | 'SETUP'           // Spiel wird vorbereitet
  | 'FIRST_TURN'      // Erster Spieler zieht
  | 'REGULAR_PLAY'    // Normales Spiel (nach Runde 2)
  | 'DAME_CALLED'     // Dame Call wurde aufgerufen
  | 'ROUND_END'       // Runde endet, Punkte werden gezählt
  | 'GAME_OVER';      // Spiel ist beendet

// Spielzustand
export interface GameState {
  players: Player[];
  currentPlayerIndex: number;
  deck: Card[];
  discardPile: Card[];
  phase: GamePhase;
  round: number;
  turnInRound: number;
  dameCallerId: string | null;
  cardsLogged: boolean; // Karten des Callers sind eingeloggt
  safePhase: boolean; // Erste 2 Runden (kein Dame Call)
  lastAction: string | null;
  roundStartPlayerIndex: number;
  dameCallTurnsRemaining: number | null;
}

// Aktionen
export type GameAction =
  | { type: 'DRAW_FROM_DECK' }
  | { type: 'DRAW_FROM_DISCARD' }
  | { type: 'SWAP_CARD'; handIndex: number }
  | { type: 'DISCARD_DRAWN_CARD' }
  | { type: 'USE_JACK_EFFECT'; handIndex: number }
  | { type: 'USE_KING_EFFECT'; targetPlayerId: string; myHandIndex: number; targetHandIndex: number }
  | { type: 'CALL_DAME' }
  | { type: 'DISCARD_EXTRA_CARD'; cardId: string }
  | { type: 'END_TURN' };

// Kartenwerte
export const CARD_VALUES: Record<CardRank, number> = {
  'A': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  '10': 10,
  'J': 10,
  'Q': 0,  // Dame hat 0 Punkte
  'K': 10,
};

// Farben für das UI — echte Spielkarten-Farben
export const SUIT_COLORS: Record<CardSuit, string> = {
  hearts: 'text-[#c41e3a]',
  diamonds: 'text-[#c41e3a]',
  clubs: 'text-[#1a1a2e]',
  spades: 'text-[#1a1a2e]',
};

export const SUIT_SYMBOLS: Record<CardSuit, string> = {
  hearts: '♥',
  diamonds: '♦',
  clubs: '♣',
  spades: '♠',
};
