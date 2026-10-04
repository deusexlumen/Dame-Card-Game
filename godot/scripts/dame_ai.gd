extends RefCounted
class_name DameAI

# KI spielt den eigenen Zug zu Ende. Keine Reaktion ausserhalb des Zuges.

var last_completed := false
var last_error := ""

func complete_turn(rules) -> bool:
	last_completed = false
	last_error = ""
	var seat := int(rules.state.current_index)
	var player: Dictionary = rules.state.players[seat]
	if not bool(player.is_ai):
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
		var action := _choose(rules, seat)
		var result: Dictionary = rules.apply_action(action)
		if not bool(result.get("ok", false)):
			last_error = str(result.get("reason", "KI-Zug gescheitert"))
			var fallback: Dictionary = rules.apply_action({"type": "end_turn", "seat": seat})
			if not bool(fallback.get("ok", false)):
				last_completed = false
				return false
	var left := int(rules.state.current_index) != seat or str(rules.state.phase) == "round_end"
	var clean := rules.state.drawn_card == null
	last_completed = left and clean
	if not last_completed and last_error == "":
		last_error = "KI hat den Zug nicht beendet"
	return last_completed


func _choose(rules, seat: int) -> Dictionary:
	var step := str(rules.state.turn_step)
	if step == "jack":
		return {
			"type": "look_card",
			"seat": seat,
			"target_seat": (seat + 1) % int(rules.SEAT_COUNT),
			"hand_index": 0,
		}
	if step == "king":
		var king_player: Dictionary = rules.state.players[seat]
		var chosen := _worst_known(king_player)
		if chosen < 0:
			chosen = 0
		return {
			"type": "king_swap",
			"seat": seat,
			"opponent_seat": (seat + 1) % int(rules.SEAT_COUNT),
			"opponent_index": 0,
			"chosen_index": chosen,
		}
	if step == "draw":
		if rules.must_take_queen():
			return {"type": "draw_discard", "seat": seat}
		var top = rules.top_discard()
		if top != null and int(top.value) <= 3:
			return {"type": "draw_discard", "seat": seat}
		return {"type": "draw_deck", "seat": seat}
	if step == "play":
		var drawn: Dictionary = rules.state.drawn_card
		var player: Dictionary = rules.state.players[seat]
		var worst := _worst_known(player)
		if worst >= 0 and int(drawn.value) < int(player.hand[worst].value):
			return {"type": "swap", "seat": seat, "hand_index": worst}
		return {"type": "discard_drawn", "seat": seat}
	return {"type": "end_turn", "seat": seat}


func _worst_known(player: Dictionary) -> int:
	var worst := -1
	var worst_value := -1
	for k in player.known:
		var idx := int(k)
		if idx < 0 or idx >= player.hand.size():
			continue
		var value := int(player.hand[idx].value)
		if value > worst_value:
			worst_value = value
			worst = idx
	return worst
