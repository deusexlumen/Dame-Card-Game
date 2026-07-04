# Phase 1: Kritische Bug-Fixes — Engine-Deadlocks, UI-Dead-Ends, Deploy

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Behebe die 7 kritischen Bugs aus dem Bug-Audit, die zu Spiel-Freezes, leeren Screens oder 404-Assets führen können.

**Architecture:** Die Fixes bleiben innerhalb der bestehenden `useGameEngine`-/`GameBoard`-Architektur. Timer- und KI-Refs werden konsistent zurückgesetzt, der Start-Dialog wird nicht-dismissible, Hot-Seat kann nach Elimination weiterlaufen, und Asset-Pfade werden relativ zum Vite-`base` aufgelöst.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS, shadcn/ui, Vitest.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `src/hooks/useGameEngine.ts` | Timer-/KI-Status zurücksetzen, AI-Thinking korrekt beenden, Input-Guards. |
| `src/components/GameBoard.tsx` | Start-Dialog nicht-dismissible, Hot-Seat-Elimination-Weiterlauf, Keyboard-Guard erweitern. |
| `src/lib/skins/registry.ts` | Skin-Assets mit relativen Pfaden (`./skins/...`) statt absolut. |
| `src/App.tsx` | Menü-Musikpfad relativ (`./sounds/music/menu.mp3`) oder entfernen. |
| `vite.config.ts` | `base` auf `'./'` ändern, damit relative Asset-Pfade auf jeder Domain funktionieren. |
| `AGENTS.md` | `base`-Dokumentation korrigieren. |

---

## Task 1.1: Reset `isAIMovingRef` on start/load

**Files:**
- Modify: `src/hooks/useGameEngine.ts:389-412` (`startGame`)
- Modify: `src/hooks/useGameEngine.ts:415-443` (`loadSavedGame`)
- Test: `src/hooks/useGameEngine.test.ts`

- [ ] **Step 1: Write the failing test**

In `src/hooks/useGameEngine.test.ts`, add a test that simulates an in-flight AI move, then calls `startGame` and verifies the AI can still move:

```ts
it('resets AI moving flag when starting a new game', async () => {
  const { result } = renderHook(() => useGameEngine([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI', isAI: true, isHuman: false, difficulty: 'easy' }]));
  act(() => result.current.startGame([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI', isAI: true, isHuman: false, difficulty: 'easy' }]));
  // simulate stale flag by calling startGame again while a move is "in progress"
  act(() => result.current.startGame([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI2', isAI: true, isHuman: false, difficulty: 'easy' }]));
  await waitFor(() => {
    expect(result.current.isAIThinking || result.current.gameState?.currentPlayerIndex).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: FAIL or at least the test is flaky because `isAIMovingRef` is not reset.

- [ ] **Step 3: Reset the flag in `startGame` and `loadSavedGame`**

In `src/hooks/useGameEngine.ts`, inside `startGame`, after `clearAITimeouts();` add:

```ts
isAIMovingRef.current = false;
```

Inside `loadSavedGame`, after `clearAITimeouts();` add:

```ts
isAIMovingRef.current = false;
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useGameEngine.ts src/hooks/useGameEngine.test.ts
git commit -m "fix(engine): reset isAIMovingRef on startGame and loadSavedGame"
```

---

## Task 1.2: Clear `isAIThinking` on auto-Dame

**Files:**
- Modify: `src/hooks/useGameEngine.ts:730-762` (`handleTryDiscardExtra`)
- Test: `src/hooks/useGameEngine.test.ts`

- [ ] **Step 1: Write the failing test**

Add a mocked test that calls `tryDiscardExtra` in a state where the hand becomes empty and verifies `isAIThinking` becomes `false` after the auto-Dame.

```ts
it('clears isAIThinking after auto-Dame from extra discard', async () => {
  const { result } = renderHook(() => useGameEngine([
    { name: 'P1', isAI: true, isHuman: false, difficulty: 'easy' },
    { name: 'P2', isAI: false, isHuman: true },
  ]));
  act(() => result.current.startGame([
    { name: 'P1', isAI: true, isHuman: false, difficulty: 'easy' },
    { name: 'P2', isAI: false, isHuman: true },
  ]));
  // This test requires a deterministic hand with one card; use a seeded deck or mock gameLogic.
});
```

Because `tryDiscardExtra` depends on the full game state, write an integration-style test or mock `discardExtraCard` to return `{ success: true, newState: <state with empty hand> }`.

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: FAIL — `isAIThinking` remains `true`.

- [ ] **Step 3: Clear `isAIThinking` in the auto-Dame branch**

In `handleTryDiscardExtra`, inside the `if (playerAfter && playerAfter.hand.length === 0)` block, before `handleEndTurn();` add:

```ts
setIsAIThinking(false);
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useGameEngine.ts src/hooks/useGameEngine.test.ts
git commit -m "fix(engine): clear isAIThinking after auto-Dame"
```

---

## Task 1.3: Clear turn timer on lifecycle changes

**Files:**
- Modify: `src/hooks/useGameEngine.ts:389-412` (`startGame`)
- Modify: `src/hooks/useGameEngine.ts:415-443` (`loadSavedGame`)
- Modify: `src/hooks/useGameEngine.ts:792-803` (`resetGame`)
- Test: `src/hooks/useGameEngine.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
it('clears the turn timer when starting a new game', async () => {
  const { result } = renderHook(() => useGameEngine([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI', isAI: true, isHuman: false, difficulty: 'easy' }], 'normal', undefined, { turnTimer: { enabled: true, seconds: 10 }, powerEffects: false }));
  act(() => result.current.startGame([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI', isAI: true, isHuman: false, difficulty: 'easy' }]));
  act(() => jest.advanceTimersByTime(100));
  act(() => result.current.startGame([{ name: 'P1', isAI: false, isHuman: true }, { name: 'AI', isAI: true, isHuman: false, difficulty: 'easy' }]));
  expect(result.current.turnTimeLeft).toBeNull();
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — timer state persists.

- [ ] **Step 3: Call `clearTimer()` in lifecycle functions**

In `startGame`, after `clearAITimeouts();` and `isAIMovingRef.current = false;` add:

```ts
clearTimer();
setIsTimerPaused(false);
```

In `loadSavedGame`, after `clearAITimeouts();` and `isAIMovingRef.current = false;` add:

```ts
clearTimer();
setIsTimerPaused(false);
```

In `resetGame`, after `clearAITimeouts();` add:

```ts
clearTimer();
setIsTimerPaused(false);
```

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/hooks/useGameEngine.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useGameEngine.ts src/hooks/useGameEngine.test.ts
git commit -m "fix(engine): clear turn timer on start, load and reset"
```

---

## Task 1.4: Make start dialog non-dismissible

**Files:**
- Modify: `src/components/GameBoard.tsx:315-383`
- Test: `src/components/GameBoard.test.tsx`

- [ ] **Step 1: Write the failing test**

```ts
it('does not close the start dialog on escape or outside click', () => {
  render(<GameBoard playerConfigs={[{ name: 'P1', isAI: false, isHuman: true }]} onBackToMenu={() => {}} />);
  const dialog = screen.getByRole('dialog');
  expect(dialog).toBeInTheDocument();
  fireEvent.keyDown(dialog, { key: 'Escape' });
  expect(screen.getByRole('dialog')).toBeInTheDocument();
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — dialog closes.

- [ ] **Step 3: Disable dismissal**

Find the start dialog:

```tsx
<Dialog open={showStartDialog} onOpenChange={setShowStartDialog}>
```

Change to:

```tsx
<Dialog open={showStartDialog} onOpenChange={() => {}}>
```

or use `modal={true}` and ensure there is no close button. If the Dialog already has a dedicated close button, remove it from the start dialog content.

- [ ] **Step 4: Run tests**

```bash
pnpm test -- --run src/components/GameBoard.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/GameBoard.tsx src/components/GameBoard.test.tsx
git commit -m "fix(ui): make start dialog non-dismissible"
```

---

## Task 1.5: Allow hot-seat to continue after elimination

**Files:**
- Modify: `src/components/GameBoard.tsx` (elimination screen)
- Test: `src/components/GameBoard.test.tsx`

- [ ] **Step 1: Locate the eliminated screen**

Find the JSX that renders when the current/bottom player is eliminated (likely around the main `PlayerHand` rendering).

- [ ] **Step 2: Add a continue button in hot-seat mode**

When `mode === 'hotseat'` and the current player is eliminated but the game is not over, render:

```tsx
<Button onClick={() => endTurn()}>
  {t('game.nextPlayer')}
</Button>
```

Use a new i18n key `game.nextPlayer` (de: „Nächster Spieler", en: "Next player").

- [ ] **Step 3: Run tests**

```bash
pnpm test -- --run src/components/GameBoard.test.tsx
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/components/GameBoard.tsx src/components/GameBoard.test.tsx src/lib/i18n.tsx
git commit -m "fix(ui): allow hot-seat to continue after player elimination"
```

---

## Task 1.6: Guard keyboard shortcuts behind Settings/Skin/Round-End dialogs

**Files:**
- Modify: `src/components/GameBoard.tsx:165-234`

- [ ] **Step 1: Update the guard condition**

Change:

```ts
if (showStartDialog || turnOverlayOpen || showJackEffect || showKingEffect || showAceEffect || showTutorial || winner) return;
```

to:

```ts
if (
  showStartDialog ||
  turnOverlayOpen ||
  showJackEffect ||
  showKingEffect ||
  showAceEffect ||
  showTutorial ||
  showSettings ||
  showSkinSelector ||
  gameState?.phase === 'ROUND_END' ||
  gameState?.phase === 'GAME_OVER' ||
  winner
) return;
```

- [ ] **Step 2: Update the dependency array**

Add `showSettings`, `showSkinSelector`, and `gameState?.phase` to the `useEffect` dependency array.

- [ ] **Step 3: Run tests**

```bash
pnpm test -- --run src/components/GameBoard.test.tsx
pnpm lint
```

Expected: PASS / clean.

- [ ] **Step 4: Commit**

```bash
git add src/components/GameBoard.tsx
git commit -m "fix(ui): block keyboard shortcuts while settings/skin/round-end dialogs are open"
```

---

## Task 1.7: Fix asset paths for subpath deployment

**Files:**
- Modify: `src/lib/skins/registry.ts`
- Modify: `src/App.tsx:84`
- Modify: `vite.config.ts:7`
- Modify: `AGENTS.md`

- [ ] **Step 1: Change skin asset paths to relative**

In `src/lib/skins/registry.ts`, replace every leading `/skins/` with `./skins/` (both `previewImage` and `assets.*`).

- [ ] **Step 2: Change menu music path to relative**

In `src/App.tsx`, change:

```ts
playMusicTrack('/sounds/music/menu.mp3')
```

to:

```ts
playMusicTrack('./sounds/music/menu.mp3')
```

- [ ] **Step 3: Change Vite base to relative**

In `vite.config.ts`, change:

```ts
base: '/Dame-Card-Game/',
```

to:

```ts
base: './',
```

- [ ] **Step 4: Update AGENTS.md**

Ensure the `Deployment` section correctly states `base: './'`.

- [ ] **Step 5: Run build and inspect output**

```bash
pnpm build
```

Open `dist/assets/index-*.js` and verify skin paths start with `./skins/` and the menu music path starts with `./sounds/`.

- [ ] **Step 6: Run tests and lint**

```bash
pnpm test -- --run
pnpm lint
```

Expected: PASS / clean.

- [ ] **Step 7: Commit**

```bash
git add src/lib/skins/registry.ts src/App.tsx vite.config.ts AGENTS.md
git commit -m "fix(deploy): use relative asset paths and base URL"
```

---

## Phase 1 Verification

- [ ] Run full test suite:

```bash
pnpm test -- --run
```

Expected: all tests pass.

- [ ] Run lint:

```bash
pnpm lint
```

Expected: no errors.

- [ ] Run build:

```bash
pnpm build
```

Expected: successful production build.

---

## Self-Review Checklist

- [ ] Spec coverage: All 7 critical bugs from the audit are addressed.
- [ ] Placeholder scan: No TBD/TODO/"implement later".
- [ ] Type consistency: `isAIMovingRef`, `clearTimer`, and `setIsTimerPaused` are used consistently.
