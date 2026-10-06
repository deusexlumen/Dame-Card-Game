import '@/test/gameBoardTestUtils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, fireEvent, within } from '@testing-library/react';
import { GameBoard } from './GameBoard';
import { useGameEngine } from '@/hooks/useGameEngine';
import {
  renderWithProviders,
  playerConfigs,
  createMockGameState,
  baseMockEngineReturn,
  resetGameBoardMocks,
  mockDrawFromDeck,
  mockDrawFromDiscard,
  mockSelectHandCard,
  mockConfirmSwap,
  mockDiscardDrawnCard,
  mockActivateJack,
  mockActivateKing,
  mockCallDame,
  mockEndTurn,
  mockStartNextRound,
} from '@/test/gameBoardTestUtils';

vi.mock('@/hooks/useGameEngine', async () => {
  const actual = await vi.importActual<typeof import('@/hooks/useGameEngine')>('@/hooks/useGameEngine');
  return {
    ...actual,
    useGameEngine: vi.fn(() => baseMockEngineReturn),
  };
});

describe('GameBoard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetGameBoardMocks();
    vi.mocked(useGameEngine).mockReturnValue(baseMockEngineReturn);
  });

  it('renders the turn overlay when turnOverlayOpen is true', () => {
    const mockedUseGameEngine = vi.mocked(useGameEngine);
    mockedUseGameEngine.mockReturnValue({
      ...baseMockEngineReturn,
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
      ...baseMockEngineReturn,
      gameState: createMockGameState(0),
      turnOverlayOpen: true,
    });

    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

    fireEvent.click(screen.getByText('Ich bin bereit'));
    expect(baseMockEngineReturn.confirmTurn).toHaveBeenCalledTimes(1);
  });

  it('does not render the turn overlay when turnOverlayOpen is false', () => {
    const mockedUseGameEngine = vi.mocked(useGameEngine);
    mockedUseGameEngine.mockReturnValue({
      ...baseMockEngineReturn,
      gameState: createMockGameState(0),
      turnOverlayOpen: false,
    });

    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

    expect(screen.queryByText('Anna ist dran')).not.toBeInTheDocument();
  });

  it('keeps the start dialog open when the overlay is clicked', () => {
    // Mock-Rückgabe vorheriger Tests zurücksetzen, damit kein laufendes Spiel gerendert wird
    vi.mocked(useGameEngine).mockReturnValue({ ...baseMockReturn });
    renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
    expect(screen.getByText('Kartenspiel mit Bluff und Strategie')).toBeInTheDocument();

    const overlay = document.querySelector('[data-slot="dialog-overlay"]');
    if (overlay) {
      fireEvent.mouseDown(overlay);
      fireEvent.mouseUp(overlay);
      fireEvent.click(overlay);
    }

    expect(screen.getByText('Kartenspiel mit Bluff und Strategie')).toBeInTheDocument();
  });

  describe('interactions', () => {
    it('calls drawFromDeck when the draw pile is clicked', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        isCurrentPlayerHuman: true,
        isAIThinking: false,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      const stacks = screen.getAllByLabelText('Stapel auswählen');
      fireEvent.click(stacks[0]);
      expect(mockDrawFromDeck).toHaveBeenCalledTimes(1);
    });

    it('calls drawFromDiscard when the discard pile is clicked', () => {
      const state = createMockGameState(0);
      state.discardPile = [{ id: 'd1', suit: 'hearts', rank: '5', value: 5, isVisible: true }];
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: state,
        isCurrentPlayerHuman: true,
        isAIThinking: false,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      const stacks = screen.getAllByLabelText('Stapel auswählen');
      fireEvent.click(stacks[1]);
      expect(mockDrawFromDiscard).toHaveBeenCalledTimes(1);
    });

    it('calls selectHandCard when a hand card is clicked while a card is drawn', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        drawnCard: { id: 'drawn', suit: 'spades', rank: 'J', value: 10, isVisible: true },
        isCurrentPlayerHuman: true,
        isAIThinking: false,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      const ownCards = screen.getAllByTestId('player-hand-card-0');
      fireEvent.click(within(ownCards[ownCards.length - 1]).getByRole('button'));
      expect(mockSelectHandCard).toHaveBeenCalledWith(0);
    });

    it('calls confirmSwap when the swap confirmation button is clicked', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        drawnCard: { id: 'drawn', suit: 'spades', rank: 'J', value: 10, isVisible: true },
        selectedHandIndex: 0,
        isCurrentPlayerHuman: true,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      fireEvent.click(screen.getByText('Tauschen bestätigen'));
      expect(mockConfirmSwap).toHaveBeenCalledTimes(1);
    });

    it('calls discardDrawnCard when the discard button is clicked', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        drawnCard: { id: 'drawn', suit: 'spades', rank: '4', value: 4, isVisible: true },
        isCurrentPlayerHuman: true,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      fireEvent.click(screen.getByText('Ablegen'));
      expect(mockDiscardDrawnCard).toHaveBeenCalledTimes(1);
    });

    it('opens the Jack effect dialog and calls activateJack', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        drawnCard: { id: 'drawn', suit: 'spades', rank: 'J', value: 10, isVisible: true },
        isCurrentPlayerHuman: true,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      fireEvent.click(screen.getByText('Bube'));
      expect(screen.getByText('Bube-Effekt')).toBeInTheDocument();

      const opponentSection = screen.getByText('Karten von Bob').closest('div') as HTMLElement;
      const opponentCard = within(opponentSection).getByTestId('jack-target-card-0');
      fireEvent.click(within(opponentCard).getByRole('button'));
      expect(mockActivateJack).toHaveBeenCalledWith('p2', 0);
    });

    it('opens the King effect dialog, selects opponent/card, and calls activateKing', () => {
      const engineState = {
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        drawnCard: { id: 'drawn', suit: 'spades' as const, rank: 'K' as const, value: 10, isVisible: true },
        isCurrentPlayerHuman: true,
      };
      vi.mocked(useGameEngine).mockReturnValue(engineState);

      const { rerender } = renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      fireEvent.click(screen.getByText('König'));
      expect(screen.getByText('König-Effekt')).toBeInTheDocument();

      const ownCards = screen.getAllByTestId(/king-own-card/);
      fireEvent.click(within(ownCards[0]).getByRole('button'));

      // Simulate engine selecting the own hand card
      vi.mocked(useGameEngine).mockReturnValue({ ...engineState, selectedHandIndex: 0 });
      rerender(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: 'Bob' }));
      const opponentCards = screen.getAllByTestId(/king-opponent-card/);
      fireEvent.click(within(opponentCards[0]).getByRole('button'));
      fireEvent.click(screen.getByText('Tauschen'));
      expect(mockActivateKing).toHaveBeenCalledWith('p2', 0, 0);
    });

    it('calls callDame and endTurn when the Dame button is clicked', () => {
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: createMockGameState(0),
        canCallDameNow: true,
        isCurrentPlayerHuman: true,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      fireEvent.click(screen.getByText('Dame rufen!'));
      expect(mockCallDame).toHaveBeenCalledTimes(1);
      expect(mockEndTurn).toHaveBeenCalledTimes(1);
    });

    it('renders the round end dialog and calls startNextRound', () => {
      const state = createMockGameState(0);
      state.phase = 'ROUND_END';
      state.players[0].score = 10;
      state.players[0].totalScore = 10;
      vi.mocked(useGameEngine).mockReturnValue({
        ...baseMockEngineReturn,
        gameState: state,
      });

      renderWithProviders(<GameBoard playerConfigs={playerConfigs} onBackToMenu={vi.fn()} />);
      expect(screen.getByText('Runde 1 beendet!')).toBeInTheDocument();
      expect(screen.getByText('+10 pts')).toBeInTheDocument();
      fireEvent.click(screen.getByText('Nächste Runde'));
      expect(mockStartNextRound).toHaveBeenCalledTimes(1);
    });
  });
});
