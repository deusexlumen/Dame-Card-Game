# Nächste Session: Godot-Build bis online auf GitHub Pages

## Context
M0–M7 sind auf `feat/godot-release` fertig, aber es gibt noch keinen Build: Export-Templates fehlen (nur `version.txt` in `%APPDATA%/Godot/export_templates/4.7.2.stable/`), `build/` existiert nicht, die CI lief noch nie. Ziel: spielbarer Windows-Build lokal, Godot-Web-Build öffentlich auf GitHub Pages. Entscheidung des Nutzers: **Pages zeigt nur noch Godot**, der React-Deploy entfällt (React-Code bleibt im Repo als Nachschlagewerk). Repo ist öffentlich.

## Schritte

### 1. Export-Templates lokal (RAM-schonend)
- Per HTTP-Range nur die nötigen Einträge aus `Godot_v4.7.2-stable_export_templates.tpz` holen: `windows_release_x86_64.exe` (+ ggf. `_console.exe`), `web_nothreads_release.zip`, `icudt_godot.dat`.
- Vorgehen: Zip-Central-Directory (Ende der Datei) per Range lesen, Offsets ermitteln, jeden Eintrag einzeln per `curl -r` **direkt auf die Platte** streamen und entpacken. Kein Puffern im RAM (letzter Versuch scheiterte daran).
- Skript im Scratchpad, Download in eigenen leeren Ordner, Ziel `%APPDATA%/Godot/export_templates/4.7.2.stable/`.
- Fallback, wenn Range scheitert: Lokalen Export überspringen und den Web-Build aus der CI (Artefakt `dame-web`) nehmen.

### 2. Lokal exportieren und prüfen
- `npm run test:godot` (Baseline grün).
- `npm run export:godot` → `build/windows/Dame.exe`, `build/web/index.html`, Windows-Smoke.
- `npm run test:godot:web` (Playwright, Chromium).
- Nutzer spielt die `.exe` einmal kurz an.

### 3. Pages-Workflow auf Godot umstellen
- `.github/workflows/deploy.yml` neu: Trigger `push` auf `main` + `workflow_dispatch`. Jobs:
  1. Godot 4.7.2 + Templates installieren (Block aus `godot.yml:45-55` wiederverwenden), Headless-Tests (`node scripts/godot-test.mjs`).
  2. Web-Export + Web-Smoke (`godot-export.mjs --skip-smoke`, `playwright test -c playwright.godot.config.ts`), dann `actions/upload-pages-artifact@v3` mit `path: build/web`.
  3. `actions/deploy-pages@v4` (wie bisher).
- React-Jobs (pnpm test, build, e2e) aus `deploy.yml` entfernen. Prüfen, ob React-Tests anderswo laufen sollen, sonst bewusst weglassen.
- Optional: `godot.yml` behält Tests + Artefakte für PRs; doppelte Template-Downloads hinnehmen (KISS).
- Web-Preset ist ohne Threads → kein COOP/COEP-Header nötig, Pages reicht.

### 4. Push, PR, Merge (jeweils mit Bestätigung)
- `feat/godot-release` pushen (enthält auch `chore/p1-hardening`-Commits).
- PR nach `main` öffnen, erste CI abwarten, rote Jobs fixen.
- Merge nach `main` nur nach Go des Nutzers → Deploy läuft.
- Repo-Einstellung prüfen: Pages-Quelle = „GitHub Actions“ (`gh api repos/deusexlumen/Dame-Card-Game/pages`).

### 5. Abschluss
- Live-URL im Browser öffnen, Start + erster Klick + eine Runde prüfen (Audio erst nach Interaktion ist erwartet).
- `SESSION_NOTES.md` + Bauplan-Abschnitt „Stand und Abweichungen“ aktualisieren, `AGENTS.md`-Deployment-Abschnitt auf Godot umschreiben.
- ACCEPTANCE_LOG-Zeile vorschlagen (Nutzer diktiert Urteil).

## Kritische Dateien
- `.github/workflows/deploy.yml` (neu schreiben), `.github/workflows/godot.yml` (Vorlage)
- `scripts/godot-export.mjs`, `godot/export_presets.cfg` (Web → `build/web/index.html`)
- `playwright.godot.config.ts`, `e2e-godot/`
- `SESSION_NOTES.md`, `AGENTS.md`

## Verifikation
- Lokal: `npm run test:godot`, `npm run export:godot`, `npm run test:godot:web` grün.
- CI: Workflows `Godot` und `Deploy to GitHub Pages` grün im PR bzw. auf `main`.
- Live: `https://deusexlumen.github.io/Dame-Card-Game/` lädt das Godot-Spiel, eine Runde spielbar.

## Risiken
- Range-Download kann wieder am RAM scheitern → Fallback CI-Artefakt.
- Erster CI-Lauf überhaupt: Fehler in `godot.yml` wahrscheinlich, Zeit einplanen.
- Merge nach `main` ersetzt die öffentliche React-Seite sofort.
