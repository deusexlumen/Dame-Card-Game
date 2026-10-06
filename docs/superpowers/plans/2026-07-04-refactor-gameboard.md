# GameBoard.tsx Refactor Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox syntax. **Do not implement before the user explicitly says "go".**

**Goal:** Split `src/components/GameBoard.tsx` (~1280 LOC) into focused sub-components and a local state/effects hook while keeping behavior identical and all tests green.

**Architecture:** Keep `GameBoard` as the top-level layout orchestrator. Move every dialog, phase screen, and the main table into its own component. Extract a `useGameBoard` hook that owns UI state (dialogs, peek/effect selection), keyboard shortcuts, and sound/message side effects. Pass primitive props and callbacks down; no new hooks in sub-components unless they are extracted from `useGameEngine`.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, shadcn/ui Dialog/Sheet/Tabs, framer-motion, project i18n/sounds/skins hooks.

---

## File Structure After Refactor

| File | Responsibility |
|------|----------------|
| `src/components/GameBoard.tsx` | Top-level layout: wire `useGameEngine`, `useGameBoard`, render chosen screen/dialogs. |
| `src/components/game-board/useGameBoard.ts` | UI state, keyboard shortcuts, sound effects, message-driven toasts, computed helpers (`bottomPlayerIndex`, `mustTakeQueen`, `isBottomPlayerEliminated`). |
| `src/components/game-board/StartDialog.tsx` | Initial start screen with rules, stats, continue/new-game/tutorial buttons. |
| `src/components/game-board/PeekPhase.tsx` | Card-memorization phase for singleplayer/hotseat. |
| `src/components/game-board/EliminatedView.tsx` | "You are eliminated" spectator screen. |
| `src/components/game-board/GameHeader.tsx` | Title, round/safe-phase badges, AI-thinking indicator, timer, toolbar buttons. |
| `src/components/game-board/OpponentsRow.tsx` | Row of opponent hands with difficulty icons. |
| `src/components/game-board/TableCenter.tsx` | Draw pile, discard pile, current-player info panel. |
| `src/components/game-board/DrawnCardDisplay.tsx` | Animated drawn card panel. |
| `src/components/game-board/ActionBar.tsx` | Jack/King/Ace/Ten/discard/call-Dame/end-turn buttons. |
| `src/components/game-board/PlayerHandArea.tsx` | Bottom player's hand with swap/extra-discard handlers. |
| `src/components/game-board/SwapConfirmation.tsx` | Floating confirm-swap button. |
| `src/components/game-board/JackEffectDialog.tsx` | Bube effect: peek at any hand and activate Jack. |
| `src/components/game-board/AceEffectDialog.tsx` | Ass effect: choose deck card and hand card to swap. |
| `src/components/game-board/KingEffectDialog.tsx` | König effect: choose own card, opponent, and opponent card to swap. |
| `src/components/game-board/WinnerDialog.tsx` | Game-over winner modal. |
| `src/components/game-board/RoundEndDialog.tsx` | Round-end score overview + next-round button. |
| `src/components/game-board/TutorialDialog.tsx` | Rules tutorial modal. |
| `src/components/game-board/SkinSelectorDialog.tsx` | In-game skin selector. |

---

## Task 1: Extract `useGameBoard` hook

**Files:**
- Create: `src/components/game-board/useGameBoard.ts`
- Modify: `src/components/GameBoard.tsx`

Move into the new hook:

- All `useState` calls from lines 145–159:
  - `showStartDialog`, `peekPhase`, `peekedPlayerIds`, `peekPlayerIndex`
  - `showJackEffect`, `showKingEffect`, `showAceEffect`
  - `showSettings`, `showTutorial`, `showSkinSelector`, `selectedSkinCategory`
  - `kingTargetPlayer`, `kingTargetCardIndex`, `kingPeekedCard`, `aceSelectedDeckIndex`
- `bottomPlayerIndex` computation (lines 120–126).
- `effectiveGameConfig` and `statsActions` memoization (lines 70–82).
- `handleStart`, `handleReady`, `handleReset` (lines 279–309).
- Keyboard-shortcut `useEffect` (lines 165–234).
- Winner sound `useEffect` (lines 237–241).
- Penalty-card toast `useEffect` (lines 244–252).
- Extra-discard/Jack/King toast `useEffect` (lines 255–276).
- `isBottomPlayerEliminated` + `mustTakeQueen` computations.

Return an object with state, setters, helpers, and handlers so `GameBoard.tsx` can render conditionally.

Example return shape:

```ts
export function useGameBoard(
  playerConfigs: PlayerConfig[],
  gameState: GameState | null,
  gameConfig: GameConfig,
  settings: Settings,
  engineActions: {
    startGame: (configs: PlayerConfig[]) => void;
    resetGame: () => void;
    confirmTurn: () => void;
    drawFromDeck: () => void;
    drawFromDiscard: () => void;
    selectHandCard: (index: number) => void;
    confirmSwap: () => void;
    discardDrawnCard: () => void;
    endTurn: () => void;
    callDame: () => void;
    activateJack: (targetPlayerId: string, handIndex: number) => void;
    activateKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
    activateAce: (deckIndex: number, handIndex: number) => void;
    activateTen: () => void;
    tryDiscardExtra: (cardId: string) => boolean;
    peekKingTarget: (targetPlayerId: string, targetHandIndex: number) => Card | null;
    startNextRound: () => void;
    loadSavedGame: () => boolean;
    pauseTurnTimer: () => void;
    resumeTurnTimer: () => void;
  },
  engineState: {
    drawnCard: Card | null;
    selectedHandIndex: number | null;
    isCurrentPlayerHuman: boolean;
    isAIThinking: boolean;
    canCallDameNow: boolean;
    turnTimeLeft: number | null;
    hasSavedGame: boolean;
    currentAIDifficulty: AIDifficulty | null;
  }
) {
  // ... implementation moved from GameBoard.tsx
}
```

**Verification:** `pnpm test -- --run src/components/GameBoard.test.tsx` passes.

---

## Task 2: Extract phase/screen components

**Files:**
- Create: `src/components/game-board/StartDialog.tsx`
- Create: `src/components/game-board/PeekPhase.tsx`
- Create: `src/components/game-board/EliminatedView.tsx`
- Modify: `src/components/GameBoard.tsx`

Lift the JSX blocks returned from the three early-return branches (lines 315–383, 386–417, 433–447) into components.

`StartDialog` props:

```ts
interface StartDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  playerConfigs: PlayerConfig[];
  hasSavedGame: boolean;
  stats: GameStats;
  onResetStats: () => void;
  onContinueGame: () => void;
  onStartGame: () => void;
  onShowTutorial: () => void;
}
```

`PeekPhase` props:

```ts
interface PeekPhaseProps {
  player: Player;
  peekPhase: boolean;
  onReady: () => void;
  card3dClass: string;
}
```

`EliminatedView` props:

```ts
interface EliminatedViewProps {
  onReset: () => void;
}
```

Replace the early-return bodies in `GameBoard.tsx` with component calls.

**Verification:** `pnpm test -- --run src/components/GameBoard.test.tsx` passes.

---

## Task 3: Extract main table components

**Files:**
- Create: `src/components/game-board/GameHeader.tsx`
- Create: `src/components/game-board/OpponentsRow.tsx`
- Create: `src/components/game-board/TableCenter.tsx`
- Create: `src/components/game-board/DrawnCardDisplay.tsx`
- Create: `src/components/game-board/ActionBar.tsx`
- Create: `src/components/game-board/PlayerHandArea.tsx`
- Create: `src/components/game-board/SwapConfirmation.tsx`
- Modify: `src/components/GameBoard.tsx`

Cut the corresponding JSX regions from the main return (lines 474–771) into the new components. Keep prop drilling shallow:

- `GameHeader`: `gameState`, `currentPlayer`, `turnTimeLeft`, `isAIThinking`, `isCurrentPlayerHuman`, `effectiveGameConfig`, action callbacks.
- `OpponentsRow`: `players`, `bottomPlayerIndex`, `currentPlayerIndex`, `playerConfigs`, `memory`, `card3dClass`.
- `TableCenter`: `deck`, `discardPile`, `currentPlayer`, `currentAIDifficulty`, `gameMessage`, `onDrawFromDeck`, `onDrawFromDiscard`, `card3dClass`.
- `DrawnCardDisplay`: `drawnCard`, `card3dClass`.
- `ActionBar`: `drawnCard`, `isHumanTurn`, `isAIThinking`, `canCallDameNow`, `effectiveGameConfig`, rank-based effect callbacks, discard/endTurn/callDame callbacks.
- `PlayerHandArea`: bottom player, `drawnCard`, `isHumanTurn`, `isAIThinking`, `selectedHandIndex`, `topDiscardCard`, `onSelectForSwap`, `onSelectForExtraDiscard`, `card3dClass`.
- `SwapConfirmation`: `drawnCard`, `selectedHandIndex`, `isHumanTurn`, `onConfirmSwap`.

`GameBoard.tsx` main return becomes a thin layout:

```tsx
return (
  <div ...table background...>
    {turnOverlayOpen && <PlayerTurnOverlay ... />}
    <GameHeader ... />
    <div className="max-w-6xl mx-auto">
      <OpponentsRow ... />
      <TableCenter ... />
      <DrawnCardDisplay ... />
      <ActionBar ... />
      <PlayerHandArea ... />
      <SwapConfirmation ... />
    </div>
    {/* dialogs */}
  </div>
);
```

**Verification:** `pnpm test -- --run src/components/GameBoard.test.tsx` passes.

---

## Task 4: Extract dialog components

**Files:**
- Create: `src/components/game-board/JackEffectDialog.tsx`
- Create: `src/components/game-board/AceEffectDialog.tsx`
- Create: `src/components/game-board/KingEffectDialog.tsx`
- Create: `src/components/game-board/WinnerDialog.tsx`
- Create: `src/components/game-board/RoundEndDialog.tsx`
- Create: `src/components/game-board/TutorialDialog.tsx`
- Create: `src/components/game-board/SkinSelectorDialog.tsx`
- Modify: `src/components/GameBoard.tsx`

Move each dialog block (lines 774–1237) into its own component. Example interfaces:

`JackEffectDialog`:

```ts
interface JackEffectDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  gameState: GameState;
  bottomPlayerIndex: number;
  onActivateJack: (targetPlayerId: string, handIndex: number) => void;
  onPauseTimer: () => void;
  onResumeTimer: () => void;
  card3dClass: string;
}
```

`AceEffectDialog`:

```ts
interface AceEffectDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  gameState: GameState;
  bottomPlayerIndex: number;
  selectedHandIndex: number | null;
  onSelectHandCard: (index: number) => void;
  onActivateAce: (deckIndex: number, handIndex: number) => void;
  onPauseTimer: () => void;
  onResumeTimer: () => void;
  card3dClass: string;
}
```

`KingEffectDialog`:

```ts
interface KingEffectDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  gameState: GameState;
  bottomPlayerIndex: number;
  selectedHandIndex: number | null;
  onSelectHandCard: (index: number) => void;
  onPeekKingTarget: (targetPlayerId: string, targetHandIndex: number) => Card | null;
  onActivateKing: (targetPlayerId: string, myHandIndex: number, targetHandIndex: number) => void;
  onPauseTimer: () => void;
  onResumeTimer: () => void;
  card3dClass: string;
}
```

The remaining dialogs (`WinnerDialog`, `RoundEndDialog`, `TutorialDialog`, `SkinSelectorDialog`) are mostly presentational and receive the minimal props they need.

**Verification:** `pnpm test -- --run src/components/GameBoard.test.tsx` passes.

---

## Task 5: Re-export barrel and final cleanup

**Files:**
- Create: `src/components/game-board/index.ts`
- Modify: `src/components/GameBoard.tsx`

Create an index file that re-exports `GameBoard` and, if needed, `useGameBoard`. Clean up any remaining inline constants/helpers that belong in a shared location (e.g., `DIFFICULTY_ICONS`/`DIFFICULTY_COLORS` can move into `src/lib/aiPlayer.ts` or a new `src/lib/difficulty.ts` if not already there).

Run full suite:

```bash
pnpm test -- --run
pnpm build
```

Both must pass before committing.

---

## Self-Review Checklist

1. **Spec coverage:** Every major UI block in `GameBoard.tsx` is assigned to a component or the hook. ✅
2. **Placeholder scan:** No TBD/TODO. ✅
3. **Type consistency:** Hook return shape and component props use existing types (`PlayerConfig`, `GameState`, `Card`, `AIDifficulty`, `GameConfig`, `GameStats`). ✅
4. **Behavior change:** None — only code movement and prop drilling. ✅
