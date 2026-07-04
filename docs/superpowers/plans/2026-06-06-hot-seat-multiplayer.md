# Hot-Seat Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Füge einen Hot-Seat-Multiplayer-Modus für 2–4 Spieler mit beliebiger Mensch/KI-Mischung und Weitergeben-Overlay hinzu.

**Architecture:** Der bestehende `useGameWithAI`-Hook wird zu `useGameEngine` verallgemeinert und verwaltet sowohl menschliche als auch KI-Spieler. Eine neue `HotSeatSetup`-Komponente konfiguriert die Spieler. `GameBoard` zeigt nach menschlichen Zügen ein `PlayerTurnOverlay`, das den nächsten Spieler auf seine Runde vorbereitet. KI-Spieler spielen automatisch weiter.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS 3.4, shadcn/ui, Vitest.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `src/types/game.ts` | Erweiterung `Player` um `isHuman`. |
| `src/hooks/useGameWithAI.ts` | Umbenennen/erweitern zu `useGameEngine`. |
| `src/hooks/useGameWithAI.test.ts` | Bestehende Tests anpassen. |
| `src/components/HotSeatSetup.tsx` | Konfigurations-UI für Hot-Seat-Spieler. |
| `src/components/PlayerTurnOverlay.tsx` | Weitergeben-Overlay. |
| `src/components/GameBoard.tsx` | Hot-Seat-Logik integrieren. |
| `src/components/GameBoard.test.tsx` | Neue Tests für Overlay-Verhalten. |
| `src/App.tsx` | Hot-Seat-Modus im Menü und Routing. |
| `src/lib/aiPlayer.ts` | Akzeptiert `isHuman`-Flag, keine Änderung am Verhalten. |
| `src/lib/i18n.tsx` | Neue Übersetzungen. |

---

## Task 1: Extend Player Type

**Files:**
- Modify: `src/types/game.ts`

- [ ] **Step 1: Write the failing test**

In `src/types/game.test.ts` (create if not exists):

```ts
import type { Player } from './game';

describe('Player type', () => {
  it('accepts isHuman flag', () => {
    const player: Player = {
      id: '1',
      name: 'Test',
      isAI: false,
      isHuman: true,
      hand: [],
      penaltyCards: [],
      score: 0,
      isEliminated: false,
      visibleCardIndices: [],
    };
    expect(player.isHuman).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/types/game.test.ts
```

Expected: FAIL – `isHuman` not in type.

- [ ] **Step 3: Add `isHuman` to Player interface**

```ts
export interface Player {
  id: string;
  name: string;
  isAI: boolean;
  isHuman: boolean;
  hand: Card[];
  penaltyCards: Card[];
  score: number;
  isEliminated: boolean;
  visibleCardIndices: number[];
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/types/game.test.ts
```

Expected: PASS.

- [ ] **Step 5: Fix TypeScript compile errors in existing factories/tests**

Because `Player` gained a new required field, update the minimum necessary existing object literals/factories so `pnpm test -- --run` and `pnpm build` keep passing (e.g. `createPlayer` in `src/lib/gameLogic.ts`, mock players in `src/lib/aiPlayer.test.ts`).

- [ ] **Step 6: Commit**

```bash
git add src/types/game.ts src/types/game.test.ts src/lib/gameLogic.ts src/lib/aiPlayer.test.ts
git commit -m "feat(types): add isHuman flag to Player"
```

---

## Task 2: Update Game Initialization and AI Hook

**Files:**
- Modify: `src/lib/gameLogic.ts`
- Modify: `src/hooks/useGameWithAI.ts`
- Modify: `src/hooks/useGameWithAI.test.ts`

- [ ] **Step 1: Update `initializeGame` to accept player configs**

In `src/lib/gameLogic.ts`:

```ts
export function initializeGame(
  playerConfigs: PlayerConfig[],
  deck?: Card[]
): GameState {
  const players = playerConfigs.map((config, index) => ({
    id: `player-${index}`,
    name: config.name,
    isAI: config.isAI,
    isHuman: config.isHuman,
    hand: [],
    penaltyCards: [],
    score: 0,
    isEliminated: false,
    visibleCardIndices: [],
  }));
  // ... rest of initialization
}
```

`initializeGame` may accept an optional `deck` parameter for deterministic tests and may persist `isAI` on `Player` if needed by downstream code.

- [ ] **Step 2: Update `useGameWithAI` signature**

Rename file and hook to `useGameEngine`:

```ts
export interface PlayerConfig {
  name: string;
  isAI: boolean;
  isHuman: boolean;
  difficulty?: AIDifficulty;
}

export function useGameEngine(
  playerConfigs: PlayerConfig[],
  aiSpeed: AISpeed = 'normal',
  statsActions?: StatsActions,
  gameConfig?: GameConfig
): UseGameEngineReturn {
  // existing logic, but initializeGame uses playerConfigs
}
```

- [ ] **Step 3: Update existing tests**

Change `useGameWithAI` imports and calls to `useGameEngine`. Pass player configs with `isHuman: true` for the human player and `isHuman: false` for AI.

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/gameLogic.ts src/hooks/useGameEngine.ts src/hooks/useGameEngine.test.ts
git commit -m "feat(engine): generalize hook to useGameEngine with player configs"
```

---

## Task 3: Add Hot-Seat Setup Component

**Files:**
- Create: `src/components/HotSeatSetup.tsx`
- Create: `src/components/HotSeatSetup.test.tsx`

- [ ] **Step 1: Write the failing test**

```ts
import { render, screen, fireEvent } from '@testing-library/react';
import { HotSeatSetup } from './HotSeatSetup';

describe('HotSeatSetup', () => {
  it('calls onStart with configured players', () => {
    const onStart = vi.fn();
    render(<HotSeatSetup onStart={onStart} onCancel={() => {}} />);

    fireEvent.click(screen.getByText('Spiel starten'));

    expect(onStart).toHaveBeenCalledWith([
      expect.objectContaining({ name: 'Spieler 1', isAI: false, isHuman: true }),
      expect.objectContaining({ name: 'Spieler 2', isAI: false, isHuman: true }),
    ]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/components/HotSeatSetup.test.tsx
```

Expected: FAIL.

- [ ] **Step 3: Implement HotSeatSetup component**

```tsx
import { useState } from 'react';
import { useI18n } from '@/lib/i18n';
import type { PlayerConfig } from '@/hooks/useGameEngine';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface HotSeatSetupProps {
  onStart: (players: PlayerConfig[]) => void;
  onCancel: () => void;
}

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;

export function HotSeatSetup({ onStart, onCancel }: HotSeatSetupProps) {
  const { t } = useI18n();
  const [count, setCount] = useState(MIN_PLAYERS);
  const [players, setPlayers] = useState<PlayerConfig[]>([
    { name: 'Spieler 1', isAI: false, isHuman: true },
    { name: 'Spieler 2', isAI: false, isHuman: true },
  ]);

  const updatePlayer = (index: number, updates: Partial<PlayerConfig>) => {
    setPlayers((prev) =>
      prev.map((p, i) => (i === index ? { ...p, ...updates } : p))
    );
  };

  const changeCount = (newCount: number) => {
    setCount(newCount);
    setPlayers((prev) => {
      if (newCount > prev.length) {
        return [
          ...prev,
          ...Array.from({ length: newCount - prev.length }, (_, i) => ({
            name: `Spieler ${prev.length + i + 1}`,
            isAI: false,
            isHuman: true,
          })),
        ];
      }
      return prev.slice(0, newCount);
    });
  };

  const hasHuman = players.some((p) => p.isHuman);
  const isValid = hasHuman && players.every((p) => p.name.trim() !== '');

  return (
    <Card className="max-w-lg mx-auto">
      <CardHeader>
        <CardTitle>{t('hotSeat.setupTitle')}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex gap-2">
          {[2, 3, 4].map((n) => (
            <Button
              key={n}
              variant={count === n ? 'default' : 'outline'}
              onClick={() => changeCount(n)}
            >
              {n} {t('hotSeat.players')}
            </Button>
          ))}
        </div>

        {players.map((player, index) => (
          <div key={index} className="flex gap-2 items-center">
            <Input
              value={player.name}
              onChange={(e) => updatePlayer(index, { name: e.target.value })}
              placeholder={t('hotSeat.playerName')}
            />
            <select
              value={player.isAI ? 'ai' : 'human'}
              onChange={(e) =>
                updatePlayer(index, {
                  isAI: e.target.value === 'ai',
                  isHuman: e.target.value === 'human',
                })
              }
            >
              <option value="human">{t('hotSeat.human')}</option>
              <option value="ai">{t('hotSeat.ai')}</option>
            </select>
            {player.isAI && (
              <select
                value={player.difficulty || 'medium'}
                onChange={(e) =>
                  updatePlayer(index, { difficulty: e.target.value as AIDifficulty })
                }
              >
                <option value="easy">{t('menu.difficulty.easy')}</option>
                <option value="medium">{t('menu.difficulty.medium')}</option>
                <option value="hard">{t('menu.difficulty.hard')}</option>
              </select>
            )}
          </div>
        ))}

        <div className="flex gap-2 justify-end">
          <Button variant="ghost" onClick={onCancel}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => onStart(players)} disabled={!isValid}>
            {t('hotSeat.start')}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/components/HotSeatSetup.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/HotSeatSetup.tsx src/components/HotSeatSetup.test.tsx
git commit -m "feat(ui): add hot-seat setup component"
```

---

## Task 4: Add Player Turn Overlay

**Files:**
- Create: `src/components/PlayerTurnOverlay.tsx`
- Create: `src/components/PlayerTurnOverlay.test.tsx`

- [ ] **Step 1: Write the failing test**

```ts
import { render, screen, fireEvent } from '@testing-library/react';
import { PlayerTurnOverlay } from './PlayerTurnOverlay';

describe('PlayerTurnOverlay', () => {
  it('shows player name and calls onReady', () => {
    const onReady = vi.fn();
    render(<PlayerTurnOverlay playerName="Anna" onReady={onReady} />);

    expect(screen.getByText(/Anna/)).toBeInTheDocument();
    fireEvent.click(screen.getByText('Ich bin bereit'));
    expect(onReady).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/components/PlayerTurnOverlay.test.tsx
```

Expected: FAIL.

- [ ] **Step 3: Implement PlayerTurnOverlay component**

```tsx
import { useI18n } from '@/lib/i18n';
import { Button } from '@/components/ui/button';

interface PlayerTurnOverlayProps {
  playerName: string;
  onReady: () => void;
}

export function PlayerTurnOverlay({ playerName, onReady }: PlayerTurnOverlayProps) {
  const { t } = useI18n();

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80">
      <div className="text-center space-y-6 p-8 rounded-xl bg-slate-900 border border-slate-700">
        <h2 className="text-2xl font-bold text-white">
          {t('hotSeat.playerTurn', { name: playerName })}
        </h2>
        <p className="text-slate-400">{t('hotSeat.lookAway')}</p>
        <Button size="lg" onClick={onReady}>
          {t('hotSeat.ready')}
        </Button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/components/PlayerTurnOverlay.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/PlayerTurnOverlay.tsx src/components/PlayerTurnOverlay.test.tsx
git commit -m "feat(ui): add player turn overlay"
```

---

## Task 5: Integrate Hot-Seat into GameBoard

**Files:**
- Modify: `src/components/GameBoard.tsx`
- Modify: `src/components/GameBoard.test.tsx` (if exists)

- [ ] **Step 1: Update GameBoard props**

```ts
interface GameBoardProps {
  playerConfigs: PlayerConfig[];
  onBackToMenu: () => void;
  gameConfig?: GameConfig;
}
```

- [ ] **Step 2: Pass playerConfigs to useGameEngine**

```ts
const { gameState, drawnCard, ..., turnOverlayOpen, confirmTurn } = useGameEngine(
  playerConfigs,
  settings.aiSpeed,
  statsActions,
  gameConfig
);
```

- [ ] **Step 3: Add turn overlay state in useGameEngine**

Add state:

```ts
const [turnOverlayOpen, setTurnOverlayOpen] = useState(false);
```

Add `confirmTurn` callback:

```ts
const confirmTurn = useCallback(() => {
  setTurnOverlayOpen(false);
}, []);
```

After `endTurn`/`handleEndTurn`, when the turn advances to the next player, check:

```ts
const nextPlayer = newState.players[newState.currentPlayerIndex];
if (nextPlayer.isHuman && !nextPlayer.isAI && !nextPlayer.isEliminated) {
  setTurnOverlayOpen(true);
}
```

Add `turnOverlayOpen` and `confirmTurn` to the returned object.

- [ ] **Step 4: Render overlay in GameBoard**

```tsx
{turnOverlayOpen && gameState && (
  <PlayerTurnOverlay
    playerName={gameState.players[gameState.currentPlayerIndex].name}
    onReady={confirmTurn}
  />
)}
```

- [ ] **Step 5: Hide opponent cards from active human player**

In `GameBoard`, when rendering opponent cards, ensure `faceUp={false}`. Only the active player's own cards are `faceUp={true}`.

- [ ] **Step 6: Run tests**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 7: Commit**

```bash
git add src/components/GameBoard.tsx src/hooks/useGameEngine.ts
git commit -m "feat(game): integrate hot-seat overlay and turn flow"
```

---

## Task 6: Add Hot-Seat to App Menu and Routing

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Add Hot-Seat button to main menu**

```tsx
<Button onClick={() => setGameMode('hotseat-setup')}>
  {t('menu.hotSeat')}
</Button>
```

- [ ] **Step 2: Add hotseat-setup and hotseat game modes**

```ts
type GameMode = 'menu' | 'game' | 'rules' | 'settings' | 'shop' | 'hotseat-setup' | 'hotseat';
```

- [ ] **Step 3: Render HotSeatSetup**

```tsx
if (gameMode === 'hotseat-setup') {
  return (
    <div className="min-h-screen ...">
      <HotSeatSetup
        onStart={(players) => {
          setPlayers(players);
          setGameMode('hotseat');
        }}
        onCancel={() => setGameMode('menu')}
      />
    </div>
  );
}
```

- [ ] **Step 4: Render GameBoard in hotseat mode**

```tsx
if (gameMode === 'hotseat') {
  return (
    <GameBoard
      playerConfigs={players}
      onBackToMenu={backToMenu}
      gameConfig={gameConfig}
    />
  );
}
```

- [ ] **Step 5: Run tests and lint**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 6: Commit**

```bash
git add src/App.tsx
git commit -m "feat(app): add hot-seat menu and routing"
```

---

## Task 7: i18n Translations

**Files:**
- Modify: `src/lib/i18n.tsx`

- [ ] **Step 1: Add German keys**

```ts
common: {
  cancel: 'Abbrechen',
},
hotSeat: {
  setupTitle: 'Hot-Seat Spiel',
  players: 'Spieler',
  playerName: 'Spielername',
  human: 'Mensch',
  ai: 'KI',
  start: 'Spiel starten',
  playerTurn: '{{name}} ist dran',
  lookAway: 'Andere Spieler bitte nicht hinschauen.',
  ready: 'Ich bin bereit',
},
menu: {
  // existing
  hotSeat: 'Hot-Seat',
},
```

- [ ] **Step 2: Add English keys**

```ts
common: {
  cancel: 'Cancel',
},
hotSeat: {
  setupTitle: 'Hot-Seat Game',
  players: 'Players',
  playerName: 'Player name',
  human: 'Human',
  ai: 'AI',
  start: 'Start game',
  playerTurn: "It's {{name}}'s turn",
  lookAway: 'Other players, please do not look.',
  ready: 'I am ready',
},
menu: {
  // existing
  hotSeat: 'Hot-Seat',
},
```

- [ ] **Step 3: Run tests and lint**

```bash
pnpm test -- --run && pnpm lint
```

- [ ] **Step 4: Commit**

```bash
git add src/lib/i18n.tsx
git commit -m "feat(i18n): add hot-seat translations"
```

---

## Task 8: Final Verification

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
git commit -m "feat: add hot-seat multiplayer mode"
```

---

## Self-Review Checklist

- [ ] Spec coverage: Hot-Seat Setup, Overlay, GameEngine, GameBoard, i18n, Tests sind abgedeckt.
- [ ] Placeholder scan: Keine TBD/TODO/"implement later" im Plan.
- [ ] Type consistency: `PlayerConfig`, `Player`, `UseGameEngineReturn` sind konsistent.
