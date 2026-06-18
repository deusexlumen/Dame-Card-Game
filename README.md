# DAME — Gedächtnis, Risiko & Bluff

[![Build](https://img.shields.io/badge/build-passing-brightgreen?logo=githubactions)](./)
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-7-646CFF?logo=vite)](https://vitejs.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-3.4-06B6D4?logo=tailwindcss)](https://tailwindcss.com/)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen?logo=vitest)](./)

> Ein browserbasiertes Kartenspiel für 2–6 Spieler. Menschliche Spieler können gegeneinander oder gegen KI-Gegner antreten. Komplett client-seitig in React + TypeScript gebaut — ohne Backend, ohne externe Assets.

---

## 🎴 Über das Spiel

**DAME** ist ein minimalistisches Informations-, Risiko- und Memory-Kartenspiel. Jeder Spieler besitzt ein verdecktes Kartenfeld aus vier Karten, von denen er sich zu Beginn nur zwei anschauen darf. Von da an muss er sich merken, welche Karte wo liegt — während er gleichzeitig die gegnerischen Aktionen beobachtet und den richtigen Moment findet, um die Runde zu beenden.

Der zentrale Reiz liegt nicht darin, einfach gute Karten zu besitzen, sondern die eigene Auslage zuverlässig zu kennen und die anderen Spieler richtig einzuschätzen. Fehler werden sofort bestraft, Information ist die wichtigste Währung, und die **Dame-Ansage** ist ein riskanter Bluff, der alles entscheiden kann.

Visuell folgt DAME einer **Terminal-/Cybernetic-Archive-Ästhetik**: schwarzer Hintergrund, grüner Phosphor-Glow, geometrische Symbole und Monospace-Typografie. Die Karten wirken wie Speicherobjekte eines archivierten Systems, nicht wie klassische Spielkarten.

---

## ✨ Features

| Feature | Beschreibung |
|---------|-------------|
| 🎮 **2–6 Spieler** | Mensch gegen Mensch oder gemischte Partien mit KI-Gegnern |
| 🤖 **KI-Gegner** | Drei Schwierigkeitsgrade: Einfach, Mittel, Schwer |
| 👁️ **Bube (J)** | Schau dir eine eigene *oder* gegnerische verdeckte Karte an |
| 👑 **König (K)** | Deck eine gegnerische Karte kurz auf und tausche sie gezielt mit einer eigenen |
| 🃏 **Dame (Q)** | Beim Ablegen ziehst du eine Strafkarte; der nächste Spieler muss eine offene Dame vom Ablagestapel ziehen |
| 📢 **Dame-Ansage** | Beende die Runde frühzeitig — liegt der Caller falsch, startet er die nächste Runde mit **5 Karten** |
| ⚡ **Extra-Ablegen** | Wenn du eine Karte mit gleichem Wert wie die oberste Ablagekarte besitzt, kannst du sie direkt ablegen |
| 🎯 **50-Punkte-Schwelle** | Wer über 50 Punkte kommt, scheidet aus; genau 50 Punkte setzen den Score auf 0 zurück |
| 🔊 **Sounds & Musik** | Prozedurale Soundeffekte über die Web Audio API, ein-/ausschaltbare Ambient-Musik |
| 🎬 **Animationen** | Framer-Motion-Animationen für Karten, UI-Übergänge und Feedback |
| ⚙️ **Einstellungen** | Sound, Musik, Animationen, KI-Geschwindigkeit und mehr |
| 💾 **Speichern & Laden** | Auto-Save im localStorage; Savegames werden validiert und bei Beschädigung verworfen |
| 📖 **Tutorial** | Integrierte Anleitung für neue Spieler |
| ♿ **Zugänglichkeit** | ARIA-Labels, Tastatursteuerung und Screenreader-freundliche Statusmeldungen |

---

## 🕹️ Spielregeln

### Ziel
Sammle so wenige Punkte wie möglich. Wer **mehr als 50 Punkte** besitzt, scheidet aus. Wer **genau 50 Punkte** erreicht, fällt auf **0** zurück.

### Aufbau
- Jeder Spieler erhält **4 verdeckte Karten**.
- Du darfst dir davon **genau 2** anschauen.
- Die Positionen der Karten bleiben erhalten — du musst dir merken, was wo liegt.

### Zugablauf
1. **Ziehen** — Nimm die oberste Karte vom Zieh- oder Ablagestapel.
2. **Entscheiden** — Behalte die Karte, tausche sie mit einer deiner Hand-Karten oder lege sie ab.
3. **Extra-Ablegen** — Passt eine deiner Hand-Karten zum Wert der obersten Ablagekarte, kannst du sie sofort mit ablegen.

### Sonderkarten
| Karte | Wert | Effekt |
|-------|------|--------|
| **Dame (Q)** | 0 | Beim Ablegen ziehst du eine Strafkarte. Liegt eine Dame oben auf dem Ablagestapel, muss der nächste Spieler sie ziehen. |
| **Bube (J)** | 10 | Schaue eine beliebige verdeckte Karte an (eigene oder gegnerische). |
| **König (K)** | 10 | Deck eine gegnerische Karte auf und tausche sie gezielt mit einer deiner Karten. |
| **Ass (A)** | 1 | Kein Effekt. |
| **2–10** | Kartenwert | Kein Effekt. |

### Dame-Ansage
Ab einer bestimmten Runde kannst du **„Dame"** rufen, wenn du glaubst, die wenigsten Punkte zu haben:
- Deine Karten werden gesperrt.
- Alle anderen Spieler erhalten noch einen letzten Zug.
- Dann werden alle Karten aufgedeckt und die Punkte berechnet.

**Wichtig:** Liegst du falsch oder hat ein anderer Spieler gleich viele oder weniger Punkte, startest du die **nächste Runde mit 5 statt 4 Karten** als Strafe.

---

## ⌨️ Tastenkürzel

| Taste | Aktion |
|-------|--------|
| `Leertaste` | Karte ziehen (wenn keine gezogen) / Gezogene Karte ablegen |
| `1` – `4` | Hand-Karte 1–4 auswählen (für Tausch oder Extra-Ablegen) |
| `Enter` | Tausch bestätigen |
| `D` | Dame rufen |
| `Z` / `E` | Zug beenden |
| `Esc` | Dialoge schließen / Aktion abbrechen |

---

## 🛠️ Tech Stack

- **Framework:** React 19
- **Sprache:** TypeScript 5.9
- **Build-Tool:** Vite 7
- **Styling:** Tailwind CSS 3.4, shadcn/ui (New-York-Style)
- **Animationen:** Framer Motion
- **State Management:** React Hooks + pure Logikfunktionen
- **Sound:** Web Audio API (prozedural generiert)
- **Testing:** Vitest + jsdom
- **Linting:** ESLint 9 mit TypeScript-Support

---

## 📁 Projektstruktur

```
src/
├── components/          # UI-Komponenten
│   ├── Card.tsx         # Kartendarstellung (Terminal-Look, Animationen)
│   ├── GameBoard.tsx    # Hauptspielbrett und Interaktionen
│   ├── PlayerHand.tsx   # Spielerhand mit Sichtbarkeitslogik
│   └── ui/              # shadcn/ui-Komponenten
├── hooks/               # React-Hooks
│   ├── useGameWithAI.ts # Spielzustand + KI-Automatisierung
│   ├── useSettings.ts   # Persistente Einstellungen
│   └── use-mobile.ts    # Mobile-Breakpoint-Erkennung
├── lib/                 # Reine Spiellogik (kein React)
│   ├── gameLogic.ts     # Spielregeln & Zustandsmaschine
│   ├── aiPlayer.ts      # KI-Entscheidungslogik
│   ├── sounds.ts        # Web-Audio-Sound-Engine
│   └── settings.ts      # Globale Settings-Referenz
├── types/               # TypeScript-Typen & Konstanten
│   └── game.ts
├── App.tsx              # Root-Komponente: Menü, Regeln, Spiel-Router
└── main.tsx             # Entry-Point
```

---

## 🚀 Getting Started

### Voraussetzungen
- [Node.js](https://nodejs.org/) (LTS empfohlen)
- [pnpm](https://pnpm.io/) als Package-Manager

### Installation & Entwicklung

```bash
# Dependencies installieren
pnpm install

# Entwicklungsserver starten
pnpm dev

# Produktions-Build erzeugen
pnpm build

# Produktions-Build lokal testen
pnpm preview
```

---

## 📜 Scripts

| Script | Befehl | Beschreibung |
|--------|--------|--------------|
| `dev` | `pnpm dev` | Vite-Entwicklungsserver starten |
| `build` | `pnpm build` | TypeScript-Check + Produktions-Build |
| `preview` | `pnpm preview` | `dist/` lokal previewen |
| `lint` | `pnpm lint` | ESLint ausführen |
| `test` | `pnpm test` | Vitest im Watch-Modus starten |
| `test:ui` | `pnpm test:ui` | Vitest mit UI-Oberfläche starten |

---

## 🧪 Tests

```bash
# Tests einmalig ausführen
pnpm vitest run

# Tests mit UI
pnpm test:ui
```

Die Tests decken ab:
- Karten-Generierung & Mischen
- Spielmechaniken (Ziehen, Tauschen, Ablegen)
- Sonderkarten-Effekte (Bube, König, Dame)
- Dame-Ansage & Strafmechanik
- Punkteberechnung & Eliminierung
- KI-Entscheidungslogik

---

## 🌍 Deployment

DAME wird als statische Single-Page-Application ausgeliefert:

1. `pnpm build` erzeugt den `dist/`-Ordner.
2. Lade den Inhalt von `dist/` auf deinen Static-Hosting-Anbieter hoch (z. B. Netlify, Vercel, GitHub Pages, Cloudflare Pages).
3. In `vite.config.ts` ist `base: './'` gesetzt — die Assets verwenden relative Pfade. Wenn du das Spiel unter einem Unterpfad bereitstellst, passe `base` entsprechend an.

**Kein Server-Side-Rendering, keine API, keine Datenbank nötig.**

---

## 📝 Lizenz

MIT

---

> Gebaut mit ❤️, ☕ und viel grünem Phosphor-Glow — viel Spaß beim Spielen!
## Offene Konzeptfragen — Finale Entscheidungen

Siehe [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md) für die verbindliche Festlegung von Echtzeit-Reaktion, Strafkarten-Anzahl, Sichtbarkeit der Dame, Mitwerfen und Rundenabschluss.
