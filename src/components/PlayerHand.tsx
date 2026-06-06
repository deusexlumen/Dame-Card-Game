import { useState } from 'react';
import type { Player } from '@/types/game';
import { CardComponent } from './Card';
import { cn } from '@/lib/utils';
import { Eye, EyeOff } from 'lucide-react';

interface PlayerHandProps {
  player: Player;
  isCurrentPlayer: boolean;
  isActivePlayer: boolean;
  onCardClick?: (index: number) => void;
  onCardSelectForSwap?: (index: number) => void;
  onCardSelectForJack?: (index: number) => void;
  onCardSelectForKing?: (index: number) => void;
  onCardSelectForExtraDiscard?: (index: number) => void;
  selectedCardIndex?: number | null;
  gamePhase?: string;
  size?: 'sm' | 'md' | 'lg';
}

export function PlayerHand({
  player,
  isCurrentPlayer,
  isActivePlayer,
  onCardClick,
  onCardSelectForSwap,
  onCardSelectForJack,
  onCardSelectForKing,
  onCardSelectForExtraDiscard,
  selectedCardIndex,
  gamePhase,
  size = 'md',
}: PlayerHandProps) {
  const [showAllCards, setShowAllCards] = useState(false);

  // Für Gegner: Karten immer verdeckt zeigen (außer beim König-Effekt)
  const isOpponent = !isCurrentPlayer && !isActivePlayer;

  return (
    <div className="flex flex-col items-center gap-3">
      {/* Spieler-Info */}
      <div className="flex items-center gap-2">
        <div
          className={cn(
            'px-3 py-1 rounded-full text-sm font-medium',
            isActivePlayer
              ? 'bg-green-500 text-white'
              : 'bg-slate-200 text-slate-700'
          )}
        >
          {player.name}
        </div>
        <div className="text-sm text-slate-600">
          {player.totalScore} pts
        </div>
        {player.isEliminated && (
          <span className="text-red-500 text-xs font-bold">OUT</span>
        )}
      </div>

      {/* Karten */}
      <div className="flex gap-1 sm:gap-2">
        {player.hand.map((card, index) => {
          const isVisible =
            showAllCards ||
            player.visibleCardIndices.includes(index) ||
            (isCurrentPlayer && gamePhase === 'ROUND_END');

          const isClickable =
            isActivePlayer &&
            !player.isEliminated &&
            (onCardClick || onCardSelectForSwap || onCardSelectForJack || onCardSelectForExtraDiscard);

          return (
            <div key={card.id} className="relative">
              <CardComponent
                card={card}
                isVisible={isOpponent ? false : isVisible}
                isSelected={selectedCardIndex === index}
                isClickable={!!isClickable}
                onClick={() => {
                  if (onCardSelectForJack) {
                    onCardSelectForJack(index);
                  } else if (onCardSelectForKing) {
                    onCardSelectForKing(index);
                  } else if (onCardSelectForSwap) {
                    onCardSelectForSwap(index);
                  } else if (onCardSelectForExtraDiscard) {
                    onCardSelectForExtraDiscard(index);
                  } else if (onCardClick) {
                    onCardClick(index);
                  }
                }}
                size={size}
              />
              
              {/* Sichtbarkeits-Indikator */}
              {!isOpponent && player.visibleCardIndices.includes(index) && (
                <div className="absolute -top-1 -right-1 sm:-top-2 sm:-right-2 w-4 h-4 sm:w-5 sm:h-5 bg-green-500 rounded-full flex items-center justify-center">
                  <Eye className="w-2 h-2 sm:w-3 sm:h-3 text-white" />
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Debug: Alle Karten anzeigen (nur für Entwicklung) */}
      {isCurrentPlayer && (
        <button
          onClick={() => setShowAllCards(!showAllCards)}
          className="text-xs text-slate-400 hover:text-slate-600 flex items-center gap-1"
        >
          {showAllCards ? (
            <>
              <EyeOff className="w-3 h-3" /> Verbergen
            </>
          ) : (
            <>
              <Eye className="w-3 h-3" /> Alle anzeigen
            </>
          )}
        </button>
      )}

      {/* Strafkarten-Anzeige */}
      {player.penaltyCards.length > 0 && (
        <div className="flex items-center gap-2 text-red-500 text-sm">
          <span>Strafkarten: {player.penaltyCards.length}</span>
        </div>
      )}
    </div>
  );
}
