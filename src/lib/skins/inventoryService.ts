import type { SkinCategory } from './types';
import { getSkinById, getSkinsByCategory } from './registry';

const INVENTORY_STORAGE_KEY = 'dame-skin-inventory';

/**
 * Persistierte Darstellung des Skin-Inventars.
 */
interface PersistedInventory {
  /** IDs der im Besitz befindlichen Skins. */
  owned: string[];
  /** Aktiver Skin pro Kategorie: category → skinId. */
  active: Record<SkinCategory, string>;
}

/**
 * Service zum Verwalten des lokalen Skin-Inventars über localStorage.
 *
 * Beim ersten Start werden alle kostenlosen Default-Skins besessen und
 * für jede Kategorie aktiviert.
 */
export class LocalSkinInventoryService {
  private owned: Set<string>;
  private active: Record<SkinCategory, string>;

  constructor() {
    const loaded = this.loadFromStorage();
    this.owned = new Set(loaded.owned);
    this.active = { ...loaded.active };
  }

  /**
   * Gibt die IDs aller im Besitz befindlichen Skins zurück.
   */
  getOwnedSkins(): string[] {
    return Array.from(this.owned);
  }

  /**
   * Gibt die aktiven Skins als Record category → skinId zurück.
   */
  getActiveSkins(): Record<SkinCategory, string> {
    return { ...this.active };
  }

  /**
   * Kauft einen Skin und fügt ihn dem Inventar hinzu.
   * Gibt `true` zurück, wenn der Kauf erfolgreich war.
   */
  purchase(skinId: string): boolean {
    const skin = getSkinById(skinId);
    if (!skin || this.owned.has(skinId)) {
      return false;
    }

    this.owned.add(skinId);
    this.save();
    return true;
  }

  /**
   * Aktiviert einen Skin für eine Kategorie.
   * Gibt `true` zurück, wenn die Aktivierung erfolgreich war.
   */
  activate(skinId: string, category: SkinCategory): boolean {
    const skin = getSkinById(skinId);
    if (!skin || skin.category !== category || !this.owned.has(skinId)) {
      return false;
    }

    this.active[category] = skinId;
    this.save();
    return true;
  }

  private loadFromStorage(): PersistedInventory {
    try {
      const raw = localStorage.getItem(INVENTORY_STORAGE_KEY);
      if (!raw) {
        return this.createDefaultInventory();
      }

      const parsed = JSON.parse(raw) as unknown;
      if (this.isValidInventory(parsed)) {
        return parsed;
      }
    } catch {
      // Beschädigter localStorage-Eintrag → auf Defaults zurücksetzen.
    }

    return this.createDefaultInventory();
  }

  private isValidInventory(value: unknown): value is PersistedInventory {
    if (typeof value !== 'object' || value === null) {
      return false;
    }

    const candidate = value as Partial<PersistedInventory>;
    if (!Array.isArray(candidate.owned) || typeof candidate.active !== 'object' || candidate.active === null) {
      return false;
    }

    const requiredCategories: SkinCategory[] = ['cardBack', 'table', 'cardFace'];
    return requiredCategories.every(
      (category) => typeof candidate.active?.[category] === 'string'
    );
  }

  private createDefaultInventory(): PersistedInventory {
    const owned: string[] = [];
    const active: Record<SkinCategory, string> = {
      cardBack: '',
      table: '',
      cardFace: '',
    };

    const categories: SkinCategory[] = ['cardBack', 'table', 'cardFace'];
    for (const category of categories) {
      const defaultSkin = getSkinsByCategory(category).find((skin) => skin.price === 0);
      if (defaultSkin) {
        owned.push(defaultSkin.id);
        active[category] = defaultSkin.id;
      }
    }

    return { owned, active };
  }

  private save(): void {
    try {
      const payload: PersistedInventory = {
        owned: Array.from(this.owned),
        active: { ...this.active },
      };
      localStorage.setItem(INVENTORY_STORAGE_KEY, JSON.stringify(payload));
    } catch {
      // localStorage nicht verfügbar oder voll – Inventar läuft im Speicher weiter.
    }
  }
}
