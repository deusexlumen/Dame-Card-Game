extends RefCounted
class_name DameAI

# Treiber fuer KI-Zuege: holt die Sicht, fragt die Policy, wendet die Aktion an.
# Die Policy sieht nie den Regelzustand. Keine Reaktion ausserhalb des eigenen Zuges.

const DameViewScript = preload("res://scripts/dame_view.gd")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")

var last_completed := false
var last_error := ""
# Zuletzt angewandte Aktion, damit der Tisch sie darstellen kann.
var last_action: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(seed: int = 1) -> void:
	rng.seed = seed


# Ein einzelner KI-Schritt. Gibt das Ergebnis von apply_action zurueck.
func step(rules) -> Dictionary:
	var seat := int(rules.state.current_index)
	if not bool(rules.state.players[seat].is_ai):
		return {"ok": false, "reason": "nicht die KI"}
	var view: Dictionary = DameViewScript.for_viewer(rules, seat)
	var action: Dictionary = DamePolicyScript.choose(view, rng)
	var result: Dictionary = rules.apply_action(action)
	if bool(result.get("ok", false)):
		last_action = action
		return result
	# Ungueltige Policy-Entscheidung: sichere Ersatzaktion fuer diesen Schritt.
	last_error = str(result.get("reason", "KI-Zug gescheitert"))
	last_action = fallback_action(rules, seat)
	return rules.apply_action(last_action)


func complete_turn(rules) -> bool:
	last_completed = false
	last_error = ""
	var seat := int(rules.state.current_index)
	if not bool(rules.state.players[seat].is_ai):
		last_error = "nicht die KI"
		return false
	var guard := 0
	while guard < 8:
		guard += 1
		if int(rules.state.current_index) != seat:
			break
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			break
		var result := step(rules)
		if not bool(result.get("ok", false)):
			last_error = str(result.get("reason", "KI-Zug gescheitert"))
			return false
	var left := int(rules.state.current_index) != seat or str(rules.state.phase) == "round_end" or str(rules.state.phase) == "game_over"
	last_completed = left and rules.state.drawn_card == null
	if not last_completed and last_error == "":
		last_error = "KI hat den Zug nicht beendet"
	return last_completed


# Sichere Standardaktion fuer den aktuellen Schritt (auch fuer abgelaufene Zugzeit).
func fallback_action(rules, seat: int) -> Dictionary:
	var view: Dictionary = DameViewScript.for_viewer(rules, seat)
	match str(view.turn_step):
		"draw":
			if int(view.deck_count) == 0 and int(view.discard_count) == 0:
				return {"type": "end_turn", "seat": seat}
			if bool(view.must_take_queen) or int(view.deck_count) == 0:
				return {"type": "draw_discard", "seat": seat}
			return {"type": "draw_deck", "seat": seat}
		"play":
			return {"type": "discard_drawn", "seat": seat}
		"jack":
			for p in view.players:
				if bool(p.eliminated):
					continue
				for card in p.cards:
					return {"type": "look_card", "seat": seat, "target_seat": int(p.seat), "hand_index": int(card.index)}
		"king":
			for p in view.players:
				if bool(p.is_self) or bool(p.eliminated) or bool(p.locked) or p.cards.is_empty():
					continue
				return {"type": "king_swap", "seat": seat, "opponent_seat": int(p.seat), "opponent_index": 0, "chosen_index": 0}
	return {"type": "end_turn", "seat": seat}
