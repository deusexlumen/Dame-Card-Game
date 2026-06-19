import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useGameWithAI } from '@/hooks/useGameWithAI';
import { useGameStats } from '@/hooks/useGameStats';
import { StatsPanel } from './StatsPanel';
import { CardComponent, CardStack } from './Card';
import { PlayerHand } from './PlayerHand';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { cn } from '@/lib/utils';
import { useI18n } from '@/lib/i18n';
import { 
  Play, 
  RotateCcw, 
  Eye, 
  Crown, 
  AlertCircle,
  ChevronRight,
  Bot,
  Brain,
  Zap,
  Target,
  Home,
} from 'lucide-react';
import type { AIDifficulty } from '@/lib/aiPlayer';
import type { Card, GameConfig } from '@/types/game';
import { playCardDraw, playCardPlace, playCardFlip, playDameCall, playWinSound, playPenaltySound, startBackgroundMusic, stopBackgroundMusic } from '@/lib/sounds';
import { setGlobalSettings } from '@/lib/settings';
import { useSettings } from '@/hooks/useSettings';
import { Toaster, toast } from 'sonner';

interface GameBoardProps {
  players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>;
  onBackToMenu: () => void;
  gameConfig: GameConfig;
}

const DIFFICULTY_ICONS: Record<AIDifficulty, React.ReactNode> = {
  easy: <Zap className="w-4 h-4" />,
  medium: <Brain className="w-4 h-4" />,
  hard: <Target className="w-4 h-4" />,
};

const DIFFICULTY_COLORS: Record<AIDifficulty, string> = {
  easy: 'text-green-400',
  medium: 'text-yellow-400',
  hard: 'text-red-400',
};

export function GameBoard({ players, onBackToMenu, gameConfig }: GameBoardProps) {
  const { stats, clear, recordRound, recordGame } = useGameStats();
  const { settings } = useSettings();
  const { t } = useI18n();

  const {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
    messageKey,
    winner,
    isAIThinking,
    currentAIDifficulty,
    startGame,
    loadSavedGame,
    hasSavedGame,
    drawFromDeck,
    drawFromDiscard,
    selectHandCard,
    confirmSwap,
    discardDrawnCard,
    activateJack,
    activateKing,
    peekKingTarget,
    callDame,
    endTurn,
    startNextRound,
    resetGame,
    canCallDameNow,
    isCurrentPlayerHuman,
    tryDiscardExtra,
    turnTimeLeft,
    pauseTurnTimer,
    resumeTurnTimer,
  } = useGameWithAI(settings.aiSpeed, { recordRound, recordGame }, gameConfig);

  // Globale Settings für Sound-Engine synchronisieren
  useEffect(() => {
    setGlobalSettings(settings);
  }, [settings]);

  // {t('settings.music')} steuern
  useEffect(() => {
    if (gameState && settings.musicEnabled) {
      startBackgroundMusic();
    } else {
      stopBackgroundMusic();
    }
    return () => {
      stopBackgroundMusic();
    };
  }, [gameState, settings.musicEnabled]);

  const [showStartDialog, setShowStartDialog] = useState(true);
  const [peekPhase, setPeekPhase] = useState(false);
  const [showJackEffect, setShowJackEffect] = useState(false);
  const [showKingEffect, setShowKingEffect] = useState(false);
  const [showTutorial, setShowTutorial] = useState(false);
  const [kingTargetPlayer, setKingTargetPlayer] = useState<string | null>(null);
  const [kingTargetCardIndex, setKingTargetCardIndex] = useState<number | null>(null);
  const [kingPeekedCard, setKingPeekedCard] = useState<Card | null>(null);

  // Prüfe ob aktueller Spieler ein menschlicher Spieler ist
  const isHumanTurn = isCurrentPlayerHuman;

  // Keyboard-Shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Nur wenn kein Dialog offen ist
      if (showStartDialog || showJackEffect || showKingEffect || showTutorial || winner) return;
      // Nur wenn menschlicher Spieler am Zug
      if (!isHumanTurn || isAIThinking) return;
      // Ignorieren wenn Input-Feld fokussiert
      if (['INPUT', 'TEXTAREA', 'BUTTON'].includes((e.target as HTMLElement).tagName)) return;

      const key = e.key.toLowerCase();

      switch (key) {
        case ' ': // Leertaste: Ziehen oder Ablegen
          e.preventDefault();
          if (!drawnCard) {
            playCardDraw();
            drawFromDeck();
          } else {
            playCardPlace();
            discardDrawnCard();
          }
          break;
        case '1':
        case '2':
        case '3':
        case '4': {
          // Karte 1-4 auswählen
          e.preventDefault();
          const cardIndex = parseInt(key) - 1;
          if (drawnCard && isHumanTurn && cardIndex >= 0 && cardIndex < 4) {
            selectHandCard(cardIndex);
          }
          break;
        }
        case 'enter':
          // Tausch bestätigen
          e.preventDefault();
          if (drawnCard && selectedHandIndex !== null) {
            playCardPlace();
            confirmSwap();
          }
          break;
        case 'd':
          // Dame rufen
          e.preventDefault();
          if (canCallDameNow && !drawnCard) {
            playDameCall();
            callDame();
            endTurn();
          }
          break;
        case 'z':
        case 'e':
          // {t('game.endTurn')}
          e.preventDefault();
          if (!drawnCard) {
            playCardPlace();
            endTurn();
          }
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [
    showStartDialog, showJackEffect, showKingEffect, showTutorial, winner,
    isHumanTurn, isAIThinking, drawnCard, selectedHandIndex, canCallDameNow,
    drawFromDeck, discardDrawnCard, selectHandCard, confirmSwap, callDame, endTurn
  ]);

  // Sieges-Sound wenn Gewinner feststeht
  useEffect(() => {
    if (winner) {
      playWinSound();
    }
  }, [winner]);

  // Strafkarten-Sound
  useEffect(() => {
    if (messageKey === 'game.queenDiscarded' || messageKey === 'game.extraDiscardFail') {
      playPenaltySound();
      toast.error(t('game.penaltyCardReceived'), {
        description: gameMessage,
        duration: 3000,
      });
    }
  }, [messageKey, gameMessage, t]);

  // Toast-Benachrichtigungen für wichtige Ereignisse
  useEffect(() => {
    switch (messageKey) {
      case 'game.extraDiscardSuccess':
        toast.success(t('game.extraDiscardSuccess'), {
          description: gameMessage,
          duration: 3000,
        });
        break;
      case 'game.jackDiscarded':
        toast.info(t('game.jackEffectActivated'), {
          description: t('game.jackEffectHint'),
          duration: 3000,
        });
        break;
      case 'game.kingDiscarded':
        toast.info(t('game.kingEffectActivated'), {
          description: t('game.kingEffectHint'),
          duration: 3000,
        });
        break;
    }
  }, [messageKey, gameMessage, t]);

  // Spiel starten: zeige zuerst die eigenen Karten zum Merken
  const handleStart = () => {
    playCardFlip();
    startGame(players);
    setShowStartDialog(false);
    setPeekPhase(true);
  };

  // Peek-Phase beenden und ins eigentliche Spiel wechseln
  const handleReady = () => {
    playCardFlip();
    setPeekPhase(false);
  };

  // Spiel zurücksetzen
  const handleReset = () => {
    playCardFlip();
    resetGame();
    setShowStartDialog(true);
    setPeekPhase(false);
  };

  // Index des menschlichen Spielers in gameState.players
  const humanPlayerIndex = players.findIndex(p => !p.isAI);
  const isHumanEliminated = humanPlayerIndex >= 0
    ? (gameState?.players[humanPlayerIndex]?.isEliminated ?? false)
    : false;

  if (!gameState) {
    return (
      <Dialog open={showStartDialog} onOpenChange={setShowStartDialog}>
        <DialogContent className="sm:max-w-md bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-2xl text-center">{t('app.title')}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-center text-[hsl(var(--terminal-green)/0.85)]">
              {t('game.startDialogSubtitle')}
            </p>
            <div className="bg-[hsl(var(--terminal-panel))] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg text-sm space-y-2">
              <p className="text-[hsl(var(--terminal-green))]"><strong>{t('game.startDialogRules')}:</strong></p>
              <ul className="list-disc list-inside space-y-1 text-[hsl(var(--terminal-green)/0.85)]">
                <li>{t('game.startDialogRuleList.cards')}</li>
                <li>{t('game.startDialogRuleList.goal')}</li>
                <li>{t('game.startDialogRuleList.over50')}</li>
                <li>{t('game.startDialogRuleList.exact50')}</li>
                <li>{t('game.startDialogRuleList.jack')}</li>
                <li>{t('game.startDialogRuleList.king')}</li>
                <li>{t('game.startDialogRuleList.queen')}</li>
              </ul>
            </div>
            <div className="bg-[hsl(var(--terminal-cyan)/0.08)] border border-[hsl(var(--terminal-cyan)/0.2)] p-3 rounded-lg">
              <p className="text-[hsl(var(--terminal-cyan))] font-medium flex items-center gap-2">
                <Bot className="w-4 h-4" />
                {t('game.aiOpponents')}
              </p>
              <p className="text-[hsl(var(--terminal-green)/0.85)] text-sm">
                {t('game.aiOpponentsDescription', { count: players.filter(p => p.isAI).length })}
              </p>
            </div>
            <div className="flex justify-center">
              <StatsPanel stats={stats} onReset={clear} />
            </div>
            {hasSavedGame && (
              <Button
                onClick={() => {
                  playCardFlip();
                  const loaded = loadSavedGame();
                  if (loaded) setShowStartDialog(false);
                }}
                variant="secondary"
                className="w-full"
              >
                <RotateCcw className="w-4 h-4 mr-2" />
                {t('game.continueGame')}
              </Button>
            )}
            <Button
              onClick={() => setShowTutorial(true)}
              variant="outline"
              className="w-full"
            >
              <Eye className="w-4 h-4 mr-2" />
              {t('game.tutorial')}
            </Button>
            <Button onClick={handleStart} className="w-full">
              <Play className="w-4 h-4 mr-2" />
              {t('menu.newGame')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    );
  }

  // Peek-Phase: Spieler darf seine beiden gesehenen Karten kurz anschauen
  if (peekPhase && humanPlayerIndex >= 0) {
    const humanPlayer = gameState.players[humanPlayerIndex];
    return (
      <div className="min-h-screen terminal-grid p-4 flex flex-col items-center justify-center">
        <div className="max-w-2xl w-full bg-[hsl(var(--terminal-panel))] border border-[hsl(var(--terminal-green)/0.3)] rounded-xl p-6 sm:p-8 text-center space-y-6">
          <h2 className="text-2xl sm:text-3xl font-bold text-[hsl(var(--terminal-green))]">
            {t('game.peekTitle')}
          </h2>
          <p className="text-[hsl(var(--terminal-green)/0.85)]">
            {t('game.peekDescription')}
          </p>
          <div className="flex justify-center">
            <PlayerHand
              player={humanPlayer}
              isCurrentPlayer={true}
              isActivePlayer={false}
              gamePhase={gameState.phase}
              peekPhase={true}
              size="lg"
            />
          </div>
          <Button onClick={handleReady} size="lg" className="w-full sm:w-auto">
            <Play className="w-5 h-5 mr-2" />
            {t('game.ready')}
          </Button>
        </div>
      </div>
    );
  }

  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  const topDiscardCard = gameState.discardPile.length > 0 
    ? gameState.discardPile[gameState.discardPile.length - 1] 
    : null;

  const mustTakeQueen =
    topDiscardCard?.rank === 'Q' &&
    !gameState.safePhase &&
    gameState.phase !== 'DAME_CALLED' &&
    gameState.phase !== 'ROUND_END' &&
    gameState.phase !== 'GAME_OVER' &&
    !drawnCard;

  // Wenn menschlicher Spieler eliminiert wurde, zeige Zuschauer-Modus
  if (isHumanEliminated) {
    return (
      <div className="min-h-screen terminal-grid p-4">
        <div className="flex flex-col items-center justify-center h-screen">
          <div className="text-6xl mb-4">👀</div>
          <h2 className="text-3xl font-bold text-[hsl(var(--terminal-green))] mb-2">{t('game.youAreEliminated')}</h2>
          <p className="text-[hsl(var(--terminal-green)/0.7)] mb-6">{t('game.eliminatedWatch')}</p>
          <Button onClick={handleReset}>
            <RotateCcw className="w-4 h-4 mr-2" />
            {t('menu.newGame')}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen felt-texture relative p-2 sm:p-4">
      {/* Header */}
      <div className="flex justify-between items-start sm:items-center mb-3 sm:mb-4 gap-2">
        <div className="flex items-center gap-1.5 sm:gap-3 flex-wrap">
          <h1 className="text-lg sm:text-2xl font-bold text-[hsl(var(--terminal-green))]">{t('app.title')}</h1>
          <div className="bg-[hsl(var(--terminal-green)/0.15)] border border-[hsl(var(--terminal-green)/0.25)] px-2 sm:px-3 py-0.5 sm:py-1 rounded-full text-[hsl(var(--terminal-green))] text-[10px] sm:text-sm">
            {t('game.round', { round: gameState.round })}
          </div>
          {gameState.safePhase && (
            <div className="bg-yellow-500/80 px-2 sm:px-3 py-0.5 sm:py-1 rounded-full text-white text-[10px] sm:text-sm">
              {t('game.safePhase')}
            </div>
          )}
          {isAIThinking && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              className="bg-purple-500/80 px-2 sm:px-3 py-0.5 sm:py-1 rounded-full text-white text-[10px] sm:text-sm flex items-center gap-1.5"
            >
              <motion.div
                animate={{ rotate: [0, 15, -15, 0] }}
                transition={{ duration: 0.5, repeat: Infinity }}
              >
                <Bot className="w-3 h-3" />
              </motion.div>
              {t('game.aiThinking')}
            </motion.div>
          )}
          {gameConfig.turnTimer.enabled && turnTimeLeft !== null && isCurrentPlayerHuman && !isAIThinking && (
            <div className={cn(
              "px-2 sm:px-3 py-0.5 sm:py-1 rounded-full text-white text-[10px] sm:text-sm font-mono",
              turnTimeLeft <= 5 ? "bg-red-500/90 animate-pulse" : "bg-[hsl(var(--terminal-cyan)/0.8)]"
            )}>
              {turnTimeLeft}s
            </div>
          )}
        </div>
        <div className="flex gap-1 sm:gap-2 shrink-0">
          <Button variant="outline" size="sm" onClick={() => setShowTutorial(true)} aria-label={t('game.tutorial')} className="h-9 w-9 sm:h-10 sm:w-10 p-0">
            <Eye className="w-4 h-4 sm:w-5 sm:h-5" />
          </Button>
          <Button variant="outline" size="sm" onClick={onBackToMenu} aria-label={t('menu.backToMenu')} className="h-9 w-9 sm:h-10 sm:w-10 p-0">
            <Home className="w-4 h-4 sm:w-5 sm:h-5" />
          </Button>
          <Button variant="outline" size="sm" onClick={handleReset} aria-label={t('game.restart')} className="h-9 px-2 sm:h-10 sm:px-3 text-[10px] sm:text-sm">
            <RotateCcw className="w-4 h-4 sm:w-5 sm:h-5 mr-1" />
            <span className="hidden sm:inline">{t('game.restart')}</span>
          </Button>
          <Button variant="outline" size="sm" onClick={onBackToMenu} aria-label={t('game.backToMenu')} className="h-9 px-2 sm:h-10 sm:px-3 text-[10px] sm:text-sm">
            {t('game.backToMenu')}
          </Button>
        </div>
      </div>

      {/* Spieltisch */}
      <div className="max-w-6xl mx-auto">
        {/* Obere Reihe - Gegner */}
        <div className="flex justify-center gap-2 sm:gap-4 mb-4 sm:mb-6 flex-wrap">
          {gameState.players.filter((_, idx) => idx !== humanPlayerIndex).map((player) => {
            const originalIdx = gameState.players.indexOf(player);
            const originalPlayer = players[originalIdx];
            const isAI = originalPlayer?.isAI;
            const difficulty = originalPlayer?.difficulty;
            const humanPlayer = gameState.players[humanPlayerIndex >= 0 ? humanPlayerIndex : 0];
            const peekedIndices = humanPlayer?.memory
              .filter((entry) => entry.targetPlayerId === player.id)
              .map((entry) => entry.index) ?? [];

            return (
              <motion.div
                key={player.id}
                className="relative scale-75 sm:scale-100 origin-top"
                animate={
                  gameState.currentPlayerIndex === gameState.players.indexOf(player)
                    ? { scale: [1, 1.02, 1], y: [0, -3, 0] }
                    : {}
                }
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
              >
                <PlayerHand
                  player={player}
                  isCurrentPlayer={false}
                  isActivePlayer={gameState.currentPlayerIndex === gameState.players.indexOf(player)}
                  gamePhase={gameState.phase}
                  size="sm"
                  peekedIndices={peekedIndices}
                />
                {isAI && difficulty && (
                  <div className={cn(
                    "absolute -top-2 -right-2 w-6 h-6 rounded-full flex items-center justify-center bg-[hsl(var(--terminal-dark))]",
                    DIFFICULTY_COLORS[difficulty]
                  )}>
                    {DIFFICULTY_ICONS[difficulty]}
                  </div>
                )}
              </motion.div>
            );
          })}
        </div>

        {/* Mitte - Spielstapel */}
        <div className="flex justify-center items-center gap-4 sm:gap-8 mb-4 sm:mb-6">
          {/* {t('game.drawPile')} */}
          <CardStack
            count={gameState.deck.length}
            label={t('game.drawPile')}
            onClick={() => { playCardDraw(); drawFromDeck(); }}
            isClickable={isHumanTurn && !drawnCard && !isAIThinking && !mustTakeQueen}
            size="md"
          />

          {/* Spiel-Info */}
          <div className="bg-[hsl(var(--terminal-green)/0.1)] border border-[hsl(var(--terminal-green)/0.2)] backdrop-blur-sm rounded-xl p-2 sm:p-4 text-center min-w-[110px] sm:min-w-[180px] max-w-[45%]">
            <p className="text-[hsl(var(--terminal-green)/0.8)] text-[10px] sm:text-sm mb-0.5 sm:mb-1">{t('game.currentPlayer')}</p>
            <p className="text-[hsl(var(--terminal-green))] text-sm sm:text-lg font-bold mb-0.5 sm:mb-1 truncate">{currentPlayer.name}</p>
            <div role="status" aria-live="polite" aria-atomic="true" className="text-yellow-300 text-[10px] sm:text-xs leading-tight">
              {gameMessage}
            </div>
            {currentAIDifficulty && (
              <div className={cn(
                "mt-1 sm:mt-2 inline-flex items-center gap-1 px-1.5 sm:px-2 py-0.5 sm:py-1 rounded-full text-[10px] sm:text-xs",
                "bg-[hsl(var(--terminal-dark)/0.5)]",
                DIFFICULTY_COLORS[currentAIDifficulty]
              )}>
                <Bot className="w-3 h-3" />
                {currentAIDifficulty === 'easy' && t('menu.difficulty.easy')}
                {currentAIDifficulty === 'medium' && t('menu.difficulty.medium')}
                {currentAIDifficulty === 'hard' && t('menu.difficulty.hard')}
              </div>
            )}
          </div>

          {/* {t('game.discardPile')} */}
          <CardStack
            count={gameState.discardPile.length}
            label={t('game.discardPile')}
            topCard={topDiscardCard}
            onClick={() => { playCardDraw(); drawFromDiscard(); }}
            isClickable={isHumanTurn && !drawnCard && !!topDiscardCard && !isAIThinking}
            size="md"
          />
        </div>

        {/* {t('game.drawnCard')} (falls vorhanden) */}
        <AnimatePresence>
          {drawnCard && isHumanTurn && (
            <motion.div
              key="drawn-card"
              initial={{ opacity: 0, y: -50, scale: 0.5, rotateY: 180 }}
              animate={{ opacity: 1, y: 0, scale: 1, rotateY: 0 }}
              exit={{ opacity: 0, y: 50, scale: 0.5 }}
              transition={{ type: 'spring' as const, stiffness: 200, damping: 20 }}
              className="flex justify-center mb-4"
            >
              <div className="bg-[hsl(var(--terminal-green)/0.15)] border border-[hsl(var(--terminal-green)/0.25)] backdrop-blur-sm rounded-xl p-3 sm:p-4">
                <p className="text-[hsl(var(--terminal-green))] text-center mb-2 text-sm sm:text-base">{t('game.drawnCard')}</p>
                <div className="flex justify-center">
                  <CardComponent card={drawnCard} isVisible={true} size="md" animate={false} />
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Aktions-Buttons */}
        {isHumanTurn && !isAIThinking && (
          <div className="flex justify-center gap-2 sm:gap-3 mb-4 sm:mb-6 flex-wrap px-2">
            {drawnCard && (
              <>
                <Button
                  onClick={() => setShowJackEffect(true)}
                  disabled={drawnCard.rank !== 'J'}
                  variant={drawnCard.rank === 'J' ? 'default' : 'outline'}
                  size="default"
                  className="h-11 px-3 text-xs sm:text-sm"
                >
                  <Eye className="w-4 h-4 sm:w-5 sm:h-5 mr-1.5" />
                  {t('game.jack')}
                </Button>
                <Button
                  onClick={() => setShowKingEffect(true)}
                  disabled={drawnCard.rank !== 'K'}
                  variant={drawnCard.rank === 'K' ? 'default' : 'outline'}
                  size="default"
                  className="h-11 px-3 text-xs sm:text-sm"
                >
                  <Crown className="w-4 h-4 sm:w-5 sm:h-5 mr-1.5" />
                  {t('game.king')}
                </Button>
                <Button
                  onClick={() => { playCardPlace(); discardDrawnCard(); }}
                  variant="secondary"
                  size="default"
                  className="h-11 px-3 text-xs sm:text-sm"
                >
                  {t('game.discard')}
                </Button>
              </>
            )}

            {canCallDameNow && !drawnCard && (
              <motion.div
                animate={{
                  scale: [1, 1.1, 1],
                  boxShadow: [
                    '0 0 0 0 rgba(239,68,68,0)',
                    '0 0 0 10px rgba(239,68,68,0.3)',
                    '0 0 0 0 rgba(239,68,68,0)',
                  ],
                }}
                transition={{ duration: 1.5, repeat: Infinity, ease: 'easeInOut' as const }}
              >
                <Button
                  onClick={() => { playDameCall(); callDame(); endTurn(); }}
                  variant="destructive"
                  size="default"
                  className="h-11 px-3 text-xs sm:text-sm"
                >
                  <AlertCircle className="w-4 h-4 sm:w-5 sm:h-5 mr-1.5" />
                  {t('game.callDame')}
                </Button>
              </motion.div>
            )}

            {!drawnCard && (
              <Button onClick={() => { playCardPlace(); endTurn(); }} size="default" className="h-11 px-4 text-xs sm:text-sm">
                {t('game.endTurn')}
                <ChevronRight className="w-4 h-4 sm:w-5 sm:h-5 ml-1.5" />
              </Button>
            )}
          </div>
        )}

        {/* Untere Reihe - Eigene Hand */}
        <div className="flex justify-center px-2">
          <PlayerHand
            player={gameState.players[humanPlayerIndex >= 0 ? humanPlayerIndex : 0]}
            isCurrentPlayer={true}
            isActivePlayer={isHumanTurn}
            onCardSelectForSwap={drawnCard && isHumanTurn ? selectHandCard : undefined}
            onCardSelectForExtraDiscard={
              topDiscardCard && isHumanTurn && !drawnCard && !isAIThinking && humanPlayerIndex >= 0
                ? (idx) => {
                    const card = gameState.players[humanPlayerIndex].hand[idx];
                    if (card.rank === topDiscardCard.rank) {
                      playCardPlace();
                      tryDiscardExtra(card.id);
                    }
                  }
                : undefined
            }
            selectedCardIndex={selectedHandIndex}
            gamePhase={gameState.phase}
            size="md"
          />
        </div>

        {/* Tausch-Bestätigung */}
        {drawnCard && selectedHandIndex !== null && isHumanTurn && (
          <motion.div
            initial={{ y: 100, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            className="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50 w-[calc(100%-2rem)] max-w-sm"
          >
            <Button onClick={() => { playCardPlace(); confirmSwap(); }} size="lg" className="w-full h-12 shadow-xl text-sm sm:text-base">
              {t('game.swapConfirm')}
            </Button>
          </motion.div>
        )}
      </div>

      {/* Bube-Effekt Dialog */}
      <Dialog open={showJackEffect} onOpenChange={(open) => {
        setShowJackEffect(open);
        if (open) {
          pauseTurnTimer();
        } else {
          resumeTurnTimer();
        }
      }}>
        <DialogContent className="sm:max-w-3xl max-h-[90vh] overflow-y-auto bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Eye className="w-5 h-5" />
              {t('game.jackEffect')}
            </DialogTitle>
          </DialogHeader>
          <p className="text-[hsl(var(--terminal-green)/0.85)] mb-4">
            {t('game.jackEffectDescription')}
          </p>
          <div className="space-y-4 max-h-[60vh] overflow-y-auto">
            {gameState.players.map((player) => {
              const humanPlayer = gameState.players[humanPlayerIndex >= 0 ? humanPlayerIndex : 0];
              const playerPeekedIndices = humanPlayer?.memory
                .filter((entry) => entry.targetPlayerId === player.id)
                .map((entry) => entry.index) ?? [];

              return (
                <div key={player.id} className="space-y-1">
                  <p className="text-[hsl(var(--terminal-cyan))] text-sm font-medium">
                    {player.id === humanPlayer?.id ? t('game.yourCards') : t('game.opponentCards', { name: player.name })}
                  </p>
                  <div className="flex justify-center">
                    <PlayerHand
                      player={player}
                      isCurrentPlayer={player.id === humanPlayer?.id}
                      isActivePlayer={true}
                      onCardSelectForJack={(idx) => {
                        playCardFlip();
                        activateJack(player.id, idx);
                        setShowJackEffect(false);
                      }}
                      peekedIndices={playerPeekedIndices}
                      gamePhase={gameState.phase}
                      size="md"
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </DialogContent>
      </Dialog>

      {/* König-Effekt Dialog */}
      <Dialog open={showKingEffect} onOpenChange={(open) => {
        setShowKingEffect(open);
        if (open) {
          pauseTurnTimer();
        } else {
          resumeTurnTimer();
          setKingTargetPlayer(null);
          setKingTargetCardIndex(null);
          setKingPeekedCard(null);
        }
      }}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Crown className="w-5 h-5" />
              {t('game.kingEffect')}
            </DialogTitle>
          </DialogHeader>
          <p className="text-[hsl(var(--terminal-green)/0.85)] mb-4">
            {t('game.kingEffectDescription')}
          </p>

          {/* Eigene Karten */}
          <div className="mb-4">
            <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">{t('game.yourCards')}</p>
            <div className="flex justify-center">
              <PlayerHand
                player={gameState.players[humanPlayerIndex >= 0 ? humanPlayerIndex : 0]}
                isCurrentPlayer={true}
                isActivePlayer={false}
                onCardSelectForSwap={selectHandCard}
                selectedCardIndex={selectedHandIndex}
                gamePhase={gameState.phase}
                size="sm"
              />
            </div>
          </div>

          {/* Gegner auswählen */}
          {selectedHandIndex !== null && (
            <div className="mb-4">
              <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">{t('game.chooseOpponent')}</p>
              <div className="flex gap-2 flex-wrap">
                {gameState.players.filter((_, idx) => idx !== humanPlayerIndex).map((player) => (
                  <Button
                    key={player.id}
                    variant="outline"
                    aria-pressed={kingTargetPlayer === player.id}
                    onClick={() => {
                      setKingTargetPlayer(player.id);
                      setKingTargetCardIndex(null);
                      setKingPeekedCard(null);
                    }}
                    className={cn(
                      'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]',
                      kingTargetPlayer === player.id && 'ring-2 ring-[hsl(var(--terminal-amber))]'
                    )}
                  >
                    {player.name}
                  </Button>
                ))}
              </div>
            </div>
          )}

          {/* Gegner-Karte auswählen */}
          {selectedHandIndex !== null && kingTargetPlayer && (
            <div className="mb-4">
              <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">{t('game.chooseOpponentCard')}</p>
              <div className="flex justify-center">
                <PlayerHand
                  player={gameState.players.find(p => p.id === kingTargetPlayer)!}
                  isCurrentPlayer={false}
                  isActivePlayer={true}
                  onCardSelectForJack={(cardIndex) => {
                    const card = peekKingTarget(kingTargetPlayer, cardIndex);
                    setKingTargetCardIndex(cardIndex);
                    setKingPeekedCard(card);
                  }}
                  peekedIndices={kingTargetCardIndex !== null ? [kingTargetCardIndex] : []}
                  gamePhase={gameState.phase}
                  size="md"
                />
              </div>
              {kingPeekedCard && (
                <p className="text-center text-[hsl(var(--terminal-amber))] text-sm mt-2">
                  {t('game.youReceive')}{' '}
                  <span
                    aria-label={t('game.memoryIndicator')}
                  >
                    {kingPeekedCard.rank}{kingPeekedCard.suit === 'hearts' ? '♥' : kingPeekedCard.suit === 'diamonds' ? '♦' : kingPeekedCard.suit === 'clubs' ? '♣' : '♠'}
                  </span>
                </p>
              )}
            </div>
          )}

          {/* {t('game.swapConfirm')} oder abbrechen */}
          {selectedHandIndex !== null && kingTargetPlayer && kingTargetCardIndex !== null && (
            <div className="flex gap-2 mt-4">
              <Button
                variant="outline"
                onClick={() => {
                  setShowKingEffect(false);
                  setKingTargetPlayer(null);
                  setKingTargetCardIndex(null);
                  setKingPeekedCard(null);
                }}
                className="flex-1 border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]"
              >
                {t('game.cancel')}
              </Button>
              <Button
                onClick={() => {
                  playCardPlace();
                  activateKing(kingTargetPlayer, selectedHandIndex, kingTargetCardIndex);
                  setShowKingEffect(false);
                  setKingTargetPlayer(null);
                  setKingTargetCardIndex(null);
                  setKingPeekedCard(null);
                }}
                className="flex-1 bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]"
              >
                {t('game.swap')}
              </Button>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* Gewinner-Dialog */}
      <Dialog open={!!winner} onOpenChange={() => {}}>
        <DialogContent className="bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-center text-2xl">
              {winner ? t('game.gameOverWinner', { name: winner.name }) : t('game.gameOver')}
            </DialogTitle>
          </DialogHeader>
          <div className="text-center">
            {winner && (
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ type: 'spring' as const, stiffness: 200, damping: 15, delay: 0.2 }}
                className="text-6xl mb-4"
              >
                🎉
              </motion.div>
            )}
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="text-[hsl(var(--terminal-green)/0.85)] mb-4"
            >
              {winner && t('game.score', { score: winner.totalScore })}
            </motion.p>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
            >
              <Button onClick={handleReset} className="w-full">
                <RotateCcw className="w-4 h-4 mr-2" />
                {t('menu.newGame')}
              </Button>
            </motion.div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Runden-Ende Übersicht */}
      <Dialog open={gameState?.phase === 'ROUND_END'} onOpenChange={() => {}}>
        <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-center text-2xl">
              {t('game.roundEnded', { round: gameState?.round })}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-6">
            {/* Spieler-Karten und Punkte */}
            {gameState?.players.filter(p => !p.isEliminated).map((player, idx) => (
              <motion.div
                key={player.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.15 }}
                className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-xl p-4"
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <span className="text-white font-bold">{player.name}</span>
                    <span className="text-yellow-300 text-sm">
                      +{player.score} {t('game.points')}
                    </span>
                  </div>
                  <span className="text-white/80 font-mono">
                    {t('game.total', { score: player.totalScore })}
                  </span>
                </div>
                <div className="flex gap-2 justify-center">
                  {player.hand.map((card) => (
                    <CardComponent
                      key={card.id}
                      card={card}
                      isVisible={true}
                      size="sm"
                      animate={false}
                    />
                  ))}
                  {player.penaltyCards.length > 0 && (
                    <div className="flex gap-1">
                      {player.penaltyCards.map((card) => (
                        <CardComponent
                          key={card.id}
                          card={card}
                          isVisible={true}
                          size="sm"
                          animate={false}
                        />
                      ))}
                    </div>
                  )}
                </div>
              </motion.div>
            ))}

            {/* Ausgeschiedene Spieler */}
            {gameState?.players.filter(p => p.isEliminated).map((player) => (
              <div key={player.id} className="bg-red-500/10 rounded-xl p-4 text-center">
                <span className="text-red-400 font-bold">{player.name}</span>
                <span className="text-red-400 ml-2">{t('game.isEliminated', { name: player.name })}</span>
              </div>
            ))}

            {/* Weiter-Button */}
            <Button onClick={startNextRound} className="w-full" size="lg">
              <ChevronRight className="w-5 h-5 mr-2" />
              {t('game.nextRound')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Tutorial / Anleitung */}
      <Dialog open={showTutorial} onOpenChange={setShowTutorial}>
        <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-2xl text-center">{t('game.tutorialTitle')}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 text-sm">
            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-cyan)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-cyan))] mb-1">{t('game.tutorialObjectiveTitle')}</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('game.tutorialObjective')}</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-green))] mb-1">{t('game.tutorialSetupTitle')}</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('game.tutorialSetup')}</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-amber)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-amber))] mb-1">{t('game.tutorialStepsTitle')}</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialSteps.draw') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialSteps.swap') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialSteps.discard') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialSteps.end') }} /></li>
              </ul>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-cyan)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-cyan))] mb-1">👑 {t('game.tutorialSpecialCards')}</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialJack') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialKing') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.tutorialQueen') }} /></li>
              </ul>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-red)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-red))] mb-1">{t('game.tutorialDameCallTitle')}</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('game.tutorialDameCall')}</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-amber)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-amber))] mb-1">{t('game.tutorialExtraDiscardTitle')}</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">{t('game.tutorialExtraDiscard')}</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-green))] mb-1">⌨️ {t('game.tutorialShortcuts')}</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutDraw') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutSelect') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutConfirm') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutCallDame') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutEndTurn') }} /></li>
                <li><span dangerouslySetInnerHTML={{ __html: t('game.shortcutClose') }} /></li>
              </ul>
            </div>

            <Button onClick={() => setShowTutorial(false)} className="w-full bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]">
              {t('game.gotIt')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Toast-Benachrichtigungen */}
      <Toaster
        position="top-center"
        toastOptions={{
          style: {
            background: 'hsl(var(--terminal-panel))',
            color: 'hsl(var(--terminal-green))',
            border: '1px solid hsl(var(--terminal-green) / 0.3)',
          },
        }}
      />
    </div>
  );
}
