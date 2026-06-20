import * as React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { GameBoard } from './GameBoard';
import { I18nProvider, useI18n } from '@/lib/i18n';
import type { PlayerConfig } from '@/hooks/useGameEngine';
import type { GameState } from '@/types/game';

const mockConfirmTurn = vi.fn();
const mockStartGame = vi.fn();
const mockLoadSavedGame = vi.fn();
const mockDrawFromDeck = vi.fn();
const mockDrawFromDiscard = vi.fn();
const mockSelectHandCard = vi.fn();
const mockConfirmSwap = vi.fn();
const mockDiscardDrawnCard = vi.fn();
const mockActivateJack = vi.fn();
const mockActivateKing = vi.fn();
const mockActivateAce = vi.fn();
const mockActivateTen = vi.fn();
const mockPeekKingTarget = vi.fn();
const mockCallDame = vi.fn();
const mockTryDiscardExtra = vi.fn();
const mockEndTurn = vi.fn();
const mockStartNextRound = vi.fn();
const mockResetGame = vi.fn();
const mockPauseTurnTimer = vi.fn();
const mockResumeTurnTimer = vi.fn();

function createMockGameState(currentPlayerIndex = 0): GameState {
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

const baseMockReturn = {
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

vi.mock('@/hooks/useGameEngine', async () => {
  const actual = await vi.importActual<typeof import('@/hooks/useGameEngine')>('@/hooks/useGameEngine');
  return {
    ...actual,
    useGameEngine: vi.fn(() => baseMockReturn),
  };
});

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

import { useGameEngine } from '@/hooks/useGameEngine';

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <I18nProvider>
      <LanguageSetter />
      {ui}
    </I18nProvider>
  );
}

function LanguageSetter() {
  const { setLanguage } = useI18n();
  React.useEffect(() => {
    setLanguage('de');
  }, [setLanguage]);
  return null;
}

describe('GameBoard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const playerConfigs: PlayerConfig[] = [
    { name: 'Anna', isAI: false, isHuman: true },
    { name: 'Bob', isAI: true, isHuman: false, difficulty: 'easy' },
  ];

  it('renders the turn overlay when turnOverlayOpen is true', () => {
    const mockedUseGameEngine = vi.mocked(useGameEngine);
    mockedUseGameEngine.mockReturnValue({
      ...baseMockReturn,
      gameState: createMockGameState(0),
      turnOverlayOpen: true,
    });

    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

    expect(screen.getByText('Anna ist dran')).toBeInTheDocument();
    expect(screen.getByText('Andere Spieler bitte nicht hinschauen.')).toBeInTheDocument();
  });

  it('calls confirmTurn when the ready button is clicked', () => {
    const mockedUseGameEngine = vi.mocked(useGameEngine);
    mockedUseGameEngine.mockReturnValue({
      ...baseMockReturn,
      gameState: createMockGameState(0),
      turnOverlayOpen: true,
    });

    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

    fireEvent.click(screen.getByText('Ich bin bereit'));
    expect(mockConfirmTurn).toHaveBeenCalledTimes(1);
  });

  it('does not render the turn overlay when turnOverlayOpen is false', () => {
    const mockedUseGameEngine = vi.mocked(useGameEngine);
    mockedUseGameEngine.mockReturnValue({
      ...baseMockReturn,
      gameState: createMockGameState(0),
      turnOverlayOpen: false,
    });

    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

    expect(screen.queryByText('Anna ist dran')).not.toBeInTheDocument();
  });
});
