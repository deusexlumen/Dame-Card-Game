import { useState } from 'react';
import { useGameWithAI } from '@/hooks/useGameWithAI';
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
  const {
    gameState,
    drawnCard,
    selectedHandIndex,
    gameMessage,
    winner,
    isAIThinking,
    currentAIDifficulty,
    startGame,
    drawFromDeck,
    drawFromDiscard,
    selectHandCard,
    confirmSwap,
    discardDrawnCard,
    useJack,
    useKing,
    callDame,
    endTurn,
    resetGame,
    canCallDameNow,
  } = useGameWithAI();

  const [showStartDialog, setShowStartDialog] = useState(true);
  const [showJackEffect, setShowJackEffect] = useState(false);
  const [showKingEffect, setShowKingEffect] = useState(false);
  const [kingTargetPlayer, setKingTargetPlayer] = useState<string | null>(null);

  // Spiel starten
  const handleStart = () => {
    startGame(players);
    setShowStartDialog(false);
  };

  // Spiel zurücksetzen
  const handleReset = () => {
    resetGame();
    setShowStartDialog(true);
  };

  // Prüfe ob aktueller Spieler ein menschlicher Spieler ist (Index 0)
  const isHumanTurn = gameState?.currentPlayerIndex === 0;
  
  // Prüfe ob der menschliche Spieler eliminiert wurde
  const isHumanEliminated = gameState?.players[0]?.isEliminated ?? false;

  if (!gameState) {
    return (
      <Dialog open={showStartDialog} onOpenChange={setShowStartDialog}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-2xl text-center">Dame</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-center text-slate-600">
              Ein spannendes Kartenspiel mit Bluff und Strategie!
            </p>
            <div className="bg-slate-100 p-4 rounded-lg text-sm space-y-2">
              <p><strong>Regeln:</strong></p>
              <ul className="list-disc list-inside space-y-1 text-slate-700">
                <li>Jeder hat 4 verdeckte Karten (sieht nur 2)</li>
                <li>Ziel: Möglichst wenige Punkte sammeln</li>
                <li>Über 50 Punkte = Ausgeschieden</li>
                <li>Genau 50 Punkte = Reset auf 0!</li>
                <li>Bube: Eigene Karte anschauen</li>
                <li>König: Mit anderem Spieler tauschen</li>
                <li>Dame: Strafkarte beim Ablegen!</li>
              </ul>
            </div>
            <div className="bg-purple-50 p-3 rounded-lg">
              <p className="text-purple-700 font-medium flex items-center gap-2">
                <Bot className="w-4 h-4" />
                KI-Gegner
              </p>
              <p className="text-purple-600 text-sm">
                {players.filter(p => p.isAI).length} KI-Gegner mit verschiedenen Schwierigkeitsgraden!
              </p>
            </div>
            <Button onClick={handleStart} className="w-full">
              <Play className="w-4 h-4 mr-2" />
              Spiel starten
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

  // Wenn menschlicher Spieler eliminiert wurde, zeige Zuschauer-Modus
  if (isHumanEliminated) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-800 to-slate-900 p-4">
        <div className="flex flex-col items-center justify-center h-screen">
          <div className="text-6xl mb-4">👀</div>
          <h2 className="text-3xl font-bold text-white mb-2">Du bist ausgeschieden!</h2>
          <p className="text-slate-400 mb-6">Schau zu, wie die KI-Gegner weiterspielen...</p>
          <Button onClick={handleReset}>
            <RotateCcw className="w-4 h-4 mr-2" />
            Neues Spiel
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-800 to-green-900 p-4">
      {/* Header */}
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center gap-4">
          <h1 className="text-2xl font-bold text-white">Dame</h1>
          <div className="bg-white/20 px-3 py-1 rounded-full text-white text-sm">
            Runde {gameState.round}
          </div>
          {gameState.safePhase && (
            <div className="bg-yellow-500/80 px-3 py-1 rounded-full text-white text-sm">
              Safe Phase
            </div>
          )}
          {isAIThinking && (
            <div className="bg-purple-500/80 px-3 py-1 rounded-full text-white text-sm flex items-center gap-2">
              <Bot className="w-3 h-3 animate-pulse" />
              KI denkt...
            </div>
          )}
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={handleReset}>
            <RotateCcw className="w-4 h-4 mr-1" />
            Neustart
          </Button>
          <Button variant="outline" size="sm" onClick={onBackToMenu}>
            Menü
          </Button>
        </div>
      </div>

      {/* Spieltisch */}
      <div className="max-w-6xl mx-auto">
        {/* Obere Reihe - Gegner */}
        <div className="flex justify-center gap-4 mb-6 flex-wrap">
          {gameState.players.slice(1).map((player, idx) => {
            const originalPlayer = players[idx + 1];
            const isAI = originalPlayer?.isAI;
            const difficulty = originalPlayer?.difficulty;
            
            return (
              <div key={player.id} className="relative">
                <PlayerHand
                  player={player}
                  isCurrentPlayer={false}
                  isActivePlayer={gameState.currentPlayerIndex === gameState.players.indexOf(player)}
                  gamePhase={gameState.phase}
                  size="sm"
                />
                {isAI && difficulty && (
                  <div className={cn(
                    "absolute -top-2 -right-2 w-6 h-6 rounded-full flex items-center justify-center bg-slate-800",
                    DIFFICULTY_COLORS[difficulty]
                  )}>
                    {DIFFICULTY_ICONS[difficulty]}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Mitte - Spielstapel */}
        <div className="flex justify-center items-center gap-8 mb-6">
          {/* Ziehstapel */}
          <CardStack
            count={gameState.deck.length}
            label="Ziehstapel"
            onClick={drawFromDeck}
            isClickable={isHumanTurn && !drawnCard && !isAIThinking}
            size="lg"
          />

          {/* Spiel-Info */}
          <div className="bg-white/10 backdrop-blur-sm rounded-xl p-4 text-center min-w-[180px]">
            <p className="text-white/80 text-sm mb-1">Aktueller Spieler</p>
            <p className="text-white text-lg font-bold mb-1">{currentPlayer.name}</p>
            <p className="text-yellow-300 text-xs">{gameMessage}</p>
            {currentAIDifficulty && (
              <div className={cn(
                "mt-2 inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs",
                "bg-slate-800/50",
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
            onClick={drawFromDiscard}
            isClickable={isHumanTurn && !drawnCard && !!topDiscardCard && !isAIThinking}
            size="lg"
          />
        </div>

        {/* Gezogene Karte (falls vorhanden) */}
        {drawnCard && isHumanTurn && (
          <div className="flex justify-center mb-4">
            <div className="bg-white/20 backdrop-blur-sm rounded-xl p-4">
              <p className="text-white text-center mb-2">Gezogene Karte</p>
              <div className="flex justify-center">
                <CardComponent card={drawnCard} isVisible={true} size="lg" />
              </div>
            </div>
          </div>
        )}

        {/* Aktions-Buttons */}
        {isHumanTurn && !isAIThinking && (
          <div className="flex justify-center gap-3 mb-6 flex-wrap">
            {drawnCard && (
              <>
                <Button
                  onClick={() => setShowJackEffect(true)}
                  disabled={drawnCard.rank !== 'J'}
                  variant={drawnCard.rank === 'J' ? 'default' : 'outline'}
                  size="sm"
                >
                  <Eye className="w-4 h-4 mr-1" />
                  Bube-Effekt
                </Button>
                <Button
                  onClick={() => setShowKingEffect(true)}
                  disabled={drawnCard.rank !== 'K'}
                  variant={drawnCard.rank === 'K' ? 'default' : 'outline'}
                  size="sm"
                >
                  <Crown className="w-4 h-4 mr-1" />
                  König-Effekt
                </Button>
                <Button
                  onClick={discardDrawnCard}
                  variant="secondary"
                  size="sm"
                >
                  Direkt ablegen
                </Button>
              </>
            )}
            
            {canCallDameNow && !drawnCard && (
              <Button
                onClick={callDame}
                variant="destructive"
                size="sm"
              >
                <AlertCircle className="w-4 h-4 mr-1" />
                Dame rufen!
              </Button>
            )}
            
            {!drawnCard && (
              <Button onClick={endTurn} size="sm">
                Zug beenden
                <ChevronRight className="w-4 h-4 ml-1" />
              </Button>
            )}
          </div>
        )}

        {/* Untere Reihe - Eigene Hand */}
        <div className="flex justify-center">
          <PlayerHand
            player={gameState.players[0]}
            isCurrentPlayer={true}
            isActivePlayer={isHumanTurn}
            onCardSelectForSwap={drawnCard && isHumanTurn ? selectHandCard : undefined}
            selectedCardIndex={selectedHandIndex}
            gamePhase={gameState.phase}
            size="lg"
          />
        </div>

        {/* Tausch-Bestätigung */}
        {drawnCard && selectedHandIndex !== null && isHumanTurn && (
          <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2">
            <Button onClick={confirmSwap} size="lg" className="shadow-xl">
              Tauschen bestätigen
            </Button>
          </div>
        )}
      </div>

      {/* Bube-Effekt Dialog */}
      <Dialog open={showJackEffect} onOpenChange={setShowJackEffect}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Bube-Effekt</DialogTitle>
          </DialogHeader>
          <p className="text-slate-600 mb-4">
            Wähle eine deiner verdeckten Karten, um sie anzuschauen:
          </p>
          <div className="flex justify-center gap-4">
            {gameState.players[0].hand.map((card, index) => (
              <button
                key={card.id}
                onClick={() => {
                  useJack(index);
                  setShowJackEffect(false);
                }}
                className="hover:scale-105 transition-transform"
              >
                <CardComponent
                  card={card}
                  isVisible={gameState.players[0].visibleCardIndices.includes(index)}
                  size="md"
                />
              </button>
            ))}
          </div>
        </DialogContent>
      </Dialog>

      {/* König-Effekt Dialog */}
      <Dialog open={showKingEffect} onOpenChange={setShowKingEffect}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>König-Effekt</DialogTitle>
          </DialogHeader>
          <p className="text-slate-600 mb-4">
            Wähle eine deiner Karten und einen Gegner zum Tauschen:
          </p>
          
          {/* Eigene Karten */}
          <div className="mb-4">
            <p className="text-sm font-medium mb-2">Deine Karten:</p>
            <div className="flex gap-2">
              {gameState.players[0].hand.map((card, cardIndex) => (
                <button
                  key={card.id}
                  onClick={() => selectHandCard(cardIndex)}
                  className={cn(
                    'hover:scale-105 transition-transform',
                    selectedHandIndex === cardIndex && 'ring-4 ring-yellow-400 rounded-lg'
                  )}
                >
                  <CardComponent
                    card={card}
                    isVisible={gameState.players[0].visibleCardIndices.includes(cardIndex)}
                    size="sm"
                  />
                </button>
              ))}
            </div>
          </div>

          {/* Gegner auswählen */}
          {selectedHandIndex !== null && (
            <div>
              <p className="text-sm font-medium mb-2">Wähle einen Gegner:</p>
              <div className="flex gap-2">
                {gameState.players.slice(1).map((player) => (
                  <Button
                    key={player.id}
                    variant="outline"
                    onClick={() => setKingTargetPlayer(player.id)}
                    className={cn(kingTargetPlayer === player.id && 'ring-2 ring-blue-500')}
                  >
                    {player.name}
                  </Button>
                ))}
              </div>
            </div>
          )}

          {/* Tauschen bestätigen */}
          {selectedHandIndex !== null && kingTargetPlayer && (
            <Button
              onClick={() => {
                useKing(kingTargetPlayer, selectedHandIndex, 0);
                setShowKingEffect(false);
                setKingTargetPlayer(null);
              }}
              className="w-full mt-4"
            >
              Tauschen
            </Button>
          )}
        </DialogContent>
      </Dialog>

      {/* Gewinner-Dialog */}
      <Dialog open={!!winner} onOpenChange={() => {}}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="text-center text-2xl">
              {winner ? `${winner.name} gewinnt!` : 'Spiel beendet!'}
            </DialogTitle>
          </DialogHeader>
          <div className="text-center">
            <p className="text-slate-600 mb-4">
              {winner && `Punktestand: ${winner.totalScore}`}
            </p>
            <Button onClick={handleReset} className="w-full">
              <RotateCcw className="w-4 h-4 mr-2" />
              Neues Spiel
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
