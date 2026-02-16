import type { Card as CardType } from '@/types/game';
import { SUIT_COLORS, SUIT_SYMBOLS } from '@/types/game';
import { cn } from '@/lib/utils';

interface CardProps {
  card: CardType;
  isVisible?: boolean;
  isSelected?: boolean;
  isClickable?: boolean;
  onClick?: () => void;
  size?: 'sm' | 'md' | 'lg';
}

export function CardComponent({
  card,
  isVisible = true,
  isSelected = false,
  isClickable = false,
  onClick,
  size = 'md',
}: CardProps) {
  const sizeClasses = {
    sm: 'w-10 h-14 text-xs',
    md: 'w-16 h-22 text-base',
    lg: 'w-24 h-34 text-xl',
  };

  if (!isVisible) {
    // Kartenrücken
    return (
      <div
        className={cn(
          sizeClasses[size],
          'rounded-lg border-2 border-slate-700 bg-gradient-to-br from-blue-600 to-blue-800',
          'flex items-center justify-center shadow-lg',
          isClickable && 'cursor-pointer hover:shadow-xl hover:scale-105 transition-transform',
          isSelected && 'ring-4 ring-yellow-400'
        )}
        onClick={isClickable ? onClick : undefined}
      >
        <div className="w-3/4 h-3/4 border-2 border-blue-400/30 rounded-md flex items-center justify-center">
          <span className="text-blue-400/50 text-2xl">♠</span>
        </div>
      </div>
    );
  }

  // Kartenfront
  const suitColor = SUIT_COLORS[card.suit];
  const suitSymbol = SUIT_SYMBOLS[card.suit];

  return (
    <div
      className={cn(
        sizeClasses[size],
        'rounded-lg border-2 border-slate-300 bg-white',
        'flex flex-col items-center justify-between p-1 shadow-lg',
        isClickable && 'cursor-pointer hover:shadow-xl hover:scale-105 transition-transform',
        isSelected && 'ring-4 ring-yellow-400'
      )}
      onClick={isClickable ? onClick : undefined}
    >
      {/* Obere linke Ecke */}
      <div className={cn('self-start leading-none font-bold', suitColor)}>
        {card.rank}
      </div>
      
      {/* Mitte - Symbol */}
      <div className={cn('text-3xl', suitColor)}>
        {suitSymbol}
      </div>
      
      {/* Untere rechte Ecke (gedreht) */}
      <div className={cn('self-end leading-none font-bold rotate-180', suitColor)}>
        {card.rank}
      </div>
    </div>
  );
}

// Kartenstapel-Komponente
interface CardStackProps {
  count?: number;
  label?: string;
  onClick?: () => void;
  isClickable?: boolean;
  topCard?: CardType | null;
  size?: 'sm' | 'md' | 'lg';
}

export function CardStack({
  count = 0,
  label,
  onClick,
  isClickable = false,
  topCard = null,
  size = 'md',
}: CardStackProps) {
  const sizeClasses = {
    sm: 'w-10 h-14',
    md: 'w-16 h-22',
    lg: 'w-24 h-34',
  };

  return (
    <div className="flex flex-col items-center gap-2">
      <div
        className={cn(
          'relative',
          sizeClasses[size],
          isClickable && 'cursor-pointer hover:scale-105 transition-transform'
        )}
        onClick={isClickable ? onClick : undefined}
      >
        {/* Stapel-Effekt */}
        {count > 0 && (
          <>
            <div className="absolute -top-1 -left-1 w-full h-full rounded-lg bg-slate-400" />
            <div className="absolute -top-0.5 -left-0.5 w-full h-full rounded-lg bg-slate-500" />
          </>
        )}
        
        {/* Oberste Karte */}
        <div className="relative">
          {topCard ? (
            <CardComponent card={topCard} isVisible={true} size={size} />
          ) : (
            <div
              className={cn(
                sizeClasses[size],
                'rounded-lg border-2 border-slate-700 bg-gradient-to-br from-blue-600 to-blue-800',
                'flex items-center justify-center'
              )}
            >
              <span className="text-white/70 text-sm font-bold">{count}</span>
            </div>
          )}
        </div>
      </div>
      
      {label && (
        <span className="text-sm text-slate-600 font-medium">{label}</span>
      )}
    </div>
  );
}
