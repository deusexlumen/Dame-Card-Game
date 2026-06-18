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
  Target
} from 'lucide-react';
import type { AIDifficulty } from '@/lib/aiPlayer';
import type { Card } from '@/types/game';
import { playCardDraw, playCardPlace, playCardFlip, playDameCall, playWinSound, playPenaltySound, startBackgroundMusic, stopBackgroundMusic } from '@/lib/sounds';
import { setGlobalSettings } from '@/lib/settings';
import { useSettings } from '@/hooks/useSettings';
import { Toaster, toast } from 'sonner';
import { Settings, Volume2, VolumeX, Sparkles, Music } from 'lucide-react';

interface GameBoardProps {
  players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>;
  onBackToMenu: () => void;
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

export function GameBoard({ players, onBackToMenu }: GameBoardProps) {
  const { stats, clear, recordRound, recordGame } = useGameStats();
  const { settings, toggleSound, toggleAnimations, toggleMusic, setAiSpeed } = useSettings();

  const {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
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
  } = useGameWithAI(settings.aiSpeed, { recordRound, recordGame });

  // Globale Settings für Sound-Engine synchronisieren
  useEffect(() => {
    setGlobalSettings(settings);
  }, [settings]);

  // Hintergrundmusik steuern
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
  const [showJackEffect, setShowJackEffect] = useState(false);
  const [showKingEffect, setShowKingEffect] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
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
      if (showStartDialog || showJackEffect || showKingEffect || showSettings || showTutorial || winner) return;
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
          // Zug beenden
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
    showStartDialog, showJackEffect, showKingEffect, showSettings, showTutorial, winner,
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
    if (gameMessage?.includes('Strafkarte')) {
      playPenaltySound();
      toast.error('Strafkarte erhalten!', {
        description: gameMessage,
        duration: 3000,
      });
    }
  }, [gameMessage]);

  // Toast-Benachrichtigungen für wichtige Ereignisse
  useEffect(() => {
    if (gameMessage?.includes('Dame')) {
      if (gameMessage.includes('falsch')) {
        toast.error('Dame-Call falsch!', {
          description: gameMessage,
          duration: 4000,
        });
      } else if (gameMessage.includes('richtig')) {
        toast.success('Dame-Call richtig!', {
          description: gameMessage,
          duration: 4000,
        });
      }
    }
    if (gameMessage?.includes('ausgeschieden')) {
      toast.warning('Spieler ausgeschieden!', {
        description: gameMessage,
        duration: 4000,
      });
    }
    if (gameMessage?.includes('Runde beendet')) {
      toast.info('Runde beendet!', {
        description: gameMessage,
        duration: 4000,
      });
    }
    if (gameMessage?.includes('Extra-Karte')) {
      toast.success('Extra-Karte abgelegt!', {
        description: gameMessage,
        duration: 3000,
      });
    }
    if (gameMessage?.includes('Bube-Effekt')) {
      toast.info('Bube-Effekt aktiviert', {
        description: 'Du kannst eine deiner Karten anschauen.',
        duration: 3000,
      });
    }
    if (gameMessage?.includes('König-Effekt')) {
      toast.info('König-Effekt aktiviert', {
        description: 'Tausche eine Karte mit einem Gegner.',
        duration: 3000,
      });
    }
  }, [gameMessage]);

  // Spiel starten
  const handleStart = () => {
    playCardFlip();
    startGame(players);
    setShowStartDialog(false);
  };

  // Spiel zurücksetzen
  const handleReset = () => {
    playCardFlip();
    resetGame();
    setShowStartDialog(true);
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
            <DialogTitle className="text-2xl text-center">Dame</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-center text-[hsl(var(--terminal-green)/0.85)]">
              Ein spannendes Kartenspiel mit Bluff und Strategie!
            </p>
            <div className="bg-[hsl(var(--terminal-panel))] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg text-sm space-y-2">
              <p className="text-[hsl(var(--terminal-green))]"><strong>Regeln:</strong></p>
              <ul className="list-disc list-inside space-y-1 text-[hsl(var(--terminal-green)/0.85)]">
                <li>Jeder hat 4 verdeckte Karten (sieht nur 2)</li>
                <li>Ziel: Möglichst wenige Punkte sammeln</li>
                <li>Über 50 Punkte = Ausgeschieden</li>
                <li>Genau 50 Punkte = Reset auf 0!</li>
                <li>Bube: Eigene oder gegnerische Karte anschauen</li>
                <li>König: Mit einem Gegner tauschen</li>
                <li>Dame: Strafkarte beim Ablegen; offene Dame muss vom nächsten Spieler genommen werden</li>
              </ul>
            </div>
            <div className="bg-[hsl(var(--terminal-cyan)/0.08)] border border-[hsl(var(--terminal-cyan)/0.2)] p-3 rounded-lg">
              <p className="text-[hsl(var(--terminal-cyan))] font-medium flex items-center gap-2">
                <Bot className="w-4 h-4" />
                KI-Gegner
              </p>
              <p className="text-[hsl(var(--terminal-green)/0.85)] text-sm">
                {players.filter(p => p.isAI).length} KI-Gegner mit verschiedenen Schwierigkeitsgraden!
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
                Spiel fortsetzen
              </Button>
            )}
            <Button
              onClick={() => setShowTutorial(true)}
              variant="outline"
              className="w-full"
            >
              <Eye className="w-4 h-4 mr-2" />
              Anleitung
            </Button>
            <Button onClick={handleStart} className="w-full">
              <Play className="w-4 h-4 mr-2" />
              Neues Spiel
            </Button>
          </div>
        </DialogContent>
      </Dialog>
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
          <h2 className="text-3xl font-bold text-[hsl(var(--terminal-green))] mb-2">Du bist ausgeschieden!</h2>
          <p className="text-[hsl(var(--terminal-green)/0.7)] mb-6">Schau zu, wie die KI-Gegner weiterspielen...</p>
          <Button onClick={handleReset}>
            <RotateCcw className="w-4 h-4 mr-2" />
            Neues Spiel
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen felt-texture relative p-2 sm:p-4">
      {/* Header */}
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center gap-2 sm:gap-4 flex-wrap">
          <h1 className="text-xl sm:text-2xl font-bold text-[hsl(var(--terminal-green))]">Dame</h1>
          <div className="bg-[hsl(var(--terminal-green)/0.15)] border border-[hsl(var(--terminal-green)/0.25)] px-2 sm:px-3 py-1 rounded-full text-[hsl(var(--terminal-green))] text-xs sm:text-sm">
            Runde {gameState.round}
          </div>
          {gameState.safePhase && (
            <div className="bg-yellow-500/80 px-2 sm:px-3 py-1 rounded-full text-white text-xs sm:text-sm">
              Safe Phase
            </div>
          )}
          {isAIThinking && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              className="bg-purple-500/80 px-2 sm:px-3 py-1 rounded-full text-white text-xs sm:text-sm flex items-center gap-2"
            >
              <motion.div
                animate={{ rotate: [0, 15, -15, 0] }}
                transition={{ duration: 0.5, repeat: Infinity }}
              >
                <Bot className="w-3 h-3" />
              </motion.div>
              KI denkt...
            </motion.div>
          )}
        </div>
        <div className="flex gap-1 sm:gap-2">
          <Button variant="outline" size="sm" onClick={() => setShowTutorial(true)} aria-label="Anleitung öffnen" className="text-xs sm:text-sm">
            <Eye className="w-3 h-3 sm:w-4 sm:h-4" />
          </Button>
          <Button variant="outline" size="sm" onClick={() => setShowSettings(true)} aria-label="Einstellungen öffnen" className="text-xs sm:text-sm">
            <Settings className="w-3 h-3 sm:w-4 sm:h-4" />
          </Button>
          <Button variant="outline" size="sm" onClick={handleReset} aria-label="Spiel neustarten" className="text-xs sm:text-sm">
            <RotateCcw className="w-3 h-3 sm:w-4 sm:h-4 mr-1" />
            Neustart
          </Button>
          <Button variant="outline" size="sm" onClick={onBackToMenu} aria-label="Zurück zum Menü" className="text-xs sm:text-sm">
            Menü
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
          {/* Ziehstapel */}
          <CardStack
            count={gameState.deck.length}
            label="Ziehstapel"
            onClick={() => { playCardDraw(); drawFromDeck(); }}
            isClickable={isHumanTurn && !drawnCard && !isAIThinking && !mustTakeQueen}
            size="md"
          />

          {/* Spiel-Info */}
          <div className="bg-[hsl(var(--terminal-green)/0.1)] border border-[hsl(var(--terminal-green)/0.2)] backdrop-blur-sm rounded-xl p-3 sm:p-4 text-center min-w-[140px] sm:min-w-[180px]">
            <p className="text-[hsl(var(--terminal-green)/0.8)] text-xs sm:text-sm mb-1">Aktueller Spieler</p>
            <p className="text-[hsl(var(--terminal-green))] text-base sm:text-lg font-bold mb-1">{currentPlayer.name}</p>
            <div role="status" aria-live="polite" aria-atomic="true" className="text-yellow-300 text-xs">
              {gameMessage}
            </div>
            {currentAIDifficulty && (
              <div className={cn(
                "mt-2 inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs",
                "bg-[hsl(var(--terminal-dark)/0.5)]",
                DIFFICULTY_COLORS[currentAIDifficulty]
              )}>
                <Bot className="w-3 h-3" />
                {currentAIDifficulty === 'easy' && 'Einfach'}
                {currentAIDifficulty === 'medium' && 'Mittel'}
                {currentAIDifficulty === 'hard' && 'Schwer'}
              </div>
            )}
          </div>

          {/* Ablagestapel */}
          <CardStack
            count={gameState.discardPile.length}
            label="Ablagestapel"
            topCard={topDiscardCard}
            onClick={() => { playCardDraw(); drawFromDiscard(); }}
            isClickable={isHumanTurn && !drawnCard && !!topDiscardCard && !isAIThinking}
            size="md"
          />
        </div>

        {/* Gezogene Karte (falls vorhanden) */}
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
                <p className="text-[hsl(var(--terminal-green))] text-center mb-2 text-sm sm:text-base">Gezogene Karte</p>
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
                  size="sm"
                  className="text-xs sm:text-sm"
                >
                  <Eye className="w-3 h-3 sm:w-4 sm:h-4 mr-1" />
                  Bube
                </Button>
                <Button
                  onClick={() => setShowKingEffect(true)}
                  disabled={drawnCard.rank !== 'K'}
                  variant={drawnCard.rank === 'K' ? 'default' : 'outline'}
                  size="sm"
                  className="text-xs sm:text-sm"
                >
                  <Crown className="w-3 h-3 sm:w-4 sm:h-4 mr-1" />
                  König
                </Button>
                <Button
                  onClick={() => { playCardPlace(); discardDrawnCard(); }}
                  variant="secondary"
                  size="sm"
                  className="text-xs sm:text-sm"
                >
                  Ablegen
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
                  size="sm"
                  className="text-xs sm:text-sm"
                >
                  <AlertCircle className="w-3 h-3 sm:w-4 sm:h-4 mr-1" />
                  Dame rufen!
                </Button>
              </motion.div>
            )}
            
            {!drawnCard && (
              <Button onClick={() => { playCardPlace(); endTurn(); }} size="sm" className="text-xs sm:text-sm">
                Zug beenden
                <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 ml-1" />
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
            className="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50"
          >
            <Button onClick={() => { playCardPlace(); confirmSwap(); }} size="lg" className="shadow-xl text-sm sm:text-base">
              Tauschen bestätigen
            </Button>
          </motion.div>
        )}
      </div>

      {/* Bube-Effekt Dialog */}
      <Dialog open={showJackEffect} onOpenChange={setShowJackEffect}>
        <DialogContent className="sm:max-w-3xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Eye className="w-5 h-5" />
              Bube-Effekt
            </DialogTitle>
          </DialogHeader>
          <p className="text-[hsl(var(--terminal-green)/0.85)] mb-4">
            Wähle eine verdeckte Karte (eigene oder gegnerische), um sie anzuschauen:
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
                    {player.id === humanPlayer?.id ? 'Deine Karten' : `Karten von ${player.name}`}
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
        if (!open) {
          setShowKingEffect(false);
          setKingTargetPlayer(null);
          setKingTargetCardIndex(null);
          setKingPeekedCard(null);
        }
      }}>
        <DialogContent className="max-w-2xl bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Crown className="w-5 h-5" />
              König-Effekt
            </DialogTitle>
          </DialogHeader>
          <p className="text-[hsl(var(--terminal-green)/0.85)] mb-4">
            Wähle eine deiner Karten, einen Gegner und dessen Karte. Du siehst die gegnerische Karte vor dem Tausch.
          </p>

          {/* Eigene Karten */}
          <div className="mb-4">
            <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">Deine Karten:</p>
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
              <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">Wähle einen Gegner:</p>
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
              <p className="text-sm font-medium mb-2 text-[hsl(var(--terminal-cyan))]">Wähle eine Karte des Gegners:</p>
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
                  Du erhältst:{' '}
                  <span
                    aria-label={`Gesehene Karte: ${kingPeekedCard.rank} ${kingPeekedCard.suit === 'hearts' ? 'Herzen' : kingPeekedCard.suit === 'diamonds' ? 'Karo' : kingPeekedCard.suit === 'clubs' ? 'Kreuz' : 'Pik'}`}
                  >
                    {kingPeekedCard.rank}{kingPeekedCard.suit === 'hearts' ? '♥' : kingPeekedCard.suit === 'diamonds' ? '♦' : kingPeekedCard.suit === 'clubs' ? '♣' : '♠'}
                  </span>
                </p>
              )}
            </div>
          )}

          {/* Tauschen bestätigen oder abbrechen */}
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
                Abbrechen
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
                Tauschen
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
              {winner ? `${winner.name} gewinnt!` : 'Spiel beendet!'}
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
              {winner && `Punktestand: ${winner.totalScore}`}
            </motion.p>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
            >
              <Button onClick={handleReset} className="w-full">
                <RotateCcw className="w-4 h-4 mr-2" />
                Neues Spiel
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
              Runde {gameState?.round} beendet!
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
                      +{player.score} Punkte
                    </span>
                  </div>
                  <span className="text-white/80 font-mono">
                    Gesamt: {player.totalScore}
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
                <span className="text-red-400 ml-2">ist ausgeschieden!</span>
              </div>
            ))}

            {/* Weiter-Button */}
            <Button onClick={startNextRound} className="w-full" size="lg">
              <ChevronRight className="w-5 h-5 mr-2" />
              Nächste Runde
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Settings-Dialog */}
      <Dialog open={showSettings} onOpenChange={setShowSettings}>
        <DialogContent className="sm:max-w-md bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Settings className="w-5 h-5" />
              Einstellungen
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            {/* Sound Toggle */}
            <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
              <div className="flex items-center gap-3">
                {settings.soundEnabled ? (
                  <Volume2 className="w-5 h-5 text-[hsl(var(--terminal-green))]" />
                ) : (
                  <VolumeX className="w-5 h-5 text-[hsl(var(--terminal-green)/0.5)]" />
                )}
                <div>
                  <p className="font-medium text-sm text-[hsl(var(--terminal-green))]">Sound-Effekte</p>
                  <p className="text-xs text-[hsl(var(--terminal-green)/0.6)]">Karten, Gewinn, Strafen</p>
                </div>
              </div>
              <Button
                variant={settings.soundEnabled ? 'default' : 'outline'}
                size="sm"
                onClick={toggleSound}
                aria-pressed={settings.soundEnabled}
                className={!settings.soundEnabled ? 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]' : ''}
              >
                {settings.soundEnabled ? 'An' : 'Aus'}
              </Button>
            </div>

            {/* Music Toggle */}
            <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
              <div className="flex items-center gap-3">
                <Music className={cn('w-5 h-5', settings.musicEnabled ? 'text-[hsl(var(--terminal-cyan))]' : 'text-[hsl(var(--terminal-green)/0.5)]')} />
                <div>
                  <p className="font-medium text-sm text-[hsl(var(--terminal-green))]">Hintergrundmusik</p>
                  <p className="text-xs text-[hsl(var(--terminal-green)/0.6)]">Ambient Casino-Sounds</p>
                </div>
              </div>
              <Button
                variant={settings.musicEnabled ? 'default' : 'outline'}
                size="sm"
                onClick={toggleMusic}
                aria-pressed={settings.musicEnabled}
                className={!settings.musicEnabled ? 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]' : ''}
              >
                {settings.musicEnabled ? 'An' : 'Aus'}
              </Button>
            </div>

            {/* Animation Toggle */}
            <div className="flex items-center justify-between p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
              <div className="flex items-center gap-3">
                <Sparkles className={cn('w-5 h-5', settings.animationsEnabled ? 'text-[hsl(var(--terminal-amber))]' : 'text-[hsl(var(--terminal-green)/0.5)]')} />
                <div>
                  <p className="font-medium text-sm text-[hsl(var(--terminal-green))]">Animationen</p>
                  <p className="text-xs text-[hsl(var(--terminal-green)/0.6)]">Karten-Bewegungen, Effekte</p>
                </div>
              </div>
              <Button
                variant={settings.animationsEnabled ? 'default' : 'outline'}
                size="sm"
                onClick={toggleAnimations}
                aria-pressed={settings.animationsEnabled}
                className={!settings.animationsEnabled ? 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]' : ''}
              >
                {settings.animationsEnabled ? 'An' : 'Aus'}
              </Button>
            </div>

            {/* KI-Geschwindigkeit */}
            <div className="p-3 bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.15)] rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <Bot className={cn('w-5 h-5', settings.aiSpeed === 'fast' ? 'text-[hsl(var(--terminal-green))]' : settings.aiSpeed === 'slow' ? 'text-[hsl(var(--terminal-red))]' : 'text-[hsl(var(--terminal-cyan))]')} />
                <div>
                  <p className="font-medium text-sm text-[hsl(var(--terminal-green))]">KI-Geschwindigkeit</p>
                  <p className="text-xs text-[hsl(var(--terminal-green)/0.6)]">Wartezeit auf KI-Züge</p>
                </div>
              </div>
              <div className="flex gap-2">
                {(['fast', 'normal', 'slow'] as const).map((speed) => (
                  <Button
                    key={speed}
                    variant={settings.aiSpeed === speed ? 'default' : 'outline'}
                    size="sm"
                    aria-pressed={settings.aiSpeed === speed}
                    className={cn(
                      'flex-1 text-xs',
                      settings.aiSpeed !== speed && 'border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]'
                    )}
                    onClick={() => setAiSpeed(speed)}
                  >
                    {speed === 'fast' && 'Schnell'}
                    {speed === 'normal' && 'Normal'}
                    {speed === 'slow' && 'Langsam'}
                  </Button>
                ))}
              </div>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Tutorial / Anleitung */}
      <Dialog open={showTutorial} onOpenChange={setShowTutorial}>
        <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <DialogHeader>
            <DialogTitle className="text-2xl text-center">Wie spielt man Dame?</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 text-sm">
            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-cyan)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-cyan))] mb-1">🎯 Ziel des Spiels</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">Sammle so wenige Punkte wie möglich. Wer über 50 Punkte kommt, scheidet aus. Wer genau 50 Punkte erreicht, fällt auf 0 zurück!</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-green))] mb-1">🃏 Kartenverteilung</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">Jeder Spieler bekommt 4 verdeckte Karten. Du siehst nur die ersten 2 Karten. Die anderen beiden bleiben verdeckt — merk sie dir!</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-amber)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-amber))] mb-1">🎮 Dein Zug</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li>Ziehe vom <strong>Ziehstapel</strong> oder vom <strong>Ablagestapel</strong></li>
                <li>Tausche die gezogene Karte mit einer deiner Hand-Karten</li>
                <li>Oder lege die gezogene Karte direkt ab</li>
                <li>Beende deinen Zug</li>
              </ul>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-cyan)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-cyan))] mb-1">👑 Sonderkarten</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li><strong>Bube (J):</strong> Schaue eine verdeckte Karte an — deine eigene oder die eines Gegners</li>
                <li><strong>König (K):</strong> Schaue eine gegnerische Karte kurz an und tausche dann blind eine deiner Karten damit</li>
                <li><strong>Dame (Q):</strong> Wenn du eine Dame ablegst, ziehst du selbst eine Strafkarte. Liegt eine Dame oben auf dem Ablagestapel, muss der nächste Spieler sie ziehen.</li>
              </ul>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-red)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-red))] mb-1">📢 Dame Call</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">Ab Runde 3 kannst du „Dame" rufen, wenn du glaubst, die wenigsten Punkte zu haben. Liegst du falsch, startest du die nächste Runde mit 5 Karten als Strafe!</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-amber)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-amber))] mb-1">🚀 Extra-Ablegen</p>
              <p className="text-[hsl(var(--terminal-green)/0.85)]">Wenn die oberste Ablagekarte z.B. eine 7 ist und du auch eine 7 in der Hand hast, kannst du diese direkt ablegen — ohne zu ziehen!</p>
            </div>

            <div className="bg-[hsl(var(--terminal-dark)/0.5)] border border-[hsl(var(--terminal-green)/0.2)] p-4 rounded-lg">
              <p className="font-bold text-[hsl(var(--terminal-green))] mb-1">⌨️ Tastenkürzel</p>
              <ul className="list-disc list-inside text-[hsl(var(--terminal-green)/0.85)] space-y-1">
                <li><strong>Leertaste</strong> — Ziehen oder Ablegen</li>
                <li><strong>1-4</strong> — Karte auswählen</li>
                <li><strong>Enter</strong> — Tausch bestätigen</li>
                <li><strong>D</strong> — Dame rufen</li>
                <li><strong>Z / E</strong> — Zug beenden</li>
                <li><strong>Escape</strong> — Offenen Dialog schließen</li>
              </ul>
            </div>

            <Button onClick={() => setShowTutorial(false)} className="w-full bg-[hsl(var(--terminal-green))] text-black hover:bg-[hsl(var(--terminal-green)/0.85)]">
              Alles klar!
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
