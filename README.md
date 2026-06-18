# ♛ DAME — Gedächtnis, Risiko & Bluff

[![Version](https://img.shields.io/badge/version-0.1.0--alpha-orange)](./)
[![Deploy](https://img.shields.io/github/deployments/deusexlumen/Dame-Card-Game/github-pages?label=deploy&logo=github)](https://deusexlumen.github.io/Dame-Card-Game/)
[![Build](https://img.shields.io/badge/build-passing-brightgreen?logo=githubactions)](https://github.com/deusexlumen/Dame-Card-Game/actions)
[![Tests](https://img.shields.io/badge/tests-57%2F57-brightgreen?logo=vitest)](./)
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-7-646CFF?logo=vite)](https://vitejs.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-3.4-06B6D4?logo=tailwindcss)](https://tailwindcss.com/)

> **Ein browserbasiertes Kartenspiel für 2–6 Spieler.**  
> Mensch gegen Mensch, Mensch gegen KI — komplett client-seitig, ohne Backend, ohne Tracking.

> 🚧 **Alpha-Version:** Das Spiel ist spielbar, aber Features, Balance und UI können sich noch ändern. Feedback ist willkommen!

🚀 **Live spielen:** https://deusexlumen.github.io/Dame-Card-Game/

🌐 **English version:** [README_EN.md](./README_EN.md)

---

## 🎴 Was ist DAME?

DAME ist ein taktisches Memory-Kartenspiel mit Bluff-Element. Du kennst deine eigenen Karten nie wirklich — nur das, was du dir merken kannst.

- Jeder Spieler bekommt **4 verdeckte Karten** und darf sich **nur 2** davon anschauen.
- Danach bleiben die Karten verdeckt liegen. Du musst dir **Position und Wert merken**.
- Ziehe, tausche, bluffe — und rufe zur richtigen Zeit **„Dame"**, um die Runde zu beenden.
- Fehler werden mit **Strafkarten** bestraft. Information ist alles.

Visuell fühlt sich DAME wie ein **Terminal eines archivierten Cyber-Systems** an: schwarzer Hintergrund, grüner Phosphor-Glow, geometrische Symbole, Monospace-Typografie.

---

## ✨ Features

|  |  |
|---|---|
| 🎮 **2–6 Spieler** | Mensch vs. Mensch oder mit KI-Gegnern |
| 🤖 **3 KI-Stufen** | Einfach, Mittel, Schwer — mit unterschiedlichen Aggressions- und Bluff-Strategien |
| 👁️ **Bube (J)** | Eigene oder gegnerische Karte anschauen |
| 👑 **König (K)** | Gegnerische Karte kurz aufdecken und gezielt tauschen |
| 🃏 **Dame (Q)** | Strafkarte beim Ablegen — und Zwangszug für den nächsten Spieler |
| ⚡ **Extra-Ablegen** | Passende Karten direkt mit ablegen |
| 📢 **Dame-Ansage** | Frühzeitig die Runde beenden — aber Vorsicht bei falschem Call |
| 🎯 **50-Punkte-Regel** | Über 50 = ausgeschieden, genau 50 = Reset auf 0 |
| 📊 **Statistiken** | Lokale Spielstatistiken im Browser |
| 🔊 **Sound & Musik** | Prozedurale Web-Audio-Sounds, abschaltbare Ambient-Musik |
| 🎬 **Animationen** | Framer-Motion-Übergänge für Karten und UI |
| ♿ **Barrierefrei** | Tastatursteuerung, ARIA-Labels, Screenreader-Support |

---

## 🕹️ Schnellstart

```bash
# 1. Repo klonen
git clone https://github.com/deusexlumen/Dame-Card-Game.git
cd Dame-Card-Game

# 2. Dependencies installieren (pnpm)
pnpm install

# 3. Dev-Server starten
pnpm dev

# 4. Tests laufen lassen
pnpm test
```

Fertig! Der Server läuft meist unter `http://localhost:5173/Dame-Card-Game/`.

---

## 📋 Die wichtigsten Regeln

1. **Aufbau:** 4 verdeckte Karten pro Spieler, 2 davon kurz anschauen.
2. **Zug:** Ziehe vom Zieh- oder Ablagestapel. Entscheide: behalten, tauschen oder ablegen.
3. **Extra-Ablegen:** Hast du eine Karte mit gleichem Wert wie die oberste Ablagekarte, darfst du sie sofort ablegen.
4. **Sonderkarten:**
   - **Dame (Q)** → Strafkarte beim Ablegen; offene Dame muss vom nächsten Spieler genommen werden.
   - **Bube (J)** → Beliebige verdeckte Karte anschauen.
   - **König (K)** → Gegnerische Karte anschauen und gezielt tauschen.
5. **Dame-Ansage:** Wer glaubt, die wenigsten Punkte zu haben, ruft „Dame". Liegt er falsch, startet er die nächste Runde mit **5 statt 4 Karten**.

Die vollständigen Konzept-Entscheidungen findest du in [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md).

---

## ⌨️ Tastatursteuerung

| Taste | Aktion |
|---|---|
| `Leertaste` | Karte ziehen / Gezogene Karte ablegen |
| `1` – `4` | Hand-Karte auswählen |
| `Enter` | Tausch bestätigen |
| `D` | Dame rufen |
| `Z` / `E` | Zug beenden |
| `Esc` | Dialog schließen |

---

## 🛠️ Tech Stack

- **Framework:** React 19
- **Language:** TypeScript 5.9
- **Build:** Vite 7
- **Styling:** Tailwind CSS 3.4 + shadcn/ui
- **Animationen:** Framer Motion
- **Sound:** Web Audio API
- **Tests:** Vitest + jsdom
- **Linting:** ESLint 9

---

## 🌍 Deployment

Jeder Push auf `main` wird automatisch auf **GitHub Pages** deployt.

- **Live-URL:** https://deusexlumen.github.io/Dame-Card-Game/
- **Workflow:** [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml)
- **Base-Pfad:** `/Dame-Card-Game/`

---

## 🧪 Tests

```bash
pnpm vitest run   # Tests einmalig ausführen
pnpm test:ui      # Tests mit UI-Oberfläche
```

Abgedeckt werden:
- Spielmechaniken (Ziehen, Tauschen, Ablegen)
- Sonderkarten-Effekte (Bube, König, Dame)
- Dame-Ansage & Strafsystem
- KI-Entscheidungslogik pro Schwierigkeitsgrad

---

## 📸 Screenshot

![DAME Spieltisch](./docs/screenshot.png)

---

## 📝 Lizenz

**Alle Rechte vorbehalten.**  
Der Quellcode, das Design, die Spielmechanik und alle Assets dieses Projekts sind proprietär.  
Eine Nutzung, Vervielfältigung, Verbreitung oder Modifikation ohne ausdrückliche Genehmigung ist nicht gestattet.

> Gebaut mit ❤️, ☕ und viel grünem Phosphor-Glow.
