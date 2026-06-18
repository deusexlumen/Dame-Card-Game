# Dame MVP Production-Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Implement task-by-task, run `pnpm lint`, `pnpm vitest run`, `pnpm build` after each major file group.

**Goal:** Das Dame-Card-Game wird production-ready: Konzept-Regeln, Terminal-Visual-Design, lint-freier Build, robustes Save/Load, Accessibility, Tests und README.

**Architecture:** React-Hooks + pure Logikfunktionen bleiben erhalten. Neue Regeln landen in `src/lib/gameLogic.ts`/`aiPlayer.ts`. Das Terminal-Design wird in `Card.tsx`/`PlayerHand.tsx`/`GameBoard.tsx`/`index.css`/`App.tsx` umgesetzt. Tooling-Fixes (ESLint, Vite, Hooks) erfolgen in Configs und State-Hooks.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS 3.4, shadcn/ui, Framer Motion, Vitest, ESLint 9.

---

## Task 1: Core Rules & Logic Alignment

**Files:**
- Modify: `src/types/game.ts`
- Modify: `src/lib/gameLogic.ts`
- Modify: `src/lib/aiPlayer.ts`
- Modify/Test: `src/lib/gameLogic.test.ts`, `src/lib/aiPlayer.test.ts`

**Deliverables:**
- [ ] Bube-Effekt erlaubt das Anschauen einer beliebigen verdeckten Karte (eigene oder gegnerische). `applyJackEffect` akzeptiert `targetPlayerId` und `handIndex`. Für gegnerische Karten wird der Wert im `GameState` sichtbar gemacht (z. B. temporär für den anschauenden Spieler; MVP: `visibleCardIndices` des Ziel-Spielers wird kurz erweitert, da im physischen Spiel der Spieler sich den Wert merken muss).
- [ ] König-Effekt zeigt die gewählte gegnerische Karte kurz an, bevor getauscht wird. `applyKingEffect` behält Signatur, UI in GameBoard zeigt sie vor dem Tausch an.
- [ ] Dame-Call-Strafe: `endRound` markiert einen falschen Caller mit `penaltyCards`. `startNextRound` gibt dem falschen Caller 5 statt 4 Karten aus (Strafkarte + neues Deck) und leert danach `penaltyCards`.
- [ ] Flakiger Test `bestraft falsches Ablegen mit Strafkarte` repariert: sicherstellen, dass die "falsche" Karte wirklich nicht zum Ablagestapel passt.
- [ ] Neue Tests für Bube/König/Dame-Call-Strafe.

**Verification:** `pnpm vitest run` grün.

---

## Task 2: Terminal / Cybernetic-Archive Visual Redesign

**Files:**
- Modify: `src/components/Card.tsx`
- Modify: `src/components/PlayerHand.tsx`
- Modify: `src/index.css`
- Modify: `src/App.tsx`
- Modify: `src/components/GameBoard.tsx` (nur visuelle Klassen, keine Logik)

**Deliverables:**
- [ ] Kartenrücken: dunkler Hintergrund, Gitter/Circuit-Muster, grüner Glow-Rahmen, kein klassisches Pik-Symbol.
- [ ] Kartenfront: schwarzes/dunkelgrünes Terminal-Panel, Monospace-Schrift für Rank und Wert, geometrisches Farbsymbol (Herz/Diamond/Club/Spade als stilisierte Form), subtile Scanline/CRT-Effekt.
- [ ] `SUIT_COLORS`/`SUIT_SYMBOLS` in `src/types/game.ts` anpassen (Task 1 Agent darf bereits Farben vorbereiten; hier finalisieren).
- [ ] Spieltisch: schwarzer Hintergrund mit feinem Terminal-Grid statt Filz-Textur.
- [ ] Menü (`App.tsx`) auf Terminal-Look umstellen: Monospace-Logo, grüne Akzente, deaktivierten Statistik-Button entfernen.
- [ ] Debug-Button `Alle anzeigen` in `PlayerHand.tsx` entfernen.

**Verification:** Visuell via `pnpm dev` oder Snapshot; Build ohne Fehler.

---

## Task 3: GameBoard Interactions & Accessibility

**Files:**
- Modify: `src/components/GameBoard.tsx`

**Deliverables:**
- [ ] Bube-Dialog: Zeigt eigene Hand und alle Gegner-Hands; nur verdeckte Karten sind klickbar. Nach Auswahl wird die Karte aufgedeckt angezeigt und der Effekt ausgeführt.
- [ ] König-Dialog: Zielspieler wählen -> Zielkarte wählen -> Karte kurz aufdecken -> eigene Karte wählen -> Tausch bestätigen. Abbrechen-Button erlaubt.
- [ ] Dame-Call-Toast/Text aktualisieren (Strafe in nächster Runde).
- [ ] Keyboard-Shortcuts erweitern/aktualisieren (z. B. Escape schließt Dialoge).
- [ ] Accessibility: `aria-label` auf allen Icon-Buttons, `role="status"`/`aria-live="polite"` für Spielstatus, Fokus-Trap in Dialogen via shadcn-Dialog (bereits vorhanden, prüfen).

**Verification:** Manuelle Smoke-Tests; Build grün.

---

## Task 4: Production Quality & Tooling

**Files:**
- Modify: `src/hooks/useGameWithAI.ts`
- Modify: `src/hooks/useSettings.ts`
- Modify: `src/hooks/use-mobile.ts`
- Modify: `src/lib/settings.ts`
- Modify: `eslint.config.js`
- Modify: `vite.config.ts`
- Modify: `package.json` (ggf. devDependency-Markierung)

**Deliverables:**
- [ ] `useGameWithAI.ts`: Funktionen nicht vor Deklaration nutzen (Reihenfolge umstellen oder `useReducer` einführen). `setHasSavedGame` aus dem Auto-Save-Effect entfernen (ableiten statt setState im Effect).
- [ ] `use-mobile.ts`: `setIsMobile` nicht synchron im Effect-Body aufrufen; Initialisierung über `useState`-Initializer.
- [ ] Save/Load validiert Savegame mit einem Schema (Zod oder Type-Guard) und löscht/liefert `null` bei Fehler.
- [ ] `vite.config.ts`: `kimi-plugin-inspect-react` nur in `mode !== 'production'` laden.
- [ ] `eslint.config.js`: shadcn/ui-Generatoren (`src/components/ui/**`) von `react-refresh/only-export-components`, `react-hooks/set-state-in-effect` und `react-hooks/purity` ausnehmen, da sie generierten Code enthalten. Eigene Code-Fehler bleiben sichtbar.
- [ ] `any`-Typen in `aiPlayer.ts`/`tests` ersetzen (spezifische Payload-Typen).

**Verification:** `pnpm lint` grün, `pnpm build` grün, `pnpm vitest run` grün.

---

## Task 5: README & Final Verification

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md` (optional, kurz)

**Deliverables:**
- [ ] README aktualisiert: Ziel, Regeln (inkl. Bube/König/Dame-Call-Strafe), Tech-Stack, Projektstruktur, Tastenkürzel, Installation, Build, Deployment-Hinweis.
- [ ] Finale Verifikation: `pnpm lint && pnpm vitest run && pnpm build`.

---

## Self-Review / Spec Coverage

- Bube/König/Dame-Call-Strafe -> Task 1 + 3
- Terminal-Design -> Task 2
- Lint/Build/Debug/Save-Load -> Task 4
- Tests/README -> Task 1 + 5
