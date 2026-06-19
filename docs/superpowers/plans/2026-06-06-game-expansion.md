# Game Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erweitere das Dame Card Game um Blitz-Modus, optionale Power-Effekte und einen Settings-basierten Standard-KI-Schwierigkeits-Default.

**Architecture:** Settings-Flags (`turnTimer`, `turnTimerSeconds`, `powerEffects`, `defaultAIDifficulty`) werden in `useSettings.ts` zentral gehalten und via `GameConfig` an `useGameWithAI` durchgereicht. `gameLogic.ts` erhält neue Karteneffekte (`applyAceEffect`, `applyTenEffect`) und verzweigt auf `powerEffects`. `aiPlayer.ts` berücksichtigt `powerEffects` in seinen Entscheidungen. Ein neues `SettingsPanel`-Component bietet die UI.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS 3.4, shadcn/ui, Vitest.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `src/hooks/useSettings.ts` | Settings-State erweitern um `defaultAIDifficulty`, `turnTimer`, `turnTimerSeconds`, `powerEffects`. |
| `src/types/game.ts` | Neuer `GameConfig`-Typ. |
| `src/lib/gameLogic.ts` | Neue Funktionen `applyAceEffect`, `applyTenEffect`; `GameConfig`-basierte Verzweigungen für Power-Effekte. |
| `src/lib/aiPlayer.ts` | KI berücksichtigt `powerEffects` bei Bube, König, Ass, 10. |
| `src/hooks/useGameWithAI.ts` | Akzeptiert `GameConfig`; implementiert Timer-Logik; reicht `GameConfig` an Logik/KI durch; erweitert Savegame um `GameConfig`. |
| `src/components/SettingsPanel.tsx` | UI für alle Settings-Optionen. |
| `src/App.tsx` | Integriert `SettingsPanel`, verwendet `defaultAIDifficulty`, übergibt `GameConfig` an `GameBoard`. |
| `src/components/GameBoard.tsx` | Empfängt `GameConfig`, zeigt Countdown, übergibt Config an `useGameWithAI`. |
| `src/lib/i18n.tsx` | Neue Übersetzungs-Keys für Settings, Power-Effekte, Timer. |
| `src/lib/gameLogic.test.ts` | Tests für `applyAceEffect`, `applyTenEffect`, Power-Effekt-Verzweigungen. |
| `src/lib/aiPlayer.test.ts` | Tests für KI-Entscheidungen mit/ohne Power-Effekte. |

---

## Task 1: Extend Settings Hook

**Files:**
- Modify: `src/hooks/useSettings.ts`
- Test: `src/lib/gameLogic.test.ts` (wird später genutzt, hier keine Änderung)

- [ ] **Step 1: Update the `GameSettings` interface**

```ts
export type AIDifficulty = 'easy' | 'medium' | 'hard';

interface GameSettings {
  soundEnabled: boolean;
  animationsEnabled: boolean;
  aiSpeed: AISpeed;
  musicEnabled: boolean;
  defaultAIDifficulty: AIDifficulty;
  turnTimer: boolean;
  turnTimerSeconds: 15 | 30 | 60;
  powerEffects: boolean;
}
```

- [ ] **Step 2: Update defaults and add setters**

```ts
const DEFAULT_SETTINGS: GameSettings = {
  soundEnabled: true,
  animationsEnabled: true,
  aiSpeed: 'normal',
  musicEnabled: true,
  defaultAIDifficulty: 'medium',
  turnTimer: false,
  turnTimerSeconds: 30,
  powerEffects: false,
};
```

Füge Setter hinzu:

```ts
const setDefaultAIDifficulty = useCallback((difficulty: AIDifficulty) => {
  setSettings((prev) => ({ ...prev, defaultAIDifficulty: difficulty }));
}, []);

const setTurnTimer = useCallback((enabled: boolean) => {
  setSettings((prev) => ({ ...prev, turnTimer: enabled }));
}, []);

const setTurnTimerSeconds = useCallback((seconds: 15 | 30 | 60) => {
  setSettings((prev) => ({ ...prev, turnTimerSeconds: seconds }));
}, []);

const setPowerEffects = useCallback((enabled: boolean) => {
  setSettings((prev) => ({ ...prev, powerEffects: enabled }));
}, []);
```

- [ ] **Step 3: Export new setters**

```ts
return {
  settings,
  toggleSound,
  toggleAnimations,
  toggleMusic,
  setAiSpeed,
  setDefaultAIDifficulty,
  setTurnTimer,
  setTurnTimerSeconds,
  setPowerEffects,
};
```

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useSettings.ts
git commit -m "feat(settings): add turnTimer, powerEffects and defaultAIDifficulty"
```

---

## Task 2: Add GameConfig Type

**Files:**
- Modify: `src/types/game.ts`

- [ ] **Step 1: Append `GameConfig` interface after `GameAction`**

```ts
export interface GameConfig {
  turnTimer: { enabled: boolean; seconds: number };
  powerEffects: boolean;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/types/game.ts
git commit -m "feat(types): add GameConfig interface"
```

---

## Task 3: Implement Ace and Ten Power Effects in gameLogic

**Files:**
- Modify: `src/lib/gameLogic.ts`
- Test: `src/lib/gameLogic.test.ts`

- [ ] **Step 1: Write failing tests for `applyAceEffect` and `applyTenEffect`**

In `src/lib/gameLogic.test.ts`:

```ts
import { applyAceEffect, applyTenEffect } from './gameLogic';

describe('applyAceEffect', () => {
  it('reveals top 3 deck cards and lets player swap one', () => {
    const game = initializeGame(['A', 'B']);
    game.deck = [
      createCard('hearts', '2'),
      createCard('clubs', '5'),
      createCard('spades', 'K'),
      createCard('diamonds', '7'),
    ];
    const player = game.players[0];
    const originalHandCard = player.hand[2];
    const result = applyAceEffect(game, player.id, 1, 2); // swap deck index 1 with hand index 2
    expect(result.revealedCards).toHaveLength(3);
    expect(result.newState.players[0].hand[2].rank).toBe('5');
    expect(result.newState.deck[1].rank).toBe(originalHandCard.rank);
  });
});

describe('applyTenEffect', () => {
  it('skips the next player turn', () => {
    const game = initializeGame(['A', 'B']);
    game.phase = 'REGULAR_PLAY';
    game.safePhase = false;
    const result = applyTenEffect(game);
    expect(result.skipNextPlayer).toBe(true);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pnpm test -- --run src/lib/gameLogic.test.ts
```

Expected: FAIL – `applyAceEffect` / `applyTenEffect` not defined.

- [ ] **Step 3: Implement `applyAceEffect` and `applyTenEffect`**

In `src/lib/gameLogic.ts`:

```ts
export interface AceEffectResult {
  revealedCards: Card[];
  newState: GameState;
}

export function applyAceEffect(
  gameState: GameState,
  playerId: string,
  deckIndex: number,
  handIndex: number
): AceEffectResult {
  const newState = structuredClone(gameState);
  const player = newState.players.find((p) => p.id === playerId)!;

  const revealedCards: Card[] = [];
  for (let i = 0; i < 3; i++) {
    const idx = newState.deck.length - 1 - i;
    if (idx >= 0) {
      const card = { ...newState.deck[idx], isVisible: true };
      revealedCards.unshift(card);
    }
  }

  if (
    deckIndex >= 0 &&
    deckIndex < revealedCards.length &&
    handIndex >= 0 &&
    handIndex < player.hand.length
  ) {
    const actualDeckIndex = newState.deck.length - 1 - deckIndex;
    const deckCard = newState.deck[actualDeckIndex];
    const handCard = player.hand[handIndex];

    player.hand[handIndex] = { ...deckCard, isVisible: false };
    newState.deck[actualDeckIndex] = { ...handCard, isVisible: true };

    // Reset visibility tracking for swapped hand position
    player.visibleCardIndices = player.visibleCardIndices.filter((i) => i !== handIndex);
  }

  newState.lastAction = `${player.name} hat die Zukunft gesehen`;
  return { revealedCards, newState };
}

export interface TenEffectResult {
  skipNextPlayer: boolean;
  newState: GameState;
}

export function applyTenEffect(gameState: GameState): TenEffectResult {
  const newState = structuredClone(gameState);
  newState.lastAction = 'Nächster Spieler überspringt den Zug';
  return { skipNextPlayer: true, newState };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pnpm test -- --run src/lib/gameLogic.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/gameLogic.ts src/lib/gameLogic.test.ts
git commit -m "feat(logic): add ace prophecy and ten stun effects"
```

---

## Task 4: Add Power-Effect Branches to gameLogic

**Files:**
- Modify: `src/lib/gameLogic.ts`

- [ ] **Step 1: Update function signatures to accept `GameConfig`**

Modify `swapCard`, `applyJackEffect`, `applyKingEffect`, `peekCard` to accept an optional `GameConfig` parameter. Example for `applyJackEffect`:

```ts
export function applyJackEffect(
  gameState: GameState,
  viewerPlayerId: string,
  targetPlayerId: string,
  handIndex: number,
  config?: GameConfig
): GameState {
  // existing logic, but if config?.powerEffects and viewerPlayerId === targetPlayerId,
  // force the player to pick an opponent card instead.
}
```

- [ ] **Step 2: Add power-effect validation in `applyJackEffect`**

```ts
if (config?.powerEffects && viewerPlayerId === targetPlayerId) {
  newState.lastAction = 'Im Power-Modus muss der Bube eine gegnerische Karte peken';
  return newState;
}
```

- [ ] **Step 3: Add power-effect validation in `applyKingEffect`**

```ts
if (config?.powerEffects && playerId === targetPlayerId) {
  newState.lastAction = 'Im Power-Modus muss der König mit einem Gegner tauschen';
  return newState;
}
```

- [ ] **Step 4: Commit**

```bash
git add src/lib/gameLogic.ts
git commit -m "feat(logic): enforce power-effect rules for jack and king"
```

---

## Task 5: Update AI Player for Power Effects

**Files:**
- Modify: `src/lib/aiPlayer.ts`
- Test: `src/lib/aiPlayer.test.ts`

- [ ] **Step 1: Update `decideAIMove` signature**

```ts
export function decideAIMove(
  gameState: GameState,
  playerId: string,
  difficulty: AIDifficulty,
  drawnCard: Card | null = null,
  config?: GameConfig
): AIDecisionWithDelay {
```

- [ ] **Step 2: Export `findWorstCardIndex` from `aiPlayer.ts`**

```ts
export function findWorstCardIndex(player: Player): number {
  // existing implementation
}
```

- [ ] **Step 3: Pass `config` to post-draw functions**

```ts
function makeMediumPostDrawMove(
  gameState: GameState,
  playerId: string,
  drawnCard: Card,
  config?: GameConfig
): AIDecision { ... }
```

- [ ] **Step 4: Adjust Jack and King logic when `config?.powerEffects`**

For Jack in `makeMediumPostDrawMove`:

```ts
if (drawnCard.rank === 'J') {
  const otherPlayers = gameState.players.filter((p) => p.id !== playerId && !p.isEliminated);
  if (config?.powerEffects && otherPlayers.length > 0) {
    const targetPlayer = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
    const targetIndex = Math.floor(Math.random() * targetPlayer.hand.length);
    return { action: 'USE_JACK', payload: { targetPlayerId: targetPlayer.id, handIndex: targetIndex } };
  }
  // existing self-peek logic
}
```

For King in `makeMediumPostDrawMove`:

```ts
if (drawnCard.rank === 'K') {
  const otherPlayers = gameState.players.filter((p) => p.id !== playerId && !p.isEliminated);
  if (config?.powerEffects && otherPlayers.length > 0) {
    const targetPlayer = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
    const myWorstCard = findWorstCardIndex(player);
    return {
      action: 'USE_KING',
      payload: {
        targetPlayerId: targetPlayer.id,
        myHandIndex: myWorstCard,
        targetHandIndex: Math.floor(Math.random() * targetPlayer.hand.length),
      },
    };
  }
  // existing logic
}
```

- [ ] **Step 5: Add Ace and Ten handling for all difficulties**

For Ace in `makeEasyPostDrawMove`, `makeMediumPostDrawMove`, `makeHardPostDrawMove`:

```ts
if (drawnCard.rank === 'A' && config?.powerEffects) {
  return { action: 'USE_ACE' };
}
```

For Ten in `makeEasyPostDrawMove`, `makeMediumPostDrawMove`, `makeHardPostDrawMove`:

```ts
if (drawnCard.rank === '10' && config?.powerEffects) {
  return { action: 'USE_TEN' };
}
```

- [ ] **Step 6: Update AI action types**

```ts
export type AIActionType =
  | 'WAIT'
  | 'DRAW_FROM_DECK'
  | 'DRAW_FROM_DISCARD'
  | 'SWAP_CARD'
  | 'DISCARD_DRAWN_CARD'
  | 'DISCARD_EXTRA_CARD'
  | 'USE_JACK'
  | 'USE_KING'
  | 'USE_ACE'
  | 'USE_TEN'
  | 'CALL_DAME'
  | 'END_TURN';
```

```ts
export type AIDecision =
  | { action: 'WAIT' }
  | { action: 'DRAW_FROM_DECK' }
  | { action: 'DRAW_FROM_DISCARD' }
  | { action: 'SWAP_CARD'; payload: { handIndex: number } }
  | { action: 'DISCARD_DRAWN_CARD' }
  | { action: 'DISCARD_EXTRA_CARD'; payload: { cardId: string } }
  | { action: 'USE_JACK'; payload: { targetPlayerId: string; handIndex: number } }
  | { action: 'USE_KING'; payload: { targetPlayerId: string; myHandIndex: number; targetHandIndex: number } }
  | { action: 'USE_ACE' }
  | { action: 'USE_TEN' }
  | { action: 'CALL_DAME' }
  | { action: 'END_TURN' };
```

- [ ] **Step 7: Write tests for AI with power effects**

In `src/lib/aiPlayer.test.ts`:

```ts
const powerConfig: GameConfig = { turnTimer: { enabled: false, seconds: 30 }, powerEffects: true };
const normalConfig: GameConfig = { turnTimer: { enabled: false, seconds: 30 }, powerEffects: false };

describe('AI power effects', () => {
  it('uses USE_ACE action when ace is drawn and power effects are enabled', () => {
    const game = initializeGame(['Human', 'AI']);
    game.phase = 'REGULAR_PLAY';
    game.safePhase = false;
    const ai = game.players[1];
    const ace = createCard('hearts', 'A');
    const decision = decideAIMove(game, ai.id, 'medium', ace, powerConfig);
    expect(decision.action).toBe('USE_ACE');
  });

  it('does not use USE_ACE when power effects are disabled', () => {
    const game = initializeGame(['Human', 'AI']);
    game.phase = 'REGULAR_PLAY';
    game.safePhase = false;
    const ai = game.players[1];
    const ace = createCard('hearts', 'A');
    const decision = decideAIMove(game, ai.id, 'medium', ace, normalConfig);
    expect(decision.action).not.toBe('USE_ACE');
  });
});
```

- [ ] **Step 8: Run tests**

```bash
pnpm test -- --run src/lib/aiPlayer.test.ts
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/lib/aiPlayer.ts src/lib/aiPlayer.test.ts
git commit -m "feat(ai): support power effects in AI decisions"
```

---

## Task 6: Integrate GameConfig and Timer into useGameWithAI

**Files:**
- Modify: `src/hooks/useGameWithAI.ts`
- Test: none (covered by existing integration tests + manual verification)

- [ ] **Step 1: Update the hook signature and interface**

```ts
export function useGameWithAI(
  aiSpeed: AISpeed = 'normal',
  statsActions?: StatsActions,
  gameConfig?: GameConfig
): UseGameWithAIReturn {
```

- [ ] **Step 2: Add timer state**

```ts
const [turnTimeLeft, setTurnTimeLeft] = useState<number | null>(null);
```

- [ ] **Step 3: Start timer when human turn begins**

```ts
useEffect(() => {
  if (!gameState || !gameConfig?.turnTimer.enabled) return;
  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  if (aiPlayers.has(currentPlayer.id)) return;
  if (gameState.phase === 'ROUND_END' || gameState.phase === 'GAME_OVER') return;

  setTurnTimeLeft(gameConfig.turnTimer.seconds);
  const interval = setInterval(() => {
    setTurnTimeLeft((prev) => {
      if (prev === null || prev <= 1) {
        clearInterval(interval);
        handleTimerExpired();
        return 0;
      }
      return prev - 1;
    });
  }, 1000);

  return () => clearInterval(interval);
}, [gameState, gameConfig, aiPlayers]);
```

- [ ] **Step 4: Implement `handleTimerExpired`**

```ts
const handleTimerExpired = useCallback(() => {
  if (!gameStateRef.current) return;
  const currentPlayerIndex = gameStateRef.current.currentPlayerIndex;
  const currentPlayer = gameStateRef.current.players[currentPlayerIndex];
  if (aiPlayersRef.current.has(currentPlayer.id)) return;

  // Draw penalty card
  const { card, newState } = drawFromDeck(gameStateRef.current);
  if (card) {
    card.isVisible = false;
    const updatedPlayer = newState.players[currentPlayerIndex];
    updatedPlayer.penaltyCards.push(card);
    gameStateRef.current = newState;
    setGameState(newState);
  }

  setMessage('game.turnTimerExpired');
  handleEndTurn();
}, [setMessage, handleEndTurn]);
```

- [ ] **Step 5: Pause timer during power-effect selection**

Return `pauseTurnTimer` and `resumeTurnTimer` from the hook:

```ts
const pauseTurnTimer = useCallback(() => setIsTimerPaused(true), []);
const resumeTurnTimer = useCallback(() => setIsTimerPaused(false), []);
```

Add `isTimerPaused` state and include it in the timer effect dependencies. When paused, the interval stops decrementing.

- [ ] **Step 6: Save `gameConfig` in savegame**

```ts
const saveData = {
  gameState: state,
  drawnCard: drawn,
  aiPlayers: Array.from(ai.entries()),
  gameMessage: msg,
  messageKey: msgKey,
  gameConfig,
  timestamp: Date.now(),
};
```

- [ ] **Step 7: Update return type and exports**

```ts
export interface UseGameWithAIReturn {
  // ... existing fields
  turnTimeLeft: number | null;
  pauseTurnTimer: () => void;
  resumeTurnTimer: () => void;
}
```

- [ ] **Step 8: Commit**

```bash
git add src/hooks/useGameWithAI.ts
git commit -m "feat(game): add turn timer and GameConfig integration"
```

---

## Task 7: Handle New AI Actions

**Files:**
- Modify: `src/hooks/useGameWithAI.ts`
- Modify: `src/types/game.ts`

- [ ] **Step 1: Add `skipNextPlayer` to `GameState`**

```ts
export interface GameState {
  // ... existing fields
  skipNextPlayer?: boolean;
}
```

- [ ] **Step 2: Import new helpers**

```ts
import { applyAceEffect, applyTenEffect } from '@/lib/gameLogic';
import { findWorstCardIndex } from '@/lib/aiPlayer';
```

- [ ] **Step 3: Add handlers for Ace and Ten effects**

```ts
const handleUseAce = useCallback(() => {
  if (!gameStateRef.current || !drawnCardRef.current) return;
  const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

  const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
  gameStateRef.current = discardedState;
  setGameState(discardedState);
  drawnCardRef.current = null;
  setDrawnCard(null);

  // For AI, auto-select worst hand card and best revealed deck card
  const worstIndex = findWorstCardIndex(currentPlayer);
  const result = applyAceEffect(discardedState, currentPlayer.id, 0, worstIndex);
  gameStateRef.current = result.newState;
  setGameState(result.newState);

  const isAI = aiPlayersRef.current.has(currentPlayer.id);
  if (!isAI) {
    setMessage('game.aceProphecy');
  }
}, [setMessage]);

const handleUseTen = useCallback(() => {
  if (!gameStateRef.current || !drawnCardRef.current) return;
  const currentPlayer = gameStateRef.current.players[gameStateRef.current.currentPlayerIndex];

  const discardedState = discardCard(gameStateRef.current, drawnCardRef.current);
  const result = applyTenEffect(discardedState);
  gameStateRef.current = result.newState;
  setGameState(result.newState);
  drawnCardRef.current = null;
  setDrawnCard(null);

  // Store skip flag in game state or handle in endTurn
  if (result.skipNextPlayer) {
    result.newState.skipNextPlayer = true;
    gameStateRef.current = result.newState;
  }

  const isAI = aiPlayersRef.current.has(currentPlayer.id);
  if (!isAI) {
    setMessage('game.tenStun');
  }
}, [setMessage]);
```

- [ ] **Step 4: Update `executeAIMove` switch**

```ts
case 'USE_ACE':
  handleUseAce();
  scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
  break;
case 'USE_TEN':
  handleUseTen();
  scheduleAITimeout(() => endTurnAfterAI(), Math.round(500 * currentSpeed));
  break;
```

- [ ] **Step 5: Handle skip next player in `endTurn`**

Add a field `skipNextPlayer?: boolean` to `GameState` or track it locally. In `handleEndTurn`, after calling `endTurn`, if `skipNextPlayer` is set, call `endTurn` once more to skip the next player.

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useGameWithAI.ts src/types/game.ts
git commit -m "feat(game): handle ace and ten power effects"
```

---

## Task 8: Create SettingsPanel Component

**Files:**
- Create: `src/components/SettingsPanel.tsx`
- Modify: `src/App.tsx`

- [ ] **Step 1: Create the component skeleton**

```tsx
import { useSettings } from '@/hooks/useSettings';
import { useI18n } from '@/lib/i18n';
import type { AIDifficulty } from '@/lib/aiPlayer';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface SettingsPanelProps {
  onClose: () => void;
}

export function SettingsPanel({ onClose }: SettingsPanelProps) {
  const { t } = useI18n();
  const {
    settings,
    toggleSound,
    toggleMusic,
    toggleAnimations,
    setAiSpeed,
    setDefaultAIDifficulty,
    setTurnTimer,
    setTurnTimerSeconds,
    setPowerEffects,
  } = useSettings();
  const { language, setLanguage } = useI18n();

  return (
    <Card className="max-w-lg mx-auto">
      <CardHeader>
        <CardTitle>{t('settings.title')}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* sections below */}
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 2: Add Game Rules section**

```tsx
<section>
  <h3 className="text-sm font-bold uppercase tracking-wider mb-2">{t('settings.gameRules')}</h3>
  <div className="flex items-center justify-between">
    <span>{t('settings.powerEffects')}</span>
    <Switch checked={settings.powerEffects} onCheckedChange={setPowerEffects} />
  </div>
  <p className="text-xs opacity-70 mt-1">{t('settings.powerEffectsHint')}</p>
</section>
```

- [ ] **Step 3: Add Blitz Mode section**

```tsx
<section>
  <h3 className="text-sm font-bold uppercase tracking-wider mb-2">{t('settings.blitzMode')}</h3>
  <div className="flex items-center justify-between mb-2">
    <span>{t('settings.turnTimer')}</span>
    <Switch checked={settings.turnTimer} onCheckedChange={setTurnTimer} />
  </div>
  {settings.turnTimer && (
    <div className="flex gap-2">
      {[15, 30, 60].map((s) => (
        <Button
          key={s}
          variant={settings.turnTimerSeconds === s ? 'default' : 'outline'}
          onClick={() => setTurnTimerSeconds(s as 15 | 30 | 60)}
        >
          {s}s
        </Button>
      ))}
    </div>
  )}
</section>
```

- [ ] **Step 4: Add AI Default section**

```tsx
<section>
  <h3 className="text-sm font-bold uppercase tracking-wider mb-2">{t('settings.aiDefault')}</h3>
  <select
    value={settings.defaultAIDifficulty}
    onChange={(e) => setDefaultAIDifficulty(e.target.value as AIDifficulty)}
  >
    <option value="easy">{t('menu.difficulty.easy')}</option>
    <option value="medium">{t('menu.difficulty.medium')}</option>
    <option value="hard">{t('menu.difficulty.hard')}</option>
  </select>
</section>
```

- [ ] **Step 5: Add Audio/Language section**

Reuse existing toggles for sound, music, animations, aiSpeed, and language.

- [ ] **Step 6: Integrate into App.tsx**

Add a `gameMode` state value `'settings'` and a button to open settings from the main menu.

```tsx
<Button onClick={() => setGameMode('settings')}>
  {t('menu.settings')}
</Button>
```

```tsx
if (gameMode === 'settings') {
  return (
    <div className="min-h-screen terminal-grid relative flex items-center justify-center p-4">
      <SettingsPanel onClose={() => setGameMode('menu')} />
    </div>
  );
}
```

- [ ] **Step 7: Commit**

```bash
git add src/components/SettingsPanel.tsx src/App.tsx
git commit -m "feat(ui): add settings panel for new game options"
```

---

## Task 9: Wire GameConfig Through App and GameBoard

**Files:**
- Modify: `src/App.tsx`
- Modify: `src/components/GameBoard.tsx`

- [ ] **Step 1: Build GameConfig in App.tsx**

```tsx
const { settings } = useSettings();

const gameConfig: GameConfig = {
  turnTimer: { enabled: settings.turnTimer, seconds: settings.turnTimerSeconds },
  powerEffects: settings.powerEffects,
};
```

- [ ] **Step 2: Pass GameConfig to GameBoard**

```tsx
<GameBoard players={players} onBackToMenu={backToMenu} gameConfig={gameConfig} />
```

- [ ] **Step 3: Update GameBoard props and pass to hook**

```tsx
interface GameBoardProps {
  players: Array<{ name: string; isAI?: boolean; difficulty?: AIDifficulty }>;
  onBackToMenu: () => void;
  gameConfig: GameConfig;
}

export function GameBoard({ players, onBackToMenu, gameConfig }: GameBoardProps) {
  const { gameState, drawnCard, ..., turnTimeLeft, pauseTurnTimer, resumeTurnTimer } = useGameWithAI(
    settings.aiSpeed,
    statsActions,
    gameConfig
  );
}
```

- [ ] **Step 4: Show timer countdown in GameBoard**

```tsx
{gameConfig.turnTimer.enabled && turnTimeLeft !== null && (
  <div className="text-xl font-mono">{turnTimeLeft}s</div>
)}
```

- [ ] **Step 5: Pause timer during power-effect selection**

In GameBoard, call `pauseTurnTimer()` when opening a power-effect selection dialog (King swap, Jack peek, Ace prophecy) and `resumeTurnTimer()` when the selection is confirmed or cancelled.

- [ ] **Step 6: Use defaultAIDifficulty when adding AI players**

```tsx
const addAIPlayer = () => {
  if (players.length < 6) {
    const aiCount = players.filter((p) => p.isAI).length;
    setPlayers([
      ...players,
      { name: `KI-${aiCount + 1}`, isAI: true, difficulty: settings.defaultAIDifficulty },
    ]);
  }
};
```

- [ ] **Step 7: Commit**

```bash
git add src/App.tsx src/components/GameBoard.tsx
git commit -m "feat(app): wire GameConfig and timer through app"
```

---

## Task 10: Add i18n Translations

**Files:**
- Modify: `src/lib/i18n.tsx`

- [ ] **Step 1: Add German keys**

```ts
de: {
  // ... existing
  settings: {
    title: 'Einstellungen',
    gameRules: 'Spielregeln',
    powerEffects: 'Power-Effekte',
    powerEffectsHint: 'König tauscht, Bube peekt, Ass prophezeit, 10 stunnert.',
    blitzMode: 'Blitz-Modus',
    turnTimer: 'Zugzeitlimit',
    aiDefault: 'Standard-KI-Schwierigkeit',
  },
  game: {
    // ... existing
    turnTimerExpired: 'Zeit abgelaufen! Strafkarte gezogen.',
    aceProphecy: 'Ass: Du hast die Zukunft gesehen.',
    tenStun: '10: Gegner überspringt den Zug.',
  },
}
```

- [ ] **Step 2: Add English keys**

```ts
en: {
  // ... existing
  settings: {
    title: 'Settings',
    gameRules: 'Game Rules',
    powerEffects: 'Power Effects',
    powerEffectsHint: 'King swaps, Jack peeks, Ace prophecies, Ten stuns.',
    blitzMode: 'Blitz Mode',
    turnTimer: 'Turn Timer',
    aiDefault: 'Default AI Difficulty',
  },
  game: {
    // ... existing
    turnTimerExpired: 'Time is up! Penalty card drawn.',
    aceProphecy: 'Ace: You have seen the future.',
    tenStun: '10: Opponent skips turn.',
  },
}
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/i18n.tsx
git commit -m "feat(i18n): add translations for settings and power effects"
```

---

## Task 11: Final Verification

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
git commit -m "feat: game expansion with blitz mode, power effects and settings panel"
```

---

## Self-Review Checklist

- [ ] Spec coverage: Blitz-Modus, Power-Effekte, KI-Default, Settings-Panel, i18n, Tests sind abgedeckt.
- [ ] Placeholder scan: Keine TBD/TODO/"implement later" im Plan.
- [ ] Type consistency: `GameConfig`, `AIDecision`, Settings-Typen sind konsistent.
