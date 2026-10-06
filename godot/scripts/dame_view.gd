extends RefCounted
class_name DameView

# Oeffentliche Sicht fuer genau einen Platz. UI und KI lesen nur das hier.
# Gezeigt wird: eigene bekannte Karten, fremde Karten aus dem eigenen Gedaechtnis,
# die oberste Ablagekarte, Zaehler. Nie: Stapelreihenfolge, fremde unbekannte Karten.

static func for_viewer(rules: RefCounted, viewer_seat: int) -> Dictionary:
	var state: Dictionary = rules.state
	var phase := str(state.phase)
	var reveal_all := phase == "round_end" or phase == "game_over"
	var viewer: Dictionary = state.players[viewer_seat]
	var seen_ids: Array = viewer.get("seen_ids", [])
	var players_out: Array = []
	for p in state.players:
		var seat := int(p.seat)
		var own := seat == viewer_seat
		var cards: Array = []
		for i in range(p.hand.size()):
			var card: Dictionary = p.hand[i]
			var show := reveal_all or bool(card.face_up)
			if own and p.known.has(i):
				show = true
			if not own and seen_ids.has(str(card.id)):
				show = true
			cards.append(_card(card, i, show))
		players_out.append({
			"seat": seat,
			"name": str(p.name),
			"is_ai": bool(p.is_ai),
			"difficulty": str(p.get("difficulty", "medium")),
			"card_count": p.hand.size(),
			"penalty_count": p.penalty_cards.size(),
			"score": int(p.score),
			"total_score": int(p.total_score),
			"eliminated": bool(p.eliminated),
			"locked": bool(p.locked),
			"is_current": seat == int(state.current_index),
			"is_self": own,
			"role": rules._seat_role(viewer_seat, seat),
			"deal_penalties": int(p.get("deal_penalties", 0)),
			"angle": rules.seat_angle(viewer_seat, seat),
			"cards": cards,
		})
	var is_my_turn := int(state.current_index) == viewer_seat
	var drawn = null
	if state.drawn_card != null:
		var public_draw := str(state.get("drawn_from", "deck")) == "discard"
		if is_my_turn or public_draw:
			drawn = _card(state.drawn_card, -1, true)
		else:
			drawn = _card(state.drawn_card, -1, false)
	var top = rules.top_discard()
	var look = rules._private_look(viewer_seat)
	return {
		"viewer_seat": viewer_seat,
		"seat_count": rules.seat_count(),
		"phase": phase,
		"turn_step": str(state.turn_step),
		"round": int(state.round),
		"deal": int(state.deal),
		"safe_phase": bool(state.safe_phase),
		"current_index": int(state.current_index),
		"current_name": str(rules.current_player().name),
		"is_my_turn": is_my_turn,
		"drawn": drawn,
		"discard_top": _card(top, -1, true) if top != null else null,
		"discard_count": state.discard.size(),
		"deck_count": state.deck.size(),
		"must_take_queen": rules.must_take_queen(),
		"can_call_dame": is_my_turn and rules.can_call_dame(),
		"dame_caller_index": int(state.dame_caller_index),
		"dame_turns_left": int(state.dame_turns_left),
		"winner_index": int(state.winner_index),
		"last_round_false_call": bool(state.get("last_round_false_call", false)),
		"last_action": str(state.last_action),
		"log": state.log.duplicate(),
		"power_effects": bool(state.get("power_effects", false)),
		"private_look": look.duplicate() if look != null else null,
		"players": players_out,
	}


static func _card(card: Dictionary, index: int, show: bool) -> Dictionary:
	if not show:
		return {"index": index, "known": false, "rank": "", "suit": "", "value": -1}
	return {
		"index": index,
		"known": true,
		"rank": str(card.rank),
		"suit": str(card.suit),
		"value": int(card.value),
	}
