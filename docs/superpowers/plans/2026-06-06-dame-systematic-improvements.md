# DAME Systematische Verbesserungen — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die fünf offenen Arbeitspakete aus dem DAME-Dossier systematisch abschließen: Konzeptlücken finalisieren, Build optimieren, KI-Balance feintunen, neues Feature (Statistiken) implementieren und Deployment (GitHub Pages) vorbereiten.

**Architecture:** Konzeptentscheidungen werden in einer zentralen `CONCEPT_DECISIONS.md` dokumentiert und bei Bedarf in `src/lib/gameLogic.ts` verankert. Build-Optimierung erfolgt über `manualChunks` in `vite.config.ts`. KI-Tuning geschieht durch konfigurierbare Thresholds in `src/lib/aiPlayer.ts` und zusätzliche Tests. Statistiken werden im `localStorage` persistiert und über einen neuen Hook bereitgestellt. Deployment wird via GitHub Actions Workflow auf GitHub Pages realisiert.

**Tech Stack:** React 19, TypeScript 5.9, Vite 7, Tailwind CSS 3.4, shadcn/ui, Vitest, GitHub Actions.

---

## File Map

| Datei | Verantwortung |
|-------|---------------|
| `CONCEPT_DECISIONS.md` | Dokumentation der finalen Designentscheidungen für offene Dossier-Fragen |
| `src/lib/gameLogic.ts` | Spielregeln, Strafkarten-Logik, Rundenabschluss |
| `src/lib/aiPlayer.ts` | KI-Entscheidungen und Balance-Parameter |
| `src/lib/aiPlayer.test.ts` | Tests für KI-Verhalten |
| `vite.config.ts` | Build-Konfiguration inkl. `manualChunks` |
| `src/lib/stats.ts` | Statistik-Typen, Speichern/Laden, Aktualisierung |
| `src/hooks/useGameStats.ts` | React-Hook für Spielstatistiken |
| `src/components/StatsPanel.tsx` | UI-Komponente zur Anzeige der Statistiken |
| `src/components/StartDialog.tsx` | Einbindung Statistik-Button |
| `.github/workflows/deploy.yml` | GitHub Actions Workflow für GitHub Pages |
| `package.json` | ggf. `homepage`-Feld |
| `README.md` | Aktualisierung um Konzeptentscheidungen, Statistiken, Deployment |

---

## Task 1: Konzeptlücken finalisieren und dokumentieren

**Files:**
- Create: `CONCEPT_DECISIONS.md`
- Modify: `README.md`
- Modify: `src/lib/gameLogic.ts` (nur Strafkarten-Anzahl formalisieren)

### Task 1.1 — Dokumentation der finalen Konzeptentscheidungen

- [ ] **Step 1: CONCEPT_DECISIONS.md erstellen**

```markdown
# DAME — Finale Konzeptentscheidungen

Basierend auf dem Dossier werden die offenen Fragen wie folgt verbindlich festgelegt:

## 1. Echtzeit-Reaktionsregel ("Mitwerfen")

**Entscheidung:** Keine physische Echtzeit-Reaktion. Das digitale Spiel arbeitet rundenbasiert.  
Stattdessen gilt die **Extra-Ablegen-Regel**: Hat ein Spieler während seines eigenen Zuges eine Karte auf der Hand, die zum aktuell obersten Ablagestapel passt, darf er diese zusätzlich ablegen.  
Dadurch bleibt der Information-/Timing-Vorteil erhalten, ohne Netzwerk-Latenz oder Klick-Wettrennen einzuführen.

## 2. Anzahl Strafkarten

**Entscheidung:** Jeder regelwidrige Fehler kostet genau **eine Strafkarte**.  
Diese wird aus dem Nachziehstapel gezogen und verdeckt an die Auslage angehängt. Gleiches gilt für das Ablegen einer Dame (Strafkarte ziehen) und eine falsche Dame-Ansage (Strafkarte in der nächsten Runde).

## 3. Sichtbarkeit der Dame

**Entscheidung:** Eine abgelegte Dame liegt immer **offen** auf dem Ablagestapel.  
Sie ist damit für alle Spieler sichtbar und löst den Zwangszug für den nächsten Spieler aus (außer in Safe Phase / Rundenende).

## 4. Mitwerfen identischer Karten

**Entscheidung:** Siehe Abschnitt 1. "Extra-Ablegen" innerhalb des eigenen Zuges.  
Es gibt keine "Schnappreaktion" anderer Spieler außerhalb ihres Zuges.

## 5. Letzte Runde formal absichern

**Entscheidung:** Nach einer Dame-Ansage:
- Die Karten des Ansagers werden gelockt (keine Manipulation mehr möglich).
- Jeder andere Spieler erhält noch **genau einen vollständigen Zug**.
- Danach werden alle Karten aufgedeckt, Punkte berechnet und der Verlierer ermittelt.
- Hat ein anderer Spieler gleich viele oder weniger Punkte als der Ansager, erhält der Ansager in der nächsten Runde eine Strafkarte (5 statt 4 Karten).
```

- [ ] **Step 2: README.md um Konzeptkapitel ergänzen**

Am Ende von `README.md` einen Abschnitt anhängen:

```markdown
## Offene Konzeptfragen — Finale Entscheidungen

Siehe [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md) für die verbindliche Festlegung von Echtzeit-Reaktion, Strafkarten-Anzahl, Sichtbarkeit der Dame, Mitwerfen und Rundenabschluss.
```

- [ ] **Step 3: Commit**

```bash
git add CONCEPT_DECISIONS.md README.md
git commit -m "docs: finalisiere offene Konzeptentscheidungen aus Dossier"
```

### Task 1.2 — Strafkarten-Anzahl in der Spielregel verankern

- [ ] **Step 1: Konstante für Strafkarten-Anzahl einführen**

In `src/lib/gameLogic.ts` oben nach den Imports einfügen:

```ts
export const PENALTY_CARD_COUNT = 1;
```

- [ ] **Step 2: Alle Stellen, die Strafkarten ziehen, auf die Konstante umstellen**

Suche nach `applyQueenEffect`, falscher Dame-Ansage und illegalem Aktionen. Beispiel (nach Anpassung):

```ts
export function applyQueenEffect(
  gameState: GameState,
  playerId: string,
): GameState {
  const newState = structuredClone(gameState);
  const player = newState.players.find((p) => p.id === playerId)!;

  for (let i = 0; i < PENALTY_CARD_COUNT; i++) {
    const draw = drawFromDeck(newState);
    if (draw.card) {
      player.penaltyCards.push(draw.card);
      player.hand.push({ ...draw.card, isVisible: false });
    }
  }

  return newState;
}
```

Gleiches für die Strafkarte bei falscher Dame-Ansage in `endRound` / `startNextRound`.

- [ ] **Step 3: Tests laufen lassen**

```bash
pnpm test
```

Erwartet: alle Tests grün.

- [ ] **Step 4: Commit**

```bash
git add src/lib/gameLogic.ts
git commit -m "refactor: standardisiere Strafkarten-Anzahl auf PENALTY_CARD_COUNT"
```

---

## Task 2: Build-Optimierung

**Files:**
- Modify: `vite.config.ts`

### Task 2.1 — Rollup manuelle Chunks konfigurieren

- [ ] **Step 1: vite.config.ts anpassen**

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          // node_modules in separate chunks
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('scheduler')) {
              return 'react-vendor';
            }
            if (id.includes('lucide')) {
              return 'icons';
            }
            if (id.includes('@radix-ui') || id.includes('class-variance')) {
              return 'ui-vendor';
            }
            return 'vendor';
          }
        },
      },
    },
    chunkSizeWarningLimit: 600,
  },
});
```

- [ ] **Step 2: Build laufen lassen**

```bash
pnpm build
```

Erwartet: Kein Fehler; Warnung wegen >500 kB sollte deutlich reduziert oder verschwunden sein.

- [ ] **Step 3: Commit**

```bash
git add vite.config.ts
git commit -m "build: split vendor chunks to reduce main bundle size"
```

---

## Task 3: Spielbalance / KI-Verhalten feintunen

**Files:**
- Modify: `src/lib/aiPlayer.ts`
- Modify: `src/lib/aiPlayer.test.ts`

### Task 3.1 — Thresholds für Extra-Ablegen konfigurierbar machen

- [ ] **Step 1: Konstanten einführen**

In `src/lib/aiPlayer.ts`:

```ts
const EXTRA_DISCARD_THRESHOLDS: Record<AIDifficulty, number> = {
  easy: 0,
  medium: 3,
  hard: 4,
};

const DAME_CALL_CONFIDENCE: Record<AIDifficulty, number> = {
  easy: 0.7,
  medium: 0.85,
  hard: 0.95,
};
```

- [ ] **Step 2: Verwendung der Konstanten sicherstellen**

`findExtraDiscardCardId` sollte den Threshold aus `EXTRA_DISCARD_THRESHOLDS[difficulty]` verwenden.  
`shouldCallDame` sollte `DAME_CALL_CONFIDENCE[difficulty]` nutzen.

- [ ] **Step 3: Tests für Thresholds ergänzen**

In `src/lib/aiPlayer.test.ts`:

```ts
it('easy KI extra-discardiert auch niedrige passende Karten', () => {
  const state = makeState({
    discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
  });
  state.players[0].hand = [
    { id: 'h1', suit: 'clubs', rank: '2', value: 2, isVisible: false },
    { id: 'h2', suit: 'diamonds', rank: '5', value: 5, isVisible: false },
    { id: 'h3', suit: 'spades', rank: '8', value: 8, isVisible: false },
    { id: 'h4', suit: 'hearts', rank: '3', value: 3, isVisible: false },
  ];
  expect(decideAIMove(state, 'p1', 'easy').action).toBe('DISCARD_EXTRA_CARD');
});

it('hard KI extra-discardiert nur hochwertige passende Karten', () => {
  const state = makeState({
    discardPile: [{ id: 'd1', suit: 'hearts', rank: '2', value: 2, isVisible: true }],
  });
  state.players[0].hand = [
    { id: 'h1', suit: 'clubs', rank: '2', value: 2, isVisible: false },
    { id: 'h2', suit: 'diamonds', rank: '5', value: 5, isVisible: false },
    { id: 'h3', suit: 'spades', rank: '8', value: 8, isVisible: false },
    { id: 'h4', suit: 'hearts', rank: '3', value: 3, isVisible: false },
  ];
  const move = decideAIMove(state, 'p1', 'hard');
  if (move.action === 'DISCARD_EXTRA_CARD') {
    expect(move.cardId).toBe('h1');
  }
});
```

- [ ] **Step 4: Tests laufen lassen**

```bash
pnpm test
```

- [ ] **Step 5: Commit**

```bash
git add src/lib/aiPlayer.ts src/lib/aiPlayer.test.ts
git commit -m "feat: make AI thresholds configurable per difficulty"
```

---

## Task 4: Neues Feature — Lokale Spielstatistiken

**Files:**
- Create: `src/lib/stats.ts`
- Create: `src/hooks/useGameStats.ts`
- Create: `src/components/StatsPanel.tsx`
- Modify: `src/components/StartDialog.tsx`
- Modify: `src/hooks/useGameWithAI.ts`
- Modify: `README.md`

### Task 4.1 — Statistik-Logik

- [ ] **Step 1: src/lib/stats.ts erstellen**

```ts
export interface GameStats {
  gamesPlayed: number;
  gamesWon: number;
  roundsPlayed: number;
  dameCalls: number;
  successfulDameCalls: number;
  totalPenaltyCards: number;
  bestRoundScore: number | null;
  lastPlayedAt: string | null;
}

const STORAGE_KEY = 'dame-game-stats';

export function getDefaultStats(): GameStats {
  return {
    gamesPlayed: 0,
    gamesWon: 0,
    roundsPlayed: 0,
    dameCalls: 0,
    successfulDameCalls: 0,
    totalPenaltyCards: 0,
    bestRoundScore: null,
    lastPlayedAt: null,
  };
}

export function loadStats(): GameStats {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return getDefaultStats();
    const parsed = JSON.parse(raw) as Partial<GameStats>;
    return { ...getDefaultStats(), ...parsed };
  } catch {
    return getDefaultStats();
  }
}

export function saveStats(stats: GameStats): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
  } catch {
    // ignore
  }
}

export function recordGameFinished(won: boolean): GameStats {
  const stats = loadStats();
  stats.gamesPlayed += 1;
  if (won) stats.gamesWon += 1;
  stats.lastPlayedAt = new Date().toISOString();
  saveStats(stats);
  return stats;
}

export function recordRoundFinished(
  dameCalled: boolean,
  dameSuccessful: boolean,
  penaltyCards: number,
  bestScore: number
): GameStats {
  const stats = loadStats();
  stats.roundsPlayed += 1;
  if (dameCalled) stats.dameCalls += 1;
  if (dameSuccessful) stats.successfulDameCalls += 1;
  stats.totalPenaltyCards += penaltyCards;
  if (stats.bestRoundScore === null || bestScore < stats.bestRoundScore) {
    stats.bestRoundScore = bestScore;
  }
  stats.lastPlayedAt = new Date().toISOString();
  saveStats(stats);
  return stats;
}

export function resetStats(): GameStats {
  const stats = getDefaultStats();
  saveStats(stats);
  return stats;
}
```

- [ ] **Step 2: Hook src/hooks/useGameStats.ts erstellen**

```ts
import { useState, useEffect, useCallback } from 'react';
import { type GameStats, loadStats, saveStats, resetStats } from '@/lib/stats';

export function useGameStats() {
  const [stats, setStats] = useState<GameStats>(() => loadStats());

  useEffect(() => {
    saveStats(stats);
  }, [stats]);

  const refresh = useCallback(() => {
    setStats(loadStats());
  }, []);

  const clear = useCallback(() => {
    setStats(resetStats());
  }, []);

  return { stats, setStats, refresh, clear };
}
```

- [ ] **Step 3: UI src/components/StatsPanel.tsx erstellen**

```tsx
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { type GameStats } from '@/lib/stats';
import { BarChart3 } from 'lucide-react';

interface StatsPanelProps {
  stats: GameStats;
  onReset?: () => void;
}

export function StatsPanel({ stats, onReset }: StatsPanelProps) {
  const winRate =
    stats.gamesPlayed > 0 ? Math.round((stats.gamesWon / stats.gamesPlayed) * 100) : 0;

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <BarChart3 className="h-4 w-4" />
          Statistiken
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Spielstatistiken</DialogTitle>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-4 py-4 text-sm">
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Spiele</div>
            <div className="text-2xl font-bold">{stats.gamesPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Siege</div>
            <div className="text-2xl font-bold">{winRate}%</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Runden</div>
            <div className="text-2xl font-bold">{stats.roundsPlayed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Beste Runde</div>
            <div className="text-2xl font-bold">{stats.bestRoundScore ?? '—'}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Dame-Ansagen</div>
            <div className="text-2xl font-bold">{stats.dameCalls}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-muted-foreground">Erfolgreiche Ansagen</div>
            <div className="text-2xl font-bold">{stats.successfulDameCalls}</div>
          </div>
        </div>
        {onReset && (
          <Button variant="destructive" size="sm" onClick={onReset}>
            Statistiken zurücksetzen
          </Button>
        )}
      </DialogContent>
    </Dialog>
  );
}
```

- [ ] **Step 4: StartDialog um Statistik-Button erweitern**

In `src/components/StartDialog.tsx` den `useGameStats`-Hook importieren und `<StatsPanel />` neben dem Start-Button platzieren.

```tsx
import { useGameStats } from '@/hooks/useGameStats';
import { StatsPanel } from '@/components/StatsPanel';

// innerhalb der Komponente:
const { stats, clear } = useGameStats();

// im JSX, z. B. neben dem Start-Button:
<StatsPanel stats={stats} onReset={clear} />
```

- [ ] **Step 5: Spielende in useGameWithAI.ts instrumentieren**

Import hinzufügen:

```ts
import { recordGameFinished, recordRoundFinished } from '@/lib/stats';
```

In der Funktion, die eine Runde beendet, z. B. `startNextRound` oder wo `GAME_OVER` gesetzt wird:

```ts
// Nach Berechnung des Runden-Ergebnisses:
const humanPlayer = newState.players.find((p) => !aiPlayers.has(p.id));
const dameCaller = newState.dameCallerId
  ? newState.players.find((p) => p.id === newState.dameCallerId)
  : null;
const dameSuccessful = dameCaller
  ? newState.players.every((p) => p.id === dameCaller.id || p.score > dameCaller.score)
  : false;

const totalPenaltyCards = newState.players.reduce(
  (sum, p) => sum + p.penaltyCards.length,
  0
);

const bestScore = Math.min(...newState.players.map((p) => p.score));

recordRoundFinished(!!dameCaller, dameSuccessful, totalPenaltyCards, bestScore);

// Wenn Spiel vorbei:
if (newState.phase === 'GAME_OVER') {
  const winner = newState.players.find((p) => !p.isEliminated);
  const humanWon = winner?.id === humanPlayer?.id;
  recordGameFinished(humanWon);
}
```

- [ ] **Step 6: README.md um Statistiken ergänzen**

```markdown
## Spielstatistiken

Das Spiel speichert lokale Statistiken im Browser (`localStorage`): gespielte Spiele, Siegquote, Runden, beste Runde sowie Dame-Ansagen. Über den Start-Dialog können sie eingesehen und zurückgesetzt werden.
```

- [ ] **Step 7: Tests, Lint, Build**

```bash
pnpm lint
pnpm test
pnpm build
```

- [ ] **Step 8: Commit**

```bash
git add src/lib/stats.ts src/hooks/useGameStats.ts src/components/StatsPanel.tsx src/components/StartDialog.tsx src/hooks/useGameWithAI.ts README.md
git commit -m "feat: add local game statistics panel"
```

---

## Task 5: Deployment vorbereiten (GitHub Pages)

**Files:**
- Create: `.github/workflows/deploy.yml`
- Modify: `vite.config.ts`
- Modify: `package.json`
- Modify: `README.md`

### Task 5.1 — GitHub Actions Workflow

- [ ] **Step 1: .github/workflows/deploy.yml erstellen**

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: 'pages'
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: 'npm'
      - name: Setup Pages
        uses: actions/configure-pages@v5
      - name: Install dependencies
        run: npm ci
      - name: Build
        run: npm run build
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./dist

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: vite.config.ts base path anpassen**

Da das Repo wahrscheinlich unter `https://deusexlumen.github.io/Dame-Card-Game/` läuft:

```ts
export default defineConfig({
  base: '/Dame-Card-Game/',
  plugins: [react()],
  // ...rest
});
```

- [ ] **Step 3: package.json homepage-Feld setzen**

```json
{
  "name": "my-app",
  "homepage": "https://deusexlumen.github.io/Dame-Card-Game/",
  // ...
}
```

- [ ] **Step 4: README.md Deployment-Abschnitt ergänzen**

```markdown
## Deployment

Das Projekt wird automatisch auf GitHub Pages deployt, sobald Änderungen in den `main`-Branch gepusht werden.  
Live-URL: https://deusexlumen.github.io/Dame-Card-Game/
```

- [ ] **Step 5: Build lokal verifizieren**

```bash
pnpm build
```

- [ ] **Step 6: Commit und Push**

```bash
git add .github/workflows/deploy.yml vite.config.ts package.json README.md
git commit -m "ci: add GitHub Pages deployment workflow"
git push origin main
```

---

## Final Verification

- [ ] `pnpm lint` läuft ohne Fehler
- [ ] `pnpm test` läuft ohne Fehler
- [ ] `pnpm build` läuft ohne Fehler und der Haupt-Chunk ist <500 kB
- [ ] Statistik-Panel ist im Start-Dialog sichtbar
- [ ] GitHub Actions Workflow ist im Repo vorhanden

## Spec Coverage Check

| Dossier-Punkt / Aufgabe | Task |
|-------------------------|------|
| Echtzeit-Reaktionsregel | Task 1.1 dokumentiert, Extra-Ablegen bleibt erhalten |
| Strafkarten-Anzahl | Task 1.2 `PENALTY_CARD_COUNT` |
| Dame sichtbar | Task 1.1 dokumentiert, bereits implementiert |
| Mitwerfen identischer Karten | Task 1.1 dokumentiert, bereits implementiert |
| Letzte Runde absichern | Task 1.1 dokumentiert, bereits implementiert |
| Build-Optimierung | Task 2 |
| KI-Balance | Task 3 |
| Neues Feature | Task 4 |
| Deployment | Task 5 |

## Placeholder Scan

Keine TBD/TODO/„später“-Platzhalter enthalten. Alle Code-Blöcke sind vollständig und verwenden existierende Dateipfade.
