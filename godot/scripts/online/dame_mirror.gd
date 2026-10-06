extends RefCounted
class_name DameMirror

# Geschwaerzter Spielzustand fuer genau einen Platz (Online-Spiel).
# Der Server schickt jedem Client diesen Zustand statt des echten. Er hat dieselbe
# Form wie DameRules.state, damit der Tisch unveraendert darauf laufen kann.
# Verdeckte Karten werden zu Platzhaltern: Karten-IDs enthalten Farbe und Rang
# ("hearts-7-3") und duerfen deshalb nie fuer unbekannte Karten mitgehen.
# Der Seed faellt weg, sonst liesse sich jeder Stapel nachrechnen.
# Abgesichert durch: DameView.for_viewer(Spiegel) == DameView.for_viewer(Original).

const HIDDEN_PREFIX := "x-"

static func for_viewer(rules: RefCounted, viewer_seat: int) -> Dictionary:
	var src: Dictionary = rules.state
	var out: Dictionary = src.duplicate(true)
	var phase := str(src.phase)
	var reveal_all := phase == "round_end" or phase == "game_over"
	var viewer: Dictionary = src.players[viewer_seat]
	var seen_ids: Array = viewer.get("seen_ids", [])
	var counter := [0]

	out.seed = 0
	# Stapel: nur die Anzahl ist oeffentlich.
	out.deck = _hidden_list(src.deck.size(), "deck", counter)
	# Ablage: oberste Karte offen, der Rest nur als Anzahl.
	var discard: Array = _hidden_list(maxi(src.discard.size() - 1, 0), "discard", counter)
	if not src.discard.is_empty():
		discard.append(src.discard.back().duplicate(true))
	out.discard = discard

	for i in range(src.players.size()):
		var p: Dictionary = src.players[i]
		var q: Dictionary = out.players[i]
		var own := int(p.seat) == viewer_seat
		var hand: Array = []
		for idx in range(p.hand.size()):
			var card: Dictionary = p.hand[idx]
			var show := reveal_all or bool(card.face_up)
			if own and p.known.has(idx):
				show = true
			if not own and seen_ids.has(str(card.id)):
				show = true
			hand.append(card.duplicate(true) if show else _hidden("hand", counter))
		q.hand = hand
		# Strafkarten kennt niemand, auch der Besitzer nicht.
		q.penalty_cards = _hidden_list(p.penalty_cards.size(), "pen", counter)
		if not own:
			# Fremdes Gedaechtnis ist privat.
			q.known = []
			q.seen_ids = []

	if src.drawn_card != null:
		var is_my_turn := int(src.current_index) == viewer_seat
		var public_draw := str(src.get("drawn_from", "deck")) == "discard"
		out.drawn_card = src.drawn_card.duplicate(true) if (is_my_turn or public_draw) else _hidden("drawn", counter)

	if src.get("last_look", null) != null and int(src.get("last_look_by", -1)) != viewer_seat:
		out.last_look = null
	var swap = src.get("last_king_swap", null)
	if swap != null and int(swap.get("from_seat", -1)) != viewer_seat:
		# Den Tausch selbst sieht jeder, die angesehene Karte nur der Tauschende.
		var public_swap: Dictionary = swap.duplicate(true)
		public_swap.erase("look_own_id")
		public_swap.erase("look_rank")
		public_swap.erase("look_suit")
		out.last_king_swap = public_swap
	out.last_queen_penalty = null
	return out


# Laedt einen Spiegel in eine DameRules-Instanz des Clients. Der Client spielt
# damit keine Regeln, er stellt nur dar; Aktionen gehen an den Server.
static func load_into(rules: RefCounted, mirror: Dictionary) -> bool:
	if typeof(mirror) != TYPE_DICTIONARY:
		return false
	for key in rules.REQUIRED_STATE_KEYS:
		if not mirror.has(key):
			return false
	var previous: Dictionary = rules.state
	rules.state = mirror.duplicate(true)
	if not rules.assert_zones():
		rules.state = previous
		return false
	return true


static func is_hidden(card) -> bool:
	return typeof(card) == TYPE_DICTIONARY and str(card.get("id", "")).begins_with(HIDDEN_PREFIX)


static func _hidden(zone: String, counter: Array) -> Dictionary:
	counter[0] += 1
	return {"id": "%s%s-%d" % [HIDDEN_PREFIX, zone, counter[0]], "suit": "", "rank": "", "value": 0, "face_up": false}


static func _hidden_list(count: int, zone: String, counter: Array) -> Array:
	var list: Array = []
	for _i in range(count):
		list.append(_hidden(zone, counter))
	return list
