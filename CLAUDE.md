# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Browser-based implementation of the German memory/bluff card game "Dame" (not checkers) for 2–6 players, human vs. human (hot-seat) or vs. AI. Pure client-side SPA (React 19 + TypeScript + Vite + Tailwind/shadcn), no backend. `AGENTS.md` holds the longer German project overview; `CONCEPT_DECISIONS.md` is the binding rules spec (extra-discard instead of real-time snapping, one penalty card per mistake, Queen always face-up and forces the next player, Dame-call locking/final-turn semantics). Design plans/specs from past work live in `docs/superpowers/`.

## Commands

Package manager is **pnpm** (lockfile + CI use pnpm 9 / Node 22). `node_modules` is not committed — run `pnpm install` first.

```bash
pnpm dev                       # Vite dev server → http://localhost:5173/Dame-Card-Game/
pnpm build                     # tsc -b && vite build (type errors fail the build)
pnpm lint                      # eslint .
pnpm test -- --run             # all Vitest tests once (jsdom, globals, setup in src/test/setup.ts)
pnpm vitest run src/lib/gameLogic.test.ts          # single file
pnpm vitest run -t "name of test"                  # single test by name
pnpm test:ui                   # Vitest UI
```

`tsconfig.app.json` is strict with `noUnusedLocals`/`noUnusedParameters` and `verbatimModuleSyntax` — unused symbols break `pnpm build`, and type-only imports must use `import type`. Path alias `@/*` → `src/*` (configured in both `vite.config.ts` and `vitest.config.ts`).

Deployment: every push to `main` builds and deploys to GitHub Pages via `.github/workflows/deploy.yml` (build only — CI does not run tests or lint). Vite `base` is `/Dame-Card-Game/` (AGENTS.md's mention of `base: './'` is outdated).

## Architecture

Three layers, data flowing one way:

1. **Pure logic — `src/lib/gameLogic.ts`, `src/lib/aiPlayer.ts`, `src/types/game.ts`.** No React. Every game function takes a `GameState` and returns a new one (`structuredClone`), e.g. `drawFromDeck`, `swapCard`, `applyJackEffect`, `applyKingEffect`, `applyQueenEffect`, `callDame`, `endTurn`, `endRound`, `startNextRound`, `discardExtraCard`. `endTurn` only signals round end (via phase / `dameCallTurnsRemaining`); the hook is responsible for calling `endRound`. Optional "power effects" (`applyAceEffect`, `applyTenEffect`) are gated by `GameConfig.powerEffects`. AI is a single entry point `decideAIMove(state, playerId, difficulty, drawnCard?)` dispatching to per-difficulty `makeXxxMove` / `makeXxxPostDrawMove`; AI uses each `Player.memory` (`MemoryEntry[]` of seen cards) and `visibleCardIndices` rather than peeking at hidden cards.

2. **Engine hook — `src/hooks/useGameEngine.ts`.** Owns React state and orchestrates everything the pure layer doesn't: the currently drawn card (`drawnCard` lives *outside* `GameState`), AI turn scheduling, turn timer, hot-seat turn overlay, stats callbacks, and save/load. Key patterns:
   - AI moves run from `useEffect` + `setTimeout`; delays come from the AI decision scaled by `SPEED_MULTIPLIERS[aiSpeed]`. Timeouts are tracked in `aiTimeoutsRef` and cleared on reset/unmount; `isAIMovingRef` guards against double execution.
   - `gameStateRef`, `drawnCardRef`, `aiPlayersRef`, etc. mirror state so timeout callbacks read current values — keep them in sync when adding state used by async callbacks.
   - The full game (state, drawn card, AI map, message, overlay flag, config) is autosaved to `localStorage['dame-game-save']` and validated field-by-field on load (`isValidCard`, valid suits/ranks/phases). Changing `GameState`/`Card` shape requires updating these validators.

3. **UI — `src/App.tsx` → `src/components/GameBoard.tsx`.** `App.tsx` is a mode router (`menu | game | rules | settings | shop | hotseat-setup | hotseat`) and builds `PlayerConfig[]`. `GameBoard` instantiates `useGameEngine`, renders `PlayerHand`/`Card`, handles keyboard shortcuts, and pushes settings into the module-level `setGlobalSettings` so non-React code (`src/lib/sounds.ts`, Web Audio) can read sound/animation flags. `PlayerTurnOverlay` hides hands between human turns in hot-seat mode.

Cross-cutting providers/state (all persisted in `localStorage`):
- **i18n** — `src/lib/i18n.tsx`: inline `de`/`en` dictionaries, `useI18n().t('dot.path', {{vars}})`. All user-facing strings go through `t()`; add keys to **both** languages. German is the default.
- **Settings** — `src/hooks/useSettings.tsx` context over `GameSettings`/`DEFAULT_SETTINGS` in `src/lib/settings.ts` (AI speed/difficulty, timer, sound/music, powerEffects, table3d).
- **Skins** — `src/lib/skins/` (`registry.ts` static `SKIN_REGISTRY`, `inventoryService.ts` local inventory, `skinContext.ts`) provided by `components/SkinProvider.tsx`; categories `cardBack | table | cardFace`.
- **Stats** — `src/lib/stats.ts` + `useGameStats`.

Visual theme is a "terminal/cyber archive" look: colors via CSS variables like `--terminal-green/amber/red/cyan` in `src/index.css` (see `SUIT_COLORS` in `types/game.ts`). shadcn/ui components are installed under `src/components/ui/`; add new ones with `npx shadcn add <component>`.

## Conventions

- Code comments and all UI text in **German**; identifiers in English.
- New game rules: add a pure function in `gameLogic.ts` (with a test in `gameLogic.test.ts`), teach `aiPlayer.ts` if AI must react to it, then wire it through `useGameEngine.ts` and the board UI.
- Tests sit next to sources (`*.test.ts(x)`); hook/component tests use Testing Library with jsdom.
