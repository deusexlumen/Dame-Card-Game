<div align="center">

# ♛ DAME

**Memory. Risk. Bluff.**

A tactical card game for 2–6 players, seen **in first person at a 3D casino table**.  
You sit in a dark back room under a hanging lamp, your opponents sit at the table with you —  
and your own hand draws, holds and places the cards.

<br>

[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Live Demo](https://img.shields.io/badge/Live--Demo-GitHub%20Pages-2ea44f?style=for-the-badge&logo=github&logoColor=white)](https://deusexlumen.github.io/Dame-Card-Game/)
[![Platforms](https://img.shields.io/badge/Web%20%C2%B7%20Windows%20%C2%B7%20PWA-d4af37?style=for-the-badge)](#development)
[![Players](https://img.shields.io/badge/2--6%20players-6f42c1?style=for-the-badge)](#what-is-dame)
[![German · English](https://img.shields.io/badge/DE%20%C2%B7%20EN-b31b1b?style=for-the-badge)](#)
[![MIT License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](./LICENSE)

<br>

### [▶ Play it live](https://deusexlumen.github.io/Dame-Card-Game/)

*No installation needed — runs right in the browser. Installable as an app (PWA);  
play with mouse, keyboard or touch.*

**[Deutsche Version](./README.md)**

</div>

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/gameplay-3d.png" alt="First-person 3D casino table: three AI opponents, your own hand, chips" width="860">
  <br>
  <em>The table in first person — Lotte, Bruno and Erika are waiting for your move.</em>
</p>

<p align="center">
  <img src="docs/screenshots/main-menu.png" alt="DAME main menu" width="430">
  &nbsp;&nbsp;
  <img src="docs/screenshots/shop.png" alt="Shop with cosmetic card backs" width="430">
  <br>
  <em>Left: main menu in the casino back room · Right: cosmetics shop, paid with chips earned by playing</em>
</p>

<p align="center">
  <img src="docs/screenshots/pause-cosmetics.png" alt="Pause menu with quick picker for card backs, faces and table felt" width="560">
  <br>
  <em>The cosmetics quick picker, right in the pause menu.</em>
</p>

---

## What is DAME?

A tactical memory card game with bluffing: **Your own cards lie face down in front of you — you only know them from memory.**

- Everyone gets **4 face-down cards** and may look at **2** of them.
- Draw, swap, discard — and remember exactly what lies where.
- From round 3 you may **call “Dame”** if you think you have the fewest points.
- Mistakes cost **exactly one penalty card**. Above 50 points you are out — exactly 50 resets you to 0.

The binding rules are in [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md); the full guide is also in the game (menu “Rules” or key **H** at the table).

## Features

**🎰 The Table**
- **First-person 3D casino table** with real characters — sitting animations, hands on the table, reaching for deck and discard. Your own hand has moving fingers.
- A casino back room with a bar, chip stacks and a gold theme. Switchable to a classic **2D view**.
- **Big moments**: Dame call with a red pulse, cards flip one after another, points count up, confetti for the winner.

**🃏 The Game**
- **2–6 players** — human vs. AI (3 levels) or hot seat on one device. Two decks from 5 players on.
- Turn timer: take too long and you draw a penalty card.
- Statistics for matches, Dame calls, win rate — and **save & resume**.

**💰 Progress without Pay-to-Win**
- **Shop for cosmetics only**: card backs, card faces, table felt — paid with chips you earn by playing.
- Quick picker in the pause menu, without leaving the table.

**🔊 Sound & Languages**
- Real card sounds and a calm jazz loop.
- Fully localized in **German and English**.

## Keys

| Key | Action |
|---|---|
| `1`–`6` | Pick card |
| `Space` | Draw from deck |
| `Enter` | Confirm / end turn |
| `A` | Discard drawn card |
| `X` | Extra discard |
| `D` | Call Dame |
| `H` | How to play |
| `Esc` | Cancel / menu |

Or simply: **mouse or touch**.

## Online Multiplayer — In Progress

DAME is meant to be played online with friends — **without a dedicated server, at roughly 0 € cost**:

- **WebRTC peer-to-peer**, host-authoritative: one player runs the rules engine, guests only send actions and receive their view.
- **Room codes** (e.g. `KX7Q`) via free Supabase Realtime signaling — afterwards everything runs directly from peer to peer. Copy-paste codes as an emergency fallback.
- **Cross-platform**: web, Windows and Android — the game is identical everywhere.
- Honest limits: no TURN server in v1 (some NATs will fail), host leaving ends the match without scoring, no public matchmaking.

The full plan with architecture, costs and risks lives in [`docs/online-p2p-plan.md`](./docs/online-p2p-plan.md).

## Development

The game is a **Godot 4.7 project** in [`godot/`](./godot) (GL Compatibility). The old React version under `src/` is kept for reference only.

```bash
npm run test:godot       # headless tests and scene flow
npm run export:godot     # Windows (build/windows/Dame.exe) and web (build/web)
npm run test:godot:web   # check the web build in a browser (Playwright)
```

Override the Godot path with `GODOT_BIN`. Every push to `main` tests, exports and publishes the web build to GitHub Pages.

Asset tools live in `godot/tools/assets/` (card art, room textures, clothing masks).

## Credits

- Characters and animations: [Quaternius](https://quaternius.com) (CC0)
- Card sounds, clicks, jingles: [Kenney](https://kenney.nl) (CC0)
- Music: “jazz improvisation looped” by Alex McCulloch / Pro Sensory (CC0)
- Fonts: Inter and Playfair Display (SIL OFL), DejaVu (free)

Details: `godot/assets/audio/CREDITS.txt`, `godot/assets/characters/LICENSE_*.txt`, `godot/assets/fonts/`.
