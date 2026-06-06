import { useState, useCallback, useEffect, useRef } from 'react';
import type { GameState, Player, Card } from '@/types/game';
import {
  initializeGame,
  drawFromDeck,
  drawFromDiscard,
  swapCard,
  discardCard,
  applyJackEffect,
  applyKingEffect,
  applyQueenEffect,
  callDame,
  endTurn,
  endRound,
  startNextRound,
  canCallDame,
  discardExtraCard,
  getWinner,
} from '@/lib/gameLogic';
import { decideAIMove, type AIDifficulty } from '@/lib/aiPlayer';
import type { AISpeed } from '@/hooks/useSettings';

export interface AIPlayerInfo {
  id: string;
  name: string;
  difficulty: AIDifficulty;
}

interface UseGameWithAIReturn {
  gameState: GameState | null;
  drawnCard: Card | null;
  selectedHandIndex: number | null;
  gameMessage: string;
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
  activateJack: (handIndex: number) => void;
  activateKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
  callDame: () => void;
  tryDiscardExtra: (cardId: string) => void;
  endTurn: () => void;
  startNextRound: () => void;
  resetGame: () => void;
  canCallDameNow: boolean;
  isCurrentPlayerHuman: boolean;
}

const SPEED_MULTIPLIERS: Record<AISpeed, number> = {
  fast: 0.4,
  normal: 1,
  slow: 2,
};

const SAVE_KEY = 'dame-game-save';

function saveGameState(state: GameState | null, drawn: Card | null, ai: Map<string, AIDifficulty>, msg: string) {
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
      timestamp: Date.now(),
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(saveData));
  } catch {
    // ignore
  }
}

function loadGameState(): { gameState: GameState; drawnCard: Card | null; aiPlayers: Map<string, AIDifficulty>; gameMessage: string } | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    return {
      gameState: data.gameState,
      drawnCard: data.drawnCard,
      aiPlayers: new Map(data.aiPlayers),
      gameMessage: data.gameMessage || 'Willkommen zurück!',
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

export function useGameWithAI(aiSpeed: AISpeed = 'normal'): UseGameWithAIReturn {
  const speedMult = SPEED_MULTIPLIERS[aiSpeed];
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [drawnCard, setDrawnCard] = useState<Card | null>(null);
  const [selectedHandIndex, setSelectedHandIndex] = useState<number | null>(null);
  const [gameMessage, setGameMessage] = useState<string>('Willkommen bei Dame!');
  const [isAIThinking, setIsAIThinking] = useState(false);
  const [aiPlayers, setAiPlayers] = useState<Map<string, AIDifficulty>>(new Map());
  const [hasSavedGame, setHasSavedGame] = useState(hasSavedGameState);
  
  // Ref für KI-Züge (um State in Timeout zu aktualisieren)
  const gameStateRef = useRef(gameState);
  const drawnCardRef = useRef(drawnCard);
  const aiPlayersRef = useRef(aiPlayers);

  useEffect(() => {
    gameStateRef.current = gameState;
  }, [gameState]);

  useEffect(() => {
    drawnCardRef.current = drawnCard;
  }, [drawnCard]);

  useEffect(() => {
    aiPlayersRef.current = aiPlayers;
  }, [aiPlayers]);

  // Auto-Save bei State-Änderungen
  useEffect(() => {
    saveGameState(gameState, drawnCard, aiPlayers, gameMessage);
    setHasSavedGame(!!gameState);
  }, [gameState, drawnCard, aiPlayers, gameMessage]);

  // Spiel starten mit KI-Unterstützung
  const startGame = useCallback((players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>) => {
    const playerNames = players.map(p => p.name);
    const newGame = initializeGame(playerNames);
    
    // Speichere KI-Informationen
    const aiMap = new Map<string, AIDifficulty>();
    players.forEach((p, index) => {
      if (p.isAI && p.difficulty) {
        aiMap.set(newGame.players[index].id, p.difficulty);
      }
    });
    setAiPlayers(aiMap);
    
    setGameState(newGame);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setGameMessage('Spiel gestartet! Ziehe eine Karte.');
    setIsAIThinking(false);
  }, []);

  // Gespeichertes Spiel laden
  const loadSavedGame = useCallback(() => {
    const saved = loadGameState();
    if (!saved) return false;
    
    setGameState(saved.gameState);
    setDrawnCard(saved.drawnCard);
    setAiPlayers(saved.aiPlayers);
    setGameMessage(saved.gameMessage);
    setSelectedHandIndex(null);
    setIsAIThinking(false);
    
    // Refs aktualisieren
    gameStateRef.current = saved.gameState;
    drawnCardRef.current = saved.drawnCard;
    aiPlayersRef.current = saved.aiPlayers;
    
    return true;
  }, []);

  // KI-Zug ausführen
  const executeAIMove = useCallback((playerId: string, difficulty: AIDifficulty) => {
    const currentState = gameStateRef.current;
    if (!currentState) return;
    
    const decision = decideAIMove(currentState, playerId, difficulty, drawnCardRef.current);
    
    setTimeout(() => {
      switch (decision.action) {
        case 'DRAW_FROM_DECK':
          handleDrawFromDeck();
          break;
        case 'DRAW_FROM_DISCARD':
          handleDrawFromDiscard();
          break;
        case 'SWAP_CARD':
          if (decision.payload) {
            setTimeout(() => {
              confirmSwap(decision.payload.handIndex);
              setTimeout(() => endTurnAfterAI(), Math.round(500 * speedMult));
            }, Math.round(300 * speedMult));
          }
          break;
        case 'DISCARD_DRAWN_CARD':
          discardDrawnCard();
          setTimeout(() => endTurnAfterAI(), Math.round(500 * speedMult));
          break;
        case 'USE_JACK':
          if (decision.payload) {
            handleUseJack(decision.payload.handIndex);
            setTimeout(() => endTurnAfterAI(), Math.round(500 * speedMult));
          }
          break;
        case 'USE_KING':
          if (decision.payload) {
            handleUseKing(
              decision.payload.targetPlayerId,
              decision.payload.myHandIndex,
              decision.payload.targetHandIndex
            );
            setTimeout(() => endTurnAfterAI(), Math.round(500 * speedMult));
          }
          break;
        case 'CALL_DAME':
          handleCallDame();
          setTimeout(() => endTurnAfterAI(), Math.round(500 * speedMult));
          break;
        case 'END_TURN':
          endTurnAfterAI();
          break;
      }
    }, Math.round(decision.delay * speedMult));
  }, []);

  // KI-Zug beenden und nächsten prüfen
  const endTurnAfterAI = useCallback(() => {
    handleEndTurn();
  }, []);

  // KI Post-Draw: wenn gezogene Karte gesetzt und KI am Zug
  useEffect(() => {
    if (!gameState || !drawnCard) return;

    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const aiDifficulty = aiPlayers.get(currentPlayer.id);

    if (aiDifficulty && !currentPlayer.isEliminated) {
      setIsAIThinking(true);
      executeAIMove(currentPlayer.id, aiDifficulty);

      const delay = Math.round((aiDifficulty === 'easy' ? 2000 : aiDifficulty === 'medium' ? 1500 : 1200) * speedMult);
      setTimeout(() => {
        setIsAIThinking(false);
      }, delay);
    }
  }, [drawnCard]);

  // Prüfe ob aktueller Spieler KI ist und führe Zug aus
  useEffect(() => {
    if (!gameState || isAIThinking) return;

    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const aiDifficulty = aiPlayers.get(currentPlayer.id);

    if (aiDifficulty && !currentPlayer.isEliminated) {
      setIsAIThinking(true);
      setGameMessage(`${currentPlayer.name} denkt...`);

      executeAIMove(currentPlayer.id, aiDifficulty);

      // Reset thinking status nach Verzögerung
      const delay = Math.round((aiDifficulty === 'easy' ? 2000 : aiDifficulty === 'medium' ? 1500 : 1200) * speedMult);
      setTimeout(() => {
        setIsAIThinking(false);
      }, delay);
    }
  }, [gameState?.currentPlayerIndex, gameState?.phase, isAIThinking]);

  const handleDrawFromDeck = useCallback(() => {
    if (!gameStateRef.current) return;
    
    const { card, newState } = drawFromDeck(gameStateRef.current);
    if (card) {
      gameStateRef.current = newState;
      setDrawnCard(card);
      setGameState(newState);
      
      const currentPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayers.has(currentPlayer.id);
      
      if (!isAI) {
        setGameMessage(`Du hast ${card.rank} gezogen. Was möchtest du tun?`);
      }
    }
  }, [aiPlayers]);

  const handleDrawFromDiscard = useCallback(() => {
    if (!gameStateRef.current) return;
    
    const { card, newState } = drawFromDiscard(gameStateRef.current);
    if (card) {
      gameStateRef.current = newState;
      setDrawnCard(card);
      setGameState(newState);
      
      const currentPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayers.has(currentPlayer.id);
      
      if (!isAI) {
        setGameMessage(`Du nimmst ${card.rank} vom Ablagestapel.`);
      }
    }
  }, [aiPlayers]);

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

    const isAI = aiPlayers.has(currentPlayer.id);
    
    // Spezialeffekte prüfen
    if (discardedCard.rank === 'Q') {
      const finalState = applyQueenEffect(newState, currentPlayer.id);
      setGameState(finalState);
      if (!isAI) {
        setGameMessage('Dame abgelegt! Du ziehst eine Strafkarte.');
      }
    } else if (discardedCard.rank === 'J') {
      if (!isAI) {
        setGameMessage('Bube abgelegt! Wähle eine Karte zum Anschauen.');
      }
    } else if (discardedCard.rank === 'K') {
      if (!isAI) {
        setGameMessage('König abgelegt! Wähle einen Spieler zum Tauschen.');
      }
    } else {
      if (!isAI) {
        setGameMessage(`Du hast ${discardedCard.rank} abgelegt.`);
      }
    }
  }, [selectedHandIndex, aiPlayers]);

  const discardDrawnCard = useCallback(() => {
    if (!gameStateRef.current || !drawnCardRef.current) return;

    const newState = discardCard(gameStateRef.current, drawnCardRef.current);
    gameStateRef.current = newState;
    setGameState(newState);
    setDrawnCard(null);
    
    const currentPlayer = newState.players[newState.currentPlayerIndex];
    const isAI = aiPlayers.has(currentPlayer.id);
    
    if (!isAI) {
      setGameMessage('Karte abgelegt.');
    }
  }, [aiPlayers]);

  const handleUseJack = useCallback((handIndex: number) => {
    if (!gameStateRef.current) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const newState = applyJackEffect(gameStateRef.current, currentPlayer.id, handIndex);
    gameStateRef.current = newState;
    setGameState(newState);
    
    const isAI = aiPlayers.has(currentPlayer.id);
    if (!isAI) {
      setGameMessage('Du kannst jetzt diese Karte sehen.');
    }
  }, [aiPlayers]);

  const handleUseKing = useCallback((
    targetPlayerId: string,
    myHandIndex: number,
    targetHandIndex: number
  ) => {
    if (!gameStateRef.current) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const newState = applyKingEffect(
      gameStateRef.current,
      currentPlayer.id,
      targetPlayerId,
      myHandIndex,
      targetHandIndex
    );
    gameStateRef.current = newState;
    setGameState(newState);
    
    const isAI = aiPlayers.has(currentPlayer.id);
    if (!isAI) {
      setGameMessage('Karten getauscht!');
    }
  }, [aiPlayers]);

  const handleCallDame = useCallback(() => {
    if (!gameStateRef.current) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const newState = callDame(gameStateRef.current, currentPlayer.id);
    gameStateRef.current = newState;
    setGameState(newState);
    setGameMessage(`${currentPlayer.name} hat Dame gerufen! Letzte Runde!`);
  }, []);

  const handleTryDiscardExtra = useCallback((cardId: string) => {
    if (!gameStateRef.current) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { success, newState } = discardExtraCard(gameStateRef.current, currentPlayer.id, cardId);
    gameStateRef.current = newState;
    setGameState(newState);
    
    const isAI = aiPlayers.has(currentPlayer.id);
    if (!isAI) {
      if (success) {
        setGameMessage('Extra-Karte abgelegt!');
      } else {
        setGameMessage('Falsche Karte! Strafkarte gezogen.');
      }
    }
  }, [aiPlayers]);

  const handleEndTurn = useCallback(() => {
    if (!gameStateRef.current) return;

    const prevRound = gameStateRef.current.round;
    const newState = endTurn(gameStateRef.current);

    // Wenn Runde gewechselt, endRound ausführen
    if (newState.turnInRound === 1 && newState.round > prevRound) {
      const roundEndState = endRound(newState);
      setGameState(roundEndState);

      const nextPlayer = roundEndState.players[roundEndState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(nextPlayer.id);
      if (!isAI) {
        if (roundEndState.phase === 'GAME_OVER') {
          setGameMessage('Spiel beendet!');
        } else {
          setGameMessage(`Runde ${roundEndState.round} beginnt! ${nextPlayer.name} startet.`);
        }
      }
    } else {
      setGameState(newState);
      const nextPlayer = newState.players[newState.currentPlayerIndex];
      const isAI = aiPlayersRef.current.has(nextPlayer.id);
      if (!isAI) {
        setGameMessage(`${nextPlayer.name} ist am Zug.`);
      }
    }
  }, []);

  const handleStartNextRound = useCallback(() => {
    if (!gameStateRef.current) return;
    const newState = startNextRound(gameStateRef.current);
    gameStateRef.current = newState;
    setGameState(newState);
    setGameMessage(`Runde ${newState.round} beginnt!`);
    drawnCardRef.current = null;
    setDrawnCard(null);
    setSelectedHandIndex(null);
  }, []);

  const resetGame = useCallback(() => {
    setGameState(null);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setGameMessage('Willkommen bei Dame!');
    setIsAIThinking(false);
    setAiPlayers(new Map());
  }, []);

  const winner = gameState ? getWinner(gameState) : null;
  const canCallDameNow = gameState ? canCallDame(gameState) : false;
  
  // Aktuelle KI-Schwierigkeit ermitteln
  const currentPlayer = gameState?.players[gameState.currentPlayerIndex];
  const currentAIDifficulty = currentPlayer ? aiPlayers.get(currentPlayer.id) || null : null;
  const isCurrentPlayerHuman = currentPlayer ? !aiPlayers.has(currentPlayer.id) : false;

  return {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
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
    callDame: handleCallDame,
    tryDiscardExtra: handleTryDiscardExtra,
    endTurn: handleEndTurn,
    startNextRound: handleStartNextRound,
    resetGame,
    canCallDameNow,
  };
}
