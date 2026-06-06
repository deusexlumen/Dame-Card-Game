# Dame Kartenspiel — Audit-Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Alle kritischen Bugs beheben — Rundenzyklus, KI-Züge, Dame Call, Zugzähler, UI-Integration — sodass das Spiel vollständig spielbar ist.

**Architecture:** Pure functions in `gameLogic.ts` erweitern/korrigieren, Hook `useGameWithAI.ts` um Automatisierung ergänzen, `GameBoard.tsx` UI nachrüsten. Keine Architektur-Änderung.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, shadcn/ui, Vite.

---

## Task 1: `gameLogic.ts` — Zugzähler, endRound, canCallDame, Dame-State

**Files:**
- Modify: `src/types/game.ts`
- Modify: `src/lib/gameLogic.ts`

### Step 1.1: `GameState` um `roundStartPlayerIndex` und `dameCallTurnsRemaining` erweitern

In `src/types/game.ts`, Interface `GameState` (Zeilen 37–49) erweitern:

```typescript
export interface GameState {
  players: Player[];
  currentPlayerIndex: number;
  deck: Card[];
  discardPile: Card[];
  phase: GamePhase;
  round: number;
  turnInRound: number;
  dameCallerId: string | null;
  cardsLogged: boolean;
  safePhase: boolean;
  lastAction: string | null;
  roundStartPlayerIndex: number;        // NEU: Wer startete diese Runde
  dameCallTurnsRemaining: number | null; // NEU: Verbleibende Züge nach Dame Call
}
```

### Step 1.2: `initializeGame` initialisiert neue Felder

In `src/lib/gameLogic.ts`, Funktion `initializeGame` (Zeilen 66–92), Return-Objekt erweitern:

```typescript
  return {
    players,
    currentPlayerIndex: 0,
    deck,
    discardPile: [],
    phase: 'SETUP',
    round: 1,
    turnInRound: 1,
    dameCallerId: null,
    cardsLogged: false,
    safePhase: true,
    lastAction: null,
    roundStartPlayerIndex: 0,        // NEU
    dameCallTurnsRemaining: null,    // NEU
  };
```

### Step 1.3: `endTurn` fixen — Rundenende korrekt erkennen

In `src/lib/gameLogic.ts`, Funktion `endTurn` (Zeilen 235–259) komplett ersetzen:

```typescript
export function endTurn(gameState: GameState): GameState {
  const newState = { ...gameState };
  const activePlayers = newState.players.filter(p => !p.isEliminated).length;

  // Nächster Spieler (überspringe Eliminierte)
  do {
    newState.currentPlayerIndex = (newState.currentPlayerIndex + 1) % newState.players.length;
  } while (newState.players[newState.currentPlayerIndex].isEliminated);

  newState.turnInRound++;

  // Rundenende prüfen: wenn wir beim Startspieler der Runde ankommen
  // und mindestens ein Zug gespielt wurde
  if (newState.currentPlayerIndex === newState.roundStartPlayerIndex && newState.turnInRound > 1) {
    newState.turnInRound = 1;
    newState.round++;
    newState.roundStartPlayerIndex = newState.currentPlayerIndex;

    if (newState.round > 2) {
      newState.safePhase = false;
      newState.phase = 'REGULAR_PLAY';
    }
  }

  return newState;
}
```

### Step 1.4: `endRound` anpassen — kein doppeltes `round++`

In `src/lib/gameLogic.ts`, Funktion `endRound` (Zeilen 262–318). `round++` entfernen, da `endTurn` das schon erhöht. Neue Felder resetten:

Ersetze die Zeilen:
```typescript
  // Neue Runde vorbereiten
  newState.round++;
  newState.turnInRound = 1;
  newState.dameCallerId = null;
  newState.cardsLogged = false;
```

durch:
```typescript
  // Neue Runde vorbereiten
  // HINWEIS: round wurde bereits von endTurn erhöht
  newState.turnInRound = 1;
  newState.dameCallerId = null;
  newState.cardsLogged = false;
  newState.dameCallTurnsRemaining = null; // NEU
```

Und am Ende der Funktion, statt:
```typescript
  newState.phase = newState.round > 2 ? 'REGULAR_PLAY' : 'SETUP';
  newState.safePhase = newState.round <= 2;
```

muss das so bleiben, aber wir fügen hinzu:
```typescript
  newState.phase = newState.round > 2 ? 'REGULAR_PLAY' : 'SETUP';
  newState.safePhase = newState.round <= 2;
  // NEU: Startspieler für die neue Runde setzen (nächster aktiver Spieler)
  const activePlayerIndices = newState.players
    .map((p, i) => (!p.isEliminated ? i : -1))
    .filter(i => i !== -1);
  const currentStartIdx = activePlayerIndices.indexOf(newState.roundStartPlayerIndex);
  const nextStartIdx = activePlayerIndices[(currentStartIdx + 1) % activePlayerIndices.length];
  newState.roundStartPlayerIndex = nextStartIdx;
  newState.currentPlayerIndex = newState.roundStartPlayerIndex;
```

### Step 1.5: `callDame` setzt `dameCallTurnsRemaining`

In `src/lib/gameLogic.ts`, Funktion `callDame` (Zeilen 216–227) ersetzen:

```typescript
export function callDame(gameState: GameState, playerId: string): GameState {
  const newState = { ...gameState };
  const player = newState.players.find(p => p.id === playerId)!;
  const activePlayers = newState.players.filter(p => !p.isEliminated).length;

  player.hasCalledDame = true;
  newState.dameCallerId = playerId;
  newState.phase = 'DAME_CALLED';
  newState.cardsLogged = true;
  newState.dameCallTurnsRemaining = activePlayers; // Jeder aktive Spieler darf noch einmal
  newState.lastAction = `${player.name} hat "Dame" gerufen!`;

  return newState;
}
```

### Step 1.6: `canCallDame` absichern

In `src/lib/gameLogic.ts`, Funktion `canCallDame` (Zeilen 230–232) ersetzen:

```typescript
export function canCallDame(gameState: GameState): boolean {
  return (
    !gameState.safePhase &&
    gameState.phase === 'REGULAR_PLAY' &&
    gameState.dameCallerId === null
  );
}
```

### Step 1.7: `endRound` um Dame-Call-Auswertung erweitern

In `src/lib/gameLogic.ts`, Funktion `endRound`. Vor der Eliminationsprüfung (nach der Punkteberechnung) fügen wir die Dame-Call-Logik hinzu. Nach der Schleife `for (const player of newState.players)` und vor `const remainingPlayers = ...`:

```typescript
  // Dame Call Auswertung
  if (newState.dameCallerId) {
    const caller = newState.players.find(p => p.id === newState.dameCallerId);
    if (caller && !caller.isEliminated) {
      const callerScore = caller.score;
      const lowestScore = Math.min(
        ...newState.players
          .filter(p => !p.isEliminated && p.id !== newState.dameCallerId)
          .map(p => p.score)
      );
      if (callerScore <= lowestScore) {
        // Caller hat gewonnen — Runde gilt als gewonnen (0 Punkte)
        caller.score = 0;
        newState.lastAction = `${caller.name} hat "Dame" richtig gerufen! Runde gewonnen.`;
      } else {
        // Caller lag falsch — Strafkarte
        const { card: penaltyCard, newState: updatedState } = drawFromDeck(newState);
        if (penaltyCard) {
          penaltyCard.isVisible = false;
          caller.penaltyCards.push(penaltyCard);
          newState.lastAction = `${caller.name} lag falsch! Strafkarte.`;
        }
      }
      // Scores nochmal berechnen (für Caller könnte sich was geändert haben)
      // Nur Caller kann sich geändert haben
      if (caller.score === 0) {
        caller.totalScore += 0; // keine Änderung
      }
    }
  }
```

Warte, das ist problematisch, weil `totalScore` schon vorher berechnet wurde. Besser: Die Dame-Call-Auswertung MUSS vor der totalScore-Berechnung passieren, oder wir recalcen den Caller.

Ich werde den Code in `endRound` so strukturieren:
1. Alle Karten aufdecken (wenn Dame Call)
2. Punkte berechnen
3. Dame Call Auswertung (Caller bekommt 0 Punkte oder Strafkarte)
4. totalScore aktualisieren
5. Elimination prüfen

Aber das erfordert, dass `endRound` komplett umgeschrieben wird für den Dame-Fall.

Eigentlich: Wenn Dame Call aktiv war, sollten wir die Runde nicht "normal" beenden, sondern sofort auswerten. `endRound` wird dann aufgerufen, wenn `dameCallTurnsRemaining === 0`.

Lass mich den Code für `endRound` komplett neu schreiben in der Plan-Datei.

Aber das wird sehr lang. Stattdessen werde ich die konkreten Edits direkt ausführen und den Plan als 