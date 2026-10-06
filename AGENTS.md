# AGENTS.md — Dame Kartenspiel

Diese Datei dokumentiert die Architektur, den Technologie-Stack und die Entwicklungskonventionen des Projekts für AI-Coding-Agenten.

---

## Hauptprojekt: Godot-Client (`godot/`)

Seit 2026-10-04 ist der Godot-Client das Hauptprojekt. Die React-App unten bleibt als Nachschlagewerk. Für Godot-Arbeit den Skill `dame-godot` laden.

- Engine: Godot 4.7.2, GL Compatibility, Hauptszene `res://scenes/main_menu.tscn`
- Regeln: `godot/scripts/dame_rules.gd` + `CONCEPT_DECISIONS.md` (verbindlich)
- Tests: `npm run test:godot` (Headless-Suites + echter Szenenfluss)
- Export: `npm run export:godot` → `build/windows/Dame.exe`, `build/web/`
- Web-Smoke: `npm run test:godot:web`
- Godot-Pfad lokal per `GODOT_BIN` überschreibbar
- Bauplan und Stand: `docs/superpowers/plans/2026-10-04-dame-godot-bauplan.md`

---

## Projektübersicht

**Dame Kartenspiel** ist eine browserbasierte Implementierung des deutschen Kartenspiels „Dame" (nicht zu verwechseln mit Dame/Checkers). Es handelt sich um ein strategisches Kartenspiel mit Bluff-Elementen für 2–6 Spieler, bei dem menschliche Spieler gegen KI-Gegner oder andere Menschen antreten können.

Das Spiel wird als statische Single-Page-Application (SPA) ausgeliefert. Es gibt kein Backend — die gesamte Spiellogik läuft client-seitig im Browser.

### Kernregeln (kurz)

- Jeder Spieler erhält 4 verdeckte Karten und darf sich nur 2 davon ansehen.
- Ziel: Möglichst wenige Punkte sammeln. Wer über 50 Punkte kommt, scheidet aus.
- Genau 50 Punkte → Reset auf 0.
- **Bube** (10 Pkt.): Beim Ablegen darf man sich eine eigene verdeckte Karte anschauen.
- **König** (10 Pkt.): Beim Ablegen tauscht man blind eine Karte mit einem Gegner.
- **Dame** (0 Pkt.): Beim Ablegen zieht man eine Strafkarte.
- **Dame Call**: Ab Runde 3 kann ein Spieler „Dame" rufen, wenn er glaubt, die wenigsten Punkte zu haben. Nach einer letzten Runde werden alle Karten aufgedeckt.

---

## Technologie-Stack

| Ebene | Technologie | Version |
|-------|-------------|---------|
| Framework | React | ^19.2.0 |
| Sprache | TypeScript | ~5.9.3 |
| Build-Tool | Vite | ^7.2.4 |
| Styling | Tailwind CSS | ^3.4.19 |
| UI-Komponenten | shadcn/ui (New-York-Style) | — |
| Icons | Lucide React | ^0.562.0 |
| Linting | ESLint + typescript-eslint | ^9.39.1 |

### Wichtige Abhängigkeiten

- **shadcn/ui** — Es wurden sehr viele Komponenten installiert (`src/components/ui/` enthält 40+ Komponenten wie Dialog, Button, Card, Form, Carousel etc.). Neue UI-Komponenten sollten über `npx shadcn add <komponente>` hinzugefügt werden.
- **Radix UI Primitives** — Unterliegende Headless-Komponenten für Accessibility und Verhalten.
- **tailwindcss-animate** — Animationen für Tailwind.
- **class-variance-authority + clsx + tailwind-merge** — Utility für variantenbasierte Styling (`cn`-Helper in `src/lib/utils.ts`).
- **zod + react-hook-form + @hookform/resolvers** — Formularvalidierung (vorbereitet, aktuell nicht aktiv im Spiel).
- **recharts** — Diagramme (vorbereitet, aktuell nicht aktiv).

---

## Build- und Entwicklungsbefehle

Alle Befehle werden über `npm` (oder `pnpm`/`yarn`) ausgeführt:

```bash
# Entwicklungsserver starten
npm run dev

# Produktionsbuild (TypeScript-Check + Vite-Build)
npm run build

# ESLint ausführen
npm run lint

# Tests einmalig ausführen
pnpm test -- --run

# Produktionsbuild lokal previewen
npm run preview
```

### Build-Ausgabe

- Vite baut nach `dist/`.
- `base: './'` ist in `vite.config.ts` gesetzt → relative Pfade für einfache statische Bereitstellung.
- Es wird ein reiner Static-Site-Export erzeugt (kein SSR).

---

## Projektstruktur

```
src/
├── types/
│   └── game.ts              # Alle TypeScript-Typen, Enums, Konstanten
├── lib/
│   ├── utils.ts             # Tailwind-Utility (cn-Funktion)
│   ├── gameLogic.ts         # Reine Spiellogik (Zustandsfunktionen, keine React-Abhängigkeit)
│   └── aiPlayer.ts          # KI-Logik mit 3 Schwierigkeitsgraden
├── hooks/
│   ├── useGameEngine.ts     # Zentraler React-Hook für Spielzustand, KI und Timer
│   ├── useGameStats.ts      # Persistente Rundenspielstatistiken
│   ├── useSettings.ts       # Spiel-Einstellungen (Timer, Sound, KI-Geschwindigkeit)
│   ├── useSkins.ts          # Aktivierte und gekaufte Skins
│   └── use-mobile.ts        # Mobile-Breakpoint-Erkennung (768px)
├── components/
│   ├── ui/                  # shadcn/ui-Komponenten (40+ Dateien)
│   ├── Card.tsx             # Kartendarstellung (Front/Rückseite, Stapel)
│   ├── PlayerHand.tsx       # Hand eines Spielers mit Sichtbarkeitslogik
│   └── GameBoard.tsx        # Hauptspielbrett mit UI-Interaktionen
├── App.tsx                  # Hauptkomponente: Menü, Regeln, Spiel-Router
├── main.tsx                 # Entry-Point (React 19 StrictMode)
├── index.css                # Tailwind-Direktiven + CSS-Variablen (Light/Dark)
└── App.css                  # Minimal, kaum genutzt
```

### Architektur-Muster

1. **Trennung von Logik und UI**
   - `gameLogic.ts` ist vollständig frei von React. Alle Funktionen nehmen einen `GameState` entgegen und geben einen neuen unveränderlichen Zustand zurück.
   - `aiPlayer.ts` ist ebenfalls rein funktional und kennt React nicht.
   - `useGameEngine.ts` kapselt den React-Zustand und ruft die puren Logik-Funktionen auf.

2. **KI-Automatisierung**
   - `useGameEngine` verwendet `useEffect`, um zu erkennen, wenn ein KI-Spieler am Zug ist.
   - KI-Züge werden über `setTimeout` mit Verzögerung ausgeführt (easy: 1.5s, medium: 1s, hard: 0.8s), um menschliches Verhalten zu simulieren.
   - `useRef`-Hooks (`gameStateRef`, `drawnCardRef`) halten den aktuellen Zustand für Timeout-Callbacks verfügbar.

3. **shadcn/ui-Konventionen**
   - Komponenten liegen unter `src/components/ui/`.
   - Alias `@/components/ui` wird für Imports verwendet.
   - Styling erfolgt ausschließlich über Tailwind-Utility-Klassen.

---

## Konventionen und Code-Stil

### Sprache

- **Code-Kommentare**: Deutsch.
- **UI-Texte**: Deutsch.
- **Variablen-/Funktionsnamen**: Englisch (camelCase für Variablen/Funktionen, PascalCase für Komponenten/Typen).
- **AGENTS.md**: Deutsch (da dies die Hauptsprache des Projekts ist).

### TypeScript-Konfiguration

- **Strict Mode** aktiviert (`strict: true` in `tsconfig.app.json`).
- `noUnusedLocals: true` und `noUnusedParameters: true` — ungenutzte Variablen/Parameter führen zu Build-Fehlern.
- `verbatimModuleSyntax: true` — Imports müssen explizit `type` verwenden für reine Typ-Imports.
- Path-Mapping: `@/*` zeigt auf `./src/*`.

### Tailwind / Styling

- Design-System basiert auf CSS-Variablen (`--background`, `--primary`, `--border` etc.), definiert in `src/index.css`.
- Dark-Mode wird über die Klasse `.dark` gesteuert (`darkMode: ["class"]` in Tailwind-Config).
- Der Utility-Helper `cn(...)` aus `src/lib/utils.ts` kombiniert `clsx` und `tailwind-merge` für saubere Klassen-Zusammenführung.
- Das Spielbrett verwendet einen grünen Farbverlauf (`from-green-800 to-green-900`), um einen Spieltisch-Look zu erzeugen.

---

## Testing

Das Projekt verwendet **Vitest** für Unit- und Komponententests. Die Tests liegen neben den Quelldateien (z. B. `src/lib/gameLogic.test.ts`, `src/lib/aiPlayer.test.ts`, `src/hooks/useGameEngine.test.ts`, `src/components/GameBoard.test.tsx`).

### Testbefehle

```bash
# Alle Tests einmalig ausführen
pnpm test -- --run

# Tests im Watch-Modus
pnpm test

# Tests mit UI
pnpm run test:ui
```

Aktuell gibt es ca. 95 Tests, die vor allem folgende Bereiche abdecken:

- **Spiellogik** (`gameLogic.test.ts`) – Initialisierung, Ziehen, Tauschen, Effekte, Punkteberechnung, Dame-Call.
- **KI** (`aiPlayer.test.ts`) – Entscheidungen für alle Schwierigkeitsgrade.
- **Spiel-Engine** (`useGameEngine.test.ts`) – Hook-Verhalten, KI-Züge, Speichern/Laden.
- **UI-Komponenten** (`GameBoard.test.tsx`, `PlayerTurnOverlay.test.tsx`, `HotSeatSetup.test.tsx`).
- **Skin-System** (`src/lib/skins/*.test.ts`).

Die puren Funktionen in `gameLogic.ts` bleiben ideal für Unit-Tests, da sie keinen React-Zustand oder DOM benötigen.

---

## KI-Gegner

Die KI ist in `src/lib/aiPlayer.ts` implementiert und bietet drei Schwierigkeitsgrade:

| Schwierigkeit | Verhalten |
|---------------|-----------|
| **Einfach** | Zufällige Entscheidungen beim Ziehen und Tauschen. Ruft nie „Dame". |
| **Mittel** | Bevorzugt gute Karten vom Ablagestapel. Nutzt Bube-/König-Effekte. Ruft „Dame" bei geschätztem Score < 15. |
| **Schwer** | Fortgeschrittene Strategie mit Risikobewertung. Tauscht gezielt mit führenden Spielern. Bluff-Elemente. Ruft „Dame" nur wenn wahrscheinlich führend. |

KI-Züge werden über die zentrale Funktion `decideAIMove(gameState, playerId, difficulty, drawnCard?)` entschieden. Jeder Schwierigkeitsgrad hat separate `makeXxxMove` und `makeXxxPostDrawMove` Funktionen.

---

## Deployment

GitHub Pages zeigt **nur den Godot-Web-Build**: https://deusexlumen.github.io/Dame-Card-Game/

1. `.github/workflows/deploy.yml` läuft bei jedem Push auf `main`: Godot 4.7.2 + Templates, Headless-Tests, Export, Web-Smoke, Pages-Deploy.
2. Web-Preset ist ohne Threads, daher keine COOP/COEP-Header nötig.
3. Die React-App wird nicht mehr veröffentlicht. `npm run build` baut sie weiterhin lokal nach `dist/`.

**Kein Server-Side-Rendering, keine API, keine Datenbank.**

---

## Sicherheits- und Qualitätsaspekte

- **Keine sensiblen Daten** — Das Spiel speichert keine Benutzerdaten, hat keine Authentifizierung und kommuniziert nicht mit externen APIs.
- **Keine Umgebungsvariablen** — Es gibt keine `.env`-Dateien oder Geheimnisse im Repository (außer der `.gitignore` Ausschluss).
- **ESLint** — Konfiguriert mit empfohlenen Regeln für TypeScript, React Hooks und React Refresh. `dist/` wird ignoriert.
- **StrictMode** — Aktiviert in `main.tsx` (React 19).

---

## Hinweise für Agenten

- **Neue Features** am besten durch Hinzufügen reiner Funktionen in `gameLogic.ts` oder `aiPlayer.ts`, gefolgt von Hook-Updates in `useGameEngine.ts`.
- **UI-Änderungen** sollten bestehende shadcn/ui-Komponenten aus `src/components/ui/` verwenden, bevor neue Komponenten erstellt werden.
- **Deutsche Sprache beibehalten** — Alle nutzerseitigen Texte und Kommentare sollten auf Deutsch verfasst werden.
- **Keine allgemeinen Annahmen über shadcn/ui** — Die vorhandenen Komponenten sind konkret installiert und können direkt importiert werden (`@/components/ui/button`).
