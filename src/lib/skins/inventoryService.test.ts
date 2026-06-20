import { describe, it, expect, beforeEach } from 'vitest';
import { LocalSkinInventoryService } from './inventoryService';

describe('LocalSkinInventoryService', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('erzeugt ein Standard-Inventar mit allen Default-Skins', () => {
    const service = new LocalSkinInventoryService();
    const owned = service.getOwnedSkins();

    expect(owned).toContain('default-card-back');
    expect(owned).toContain('default-table');
    expect(owned).toContain('default-card-face');
    expect(owned).not.toContain('neon-green-card-back');
  });

  it('aktiviert die Default-Skins für jede Kategorie', () => {
    const service = new LocalSkinInventoryService();
    const active = service.getActiveSkins();

    expect(active.cardBack).toBe('default-card-back');
    expect(active.table).toBe('default-table');
    expect(active.cardFace).toBe('default-card-face');
  });

  it('kauft einen neuen Skin und speichert ihn im Inventar', () => {
    const service = new LocalSkinInventoryService();

    expect(service.purchase('neon-green-card-back')).toBe(true);
    expect(service.getOwnedSkins()).toContain('neon-green-card-back');

    // Persistenz überprüfen: ein neuer Service liest den gekauften Skin.
    const reloaded = new LocalSkinInventoryService();
    expect(reloaded.getOwnedSkins()).toContain('neon-green-card-back');
  });

  it('kann einen Skin für die passende Kategorie aktivieren', () => {
    const service = new LocalSkinInventoryService();

    service.purchase('neon-green-card-back');
    expect(service.activate('neon-green-card-back', 'cardBack')).toBe(true);
    expect(service.getActiveSkins().cardBack).toBe('neon-green-card-back');
  });

  it('verweigert die Aktivierung eines nicht besessenen Skins', () => {
    const service = new LocalSkinInventoryService();

    expect(service.activate('neon-green-card-back', 'cardBack')).toBe(false);
    expect(service.getActiveSkins().cardBack).toBe('default-card-back');
  });

  it('verweigert die Aktivierung mit falscher Kategorie', () => {
    const service = new LocalSkinInventoryService();

    service.purchase('neon-green-card-back');
    expect(service.activate('neon-green-card-back', 'table')).toBe(false);
  });

  it('korrumpierten localStorage-Daten werden ignoriert', () => {
    localStorage.setItem('dame-skin-inventory', 'not-json');

    const service = new LocalSkinInventoryService();
    expect(service.getOwnedSkins()).toContain('default-card-back');
    expect(service.getActiveSkins().cardBack).toBe('default-card-back');
  });
});
