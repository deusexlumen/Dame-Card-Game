# Design: Dame Card Game – Professional Polish & Skin-System

**Datum:** 2026-06-06  
**Status:** Draft – wartet auf Review  
**Scope:** Visuelles und akustisches Professionalisieren des Spiels mit Skin-System, Modern-Dark-Casino-Look, Pseudo-3D-Ansicht und Sound/Musik.

---

## Zusammenfassung

Das Dame Card Game wird professioneller, ohne die Spielbarkeit zu beeinträchtigen. Es entsteht ein **Modern-Dark-Casino-Look** mit austauschbaren Skins für Kartenrückseiten, Tisch-Oberflächen und Kartenvorderseiten. Das Skin-System ist lokal gespeichert, aber so abstrahiert, dass später ein Backend für geräteübergreifende Käufe einfach angebunden werden kann.

Zusätzlich wird das Spiel um **Soundeffekte und Hintergrundmusik** erweitert sowie um eine optionale **Pseudo-3D-Tischansicht** (CSS 3D-Transforms), die später in einem separaten Projekt „Dame 2“ durch echte First-Person-3D ersetzt werden kann.

---

## Ziele

- Das Spiel erhält ein konsistentes Modern-Dark-Casino-Visual-Design.
- Spieler können Skins für Kartenrückseiten, Tische und Kartenvorderseiten kaufen und aktivieren.
- Das Skin-System ist erweiterbar und Backend-ready.
- Soundeffekte und Hintergrundmusik verbessern das Spielgefühl.
- Eine optionale Pseudo-3D-Ansicht gibt dem Spiel Tiefe, ohne die Übersichtlichkeit zu beeinträchtigen.
- Multiplayer bleibt außerhalb dieses Scopes und wird als separates Projekt „Dame 2“ geplant.

## Nicht-Ziele

- Echte First-Person-3D mit Game Engine (wird als „Dame 2“ ausgelagert).
- Online-Multiplayer.
- Echte Zahlungsabwicklung im ersten Wurf (Kauf wird lokal simuliert).
- Account-System oder Cloud-Speicherung im ersten Wurf.

---

## Architektur

### Skin-System

**Neue Dateien:**

| Datei | Verantwortung |
|-------|----------------|
| `src/lib/skins/types.ts` | Typen: `Skin`, `SkinCategory`, `SkinInventory`. |
| `src/lib/skins/registry.ts` | Statische Liste aller verfügbaren Skins. |
| `src/lib/skins/inventoryService.ts` | `LocalSkinInventoryService` mit klarer Interface-Abstraktion. |
| `src/hooks/useSkins.ts` | React-Hook für aktive Skins. |
| `src/components/SkinProvider.tsx` | Context Provider. |
| `src/components/SkinShop.tsx` | Shop-UI. |
| `src/components/SkinSelector.tsx` | Schnellauswahl im Spiel. |

**Datenfluss:**

1. `App` rendert `SkinProvider`.
2. `SkinProvider` initialisiert `LocalSkinInventoryService` und lädt Inventar aus `localStorage`.
3. Komponenten lesen aktive Skins über `useSkins()`.
4. Karten- und Tisch-Komponenten rendern basierend auf aktiven Skin-Assets.
5. Käufe werden über `inventoryService.purchase(skinId)` abgewickelt.

**Skin-Typ:**

```ts
export type SkinCategory = 'cardBack' | 'table' | 'cardFace';

export interface Skin {
  id: string;
  name: string;
  category: SkinCategory;
  price: number;
  currency: 'EUR';
  previewImage: string;
  assets: {
    cardBack?: string; // e.g. '/skins/neon-green/card-back.svg'
    cardFace?: string; // e.g. '/skins/neon-green/card-face.svg'
    table?: string;    // e.g. '/skins/neon-green/table-bg.jpg'
  };
}
```

### Asset-Struktur

```
public/skins/
├── default/
│   ├── card-back.svg
│   ├── card-face.svg
│   └── table-bg.jpg
├── neon-green/
│   ├── card-back.svg
│   ├── card-face.svg
│   └── table-bg.jpg
├── cyber-felt/
│   └── table-bg.jpg
└── royal-gold/
    ├── card-back.svg
    └── card-face.svg
```

- Jedes Skin-Pack hat einen eigenen Ordner.
- `default` ist immer kostenlos verfügbar.
- Neue Skins werden durch neuen Ordner + Eintrag in `registry.ts` hinzugefügt.

---

## UI/UX

### Skin-Shop

- Erreichbar aus dem Hauptmenü.
- Raster mit allen Skins, gruppiert nach Kategorie.
- Jeder Skin zeigt: Vorschaubild, Name, Preis, „Kaufen“- oder „Auswählen“-Button.
- Nach Kauf wechselt der Button zu „Aktivieren“.
- Kategorie-Tabs: Kartenrückseiten, Tische, Kartenvorderseiten.

### Skin-Schnellauswahl im Spiel

- Kleines Panel im In-Game-Menü.
- Zeigt nur gekaufte Skins.
- Ermöglicht schnelles Wechseln zwischen ausgewählten Skins.

### Zahlungsfluss (Demo)

- Klick auf „Kaufen“ öffnet einen Bestätigungsdialog.
- Bei Bestätigung wird der Skin dem Inventar hinzugefügt.
- Echte Zahlungsintegration wird später über ein Backend-Plugin an `inventoryService` angebunden.

---

## Pseudo-3D / Isometrie

- Der Tisch wird mit `perspective` und `rotateX` leicht geneigt.
- Karten und Stapel bekommen Schatten und leichte Tiefe.
- Eigener Stapel, Gegner-Stapel, Ablagestapel und Nachziehstapel bleiben übersichtlich erkennbar.
- Die Neigung bleibt moderat (max. 15–20°).
- Es gibt einen Toggle im Menü: „Klassische 2D-Ansicht“ vs. „3D-Tischansicht“.

```css
.table-3d {
  perspective: 1200px;
  transform-style: preserve-3d;
}

.table-surface {
  transform: rotateX(15deg);
}
```

---

## Sound & Musik

### Soundeffekte

- Karte ziehen (Rascheln)
- Karte ablegen (Plopp/Klack)
- Power-Effekt aktiviert
- Dame-Call / Warnung
- Sieg / Niederlage

### Musik

- Loopbarer Hintergrund-Track im Menü und im Spiel.
- MP3 mit 128–192 kbps als bevorzugtes Format.
- Separate Lautstärkeregler für Musik und Effekte.
- Mute-Option.

### Technik

- `Web Audio API` für kurze Soundeffekte.
- `<audio>`-Element für Musik.
- Assets unter `public/sounds/`.

---

## Fehlerbehandlung

- Asset nicht ladbar → Fallback auf `default`-Skin.
- Korruptes Inventar in `localStorage` → Reset auf Default-Inventar.
- Kauf ohne ausreichend Guthaben (Demo-Modus) → Hinweisdialog.
- Audio nicht abspielbar (Autoplay-Policy) → Musik startet erst nach erster Nutzerinteraktion.

---

## Testing

- Unit-Tests für `inventoryService` (Kauf, Aktivierung, Persistenz).
- Unit-Tests für `SkinProvider`.
- Visuelle Regressionstests für Karten- und Tisch-Rendering mit verschiedenen Skins.
- Audio-Tests: Sound wird bei korrekten Events abgespielt.

---

## i18n

Alle neuen UI-Texte (Shop, Skin-Kategorien, Ansichts-Toggle, Audio-Einstellungen) werden vollständig auf Deutsch und Englisch übersetzt.

---

## Offene Fragen

Keine – Design wurde vom Product-Owner bestätigt.
