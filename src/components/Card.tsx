import { motion } from 'framer-motion';
import type { Card as CardType } from '@/types/game';
import { SUIT_COLORS, SUIT_SYMBOLS } from '@/types/game';
import { cn } from '@/lib/utils';
import { isAnimationsEnabled } from '@/lib/settings';
import { useI18n } from '@/lib/i18n';

/** Gemeinsame Barrierefreiheits-Props für klickbare Karten. */
function getCardClickProps(
  isClickable: boolean | undefined,
  onClick: (() => void) | undefined,
  label = 'Karte auswählen'
) {
  if (!isClickable || !onClick) return {};
  return {
    role: 'button' as const,
    tabIndex: 0 as const,
    onKeyDown: (e: React.KeyboardEvent<HTMLDivElement>) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick();
      }
    },
    'aria-label': label,
  };
}

interface CardProps {
  card: CardType;
  isVisible?: boolean;
  isSelected?: boolean;
  isClickable?: boolean;
  onClick?: () => void;
  size?: 'sm' | 'md' | 'lg';
  animate?: boolean;
  index?: number;
  layoutId?: string;
}

function CardBack({
  size,
  isSelected,
  isClickable,
  onClick,
}: {
  size: 'sm' | 'md' | 'lg';
  isSelected?: boolean;
  isClickable?: boolean;
  onClick?: () => void;
}) {
  const { t } = useI18n();
  const sizeClasses = {
    sm: 'w-10 h-14 text-[8px]',
    md: 'w-16 h-[5.5rem] text-xs',
    lg: 'w-24 h-[8.5rem] text-sm',
  };

  const content = (
    <div
      className={cn(
        sizeClasses[size],
        'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
        'circuit-pattern terminal-scanlines',
        'flex items-center justify-center',
        'terminal-border-glow',
        'relative overflow-hidden',
        'select-none',
        isSelected && 'ring-2 ring-[hsl(var(--terminal-amber))]',
        isClickable && 'cursor-pointer hover:brightness-125'
      )}
      onClick={isClickable ? onClick : undefined}
      {...getCardClickProps(isClickable, onClick, t('game.selectCard'))}
    >
      {/* Leuchtende Ecken als Orientierungshilfen */}
      <div className="absolute top-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute top-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute bottom-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute bottom-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />

      {/* Zentrales System-Symbol */}
      <div className="relative w-1/2 h-1/2 border border-[hsl(var(--terminal-green)/0.3)] rounded-sm flex items-center justify-center">
        <div className="w-2/3 h-2/3 border border-[hsl(var(--terminal-green)/0.2)] rotate-45" />
        <div className="absolute w-1.5 h-1.5 bg-[hsl(var(--terminal-green)/0.8)] rounded-full animate-pulse" />
      </div>
    </div>
  );

  return content;
}

export function CardComponent({
  card,
  isVisible = true,
  isSelected = false,
  isClickable = false,
  onClick,
  size = 'md',
  animate = true,
  index = 0,
  layoutId,
}: CardProps) {
  const { t } = useI18n();
  const animationsOn = isAnimationsEnabled();
  const sizeClasses = {
    sm: 'w-10 h-14 text-[8px]',
    md: 'w-16 h-[5.5rem] text-xs',
    lg: 'w-24 h-[8.5rem] text-sm',
  };

  const symbolSizeClasses = {
    sm: 'text-base',
    md: 'text-2xl',
    lg: 'text-4xl',
  };

  const springTransition = {
    type: 'spring' as const,
    stiffness: 300,
    damping: 25,
    delay: index * 0.05,
  };

  const hoverSpring = {
    type: 'spring' as const,
    stiffness: 400,
    damping: 20,
  };

  const entranceAnimation = animate && animationsOn
    ? {
        initial: { opacity: 0, y: -30, scale: 0.8, rotateY: 0 },
        animate: {
          opacity: 1,
          y: 0,
          scale: 1,
          rotateY: isVisible ? 0 : 180,
          transition: springTransition,
        },
      }
    : {};

  // Wenn Animationen aus sind, verwenden wir einfache divs
  if (!animationsOn) {
    if (!isVisible) {
      return (
        <CardBack
          size={size}
          isSelected={isSelected}
          isClickable={isClickable}
          onClick={onClick}
        />
      );
    }

    const suitColor = SUIT_COLORS[card.suit];
    const suitSymbol = SUIT_SYMBOLS[card.suit];

    return (
      <div
        className={cn(
          sizeClasses[size],
          'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
          'bg-[hsl(var(--terminal-panel))] terminal-scanlines',
          'flex flex-col items-center justify-between p-1',
          'terminal-border-glow',
          'select-none',
          'relative overflow-hidden font-mono',
          isSelected && 'ring-2 ring-[hsl(var(--terminal-amber))]',
          isClickable && 'cursor-pointer hover:brightness-110 hover:-translate-y-0.5'
        )}
        onClick={isClickable ? onClick : undefined}
        {...getCardClickProps(isClickable, onClick, t('game.selectCard'))}
      >
        {/* Äußerer Rahmen */}
        <div className="absolute inset-0.5 border border-[hsl(var(--terminal-green)/0.15)] rounded-sm pointer-events-none" />

        {/* Scanlines */}
        <div className="absolute inset-0 opacity-30 pointer-events-none terminal-scanlines-static" />

        {/* Obere linke Ecke: Rank */}
        <div className={cn('self-start leading-none font-bold z-10 tracking-tighter', suitColor)}>
          {card.rank}
        </div>

        {/* Zentrales geometrisches Symbol */}
        <div className={cn(symbolSizeClasses[size], 'z-10 drop-shadow-[0_0_6px_currentColor]', suitColor)}>
          {suitSymbol}
        </div>

        {/* Untere rechte Ecke: Rank (gedreht) */}
        <div className={cn('self-end leading-none font-bold rotate-180 z-10 tracking-tighter', suitColor)}>
          {card.rank}
        </div>
      </div>
    );
  }

  if (!isVisible) {
    return (
      <motion.div
        {...entranceAnimation}
        layoutId={layoutId}
        className={cn(
          sizeClasses[size],
          'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
          'circuit-pattern terminal-scanlines',
          'flex items-center justify-center',
          'terminal-border-glow',
          'relative overflow-hidden',
          isSelected && 'ring-2 ring-[hsl(var(--terminal-amber))]'
        )}
        onClick={isClickable ? onClick : undefined}
        {...getCardClickProps(isClickable, onClick, t('game.selectCard'))}
        whileHover={isClickable ? { scale: 1.08, rotateY: 10 } : {}}
        whileTap={isClickable ? { scale: 0.95 } : {}}
        style={{ transformStyle: 'preserve-3d' }}
      >
        {/* Leuchtende Ecken als Orientierungshilfen */}
        <div className="absolute top-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
        <div className="absolute top-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
        <div className="absolute bottom-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
        <div className="absolute bottom-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />

        <div className="relative w-1/2 h-1/2 border border-[hsl(var(--terminal-green)/0.3)] rounded-sm flex items-center justify-center">
          <div className="w-2/3 h-2/3 border border-[hsl(var(--terminal-green)/0.2)] rotate-45" />
          <div className="absolute w-1.5 h-1.5 bg-[hsl(var(--terminal-green)/0.8)] rounded-full animate-pulse" />
        </div>
      </motion.div>
    );
  }

  const suitColor = SUIT_COLORS[card.suit];
  const suitSymbol = SUIT_SYMBOLS[card.suit];

  const selectedAnimation = {
    scale: [1, 1.03, 1],
    boxShadow: [
      '0 0 8px hsl(var(--terminal-green) / 0.2)',
      '0 0 20px hsl(var(--terminal-amber) / 0.5)',
      '0 0 8px hsl(var(--terminal-green) / 0.2)',
    ],
    transition: {
      duration: 1.5,
      repeat: Infinity,
      ease: 'easeInOut' as const,
    },
  };

  return (
    <motion.div
      {...entranceAnimation}
      layoutId={layoutId}
      className={cn(
        sizeClasses[size],
        'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
        'bg-[hsl(var(--terminal-panel))] terminal-scanlines',
        'flex flex-col items-center justify-between p-1',
        'terminal-border-glow',
        'select-none',
        'relative overflow-hidden font-mono',
        isSelected && 'ring-2 ring-[hsl(var(--terminal-amber))]'
      )}
      onClick={isClickable ? onClick : undefined}
      {...getCardClickProps(isClickable, onClick, t('game.selectCard'))}
      whileHover={
        isClickable
          ? {
              scale: 1.08,
              y: -3,
              rotateX: -5,
              transition: hoverSpring,
            }
          : {}
      }
      whileTap={isClickable ? { scale: 0.95 } : {}}
      animate={isSelected ? selectedAnimation : entranceAnimation.animate}
      style={{ transformStyle: 'preserve-3d' }}
    >
      {/* Äußerer Rahmen */}
      <div className="absolute inset-0.5 border border-[hsl(var(--terminal-green)/0.15)] rounded-sm pointer-events-none" />

      {/* Obere linke Ecke: Rank */}
      <div className={cn('self-start leading-none font-bold z-10 tracking-tighter', suitColor)}>
        {card.rank}
      </div>

      {/* Zentrales geometrisches Symbol */}
      <div className={cn(symbolSizeClasses[size], 'z-10 drop-shadow-[0_0_6px_currentColor]', suitColor)}>
        {suitSymbol}
      </div>

      {/* Untere rechte Ecke: Rank (gedreht) */}
      <div className={cn('self-end leading-none font-bold rotate-180 z-10 tracking-tighter', suitColor)}>
        {card.rank}
      </div>
    </motion.div>
  );
}

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
  const { t } = useI18n();
  const animationsOn = isAnimationsEnabled();
  const sizeClasses = {
    sm: 'w-10 h-14',
    md: 'w-16 h-[5.5rem]',
    lg: 'w-24 h-[8.5rem]',
  };

  const stackBack = (
    <div
      className={cn(
        sizeClasses[size],
        'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
        'circuit-pattern terminal-scanlines',
        'flex items-center justify-center',
        'terminal-border-glow',
        'relative overflow-hidden',
        isClickable && 'cursor-pointer hover:brightness-110'
      )}
    >
      <div className="absolute top-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute top-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute bottom-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
      <div className="absolute bottom-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />

      <div className="relative w-1/2 h-1/2 border border-[hsl(var(--terminal-green)/0.3)] rounded-sm flex items-center justify-center">
        <div className="w-2/3 h-2/3 border border-[hsl(var(--terminal-green)/0.2)] rotate-45" />
        <div className="absolute w-1.5 h-1.5 bg-[hsl(var(--terminal-green)/0.8)] rounded-full animate-pulse" />
      </div>

      <span className="absolute bottom-1 right-1 text-[10px] font-mono text-[hsl(var(--terminal-green)/0.8)] z-10">
        {count}
      </span>
    </div>
  );

  if (!animationsOn) {
    return (
      <div className="flex flex-col items-center gap-2">
        <div
          className={cn('relative', sizeClasses[size], isClickable && 'cursor-pointer hover:scale-105')}
          onClick={isClickable ? onClick : undefined}
          {...getCardClickProps(isClickable, onClick, t('game.selectStack'))}
        >
          {count > 0 && (
            <>
              <div className="absolute -top-1 -left-1 w-full h-full rounded-md bg-[hsl(var(--terminal-green)/0.15)] shadow-md border border-[hsl(var(--terminal-green)/0.2)]" />
              <div className="absolute -top-0.5 -left-0.5 w-full h-full rounded-md bg-[hsl(var(--terminal-panel))] shadow-md border border-[hsl(var(--terminal-green)/0.25)]" />
            </>
          )}
          <div className="relative">
            {topCard ? (
              <CardComponent card={topCard} isVisible={true} size={size} />
            ) : (
              stackBack
            )}
          </div>
        </div>
        {label && (
          <span className="text-xs font-mono text-[hsl(var(--terminal-green)/0.8)] uppercase tracking-wider">{label}</span>
        )}
      </div>
    );
  }

  return (
    <motion.div
      className="flex flex-col items-center gap-2"
      whileHover={isClickable ? { scale: 1.05 } : {}}
    >
      <motion.div
        className={cn('relative', sizeClasses[size])}
        onClick={isClickable ? onClick : undefined}
        {...getCardClickProps(isClickable, onClick, t('game.selectStack'))}
        whileHover={isClickable ? { scale: 1.05 } : {}}
        whileTap={isClickable ? { scale: 0.95 } : {}}
      >
        {count > 0 && (
          <>
            <motion.div
              className="absolute -top-1 -left-1 w-full h-full rounded-md bg-[hsl(var(--terminal-green)/0.15)] shadow-md border border-[hsl(var(--terminal-green)/0.2)]"
              animate={{ y: [0, -2, 0] }}
              transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' as const }}
            />
            <motion.div
              className="absolute -top-0.5 -left-0.5 w-full h-full rounded-md bg-[hsl(var(--terminal-panel))] shadow-md border border-[hsl(var(--terminal-green)/0.25)]"
              animate={{ y: [0, -1, 0] }}
              transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' as const, delay: 0.2 }}
            />
          </>
        )}
        <div className="relative">
          {topCard ? (
            <CardComponent card={topCard} isVisible={true} size={size} />
          ) : (
            <motion.div
              className={cn(
                sizeClasses[size],
                'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
                'circuit-pattern terminal-scanlines',
                'flex items-center justify-center',
                'terminal-border-glow',
                'relative overflow-hidden',
                isClickable && 'cursor-pointer'
              )}
              whileHover={isClickable ? { scale: 1.05 } : {}}
            >
              <div className="absolute top-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
              <div className="absolute top-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
              <div className="absolute bottom-0.5 left-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />
              <div className="absolute bottom-0.5 right-0.5 w-1 h-1 bg-[hsl(var(--terminal-green)/0.6)]" />

              <div className="relative w-1/2 h-1/2 border border-[hsl(var(--terminal-green)/0.3)] rounded-sm flex items-center justify-center">
                <div className="w-2/3 h-2/3 border border-[hsl(var(--terminal-green)/0.2)] rotate-45" />
                <div className="absolute w-1.5 h-1.5 bg-[hsl(var(--terminal-green)/0.8)] rounded-full animate-pulse" />
              </div>

              <span className="absolute bottom-1 right-1 text-[10px] font-mono text-[hsl(var(--terminal-green)/0.8)] z-10">
                {count}
              </span>
            </motion.div>
          )}
        </div>
      </motion.div>
      {label && (
        <span className="text-xs font-mono text-[hsl(var(--terminal-green)/0.8)] uppercase tracking-wider">{label}</span>
      )}
    </motion.div>
  );
}
