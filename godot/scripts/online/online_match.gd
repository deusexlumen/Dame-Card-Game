extends RefCounted
class_name OnlineMatch

# Eine Online-Partie auf dem Server. Keine Szene, kein Netzwerk, keine Echtzeit:
# Die Zeit kommt nur ueber tick(delta) herein, dadurch ist alles headless testbar.
# Regeln: DameRules (einzige Regelquelle). Verbindlich: CONCEPT_DECISIONS §10/§11.
#   §10 nur live, Zugtimer immer an, Zeit abgelaufen = eine Strafkarte (§9)
#   §11 Stufe 1 Funkloch straffrei, Stufe 2 KI uebernimmt + Strafkarte beim
#       Wiedereinstieg, Stufe 3 Abbruch = Aufgabe

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DameMirrorScript = preload("res://scripts/online/dame_mirror.gd")

const TURN_SECONDS_CHOICES := [20, 30, 45]
const DEFAULT_TURN_SECONDS := 30
const RESERVE_WAIT := 15.0       # Zusatzwartezeit, wenn der Abwesende am Zug ist
const STAGE1_RUN := 60.0         # am Stueck abwesend, bis die KI uebernimmt
const STAGE1_TOTAL := 120.0      # Reserve pro Partie insgesamt
const REJOIN_LIMIT := 300.0      # danach ist der Platz verloren
const ALL_AWAY_LIMIT := 300.0    # alle Menschen weg: Partie endet ohne Wertung
const AI_STEP_SECONDS := 0.8     # Tempo der KI, damit Clients animieren koennen
const NEXT_DEAL_SECONDS := 10.0  # Pause zwischen zwei Ausgaben

# Aktionen, die ein Client schicken darf. Alles andere loest nur der Server aus.
const CLIENT_ACTIONS := [
	"draw_deck", "draw_discard", "swap", "discard_drawn", "discard_extra",
	"look_card", "king_swap", "call_dame", "end_turn",
]

var rules = DameRulesScript.new()
var ai = null
var seats: Array = []
var turn_seconds := float(DEFAULT_TURN_SECONDS)
var version := 0
var finished := false
var end_reason := ""            # "game_over" | "abandoned"
var last_public_action: Dictionary = {}

var _turn_key := ""
var _turn_elapsed := 0.0
var _ai_wait := 0.0
var _deal_wait := 0.0
var _all_away := 0.0
var _ready: Dictionary = {}


# config.seats: [{name, kind: "human"|"ai", difficulty}], 2-6 Eintraege
# config.turn_seconds: 20/30/45, config.seed: nur fuer Tests (sonst zufaellig)
func _init(config: Dictionary = {}) -> void:
	var list: Array = config.get("seats", [])
	var names: Array = []
	var ai_seats: Array = []
	var difficulties := {}
	for i in range(list.size()):
		var s: Dictionary = list[i]
		var kind := str(s.get("kind", "human"))
		names.append(str(s.get("name", "Platz %d" % (i + 1))))
		if kind == "ai":
			ai_seats.append(i)
			difficulties[i] = str(s.get("difficulty", "medium"))
		seats.append({
			"kind": kind,
			"name": names[i],
			"present": kind == "ai",
			"away_run": 0.0,
			"away_total": 0.0,
			"stage": 0,
			"pending_penalty": false,
			"forfeited": false,
			"ready": false,
		})
	var secs := int(config.get("turn_seconds", DEFAULT_TURN_SECONDS))
	turn_seconds = float(secs if TURN_SECONDS_CHOICES.has(secs) else DEFAULT_TURN_SECONDS)
	var seed := int(config.get("seed", 0))
	if seed == 0:
		# Online nie vorhersagbar: der Seed bestimmt jede Mischung.
		seed = int(Crypto.new().generate_random_bytes(4).decode_u32(0)) | 1
	rules.start_match({
		"seed": seed,
		"seat_count": seats.size(),
		"ai_seats": ai_seats,
		"difficulties": difficulties,
		"names": names,
	})
	ai = DameAIScript.new(seed ^ 0x5eed)
	_turn_key = _current_turn_key()


# ---------------------------------------------------------------- Abfragen

func mirror_for(seat: int) -> Dictionary:
	return DameMirrorScript.for_viewer(rules, seat)


# Oeffentliche Zusatzinfos fuer alle Clients (Anwesenheit, Restzeit, Stufen).
func meta() -> Dictionary:
	var out: Array = []
	for i in range(seats.size()):
		var s: Dictionary = seats[i]
		out.append({
			"seat": i,
			"name": str(s.name),
			"kind": str(s.kind),
			"present": bool(s.present),
			"stage": int(s.stage),
			"forfeited": bool(s.forfeited),
			"rejoin_left": maxf(REJOIN_LIMIT - float(s.away_run), 0.0) if int(s.stage) == 2 else 0.0,
		})
	return {
		"version": version,
		"seats": out,
		"turn_seconds": turn_seconds,
		"turn_left": turn_left(),
		"next_deal_left": maxf(NEXT_DEAL_SECONDS - _deal_wait, 0.0) if str(rules.state.phase) == "round_end" else 0.0,
		"finished": finished,
		"end_reason": end_reason,
		"last_action": last_public_action.duplicate(true),
	}


func turn_left() -> float:
	return maxf(turn_seconds - _turn_elapsed, 0.0)


func human_seats() -> Array:
	var list: Array = []
	for i in range(seats.size()):
		if str(seats[i].kind) == "human":
			list.append(i)
	return list


func can_rejoin(seat: int) -> bool:
	return seat >= 0 and seat < seats.size() and str(seats[seat].kind) == "human" and not bool(seats[seat].forfeited)


# ---------------------------------------------------------------- Eingaben

func set_present(seat: int, present: bool) -> void:
	if seat < 0 or seat >= seats.size() or str(seats[seat].kind) != "human":
		return
	var s: Dictionary = seats[seat]
	if bool(s.forfeited):
		return
	if present and not bool(s.present):
		if int(s.stage) == 2:
			# §11 Stufe 2: Wiedereinstieg kostet eine Strafkarte in der naechsten Ausgabe.
			s.pending_penalty = true
		s.away_run = 0.0
		s.stage = 0
	s.present = present
	version += 1


func submit(seat: int, action: Dictionary) -> Dictionary:
	if finished:
		return {"ok": false, "reason": "Partie ist beendet"}
	var type := str(action.get("type", ""))
	if type == "ready_next":
		return _ready_next(seat)
	if not CLIENT_ACTIONS.has(type):
		return {"ok": false, "reason": "Aktion nicht erlaubt"}
	if seat < 0 or seat >= seats.size() or not _human_controls(seat):
		return {"ok": false, "reason": "Platz wird nicht von dir gespielt"}
	var clean := action.duplicate(true)
	clean.seat = seat
	return _apply(clean)


# ---------------------------------------------------------------- Zeit

# Gibt true zurueck, wenn sich etwas geaendert hat (Clients neu beliefern).
func tick(delta: float) -> bool:
	if finished:
		return false
	var before := version
	if _everyone_away():
		_all_away += delta
		if _all_away >= ALL_AWAY_LIMIT:
			_finish("abandoned")
		return version != before
	_all_away = 0.0
	_update_absence(delta)
	var phase := str(rules.state.phase)
	if phase == "game_over":
		_finish("game_over")
	elif phase == "round_end":
		_deal_wait += delta
		if _deal_wait >= NEXT_DEAL_SECONDS or _all_ready():
			_start_next_deal()
	else:
		_tick_turn(delta)
	return version != before


func _tick_turn(delta: float) -> void:
	var key := _current_turn_key()
	if key != _turn_key:
		_turn_key = key
		_turn_elapsed = 0.0
		_ai_wait = 0.0
	var seat := int(rules.state.current_index)
	var s: Dictionary = seats[seat]
	if not _human_controls(seat):
		_ai_wait += delta
		if _ai_wait >= AI_STEP_SECONDS:
			_ai_wait = 0.0
			_machine_step(seat)
		return
	_turn_elapsed += delta
	if bool(s.present):
		if _turn_elapsed >= turn_seconds:
			_timeout(seat)
	elif _turn_elapsed >= turn_seconds + RESERVE_WAIT:
		_absent_turn(seat)


func _update_absence(delta: float) -> void:
	for i in range(seats.size()):
		var s: Dictionary = seats[i]
		if str(s.kind) != "human" or bool(s.present) or bool(s.forfeited):
			continue
		s.away_run = float(s.away_run) + delta
		var stage := int(s.stage)
		if stage < 2:
			s.away_total = float(s.away_total) + delta
		var new_stage := 1
		if float(s.away_run) > STAGE1_RUN or float(s.away_total) > STAGE1_TOTAL:
			new_stage = 2
		if float(s.away_run) > REJOIN_LIMIT:
			new_stage = 3
		if new_stage != stage:
			s.stage = new_stage
			if new_stage == 3:
				# §11 Stufe 3: Platz verloren, Partie zaehlt als Aufgabe.
				s.forfeited = true
			version += 1


# ---------------------------------------------------------------- Ablauf

func _apply(action: Dictionary) -> Dictionary:
	var result: Dictionary = rules.apply_action(action)
	if bool(result.get("ok", false)):
		last_public_action = _public_action(action)
		version += 1
	return result


# Zug eines Platzes ohne anwesenden Menschen: echte KI oder vorsichtige Vertretung.
func _machine_step(seat: int) -> void:
	if str(seats[seat].kind) == "ai":
		var result: Dictionary = ai.step(rules)
		if bool(result.get("ok", false)):
			last_public_action = _public_action(ai.last_action)
			version += 1
		else:
			_finish_turn_safely(seat)
		return
	# Vertretung (§11 Stufe 2/3): ruft nie Dame, nimmt nur sichere Standardzuege.
	_apply(_cautious_action(seat))


func _timeout(seat: int) -> void:
	# §10 / §9: anwesend und Zeit abgelaufen = genau eine Strafkarte, dann Zug beenden.
	var pen: Dictionary = rules.apply_action({"type": "timeout_penalty", "seat": seat})
	if bool(pen.get("ok", false)):
		version += 1
	_finish_turn_safely(seat)


func _absent_turn(seat: int) -> void:
	# §11 Stufe 1: aussetzen, keine Strafkarte. Mitten im Zug: neutral zu Ende spielen.
	if str(rules.state.turn_step) == "draw" and rules.state.drawn_card == null:
		if rules.must_take_queen():
			_forced_queen(seat)
			return
		if bool(_apply({"type": "skip_turn", "seat": seat}).get("ok", false)):
			return
	_finish_turn_safely(seat)


# Dame-Zwangszug regulaer: Dame nehmen und gegen die schlechteste bekannte Karte tauschen.
func _forced_queen(seat: int) -> void:
	if not bool(_apply({"type": "draw_discard", "seat": seat}).get("ok", false)):
		_finish_turn_safely(seat)
		return
	var player: Dictionary = rules.state.players[seat]
	var best := 0
	var best_value := -1
	for i in range(player.hand.size()):
		if player.known.has(i) and int(player.hand[i].value) > best_value:
			best_value = int(player.hand[i].value)
			best = i
	if not bool(_apply({"type": "swap", "seat": seat, "hand_index": best}).get("ok", false)):
		_finish_turn_safely(seat)
		return
	_finish_turn_safely(seat)


func _finish_turn_safely(seat: int) -> void:
	var guard := 0
	while guard < 10 and not finished and int(rules.state.current_index) == seat:
		guard += 1
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			return
		if not bool(_apply(_cautious_action(seat)).get("ok", false)):
			if not _try_any_target(seat):
				return


func _cautious_action(seat: int) -> Dictionary:
	if str(rules.state.turn_step) == "extra":
		return {"type": "end_turn", "seat": seat}
	return ai.fallback_action(rules, seat)


# Bube/Koenig: die Standardwahl kann eine offene Karte treffen. Dann irgendein gueltiges Ziel.
func _try_any_target(seat: int) -> bool:
	var step := str(rules.state.turn_step)
	for p in rules.state.players:
		if bool(p.eliminated):
			continue
		for i in range(p.hand.size()):
			var action := {}
			if step == "jack":
				action = {"type": "look_card", "seat": seat, "target_seat": int(p.seat), "hand_index": i}
			elif step == "king" and int(p.seat) != seat:
				for mine in range(rules.state.players[seat].hand.size()):
					if bool(_apply({"type": "king_swap", "seat": seat, "opponent_seat": int(p.seat), "opponent_index": i, "chosen_index": mine}).get("ok", false)):
						return true
				continue
			else:
				return false
			if bool(_apply(action).get("ok", false)):
				return true
	return false


func _start_next_deal() -> void:
	var result: Dictionary = rules.apply_action({"type": "start_next_round"})
	if not bool(result.get("ok", false)):
		return
	_deal_wait = 0.0
	for i in range(seats.size()):
		var s: Dictionary = seats[i]
		s.ready = false
		if bool(s.pending_penalty):
			s.pending_penalty = false
			rules.give_absence_penalty(i)
	last_public_action = {"type": "start_next_round"}
	version += 1


func _ready_next(seat: int) -> Dictionary:
	if str(rules.state.phase) != "round_end":
		return {"ok": false, "reason": "Keine abgeschlossene Runde"}
	if seat < 0 or seat >= seats.size():
		return {"ok": false, "reason": "Ungültiger Platz"}
	seats[seat].ready = true
	version += 1
	if _all_ready():
		_start_next_deal()
	return {"ok": true, "reason": ""}


func _finish(reason: String) -> void:
	if finished:
		return
	finished = true
	end_reason = reason
	version += 1


# ---------------------------------------------------------------- Hilfen

func _human_controls(seat: int) -> bool:
	var s: Dictionary = seats[seat]
	return str(s.kind) == "human" and not bool(s.forfeited) and int(s.stage) < 2


func _everyone_away() -> bool:
	for s in seats:
		if str(s.kind) == "human" and bool(s.present):
			return false
	return true


func _all_ready() -> bool:
	var any := false
	for s in seats:
		if str(s.kind) == "human" and bool(s.present):
			any = true
			if not bool(s.ready):
				return false
	return any


func _current_turn_key() -> String:
	var st: Dictionary = rules.state
	return "%d:%d:%d:%s:%d" % [int(st.current_index), int(st.deal), int(st.round), str(st.phase), int(st.dame_turns_left)]


# Was alle sehen duerfen: Art des Zugs und Positionen, nie Kartenwerte.
static func _public_action(action: Dictionary) -> Dictionary:
	var out := {}
	for key in ["type", "seat", "hand_index", "target_seat", "opponent_seat", "opponent_index", "chosen_index"]:
		if action.has(key):
			out[key] = action[key]
	return out
