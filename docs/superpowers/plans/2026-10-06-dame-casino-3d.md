# DAME — Casino-3D-Umbau (Godot)

**Ziel:** Das Godot-Spiel erfüllt alle Specs: Egoperspektive am 3D-Tisch mit echten Figuren und eigener Hand, Modern-Dark-Casino-Look überall, echte Sounds und Musik, Deutsch + Englisch, 2–6 Spieler, alle Effekte aus dem Visual-Polish-Plan.

**Quellen (alle gelesen 2026-10-06):** `docs/superpowers/specs/*`, alle Pläne in `docs/superpowers/plans/`, `CONCEPT_DECISIONS.md` (§9 = Entscheidungen vom 2026-10-06).

**Regel:** Der Terminal-/Phosphor-Look ist überholt. Nichts davon bleibt als Vorgabe.

## Meilensteine

| # | Inhalt | Status |
|---|---|---|
| C1 | Figuren (Quaternius UBC, CC0) mit Kleidung, Sitz-Animationen, eigener Arm mit Fingern statt Grundformen | erledigt |
| C2 | Casino-Look: Theme, Schriften, Menüs, Shop, Regeln, Statistik, Einstellungen; Bildröhren-Effekt raus; Raum/Tisch/Licht; Kartenfront klassisch, Kartenrücken im Casino-Stil | erledigt |
| C3 | Echte Sounds (CC0, z. B. Kenney Casino Audio) + Musikschleife als Datei, Niederlage-Sound | erledigt |
| C4 | Regeln: 2–6 Spieler, Decks = ⌈P/4⌉, 6 Plätze radial 60°; Zugtimer = Strafkarte + Zugende, Pause bei Bube/König; Feature-Flag `power_effects` (aus) | erledigt |
| C5 | Deutsch + Englisch, Locale-Keys, Umschalter in Einstellungen | erledigt |
| C6 | Ereignisse: Dame-Ruf (roter Puls, Countdown, alle Karten drehen, Punkte zählen hoch), Sieger-Feier (Konfetti, Gewinnerkarte, Balken), KI-denkt-Anzeige, Spielerwechsel-Überblendung, Anleitung im Spiel | erledigt |
| C7 | Shop: Kategorie Kartenvorderseiten statt Phosphor-Farbe, Kaufbestätigung, Skin-Schnellauswahl im Spiel | erledigt |
| C8 | Touch/Handy (Tippflächen ≥ 44 px, Layout), PWA im Web-Export, README auf Godot, Barrierefreiheit (zuletzt) | erledigt bis auf Barrierefreiheit (Screenreader) – zurückgestellt; Hochformat auf Handys wird nur skaliert |

## Prüfung je Meilenstein

`npm run test:godot`, Screenshot über `tools/shot.gd`, am Ende `npm run export:godot` und `npm run test:godot:web`.

## Abnahme

Jeder Punkt aus Abschnitt A und B der Prüfung vom 2026-10-06 ist erledigt und mit Screenshot oder Test belegt.
