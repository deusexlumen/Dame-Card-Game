# DAME – Memory, Risk & Bluff

A card game for 2–6 players, seen **in first person at a 3D casino table**. You sit in a dark back room under a hanging lamp, your opponents sit at the table with you, and your own hand draws, holds and places the cards.

**Play live:** https://deusexlumen.github.io/Dame-Card-Game/
**Deutsche Version:** [README.md](./README.md)

---

## What is DAME?

A tactical memory card game with bluffing. Your own cards lie face down in front of you; you only know them from memory.

- Everyone gets **4 face-down cards** and may look at **2** of them.
- Draw, swap, discard and remember what lies where.
- From round 3 you may **call “Dame”** if you think you have the fewest points.
- Mistakes cost **exactly one penalty card**. Above 50 points you are out.

The binding rules are in [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md); the full guide is also in the game (menu “Rules” or key **H** at the table).

## Features

- **First-person 3D table** with real characters (sitting animations, hands on the table, reaching for deck and discard) and your own hand with moving fingers. Switchable to a classic 2D view.
- **2–6 players**, human vs. AI (3 levels) or hot seat on one device. Two decks from 5 players on.
- **Casino look**: card art, back room with a bar, chip stacks, gold theme.
- **Big moments**: Dame call with a red pulse, cards flip one after another, points count up, confetti for the winner.
- **Shop** for cosmetics only (card backs, card faces, table felt), paid with chips you earn by playing. Quick picker in the pause menu.
- **Sound and music**: real card sounds and a calm jazz loop.
- **German and English**, turn timer (penalty card when time runs out), statistics, save and resume.
- **Web and Windows**. Installable as an app in the browser; play with mouse, keyboard or touch.

## Keys

| Key | Action |
|---|---|
| 1–6 | Pick card |
| Space | Draw from deck |
| Enter | Confirm / end turn |
| A | Discard drawn card |
| X | Extra discard |
| D | Call Dame |
| H | How to play |
| Esc | Cancel / menu |

## Development

The game is a Godot 4.7 project in [`godot/`](./godot) (GL Compatibility). The old React version under `src/` is kept for reference only.

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
