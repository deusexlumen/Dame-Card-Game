import { motion } from 'framer-motion';
import type { Card as CardType } from '@/types/game';
import { SUIT_COLORS, SUIT_SYMBOLS } from '@/types/game';
import { cn } from '@/lib/utils';
import { isAnimationsEnabled } from '@/lib/settings';

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
  const animationsOn = isAnimationsEnabled();
  const sizeClasses = {
    sm: 'w-10 h-14 text-xs',
    md: 'w-16 h-22 text-base',
    lg: 'w-24 h-34 text-xl',
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
        <div
          className={cn(
            sizeClasses[size],
            'rounded-lg border border-slate-600 bg-gradient-to-br from-blue-700 via-blue-800 to-slate-900',
            'flex items-center justify-center shadow-lg',
            'relative overflow-hidden',
            isSelected && 'ring-4 ring-yellow-400',
            isClickable && 'cursor-pointer hover:scale-105'
          )}
          onClick={isClickable ? onClick : undefined}
        >
          {/* Kartenrücken-Muster */}
          <div className="absolute inset-0 opacity-20">
            <div className="absolute inset-0" style={{
              backgroundImage: 'repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(255,255,255,0.1) 4px, rgba(255,255,255,0.1) 8px)',
            }} />
          </div>
          <div className="w-3/4 h-3/4 border border-blue-400/40 rounded flex items-center justify-center relative">
            <span className="text-blue-300/60 text-2xl">♠</span>
          </div>
        </div>
      );
    }

    const suitColor = SUIT_COLORS[card.suit];
    const suitSymbol = SUIT_SYMBOLS[card.suit];

    return (
      <div
        className={cn(
          sizeClasses[size],
          'rounded-lg border border-slate-300 bg-white',
          'flex flex-col items-center justify-between p-1',
          'shadow-[0_2px_8px_rgba(0,0,0,0.15)]',
          'select-none',
          'relative overflow-hidden',
          isSelected && 'ring-4 ring-yellow-400',
          isClickable && 'cursor-pointer hover:scale-105 hover:-translate-y-1'
        )}
        onClick={isClickable ? onClick : undefined}
      >
        {/* Innerer Rahmen */}
        <div className="absolute inset-0.5 border border-slate-200 rounded-md pointer-events-none" />
        <div className={cn('self-start leading-none font-bold z-10', suitColor)}>
          {card.rank}
        </div>
        <div className={cn('text-3xl z-10', suitColor)}>
          {suitSymbol}
        </div>
        <div className={cn('self-end leading-none font-bold rotate-180 z-10', suitColor)}>
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
          'rounded-lg border border-slate-600 bg-gradient-to-br from-blue-700 via-blue-800 to-slate-900',
          'flex items-center justify-center shadow-lg',
          'relative overflow-hidden',
          isSelected && 'ring-4 ring-yellow-400'
        )}
        onClick={isClickable ? onClick : undefined}
        whileHover={isClickable ? { scale: 1.08, rotateY: 10, boxShadow: '0 10px 25px rgba(0,0,0,0.3)' } : {}}
        whileTap={isClickable ? { scale: 0.95 } : {}}
        style={{ transformStyle: 'preserve-3d' }}
      >
        {/* Kartenrücken-Muster */}
        <div className="absolute inset-0 opacity-20">
          <div className="absolute inset-0" style={{
            backgroundImage: 'repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(255,255,255,0.1) 4px, rgba(255,255,255,0.1) 8px)',
          }} />
        </div>
        <div className="w-3/4 h-3/4 border border-blue-400/40 rounded flex items-center justify-center relative">
          <span className="text-blue-300/60 text-2xl">♠</span>
        </div>
      </motion.div>
    );
  }

  const suitColor = SUIT_COLORS[card.suit];
  const suitSymbol = SUIT_SYMBOLS[card.suit];

  const selectedAnimation = {
    scale: [1, 1.05, 1],
    boxShadow: [
      '0 2px 8px rgba(0,0,0,0.15)',
      '0 0 20px rgba(250,204,21,0.6)',
      '0 2px 8px rgba(0,0,0,0.15)',
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
        'rounded-lg border border-slate-300 bg-white',
        'flex flex-col items-center justify-between p-1',
        'shadow-[0_2px_8px_rgba(0,0,0,0.15)]',
        'select-none',
        'relative overflow-hidden',
        isSelected && 'ring-4 ring-yellow-400'
      )}
      onClick={isClickable ? onClick : undefined}
      whileHover={
        isClickable
          ? {
              scale: 1.08,
              y: -5,
              rotateX: -5,
              boxShadow: '0 15px 30px rgba(0,0,0,0.25)',
              transition: hoverSpring,
            }
          : {}
      }
      whileTap={isClickable ? { scale: 0.95 } : {}}
      animate={isSelected ? selectedAnimation : entranceAnimation.animate}
      style={{ transformStyle: 'preserve-3d' }}
    >
      {/* Innerer Rahmen */}
      <div className="absolute inset-0.5 border border-slate-200 rounded-md pointer-events-none" />
      <div className={cn('self-start leading-none font-bold z-10', suitColor)}>
        {card.rank}
      </div>
      <div className={cn('text-3xl z-10', suitColor)}>
        {suitSymbol}
      </div>
      <div className={cn('self-end leading-none font-bold rotate-180 z-10', suitColor)}>
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
  const animationsOn = isAnimationsEnabled();
  const sizeClasses = {
    sm: 'w-10 h-14',
    md: 'w-16 h-22',
    lg: 'w-24 h-34',
  };

  if (!animationsOn) {
    return (
      <div className="flex flex-col items-center gap-2">
        <div
          className={cn('relative', sizeClasses[size], isClickable && 'cursor-pointer hover:scale-105')}
          onClick={isClickable ? onClick : undefined}
        >
          {count > 0 && (
            <>
              <div className="absolute -top-1 -left-1 w-full h-full rounded-lg bg-slate-400 shadow-md" />
              <div className="absolute -top-0.5 -left-0.5 w-full h-full rounded-lg bg-slate-500 shadow-md" />
            </>
          )}
          <div className="relative">
            {topCard ? (
              <CardComponent card={topCard} isVisible={true} size={size} />
            ) : (
              <div
                className={cn(
                  sizeClasses[size],
                  'rounded-lg border border-slate-600 bg-gradient-to-br from-blue-700 via-blue-800 to-slate-900',
                  'flex items-center justify-center relative overflow-hidden'
                )}
              >
                <div className="absolute inset-0 opacity-20" style={{
                  backgroundImage: 'repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(255,255,255,0.1) 4px, rgba(255,255,255,0.1) 8px)',
                }} />
                <span className="text-white/70 text-sm font-bold relative z-10">{count}</span>
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

  return (
    <motion.div
      className="flex flex-col items-center gap-2"
      whileHover={isClickable ? { scale: 1.05 } : {}}
    >
      <motion.div
        className={cn('relative', sizeClasses[size])}
        onClick={isClickable ? onClick : undefined}
        whileHover={isClickable ? { scale: 1.05 } : {}}
        whileTap={isClickable ? { scale: 0.95 } : {}}
      >
        {count > 0 && (
          <>
            <motion.div
              className="absolute -top-1 -left-1 w-full h-full rounded-lg bg-slate-400 shadow-md"
              animate={{ y: [0, -2, 0] }}
              transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' as const }}
            />
            <motion.div
              className="absolute -top-0.5 -left-0.5 w-full h-full rounded-lg bg-slate-500 shadow-md"
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
                'rounded-lg border border-slate-600 bg-gradient-to-br from-blue-700 via-blue-800 to-slate-900',
                'flex items-center justify-center relative overflow-hidden',
                isClickable && 'cursor-pointer'
              )}
              whileHover={
                isClickable
                  ? {
                      boxShadow: '0 10px 25px rgba(0,0,0,0.3)',
                      scale: 1.05,
                    }
                  : {}
              }
            >
              <div className="absolute inset-0 opacity-20" style={{
                backgroundImage: 'repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(255,255,255,0.1) 4px, rgba(255,255,255,0.1) 8px)',
              }} />
              <span className="text-white/70 text-sm font-bold relative z-10">{count}</span>
            </motion.div>
          )}
        </div>
      </motion.div>
      {label && (
        <span className="text-sm text-slate-600 font-medium">{label}</span>
      )}
    </motion.div>
  );
}
