import { useState } from 'react';
import { useSkins } from '@/hooks/useSkins';
import { useI18n } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { getSkinsByCategory } from '@/lib/skins/registry';
import type { SkinCategory } from '@/lib/skins/types';
import { Button } from '@/components/ui/button';
import { Card as UiCard, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { X, Check, ShoppingBag } from 'lucide-react';

interface SkinShopProps {
  onClose: () => void;
}

const CATEGORY_ORDER: SkinCategory[] = ['cardBack', 'table', 'cardFace'];

/**
 * Shop-Oberfläche für Skins.
 *
 * Zeigt alle verfügbaren Skins gruppiert nach Kategorie. Bereits im Besitz
 * befindliche Skins können aktiviert werden, nicht besessene gekauft werden.
 */
export function SkinShop({ onClose }: SkinShopProps) {
  const { t } = useI18n();
  const { purchaseSkin, activateSkin, isOwned, isActive } = useSkins();
  const [activeCategory, setActiveCategory] = useState<SkinCategory>('cardBack');

  const renderSkinList = (category: SkinCategory) => {
    const skins = getSkinsByCategory(category);

    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {skins.map((skin) => {
          const owned = isOwned(skin.id);
          const active = isActive(skin.id);

          const handleAction = () => {
            if (active) return;
            if (owned) {
              activateSkin(skin.id, category);
            } else {
              purchaseSkin(skin.id);
            }
          };

          const priceLabel = skin.price === 0
            ? t('shop.price.free')
            : t('shop.price.format', { price: skin.price.toFixed(2), currency: skin.currency });

          return (
            <UiCard
              key={skin.id}
              className={cn(
                'bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.2)]',
                active && 'ring-1 ring-[hsl(var(--terminal-amber))]'
              )}
            >
              <CardHeader className="p-3 pb-2">
                <div className="aspect-video w-full rounded-md overflow-hidden bg-[hsl(var(--terminal-dark))] border border-[hsl(var(--terminal-green)/0.2)]">
                  <img
                    src={skin.previewImage}
                    alt={skin.name}
                    className="w-full h-full object-cover"
                    loading="lazy"
                  />
                </div>
              </CardHeader>
              <CardContent className="p-3 pt-0 space-y-2">
                <CardTitle className="text-sm font-mono text-[hsl(var(--terminal-green))]">
                  {skin.name}
                </CardTitle>
                <p className="text-xs font-mono text-[hsl(var(--terminal-green)/0.7)]">
                  {priceLabel}
                </p>
                <Button
                  onClick={handleAction}
                  disabled={active}
                  variant={active ? 'secondary' : 'default'}
                  size="sm"
                  className="w-full text-xs font-mono"
                >
                  {active ? (
                    <>
                      <Check className="w-3.5 h-3.5 mr-1.5" />
                      {t('shop.active')}
                    </>
                  ) : owned ? (
                    <>
                      <Check className="w-3.5 h-3.5 mr-1.5" />
                      {t('shop.activate')}
                    </>
                  ) : (
                    <>
                      <ShoppingBag className="w-3.5 h-3.5 mr-1.5" />
                      {t('shop.buy')}
                    </>
                  )}
                </Button>
              </CardContent>
            </UiCard>
          );
        })}
      </div>
    );
  };

  return (
    <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
      <div className="max-w-3xl w-full">
        <UiCard className="bg-[hsl(var(--terminal-panel))] border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))]">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xl font-mono terminal-glow flex items-center gap-2">
              <ShoppingBag className="w-5 h-5" />
              {t('shop.title')}
            </CardTitle>
            <Button
              variant="outline"
              size="icon"
              onClick={onClose}
              className="h-9 w-9 border-[hsl(var(--terminal-green)/0.3)] text-[hsl(var(--terminal-green))] hover:bg-[hsl(var(--terminal-green)/0.1)]"
              aria-label={t('shop.close')}
            >
              <X className="w-4 h-4" />
            </Button>
          </CardHeader>
          <CardContent>
            <Tabs value={activeCategory} onValueChange={(value) => setActiveCategory(value as SkinCategory)}>
              <TabsList className="w-full bg-[hsl(var(--terminal-dark))] border border-[hsl(var(--terminal-green)/0.2)] mb-4">
                {CATEGORY_ORDER.map((category) => (
                  <TabsTrigger
                    key={category}
                    value={category}
                    className="flex-1 font-mono text-xs data-[state=active]:bg-[hsl(var(--terminal-green))] data-[state=active]:text-black"
                  >
                    {t(`shop.category.${category}`)}
                  </TabsTrigger>
                ))}
              </TabsList>
              {CATEGORY_ORDER.map((category) => (
                <TabsContent key={category} value={category}>
                  {renderSkinList(category)}
                </TabsContent>
              ))}
            </Tabs>
          </CardContent>
        </UiCard>
      </div>
    </div>
  );
}
