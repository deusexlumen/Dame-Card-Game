import { useSkins } from '@/hooks/useSkins';
import { useI18n } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { getSkinsByCategory } from '@/lib/skins/registry';
import type { SkinCategory } from '@/lib/skins/types';
import { Check } from 'lucide-react';

interface SkinSelectorProps {
  category: SkinCategory;
}

/**
 * Zeigt alle im Besitz befindlichen Skins einer Kategorie als auswählbare Buttons.
 * Durch Klicken wird der Skin für die Kategorie aktiviert.
 */
export function SkinSelector({ category }: SkinSelectorProps) {
  const { t } = useI18n();
  const { inventory, activeSkins, activateSkin } = useSkins();

  const skins = getSkinsByCategory(category).filter((skin) => inventory.includes(skin.id));

  if (skins.length === 0) {
    return (
      <p className="text-sm text-[hsl(var(--terminal-green)/0.7)] text-center py-4">
        {t('skins.noOwnedSkins')}
      </p>
    );
  }

  const activeSkin = activeSkins[category];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
      {skins.map((skin) => {
        const isCurrentlyActive = activeSkin?.id === skin.id;

        return (
          <button
            key={skin.id}
            type="button"
            onClick={() => activateSkin(skin.id, category)}
            className={cn(
              'relative rounded-lg border overflow-hidden text-left',
              'bg-[hsl(var(--terminal-panel))]',
              'border-[hsl(var(--terminal-green)/0.2)]',
              'hover:border-[hsl(var(--terminal-green)/0.5)] hover:bg-[hsl(var(--terminal-green)/0.05)]',
              'focus:outline-none focus:ring-2 focus:ring-[hsl(var(--terminal-green)/0.5)]',
              isCurrentlyActive && 'ring-2 ring-[hsl(var(--terminal-amber))] border-[hsl(var(--terminal-amber)/0.5)]'
            )}
            aria-pressed={isCurrentlyActive}
          >
            <div className="aspect-video w-full overflow-hidden bg-[hsl(var(--terminal-dark))]">
              <img
                src={skin.previewImage}
                alt={skin.name}
                className="w-full h-full object-cover"
                loading="lazy"
              />
            </div>
            <div className="p-2">
              <p className="text-xs font-mono text-[hsl(var(--terminal-green))] truncate">
                {skin.name}
              </p>
              {isCurrentlyActive && (
                <p className="text-[10px] font-mono text-[hsl(var(--terminal-amber))] flex items-center gap-1 mt-1">
                  <Check className="w-3 h-3" />
                  {t('skins.activated')}
                </p>
              )}
            </div>
          </button>
        );
      })}
    </div>
  );
}
