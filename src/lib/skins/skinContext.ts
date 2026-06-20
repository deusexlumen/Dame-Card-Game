import { createContext } from 'react';
import type { Skin, SkinCategory } from './types';

/**
 * Wert-Typ für den SkinContext.
 */
export interface SkinContextValue {
  /** IDs aller im Besitz befindlichen Skins. */
  inventory: string[];
  /** Aktuell aktiver Skin pro Kategorie. */
  activeSkins: Record<SkinCategory, Skin | undefined>;
  /** Kauft einen Skin und gibt zurück, ob der Kauf erfolgreich war. */
  purchaseSkin: (skinId: string) => boolean;
  /** Aktiviert einen Skin für eine Kategorie und gibt zurück, ob es geklappt hat. */
  activateSkin: (skinId: string, category: SkinCategory) => boolean;
  /** Prüft, ob ein Skin im Besitz ist. */
  isOwned: (skinId: string) => boolean;
  /** Prüft, ob ein Skin aktuell aktiv ist. */
  isActive: (skinId: string) => boolean;
}

/**
 * React-Kontext für das Skin-System.
 */
export const SkinContext = createContext<SkinContextValue | undefined>(undefined);
