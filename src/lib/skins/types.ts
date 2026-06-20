/**
 * Verfügbare Kategorien für Skins.
 */
export type SkinCategory = 'cardBack' | 'table' | 'cardFace';

/**
 * Beschreibt einen einzelnen Skin im Shop.
 */
export interface Skin {
  /** Eindeutige Skin-ID. */
  id: string;
  /** Anzeigename im Shop. */
  name: string;
  /** Kategorie, für die der Skin gilt. */
  category: SkinCategory;
  /** Preis in der angegebenen Währung (0 = kostenlos). */
  price: number;
  /** Währung, z. B. EUR. */
  currency: string;
  /** Pfad/URL zum Vorschaubild. */
  previewImage: string;
  /** Zugehörige Assets (z. B. Texturen), key → path/URL. */
  assets: Record<string, string>;
}
