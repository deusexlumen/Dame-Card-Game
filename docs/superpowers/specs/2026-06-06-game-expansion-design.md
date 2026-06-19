# Design: Dame Card Game – Spiel-Ausbau

**Datum:** 2026-06-06  
**Status:** Draft – wartet auf Review  
**Scope:** Settings-basierter Ausbau mit Blitz-Modus, optionalen Power-Effekten und verbesserter KI-Schwierigkeits-Integration.

---

## Zusammenfassung

Das MVP des Dame Card Game wird um zwei neue globale Settings-Optionen erweitert:

1. **Blitz-Modus** mit einstellbarem Zugzeitlimit und Strafkarte bei Zeitablauf.
2. **Power-Effekte** – eine optional zuschaltbare Regel-Variante, die König, Bube, Ass und 10 erweiterte Fähigkeiten gibt.

**KI-Schwierigkeit** existiert bereits pro Spieler im Hauptmenü. Der Ausbau fügt einen optionalen **globalen Standard-Schwierigkeits-Default** in den Settings hinzu, der für neu hinzugefügte KI-Spieler verwendet wird.

Alle neuen Optionen werden in den bestehenden Settings persistiert, durch `GameConfig` an die Spiellogik gereicht und vollständig ins bestehende i18n-System übersetzt.

---

## Ziele

- Spieler können einen optionalen Blitz-Modus mit Zeitlimit aktivieren.
- Spieler können erweiterte Karteneffekte (Power-Effekte) optional zuschalten.
- Neue KI-Spieler verwenden einen in den Settings wählbaren Schwierigkeits-Default.
- Alle neuen Features bleiben rückwärtskompatibel zum klassischen Spielmodus (alles aus = aktuelles Verhalten).
- Die Architektur bleibt übersichtlich: keine vollständige Regel-Engine, sondern gezielte Settings-Flags mit sauberen Verzweigungen.

## Nicht-Ziele

- Online-Multiplayer oder Hot-Seat.
- Neue Kartenrückseiten, Skins oder visuelle Kampagnen.
- Persistente Level-Progression oder Achievements.
- Veränderung der klassischen Dame-Call- und Punkte-Logik (außer durch Power-Effekte, wenn diese aktiv sind).

---

## Architektur

### Neue Settings

Erweiterung von `src/hooks/useSettings.ts`:

```ts
interface GameSettings {
  // bestehend
  soundEnabled: boolean;
  animationsEnabled: boolean;
  aiSpeed: 'fast' | 'normal' | 'slow';
  musicEnabled: boolean;

  // neu
  defaultAIDifficulty: 'easy' | 'medium' | 'hard';
  turnTimer: boolean;
  turnTimerSeconds: 15 | 30 | 60;
  powerEffects: boolean;
}
```

`src/lib/settings.ts` (globale Referenz für Nicht-React-Code) wird nicht für Spielregeln verwendet.

### GameConfig

`useGameWithAI` liest die Settings und erzeugt ein flaches `GameConfig`, das an `gameLogic.ts` und `aiPlayer.ts` weitergegeben wird:

```ts
interface GameConfig {
  turnTimer: { enabled: boolean; seconds: number };
  powerEffects: boolean;
}
```

### Datenfluss

1. Spieler öffnet Settings, ändert Optionen.
2. `useSettings` persistiert in `localStorage`.
3. `App` liest die aktuellen Settings über `useSettings`.
4. Beim Spielstart übergibt `App` die relevanten Settings (`turnTimer`, `powerEffects`) zusammen mit `players` an `GameBoard`.
5. `GameBoard` leitet sie an `useGameWithAI` weiter.
6. `useGameWithAI` erzeugt `GameConfig` und reicht sie an Spiellogik (`gameLogic.ts`) und KI (`aiPlayer.ts`).
7. UI zeigt aktive Optionen an (z. B. Countdown, Power-Effekt-Indikatoren).
8. `App` verwendet `defaultAIDifficulty`, wenn ein neuer KI-Spieler hinzugefügt wird.

---

## Features im Detail

### 1. KI-Schwierigkeit (bestehend, erweitert)

- Die Schwierigkeit wird weiterhin **pro KI-Spieler** im Hauptmenü gewählt.
- In den Settings gibt es einen neuen Default `defaultAIDifficulty`.
- Wenn ein neuer KI-Spieler hinzugefügt wird, verwendet `App` diesen Default.
- Die KI nutzt Power-Effekte nur, wenn `powerEffects: true` ist; bei `false` verhält sie sich wie bisher.

| Stufe | Verhalten |
|-------|-----------|
| `easy` | Zufällige Züge; ignoriert Memory; callt „Dame“ nur mit sehr niedriger Hand. |
| `medium` | Nutzt Memory für eigene und gesehene gegnerische Karten; callt „Dame“, wenn sie vermutlich führt. |
| `hard` | Berechnet Wahrscheinlichkeiten über verbleibende Karten; spielt aggressiv; nutzt Power-Effekte optimal, falls aktiv. |

### 2. Blitz-Modus

- Aktivierbar über Toggle `turnTimer`.
- Wählbare Sekunden: 15, 30, 60.
- Sichtbarer Countdown im Spiel-UI.
- Zeit abgelaufen → Spieler zieht **eine Strafkarte** vom Deck; Zug endet sofort.
- Der Timer pausiert während Power-Effekt-Auswahlen (z. B. König-Tausch, Ass-Prophecy), damit UI-Interaktionen fair bleiben.

### 3. Power-Effekte

Wenn `powerEffects: true`, erhalten folgende Karten zusätzliche Effekte beim Ablegen:

| Karte | Effekt |
|-------|--------|
| König | Wähle einen Gegner und tausche eine deiner Handkarten mit einer **zufälligen gegnerischen Handkarte**. Beide Karten bleiben verdeckt. |
| Bube | Wähle einen Gegner und **peek** eine seiner Handkarten. Wissen landet im Memory. |
| Ass | **Prophecy** – schau dir die obersten 3 Karten des Nachziehstapels an. Du darfst eine davon wählen und mit einer beliebigen Handkarte tauschen (oder abbrechen). |
| 10 | **Stun** – der **nächste Spieler in der Zugreihenfolge** überspringt seinen nächsten Zug. |

Wenn `powerEffects: false`:
- König behält sein Standard-Verhalten (Tausch mit Gegner oder Peek).
- Bube behält sein Standard-Verhalten (Peek auf eigene oder gegnerische Karte).
- Ass und 10 haben keinen Effekt.

Wenn `powerEffects: true`:
- König muss mit einem Gegner tauschen.
- Bube muss eine gegnerische Karte peken.
- Ass und 10 erhalten ihre neuen Effekte.

---

## UI/UX

### Settings-Panel

- Zentraler Screen, erreichbar über Hauptmenü und In-Game-Menü.
- Sektionen:
  - **Spielregeln**: Toggle „Power-Effekte“ mit kurzer Erklärung.
  - **Blitz-Modus**: Toggle + Sekunden-Auswahl (15/30/60).
  - **KI-Gegner**: Dropdown „Standard-Schwierigkeit für neue KI-Spieler“ (Einfach / Mittel / Schwer).
  - **Audio & Sprache**: Sound-Toggle + Sprachauswahl.

### In-Game UI

- Schwierigkeits-Badge neben dem KI-Namen.
- Countdown-Anzeige, wenn Blitz-Modus aktiv.
- Toast-Meldungen für Power-Effekte (z. B. „König: Karte mit Gegner getauscht“).

---

## Fehlerbehandlung

- Ungültige Power-Effekt-Ziele werden vor Ausführung validiert.
- Eine leere Hand löst automatisch „Dame“ aus, bevor Power-Effekte auf den Gegner zielen können.
- Deck leer beim Ziehen einer Strafkarte → Ablagestapel neu mischen; falls nicht möglich, passiert nichts.
- Ungültige `localStorage`-Settings werden auf Defaults zurückgesetzt.

---

## Testing

- Unit-Tests für `applyAceEffect` (Prophecy) und `applyTenEffect` (Stun).
- Unit-Tests für Timer-Strafkarte bei Zeitablauf in `useGameWithAI`.
- Unit-Tests für KI-Entscheidungen mit `powerEffects: true` und `powerEffects: false`.
- Render-Test für das Settings-Panel.
- Snapshot-Tests für i18n-Keys der neuen Texte.

---

## i18n

Alle neuen UI-Texte und Spielmeldungen erhalten deutsche und englische Übersetzungen in `src/lib/i18n.tsx`.

---

## Offene Fragen

Keine – Design wurde vom Product-Owner bestätigt.
