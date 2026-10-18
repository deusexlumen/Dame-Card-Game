# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Browser-based implementation of the German memory/bluff card game "Dame" (not checkers) for 2–6 players, human vs. human (hot-seat) or vs. AI. Pure client-side SPA (React 19 + TypeScript + Vite + Tailwind/shadcn), no backend. `AGENTS.md` holds the longer German project overview; `CONCEPT_DECISIONS.md` is the binding rules spec (extra-discard instead of real-time snapping, one penalty card per mistake, Queen always face-up and forces the next player, Dame-call locking/final-turn semantics). Design plans/specs from past work live in `docs/superpowers/`.

**Main project is now the Godot client in `godot/`** (see the top of `AGENTS.md`, load the `dame-godot` skill). GitHub Pages deploys only the Godot web build. The React app below is kept as reference.

## Leitbild (verbindlich, vom Nutzer, gilt vor allen anderen Dokumenten)

1. **Herzensprojekt.** Es soll funktionieren und Spaß machen, weil es Spaß machen soll. Geld ist kein Ziel. Keine Planung zu Shop, Preisen, Verkauf, Geschäftsmodell oder Veröffentlichung, außer der Nutzer spricht es selbst an.
2. **Eine App.** Alles wird eine einzige App: die Latte-App („Die Latte liegt am Boden“, Repo `latte-app`). Kein Spiel ist als eigenständige App ein Ziel; DAME und Lobby-Loop sind Quellen dieser App.
3. **Wofür.** Im Mittelpunkt stehen die Welt, ihre Funktion und das Erleben. Man soll mit mehr aus dem Spiel gehen, als man hineingegangen ist, obwohl man die ganze Zeit verliert. Grundlage sind das Manifest „Die Latte liegt am Boden“ (Kulisse gegen Fundament, Diogenes, Mad Jack) und ein systemtheoretischer Blick auf Institutionen. Jede Funktion wird daran gemessen, ob sie die Welt, das Erleben und diese Erkenntnis stärkt.
4. Ältere Dokumente, die Verkauf, Geschäftsmodell oder eigenständige Apps planen (z. B. im Gesamtkonzept „Geld ohne Gier“ und „Kein Spiel hängt vom anderen ab … einzeln startbar“), sind darin überholt.

DAME ist im Godot-Teil (`godot/`) eine Quelle der Latte-App: `latte-app/tools/sync-games.mjs` übernimmt es nach `addons/dame/`. Änderungen an DAME passieren hier, danach wird in Latte neu gesynct.

## Arbeitsweise mit dem Nutzer (verbindlich, geht allem anderen vor)

Der Nutzer gibt Routinearbeit komplett ab. Diese Regeln gelten wörtlich:

1. **Selbst erledigen, nicht fragen.** Eigene PRs gleich als „ready“ (kein Draft) öffnen, CI-Fehler und Review-Kommentare selbst beheben und **selbst nach `main` mergen** (Squash), sobald CI auf dem aktuellen Commit grün ist, kein Konflikt besteht und kein Review-Thread offen ist. Dafür keine Rückfrage. Gefragt wird nur bei echten Produktentscheidungen (Spielregeln, Geld, Datenschutz, Löschen).
2. **Nur melden, was der Nutzer zum Handeln braucht.** Keine Bestätigung von Selbstverständlichem (Merge geklappt, Subscription beendet, Benachrichtigung gelesen). Läuft alles glatt, reicht ein Satz.
3. **Kein „offen“ oder „ungeprüft“ ohne Lösungsversuch.** Erst lösen. Geht es nicht: sagen, warum nicht, was das praktisch fürs Spiel bedeutet und wer konkret was tun muss. Ein Grund muss geprüft sein, nicht vermutet.
4. **Wörter meinen, was sie sagen.** „Nichts zu tun“ heißt: gemergt, Notizen aktuell, kein offener Punkt. Sonst die offenen Punkte nennen.

## Cloud-Sandbox (Claude Code im Web)

- `.claude/hooks/session-start.sh` holt Linux-Godot 4.7.2 und setzt `GODOT_BIN`; Tests: `node scripts/godot-test.mjs`.
- Die Sandbox lässt **keine WebSockets** durch (Proxy) und hat keine Netzwerkschnittstellen für WebRTC. Dort schlagen deshalb 3 Warte-Checks in `test_rtc_connector`/`test_online_screen` fehl; maßgeblich ist die CI auf GitHub, nicht die Sandbox.
- Live-Prüfungen gegen Supabase laufen deshalb in GitHub Actions: `.github/workflows/online-live.yml` (`godot/tools/live_signaling.gd`, bei Netz-Änderungen und täglich).

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

Deployment: every push to `main` runs `.github/workflows/deploy.yml`, which tests, exports and deploys only the **Godot** web build to GitHub Pages. The React app is no longer built or deployed; CI does not run its tests or lint. Vite `base` is `/Dame-Card-Game/` (AGENTS.md's mention of `base: './'` is outdated).

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
