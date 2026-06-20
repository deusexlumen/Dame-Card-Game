import { describe, it, expect, beforeEach } from 'vitest';
import { LocalSkinInventoryService } from './inventoryService';
import { getSkinById } from './registry';

describe('Skin-Integration', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('can purchase and activate a skin end-to-end', () => {
    const service = new LocalSkinInventoryService();
    const skin = getSkinById('neon-green-card-back')!;

    expect(service.purchase(skin.id)).toBe(true);
    expect(service.activate(skin.id, skin.category)).toBe(true);
    expect(service.getActiveSkins().cardBack).toBe(skin.id);
  });
});
