# Online 1b: Tisch nur aus der Sicht — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Vor jeder Godot-Arbeit Skill `dame-godot` laden.

**Goal:** Der Spieltisch (`godot/scripts/table_view.gd`) liest nur noch die eigene `DameView` und schreibt nur über eine Session. Dadurch läuft derselbe Tisch offline, im Hot-Seat, als Online-Host und als Online-Gast, ohne dass sich Offline-Spiel verändert.

**Architecture:** Jeder Tisch hat eine Session. Offline, im Hot-Seat und als Online-Host ist das ein `DameHost` (hält `DameRules`, einziger Schreiber, führt KI, Zeitablauf und neue Ausgabe aus). Als Gast ist es ein `DameGuest` (kennt nur Sichten). Der Host schickt mit jeder Sicht die gerade angenommene Aktion mit (nur Typ, Platz, Indizes), damit jeder Tisch Animationen und Töne gleich erzeugt. Der Tisch hat genau einen Darstellungsweg: Sicht kommt an → `_on_view(view, action)`.

**Tech Stack:** Godot 4.7.2, GDScript, Headless-Tests (`npm run test:godot`).

**Spec:** `docs/online-p2p-plan.md` (Schritt 1b), `CONCEPT_DECISIONS.md` §10–§12, Netz-Kern in `godot/scripts/net/` (Schritt 1, Branch `feat/online-net-core`).

## Global Constraints

- Engine Godot 4.7.2, GL Compatibility, 1280×720. Renderer nicht wechseln.
- Regeln bleiben in `DameRules`. Keine zweite Regelimplementierung, auch nicht im Tisch.
- `table_view.gd` ruft nie `apply_action` auf. Abnahme: `grep -n "apply_action" godot/scripts/table_view.gd` liefert nichts.
- Erlaubte direkte `rules`-Nutzung im Tisch (Allowlist): `start()` (Regeln anlegen), `_try_resume()` (laden), `_save()` (`rules.to_dict()`), die Eigenschaft `rules` für Tests. Sonst nichts.
- Offline-Spiel bleibt bitgleich: der Golden-Test aus Task 0 muss nach jedem Task unverändert grün sein.
- Alle neuen Spielertexte: deutscher Schlüssel in `tr()` plus englische Übersetzung in `scripts/i18n.gd`.
- Aktionen auf dem Draht enthalten nur `type`, `seat` und die int-Felder aus `Protocol.PLAYER_ACTIONS`. Nie Kartenwerte, nie IDs.
- Kommentare Deutsch, Bezeichner Englisch.

## Nicht in diesem Plan (bewusst)

- Zugtimer-Hoheit online (Host misst Zeit aller Plätze), Presence, Abwesenheitsstufen §11, Host-Abbruch-Ende: Schritt 2.
- WebRTC, Signaling, Lobby: Schritte 3–4.
- Spielstand für Online-Partien: Gäste speichern nie; ein Online-Host speichert in 1b ebenfalls nicht.

## Review Focus

1. **Hot-Seat-Übergabe:** Der nächste Spieler darf keinen Frame lang die Sicht (Gedächtnis) des vorigen bekommen und umgekehrt. `HOST_PEER` wird nur in `confirm_handoff()` umgehängt, nie beim Zugwechsel. → Test in Task 4.
2. **Doppelte Animation:** Eine Aktion darf im 3D-Tisch nur einmal animiert werden (früher direkte `queue_action`-Aufrufe in `act`, `_ai_step`, `timeout_turn`). → Test in Task 3.
3. **Gast am Rundenende:** Enter/Knopf startet keine neue Ausgabe, sondern zeigt „Warte auf den Host …“. → Test in Task 5.
4. **Gast-Zeitablauf:** Ein Gast löst nie `timeout_penalty` aus (Systemaktion des Hosts); der Zugtimer ist beim Gast in 1b aus. → Test in Task 5.
5. **Statistik/Chips doppelt:** `_record_round_once` darf pro Ausgabe genau einmal zählen, auch wenn dieselbe Sicht mehrfach ankommt. → Test in Task 4.

---

## Dateien

| Datei | Änderung |
|---|---|
| `godot/scripts/dame_rules.gd` | statische `seat_role_for(viewer, seat, n)` / `seat_angle_for(...)`; Instanzmethoden rufen sie auf |
| `godot/scripts/dame_view.gd` | pro Spieler `deal_penalties`, `angle` |
| `godot/scripts/net/net_protocol.gd` | `public_action(action, seat)` |
| `godot/scripts/net/dame_host.gd` | Aktion in jeder Sicht; `ai_step`, `timeout_turn`, `next_round`; `local_seats`; Signal `view_changed(view, action)` |
| `godot/scripts/net/dame_guest.gd` | Signal `view_changed(view, action)` |
| `godot/scripts/table_view.gd` | Session statt `rules`; ein Darstellungsweg; lokale Plätze; Gast-Modus |
| `godot/scripts/i18n.gd` | neue Texte |
| `godot/tests/test_golden.gd` (neu) | bitgleiches Offline-Spiel |
| `godot/tests/test_net.gd` | Aktionen auf dem Draht, Host-Methoden |
| `godot/tests/test_table_ui.gd` | `host.broadcast()` nach direkten Zustandsänderungen |
| `godot/tests/test_table_net.gd` (neu) | Gast-Tisch spielt eine ganze Partie über die Eingabeschicht, `table.rules == null` |
| `godot/tests/run_all.gd` | neue Suites eintragen |

---

### Task 0: Golden-Test für Offline-Spiel (vor jeder Tischänderung)

**Files:** Create `godot/tests/test_golden.gd`, `godot/tests/fixtures/golden_offline.txt`; Modify `godot/tests/run_all.gd`

**Interfaces:** Consumes nur heutige Tisch-API (`pending_config`, `instant_ai`, `run_ai_until_human`, `_on_deck`, `_on_card`, `end_turn`, `next_deal`, `confirm_handoff`). Produces: Fixture, gegen die jeder spätere Task prüft.

- [ ] **Step 1: Test schreiben.** Zwei Skripte: (a) 1 Mensch + 3 KI, Seed 2024; (b) Hot-Seat 2 Menschen + 1 KI, Seed 2025. Eingaben deterministisch: Mensch zieht immer vom Stapel, tauscht Index `deal % 4`, bei Bube eigene Karte 0 ansehen, bei König eigene 0 gegen ersten Gegner Index 0, sonst `end_turn`; Hot-Seat ruft vor jedem menschlichen Zug `confirm_handoff()`. Läuft bis `game_over` oder 3 Ausgaben. Danach `var_to_str(table.rules.state)` mit der Fixture vergleichen.

```gdscript
extends RefCounted

# Bitgleichheit: dieselben Eingaben ergeben vor und nach dem Umbau denselben Zustand.

const TableScene = preload("res://scenes/table.tscn")
const FIXTURE := "res://tests/fixtures/golden_offline.txt"
# Nur zum Neuaufnehmen auf true setzen, nie committen.
const RECORD := false

var t

func run(ctx) -> void:
	t = ctx
	var got := _play({"seed": 2024, "seat_count": 4, "ai_seats": [1, 2, 3]}) + "\n---\n" + _play({"seed": 2025, "seat_count": 3, "ai_seats": [2]})
	if RECORD:
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(got)
		return
	var want := FileAccess.get_file_as_string(FIXTURE)
	t.expect(want != "", "Golden-Fixture fehlt")
	t.expect(got == want, "Offline-Spiel weicht vom Golden-Stand ab")


func _play(cfg: Dictionary) -> String:
	var table = TableScene.instantiate()
	table.instant_ai = true
	table.settings_override = {"memory_aid": true, "animations": false, "turn_timer": false}
	table.pending_config = cfg
	t.root.add_child(table)
	var guard := 0
	while guard < 3000:
		guard += 1
		var phase := str(table.rules.state.phase)
		if phase == "game_over" or int(table.rules.state.deal) > 3:
			break
		if phase == "round_end":
			table.next_deal()
			continue
		if table.handoff_pending:
			table.confirm_handoff()
			continue
		table.run_ai_until_human()
		if not table._human_turn():
			continue
		_human_step(table)
	var out := var_to_str(table.rules.state)
	table.queue_free()
	return out


func _human_step(table) -> void:
	var seat: int = table.viewer_seat
	var opp := (seat + 1) % int(table.rules.seat_count())
	match str(table.rules.state.turn_step):
		"draw":
			table._on_deck()
		"play":
			table._on_card(seat, int(table.rules.state.deal) % 4)
		"jack":
			table._on_card(seat, 0)
		"king":
			table._on_card(seat, 0)
			table._on_card(opp, 0)
		_:
			table.end_turn()
```

Hinweis: Der Test liest `table.rules.state` nur zum Steuern; das bleibt über die Allowlist-Eigenschaft `rules` möglich.

- [ ] **Step 2: Aufnehmen.** `RECORD := true`, `npm run test:godot`, Fixture prüfen (nicht leer, endet bei `game_over` oder Ausgabe 4), `RECORD := false`.
- [ ] **Step 3: Grün laufen lassen.** `npm run test:godot` → `ALL_TESTS_OK`.
- [ ] **Step 4: Commit.** `test: Golden-Test fuer unveraendertes Offline-Spiel`

---

### Task 1: Sitzgeometrie statisch, Sicht ergänzt

**Files:** Modify `godot/scripts/dame_rules.gd:311-331`, `godot/scripts/dame_view.gd`; Test `godot/tests/test_ai.gd` (Sicht-Tests stehen dort)

**Interfaces:** Produces `DameRules.seat_role_for(viewer: int, seat: int, n: int) -> String`, `DameRules.seat_angle_for(viewer: int, seat: int, n: int) -> float` (static). Sicht pro Spieler zusätzlich `deal_penalties: int`, `angle: float` (aus Sicht des Betrachters).

- [ ] **Step 1: Test.** In `test_ai.gd` neue Prüfung `_check_view_geometry()`:

```gdscript
func _check_view_geometry() -> void:
	var rules = _new_rules({"seed": 5, "seat_count": 6, "ai_seats": []})
	var view: Dictionary = DameViewScript.for_viewer(rules, 2)
	for p in view.players:
		t.expect(str(p.role) == DameRulesScript.seat_role_for(2, int(p.seat), 6), "Rolle ungleich statischer Funktion")
		t.expect(is_equal_approx(float(p.angle), rules.seat_angle(2, int(p.seat))), "Winkel fehlt in der Sicht")
		t.expect(p.has("deal_penalties"), "deal_penalties fehlt in der Sicht")
```

- [ ] **Step 2: Rot laufen lassen.** Erwartet: Parse-Fehler/`seat_role_for` unbekannt.
- [ ] **Step 3: Umsetzen.**

```gdscript
static func seat_angle_for(viewer: int, seat: int, n: int) -> float:
	if seat == viewer:
		return 0.0
	var offset := (seat - viewer + n) % n
	var list: Array = SEAT_ANGLES.get(n, SEAT_ANGLES[4])
	return -float(list[clampi(offset - 1, 0, list.size() - 1)])


static func seat_role_for(viewer: int, seat: int, n: int) -> String:
	if seat == viewer:
		return "self"
	var offset := (seat - viewer + n) % n
	if n == 2:
		return "opposite"
	if n == 3:
		return "left" if offset == 1 else "right"
	if offset == 2:
		return "opposite"
	return "left" if offset == 1 else "right"


func seat_angle(viewer: int, seat: int) -> float:
	return seat_angle_for(viewer, seat, seat_count())


func _seat_role(viewer: int, seat: int) -> String:
	return seat_role_for(viewer, seat, seat_count())
```

In `dame_view.gd` im Spieler-Dictionary ergänzen: `"deal_penalties": int(p.get("deal_penalties", 0)),` und `"angle": rules.seat_angle(viewer_seat, seat),`.

- [ ] **Step 4: Grün** inkl. Golden-Test. **Step 5: Commit** `feat: Sitzgeometrie statisch, Sicht mit deal_penalties und Winkel`

---

### Task 2: Host schickt Aktion mit, Host-Methoden für KI, Zeitablauf, neue Ausgabe

**Files:** Modify `godot/scripts/net/net_protocol.gd`, `dame_host.gd`, `dame_guest.gd`; Test `godot/tests/test_net.gd`

**Interfaces:**
- `Protocol.public_action(action: Dictionary, seat: int) -> Dictionary` — Whitelist-Kopie plus `seat`; für `timeout_penalty`/`start_next_round` nur `{type, seat}`.
- Sicht-Nachricht: `{"t": "view", "rev": int, "view": Dictionary, "action": Dictionary}` (`action` darf `{}` sein, z. B. bei Platzzuweisung).
- Signale (Host und Gast): `view_changed(view: Dictionary, action: Dictionary)`.
- `DameHost.local_seats: Array` — Plätze, die an diesem Gerät gespielt werden.
- `DameHost.ai_step(ai) -> Dictionary` — ein KI-Schritt, sendet Sicht + `public_action(ai.last_action)`.
- `DameHost.timeout_turn(ai) -> Dictionary` — Strafkarte, dann Ersatzaktionen bis Zugende; jede angenommene Aktion wird einzeln mit Sicht verschickt. Rückgabe `{"ok": bool, "penalty": bool}`.
- `DameHost.next_round() -> Dictionary` — `start_next_round`, verschickt Sicht mit `{type: "start_next_round", seat: -1}`.
- `DameHost.is_authority() -> bool` (true), `DameGuest.is_authority() -> bool` (false).

- [ ] **Step 1: Tests** in `test_net.gd`:

```gdscript
func _check_public_actions() -> void:
	var a := Protocol.public_action({"type": "king_swap", "opponent_seat": 2, "opponent_index": 1, "chosen_index": 0, "rank": "K", "id": "x"}, 1)
	t.expect(a.keys().size() == 5 and int(a.seat) == 1 and not a.has("rank") and not a.has("id"), "Aktion traegt fremde Felder")
	t.expect(Protocol.public_action({"type": "timeout_penalty", "seat": 0, "card": {}}, 0).keys().size() == 2, "Systemaktion traegt Zusatzfelder")


func _check_host_drives_ai_and_timeout() -> void:
	_setup(44)
	var actions: Array = []
	guest.view_changed.connect(func(_v, a): actions.append(a))
	host.send_action({"type": "draw_deck"})
	host.send_action({"type": "discard_drawn"})
	host.send_action({"type": "end_turn"})
	guest.poll()
	t.expect(str(actions[-1].type) == "end_turn" and int(actions[-1].seat) == 0, "Gast bekommt Aktion des Hosts nicht")
	# Sitz 1 ist der Gast: Zeitablauf auf dem Host beendet seinen Zug.
	var ai = DameAIScript.new(1)
	var pen_before: int = rules.state.players[1].penalty_cards.size()
	var res: Dictionary = host.timeout_turn(ai)
	guest.poll()
	t.expect(bool(res.ok) and int(rules.state.current_index) == 2, "Zeitablauf beendet den Zug nicht")
	t.expect(rules.state.players[1].penalty_cards.size() == pen_before + 1, "Zeitablauf ohne Strafkarte")
	t.expect(str(actions[-1].type) == "end_turn", "Ersatzaktionen nicht einzeln verschickt")
	var r2: Dictionary = host.ai_step(ai)
	guest.poll()
	t.expect(bool(r2.ok) and int(actions[-1].seat) == 2, "KI-Schritt nicht verschickt")
```

Im Leak-Test (`_on_guest_view`) Signatur auf `(view, action)` ändern und ergänzen: jede Aktion hat nur erlaubte Schlüssel (`type`, `seat` plus `Protocol.PLAYER_ACTIONS[type]`).

- [ ] **Step 2: Rot.**
- [ ] **Step 3: Umsetzen.**

`net_protocol.gd`:
```gdscript
# Oeffentliche Form einer angenommenen Aktion fuer alle Tische (Animation, Toene).
static func public_action(a: Dictionary, seat: int) -> Dictionary:
	var type := str(a.get("type", ""))
	var out := {"type": type, "seat": seat}
	if PLAYER_ACTIONS.has(type):
		for field in PLAYER_ACTIONS[type]:
			out[field] = int(a.get(field, -1))
	return out
```

`dame_host.gd` (Ausschnitt; `_broadcast(action := {})` bekommt die Aktion und legt sie in jede Sicht-Nachricht; `submit` übergibt `Protocol.public_action(action, seat)`; `_deliver_local` emittiert `view_changed.emit(latest_view, msg.get("action", {}))`):
```gdscript
var local_seats: Array = []

func is_authority() -> bool:
	return true


func ai_step(ai) -> Dictionary:
	var seat := int(rules.state.current_index)
	var res: Dictionary = ai.step(rules)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast(Protocol.public_action(ai.last_action, seat)))
	return res


# Zeit abgelaufen: genau eine Strafkarte, dann sichere Ersatzaktionen bis Zugende.
func timeout_turn(ai) -> Dictionary:
	var seat := int(rules.state.current_index)
	var pen: Dictionary = rules.apply_action({"type": "timeout_penalty", "seat": seat})
	if not bool(pen.get("ok", false)):
		return {"ok": false, "penalty": false}
	_dispatch(_broadcast({"type": "timeout_penalty", "seat": seat}))
	var guard := 0
	while guard < 8 and int(rules.state.current_index) == seat:
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			break
		guard += 1
		var fallback: Dictionary = ai.fallback_action(rules, seat)
		if not bool(rules.apply_action(fallback).get("ok", false)):
			break
		_dispatch(_broadcast(Protocol.public_action(fallback, seat)))
	return {"ok": true, "penalty": bool(pen.get("penalty", false))}


func next_round() -> Dictionary:
	var res: Dictionary = rules.apply_action({"type": "start_next_round"})
	if bool(res.get("ok", false)):
		_dispatch(_broadcast({"type": "start_next_round", "seat": -1}))
	return res
```
`system_action` entfällt zugunsten dieser drei Methoden (Tests aus Schritt 1 entsprechend umstellen).

`dame_guest.gd`: `signal view_changed(view: Dictionary, action: Dictionary)`, `func is_authority() -> bool: return false`, beim Empfang `view_changed.emit(latest_view, msg.get("action", {}))`.

- [ ] **Step 4: Grün** inkl. Golden. **Step 5: Commit** `feat(net): Aktion mit jeder Sicht, Host fuehrt KI, Zeitablauf und neue Ausgabe`

---

### Task 3: Tisch schreibt nur noch über die Session (ein Darstellungsweg)

**Files:** Modify `godot/scripts/table_view.gd` (`start`, `_try_resume`, `_after_start`, `act`, `_after_human_action`, `_ai_step`, `run_ai_until_human`, `next_deal`, `timeout_turn`, `_feedback`, `_snapshot`, `_penalty_total`, `_refresh`); Test `godot/tests/test_table_ui.gd`

**Interfaces:**
- `var session` (DameHost oder DameGuest). `rules` wird Eigenschaft: `var rules: get: return session.rules if session != null and session.is_authority() else null`.
- `func _on_view(view: Dictionary, action: Dictionary) -> void` — einziger Ort für: `_view` setzen, `_table3d.queue_action(action)`, Töne aus Sicht-Vergleich, Aufdecken eigener Aktionen, `_after_change()`.
- `func _on_result(msg: Dictionary) -> void` — bei `ok == false`: Fehlerton + Toast `msg.reason`.
- `_refresh()` erzeugt keine Sicht mehr, sondern zeichnet aus `_view` plus lokalem UI-Zustand.

- [ ] **Step 1: Test** in `test_table_ui.gd` (Review Focus 2):

```gdscript
func _check_single_animation_path() -> void:
	var table = _make_table(_cfg({"seed": 108}))
	var calls := [0]
	table._table3d_queue_hook = func(_a): calls[0] += 1
	table._on_deck()
	t.expect(calls[0] == 1, "Ziehen wird %d-mal animiert" % calls[0])
	_free(table)
```
(Dafür in `table_view.gd` eine Test-Hook-Variable `_table3d_queue_hook: Callable` vorsehen, die `_on_view` zusätzlich zu `_table3d.queue_action` aufruft.)

Außerdem `_check_timer_pauses_for_powers` anpassen: nach jedem `table.rules.state.turn_step = ...` folgt `table.session.broadcast()`.

- [ ] **Step 2: Rot.**
- [ ] **Step 3: Umsetzen.**

`start()`:
```gdscript
	var r = DameRulesScript.new()
	r.start_match(config)
	_attach_host(r, int(config.seed) + 7)
```
`_try_resume()`: statt `rules = r` und `ai = DameAIScript.new(...)` → `_attach_host(r, int(config.get("seed", 1)) + int(r.state.deal) * 31)` (Seed-Formeln exakt wie heute, sonst bricht der Golden-Test).
```gdscript
func _attach_host(r, ai_seed: int) -> void:
	session = DameHostScript.new(r, null)
	session.view_changed.connect(_on_view)
	session.action_result.connect(_on_result)
	ai = DameAIScript.new(ai_seed)
	session.local_seats = _human_seats_of(r)
	_after_start()
	session.assign_seat(DameProtocol.HOST_PEER, viewer_seat if viewer_seat >= 0 else int(session.local_seats[0]) if not session.local_seats.is_empty() else 0)
```
`act()`:
```gdscript
func act(action: Dictionary) -> Dictionary:
	if session == null or handoff_pending:
		return {"ok": false, "reason": "Nicht bereit"}
	_last_result = {}
	session.send_action(action)
	# Host antwortet synchron; ein Gast bekommt das Ergebnis spaeter per Signal.
	return _last_result if not _last_result.is_empty() else {"ok": true, "pending": true}
```
`_ai_step()` → `session.ai_step(ai)`; `next_deal()` → `session.next_round()` (nur wenn `session.is_authority()`); `timeout_turn()` → `var res = session.timeout_turn(ai)` plus Toast/Ton wie bisher. Alle direkten `_table3d.queue_action`-Aufrufe entfernen. `_save()` nach jeder Änderung bleibt (nur Authority, nur ohne Link).

`_on_view`:
```gdscript
func _on_view(view: Dictionary, action: Dictionary) -> void:
	var before := _view
	_view = view
	if not action.is_empty():
		if _table3d != null:
			_table3d.queue_action(action)
		if _table3d_queue_hook.is_valid():
			_table3d_queue_hook.call(action)
		_feedback_from(before, view, action)
		if int(action.get("seat", -1)) == viewer_seat:
			_after_own_action(action)
	if session.is_authority():
		_save()
	_after_change()
```
`_feedback_from(before, after, action)` ersetzt `_feedback`/`_snapshot`/`_penalty_total`: Strafen = Summe `penalty_count` der Spieler; sonst dieselbe Reihenfolge wie heute (`penalty`, `dame`, `win`/`lose` über `after.players[winner].is_ai`, `flip`, `place` über `discard_count`, `draw`). `start_next_round` → Ton `shuffle`, Aufdecken wie heute in `next_deal`.

`_after_own_action` = bisheriges `_after_human_action`, König-Toast aus `_view.private_look` statt `rules.state.last_look`.

- [ ] **Step 4: Grün** inkl. Golden (bitgleich!). **Step 5: Commit** `refactor(table): Tisch schreibt nur ueber die Session`

---

### Task 4: Tisch liest nur noch die Sicht, lokale Plätze

**Files:** Modify `godot/scripts/table_view.gd` (alle übrigen `rules.`-Lesestellen: `_layout_seats`, `_after_change`, `_events`, `_begin_handoff`, `confirm_handoff`, `_human_turn`, `_on_*`, `select`, `_unhandled_input`, `_process`, `_reveal_own_known`, `_targets_for`, `_refresh`, `_prompt_text`, `_update_actions`, `_has_hard_ai`, `_record_round_once`, `_record_game_once`); Test `test_table_ui.gd`

**Interfaces:** `human_seats` wird durch `local_seats` ersetzt (`session.local_seats` beim Host, `[eigener Platz]` beim Gast). `is_hotseat()` = `local_seats.size() > 1`. `_local_seat()` = `local_seats[0]` wenn genau ein lokaler Platz.

Ersetzungstabelle (vollständig, gilt für alle oben genannten Funktionen):

| Heute | Neu |
|---|---|
| `rules == null` | `_view.is_empty()` |
| `rules.state.phase` / `.turn_step` / `.current_index` / `.round` / `.deal` / `.dame_turns_left` / `.dame_caller_index` / `.winner_index` / `.last_round_false_call` | gleichnamiges Feld in `_view` |
| `rules.state.players[i].is_ai` / `.name` / `.difficulty` / `.score` / `.deal_penalties` | `_view.players[i].…` |
| `rules.current_player().is_ai` | `_view.players[int(_view.current_index)].is_ai` |
| `rules.seat_count()` | `int(_view.seat_count)` |
| `rules._seat_role(a, s)` / `rules.seat_angle(a, s)` | `DameRulesScript.seat_role_for(a, s, n)` / `seat_angle_for(a, s, n)` |
| `rules.state.players[viewer_seat].known` | Indizes der eigenen Karten mit `known == true` in `_view.players[viewer_seat].cards` |
| `rules.state.players[me].hand.size()` (nur Tests) | bleibt in Tests über `table.rules` |

`confirm_handoff()`: nach `viewer_seat = seat` zuerst `session.assign_seat(HOST_PEER, seat)` (liefert die Sicht des neuen Spielers), erst danach `_reveal_own_known`. `_begin_handoff` hängt nichts um (Review Focus 1).

`_record_round_once`/`_record_game_once`: aus `_view` (Punkte, `deal_penalties`, Ansager, `last_round_false_call`, Sieger), Sperre weiter über `_recorded_deal` (Review Focus 5).

- [ ] **Step 1: Tests:**

```gdscript
func _check_handoff_never_shows_previous_memory() -> void:
	var table = _make_table(_cfg({"seed": 109, "seat_count": 3, "ai_seats": [2]}))
	table.confirm_handoff()
	var seen: Array = []
	table.session.view_changed.connect(func(v, _a): seen.append([int(v.viewer_seat), table.viewer_seat, table.handoff_pending]))
	_finish_turn(table)  # zieht, legt ab, beendet Zug -> Uebergabe an Sitz 1
	t.expect(table.handoff_pending, "keine Uebergabe nach Zugende")
	for s in seen:
		t.expect(int(s[0]) == 0, "Sicht von Sitz %d kam vor der Bestaetigung" % int(s[0]))
	table.confirm_handoff()
	t.expect(int(table._view.viewer_seat) == 1, "nach Bestaetigung nicht die Sicht von Sitz 1")
	_free(table)


func _check_round_recorded_once() -> void:
	if app == null:
		return
	var table = _make_table(_cfg({"seed": 110}))
	var before: int = app.stats.rounds_played()
	_play_to_round_end(table)
	table.session.broadcast()
	table.session.broadcast()
	t.expect(app.stats.rounds_played() == before + 1, "Ausgabe mehrfach gezaehlt")
	_free(table)
```
(`_finish_turn` / `_play_to_round_end` als kleine Helfer im Test aus vorhandenen Schleifen in `test_table_ui.gd` bauen; Name der Statistik-Zählfunktion vorher in `scripts/services/stats_service.gd` nachsehen und exakt verwenden.)

- [ ] **Step 2: Rot.** **Step 3: Umsetzen** (Tabelle). **Step 4: Prüfen:** `grep -n "rules\." godot/scripts/table_view.gd` zeigt nur Allowlist-Stellen; `grep -n apply_action godot/scripts/table_view.gd` leer; Golden grün. **Step 5: Commit** `refactor(table): Tisch liest nur die eigene Sicht`

---

### Task 5: Gast-Tisch

**Files:** Modify `godot/scripts/table_view.gd`, `godot/scripts/i18n.gd`; Create `godot/tests/test_table_net.gd`; Modify `godot/tests/run_all.gd`

**Interfaces:** `var pending_session` — vor `add_child` gesetzt (wie `pending_config`); ist es ein `DameGuest`, startet der Tisch ohne Regeln: `session = pending_session`, Signale verbinden, `local_seats = [int(session.latest_view.viewer_seat)]`, `viewer_seat` daraus. In `_process`: `session.poll()` (Host mit Link ebenfalls). Gast: kein KI-Timer, kein Zugtimer, kein `_save`, `next_deal()` zeigt nur Prompt „Warte auf den Host …“.

Neue Texte (DE-Schlüssel → EN): „Warte auf den Host …“ → "Waiting for the host …".

- [ ] **Step 1: Test** `test_table_net.gd`: In-Test-`DameHost` mit Loopback, Sitz 0 Host-Spieler (vom Test per Policy gesteuert), Sitz 1 Gast-Tisch, Sitz 2 KI (`host.ai_step`). Der Gast-Tisch wird **nur über die Eingabeschicht** gesteuert: `_on_deck()`, `_on_discard()`, `_on_card(seat, i)`, `select(i)`, `call_dame()`, `end_turn()`; Entscheidung per `DamePolicyScript.choose(table._view, rng)` und Übersetzung in Eingaben (König: erst `_on_card(eigener, i)`, dann `_on_card(gegner, j)`). Nach jedem Schritt `host.poll()`, `table.session.poll()`.

Prüfungen:
```gdscript
	t.expect(table.rules == null, "Gast-Tisch hat Regeln")
	t.expect(str(rules.state.phase) == "game_over", "Partie mit Gast-Tisch endet nicht")
	# Gesichter nur fuer Karten, die die Sicht als known fuehrt.
	for seat in [0, 2]:
		for i in range(table._view.players[seat].cards.size()):
			if not bool(table._view.players[seat].cards[i].known):
				t.expect(not table._face_for(seat, i, table._view.players[seat].cards[i]), "Gast zeigt unbekannte Karte")
	# Review Focus 3: Enter am Rundenende startet nichts
	var deal_before: int = int(rules.state.deal)
	table.next_deal()
	t.expect(int(rules.state.deal) == deal_before, "Gast startet neue Ausgabe")
	# Review Focus 4: Gast-Zeitablauf
	table.settings_override["turn_timer"] = true
	table._process(999.0)
	t.expect(rules.state.players[1].penalty_cards.size() == pens_before, "Gast loest Zeitablauf aus")
```
Jede übrig gebliebene direkte `rules`-Lesestelle im Tisch lässt diesen Test abstürzen. Das ist gewollt.

- [ ] **Step 2: Rot.** **Step 3: Umsetzen.** **Step 4: Grün** inkl. Golden und `FLOW_OK`. **Step 5: Commit** `feat(table): Tisch als Online-Gast`

---

### Task 6: Abschluss

- [ ] `npm run test:godot` → `ALL_TESTS_OK` und `FLOW_OK`.
- [ ] Web-Build lokal starten und eine Offline-Partie und eine Hot-Seat-Übergabe von Hand spielen (Animationen, Töne, Aufdecken wie vorher).
- [ ] `docs/online-p2p-plan.md`: 1b als erledigt markieren. `.claude/skills/dame-godot/references/architecture.md`: Abschnitt „Session“ (Tisch liest nur Sicht, schreibt nur über Session; Host/Gast).
- [ ] Commit `docs: 1b erledigt, Architektur um Session ergaenzt`

---

## Weg bis „Freunde können spielen“

1. **1b** (dieser Plan): Tisch aus der Sicht.
2. **WebRTC-Link-Adapter:** `MultiplayerPeer`-Rohpakete (`put_packet`/`get_packet`/`get_packet_peer`) hinter der `send`/`receive`-Schnittstelle des Loopback-Links.
3. **Signaling-Client für Supabase Realtime in GDScript:** zuerst prüfen, ob es einen gepflegten Godot-4-Client gibt; sonst `WebSocketPeer` plus Phoenix-Channel-Protokoll (eigene Arbeit, nicht klein). Copy-Paste-Code als Fallback.
4. **`webrtc-native`** in die Windows-/Android-Exporte einbinden und testen.
5. **Lobby-UI:** Raum erstellen, Code anzeigen, per Code beitreten, Plätze zuweisen.
6. **Schritt 2:** Presence, Zugtimer-Hoheit beim Host, Abwesenheitsstufen §11, Host-Abbruch beendet ohne Wertung.
