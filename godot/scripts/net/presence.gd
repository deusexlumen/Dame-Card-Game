extends RefCounted
class_name Presence

# Abwesenheit der Online-Spieler (CONCEPT_DECISIONS §11), nur auf dem Host.
# Keine Szene, kein Netz: die Zeit kommt ueber tick(delta), dadurch headless testbar.
#   Stufe 1 Funkloch: bis 60 s am Stueck, max. 120 s je Partie, straffrei
#   Stufe 2 KI-Vertretung, Wiedereinstieg bis 300 s mit einer Strafkarte
#   Stufe 3 Platz verloren (Aufgabe)

const STAGE1_RUN := 60.0
const STAGE1_TOTAL := 120.0
const REJOIN_LIMIT := 300.0
const RESERVE_WAIT := 15.0

signal stage_changed(seat: int, stage: int)

# seat -> {present, away_run, away_total, stage, pending_penalty, forfeited}
var seats := {}


# Beobachtete Plaetze (nur menschliche Gaeste; der Host-Spieler ist nie abwesend).
func track(seat: int) -> void:
	if not seats.has(seat):
		seats[seat] = {"present": true, "away_run": 0.0, "away_total": 0.0, "stage": 0, "pending_penalty": false, "forfeited": false}


func is_tracked(seat: int) -> bool:
	return seats.has(seat)


func set_present(seat: int, present: bool) -> void:
	if not seats.has(seat):
		return
	var s: Dictionary = seats[seat]
	if bool(s.forfeited) or bool(s.present) == present:
		return
	if present:
		if int(s.stage) == 2:
			# §11 Stufe 2: Wiedereinstieg kostet eine Strafkarte in der naechsten Ausgabe.
			s.pending_penalty = true
		s.away_run = 0.0
		s.stage = 0
		stage_changed.emit(seat, 0)
	else:
		s.stage = 1
		stage_changed.emit(seat, 1)
	s.present = present


func is_present(seat: int) -> bool:
	return not seats.has(seat) or bool(seats[seat].present)


func stage_of(seat: int) -> int:
	return int(seats[seat].stage) if seats.has(seat) else 0


func is_forfeited(seat: int) -> bool:
	return seats.has(seat) and bool(seats[seat].forfeited)


# Spielt eine Vertretung statt des Menschen (Stufe 2 und 3).
func is_machine_controlled(seat: int) -> bool:
	return stage_of(seat) >= 2


func rejoin_allowed(seat: int) -> bool:
	return seats.has(seat) and not bool(seats[seat].forfeited)


# Verstreicht Zeit. Gibt true zurueck, wenn sich eine Stufe geaendert hat.
func tick(delta: float) -> bool:
	var changed := false
	for seat in seats:
		var s: Dictionary = seats[seat]
		if bool(s.present) or bool(s.forfeited):
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
				s.forfeited = true
			stage_changed.emit(int(seat), new_stage)
			changed = true
	return changed

# Plaetze mit offener Strafkarte (Wiedereinstieg), einmal abholen.
func take_pending_penalties() -> Array:
	var out: Array = []
	for seat in seats:
		if bool(seats[seat].pending_penalty):
			seats[seat].pending_penalty = false
			out.append(int(seat))
	return out
