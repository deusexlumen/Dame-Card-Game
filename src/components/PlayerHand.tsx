import type { Player, GamePhase } from '@/types/game';
import { CardComponent } from './Card';
import { cn } from '@/lib/utils';
import { useI18n } from '@/lib/i18n';
import { Eye } from 'lucide-react';

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
  gamePhase?: GamePhase;
  size?: 'sm' | 'md' | 'lg';
  peekedIndices?: number[];
  peekPhase?: boolean;
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
  peekedIndices = [],
  peekPhase = false,
}: PlayerHandProps) {
  const { t } = useI18n();
  // Gegner-Karten immer verdeckt zeigen, auch wenn der Gegner am Zug ist
  const isOpponent = !isCurrentPlayer;

  return (
    <div className="flex flex-col items-center gap-3">
      {/* Spieler-Info */}
      <div className="flex items-center gap-2">
        <div
          className={cn(
            'px-3 py-1 rounded-sm text-xs font-mono uppercase tracking-wider border',
            isActivePlayer
              ? 'bg-[hsl(var(--terminal-green)/0.15)] text-[hsl(var(--terminal-green))] border-[hsl(var(--terminal-green)/0.5)] terminal-glow'
              : 'bg-[hsl(var(--terminal-panel))] text-[hsl(var(--terminal-green)/0.7)] border-[hsl(var(--terminal-green)/0.2)]'
          )}
        >
          {player.name}
        </div>
        <div className="text-xs font-mono text-[hsl(var(--terminal-green)/0.8)]">
          {player.totalScore} {t('game.points')}
        </div>
        {player.isEliminated && (
          <span className="text-[hsl(var(--terminal-red))] text-xs font-mono font-bold terminal-glow">OUT</span>
        )}
      </div>

      {/* Karten */}
      <div className="flex gap-1 sm:gap-2">
        {player.hand.map((card, index) => {
          // Nur eigene Karten während der Peek-Phase oder am Rundenende aufdecken
          const isVisible =
            (isCurrentPlayer && peekPhase && player.visibleCardIndices.includes(index)) ||
            (isCurrentPlayer && gamePhase === 'ROUND_END');

          const isClickable =
            isActivePlayer &&
            !player.isEliminated &&
            (onCardClick || onCardSelectForSwap || onCardSelectForJack || onCardSelectForExtraDiscard);

          // Gedächtnis-Indikatoren: eigene gesehene Karten oder gegnerische Karten,
          // die der menschliche Spieler durch Bube/König gesehen hat
          const showMemoryIndicator =
            (!isOpponent && player.visibleCardIndices.includes(index)) ||
            (isOpponent && peekedIndices.includes(index));

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
              {showMemoryIndicator && (
                <div className="absolute -top-1 -right-1 sm:-top-2 sm:-right-2 w-4 h-4 sm:w-5 sm:h-5 bg-[hsl(var(--terminal-panel))] border border-[hsl(var(--terminal-green)/0.6)] rounded-full flex items-center justify-center terminal-border-glow">
                  <Eye aria-hidden="true" className="w-2 h-2 sm:w-3 sm:h-3 text-[hsl(var(--terminal-green))]" />
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Strafkarten-Anzeige */}
      {player.penaltyCards.length > 0 && (
        <div className="flex items-center gap-2 text-[hsl(var(--terminal-red))] text-xs font-mono">
          <span>{t('game.penaltyCards')}: {player.penaltyCards.length}</span>
        </div>
      )}
    </div>
  );
}
