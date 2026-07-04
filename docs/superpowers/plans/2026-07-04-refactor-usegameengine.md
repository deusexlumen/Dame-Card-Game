# useGameEngine.ts Refactor Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox syntax. **Do not implement before the user explicitly says "go".**
>
> Note: the file to refactor is `src/hooks/useGameEngine.ts` (~1089 LOC). The user referred to it as `useGameWithAI.ts`; no such file exists in the repo, so this plan targets `useGameEngine.ts`.

**Goal:** Split `src/hooks/useGameEngine.ts` into focused, single-responsibility hooks (persistence, timer, AI orchestration, turn/action logic) while preserving exact behavior and all tests.

**Architecture:** Keep `useGameEngine` as the composer. State and refs live in `useGameEngine` and are passed into sub-hooks. Each sub-hook owns one concern and returns the state/callbacks `useGameEngine` needs for its public return object. Save/load validation moves to a plain module so the hook file contains only React code.

**Tech Stack:** React 19 hooks (useState, useCallback, useEffect, useRef), TypeScript, project gameLogic/aiPlayer/i18n modules.

---

## File Structure After Refactor

| File | Responsibility |
|------|----------------|
| `src/lib/saveGame.ts` | Pure functions: `saveGameState`, `loadGameState`, `hasSavedGameState`, and all validation predicates (`isValidCard`, `isValidPlayer`, `isValidGameState`, etc.). |
| `src/hooks/useGameTimer.ts` | Turn-timer state (`turnTimeLeft`, `isTimerPaused`), refs, and the countdown effect. |
| `src/hooks/useGameActions.ts` | All player action handlers: draw, swap, discard, Jack/King/Ace/Ten effects, call Dame, end turn, start next round, reset game. |
| `src/hooks/useAIOrchestrator.ts` | AI thinking state, timeout scheduling, and the effects that trigger AI moves. |
| `src/hooks/useGamePersistence.ts` | Auto-save effect and `loadSavedGame` callback that restores a saved game. |
| `src/hooks/useGameEngine.ts` | Composer: declares shared state/refs, calls sub-hooks, computes derived values, returns the public API. |

---

## Task 1: Move save/load validation to `src/lib/saveGame.ts`

**Files:**
- Create: `src/lib/saveGame.ts`
- Modify: `src/hooks/useGameEngine.ts`

Move lines 87–277 of `useGameEngine.ts` into a new module. Export everything that `useGameEngine` still needs:

```ts
export const SAVE_KEY = 'dame-game-save';
export function saveGameState(...): void;
export function loadGameState(): SaveData | null;
export function hasSavedGameState(): boolean;
```

Update `useGameEngine.ts` to import from `@/lib/saveGame`.

**Verification:** `pnpm test -- --run src/hooks/useGameEngine.test.ts` passes.

---

## Task 2: Extract `useGameTimer`

**Files:**
- Create: `src/hooks/useGameTimer.ts`
- Modify: `src/hooks/useGameEngine.ts`

Move timer-related state and effects (lines 301–302, 314–316, 357–377, 1001–1045) into `useGameTimer`.

Input parameters:

```ts
interface UseGameTimerOptions {
  gameState: GameState | null;
  gameConfig: GameConfig | undefined;
  isCurrentPlayerHuman: boolean;
  drawnCard: Card | null;
  onTimerExpired: () => void;
}
```

Return:

```ts
interface UseGameTimerReturn {
  turnTimeLeft: number | null;
  isTimerPaused: boolean;
  pauseTurnTimer: () => void;
  resumeTurnTimer: () => void;
  clearTimer: () => void;
  setTurnTimeLeft: React.Dispatch<React.SetStateAction<number | null>>;
  setIsTimerPaused: React.Dispatch<React.SetStateAction<boolean>>;
}
```

The hook declares its own `timerIntervalRef` and `timerTimeoutRef`, runs the countdown `useEffect`, and exposes the pause/resume/clear callbacks.

`useGameEngine` calls this hook and passes `actions.handleTimerExpired` (see Task 3).

**Verification:** `pnpm test -- --run src/hooks/useGameEngine.test.ts` passes.

---

## Task 3: Extract `useGameActions`

**Files:**
- Create: `src/hooks/useGameActions.ts`
- Modify: `src/hooks/useGameEngine.ts`

Move all player-action callbacks (lines 389–417, 419–450, 452–648, 660–735, 737–769, 771–786, 788–797, 799–812) into `useGameActions`.

Input parameters:

```ts
interface UseGameActionsOptions {
  gameStateRef: React.MutableRefObject<GameState | null>;
  drawnCardRef: React.MutableRefObject<Card | null>;
  aiPlayersRef: React.MutableRefObject<Map<string, AIDifficulty>>;
  gameConfigRef: React.MutableRefObject<GameConfig | undefined>;
  playerConfigsRef: React.MutableRefObject<PlayerConfig[]>;
  setGameState: React.Dispatch<React.SetStateAction<GameState | null>>;
  setDrawnCard: React.Dispatch<React.SetStateAction<Card | null>>;
  setSelectedHandIndex: React.Dispatch<React.SetStateAction<number | null>>;
  setMessage: (key: string, vars?: Record<string, string | number>) => void;
  setTurnOverlayOpen: React.Dispatch<React.SetStateAction<boolean>>;
  setAiPlayers: React.Dispatch<React.SetStateAction<Map<string, AIDifficulty>>>;
  setHasSavedGame: React.Dispatch<React.SetStateAction<boolean>>;
  statsActions?: StatsActions;
  clearTimer: () => void;
  clearAITimeouts: () => void;
}
```

Return all action callbacks:

```ts
interface UseGameActionsReturn {
  startGame: (configs: PlayerConfig[]) => void;
  loadSavedGame: () => boolean;
  handleDrawFromDeck: () => void;
  handleDrawFromDiscard: () => void;
  selectHandCard: (index: number) => void;
  confirmSwap: (forcedHandIndex?: number) => void;
  discardDrawnCard: () => void;
  handleUseJack: (targetPlayerId: string, handIndex: number) => void;
  handleUseKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
  handleUseAce: (deckIndex: number, handIndex: number) => void;
  handleUseTen: () => void;
  peekKingTarget: (targetPlayerId: string, targetHandIndex: number) => Card | null;
  handleCallDame: () => void;
  handleTryDiscardExtra: (cardId: string) => boolean;
  handleEndTurn: () => void;
  handleStartNextRound: () => void;
  resetGame: () => void;
  handleTimerExpired: () => void;
}
```

The body of each callback is copied verbatim; only the surrounding hook signature changes. `useGameEngine` will call this hook and use the returned callbacks for AI orchestration, the public API, and persistence restoration.

**Verification:** `pnpm test -- --run src/hooks/useGameEngine.test.ts` passes.

---

## Task 4: Extract `useAIOrchestrator`

**Files:**
- Create: `src/hooks/useAIOrchestrator.ts`
- Modify: `src/hooks/useGameEngine.ts`

Move AI-related state, refs, and effects (lines 298–299, 311–312, 346–355, 814–964) into `useAIOrchestrator`.

Input parameters:

```ts
interface UseAIOrchestratorOptions {
  gameState: GameState | null;
  drawnCard: Card | null;
  aiPlayers: Map<string, AIDifficulty>;
  aiSpeed: AISpeed;
  gameConfig: GameConfig | undefined;
  gameStateRef: React.MutableRefObject<GameState | null>;
  drawnCardRef: React.MutableRefObject<Card | null>;
  aiPlayersRef: React.MutableRefObject<Map<string, AIDifficulty>>;
  gameConfigRef: React.MutableRefObject<GameConfig | undefined>;
  speedMultRef: React.MutableRefObject<number>;
  actions: UseGameActionsReturn;
  setMessage: (key: string, vars?: Record<string, string | number>) => void;
  setTurnOverlayOpen: React.Dispatch<React.SetStateAction<boolean>>;
}
```

Return:

```ts
interface UseAIOrchestratorReturn {
  isAIThinking: boolean;
  clearAITimeouts: () => void;
}
```

The hook contains `scheduleAITimeout`, `executeAIMove`, `endTurnAfterAI`, and the three effects that watch `gameState`/`drawnCard` and trigger AI moves. The timeout refs (`aiTimeoutsRef`, `isAIMovingRef`) stay inside this hook; `useGameEngine` no longer needs to clear them directly except by using the returned `clearAITimeouts`.

**Verification:** `pnpm test -- --run src/hooks/useGameEngine.test.ts` passes.

---

## Task 5: Extract `useGamePersistence`

**Files:**
- Create: `src/hooks/useGamePersistence.ts`
- Modify: `src/hooks/useGameEngine.ts`

Move the auto-save effect (lines 383–386) and the `loadSavedGame` restoration logic into `useGamePersistence`.

Input parameters:

```ts
interface UseGamePersistenceOptions {
  gameState: GameState | null;
  drawnCard: Card | null;
  aiPlayers: Map<string, AIDifficulty>;
  gameMessage: string;
  messageKey: string;
  turnOverlayOpen: boolean;
  gameConfig: GameConfig | undefined;
  setHasSavedGame: React.Dispatch<React.SetStateAction<boolean>>;
  loadSavedGame: () => boolean; // from useGameActions
}
```

This hook has no return value; it only runs the auto-save `useEffect`. The `loadSavedGame` callback remains defined in `useGameActions` because it mutates game state, but this hook is the place for the effect that writes to `localStorage`.

**Verification:** `pnpm test -- --run src/hooks/useGameEngine.test.ts` passes.

---

## Task 6: Recompose `useGameEngine.ts`

**Files:**
- Modify: `src/hooks/useGameEngine.ts`

After the above extractions, `useGameEngine.ts` should contain only:

1. Imports.
2. The `PlayerConfig`, `StatsActions`, `UseGameEngineReturn` interfaces.
3. `SPEED_MULTIPLIERS` and the `useGameEngine` function.
4. State declarations.
5. `setMessage` helper.
6. Calls to `useGameActions`, `useGameTimer`, `useAIOrchestrator`, and `useGamePersistence`.
7. Derived values (`winner`, `canCallDameNow`, `currentAIDifficulty`, `isCurrentPlayerHuman`).
8. The public return object.

Expected final length: ~150–200 LOC.

Run full verification:

```bash
pnpm test -- --run
pnpm build
```

Both must pass before committing.

---

## Self-Review Checklist

1. **Spec coverage:** Persistence, timer, AI, and turn/action logic each have a dedicated extraction task. ✅
2. **Placeholder scan:** No TBD/TODO. ✅
3. **Type consistency:** Interfaces reuse existing types (`GameState`, `Card`, `PlayerConfig`, `AIDifficulty`, `GameConfig`, `StatsActions`). ✅
4. **Behavior change:** None — all callbacks are moved verbatim; state/refs stay synchronized by passing them from the composer hook. ✅
