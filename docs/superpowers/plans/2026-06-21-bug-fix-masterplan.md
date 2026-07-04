# Bug-Fix Masterplan — Dame Card Game

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans for each phase, then superpowers:subagent-driven-development or superpowers:executing-plans to implement.

**Goal:** Alle aus dem Schwarm-Bug-Audit vom 2026-06-21 identifizierten Bugs fixen.

**Architecture:** Die Fixes bleiben innerhalb der bestehenden Architektur. Kritische Engine-Deadlocks und UI-Dead-Ends werden zuerst behoben, dann Spiellogik, UI/UX/i18n, Tests und schließlich Skins/Shop.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS, shadcn/ui, Vitest.

---

## Phase 1: Kritische Bugs (Engine-Deadlocks, UI-Dead-Ends, Deploy)

**Ziel:** Spiel läuft stabil, keine Freezes, kein leerer Screen, Assets laden auf GitHub Pages.

| # | Bug | Dateien |
|---|---|---|
| 1.1 | `isAIMovingRef` nicht reset bei `startGame` / `loadSavedGame` | `src/hooks/useGameEngine.ts` |
| 1.2 | Auto-Dame in `tryDiscardExtra` setzt `isAIThinking` nicht zurück | `src/hooks/useGameEngine.ts` |
| 1.3 | Turn-Timer nicht gecleared bei Start/Load/Reset | `src/hooks/useGameEngine.ts` |
| 1.4 | Start-Dialog kann geschlossen werden → leerer Screen | `src/components/GameBoard.tsx` |
| 1.5 | Hot-Seat: eliminierter Spieler blockiert Fortsetzung | `src/components/GameBoard.tsx` |
| 1.6 | Keyboard-Shortcuts feuern hinter Modals | `src/components/GameBoard.tsx` |
| 1.7 | Asset-Pfade ignorieren Vite-`base` → 404 auf GitHub Pages | `src/lib/skins/registry.ts`, `src/App.tsx`, `vite.config.ts` |

## Phase 2: Spiellogik-Bugs

**Ziel:** Regeln werden korrekt umgesetzt.

| # | Bug | Dateien |
|---|---|---|
| 2.1 | Zehn-Effekt überspringt nächsten Spieler nicht | `src/lib/gameLogic.ts`, `src/types/game.ts` |
| 2.2 | `visibleCardIndices` korrupt nach `discardExtraCard` | `src/lib/gameLogic.ts` |
| 2.3 | Ass-Effekt deckt Deck-Karten dauerhaft auf | `src/lib/gameLogic.ts` |
| 2.4 | Bube/König im Standard-Modus falsch (Selbstziel/Gegnerziel) | `src/lib/gameLogic.ts`, `src/hooks/useGameEngine.ts` |
| 2.5 | Dame-Call rotiert Startspieler falsch | `src/lib/gameLogic.ts` |
| 2.6 | `getWinner` crasht bei allen eliminiert | `src/lib/gameLogic.ts` |
| 2.7 | KI kann „Dame" außerhalb ihres Zugs rufen | `src/lib/aiPlayer.ts` |
| 2.8 | `createAIPlayer` liefert kein `isHuman` | `src/lib/aiPlayer.ts` |
| 2.9 | `handleCallDame` validiert `canCallDame` nicht | `src/hooks/useGameEngine.ts` |

## Phase 3: Engine-State & Race Conditions

**Ziel:** Immutability und korrekte Ref-Synchronisation.

| # | Bug | Dateien |
|---|---|---|
| 3.1 | `gameStateRef` stale nach Rundenende | `src/hooks/useGameEngine.ts` |
| 3.2 | Human input nicht gegen AI turns geschützt | `src/hooks/useGameEngine.ts` |
| 3.3 | Timer läuft während Turn Overlay | `src/hooks/useGameEngine.ts` |
| 3.4 | `handleTimerExpired` mutiert State | `src/hooks/useGameEngine.ts` |
| 3.5 | `handleUseTen` mutiert State | `src/hooks/useGameEngine.ts`, `src/lib/gameLogic.ts` |
| 3.6 | Turn overlay kann bei Game-Over öffnen | `src/hooks/useGameEngine.ts` |
| 3.7 | `loadSavedGame` kann Overlay für AI öffnen | `src/hooks/useGameEngine.ts` |
| 3.8 | Power-Handler ignorieren `gameConfig.powerEffects` | `src/hooks/useGameEngine.ts` |
| 3.9 | `aiTimeoutsRef` leaked Timeout-IDs | `src/hooks/useGameEngine.ts` |
| 3.10 | Auto-save auf jeder Message-Änderung | `src/hooks/useGameEngine.ts` |

## Phase 4: UI/UX & i18n

**Ziel:** Bedienbar, konsistent, übersetzt.

| # | Bug | Dateien |
|---|---|---|
| 4.1 | `PlayerTurnOverlay` fehlende ARIA-Semantik | `src/components/PlayerTurnOverlay.tsx` |
| 4.2 | Hauptmenü-Name-Input ohne Label | `src/App.tsx` |
| 4.3 | AI-Difficulty-Buttons ohne `aria-pressed` | `src/App.tsx` |
| 4.4 | „End Turn" nicht disabled bei `mustTakeQueen` | `src/components/GameBoard.tsx` |
| 4.5 | `App.tsx` mutiert Spieler-Objekte direkt | `src/App.tsx` |
| 4.6 | Tutorial nutzt `dangerouslySetInnerHTML` | `src/components/GameBoard.tsx` |
| 4.7 | Hardcoded Default-Namen (Deutsch) | `src/App.tsx`, `src/components/HotSeatSetup.tsx` |
| 4.8 | Hardcoded Sprach-Labels | `src/App.tsx` |
| 4.9 | Hardcoded Timer-Suffix | `src/components/GameBoard.tsx` |
| 4.10 | Kartensuit-Namen in ARIA immer Englisch | `src/components/Card.tsx` |
| 4.11 | Hot-Seat Peek läuft, während Timer läuft | `src/components/GameBoard.tsx`, `src/hooks/useGameEngine.ts` |
| 4.12 | `PlayerTurnOverlay` Theme inkonsistent | `src/components/PlayerTurnOverlay.tsx` |

## Phase 5: Tests & Build

**Ziel:** Schneller, stabiler, besser abgedeckt.

| # | Bug | Dateien |
|---|---|---|
| 5.1 | `vitest.config.ts` nicht im TS-Projekt | `tsconfig.node.json` |
| 5.2 | Wahrscheinlichkeitsbasierte KI-Tests | `src/lib/aiPlayer.test.ts` |
| 5.3 | Veraltete `userEvent` API im Overlay-Test | `src/components/PlayerTurnOverlay.test.tsx` |
| 5.4 | jsdom-Mocks zentralisieren | `src/test/setup.ts`, `src/components/HotSeatSetup.test.tsx` |
| 5.5 | Eigenbau-`renderHook` durch Testing Library ersetzen | `src/hooks/useGameEngine.test.ts` |
| 5.6 | Nicht-deterministischer Shuffle-Test | `src/lib/gameLogic.test.ts` |
| 5.7 | Coverage-Konfiguration fehlt | `vitest.config.ts`, `package.json` |
| 5.8 | `GameBoard`-Testabdeckung erweitern | `src/components/GameBoard.test.tsx` |

## Phase 6: Skins, Sounds & Shop

**Ziel:** Robuste Asset-Handling und konsistente Wirtschaft.

| # | Bug | Dateien |
|---|---|---|
| 6.1 | `menu.mp3` fehlt | `public/sounds/music/`, `src/App.tsx` |
| 6.2 | Skin-Inventar validiert nicht gegen Registry | `src/lib/skins/inventoryService.ts` |
| 6.3 | Kein Fallback auf Default-Skin | `src/hooks/useSkins.ts`, `src/components/Card.tsx`, `src/components/GameBoard.tsx` |
| 6.4 | Shop-Kauf erzwingt keine Zahlung | `src/lib/skins/inventoryService.ts`, `src/components/SkinShop.tsx` |
| 6.5 | Bild-Fallbacks in Shop/Selector | `src/components/SkinShop.tsx`, `src/components/SkinSelector.tsx` |
| 6.6 | Race Condition in `stopBackgroundMusic` | `src/lib/sounds.ts` |
| 6.7 | `AudioContext` nie geschlossen | `src/lib/sounds.ts` |
| 6.8 | `AGENTS.md` widerspricht `vite.config.ts` bei `base` | `AGENTS.md` |

---

## Abhängigkeiten zwischen Phasen

- Phase 1 muss zuerst.
- Phase 2 und 3 können parallel beginnen, sobald Phase 1 abgeschlossen ist.
- Phase 4 hängt von Phase 3 ab (Timer/Overlay).
- Phase 5 kann jederzeit parallel laufen.
- Phase 6 hängt von Phase 1 (Asset-Pfade) ab.

## Abschlusskriterium

- `pnpm test -- --run` ≥ 95 Tests passing (mehr nach neuen Tests)
- `pnpm lint` clean
- `pnpm build` erfolgreich
- Keine kritischen/wichtigen Bugs aus dem Audit offen
