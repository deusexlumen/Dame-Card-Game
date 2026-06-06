import { useState, useCallback } from 'react';
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
  canCallDame,
  discardExtraCard,
  getWinner,
} from '@/lib/gameLogic';

interface UseGameReturn {
  gameState: GameState | null;
  drawnCard: Card | null;
  selectedHandIndex: number | null;
  gameMessage: string;
  winner: Player | null;
  startGame: (playerNames: string[]) => void;
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
  resetGame: () => void;
  canCallDameNow: boolean;
}

export function useGame(): UseGameReturn {
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [drawnCard, setDrawnCard] = useState<Card | null>(null);
  const [selectedHandIndex, setSelectedHandIndex] = useState<number | null>(null);
  const [gameMessage, setGameMessage] = useState<string>('Willkommen bei Dame!');

  const startGame = useCallback((playerNames: string[]) => {
    const newGame = initializeGame(playerNames);
    setGameState(newGame);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setGameMessage('Spiel gestartet! Ziehe eine Karte.');
  }, []);

  const handleDrawFromDeck = useCallback(() => {
    if (!gameState) return;
    
    const { card, newState } = drawFromDeck(gameState);
    if (card) {
      setDrawnCard(card);
      setGameState(newState);
      setGameMessage(`Du hast ${card.rank}${card.suit} gezogen. Was möchtest du tun?`);
    }
  }, [gameState]);

  const handleDrawFromDiscard = useCallback(() => {
    if (!gameState) return;
    
    const { card, newState } = drawFromDiscard(gameState);
    if (card) {
      setDrawnCard(card);
      setGameState(newState);
      setGameMessage(`Du nimmst ${card.rank}${card.suit} vom Ablagestapel.`);
    }
  }, [gameState]);

  const selectHandCard = useCallback((index: number) => {
    setSelectedHandIndex(index);
  }, []);

  const confirmSwap = useCallback(() => {
    if (!gameState || !drawnCard || selectedHandIndex === null) return;
    
    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const { discardedCard, newState } = swapCard(
      gameState,
      currentPlayer.id,
      selectedHandIndex,
      drawnCard
    );
    
    setGameState(newState);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    
    // Spezialeffekte prüfen
    if (discardedCard.rank === 'Q') {
      // Dame abgelegt - Strafkarte!
      const finalState = applyQueenEffect(newState, currentPlayer.id);
      setGameState(finalState);
      setGameMessage('Dame abgelegt! Du ziehst eine Strafkarte.');
    } else if (discardedCard.rank === 'J') {
      setGameMessage('Bube abgelegt! Wähle eine Karte zum Anschauen.');
    } else if (discardedCard.rank === 'K') {
      setGameMessage('König abgelegt! Wähle einen Spieler zum Tauschen.');
    } else {
      setGameMessage(`Du hast ${discardedCard.rank} abgelegt.`);
    }
  }, [gameState, drawnCard, selectedHandIndex]);

  const discardDrawnCard = useCallback(() => {
    if (!gameState || !drawnCard) return;
    
    const newState = discardCard(gameState, drawnCard);
    setGameState(newState);
    setDrawnCard(null);
    setGameMessage('Karte abgelegt.');
  }, [gameState, drawnCard]);

  const handleUseJack = useCallback((handIndex: number) => {
    if (!gameState) return;
    
    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const newState = applyJackEffect(gameState, currentPlayer.id, handIndex);
    setGameState(newState);
    setGameMessage('Du kannst jetzt diese Karte sehen.');
  }, [gameState]);

  const handleUseKing = useCallback((
    targetPlayerId: string,
    myHandIndex: number,
    targetHandIndex: number
  ) => {
    if (!gameState) return;
    
    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const newState = applyKingEffect(
      gameState,
      currentPlayer.id,
      targetPlayerId,
      myHandIndex,
      targetHandIndex
    );
    setGameState(newState);
    setGameMessage('Karten getauscht!');
  }, [gameState]);

  const handleCallDame = useCallback(() => {
    if (!gameState) return;
    
    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const newState = callDame(gameState, currentPlayer.id);
    setGameState(newState);
    setGameMessage(`${currentPlayer.name} hat Dame gerufen! Letzte Runde!`);
  }, [gameState]);

  const handleTryDiscardExtra = useCallback((cardId: string) => {
    if (!gameState) return;
    
    const currentPlayer = gameState.players[gameState.currentPlayerIndex];
    const { success, newState } = discardExtraCard(gameState, currentPlayer.id, cardId);
    setGameState(newState);
    
    if (success) {
      setGameMessage('Extra-Karte abgelegt!');
    } else {
      setGameMessage('Falsche Karte! Strafkarte gezogen.');
    }
  }, [gameState]);

  const handleEndTurn = useCallback(() => {
    if (!gameState) return;
    
    const newState = endTurn(gameState);
    setGameState(newState);
    
    const nextPlayer = newState.players[newState.currentPlayerIndex];
    setGameMessage(`${nextPlayer.name} ist am Zug.`);
  }, [gameState]);

  const resetGame = useCallback(() => {
    setGameState(null);
    setDrawnCard(null);
    setSelectedHandIndex(null);
    setGameMessage('Willkommen bei Dame!');
  }, []);

  const winner = gameState ? getWinner(gameState) : null;
  const canCallDameNow = gameState ? canCallDame(gameState) : false;

  return {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
    winner,
    startGame,
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
    resetGame,
    canCallDameNow,
  };
}
