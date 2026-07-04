# Professional Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verwandle das Dame Card Game in ein professionelles Modern-Dark-Casino-Erlebnis mit Skin-System, Pseudo-3D-Ansicht, Soundeffekten und Musik.

**Architecture:** Ein zentrales Skin-System mit `SkinProvider`, `useSkins`-Hook und `LocalSkinInventoryService` verwaltet gekaufte und aktive Skins. Komponenten lesen Skin-Assets über `useSkins()` und rendern Karten/Tische dynamisch. Sound und Musik werden durch eine erweiterte Sound-Engine abgespielt. Pseudo-3D wird per CSS-Transforms realisiert und ist optional abschaltbar.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS 3.4, shadcn/ui, Vitest.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `src/lib/skins/types.ts` | Skin-Typen. |
| `src/lib/skins/registry.ts` | Statische Liste aller Skins. |
| `src/lib/skins/inventoryService.ts` | Lokales Inventar (Kauf/Aktivierung/Persistenz). |
| `src/lib/skins/inventoryService.test.ts` | Tests für Inventar-Service. |
| `src/hooks/useSkins.ts` | React-Hook für aktive Skins. |
| `src/components/SkinProvider.tsx` | Context Provider. |
| `src/components/SkinShop.tsx` | Shop-UI. |
| `src/components/SkinSelector.tsx` | Schnellauswahl im Spiel. |
| `public/skins/default/*` | Standard-Skin-Assets. |
| `public/skins/neon-green/*` | Beispiel-Skin-Assets. |
| `src/components/Card.tsx` | Wiederverwendbare Karten-Komponente mit Skin-Unterstützung. |
| `src/components/GameBoard.tsx` | Wendet Tisch-Skin an, integriert SkinSelector. |
| `src/lib/soundEngine.ts` | Erweiterte Sound-Engine für Effekte und Musik. |
| `src/hooks/useSound.ts` | Hook für Sound-Steuerung. |
| `src/components/SettingsPanel.tsx` | Erweitert um Audio-Einstellungen. |
| `src/App.tsx` | Integriert SkinProvider und SkinShop-Zugang. |
| `src/lib/i18n.tsx` | Neue Übersetzungen. |
| `src/index.css` / `src/App.css` | Pseudo-3D-CSS-Klassen. |

---

## Task 1: Skin Types and Registry

**Files:**
- Create: `src/lib/skins/types.ts`
- Create: `src/lib/skins/registry.ts`

- [ ] **Step 1: Write the failing test**

In `src/lib/skins/registry.test.ts`:

```ts
import { SKIN_REGISTRY, getSkinById, getSkinsByCategory } from './registry';

describe('registry', () => {
  it('contains default card back skin', () => {
    const skin = getSkinById('default-card-back');
    expect(skin).toBeDefined();
    expect(skin?.category).toBe('cardBack');
  });

  it('groups skins by category', () => {
    const backs = getSkinsByCategory('cardBack');
    expect(backs.length).toBeGreaterThanOrEqual(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/lib/skins/registry.test.ts
```

Expected: FAIL – module not found.

- [ ] **Step 3: Implement types and registry**

`src/lib/skins/types.ts`:

```ts
export type SkinCategory = 'cardBack' | 'table' | 'cardFace';

export interface Skin {
  id: string;
  name: string;
  category: SkinCategory;
  price: number;
  currency: 'EUR';
  previewImage: string;
  assets: {
    cardBack?: string;
    cardFace?: string;
    table?: string;
  };
}
```

`src/lib/skins/registry.ts`:

```ts
import type { Skin, SkinCategory } from './types';

export const SKIN_REGISTRY: Skin[] = [
  {
    id: 'default-card-back',
    name: 'Standard Rückseite',
    category: 'cardBack',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/default/card-back-preview.svg',
    assets: { cardBack: '/skins/default/card-back.svg' },
  },
  {
    id: 'neon-green-card-back',
    name: 'Neon Green Rückseite',
    category: 'cardBack',
    price: 199,
    currency: 'EUR',
    previewImage: '/skins/neon-green/card-back-preview.svg',
    assets: { cardBack: '/skins/neon-green/card-back.svg' },
  },
  {
    id: 'default-table',
    name: 'Standard Tisch',
    category: 'table',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/default/table-preview.jpg',
    assets: { table: '/skins/default/table-bg.jpg' },
  },
  {
    id: 'neon-green-table',
    name: 'Neon Green Filz',
    category: 'table',
    price: 299,
    currency: 'EUR',
    previewImage: '/skins/neon-green/table-preview.jpg',
    assets: { table: '/skins/neon-green/table-bg.jpg' },
  },
  {
    id: 'default-card-face',
    name: 'Standard Vorderseite',
    category: 'cardFace',
    price: 0,
    currency: 'EUR',
    previewImage: '/skins/default/card-face-preview.svg',
    assets: { cardFace: '/skins/default/card-face.svg' },
  },
  {
    id: 'neon-green-card-face',
    name: 'Neon Green Vorderseite',
    category: 'cardFace',
    price: 199,
    currency: 'EUR',
    previewImage: '/skins/neon-green/card-face-preview.svg',
    assets: { cardFace: '/skins/neon-green/card-face.svg' },
  },
];

export function getSkinById(id: string): Skin | undefined {
  return SKIN_REGISTRY.find((skin) => skin.id === id);
}

export function getSkinsByCategory(category: SkinCategory): Skin[] {
  return SKIN_REGISTRY.filter((skin) => skin.category === category);
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/lib/skins/registry.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/skins/
git commit -m "feat(skins): add skin types and registry"
```

---

## Task 2: Local Inventory Service

**Files:**
- Create: `src/lib/skins/inventoryService.ts`
- Create: `src/lib/skins/inventoryService.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { LocalSkinInventoryService } from './inventoryService';

describe('LocalSkinInventoryService', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('returns default inventory', () => {
    const service = new LocalSkinInventoryService();
    expect(service.getOwnedSkins()).toContain('default-card-back');
    expect(service.getActiveSkins()).toEqual({
      cardBack: 'default-card-back',
      table: 'default-table',
      cardFace: 'default-card-face',
    });
  });

  it('purchases a skin', () => {
    const service = new LocalSkinInventoryService();
    service.purchase('neon-green-card-back');
    expect(service.getOwnedSkins()).toContain('neon-green-card-back');
  });

  it('activates a skin', () => {
    const service = new LocalSkinInventoryService();
    service.purchase('neon-green-card-back');
    service.activate('neon-green-card-back');
    expect(service.getActiveSkins().cardBack).toBe('neon-green-card-back');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/lib/skins/inventoryService.test.ts
```

Expected: FAIL.

- [ ] **Step 3: Implement inventory service**

```ts
import type { SkinCategory } from './types';

export interface SkinInventory {
  owned: string[];
  active: Record<SkinCategory, string>;
}

const STORAGE_KEY = 'dame-skin-inventory';

export class LocalSkinInventoryService {
  private inventory: SkinInventory;

  constructor() {
    this.inventory = this.load();
  }

  private load(): SkinInventory {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<SkinInventory>;
        return {
          owned: Array.isArray(parsed.owned) ? parsed.owned : this.getDefaultInventory().owned,
          active: { ...this.getDefaultInventory().active, ...parsed.active },
        };
      }
    } catch {
      // ignore corrupt storage
    }
    return this.getDefaultInventory();
  }

  private save(): void {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.inventory));
  }

  private getDefaultInventory(): SkinInventory {
    return {
      owned: ['default-card-back', 'default-table', 'default-card-face'],
      active: {
        cardBack: 'default-card-back',
        table: 'default-table',
        cardFace: 'default-card-face',
      },
    };
  }

  getOwnedSkins(): string[] {
    return [...this.inventory.owned];
  }

  getActiveSkins(): Record<SkinCategory, string> {
    return { ...this.inventory.active };
  }

  purchase(skinId: string): boolean {
    if (this.inventory.owned.includes(skinId)) return false;
    this.inventory.owned.push(skinId);
    this.save();
    return true;
  }

  activate(skinId: string, category: SkinCategory): boolean {
    if (!this.inventory.owned.includes(skinId)) return false;
    this.inventory.active[category] = skinId;
    this.save();
    return true;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/lib/skins/inventoryService.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/skins/
git commit -m "feat(skins): add local inventory service"
```

---

## Task 3: Skin Provider and Hook

**Files:**
- Create: `src/components/SkinProvider.tsx`
- Create: `src/hooks/useSkins.ts`

- [ ] **Step 1: Create SkinContext and Provider**

`src/components/SkinProvider.tsx`:

```tsx
import { createContext, useState, useCallback, useMemo, type ReactNode } from 'react';
import { LocalSkinInventoryService } from '@/lib/skins/inventoryService';
import type { Skin, SkinCategory, SkinInventory } from '@/lib/skins/types';
import { getSkinById } from '@/lib/skins/registry';

export interface SkinContextValue {
  inventory: SkinInventory;
  activeSkins: Record<SkinCategory, Skin | undefined>;
  purchaseSkin: (skinId: string) => boolean;
  activateSkin: (skinId: string, category: SkinCategory) => boolean;
  isOwned: (skinId: string) => boolean;
  isActive: (skinId: string) => boolean;
}

export const SkinContext = createContext<SkinContextValue | null>(null);

export function SkinProvider({ children }: { children: ReactNode }) {
  const [service] = useState(() => new LocalSkinInventoryService());
  const [inventory, setInventory] = useState(() => ({
    owned: service.getOwnedSkins(),
    active: service.getActiveSkins(),
  }));

  const refresh = useCallback(() => {
    setInventory({
      owned: service.getOwnedSkins(),
      active: service.getActiveSkins(),
    });
  }, [service]);

  const purchaseSkin = useCallback((skinId: string) => {
    const success = service.purchase(skinId);
    if (success) refresh();
    return success;
  }, [service, refresh]);

  const activateSkin = useCallback((skinId: string, category: SkinCategory) => {
    const success = service.activate(skinId, category);
    if (success) refresh();
    return success;
  }, [service, refresh]);

  const activeSkins = useMemo(() => ({
    cardBack: getSkinById(inventory.active.cardBack),
    table: getSkinById(inventory.active.table),
    cardFace: getSkinById(inventory.active.cardFace),
  }), [inventory.active]);

  const isOwned = useCallback((skinId: string) => inventory.owned.includes(skinId), [inventory.owned]);
  const isActive = useCallback((skinId: string) => Object.values(inventory.active).includes(skinId), [inventory.active]);

  return (
    <SkinContext.Provider value={{ inventory, activeSkins, purchaseSkin, activateSkin, isOwned, isActive }}>
      {children}
    </SkinContext.Provider>
  );
}
```

- [ ] **Step 2: Create useSkins hook**

`src/hooks/useSkins.ts`:

```ts
import { useContext } from 'react';
import { SkinContext } from '@/components/SkinProvider';

export function useSkins() {
  const context = useContext(SkinContext);
  if (!context) {
    throw new Error('useSkins must be used within SkinProvider');
  }
  return context;
}
```

- [ ] **Step 3: Wrap App with SkinProvider**

In `src/App.tsx`:

```tsx
import { SkinProvider } from '@/components/SkinProvider';

function App() {
  return (
    <SkinProvider>
      <I18nProvider>
        {/* existing providers */}
        <AppContent />
      </I18nProvider>
    </SkinProvider>
  );
}
```

- [ ] **Step 4: Run tests and lint**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 5: Commit**

```bash
git add src/components/SkinProvider.tsx src/hooks/useSkins.ts src/App.tsx
git commit -m "feat(skins): add provider and useSkins hook"
```

---

## Task 4: Default and Neon-Green Skin Assets

**Files:**
- Create: `public/skins/default/card-back.svg`
- Create: `public/skins/default/card-back-preview.svg`
- Create: `public/skins/default/card-face.svg`
- Create: `public/skins/default/card-face-preview.svg`
- Create: `public/skins/default/table-bg.jpg`
- Create: `public/skins/default/table-preview.jpg`
- Create: `public/skins/neon-green/card-back.svg`
- Create: `public/skins/neon-green/card-back-preview.svg`
- Create: `public/skins/neon-green/card-face.svg`
- Create: `public/skins/neon-green/card-face-preview.svg`
- Create: `public/skins/neon-green/table-bg.jpg`
- Create: `public/skins/neon-green/table-preview.jpg`

- [ ] **Step 1: Create placeholder SVG assets**

For `public/skins/default/card-back.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 140">
  <rect width="100" height="140" rx="8" fill="#1e293b" stroke="#334155" stroke-width="2"/>
  <circle cx="50" cy="70" r="25" fill="none" stroke="#22c55e" stroke-width="2"/>
</svg>
```

For `public/skins/neon-green/card-back.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 140">
  <defs>
    <linearGradient id="ng" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0f172a"/>
      <stop offset="100%" stop-color="#1e293b"/>
    </linearGradient>
  </defs>
  <rect width="100" height="140" rx="8" fill="url(#ng)" stroke="#22c55e" stroke-width="3"/>
  <circle cx="50" cy="70" r="20" fill="none" stroke="#22c55e" stroke-width="2" filter="drop-shadow(0 0 4px #22c55e)"/>
</svg>
```

Create the following placeholder files:

`public/skins/default/card-face.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 140">
  <rect width="100" height="140" rx="8" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2"/>
</svg>
```

`public/skins/neon-green/card-face.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 140">
  <defs>
    <linearGradient id="ngf" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0f172a"/>
      <stop offset="100%" stop-color="#1e293b"/>
    </linearGradient>
  </defs>
  <rect width="100" height="140" rx="8" fill="url(#ngf)" stroke="#22c55e" stroke-width="2"/>
</svg>
```

For preview images, reuse the corresponding SVG files where acceptable, or create small 200x140 SVG previews.

For table backgrounds, create small placeholder JPG files (e.g. 800x600 solid color) or use placeholder services. If JPG creation is inconvenient, register `.jpg` paths but ship `.svg` files and update registry paths accordingly.

- [ ] **Step 2: Verify assets are served**

Run dev server and open e.g. `http://localhost:5173/skins/default/card-back.svg`.

- [ ] **Step 3: Commit**

```bash
git add public/skins/
git commit -m "assets(skins): add default and neon-green skin placeholders"
```

---

## Task 5: Card and Table Components with Skin Support

**Files:**
- Create: `src/components/Card.tsx`
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 1: Create Card component**

`src/components/Card.tsx`:

```tsx
import { useSkins } from '@/hooks/useSkins';
import type { Card as CardType } from '@/types/game';

interface CardProps {
  card: CardType;
  faceUp?: boolean;
  className?: string;
  onClick?: () => void;
}

export function Card({ card, faceUp = false, className = '', onClick }: CardProps) {
  const { activeSkins } = useSkins();
  const cardBackUrl = activeSkins.cardBack?.assets.cardBack ?? '/skins/default/card-back.svg';
  const cardFaceUrl = activeSkins.cardFace?.assets.cardFace ?? '/skins/default/card-face.svg';

  return (
    <button
      type="button"
      onClick={onClick}
      className={`relative w-16 h-24 rounded-lg shadow-md transition-transform hover:scale-105 ${className}`}
      style={{
        backgroundImage: `url(${faceUp ? cardFaceUrl : cardBackUrl})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }}
    >
      {faceUp && (
        <span className="absolute inset-0 flex items-center justify-center text-2xl font-bold text-slate-900">
          {card.rank}{card.suit}
        </span>
      )}
    </button>
  );
}
```

- [ ] **Step 2: Apply table skin in GameBoard**

In `src/components/GameBoard.tsx`:

```tsx
const { activeSkins } = useSkins();
const tableUrl = activeSkins.table?.assets.table ?? '/skins/default/table-bg.jpg';
```

Apply as background:

```tsx
<div
  className="min-h-screen w-full bg-cover bg-center"
  style={{ backgroundImage: `url(${tableUrl})` }}
>
  {/* existing board content */}
</div>
```

- [ ] **Step 3: Replace existing card rendering with Card component**

Find places where cards are rendered and replace with `<Card card={card} faceUp={...} ... />`.

- [ ] **Step 4: Run tests and lint**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 5: Commit**

```bash
git add src/components/Card.tsx src/components/GameBoard.tsx
git commit -m "feat(ui): apply skins to cards and table"
```

---

## Task 6: Skin Shop and Selector

**Files:**
- Create: `src/components/SkinShop.tsx`
- Create: `src/components/SkinSelector.tsx`
- Modify: `src/App.tsx`

- [ ] **Step 1: Create SkinShop component**

`src/components/SkinShop.tsx`:

```tsx
import { useSkins } from '@/hooks/useSkins';
import { useI18n } from '@/lib/i18n';
import { SKIN_REGISTRY } from '@/lib/skins/registry';
import type { SkinCategory } from '@/lib/skins/types';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface SkinShopProps {
  onClose: () => void;
}

const categories: SkinCategory[] = ['cardBack', 'table', 'cardFace'];

export function SkinShop({ onClose }: SkinShopProps) {
  const { t } = useI18n();
  const { purchaseSkin, activateSkin, isOwned, isActive } = useSkins();

  return (
    <Card className="max-w-3xl mx-auto max-h-[90vh] overflow-auto">
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>{t('shop.title')}</CardTitle>
        <Button variant="ghost" onClick={onClose}>{t('common.close')}</Button>
      </CardHeader>
      <CardContent className="space-y-8">
        {categories.map((category) => (
          <section key={category}>
            <h3 className="text-lg font-bold mb-3">{t(`shop.category.${category}`)}</h3>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
              {SKIN_REGISTRY.filter((s) => s.category === category).map((skin) => {
                const owned = isOwned(skin.id);
                const active = isActive(skin.id);
                return (
                  <div key={skin.id} className="border rounded-lg p-3 flex flex-col gap-2">
                    <img src={skin.previewImage} alt={skin.name} className="w-full h-24 object-cover rounded" />
                    <div className="font-medium">{skin.name}</div>
                    <div className="text-sm opacity-70">
                      {skin.price === 0 ? t('shop.free') : `€${(skin.price / 100).toFixed(2)}`}
                    </div>
                    {owned ? (
                      <Button
                        variant={active ? 'secondary' : 'default'}
                        onClick={() => activateSkin(skin.id, skin.category)}
                        disabled={active}
                      >
                        {active ? t('shop.active') : t('shop.activate')}
                      </Button>
                    ) : (
                      <Button onClick={() => purchaseSkin(skin.id)}>
                        {t('shop.buy')}
                      </Button>
                    )}
                  </div>
                );
              })}
            </div>
          </section>
        ))}
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 2: Create SkinSelector component**

`src/components/SkinSelector.tsx`:

```tsx
import { useSkins } from '@/hooks/useSkins';
import { useI18n } from '@/lib/i18n';
import { SKIN_REGISTRY } from '@/lib/skins/registry';
import type { SkinCategory } from '@/lib/skins/types';
import { Button } from '@/components/ui/button';

interface SkinSelectorProps {
  category: SkinCategory;
}

export function SkinSelector({ category }: SkinSelectorProps) {
  const { t } = useI18n();
  const { activateSkin, isOwned, inventory } = useSkins();
  const skins = SKIN_REGISTRY.filter((s) => s.category === category && isOwned(s.id));

  return (
    <div className="flex gap-2 flex-wrap">
      {skins.map((skin) => (
        <Button
          key={skin.id}
          variant={inventory.active[category] === skin.id ? 'default' : 'outline'}
          size="sm"
          onClick={() => activateSkin(skin.id, category)}
        >
          {skin.name}
        </Button>
      ))}
    </div>
  );
}
```

- [ ] **Step 3: Add shop access in App.tsx**

Add `'shop'` to `GameMode` and a button to open it from the main menu.

- [ ] **Step 4: Run tests and lint**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 5: Commit**

```bash
git add src/components/SkinShop.tsx src/components/SkinSelector.tsx src/App.tsx
git commit -m "feat(ui): add skin shop and selector"
```

---

## Task 7: Sound and Music Engine

**Files:**
- Modify: `src/lib/sounds.ts`
- Modify: `src/lib/settings.ts`
- Modify: `src/hooks/useSettings.ts`
- Modify: `src/components/SettingsPanel.tsx`

- [ ] **Step 1: Extend sounds module with volume control and file-based music**

`src/lib/sounds.ts`:

```ts
// Add at the top
let musicVolume = 0.5;
let effectsVolume = 0.7;
let musicAudio: HTMLAudioElement | null = null;

export function setMusicVolume(vol: number) {
  musicVolume = Math.max(0, Math.min(1, vol));
  if (bgMusicNodes) {
    bgMusicNodes.gain.gain.setTargetAtTime(musicVolume * 0.015, audioCtx?.currentTime ?? 0, 0.1);
  }
  if (musicAudio) {
    musicAudio.volume = musicVolume;
  }
}

export function setEffectsVolume(vol: number) {
  effectsVolume = Math.max(0, Math.min(1, vol));
}

export function getMusicVolume() {
  return musicVolume;
}

export function getEffectsVolume() {
  return effectsVolume;
}

// Add helper to apply volume to effect gains
function applyEffectVolume(gain: GainNode) {
  const base = gain.gain.value;
  gain.gain.setValueAtTime(base * effectsVolume, audioCtx?.currentTime ?? 0);
}

// Optional: play file-based background music
export function playMusicTrack(src: string) {
  if (!isMusicEnabled()) return;
  try {
    stopBackgroundMusic();
    musicAudio = new Audio(src);
    musicAudio.loop = true;
    musicAudio.volume = musicVolume;
    musicAudio.play().catch(() => {});
  } catch {
    // ignore
  }
}
```

Update existing effect functions to use `applyEffectVolume` on their gain nodes.

- [ ] **Step 2: Add volume settings to global settings and useSettings**

`src/lib/settings.ts`:

```ts
export interface GlobalSettings {
  soundEnabled: boolean;
  musicEnabled: boolean;
  musicVolume: number;
  effectsVolume: number;
}

export const globalSettings: GlobalSettings = {
  soundEnabled: true,
  musicEnabled: true,
  musicVolume: 0.5,
  effectsVolume: 0.7,
};
```

`src/hooks/useSettings.ts`:

```ts
interface GameSettings {
  // existing fields
  musicVolume: number;
  effectsVolume: number;
}

const DEFAULT_SETTINGS: GameSettings = {
  // existing defaults
  musicVolume: 0.5,
  effectsVolume: 0.7,
};
```

Add setters:

```ts
const setMusicVolume = useCallback((vol: number) => {
  setSettings((prev) => ({ ...prev, musicVolume: vol }));
  globalSettings.musicVolume = vol;
  sounds.setMusicVolume(vol);
}, []);

const setEffectsVolume = useCallback((vol: number) => {
  setSettings((prev) => ({ ...prev, effectsVolume: vol }));
  globalSettings.effectsVolume = vol;
  sounds.setEffectsVolume(vol);
}, []);
```

- [ ] **Step 3: Add audio controls to SettingsPanel**

Add two range sliders (0–100) for music and effects volume, plus a mute-all toggle.

- [ ] **Step 4: Add placeholder music file**

Create `public/sounds/music/menu.mp3`. If no MP3 is available, leave a `.gitkeep` and update `App.tsx` to fall back to generated music when the file is missing.

- [ ] **Step 5: Play music on app start**

In `App.tsx`, after first user interaction, try `playMusicTrack('/sounds/music/menu.mp3')`; if the file fails, fall back to `startBackgroundMusic()`.

- [ ] **Step 6: Commit**

```bash
git add src/lib/sounds.ts src/lib/settings.ts src/hooks/useSettings.ts src/components/SettingsPanel.tsx public/sounds/
git commit -m "feat(audio): add volume control and file-based music support"
```

---

## Task 8: Pseudo-3D Table View

**Files:**
- Modify: `src/index.css` or `src/App.css`
- Modify: `src/components/GameBoard.tsx`
- Modify: `src/components/SettingsPanel.tsx`

- [ ] **Step 1: Add CSS classes**

```css
.table-3d {
  perspective: 1200px;
  transform-style: preserve-3d;
}

.table-surface {
  transform: rotateX(12deg);
  transform-origin: center bottom;
  transform-style: preserve-3d;
}

.card-3d {
  transform: translateZ(2px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.4);
  transition: transform 0.2s ease;
}
```

- [ ] **Step 2: Add view toggle to settings**

Add `table3d: boolean` to `useSettings`.

- [ ] **Step 3: Apply 3D classes conditionally in GameBoard**

```tsx
const is3d = settings.table3d;

<div className={is3d ? 'table-3d' : ''}>
  <div className={is3d ? 'table-surface' : ''}>
    {/* board content */}
  </div>
</div>
```

- [ ] **Step 4: Commit**

```bash
git add src/index.css src/components/GameBoard.tsx src/hooks/useSettings.ts src/components/SettingsPanel.tsx
git commit -m "feat(ui): add optional pseudo-3d table view"
```

---

## Task 9: i18n and Settings Integration

**Files:**
- Modify: `src/lib/i18n.tsx`
- Modify: `src/components/SettingsPanel.tsx`

- [ ] **Step 1: Add i18n keys**

German:

```ts
shop: {
  title: 'Skin-Shop',
  category: {
    cardBack: 'Kartenrückseiten',
    table: 'Tische',
    cardFace: 'Kartenvorderseiten',
  },
  free: 'Kostenlos',
  buy: 'Kaufen',
  activate: 'Aktivieren',
  active: 'Aktiv',
},
settings: {
  // existing
  musicVolume: 'Musik-Lautstärke',
  effectsVolume: 'Effekt-Lautstärke',
  table3d: '3D-Tischansicht',
},
```

English:

```ts
shop: {
  title: 'Skin Shop',
  category: {
    cardBack: 'Card Backs',
    table: 'Tables',
    cardFace: 'Card Faces',
  },
  free: 'Free',
  buy: 'Buy',
  activate: 'Activate',
  active: 'Active',
},
settings: {
  // existing
  musicVolume: 'Music Volume',
  effectsVolume: 'Effects Volume',
  table3d: '3D Table View',
},
```

- [ ] **Step 2: Integrate new settings controls**

Add toggles/sliders in `SettingsPanel` for music/effects volume and 3D view.

- [ ] **Step 3: Commit**

```bash
git add src/lib/i18n.tsx src/components/SettingsPanel.tsx
git commit -m "feat(i18n): add shop and audio settings translations"
```

---

## Task 10: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Run lint**

```bash
pnpm lint
```

Expected: no errors.

- [ ] **Step 2: Run tests**

```bash
pnpm test -- --run
```

Expected: all tests pass.

- [ ] **Step 3: Run build**

```bash
pnpm build
```

Expected: build succeeds.

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: professional polish with skins, audio and pseudo-3d"
```

---

## Self-Review Checklist

- [ ] Spec coverage: Skin-System, Shop, Audio, Pseudo-3D, i18n, Tests sind abgedeckt.
- [ ] Placeholder scan: Keine TBD/TODO/"implement later" im Plan.
- [ ] Type consistency: `Skin`, `SkinCategory`, `SkinInventory`, Settings-Typen sind konsistent.
