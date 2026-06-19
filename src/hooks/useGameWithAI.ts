import { useState, useCallback, useEffect, useRef } from 'react';
import type { GameState, Player, Card, MemoryEntry, CardSuit, CardRank, GamePhase, GameConfig } from '@/types/game';
import {
  initializeGame,
  drawFromDeck,
  drawFromDiscard,
  swapCard,
  discardCard,
  applyJackEffect,
  applyKingEffect,
  applyQueenEffect,
  applyAceEffect,
  applyTenEffect,
  callDame,
  endTurn,
  endRound,
  startNextRound,
  canCallDame,
  discardExtraCard,
  getWinner,
  peekCard,
} from '@/lib/gameLogic';
import { decideAIMove, findWorstCardIndex, type AIDifficulty } from '@/lib/aiPlayer';
import { useI18n } from '@/lib/i18n';
import type { AISpeed } from '@/hooks/useSettings';

export interface AIPlayerInfo {
  id: string;
  name: string;
  difficulty: AIDifficulty;
}

interface StatsActions {
  recordRound: (dameCalled: boolean, dameSuccessful: boolean, penaltyCards: number, bestScore: number) => void;
  recordGame: (won: boolean) => void;
}

interface UseGameWithAIReturn {
  gameState: GameState | null;
  drawnCard: Card | null;
  selectedHandIndex: number | null;
  gameMessage: string;
  messageKey: string;
  winner: Player | null;
  isAIThinking: boolean;
  currentAIDifficulty: AIDifficulty | null;
  startGame: (players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>) => void;
  loadSavedGame: () => boolean;
  hasSavedGame: boolean;
  drawFromDeck: () => void;
  drawFromDiscard: () => void;
  selectHandCard: (index: number) => void;
  confirmSwap: () => void;
  discardDrawnCard: () => void;
  activateJack: (targetPlayerId: string, handIndex: number) => void;
  activateKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
  activateAce: (deckIndex: number, handIndex: number) => void;
  activateTen: () => void;
  peekKingTarget: (targetPlayerId: string, targetHandIndex: number) => Card | null;
  callDame: () => void;
  tryDiscardExtra: (cardId: string) => boolean;
  endTurn: () => void;
  startNextRound: () => void;
  resetGame: () => void;
  canCallDameNow: boolean;
  isCurrentPlayerHuman: boolean;
  turnTimeLeft: number | null;
  pauseTurnTimer: () => void;
  resumeTurnTimer: () => void;
}

const SPEED_MULTIPLIERS: Record<AISpeed, number> = {
  fast: 0.4,
  normal: 1,
  slow: 2,
};

const SAVE_KEY = 'dame-game-save';

const VALID_SUITS: CardSuit[] = ['hearts', 'diamonds', 'clubs', 'spades'];
const VALID_RANKS: CardRank[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const VALID_PHASES: GamePhase[] = ['SETUP', 'FIRST_TURN', 'REGULAR_PLAY', 'DAME_CALLED', 'ROUND_END', 'GAME_OVER'];

function saveGameState(
  state: GameState | null,
  drawn: Card | null,
  ai: Map<string, AIDifficulty>,
  msg: string,
  msgKey: string,
  config?: GameConfig
) {
  try {
    if (!state) {
      localStorage.removeItem(SAVE_KEY);
      return;
    }
    const saveData = {
      gameState: state,
      drawnCard: drawn,
      aiPlayers: Array.from(ai.entries()),
      gameMessage: msg,
      messageKey: msgKey,
      gameConfig: config,
      timestamp: Date.now(),
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(saveData));
  } catch {
    // ignore
  }
}

function isValidCard(value: unknown): value is Card {
  if (typeof value !== 'object' || value === null) return false;
  const card = value as Partial<Card>;
  return (
    typeof card.id === 'string' &&
    typeof card.suit === 'string' &&
    VALID_SUITS.includes(card.suit as CardSuit) &&
    typeof card.rank === 'string' &&
    VALID_RANKS.includes(card.rank as CardRank) &&
    typeof card.value === 'number' &&
    typeof card.isVisible === 'boolean'
  );
}

function isValidMemoryEntry(value: unknown, targetPlayer: Player): value is MemoryEntry {
  if (typeof value !== 'object' || value === null) return false;
  const entry = value as Partial<MemoryEntry>;
  return (
    typeof entry.targetPlayerId === 'string' &&
    typeof entry.index === 'number' &&
    Number.isInteger(entry.index) &&
    entry.index >= 0 &&
    entry.index < targetPlayer.hand.length &&
    typeof entry.rank === 'string' &&
    VALID_RANKS.includes(entry.rank as CardRank) &&
    typeof entry.suit === 'string' &&
    VALID_SUITS.includes(entry.suit as CardSuit) &&
    typeof entry.round === 'number' &&
    typeof entry.turn === 'number'
  );
}

function isValidPlayer(value: unknown): value is Player {
  if (typeof value !== 'object' || value === null) return false;
  const player = value as Partial<Player>;
  if (
    typeof player.id !== 'string' ||
    typeof player.name !== 'string' ||
    !Array.isArray(player.hand) ||
    player.hand.length === 0 ||
    !player.hand.every(isValidCard) ||
    !Array.isArray(player.visibleCardIndices) ||
    typeof player.score !== 'number' ||
    typeof player.totalScore !== 'number' ||
    typeof player.isActive !== 'boolean' ||
    typeof player.isEliminated !== 'boolean' ||
    typeof player.hasCalledDame !== 'boolean' ||
    !Array.isArray(player.penaltyCards) ||
    !player.penaltyCards.every(isValidCard) ||
    !Array.isArray(player.memory) ||
    !player.memory.every((entry) => isValidMemoryEntry(entry, player as Player))
  ) {
    return false;
  }
  return true;
}

function isValidGameState(value: unknown): value is GameState {
  if (typeof value !== 'object' || value === null) return false;
  const state = value as Partial<GameState>;
  return (
    Array.isArray(state.players) &&
    state.players.length > 0 &&
    state.players.every(isValidPlayer) &&
    typeof state.currentPlayerIndex === 'number' &&
    state.currentPlayerIndex >= 0 &&
    state.currentPlayerIndex < state.players.length &&
    Array.isArray(state.deck) &&
    state.deck.every(isValidCard) &&
    Array.isArray(state.discardPile) &&
    state.discardPile.every(isValidCard) &&
    typeof state.phase === 'string' &&
    VALID_PHASES.includes(state.phase as GamePhase) &&
    typeof state.round === 'number' &&
    typeof state.turnInRound === 'number' &&
    (typeof state.dameCallerId === 'string' || state.dameCallerId === null) &&
    typeof state.cardsLogged === 'boolean' &&
    typeof state.safePhase === 'boolean' &&
    (typeof state.lastAction === 'string' || state.lastAction === null) &&
    typeof state.roundStartPlayerIndex === 'number' &&
    state.roundStartPlayerIndex >= 0 &&
    state.roundStartPlayerIndex < state.players.length &&
    (typeof state.dameCallTurnsRemaining === 'number' || state.dameCallTurnsRemaining === null)
  );
}

function isValidAIDifficulty(value: unknown): value is AIDifficulty {
  return value === 'easy' || value === 'medium' || value === 'hard';
}

function isValidGameConfig(value: unknown): value is GameConfig {
  if (typeof value !== 'object' || value === null) return false;
  const config = value as Partial<GameConfig>;
  return (
    typeof config.turnTimer === 'object' &&
    config.turnTimer !== null &&
    typeof config.turnTimer.enabled === 'boolean' &&
    typeof config.turnTimer.seconds === 'number' &&
    typeof config.powerEffects === 'boolean'
  );
}

function isValidSaveData(data: unknown): data is {
  gameState: GameState;
  drawnCard: Card | null;
  aiPlayers: Array<[string, AIDifficulty]>;
  gameMessage: string;
  messageKey?: string;
  gameConfig?: GameConfig;
  timestamp: number;
} {
  if (typeof data !== 'object' || data === null) return false;
  const save = data as Partial<Record<string, unknown>>;
  if (!isValidGameState(save.gameState)) return false;
  if (save.drawnCard !== null && !isValidCard(save.drawnCard)) return false;
  if (!Array.isArray(save.aiPlayers)) return false;
  if (!save.aiPlayers.every((entry) => Array.isArray(entry) && entry.length === 2 && typeof entry[0] === 'string' && isValidAIDifficulty(entry[1]))) {
    return false;
  }
  if (typeof save.gameMessage !== 'string') return false;
  if (save.messageKey !== undefined && typeof save.messageKey !== 'string') return false;
  if (save.gameConfig !== undefined && !isValidGameConfig(save.gameConfig)) return false;
  if (typeof save.timestamp !== 'number') return false;
  return true;
}

function loadGameState():
  | { gameState: GameState; drawnCard: Card | null; aiPlayers: Map<string, AIDifficulty>; gameMessage: string; messageKey: string; gameConfig?: GameConfig }
  | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!isValidSaveData(data)) {
      localStorage.removeItem(SAVE_KEY);
      return null;
    }
    return {
      gameState: data.gameState,
      drawnCard: data.drawnCard,
      aiPlayers: new Map(data.aiPlayers),
      gameMessage: data.gameMessage || 'Willkommen zurück!',
      messageKey: data.messageKey || 'game.continueGame',
      gameConfig: data.gameConfig,
    };
  } catch {
    return null;
  }
}

function hasSavedGameState(): boolean {
  try {
    return !!localStorage.getItem(SAVE_KEY);
  } catch {
    return false;
  }
}

export function useGameWithAI(aiSpeed: AISpeed = 'normal', statsActions?: StatsActions, gameConfig?: GameConfig): UseGameWithAIReturn {
  const speedMult = SPEED_MULTIPLIERS[aiSpeed];
  const speedMultRef = useRef(speedMult);
  useEffect(() => {
    speedMultRef.current = speedMult;
  }, [speedMult]);

  const { t } = useI18n();

  const [gameState, setGameState] = useState<GameState | null>(null);
  const [drawnCard, setDrawnCard] = useState<Card | null>(null);
  const [selectedHandIndex, setSelectedHandIndex] = useState<number | null>(null);
  const [gameMessage, setGameMessage] = useState<string>(t('game.welcome'));
  const [messageKey, setMessageKey] = useState<string>('game.welcome');
  const [isAIThinking, setIsAIThinking] = useState(false);
  const [aiPlayers, setAiPlayers] = useState<Map<string, AIDifficulty>>(new Map());
  const [hasSavedGame, setHasSavedGame] = useState(hasSavedGameState);
  const [turnTimeLeft, setTurnTimeLeft] = useState<number | null>(null);
  const [isTimerPaused, setIsTimerPaused] = useState(false);

  // Refs für KI-Züge (um State in Timeouts zu aktualisieren)
  const gameStateRef = useRef(gameState);
  const drawnCardRef = useRef(drawnCard);
  const aiPlayersRef = useRef(aiPlayers);
  const gameConfigRef = useRef(gameConfig);
  const aiTimeoutsRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const isAIMovingRef = useRef(false);

  // Refs für Zug-Timer, um Interval-Leaks zu vermeiden
  const timerIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const timerTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const setMessage = useCallback(
    (key: string, vars?: Record<string, string | number>) => {
      setMessageKey(key);
      setGameMessage(t(key, vars));
    },
    [t]
  );

  useEffect(() => {
    gameStateRef.current = gameState;
  }, [gameState]);

  useEffect(() => {
    drawnCardRef.current = drawnCard;
  }, [drawnCard]);

  useEffect(() => {
    aiPlayersRef.current = aiPlayers;
  }, [aiPlayers]);

  useEffect(() => {
    gameConfigRef.current = gameConfig;
  }, [gameConfig]);

  const clearAITimeouts = useCallback(() => {
    aiTimeoutsRef.current.forEach((id) => clearTimeout(id));
    aiTimeoutsRef.current = [];
  }, []);

  const scheduleAITimeout = useCallback((callback: () => void, delay: number) => {
    const id = setTimeout(callback, delay);
    aiTimeoutsRef.current.push(id);
    return id;
  }, []);

  const clearTimer = useCallback(() => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current);
      timerIntervalRef.current = null;
    }
    if (timerTimeoutRef.current) {
      clearTimeout(timerTimeoutRef.current);
      timerTimeoutRef.current = null;
    }
  }, []);

  const pauseTurnTimer = useCallback(() => {
    clearTimer();
    setIsTimerPaused(true);
  }, [clearTimer]);

  const resumeTurnTimer = useCallback(() => {
    // Timer-Intervalle bereinigen, bevor der Effekt neu startet
    clearTimer();
    setIsTimerPaused(false);
  }, [clearTimer]);

  // Auto-Save bei State-Änderungen
  useEffect(() => {
    saveGameState(gameState, drawnCard, aiPlayers, gameMessage, messageKey, gameConfig);
  }, [gameState, drawnCard, aiPlayers, gameMessage, messageKey, gameConfig]);

  // Spiel starten mit KI-Unterstützung
  const startGame = useCallback((players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>) => {
    const playerNames = players.map((p) => p.name);
    const newGame = initializeGame(playerNames);

    // Speichere KI-Informationen
    const aiMap = new Map<string, AIDifficulty>();
    players.forEach((p, index) => {
      if (p.isAI && p.difficulty) {
        aiMap.set(newGame.players[index].id, p.difficulty);
      }
    });

    clearAITimeouts();
    setAiPlayers(aiMap);
    setGameState(newGame);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setMessage('game.gameStarted');
    setIsAIThinking(false);
    setHasSavedGame(true);
  }, [clearAITimeouts, setMessage]);

  // Gespeichertes Spiel laden
  const loadSavedGame = useCallback(() => {
    const saved = loadGameState();
    if (!saved) {
      setHasSavedGame(false);
      return false;
    }

    clearAITimeouts();
    setGameState(saved.gameState);
    setDrawnCard(saved.drawnCard);
    setAiPlayers(saved.aiPlayers);
    setMessage(saved.messageKey);
    setSelectedHandIndex(null);
    setIsAIThinking(false);
    setHasSavedGame(true);

    // Refs aktualisieren
    gameStateRef.current = saved.gameState;
    drawnCardRef.current = saved.drawnCard;
    aiPlayersRef.current = saved.aiPlayers;
    gameConfigRef.current = saved.gameConfig;

    return true;
  }, [clearAITimeouts, setMessage]);

  const handleDrawFromDeck = useCallback(() => {
    if (!gameStateRef.current) return;

    const { card, newState } = drawFromDeck(gameStateRef.current);
    if (card) {
      gameStateRef.current = newState;
      setDrawnCard(card);
      setGameState(newState);

      const currentPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(currentPlayer.id);

      if (!isAI) {
        setMessage('game.drawnCardPrompt', { rank: card.rank });
      }
    }
  }, [setMessage]);

  const handleDrawFromDiscard = useCallback(() => {
    if (!gameStateRef.current) return;

    const { card, newState } = drawFromDiscard(gameStateRef.current);
    if (card) {
      gameStateRef.current = newState;
      setDrawnCard(card);
      setGameState(newState);

      const currentPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(currentPlayer.id);

      if (!isAI) {
        setMessage('game.drawnFromDiscard', { rank: card.rank });
      }
    }
  }, [setMessage]);

  const selectHandCard = useCallback((index: number) => {
    setSelectedHandIndex(index);
  }, []);

  const confirmSwap = useCallback((forcedHandIndex?: number) => {
    const handIndex = forcedHandIndex !== undefined ? forcedHandIndex : selectedHandIndex;
    if (!gameStateRef.current || !drawnCardRef.current || handIndex === null) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { discardedCard, newState } = swapCard(
      gameStateRef.current,
      currentPlayer.id,
      handIndex,
      drawnCardRef.current
    );

    gameStateRef.current = newState;
    setGameState(newState);
    setDrawnCard(null);
    setSelectedHandIndex(null);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);

    // Spezialeffekte prüfen
    if (discardedCard.rank === 'Q') {
      const finalState = applyQueenEffect(newState, currentPlayer.id);
      setGameState(finalState);
      if (!isAI) {
        setMessage('game.queenDiscarded');
      }
    } else if (discardedCard.rank === 'J') {
      if (!isAI) {
        setMessage('game.jackDiscarded');
      }
    } else if (discardedCard.rank === 'K') {
      if (!isAI) {
        setMessage('game.kingDiscarded');
      }
    } else {
      if (!isAI) {
        setMessage('game.cardDiscarded', { rank: discardedCard.rank });
      }
    }
  }, [selectedHandIndex, setMessage]);

  const discardDrawnCard = useCallback(() => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const newState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = newState;
    setGameState(newState);
    setDrawnCard(null);

    const currentPlayer = newState.players[newState.currentPlayerIndex];
    const isAI = aiPlayersRef.current.has(currentPlayer.id);

    if (!isAI) {
      setMessage('game.cardDiscardedGeneric');
    }
  }, [setMessage]);

  const handleUseJack = useCallback((targetPlayerId: string, handIndex: number) => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

    // Gezogene Bube-Karte zuerst ablegen, bevor der Effekt wirkt
    const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = discardedState;
    setGameState(discardedState);
    drawnCardRef.current = null;
    setDrawnCard(null);

    const newState = applyJackEffect(discardedState, currentPlayer.id, targetPlayerId, handIndex);
    gameStateRef.current = newState;
    setGameState(newState);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);
    if (!isAI) {
      setMessage('game.cardSeen');
    }
  }, [setMessage]);

  const handleUseKing = useCallback((
    targetPlayerId: string,
    myHandIndex: number,
    targetHandIndex: number
  ) => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

    // Gezogene König-Karte zuerst ablegen, bevor der Effekt wirkt
    const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = discardedState;
    setGameState(discardedState);
    drawnCardRef.current = null;
    setDrawnCard(null);

    const newState = applyKingEffect(
      discardedState,
      currentPlayer.id,
      targetPlayerId,
      myHandIndex,
      targetHandIndex
    );
    gameStateRef.current = newState;
    setGameState(newState);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);
    if (!isAI) {
      setMessage('game.swapped');
    }
  }, [setMessage]);

  const handleUseAce = useCallback((deckIndex: number, handIndex: number) => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

    // Gezogene Ass-Karte zuerst ablegen, bevor der Effekt wirkt
    const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = discardedState;
    setGameState(discardedState);
    drawnCardRef.current = null;
    setDrawnCard(null);

    const { newState } = applyAceEffect(discardedState, currentPlayer.id, deckIndex, handIndex);
    gameStateRef.current = newState;
    setGameState(newState);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);
    if (!isAI) {
      setMessage('game.aceEffectUsed');
    }
  }, [setMessage]);

  const handleUseTen = useCallback(() => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

    // Gezogene Zehn-Karte zuerst ablegen, bevor der Effekt wirkt
    const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = discardedState;
    setGameState(discardedState);
    drawnCardRef.current = null;
    setDrawnCard(null);

    const { newState, skipNextPlayer } = applyTenEffect(discardedState, currentPlayer.id);
    if (skipNextPlayer) {
      newState.skipNextPlayer = true;
    }
    gameStateRef.current = newState;
    setGameState(newState);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);
    if (!isAI) {
      setMessage('game.tenEffectUsed');
    }
  }, [setMessage]);

  const peekKingTarget = useCallback((targetPlayerId: string, targetHandIndex: number): Card | null => {
    if (!gameStateRef.current) return null;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { card, newState } = peekCard(gameStateRef.current, currentPlayer.id, targetPlayerId, targetHandIndex);
    gameStateRef.current = newState;
    setGameState(newState);
    return card;
  }, []);

  const handleCallDame = useCallback(() => {
    if (!gameStateRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const newState = callDame(gameStateRef.current, currentPlayer.id);
    gameStateRef.current = newState;
    setGameState(newState);
    setMessage('game.dameCalled', { name: currentPlayer.name });
  }, [setMessage]);

  const handleTryDiscardExtra = useCallback((cardId: string): boolean => {
    if (!gameStateRef.current) return false;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { success, newState } = discardExtraCard(gameStateRef.current, currentPlayer.id, cardId);
    gameStateRef.current = newState;
    setGameState(newState);

    const isAI = aiPlayersRef.current.has(currentPlayer.id);
    if (!isAI) {
      if (success) {
        setMessage('game.extraDiscardSuccess');
      } else {
        setMessage('game.extraDiscardFail');
      }
    }

    // Wenn der Spieler durch das Extra-Ablegen keine Karten mehr hat, Dame automatisch rufen
    if (success) {
      const playerAfter = newState.players.find((p) => p.id === currentPlayer.id);
      if (playerAfter && playerAfter.hand.length === 0) {
        isAIMovingRef.current = false;
        const dameState = callDame(newState, currentPlayer.id);
        const endState = endTurn(dameState);
        gameStateRef.current = endState;
        setGameState(endState);
        setMessage('game.autoDameCall', { name: currentPlayer.name });
        return true;
      }
    }

    return false;
  }, [setMessage]);

  const handleEndTurn = useCallback(() => {
    if (!gameStateRef.current) return;

    const prevRound = gameStateRef.current.round;
    let newState = endTurn(gameStateRef.current);

    // Nächsten Spieler überspringen, wenn Zehn-Effekt aktiv war
    if (gameStateRef.current.skipNextPlayer) {
      newState = endTurn(newState);
      newState.skipNextPlayer = false;
    }
    gameStateRef.current = newState;

    // Wenn Runde gewechselt, endRound ausführen
    if (newState.turnInRound === 1 && newState.round > prevRound) {
      const roundEndState = endRound(newState);
      setGameState(roundEndState);

      // Rundenstatistiken erfassen
      const dameCalled = !!roundEndState.dameCallerId;
      const caller = dameCalled
        ? roundEndState.players.find((p) => p.id === roundEndState.dameCallerId)
        : undefined;
      const dameSuccessful = caller
        ? roundEndState.players.every((p) => p.id === caller.id || p.score > caller.score)
        : false;
      const totalPenaltyCards = roundEndState.players.reduce(
        (sum, p) => sum + p.penaltyCards.length,
        0
      );
      const activeScores = roundEndState.players
        .filter((p) => !p.isEliminated)
        .map((p) => p.score);
      const bestScore = activeScores.length > 0 ? Math.min(...activeScores) : 0;
      statsActions?.recordRound(dameCalled, dameSuccessful, totalPenaltyCards, bestScore);

      if (roundEndState.phase === 'GAME_OVER') {
        const winner = getWinner(roundEndState);
        const humanWon = winner ? !aiPlayersRef.current.has(winner.id) : false;
        statsActions?.recordGame(humanWon);
      }

      const nextPlayer = roundEndState.players[roundEndState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(nextPlayer.id);
      if (!isAI) {
        if (roundEndState.phase === 'GAME_OVER') {
          setMessage('game.gameOver');
        } else {
          setMessage('game.roundStarts', { round: roundEndState.round, name: nextPlayer.name });
        }
      }
    } else {
      setGameState(newState);
      const nextPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(nextPlayer.id);
      if (!isAI) {
        setMessage('game.yourTurn', { name: nextPlayer.name });
      }
    }
  }, [statsActions, setMessage]);

  // Zug-Timer abgelaufen: Strafkarte ziehen und Zug beenden
  const handleTimerExpired = useCallback(() => {
    if (!gameStateRef.current) return;

    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { card, newState } = drawFromDeck(gameStateRef.current);
    if (card) {
      card.isVisible = false;
      const player = newState.players.find((p) => p.id === currentPlayer.id)!;
      player.penaltyCards.push(card);
      gameStateRef.current = newState;
      setGameState(newState);
      setMessage('game.turnTimerExpired', { name: currentPlayer.name });
      handleEndTurn();
    }
  }, [setMessage, handleEndTurn]);

  const handleStartNextRound = useCallback(() => {
    if (!gameStateRef.current) return;
    const newState = startNextRound(gameStateRef.current);
    gameStateRef.current = newState;
    setGameState(newState);
    setMessage('game.roundStarts', { round: newState.round, name: newState.players[newState.currentPlayerIndex].name });
    drawnCardRef.current = null;
    setDrawnCard(null);
    setSelectedHandIndex(null);
  }, [setMessage]);

  const resetGame = useCallback(() => {
    clearAITimeouts();
    isAIMovingRef.current = false;
    setGameState(null);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setMessage('game.welcome');
    setIsAIThinking(false);
    setAiPlayers(new Map());
    setHasSavedGame(false);
  }, [clearAITimeouts, setMessage]);

  // KI-Zug beenden und nächsten prüfen
  const endTurnAfterAI = useCallback(() => {
    isAIMovingRef.current = false;
    handleEndTurn();
    setIsAIThinking(false);
  }, [handleEndTurn]);

  // KI-Zug ausführen
  const executeAIMove = useCallback((playerId: string, difficulty: AIDifficulty) => {
    const currentState = gameStateRef.current;
    if (!currentState) return;

    const decision = decideAIMove(currentState, playerId, difficulty, drawnCardRef.current, gameConfigRef.current);
    const currentSpeed = speedMultRef.current;

    scheduleAITimeout(() => {
      switch (decision.action) {
        case 'DRAW_FROM_DECK':
          handleDrawFromDeck();
          break;
        case 'DRAW_FROM_DISCARD':
          handleDrawFromDiscard();
          break;
        case 'SWAP_CARD':
          if (decision.payload) {
            scheduleAITimeout(() => {
              confirmSwap(decision.payload.handIndex);
              scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
            }, Math.round(300 * currentSpeed));
          }
          break;
        case 'DISCARD_DRAWN_CARD':
          discardDrawnCard();
          scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          break;
        case 'DISCARD_EXTRA_CARD':
          if (decision.payload) {
            const autoDame = handleTryDiscardExtra(decision.payload.cardId);
            if (!autoDame) {
              scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
            }
          }
          break;
        case 'USE_JACK':
          if (decision.payload) {
            handleUseJack(decision.payload.targetPlayerId, decision.payload.handIndex);
            scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          }
          break;
        case 'USE_KING':
          if (decision.payload) {
            handleUseKing(
              decision.payload.targetPlayerId,
              decision.payload.myHandIndex,
              decision.payload.targetHandIndex
            );
            scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          }
          break;
        case 'USE_ACE': {
          const acePlayer = currentState.players[currentState.currentPlayerIndex];
          const worstHandIndex = findWorstCardIndex(acePlayer);
          handleUseAce(0, worstHandIndex);
          scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          break;
        }
        case 'USE_TEN':
          handleUseTen();
          scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          break;
        case 'CALL_DAME':
          handleCallDame();
          scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
          break;
        case 'END_TURN':
          endTurnAfterAI();
          break;
      }
    }, Math.round(decision.delay * currentSpeed));
  }, [scheduleAITimeout, endTurnAfterAI, handleDrawFromDeck, handleDrawFromDiscard, confirmSwap, discardDrawnCard, handleTryDiscardExtra, handleUseJack, handleUseKing, handleUseAce, handleUseTen, handleCallDame]);

  // KI Post-Draw: wenn gezogene Karte gesetzt und KI am Zug
  useEffect(() => {
    if (!gameState || !drawnCard) return;

    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const aiDifficulty = aiPlayers.get(currentPlayer.id);

    if (!aiDifficulty || currentPlayer.isEliminated) return;
    if (isAIMovingRef.current) return;

    isAIMovingRef.current = true;
    let didStart = false;

    const startId = setTimeout(() => {
      didStart = true;
      setIsAIThinking(true);
      executeAIMove(currentPlayer.id, aiDifficulty);
    }, 0);

    return () => {
      clearTimeout(startId);
      if (!didStart) {
        isAIMovingRef.current = false;
        setIsAIThinking(false);
      }
    };
  }, [gameState, drawnCard, aiPlayers, executeAIMove, speedMult]);

  // Prüfe ob aktueller Spieler KI ist und führe Zug aus
  useEffect(() => {
    if (!gameState) return;

    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const aiDifficulty = aiPlayers.get(currentPlayer.id);

    if (!aiDifficulty || currentPlayer.isEliminated) return;
    if (isAIMovingRef.current) return;
    if (drawnCard) return;

    const topDiscard = gameState.discardPile[gameState.discardPile.length - 1];
    const mustTakeQueen =
      topDiscard?.rank === 'Q' &&
      !gameState.safePhase &&
      gameState.phase !== 'DAME_CALLED' &&
      gameState.phase !== 'ROUND_END' &&
      gameState.phase !== 'GAME_OVER';

    isAIMovingRef.current = true;
    let didStart = false;

    const startId = setTimeout(() => {
      didStart = true;
      setIsAIThinking(true);
      if (mustTakeQueen) {
        setMessage('game.aiMustTakeQueen', { name: currentPlayer.name });
        handleDrawFromDiscard();
      } else {
        setMessage('game.aiThinking', { name: currentPlayer.name });
        executeAIMove(currentPlayer.id, aiDifficulty);
      }
    }, 0);

    return () => {
      clearTimeout(startId);
      if (!didStart) {
        isAIMovingRef.current = false;
        setIsAIThinking(false);
      }
    };
  }, [gameState, aiPlayers, executeAIMove, speedMult, handleDrawFromDiscard, drawnCard, setMessage]);

  // Zwangszug: menschlicher Spieler muss eine offene Dame vom Ablagestapel nehmen
  useEffect(() => {
    if (!gameState || drawnCard) return;

    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    if (!currentPlayer || currentPlayer.isEliminated || aiPlayers.has(currentPlayer.id)) return;

    const topDiscard = gameState.discardPile[gameState.discardPile.length - 1];
    if (
      !topDiscard ||
      topDiscard.rank !== 'Q' ||
      gameState.safePhase ||
      gameState.phase === 'DAME_CALLED' ||
      gameState.phase === 'ROUND_END' ||
      gameState.phase === 'GAME_OVER'
    ) {
      return;
    }

    const id = setTimeout(() => {
      setMessage('game.mustTakeQueen');
      handleDrawFromDiscard();
    }, Math.round(400 * speedMult));

    return () => clearTimeout(id);
  }, [gameState, drawnCard, aiPlayers, speedMult, handleDrawFromDiscard, setMessage]);

  const winner = gameState ? getWinner(gameState) : null;
  const canCallDameNow = gameState ? canCallDame(gameState) : false;

  // Aktuelle KI-Schwierigkeit ermitteln
  const currentPlayer = gameState?.players[gameState.currentPlayerIndex];
  const currentAIDifficulty = currentPlayer ? aiPlayers.get(currentPlayer.id) || null : null;
  const isCurrentPlayerHuman = currentPlayer ? !aiPlayers.has(currentPlayer.id) : false;

  // Zug-Timer für menschliche Spieler
  useEffect(() => {
    // Bestehende Timer immer bereinigen, bevor neue gestartet werden
    clearTimer();

    if (!gameState || !gameConfig?.turnTimer.enabled || !isCurrentPlayerHuman) {
      timerTimeoutRef.current = setTimeout(() => setTurnTimeLeft(null), 0);
      return () => {
        clearTimer();
      };
    }
    if (gameState.phase === 'ROUND_END' || gameState.phase === 'GAME_OVER') {
      timerTimeoutRef.current = setTimeout(() => setTurnTimeLeft(null), 0);
      return () => {
        clearTimer();
      };
    }
    // Timer pausieren, wenn eine Karte gezogen wurde (Entscheidungsphase) oder explizit pausiert wurde
    if (drawnCard !== null || isTimerPaused) {
      return () => {
        clearTimer();
      };
    }

    timerTimeoutRef.current = setTimeout(() => {
      setTurnTimeLeft(gameConfig.turnTimer.seconds);
      timerIntervalRef.current = setInterval(() => {
        setTurnTimeLeft((prev) => {
          if (prev === null) return null;
          if (prev <= 1) {
            clearTimer();
            handleTimerExpired();
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      // Timeout-Ref zurücksetzen, damit clearTimer nicht das bereits abgelaufene Timeout doppelt bereinigt
      timerTimeoutRef.current = null;
    }, 0);

    return () => {
      clearTimer();
    };
  }, [gameState, gameConfig, isCurrentPlayerHuman, drawnCard, isTimerPaused, handleTimerExpired, clearTimer]);

  // Timeouts beim Unmount bereinigen
  useEffect(() => {
    return () => {
      clearAITimeouts();
    };
  }, [clearAITimeouts]);

  return {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
    messageKey,
    winner,
    isAIThinking,
    currentAIDifficulty,
    isCurrentPlayerHuman,
    startGame,
    loadSavedGame,
    hasSavedGame,
    drawFromDeck: handleDrawFromDeck,
    drawFromDiscard: handleDrawFromDiscard,
    selectHandCard,
    confirmSwap,
    discardDrawnCard,
    activateJack: handleUseJack,
    activateKing: handleUseKing,
    activateAce: handleUseAce,
    activateTen: handleUseTen,
    peekKingTarget,
    callDame: handleCallDame,
    tryDiscardExtra: handleTryDiscardExtra,
    endTurn: handleEndTurn,
    startNextRound: handleStartNextRound,
    resetGame,
    canCallDameNow,
    turnTimeLeft,
    pauseTurnTimer,
    resumeTurnTimer,
  };
}
