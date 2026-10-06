# Session Notes

## 2026-10-04
- Godot (`godot/`) ist Hauptprojekt. React (`src/`) nur Nachschlagewerk.
- Regeln: Godot-Code + `CONCEPT_DECISIONS.md` gelten (König: ansehen + blind tauschen; Ass/Zehn ohne Wirkung).
- Engine: Godot 4.7.2 (`C:/Users/Buxe/tools/Godot/`), Export-Templates 4.7.2.
- Ökonomie: Chips nur kosmetisch; Echtgeld später über `PurchaseProvider`, jetzt Stub.
- Export: Windows + Web (ohne Threads). Android später.
- Bauplan: `docs/superpowers/plans/2026-10-04-dame-godot-bauplan.md`, Abschnitt „Stand und Abweichungen“.
- Branch `feat/godot-release`: M0–M7 umgesetzt. Tests: `npm run test:godot`, Export: `npm run export:godot`, Web-Smoke: `npm run test:godot:web`.
- Regeldetails: Runde + Safe Phase je Ausgabe neu; Spielende auch ohne Menschen im Spiel; Statistik/Chips nur bei genau einem Menschen; Standardname „Spieler“.
- Tests/Screenshots schreiben nur `user://test_*` (App.use_test_storage).
- Offen (Nutzer): Push/PR, Web-Veröffentlichung, Echtgeld-Anbieter, Multiplayer.

### Nächster Einstieg (geplant 2026-10-06)
Plan: `docs/superpowers/plans/2026-10-06-godot-pages-release.md`. Ziel: Godot-Web-Build live auf GitHub Pages.
- Entschieden: Pages zeigt **nur Godot**, React-Deploy in `deploy.yml` fällt weg (React-Code bleibt im Repo).
1. Export-Templates per HTTP-Range, direkt auf Platte streamen (letzter Versuch scheiterte an RAM). Fallback: Web-Build aus CI-Artefakt.
2. `npm run test:godot`, `npm run export:godot`, `npm run test:godot:web`.
3. `deploy.yml` auf Godot umbauen (Godot + Templates, Tests, Web-Export, Smoke, Pages-Deploy).
4. Push, PR, erste CI fixen, Merge nach `main` nur nach Go.
5. Live-URL prüfen, Notizen + AGENTS.md aktualisieren.

## 2026-10-06
- Export-Templates per HTTP-Range geholt (Skript streamt nur Windows- + Web-nothreads-Einträge direkt auf Platte, ~120 MB statt 1,28 GB). Liegen in `%APPDATA%/Godot/export_templates/4.7.2.stable/`.
- Lokal grün: `test:godot` (565 Checks), `export:godot` (Dame.exe 110 MB + Web), `test:godot:web`.
- Fix: kaputte Regex in `scripts/serve-static.mjs` (Web-Smoke startete nicht).
- `deploy.yml` neu: nur Godot (Tests, Export, Web-Smoke, Pages-Deploy). React-Jobs entfernt.
- Pages-Quelle ist bereits „GitHub Actions“.
- PR #4 gemergt (Merge-Commit), `Deploy to GitHub Pages` beim ersten Lauf grün.
- **Live:** https://deusexlumen.github.io/Dame-Card-Game/ (Web-Smoke live bestanden).
- Web-Smoke nutzt jetzt `goto('./')`, damit er auch unter Unterpfaden läuft.
- Offen: Echtgeld-Anbieter, Multiplayer, Android. CI-Warnung: Actions auf Node 20 veraltet, `ubuntu-latest` wechselt ab 2026-10-19 auf Ubuntu 26.
- PR #4 offen, CI grün. Konflikte mit main gelöst: main hatte nur ältere Stände (Squash von p1-hardening, doppelter Godot-Stufe-1-Commit) → Branch-Stand behalten, CLAUDE.md + 10x-Notizen übernommen, alte round_check-Dateien wieder entfernt.
