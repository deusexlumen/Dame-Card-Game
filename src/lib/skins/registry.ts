import type { Skin, SkinCategory } from './types';

/**
 * Globale Skin-Registry. Enthält alle im Spiel verfügbaren Skins.
 */
export const SKIN_REGISTRY: readonly Skin[] = [
  {
    id: 'default-card-back',
    name: 'Standard Kartenrücken',
    category: 'cardBack',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/card-backs/default-preview.svg',
    assets: {
      back: '/skins/card-backs/default-back.svg',
    },
  },
  {
    id: 'neon-green-card-back',
    name: 'Neon-Grün Kartenrücken',
    category: 'cardBack',
    price: 1.99,
    currency: 'EUR',
    previewImage: '/skins/card-backs/neon-green-preview.svg',
    assets: {
      back: '/skins/card-backs/neon-green-back.svg',
    },
  },
  {
    id: 'default-table',
    name: 'Standard Tisch',
    category: 'table',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/tables/default-preview.svg',
    assets: {
      felt: '/skins/tables/default-felt.svg',
    },
  },
  {
    id: 'neon-green-table',
    name: 'Neon-Grün Tisch',
    category: 'table',
    price: 2.99,
    currency: 'EUR',
    previewImage: '/skins/tables/neon-green-preview.svg',
    assets: {
      felt: '/skins/tables/neon-green-felt.svg',
    },
  },
  {
    id: 'default-card-face',
    name: 'Standard Kartengesicht',
    category: 'cardFace',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/card-faces/default-preview.svg',
    assets: {
      face: '/skins/card-faces/default-face.svg',
    },
  },
  {
    id: 'neon-green-card-face',
    name: 'Neon-Grün Kartengesicht',
    category: 'cardFace',
    price: 1.99,
    currency: 'EUR',
    previewImage: '/skins/card-faces/neon-green-preview.svg',
    assets: {
      face: '/skins/card-faces/neon-green-face.svg',
    },
  },
] as const;

/**
 * Liefert einen Skin anhand seiner ID oder `undefined`.
 */
export function getSkinById(id: string): Skin | undefined {
  return SKIN_REGISTRY.find((skin) => skin.id === id);
}

/**
 * Liefert alle Skins einer bestimmten Kategorie.
 */
export function getSkinsByCategory(category: SkinCategory): Skin[] {
  return SKIN_REGISTRY.filter((skin) => skin.category === category);
}
