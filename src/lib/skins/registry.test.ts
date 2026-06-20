import { describe, it, expect } from 'vitest';
import { SKIN_REGISTRY, getSkinById, getSkinsByCategory } from './registry';

describe('Skin-Registry', () => {
  it('enthält den Standard-Kartenrücken', () => {
    const skin = getSkinById('default-card-back');
    expect(skin).toBeDefined();
    expect(skin?.name).toBe('Standard Kartenrücken');
    expect(skin?.price).toBe(0);
  });

  it('gruppiert Skins korrekt nach Kategorie', () => {
    const cardBacks = getSkinsByCategory('cardBack');
    const tables = getSkinsByCategory('table');
    const cardFaces = getSkinsByCategory('cardFace');

    expect(cardBacks).toHaveLength(2);
    expect(tables).toHaveLength(2);
    expect(cardFaces).toHaveLength(2);

    expect(cardBacks.map((skin) => skin.id)).toContain('default-card-back');
    expect(cardBacks.map((skin) => skin.id)).toContain('neon-green-card-back');
  });

  it('enthält mindestens sechs Skins', () => {
    expect(SKIN_REGISTRY.length).toBeGreaterThanOrEqual(6);
  });
});
