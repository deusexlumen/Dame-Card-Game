# 🃏 Dame — Das Kartenspiel mit Bluff & Strategie

[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-7-646CFF?logo=vite)](https://vitejs.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?logo=tailwindcss)](https://tailwindcss.com/)
[![Tests](https://img.shields.io/badge/Tests-46%20passing-brightgreen)](#tests)

> Ein browser-basiertes Kartenspiel für 2–4 Spieler mit KI-Gegnern, komplett in React + TypeScript gebaut. Keine externen Assets — alle Sounds werden per Web Audio API generiert.

---

## ✨ Features

| Feature | Beschreibung |
|---------|-------------|
| 🤖 **KI-Gegner** | 3 Schwierigkeitsgrade (Einfach, Mittel, Schwer) mit unterschiedlichen Strategien |
| 🎵 **Prozedurale Sound-Effekte** | Web Audio API — kein einziges MP3 nötig |
| 🎶 **Ambient-Hintergrundmusik** | Sanfte Casino-Atmosphäre, ein-/ausschaltbar |
| 🎨 **Framer Motion Animationen** | Karten-Flip, Hover-Effekte, Spring-Physics |
| 📱 **Mobile-Optimierung** | Responsive Design, Touch-freundliche Steuerung |
| 💾 **Spielstand-Speicherung** | Auto-Save in localStorage — jederzeit fortsetzen |
| ⚡ **Keyboard-Shortcuts** | Vollständige Tastatursteuerung |
| 🔔 **Toast-Benachrichtigungen** | Echtzeit-Feedback für Spielereignisse |
| 📋 **Tutorial/Anleitung** | Integrierte Hilfe für neue Spieler |
| ⚙️ **Einstellungen** | Sound, Musik, Animationen, KI-Geschwindigkeit |

---

## 🎮 Spielanleitung

### Ziel
Sammle so wenige Punkte wie möglich. Wer **über 50 Punkte** kommt, scheidet aus. Wer **genau 50 Punkte** erreicht, fällt auf **0** zurück!

### Spielablauf
1. **Kartenverteilung** — Jeder bekommt 4 verdeckte Karten. Du siehst nur 2 davon.
2. **Ziehen** — Nimm die oberste Karte vom Zieh- oder Ablagestapel.
3. **Tauschen** — Tausche die gezogene Karte mit einer deiner Hand-Karten.
4. **Ablegen** — Oder lege die gezogene Karte direkt auf den Ablagestapel.
5. **Extra-Ablegen** — Wenn die oberste Ablagekarte z.B. eine 7 ist und du auch eine 7 hast, kannst du diese direkt ablegen!

### Sonderkarten
| Karte | Effekt |
|-------|--------|
| **Bube (J)** | Schaue eine deiner verdeckten Karten an |
| **König (K)** | Tausche eine Karte blind mit einem Gegner |
| **Dame (Q)** | Rufe „Dame!" — der Spieler mit den meisten Punkten bekommt eine Strafkarte |

### Rundenende
Wenn alle Karten vom Ziehstapel aufgebraucht sind, endet die Runde. Alle Karten werden aufgedeckt und die Punkte berechnet. Dann geht's in die nächste Runde!

---

## ⌨️ Tastenkürzel

| Taste | Aktion |
|-------|--------|
| `Leertaste` | Ziehen (wenn keine Karte) / Gezogene Karte ablegen |
| `1` – `4` | Hand-Karte 1–4 auswählen (für Tausch) |
| `Enter` | Tausch bestätigen |
| `D` | Dame rufen |
| `Z` / `E` | Zug beenden |

---

## 🛠️ Tech Stack

- **Frontend:** React 19, TypeScript 5.7, Vite 7
- **Styling:** Tailwind CSS 4, shadcn/ui
- **Animationen:** Framer Motion
- **State Management:** React Hooks + useReducer (Game Logic)
- **Sound:** Web Audio API (prozedural generiert)
- **Tests:** Vitest + jsdom

---

## 🚀 Entwicklung

```bash
# Dependencies installieren
pnpm install

# Dev-Server starten
pnpm run dev

# Tests ausführen
pnpm run test

# Produktions-Build
pnpm run build
```

---

## 🧪 Tests

```
✓ src/lib/aiPlayer.test.ts    (16 tests)
✓ src/lib/gameLogic.test.ts   (30 tests)
─────────────────────────────────────
Test Files  2 passed (2)
     Tests  46 passed (46)
```

Die Tests decken ab:
- Karten-Generierung & Mischen
- Spielmechaniken (Ziehen, Tauschen, Ablegen)
- Sonderkarten-Effekte (Bube, König, Dame)
- Punkteberechnung & Eliminierung
- KI-Entscheidungslogik

---

## 📁 Projektstruktur

```
src/
├── components/
│   ├── Card.tsx           # Karten-Komponente mit Animationen
│   ├── GameBoard.tsx      # Hauptspiel-UI
│   ├── PlayerHand.tsx     # Spieler-Hand-Anzeige
│   └── ui/                # shadcn/ui Komponenten
├── hooks/
│   ├── useGameWithAI.ts   # Spiel-Logic + KI-Integration
│   └── useSettings.ts     # Persistente Einstellungen
├── lib/
│   ├── gameLogic.ts       # Spiele-Regeln & State-Machine
│   ├── aiPlayer.ts        # KI-Entscheidungslogik
│   ├── sounds.ts          # Web Audio API Sound-Engine
│   └── settings.ts        # Globale Settings-Referenz
├── types/
│   └── game.ts            # TypeScript Interfaces
└── App.tsx                # Root-Komponente
```

---

## 📝 Lizenz

MIT

---

> Gebaut mit ❤️ und viel ☕ — viel Spaß beim Spielen!
