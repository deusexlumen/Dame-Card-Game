# AGENTS.md — Dame Kartenspiel

Diese Datei dokumentiert die Architektur, den Technologie-Stack und die Entwicklungskonventionen des Projekts für AI-Coding-Agenten.

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
│   ├── useGame.ts           # React-Hook für Spielzustand (menschenonly)
│   ├── useGameWithAI.ts     # Erweiterter Hook mit automatischer KI-Zugausführung
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
   - `useGame.ts` / `useGameWithAI.ts` kapseln den React-Zustand und rufen die puren Logik-Funktionen auf.

2. **KI-Automatisierung**
   - `useGameWithAI` verwendet `useEffect`, um zu erkennen, wenn ein KI-Spieler am Zug ist.
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

**Aktuell gibt es keine Tests im Projekt.** Es ist kein Test-Framework installiert (kein Jest, Vitest, Playwright o.ä.).

Wenn Tests hinzugefügt werden sollen:

- **Empfohlen**: Vitest (passt nativ zu Vite) für Unit-Tests der Spiellogik in `gameLogic.ts` und `aiPlayer.ts`.
- **Optional**: Playwright oder Cypress für E2E-Tests der Spiel-UI.

Die puren Funktionen in `gameLogic.ts` sind ideal für Unit-Tests, da sie keinen React-Zustand oder DOM benötigen.

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

Das Projekt ist für statisches Hosting vorkonfiguriert:

1. `npm run build` erzeugt den `dist/`-Ordner.
2. `dist/` kann direkt auf einem Static-Hosting-Dienst (Netlify, Vercel, GitHub Pages, Cloudflare Pages) bereitgestellt werden.
3. Die `base: './'`-Konfiguration in `vite.config.ts` stellt sicher, dass Assets mit relativen Pfaden referenziert werden.

**Kein Server-Side-Rendering, keine API, keine Datenbank.**

---

## Sicherheits- und Qualitätsaspekte

- **Keine sensiblen Daten** — Das Spiel speichert keine Benutzerdaten, hat keine Authentifizierung und kommuniziert nicht mit externen APIs.
- **Keine Umgebungsvariablen** — Es gibt keine `.env`-Dateien oder Geheimnisse im Repository (außer der `.gitignore` Ausschluss).
- **ESLint** — Konfiguriert mit empfohlenen Regeln für TypeScript, React Hooks und React Refresh. `dist/` wird ignoriert.
- **StrictMode** — Aktiviert in `main.tsx` (React 19).

---

## Hinweise für Agenten

- **Neue Features** am besten durch Hinzufügen reiner Funktionen in `gameLogic.ts` oder `aiPlayer.ts`, gefolgt von Hook-Updates in `useGameWithAI.ts`.
- **UI-Änderungen** sollten bestehende shadcn/ui-Komponenten aus `src/components/ui/` verwenden, bevor neue Komponenten erstellt werden.
- **Deutsche Sprache beibehalten** — Alle nutzerseitigen Texte und Kommentare sollten auf Deutsch verfasst werden.
- **Keine allgemeinen Annahmen über shadcn/ui** — Die vorhandenen Komponenten sind konkret installiert und können direkt importiert werden (`@/components/ui/button`).
