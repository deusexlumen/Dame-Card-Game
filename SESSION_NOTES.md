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

### Nächster Einstieg
1. Export-Templates fehlen noch (nur `version.txt` in `%APPDATA%/Godot/export_templates/4.7.2.stable/`). Download per HTTP-Range nur der nötigen Dateien (`windows_release_x86_64*.exe`, `web_nothreads_*.zip`, `icudt_godot.dat`); Volldownload 1,28 GB war zu langsam, Range-Download wurde wegen RAM-Knappheit abgebrochen.
2. Dann `npm run export:godot` und `npm run test:godot:web`.
3. Offen (Nutzer): Push/PR von `feat/godot-release` (enthält auch `chore/p1-hardening`-Commits), Web-Veröffentlichung, ACCEPTANCE_LOG-Urteil.
