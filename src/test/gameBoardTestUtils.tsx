/* eslint-disable react-refresh/only-export-components */
import * as React from 'react';
import { render } from '@testing-library/react';
import { I18nProvider, useI18n } from '@/lib/i18n';
import type { PlayerConfig } from '@/hooks/useGameEngine';
import type { GameState } from '@/types/game';
import { vi } from 'vitest';

export const mockConfirmTurn = vi.fn();
export const mockStartGame = vi.fn();
export const mockLoadSavedGame = vi.fn();
export const mockDrawFromDeck = vi.fn();
export const mockDrawFromDiscard = vi.fn();
export const mockSelectHandCard = vi.fn();
export const mockConfirmSwap = vi.fn();
export const mockDiscardDrawnCard = vi.fn();
export const mockActivateJack = vi.fn();
export const mockActivateKing = vi.fn();
export const mockActivateAce = vi.fn();
export const mockActivateTen = vi.fn();
export const mockPeekKingTarget = vi.fn();
export const mockCallDame = vi.fn();
export const mockTryDiscardExtra = vi.fn();
export const mockEndTurn = vi.fn();
export const mockStartNextRound = vi.fn();
export const mockResetGame = vi.fn();
export const mockPauseTurnTimer = vi.fn();
export const mockResumeTurnTimer = vi.fn();

export function resetGameBoardMocks() {
  mockConfirmTurn.mockReset();
  mockStartGame.mockReset();
  mockLoadSavedGame.mockReset();
  mockDrawFromDeck.mockReset();
  mockDrawFromDiscard.mockReset();
  mockSelectHandCard.mockReset();
  mockConfirmSwap.mockReset();
  mockDiscardDrawnCard.mockReset();
  mockActivateJack.mockReset();
  mockActivateKing.mockReset();
  mockActivateAce.mockReset();
  mockActivateTen.mockReset();
  mockPeekKingTarget.mockReset();
  mockCallDame.mockReset();
  mockTryDiscardExtra.mockReset();
  mockEndTurn.mockReset();
  mockStartNextRound.mockReset();
  mockResetGame.mockReset();
  mockPauseTurnTimer.mockReset();
  mockResumeTurnTimer.mockReset();
}

export function createMockGameState(currentPlayerIndex = 0): GameState {
  return {
    players: [
      {
        id: 'p1',
        name: 'Anna',
        hand: [
          { id: 'c1', suit: 'hearts', rank: '7', value: 7, isVisible: false },
          { id: 'c2', suit: 'diamonds', rank: '8', value: 8, isVisible: false },
          { id: 'c3', suit: 'clubs', rank: '9', value: 9, isVisible: false },
          { id: 'c4', suit: 'spades', rank: '10', value: 10, isVisible: false },
        ],
        visibleCardIndices: [0, 1],
        score: 0,
        totalScore: 0,
        isActive: true,
        isEliminated: false,
        hasCalledDame: false,
        penaltyCards: [],
        memory: [],
        isAI: false,
        isHuman: true,
      },
      {
        id: 'p2',
        name: 'Bob',
        hand: [
          { id: 'c5', suit: 'hearts', rank: '2', value: 2, isVisible: false },
          { id: 'c6', suit: 'diamonds', rank: '3', value: 3, isVisible: false },
          { id: 'c7', suit: 'clubs', rank: '4', value: 4, isVisible: false },
          { id: 'c8', suit: 'spades', rank: '5', value: 5, isVisible: false },
        ],
        visibleCardIndices: [0, 1],
        score: 0,
        totalScore: 0,
        isActive: false,
        isEliminated: false,
        hasCalledDame: false,
        penaltyCards: [],
        memory: [],
        isAI: true,
        isHuman: false,
      },
    ],
    currentPlayerIndex,
    deck: [],
    discardPile: [],
    phase: 'FIRST_TURN',
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

export const baseMockEngineReturn = {
  gameState: null,
  drawnCard: null,
  selectedHandIndex: null,
  gameMessage: 'Willkommen!',
  messageKey: 'game.welcome',
  winner: null,
  isAIThinking: false,
  currentAIDifficulty: null,
  turnOverlayOpen: false,
  confirmTurn: mockConfirmTurn,
  startGame: mockStartGame,
  loadSavedGame: mockLoadSavedGame,
  hasSavedGame: false,
  drawFromDeck: mockDrawFromDeck,
  drawFromDiscard: mockDrawFromDiscard,
  selectHandCard: mockSelectHandCard,
  confirmSwap: mockConfirmSwap,
  discardDrawnCard: mockDiscardDrawnCard,
  activateJack: mockActivateJack,
  activateKing: mockActivateKing,
  activateAce: mockActivateAce,
  activateTen: mockActivateTen,
  peekKingTarget: mockPeekKingTarget,
  callDame: mockCallDame,
  tryDiscardExtra: mockTryDiscardExtra,
  endTurn: mockEndTurn,
  startNextRound: mockStartNextRound,
  resetGame: mockResetGame,
  canCallDameNow: false,
  isCurrentPlayerHuman: true,
  turnTimeLeft: null,
  pauseTurnTimer: mockPauseTurnTimer,
  resumeTurnTimer: mockResumeTurnTimer,
};

vi.mock('@/hooks/useGameStats', () => ({
  useGameStats: () => ({
    stats: { games: 0, wins: 0, rounds: 0, bestRound: 0, dameCalls: 0, successfulDameCalls: 0 },
    clear: vi.fn(),
    recordRound: vi.fn(),
    recordGame: vi.fn(),
  }),
}));

vi.mock('@/hooks/useSettings', () => ({
  useSettings: () => ({
    settings: {
      aiSpeed: 'normal',
      turnTimer: false,
      turnTimerSeconds: 30,
      powerEffects: true,
      musicEnabled: false,
      soundEnabled: true,
      table3d: false,
      defaultAIDifficulty: 'medium',
    },
  }),
}));

vi.mock('@/hooks/useSkins', () => ({
  useSkins: () => ({ activeSkins: {} }),
}));

vi.mock('@/lib/sounds', () => ({
  playCardDraw: vi.fn(),
  playCardPlace: vi.fn(),
  playCardFlip: vi.fn(),
  playDameCall: vi.fn(),
  playWinSound: vi.fn(),
  playPenaltySound: vi.fn(),
  startBackgroundMusic: vi.fn(),
  stopBackgroundMusic: vi.fn(),
}));

vi.mock('sonner', () => ({
  Toaster: () => null,
  toast: {
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
  },
}));

export const playerConfigs: PlayerConfig[] = [
  { name: 'Anna', isAI: false, isHuman: true },
  { name: 'Bob', isAI: true, isHuman: false, difficulty: 'easy' },
];

export function renderWithProviders(ui: React.ReactElement) {
  const { rerender: baseRerender, ...result } = render(
    <I18nProvider>
      <LanguageSetter />
      {ui}
    </I18nProvider>
  );

  return {
    ...result,
    rerender: (nextUi: React.ReactElement) =>
      baseRerender(
        <I18nProvider>
          <LanguageSetter />
          {nextUi}
        </I18nProvider>
      ),
  };
}

function LanguageSetter() {
  const { setLanguage } = useI18n();
  React.useEffect(() => {
    setLanguage('de');
  }, [setLanguage]);
  return null;
}
