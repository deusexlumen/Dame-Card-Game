# DAME Godot — Bauplan bis Release-Build

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Vor jeder Godot-Arbeit Skill `dame-godot` laden.

**Goal:** Aus der Godot-Stufe 1 (`godot/`) ein fertiges Einzelspieler-/Hot-Seat-Spiel mit KI, Menüs, Speichern, Audio, Spielwährung und Shop machen und als Windows- und Web-Build exportieren.

**Architecture:** Regeln bleiben in `DameRules` (`RefCounted`, kein Node). Alles, was ein Spieler oder die KI sieht, läuft über eine Sicht-Projektion (`DameView`). Szenen rufen Regeln auf und zeigen nur die Projektion. Meta-Systeme (Einstellungen, Statistik, Profil/Währung, Spielstand) sind eigene `RefCounted`-Dienste mit `user://`-Dateien. Ein dünnes Autoload `App` hält nur Dienst-Instanzen und Szenenwechsel, keinen Spielzustand.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GL Compatibility, Headless-Tests per Szene, GitHub Actions.

**Spec:** Dieses Dokument (Abschnitt „Meilensteine“) plus `CONCEPT_DECISIONS.md` und `.claude/skills/dame-godot/`.

## Global Constraints

- Engine: Godot 4.7.2, `config/features=PackedStringArray("4.7", "GL Compatibility")`, Renderer `gl_compatibility`, 1280×720.
- Regelquelle: bestehender Godot-Code + `CONCEPT_DECISIONS.md`. React (`src/`) ist nur Nachschlagewerk, nicht verbindlich.
- Sonderkarten (verbindlich): Bube = beliebige verdeckte Karte ansehen, kein Tausch. König = eigene verdeckte Karte ansehen, dann blind mit Gegnerkarte tauschen, beide bleiben verdeckt. Ass und Zehn = keine Wirkung. Dame (Q, 0 Punkte) offen abgelegt = Strafkarte; ist nicht die Dame-Ansage.
- Genau 1 Strafkarte (`PENALTY_CARD_COUNT = 1`). Falsche Ansage: nächste Ausgabe 5 statt 4 Karten. Ansager gewinnt nur mit strikt weniger Punkten.
- Spieleranzahl: 2–4 Plätze (Tischlayout hat 4 Positionen). 5–6 nicht im Umfang.
- Regeln: kein `Node`, kein `get_tree()`, kein `await`, kein `randf()`; jede Mischung mit Seed.
- KI und UI lesen nur `DameView`, nie `rules.state`.
- Texte für Spieler und `last_action`: Deutsch. Bezeichner: Englisch. Kommentare: Deutsch.
- Speichern nur nach `user://`. Nie nach `res://`.
- ~~Kein Multiplayer.~~ **Seit 2026-10-06: Online-Multiplayer gewollt (nur live), siehe `CONCEPT_DECISIONS.md` §10/§11 und `docs/online-p2p-plan.md` (ersetzt die Hosting-Idee aus `.claude/docs/ai/dame/10x/session-3.md`).** Kein Echtgeld-Kauf im Build; nur Schnittstelle `PurchaseProvider` mit Stub.
- Ökonomie rein kosmetisch. Keine Spielvorteile kaufbar.
- Export: Windows Desktop (x86_64) und Web (ohne Threads, damit kein COOP/COEP-Header nötig ist).

## Review Focus

1. Hot-Seat-Wechsel: Handkarten des vorigen Spielers dürfen beim Platzwechsel keinen Frame sichtbar bleiben. → Test in M3.
2. Kaputte oder alte `user://`-Datei (Spielstand, Profil, Einstellungen): Spiel startet trotzdem mit Standardwerten, Datei wird nicht überschrieben, bevor sie gesichert ist. → Tests in M4/M6.
3. Leerer Nachziehstapel und leere Ablage gleichzeitig: Zug scheitert sauber mit deutscher Meldung, kein Absturz, keine verlorene Karte. → Test in M1.
4. Spiel endet mitten in Dame-Runde durch Ausscheiden (über 50): Gewinner wird korrekt bestimmt, Währung wird genau einmal gutgeschrieben. → Tests in M1/M6.
5. Web-Build ohne Tastatur-Fokus (erster Klick): Eingabe funktioniert nach Klick auf die Seite, Audio startet erst nach Nutzerinteraktion. → Smoke-Test in M7.

---

## Meilensteine (Übersicht)

Jeder Meilenstein endet mit grünen Headless-Tests, einem Commit und einem spielbaren Stand. M0 ist unten im Detail ausgeplant. M1–M7 bekommen ihren Detailplan erst beim Start (`docs/superpowers/plans/2026-10-04-dame-godot-mN-*.md`), weil jeder Meilenstein die Schnittstellen des nächsten festlegt.

| # | Name | Ergebnis |
|---|---|---|
| M0 | Fundament | Projekt auf 4.7, Skill und Doku passen zum Code, Test-Runner lokal + CI |
| M1 | Regelkern komplett | Spielende, Sieger, 2–4 Plätze, Zonen-Prüfung, Spielstand serialisierbar |
| M2 | Sicht + KI | `DameView`, KI liest nur Sicht, drei Stufen, mehrere KI-Plätze |
| M3 | Spieltisch-UI | Neuer Tisch aus Control-Szenen, Tastatur + Maus, Hot-Seat-Overlay, Runden-/Spielende-Screen, Animationen, Phosphor-Theme |
| M4 | Meta-Screens | Hauptmenü, Spiel-Setup, Regeln, Einstellungen, Statistik, Fortsetzen, Zugtimer |
| M5 | Audio | Soundeffekte + Musik, Lautstärke aus Einstellungen |
| M6 | Ökonomie + Shop | Chips verdienen, Shop für Kartenrücken/Tisch/Farben, Inventar, `PurchaseProvider`-Stub |
| M7 | Release-Build | Export-Presets Windows + Web, Icon, Version, Export-Skript, Smoke-Tests, CI-Artefakte |

### M1 — Regelkern komplett

- `phase = "game_over"` wird gesetzt, sobald nach einer Runde höchstens ein Spieler übrig ist. `state.winner_index` gesetzt. Endet kein Spieler über 50, läuft das Spiel weiter.
- `start_match` nimmt `seat_count` 2–4 und `ai_seats: Array[int]` statt `ai_seat`. `SEAT_COUNT` wird Zustandswert.
- `assert_zones() -> bool`: jede Karten-ID genau einmal in Stapel, Hand, Ablage, Strafkarten oder gezogener Karte; 52 IDs gesamt. Wird nach jedem `apply_action` in Tests geprüft.
- Leerer Stapel: Ablage außer oberster Karte wird mit Seed gemischt; beides leer ⇒ `_fail("Keine Karten mehr")`.
- Automatische Dame-Ansage, wenn Hand nach erlaubtem Extra-Ablegen leer ist.
- `to_dict()` / `from_dict(d) -> bool` mit `save_version`. Ungültige Daten ⇒ `false`, Zustand unverändert.
- Tests aufgeteilt: `tests/test_deal.gd`, `test_draw.gd`, `test_powers.gd`, `test_dame_call.gd`, `test_scoring.gd`, `test_save.gd`, gestartet von `tests/run_all.gd`.

### M2 — Sicht + KI

- `scripts/dame_view.gd`: `static func for_viewer(rules: DameRules, viewer_seat: int) -> Dictionary` übernimmt `display_state`. `display_state` bleibt als Weiterleitung, bis M3 den alten Tisch ersetzt.
- Sicht enthält zusätzlich `known_cards`: für den Betrachter bekannte Karten fremder Plätze (aus Bube/König-Gedächtnis).
- `scripts/dame_policy.gd`: `static func choose(view: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> Dictionary`. Einfach = zufällig erlaubt. Mittel = Logik aus heutigem `dame_ai.gd`. Schwer = Punkte-Schätzung unbekannter Karten, gezielter König gegen Führenden, Ansage nur bei geschätzter Führung.
- `dame_ai.gd` wird zum Treiber: holt Sicht, fragt Policy, wendet an. Test: Policy-Signatur akzeptiert kein `DameRules`; Test mit manipulierter fremder Hand ändert Entscheidung nicht.

### M3 — Spieltisch-UI

- `scenes/card_slot.tscn` (Control): Vorder-/Rückseite aus Sicht-Daten, Fokus-Rahmen, Klick-Signal `pressed(index)`.
- `scenes/seat.tscn`: Name, Punkte, Hand mit bis zu 6 Slots, Strafkarten-Zähler.
- `scenes/table.tscn` neu als Control (Vollbild): Stapel, Ablage, 4 Sitzpositionen, Aktionsleiste, Protokoll. Hauptszenenpfad bleibt gleich; Hauptszene wird in M4 auf Menü umgestellt.
- Tasten wie Web: `1–4` Slot, `Leertaste` ziehen, `Enter` bestätigen, `D` Dame, `Z`/`E` Ansehen zurück, `Esc` abbrechen. Fokus bleibt nach Neuzeichnen.
- Hot-Seat: Overlay „Gerät an X weitergeben“ verdeckt Tisch; Sicht wird vor dem Overlay geleert.
- KI-Züge mit `Timer` im Tisch, Tempo aus Einstellungen. Animationen per `Tween` auf Slot-Nodes.
- Phosphor-Theme: `themes/phosphor.tres`, schwarz, grün, Monospace-Schrift (OFL, z. B. „VT323“ oder „IBM Plex Mono“) unter `assets/fonts/`.
- `round_check.tscn` testet weiter nur Regeln; UI-Test: `tests/test_table_view.gd` instanziert Tisch headless und prüft, dass fremde Ränge nie in Labels stehen.

### M4 — Meta-Screens

- Autoload `App` (`scripts/app.gd`): Dienste `settings`, `stats`, `profile`, `saves`; `goto(scene_path)`.
- `scenes/main_menu.tscn`: Neues Spiel, Fortsetzen (nur bei Spielstand), Hot-Seat, Regeln, Statistik, Shop (ab M6), Einstellungen, Beenden (nicht im Web).
- `scenes/setup.tscn`: Platzanzahl 2–4, je Platz Mensch/KI, KI-Stufe, Namen.
- `scripts/settings_service.gd` → `user://settings.cfg` (`ConfigFile`): Sound, Musik, Lautstärken, KI-Tempo, Animationen, Zugtimer an/aus + Sekunden (15/30/60).
- `scripts/stats_service.gd` → `user://stats.json`: Felder wie React `stats.ts`.
- `scripts/save_service.gd` → `user://save.json`: speichert nach jedem Zug `rules.to_dict()`; Fortsetzen lädt per `from_dict`.
- Zugtimer: läuft im Tisch; Ablauf ⇒ Mensch zieht automatisch vom Stapel und legt ab.
- Hauptszene wird `res://scenes/main_menu.tscn` (bewusste Abweichung vom Skill; Skill wird nachgezogen).

### M5 — Audio

- Effekte: Ziehen, Ablegen, Umdrehen, Dame-Ansage, Sieg, Strafkarte. Musik: eine ruhige Schleife.
- Quelle: CC0-Dateien (`.ogg`) unter `assets/audio/` mit `assets/audio/LICENSES.md`; falls keine passenden gefunden werden, mit `tools/gen_sfx.gd` synthetisch erzeugen (wie React `sounds.ts`).
- Audiobusse `Music` und `SFX` in `default_bus_layout.tres`; Autoload `App` hält `AudioPlayer`. Web: Musik startet erst nach erster Eingabe.

### M6 — Ökonomie + Shop

Strategie (entschieden): **eine weiche Währung „Chips“, nur kosmetisch, durch Spielen verdient**. Echtgeld später als zweiter Weg zu denselben Artikeln oder als Chip-Pakete, nie als einziger Weg. Begründung: Ein Bluff-/Gedächtnisspiel lebt von Fairness; kaufbare Vorteile würden es zerstören. Kosmetik + verdiente Währung ist im Spielemarkt üblich und hält den Shop ohne Zahlungsanbieter testbar.

- Verdienst: Runde gespielt +5, richtige Dame-Ansage +20, Spiel gewonnen +50 (gegen KI Schwer ×2). Gutschrift genau einmal pro Ereignis (Ereignis-ID im Profil).
- Artikel: Kartenrücken, Tischfarbe, Phosphor-Farbe (grün/bernstein/blau), Kartenfront-Schrift. Je Kategorie ein Gratis-Standard.
- `scripts/catalog.gd` (statische Artikelliste), `scripts/profile_service.gd` → `user://profile.json` (Chips, Besitz, Ausgerüstet, Ereignis-IDs).
- `scripts/purchase_provider.gd` (Basisklasse) mit `ChipProvider` (aktiv) und `RealMoneyProviderStub` (gibt immer „Nicht verfügbar“ zurück). Shop-UI ruft nur die Basisklasse.
- `scenes/shop.tscn`: Kategorien, Vorschau, Kaufen/Ausrüsten, Kontostand.

### M7 — Release-Build

- Export-Templates 4.7.2 installieren (`%APPDATA%/Godot/export_templates/4.7.2.stable/`).
- `godot/export_presets.cfg`: „Windows Desktop“ → `build/windows/Dame.exe`, „Web“ → `build/web/index.html`, Threads aus.
- Icon `assets/icon.svg`, `application/config/version="1.0.0"`, Windows-Metadaten (Produktname, Firma „Buxe“).
- `scripts/export.mjs`: exportiert beide Presets headless (`--export-release`).
- Smoke-Tests: Windows-Exe startet mit `--headless --quit-after 300` ohne Fehler; Web-Build per lokalem Server + Playwright (`e2e/godot-web.spec.ts`): Seite lädt, Canvas sichtbar, keine Konsolenfehler.
- CI `.github/workflows/godot.yml`: Tests + Export, Builds als Artefakte. Optional Web-Build auf itch.io/GitHub Pages (eigener Schritt, nur nach Freigabe).

---

## M0 — Detailplan

### Task 1: Projekt auf Godot 4.7

**Files:**
- Modify: `godot/project.godot:15`

**Interfaces:**
- Consumes: —
- Produces: Projekt-Feature `4.7`; alle späteren Tasks testen mit `Godot_v4.7.2-stable_win64_console.exe`.

- [ ] **Step 1: Baseline-Test laufen lassen**

Run: `/c/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot res://scenes/round_check.tscn`
Expected: letzte Zeile `STUFE1_OK`, Exit 0.

- [ ] **Step 2: Feature-Zeile ändern**

In `godot/project.godot`:

```ini
config/features=PackedStringArray("4.7", "GL Compatibility")
```

- [ ] **Step 3: Test erneut + Diff prüfen**

Run: Befehl aus Step 1, dann `git diff --stat`
Expected: `STUFE1_OK`; Diff nur `godot/project.godot` (1 Zeile). Andere geänderte Dateien ⇒ prüfen, nicht blind committen.

- [ ] **Step 4: Commit**

```bash
git add godot/project.godot
git commit -m "chore(godot): Projekt auf Godot 4.7 umstellen"
```

### Task 2: Skill und Konzept an den Code angleichen

**Files:**
- Modify: `.claude/skills/dame-godot/SKILL.md`
- Modify: `.claude/skills/dame-godot/references/rules.md`
- Rename: `.claude/skills/dame-godot/references/gdscript-45.md` → `gdscript-47.md`
- Modify: `.claude/skills/dame-godot/references/INDEX.md`, `references/architecture.md`, `references/ui.md` (Links `[[gdscript-45]]` → `[[gdscript-47]]`)
- Modify: `.claude/skills/dame-godot/CHANGELOG.md`
- Modify: `CONCEPT_DECISIONS.md` (neuer Abschnitt 6)

**Interfaces:**
- Produces: Skill beschreibt Godot 4.7 und die tatsächliche Dateistruktur; spätere Meilensteine laden diesen Skill.

- [ ] **Step 1: SKILL.md anpassen**

Ersetzen:
- Satz „Godot 4.5, GL Compatibility …“ → „Godot 4.7, GL Compatibility, main scene `res://scenes/table.tscn` (ab M4 `res://scenes/main_menu.tscn`), 1280×720.“
- „Read `references/gdscript-45.md` when an API call fails or a 4.7 snippet appears.“ → „Read `references/gdscript-47.md` when an API call fails.“
- Hard stop 7 → „7. Engine is Godot 4.7.2. `config/features=PackedStringArray("4.7", "GL Compatibility")`. Do not switch renderer.“
- Neuer Hard stop 9 → „9. Rules source is the existing Godot code plus `CONCEPT_DECISIONS.md`. The React tree is reference only. Jack: peek any face-down card. King: peek own card, then blind swap with opponent. Ace and Ten: no effect.“
- Build order Schritt 1 → „Read `godot/project.godot`. If features are not 4.7, stop and report the version.“
- Build order Schritte 2–7 ersetzen durch: „2. Follow the milestone plan in `docs/superpowers/plans/2026-10-04-dame-godot-bauplan.md`.“
- File map ersetzen:

```markdown
| Path | Owns |
|---|---|
| `scripts/dame_rules.gd` | State, zones, transitions (`DameRules`, RefCounted) |
| `scripts/dame_view.gd` | Public projection for a viewer seat (M2) |
| `scripts/dame_policy.gd` | Easy / medium / hard. Reads a view, returns an action (M2) |
| `scripts/dame_ai.gd` | Drives one AI turn via view + policy |
| `scripts/table_view.gd` + `scenes/table.tscn` | Table layout and input |
| `scripts/round_check.gd` + `scenes/round_check.tscn` | Headless rule checks (until M1 `tests/run_all.gd`) |
```

- `[[gdscript-45]] — 4.5 traps …` → `[[gdscript-47]] — engine traps that break this port`

- [ ] **Step 2: rules.md anpassen**

- Zeile „Oracle: `src/lib/gameLogic.ts` … On conflict, the TypeScript wins.“ → „Source of truth: `godot/scripts/dame_rules.gd` and `CONCEPT_DECISIONS.md`. `src/lib/gameLogic.ts` is reference only.“
- Tabelle „Power cards“ ersetzen:

```markdown
| Card | Resolution |
|---|---|
| J | Peek any face-down slot, own or opponent. Store in viewer memory. No swap. |
| K | Peek one own face-down slot, then blind swap it with one opponent slot. Opponent card stays unseen. Both end face-down. |
| A | No effect. Normal rank, 1 point. |
| 10 | No effect. Normal rank, 10 points. |
| Q | Open queen on discard forces the next drawer to take it (outside safe phase) and gives one penalty card. |
```

- Abschnitt „Dame call“: „Caller wins the call if caller total ≤ lowest other total.“ → „Caller wins only with strictly fewer points than every other living player. Equal ⇒ wrong call.“
- „2–6 players“ → „2–4 seats“.

- [ ] **Step 3: gdscript-Referenz umbenennen und Kopf anpassen**

```bash
git mv .claude/skills/dame-godot/references/gdscript-45.md .claude/skills/dame-godot/references/gdscript-47.md
```

Frontmatter-`description` → `"Godot 4.7 and GL Compatibility traps for DAME. Read when a node call returns null or an API call fails."`. Überschrift → `# Godot 4.7 traps`. Satz „Project features are `4.5` … not authoritative here.“ → „Project features are `4.7` and `GL Compatibility`.“

Run: `grep -rn "gdscript-45\|4\.5" .claude/skills/dame-godot`
Expected: keine Treffer mehr (außer CHANGELOG-Historie). Treffer in INDEX/architecture/ui ersetzen.

- [ ] **Step 4: CHANGELOG + CONCEPT_DECISIONS**

`CHANGELOG.md` oben ergänzen:

```markdown
## 2026-10-04
- Engine 4.5 → 4.7. Regeln folgen Godot-Code + CONCEPT_DECISIONS. File map an echte Dateien angepasst.
```

`CONCEPT_DECISIONS.md` am Ende ergänzen:

```markdown
## 6. Sonderkarten (Godot-Fassung, verbindlich)

- **Bube:** Beim Ablegen eine beliebige verdeckte Karte ansehen (eigene oder fremde). Kein Tausch.
- **König:** Eine eigene verdeckte Karte ansehen, dann blind mit einer gegnerischen Karte tauschen. Die Gegnerkarte bleibt ungesehen, beide liegen danach verdeckt.
- **Ass und Zehn:** Keine Sonderwirkung.
- **Dame-Ansage:** Ansager gewinnt nur mit strikt weniger Punkten als jeder andere. Gleichstand = falsch.
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/dame-godot CONCEPT_DECISIONS.md
git commit -m "docs(skill): dame-godot an Godot 4.7 und echte Regeln angleichen"
```

### Task 3: Test-Runner lokal und in CI

**Files:**
- Create: `scripts/godot-test.mjs`
- Modify: `package.json` (Script `test:godot`)
- Create: `.github/workflows/godot.yml`

**Interfaces:**
- Produces: `npm run test:godot` (Exit 0 nur bei `STUFE1_OK`); Umgebungsvariable `GODOT_BIN` überschreibt Pfad. M1 ersetzt Szene durch `tests/run_all.gd`, Runner bleibt.

- [ ] **Step 1: Runner schreiben**

`scripts/godot-test.mjs`:

```js
// Startet die Godot-Headless-Regeltests und prüft das Ergebnis.
import { spawnSync } from 'node:child_process';

const bin = process.env.GODOT_BIN
  ?? 'C:/Users/Buxe/tools/Godot/Godot_v4.7.2-stable_win64_console.exe';
const scene = process.argv[2] ?? 'res://scenes/round_check.tscn';

const run = spawnSync(bin, ['--headless', '--path', 'godot', scene], {
  encoding: 'utf8',
});
process.stdout.write(run.stdout ?? '');
process.stderr.write(run.stderr ?? '');

if (run.error) {
  console.error(`Godot nicht startbar: ${run.error.message}`);
  process.exit(1);
}
const ok = run.status === 0 && /STUFE1_OK|ALL_TESTS_OK/.test(run.stdout ?? '');
process.exit(ok ? 0 : 1);
```

- [ ] **Step 2: npm-Script**

In `package.json` unter `scripts`:

```json
"test:godot": "node scripts/godot-test.mjs"
```

- [ ] **Step 3: Lokal prüfen (grün und rot)**

Run: `npm run test:godot`
Expected: `STUFE1_OK`, Exit 0.

Run: `GODOT_BIN=does-not-exist npm run test:godot`
Expected: `Godot nicht startbar: …`, Exit 1.

- [ ] **Step 4: CI-Workflow**

`.github/workflows/godot.yml`:

```yaml
name: Godot

on:
  push:
    paths: ['godot/**', 'scripts/godot-test.mjs', '.github/workflows/godot.yml']
  pull_request:
    paths: ['godot/**', 'scripts/godot-test.mjs', '.github/workflows/godot.yml']

jobs:
  rules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Install Godot 4.7.2
        run: |
          curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
          unzip -q godot.zip
          echo "GODOT_BIN=$PWD/Godot_v4.7.2-stable_linux.x86_64" >> "$GITHUB_ENV"
      - name: Import project
        run: $GODOT_BIN --headless --path godot --import || true
      - name: Rule tests
        run: node scripts/godot-test.mjs
```

Vorher prüfen: `curl -sI https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip | head -1` ⇒ `302`/`200`. Sonst Dateinamen auf der Release-Seite nachsehen und anpassen.

- [ ] **Step 5: Commit**

```bash
git add scripts/godot-test.mjs package.json .github/workflows/godot.yml
git commit -m "ci(godot): Headless-Regeltests lokal und in CI"
```

---

## Abnahme M0

- `npm run test:godot` grün auf 4.7.2.
- `grep -rn "4\.5" .claude/skills/dame-godot godot/project.godot` ohne Treffer (außer CHANGELOG).
- CI-Job „Godot“ grün nach Push.

---

## Stand und Abweichungen (2026-10-04)

Umgesetzt auf Branch `feat/godot-release`: M0–M6 komplett, M7 Export eingerichtet. Prüfen mit `npm run test:godot` (Suites + echter Szenenfluss), `npm run export:godot` (Windows + Web + Windows-Smoke), `npm run test:godot:web` (Web-Smoke in Chromium).

Abweichungen vom Plan, bewusst entschieden:

- **Detailpläne M1–M7** nicht als eigene Dateien geschrieben; Umsetzung direkt mit Tests je Meilenstein, Entscheidungen hier und in `SESSION_NOTES.md`.
- **Tests:** ein Einstieg `tests/run_all.tscn` mit Suites `test_stage1`, `test_rules_core`, `test_ai`, `test_table_ui`, `test_meta` statt einer Datei je Regelgruppe. `round_check` ist in `test_stage1` aufgegangen. Zusätzlich `tools/flow_smoke.gd` mit echten Szenenwechseln.
- **Einstellungen** als JSON (`user://settings.json`) statt `ConfigFile`; **Spielstand** als `var_to_str` in `user://save.dat` (JSON würde int zu float machen).
- **Audiobusse** werden zur Laufzeit angelegt (kein `default_bus_layout.tres`). **Sounds und Musik** synthetisch erzeugt (`tools/gen_audio.gd`), keine CC0-Dateien nötig.
- **Dienste** (Einstellungen, Statistik, Spielstand, Profil, Audio) schon in M3 gebaut, weil der Tisch sie braucht.
- **Schrift:** DejaVu Sans Mono (enthält ♥♦♣♠) statt VT323/IBM Plex Mono; Lizenz in `assets/fonts/DejaVu-LICENSE.txt`.
- **Regeln präzisiert:** Ausgabe-Zähler `deal`, Runde und Safe Phase je Ausgabe neu; Extra-Ablegen füllt die Hand weiter aus dem Stapel auf (Stufe-1-Verhalten); Spielende auch, wenn kein Mensch mehr im Spiel ist; scheiden alle zugleich aus, gewinnt der mit den wenigsten Punkten.
- **Statistik und Chips** zählen nur Partien mit genau einem Menschen (Hot-Seat zählt nicht).
- **Standardname** „Spieler“ statt „Du“ (Protokollsätze wie „Du zieht“ wären falsch).
- **Gedächtnishilfe** als Einstellung: an = bekannte Karten bleiben offen, aus = nur kurz gezeigt.
- **Bildröhren-Effekt** als Shader-Overlay (abschaltbar).

**Update 2026-10-06:** PR #4 nach `main` gemergt, CI grün. Web-Build live auf GitHub Pages (https://deusexlumen.github.io/Dame-Card-Game/), React-Deploy entfernt.

Offen und nur durch den Nutzer zu entscheiden: Echtgeld-Anbieter, ggf. zusätzlich itch.io. Multiplayer ist entschieden (Online v1, live), Bauplan „Online v1“ steht noch aus.
