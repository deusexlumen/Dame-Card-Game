# DAME – Gedächtnis, Risiko & Bluff

Ein Kartenspiel für 2–6 Spieler in der **Egoperspektive an einem 3D-Casinotisch**. Du sitzt in einem dunklen Hinterzimmer unter einer Hängelampe, deine Gegner sitzen mit dir am Tisch, und deine eigene Hand zieht, hält und legt die Karten.

**Live spielen:** https://deusexlumen.github.io/Dame-Card-Game/
**English version:** [README_EN.md](./README_EN.md)

---

## Was ist DAME?

Ein taktisches Gedächtnis-Kartenspiel mit Bluff. Deine eigenen Karten liegen verdeckt vor dir, du kennst sie nur aus dem Gedächtnis.

- Jeder bekommt **4 verdeckte Karten** und darf sich **2** davon ansehen.
- Ziehe, tausche, lege ab und merke dir, was wo liegt.
- Ab Runde 3 darfst du **„Dame“ rufen**, wenn du glaubst, die wenigsten Punkte zu haben.
- Fehler kosten **genau eine Strafkarte**. Über 50 Punkte scheidest du aus.

Die verbindlichen Regeln stehen in [`CONCEPT_DECISIONS.md`](./CONCEPT_DECISIONS.md), die volle Anleitung auch im Spiel (Menü „Regeln“ oder Taste **H** am Tisch).

## Features

- **3D-Tisch in Egoperspektive** mit echten Figuren (Sitz-Animationen, Hände auf dem Tisch, greifen nach Stapel und Ablage) und eigener Hand mit beweglichen Fingern. Umschaltbar auf eine klassische 2D-Ansicht.
- **2–6 Spieler**, Mensch gegen KI (3 Stufen) oder Hot-Seat an einem Gerät. Ab 5 Spielern zwei Decks.
- **Casino-Look**: Kartengrafiken, Hinterzimmer mit Bar, Chip-Stapel, Gold-Theme.
- **Besondere Momente**: Dame-Ruf mit rotem Puls, Karten drehen sich nacheinander um, Punkte zählen hoch, Konfetti beim Sieg.
- **Shop** nur für Kosmetik (Kartenrücken, Kartenvorderseiten, Tischfilz), bezahlt mit Chips, die du durchs Spielen verdienst. Schnellauswahl im Pausenmenü.
- **Sound und Musik**: echte Kartengeräusche und ein ruhiger Jazz-Loop.
- **Deutsch und Englisch**, Zugtimer (Strafkarte bei Zeitablauf), Statistik, Speichern und Fortsetzen.
- **Web und Windows**. Im Browser als App installierbar, per Maus, Tastatur oder Touch spielbar.

## Tasten

| Taste | Aktion |
|---|---|
| 1–6 | Karte wählen |
| Leertaste | Vom Stapel ziehen |
| Enter | Bestätigen / Zug beenden |
| A | Gezogene Karte ablegen |
| X | Extra ablegen |
| D | Dame rufen |
| H | Anleitung |
| Esc | Abbrechen / Menü |

## Entwicklung

Das Spiel ist ein Godot-4.7-Projekt in [`godot/`](./godot) (GL Compatibility). Die alte React-Fassung unter `src/` bleibt nur als Nachschlagewerk.

```bash
npm run test:godot       # Headless-Tests und Szenenfluss
npm run export:godot     # Windows (build/windows/Dame.exe) und Web (build/web)
npm run test:godot:web   # Web-Build im Browser prüfen (Playwright)
```

Godot-Pfad lokal per `GODOT_BIN` änderbar. Jeder Push auf `main` testet, exportiert und veröffentlicht den Web-Build auf GitHub Pages.

Werkzeuge für Assets liegen in `godot/tools/assets/` (Kartengrafiken, Raumtexturen, Kleidungsmasken).

## Credits

- Figuren und Animationen: [Quaternius](https://quaternius.com) (CC0)
- Kartengeräusche, Klicks, Jingles: [Kenney](https://kenney.nl) (CC0)
- Musik: „jazz improvisation looped“ von Alex McCulloch / Pro Sensory (CC0)
- Schriften: Inter und Playfair Display (SIL OFL), DejaVu (frei)
- WebRTC unter Windows/Linux: [webrtc-native](https://github.com/godotengine/webrtc-native) (MIT, per `npm run fetch:webrtc` geladen, nicht eingecheckt)

Details: `godot/assets/audio/CREDITS.txt`, `godot/assets/characters/LICENSE_*.txt`, `godot/assets/fonts/`, `godot/addons/webrtc/README.md`.
