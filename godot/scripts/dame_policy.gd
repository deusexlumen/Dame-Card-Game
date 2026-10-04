extends RefCounted
class_name DamePolicy

# KI-Entscheidungen. Liest nur eine DameView (Dictionary), nie den Regelzustand.
# Schwierigkeit aendert die Strategie, nicht die Sicht.

# Durchschnittswert einer unbekannten Karte (52 Karten, Summe 300).
const UNKNOWN_VALUE := 5.8

static func choose(view: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var me := _me(view)
	var difficulty := str(me.difficulty)
	var seat := int(view.viewer_seat)
	match str(view.turn_step):
		"draw":
			return _choose_draw(view, me, difficulty, rng)
		"play":
			return _choose_play(view, me, difficulty, rng)
		"jack":
			return _choose_jack(view, me, difficulty, rng)
		"king":
			return _choose_king(view, me, difficulty, rng)
		"extra":
			return _choose_extra(view, me, difficulty)
	return {"type": "end_turn", "seat": seat}


static func estimate_own_score(view: Dictionary) -> float:
	var me := _me(view)
	var total := 0.0
	for card in me.cards:
		total += float(card.value) if bool(card.known) else UNKNOWN_VALUE
	# Strafkarten sind verdeckt und unbekannt.
	total += float(me.penalty_count) * UNKNOWN_VALUE
	return total


static func _me(view: Dictionary) -> Dictionary:
	return view.players[int(view.viewer_seat)]


static func _choose_draw(view: Dictionary, me: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> Dictionary:
	var seat := int(view.viewer_seat)
	if bool(view.can_call_dame) and _should_call(view, difficulty):
		return {"type": "call_dame", "seat": seat}
	if bool(view.must_take_queen):
		return {"type": "draw_discard", "seat": seat}
	var top = view.discard_top
	if top == null:
		return {"type": "draw_deck", "seat": seat}
	var top_value := int(top.value)
	match difficulty:
		"easy":
			return {"type": "draw_discard" if rng.randf() < 0.3 else "draw_deck", "seat": seat}
		"hard":
			var worst := _worst_slot_value(me)
			if top_value <= 2 or float(top_value) < worst - 2.0:
				return {"type": "draw_discard", "seat": seat}
		_:
			if top_value <= 3:
				return {"type": "draw_discard", "seat": seat}
	return {"type": "draw_deck", "seat": seat}


static func _choose_play(view: Dictionary, me: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> Dictionary:
	var seat := int(view.viewer_seat)
	var drawn = view.drawn
	if drawn == null or not bool(drawn.known):
		return {"type": "discard_drawn", "seat": seat}
	var value := int(drawn.value)
	var cards: Array = me.cards
	if cards.is_empty():
		return {"type": "discard_drawn", "seat": seat}
	if difficulty == "easy":
		if str(drawn.rank) == "Q" or rng.randf() < 0.4:
			return {"type": "swap", "seat": seat, "hand_index": rng.randi_range(0, cards.size() - 1)}
		return {"type": "discard_drawn", "seat": seat}
	# Abgelegte Dame kostet eine Strafkarte: Dame immer behalten.
	var keep_queen := str(drawn.rank) == "Q"
	var worst_known := -1
	var worst_value := -1
	var unknown := -1
	for card in cards:
		if bool(card.known):
			if int(card.value) > worst_value:
				worst_value = int(card.value)
				worst_known = int(card.index)
		elif unknown < 0:
			unknown = int(card.index)
	var margin := 0 if difficulty == "hard" else 1
	if worst_known >= 0 and value < worst_value - margin:
		return {"type": "swap", "seat": seat, "hand_index": worst_known}
	var unknown_limit := 4 if difficulty == "hard" else 3
	if unknown >= 0 and value <= unknown_limit:
		return {"type": "swap", "seat": seat, "hand_index": unknown}
	if keep_queen:
		var target := worst_known if worst_known >= 0 else (unknown if unknown >= 0 else 0)
		return {"type": "swap", "seat": seat, "hand_index": target}
	return {"type": "discard_drawn", "seat": seat}


static func _choose_jack(view: Dictionary, me: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> Dictionary:
	var seat := int(view.viewer_seat)
	var targets: Array = []
	if difficulty != "easy":
		# Erst eigene unbekannte Karte ansehen, dann eine fremde.
		for card in me.cards:
			if not bool(card.known):
				return {"type": "look_card", "seat": seat, "target_seat": seat, "hand_index": int(card.index)}
	for p in _opponents(view, false):
		for card in p.cards:
			if not bool(card.known):
				targets.append([int(p.seat), int(card.index)])
	if difficulty == "easy":
		for card in me.cards:
			targets.append([seat, int(card.index)])
	if targets.is_empty():
		var any_index := 0
		for card in me.cards:
			any_index = int(card.index)
		return {"type": "look_card", "seat": seat, "target_seat": seat, "hand_index": any_index}
	var pick: Array = targets[0] if difficulty == "hard" else targets[rng.randi_range(0, targets.size() - 1)]
	if difficulty == "hard":
		# Beim Fuehrenden nachsehen.
		var leader := _leader(view)
		for tg in targets:
			if int(tg[0]) == leader:
				pick = tg
				break
	return {"type": "look_card", "seat": seat, "target_seat": int(pick[0]), "hand_index": int(pick[1])}


static func _choose_king(view: Dictionary, me: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> Dictionary:
	var seat := int(view.viewer_seat)
	var opponents := _opponents(view, true)
	if opponents.is_empty() or me.cards.is_empty():
		return {"type": "end_turn", "seat": seat}
	var chosen := 0
	var worst_value := -1
	var unknown := -1
	for card in me.cards:
		if bool(card.known):
			if int(card.value) > worst_value:
				worst_value = int(card.value)
				chosen = int(card.index)
		elif unknown < 0:
			unknown = int(card.index)
	# Bekannte gute Karte nicht weggeben: dann lieber eine unbekannte.
	if (worst_value < 0 or worst_value <= 3) and unknown >= 0:
		chosen = unknown
	if difficulty == "easy":
		chosen = rng.randi_range(0, me.cards.size() - 1)
	var opp: Dictionary = opponents[0]
	var opp_index := 0
	if difficulty == "easy":
		opp = opponents[rng.randi_range(0, opponents.size() - 1)]
		opp_index = rng.randi_range(0, opp.cards.size() - 1)
	elif difficulty == "hard":
		# Bekannte niedrige fremde Karte holen, sonst beim Fuehrenden tauschen.
		var best_value := 99
		for p in opponents:
			for card in p.cards:
				if bool(card.known) and int(card.value) < best_value:
					best_value = int(card.value)
					opp = p
					opp_index = int(card.index)
		if best_value == 99:
			var leader := _leader(view)
			for p in opponents:
				if int(p.seat) == leader:
					opp = p
			opp_index = rng.randi_range(0, opp.cards.size() - 1)
	else:
		opp = opponents[rng.randi_range(0, opponents.size() - 1)]
		opp_index = rng.randi_range(0, opp.cards.size() - 1)
	return {
		"type": "king_swap",
		"seat": seat,
		"opponent_seat": int(opp.seat),
		"opponent_index": opp_index,
		"chosen_index": chosen,
	}


static func _choose_extra(view: Dictionary, me: Dictionary, difficulty: String) -> Dictionary:
	var seat := int(view.viewer_seat)
	var top = view.discard_top
	if difficulty != "easy" and top != null:
		for card in me.cards:
			# Nur mit sicherem Wissen ablegen, sonst droht eine Strafkarte.
			if bool(card.known) and str(card.rank) == str(top.rank) and str(card.rank) != "Q":
				return {"type": "discard_extra", "seat": seat, "hand_index": int(card.index)}
	return {"type": "end_turn", "seat": seat}


static func _should_call(view: Dictionary, difficulty: String) -> bool:
	var estimate := estimate_own_score(view)
	match difficulty:
		"easy":
			return false
		"hard":
			# Nur mit sicherem Vorsprung: Gegner schaetzen nach Kartenzahl.
			var best_other := 999.0
			for p in _opponents(view, false):
				var est := 0.0
				for card in p.cards:
					est += float(card.value) if bool(card.known) else UNKNOWN_VALUE * 0.75
				best_other = minf(best_other, est)
			return estimate <= 8.0 and estimate < best_other - 2.0
	return estimate < 10.0


static func _worst_slot_value(me: Dictionary) -> float:
	var worst := 0.0
	for card in me.cards:
		var v := float(card.value) if bool(card.known) else UNKNOWN_VALUE
		worst = maxf(worst, v)
	return worst


# Gegner mit Karten. Fuer den Koenig ohne gelockte Ansager.
static func _opponents(view: Dictionary, for_king: bool) -> Array:
	var out: Array = []
	for p in view.players:
		if bool(p.is_self) or bool(p.eliminated) or p.cards.is_empty():
			continue
		if for_king and bool(p.locked):
			continue
		out.append(p)
	return out


static func _leader(view: Dictionary) -> int:
	var best := -1
	var best_score := 99999
	for p in _opponents(view, false):
		if int(p.total_score) < best_score:
			best_score = int(p.total_score)
			best = int(p.seat)
	return best
