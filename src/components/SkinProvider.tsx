import {
  useCallback,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { LocalSkinInventoryService } from '@/lib/skins/inventoryService';
import { SkinContext, type SkinContextValue } from '@/lib/skins/skinContext';
import { getSkinById } from '@/lib/skins/registry';
import type { Skin, SkinCategory } from '@/lib/skins/types';

interface SkinProviderProps {
  children: ReactNode;
}

/**
 * Provider für das Skin-System.
 *
 * Verwaltet Besitz und Aktivierung über LocalSkinInventoryService und
 * stellt die Daten für untergeordnete Komponenten bereit.
 */
export function SkinProvider({ children }: SkinProviderProps) {
  const [service] = useState(() => new LocalSkinInventoryService());
  const [ownedIds, setOwnedIds] = useState(() => service.getOwnedSkins());
  const [activeIds, setActiveIds] = useState(() => service.getActiveSkins());

  const activeSkins = useMemo<Record<SkinCategory, Skin | undefined>>(() => {
    const result: Record<SkinCategory, Skin | undefined> = {
      cardBack: undefined,
      table: undefined,
      cardFace: undefined,
    };

    (Object.keys(activeIds) as SkinCategory[]).forEach((category) => {
      result[category] = getSkinById(activeIds[category]);
    });

    return result;
  }, [activeIds]);

  const purchaseSkin = useCallback(
    (skinId: string) => {
      const success = service.purchase(skinId);
      if (success) {
        setOwnedIds(service.getOwnedSkins());
      }
      return success;
    },
    [service]
  );

  const activateSkin = useCallback(
    (skinId: string, category: SkinCategory) => {
      const success = service.activate(skinId, category);
      if (success) {
        setActiveIds(service.getActiveSkins());
      }
      return success;
    },
    [service]
  );

  const isOwned = useCallback(
    (skinId: string) => ownedIds.includes(skinId),
    [ownedIds]
  );

  const isActive = useCallback(
    (skinId: string) => Object.values(activeIds).includes(skinId),
    [activeIds]
  );

  const value = useMemo<SkinContextValue>(
    () => ({
      inventory: ownedIds,
      activeSkins,
      purchaseSkin,
      activateSkin,
      isOwned,
      isActive,
    }),
    [ownedIds, activeSkins, purchaseSkin, activateSkin, isOwned, isActive]
  );

  return <SkinContext.Provider value={value}>{children}</SkinContext.Provider>;
}
