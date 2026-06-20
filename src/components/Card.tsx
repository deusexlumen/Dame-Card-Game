import { motion } from 'framer-motion';
import type { Card as CardType } from '@/types/game';
import { SUIT_COLORS, SUIT_SYMBOLS } from '@/types/game';
import { cn } from '@/lib/utils';
import { isAnimationsEnabled } from '@/lib/settings';
import { useI18n } from '@/lib/i18n';
import { useSkins } from '@/hooks/useSkins';

interface CardProps {
  card: CardType;
  faceUp?: boolean;
  className?: string;
  onClick?: () => void;
}

/**
 * Skin-fähige Kartenkomponente.
 *
 * Rendert eine Karte mit dem aktiven Kartenrücken- bzw. Kartengesicht-Asset.
 * Ist `onClick` vorhanden, wird ein Button gerendert, ansonsten ein div.
 */
export function Card({ card, faceUp = false, className, onClick }: CardProps) {
  const { t } = useI18n();
  const { activeSkins } = useSkins();

  const backUrl = activeSkins.cardBack?.assets.back ?? '';
  const faceUrl = activeSkins.cardFace?.assets.face ?? '';

  const suitColor = SUIT_COLORS[card.suit];
  const suitSymbol = SUIT_SYMBOLS[card.suit];

  const baseClassName = cn(
    'relative rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
    'bg-cover bg-center bg-no-repeat',
    'flex items-center justify-center',
    'select-none font-mono',
    onClick ? 'cursor-pointer hover:brightness-110' : 'cursor-default',
    className
  );

  const style = { backgroundImage: `url(${faceUp ? faceUrl : backUrl})` };

  const faceOverlay = faceUp && (
    <>
      <div className="absolute inset-0.5 border border-[hsl(var(--terminal-green)/0.15)] rounded-sm pointer-events-none" />
      <span className={cn('absolute top-1 left-1 leading-none font-bold z-10 tracking-tighter', suitColor)}>
        {card.rank}
      </span>
      <span className={cn('text-2xl z-10 drop-shadow-[0_0_6px_currentColor]', suitColor)}>
        {suitSymbol}
      </span>
      <span className={cn('absolute bottom-1 right-1 leading-none font-bold rotate-180 z-10 tracking-tighter', suitColor)}>
        {card.rank}
      </span>
    </>
  );

  if (onClick) {
    return (
      <button
        type="button"
        className={baseClassName}
        style={style}
        onClick={onClick}
        aria-label={faceUp ? `${card.rank} ${card.suit}` : t('game.selectCard')}
      >
        {faceOverlay}
      </button>
    );
  }

  return (
    <div
      className={baseClassName}
      style={style}
      aria-label={faceUp ? `${card.rank} ${card.suit}` : t('game.selectCard')}
    >
      {faceOverlay}
    </div>
  );
}

interface CardComponentProps {
  card: CardType;
  isVisible?: boolean;
  isSelected?: boolean;
  isClickable?: boolean;
  onClick?: () => void;
  size?: 'sm' | 'md' | 'lg';
  animate?: boolean;
  index?: number;
  layoutId?: string;
  className?: string;
}

const sizeClasses = {
  sm: 'w-10 h-14 text-[8px]',
  md: 'w-16 h-[5.5rem] text-xs',
  lg: 'w-24 h-[8.5rem] text-sm',
};

/**
 * Legacy-kompatible Kartenkomponente mit Animationen.
 *
 * Verwendet intern die neue `Card`-Komponente und ergänzt Größen,
 * Auswahl-Status und Framer-Motion-Animationen.
 */
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
  className: extraClassName,
}: CardComponentProps) {
  const animationsOn = isAnimationsEnabled() && animate;

  const className = cn(
    sizeClasses[size],
    isSelected && 'ring-2 ring-[hsl(var(--terminal-amber))]',
    isClickable && 'hover:-translate-y-0.5',
    extraClassName
  );

  if (!animationsOn) {
    return (
      <Card
        card={card}
        faceUp={isVisible}
        className={className}
        onClick={isClickable ? onClick : undefined}
      />
    );
  }

  const springTransition = {
    type: 'spring' as const,
    stiffness: 300,
    damping: 25,
    delay: index * 0.05,
  };

  return (
    <motion.div
      layoutId={layoutId}
      initial={{ opacity: 0, y: -30, scale: 0.8 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={springTransition}
      whileHover={isClickable ? { scale: 1.08, y: -3 } : {}}
      whileTap={isClickable ? { scale: 0.95 } : {}}
    >
      <Card
        card={card}
        faceUp={isVisible}
        className={className}
        onClick={isClickable ? onClick : undefined}
      />
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
  className?: string;
}

/**
 * Darstellung eines Kartenstapels (Zieh- oder Ablagestapel).
 *
 * Verwendet den aktiven Kartenrücken-Skin und zeigt optional die oberste Karte.
 */
export function CardStack({
  count = 0,
  label,
  onClick,
  isClickable = false,
  topCard = null,
  size = 'md',
  className: extraClassName,
}: CardStackProps) {
  const { t } = useI18n();
  const { activeSkins } = useSkins();
  const backUrl = activeSkins.cardBack?.assets.back ?? '';
  const animationsOn = isAnimationsEnabled();
  const sizeClass = sizeClasses[size];

  const stackBack = (
    <div
      className={cn(
        sizeClass,
        'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
        'bg-cover bg-center bg-no-repeat',
        'flex items-center justify-center',
        'terminal-border-glow',
        'relative overflow-hidden',
        isClickable && 'cursor-pointer hover:brightness-110',
        extraClassName
      )}
      style={{ backgroundImage: `url(${backUrl})` }}
    >
      <span className="absolute bottom-1 right-1 text-[10px] font-mono text-[hsl(var(--terminal-green)/0.8)] z-10">
        {count}
      </span>
    </div>
  );

  if (!animationsOn) {
    return (
      <div className="flex flex-col items-center gap-2">
        <div
          className={cn('relative', sizeClass, isClickable && 'cursor-pointer hover:scale-105')}
          onClick={isClickable ? onClick : undefined}
          role={isClickable ? 'button' : undefined}
          tabIndex={isClickable ? 0 : undefined}
          aria-label={isClickable ? t('game.selectStack') : undefined}
        >
          {count > 0 && (
            <>
              <div className="absolute -top-1 -left-1 w-full h-full rounded-md bg-[hsl(var(--terminal-green)/0.15)] shadow-md border border-[hsl(var(--terminal-green)/0.2)]" />
              <div className="absolute -top-0.5 -left-0.5 w-full h-full rounded-md bg-[hsl(var(--terminal-panel))] shadow-md border border-[hsl(var(--terminal-green)/0.25)]" />
            </>
          )}
          <div className="relative">
            {topCard ? (
              <Card card={topCard} faceUp className={cn(sizeClass, extraClassName)} />
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
        className={cn('relative', sizeClass)}
        onClick={isClickable ? onClick : undefined}
        role={isClickable ? 'button' : undefined}
        tabIndex={isClickable ? 0 : undefined}
        aria-label={isClickable ? t('game.selectStack') : undefined}
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
            <Card card={topCard} faceUp className={cn(sizeClass, extraClassName)} />
          ) : (
            <motion.div
              className={cn(
                sizeClass,
                'rounded-md border border-[hsl(var(--terminal-green)/0.4)]',
                'bg-cover bg-center bg-no-repeat',
                'flex items-center justify-center',
                'terminal-border-glow',
                'relative overflow-hidden',
                isClickable && 'cursor-pointer',
                extraClassName
              )}
              style={{ backgroundImage: `url(${backUrl})` }}
              whileHover={isClickable ? { scale: 1.05 } : {}}
            >
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
