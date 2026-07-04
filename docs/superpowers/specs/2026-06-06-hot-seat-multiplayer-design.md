# Design: Dame Card Game – Hot-Seat Multiplayer

**Datum:** 2026-06-06  
**Status:** Draft – wartet auf Review  
**Scope:** Hot-Seat Multiplayer für 2–4 Spieler mit beliebiger Mensch/KI-Mischung, Pass-&-Play-Verdeckung und Weitergeben-Overlay.

---

## Zusammenfassung

Das Dame Card Game erhält einen **Hot-Seat-Multiplayer-Modus** für 2–4 Spieler am selben Gerät. Spieler können beliebig als Mensch oder KI konfiguriert werden. Nicht-aktive menschliche Spieler sehen ihre Karten verdeckt; der aktive Spieler bestätigt über ein „Weitergeben“-Overlay, bevor sein Board sichtbar wird. KI-Spieler spielen weiterhin automatisch.

---

## Ziele

- Hot-Seat-Modus für 2–4 Spieler ermöglichen.
- Beliebige Mischung aus menschlichen und KI-Spielern unterstützen.
- Nur der aktive menschliche Spieler sieht seine eigenen Karten offen.
- KI-Spieler benötigen kein Weitergeben-Overlay.
- Der Modus bleibt visuell und technisch konsistent zum bestehenden Spiel.

## Nicht-Ziele

- Online-Multiplayer (folgt später).
- Getrennte Bildschirme pro Spieler.
- Anpassung der Spielregeln für Multiplayer (Regeln bleiben gleich).

---

## Architektur

### Neue/angepasste Dateien

| Datei | Verantwortung |
|-------|----------------|
| `src/types/game.ts` | Erweiterung `Player` um `isHuman`. |
| `src/hooks/useGameWithAI.ts` | Umbenennen/erweitern zu `useGameEngine`; verwaltet menschliche und KI-Spieler. |
| `src/components/GameBoard.tsx` | Zeigt Weitergeben-Overlay, reagiert auf aktiven Spieler. |
| `src/components/PlayerTurnOverlay.tsx` | Neues Overlay: „Spieler X ist dran“. |
| `src/components/HotSeatSetup.tsx` | Konfigurations-UI für Hot-Seat-Spieler. |
| `src/App.tsx` | Hot-Seat-Button und Modus-Routing. |
| `src/lib/i18n.tsx` | Neue Übersetzungen. |

### Spieler-Modell

```ts
export interface Player {
  id: string;
  name: string;
  isAI: boolean;
  isHuman: boolean;
  hand: Card[];
  penaltyCards: Card[];
  score: number;
  isEliminated: boolean;
  visibleCardIndices: number[];
}
```

- `isHuman = true && isAI = false`: menschlicher Hot-Seat-Spieler.
- `isHuman = false && isAI = true`: KI-Spieler.
- Im Einzelspielermodus: ein menschlicher Spieler + KI-Gegner.

### Datenfluss

1. Spieler wählt im Hauptmenü „Hot-Seat“.
2. `HotSeatSetup` sammelt Spieleranzahl, Namen und Typen.
3. `App` übergibt die Spielerliste an `GameBoard`.
4. `useGameEngine` initialisiert das Spiel.
5. Nach jedem Zug prüft die Engine den nächsten Spieler:
   - KI → automatischer Zug.
   - Mensch → `showTurnOverlay = true`.
6. Spieler klickt „Bereit“, Overlay verschwindet, Board wird sichtbar.

---

## UI/UX

### Hauptmenü

- Neuer Button „Hot-Seat“.
- Beim Klick: `HotSeatSetup`-Dialog/Seite.

### Hot-Seat Setup

- Spieleranzahl: 2, 3 oder 4.
- Pro Spieler:
  - Name (Textfeld).
  - Typ: Mensch / KI.
  - Falls KI: Schwierigkeit (Einfach / Mittel / Schwer).
- Button „Spiel starten“.

### GameBoard im Hot-Seat-Modus

- Oben: Name des aktiven Spielers.
- Mitte: Gemeinsame Stapel (Ablage, Nachzieh) – für alle sichtbar.
- Unten: Eigener Stapel des aktiven Spielers (nur für ihn lesbar).
- Gegnerische Stapel werden verdeckt angezeigt.

### Weitergeben-Overlay

- Vollflächiges Modal.
- Text: „Spieler [Name] ist dran“.
- Button: „Ich bin bereit“.
- Hinweis: „Andere Spieler bitte nicht hinschauen.“

### KI-Verhalten

- KI-Spieler spielen ohne Overlay automatisch weiter.
- Verzögerung bleibt über `aiSpeed` einstellbar.

---

## Fehlerbehandlung

- Mindestens ein menschlicher Spieler muss vorhanden sein.
- Namen dürfen nicht leer sein (Fallback auf „Spieler 1“, „Spieler 2“ etc.).
- Bei ungültiger Konfiguration wird der Start-Button deaktiviert.
- Speicherstand im Hot-Seat-Modus merkt sich, welcher Spieler gerade am Zug ist und ob das Overlay aktiv war.

---

## Testing

- Unit-Tests für `useGameEngine` / `useGameWithAI` mit gemischten Mensch/KI-Spielern.
- Tests für `HotSeatSetup` (Validierung, Spieler hinzufügen/entfernen).
- Tests für `PlayerTurnOverlay` (Render bei aktivem Spieler).
- Integrationstest: Ein vollständiger Zyklus Mensch → KI → Mensch.

---

## i18n

Alle neuen UI-Texte (Setup, Overlay, Menü) werden auf Deutsch und Englisch übersetzt.

---

## Offene Fragen

Keine – Design wurde vom Product-Owner bestätigt.
