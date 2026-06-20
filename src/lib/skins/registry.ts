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
    previewImage: '/skins/default/card-back.svg',
    assets: {
      back: '/skins/default/card-back.svg',
    },
  },
  {
    id: 'neon-green-card-back',
    name: 'Neon-Grün Kartenrücken',
    category: 'cardBack',
    price: 1.99,
    currency: 'EUR',
    previewImage: '/skins/neon-green/card-back.svg',
    assets: {
      back: '/skins/neon-green/card-back.svg',
    },
  },
  {
    id: 'default-table',
    name: 'Standard Tisch',
    category: 'table',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/default/table-bg.jpg',
    assets: {
      felt: '/skins/default/table-bg.jpg',
    },
  },
  {
    id: 'neon-green-table',
    name: 'Neon-Grün Tisch',
    category: 'table',
    price: 2.99,
    currency: 'EUR',
    previewImage: '/skins/neon-green/table-bg.jpg',
    assets: {
      felt: '/skins/neon-green/table-bg.jpg',
    },
  },
  {
    id: 'default-card-face',
    name: 'Standard Kartengesicht',
    category: 'cardFace',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/default/card-face.svg',
    assets: {
      face: '/skins/default/card-face.svg',
    },
  },
  {
    id: 'neon-green-card-face',
    name: 'Neon-Grün Kartengesicht',
    category: 'cardFace',
    price: 1.99,
    currency: 'EUR',
    previewImage: '/skins/neon-green/card-face.svg',
    assets: {
      face: '/skins/neon-green/card-face.svg',
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
