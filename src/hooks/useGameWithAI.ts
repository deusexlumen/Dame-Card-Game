import { useState, useCallback, useEffect, useRef } from 'react';
import type { GameState, Player, Card } from '@/types/game';
import {
  initializeGame,
  drawFromDeck,
  drawFromDiscard,
  swapCard,
  discardCard,
  useJackEffect,
  useKingEffect,
  useQueenEffect,
  callDame,
  endTurn,
  canCallDame,
  discardExtraCard,
  getWinner,
} from '@/lib/gameLogic';
import { decideAIMove, type AIDifficulty } from '@/lib/aiPlayer';

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
  drawFromDeck: () => void;
  drawFromDiscard: () => void;
  selectHandCard: (index: number) => void;
  confirmSwap: () => void;
  discardDrawnCard: () => void;
  useJack: (handIndex: number) => void;
  useKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
  callDame: () => void;
  tryDiscardExtra: (cardId: string) => void;
  endTurn: () => void;
  resetGame: () => void;
  canCallDameNow: boolean;
}

export function useGameWithAI(): UseGameWithAIReturn {
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [drawnCard, setDrawnCard] = useState<Card | null>(null);
  const [selectedHandIndex, setSelectedHandIndex] = useState<number | null>(null);
  const [gameMessage, setGameMessage] = useState<string>('Willkommen bei Dame!');
  const [isAIThinking, setIsAIThinking] = useState(false);
  const [aiPlayers, setAiPlayers] = useState<Map<string, AIDifficulty>>(new Map());
  
  // Ref für KI-Züge (um State in Timeout zu aktualisieren)
  const gameStateRef = useRef(gameState);
  const drawnCardRef = useRef(drawnCard);
  
  useEffect(() => {
    gameStateRef.current = gameState;
  }, [gameState]);
  
  useEffect(() => {
    drawnCardRef.current = drawnCard;
  }, [drawnCard]);

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
            setSelectedHandIndex(decision.payload.handIndex);
            setTimeout(() => confirmSwap(), 300);
          }
          break;
        case 'DISCARD_DRAWN_CARD':
          discardDrawnCard();
          break;
        case 'USE_JACK':
          if (decision.payload) {
            handleUseJack(decision.payload.handIndex);
            setTimeout(() => endTurnAfterAI(), 500);
          }
          break;
        case 'USE_KING':
          if (decision.payload) {
            handleUseKing(
              decision.payload.targetPlayerId,
              decision.payload.myHandIndex,
              decision.payload.targetHandIndex
            );
            setTimeout(() => endTurnAfterAI(), 500);
          }
          break;
        case 'CALL_DAME':
          handleCallDame();
          break;
        case 'END_TURN':
          endTurnAfterAI();
          break;
      }
    }, decision.delay);
  }, []);

  // KI-Zug beenden und nächsten prüfen
  const endTurnAfterAI = useCallback(() => {
    handleEndTurn();
  }, []);

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
      const delay = aiDifficulty === 'easy' ? 2000 : aiDifficulty === 'medium' ? 1500 : 1200;
      setTimeout(() => {
        setIsAIThinking(false);
      }, delay);
    }
  }, [gameState?.currentPlayerIndex, gameState?.phase]);

  const handleDrawFromDeck = useCallback(() => {
    if (!gameStateRef.current) return;
    
    const { card, newState } = drawFromDeck(gameStateRef.current);
    if (card) {
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

  const confirmSwap = useCallback(() => {
    if (!gameStateRef.current || !drawnCardRef.current || selectedHandIndex === null) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { discardedCard, newState } = swapCard(
      gameStateRef.current,
      currentPlayer.id,
      selectedHandIndex,
      drawnCardRef.current
    );
    
    setGameState(newState);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    
    const isAI = aiPlayers.has(currentPlayer.id);
    
    // Spezialeffekte prüfen
    if (discardedCard.rank === 'Q') {
      const finalState = useQueenEffect(newState, currentPlayer.id);
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
    const newState = useJackEffect(gameStateRef.current, currentPlayer.id, handIndex);
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
    const newState = useKingEffect(
      gameStateRef.current,
      currentPlayer.id,
      targetPlayerId,
      myHandIndex,
      targetHandIndex
    );
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
    setGameState(newState);
    setGameMessage(`${currentPlayer.name} hat Dame gerufen! Letzte Runde!`);
  }, []);

  const handleTryDiscardExtra = useCallback((cardId: string) => {
    if (!gameStateRef.current) return;
    
    const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];
    const { success, newState } = discardExtraCard(gameStateRef.current, currentPlayer.id, cardId);
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
    
    const newState = endTurn(gameStateRef.current);
    setGameState(newState);
    
    const nextPlayer = newState.players[newState.currentPlayerIndex];
    const isAI = aiPlayers.has(nextPlayer.id);
    
    if (!isAI) {
      setGameMessage(`${nextPlayer.name} ist am Zug.`);
    }
  }, [aiPlayers]);

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

  return {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
    winner,
    isAIThinking,
    currentAIDifficulty,
    startGame,
    drawFromDeck: handleDrawFromDeck,
    drawFromDiscard: handleDrawFromDiscard,
    selectHandCard,
    confirmSwap,
    discardDrawnCard,
    useJack: handleUseJack,
    useKing: handleUseKing,
    callDame: handleCallDame,
    tryDiscardExtra: handleTryDiscardExtra,
    endTurn: handleEndTurn,
    resetGame,
    canCallDameNow,
  };
}
