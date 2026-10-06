extends RefCounted
class_name DameRules

# Reine Regeln. Keine Szene, keine Darstellung.
# Verbindlich: CONCEPT_DECISIONS.md
# 1 Extra-Ablegen nur im eigenen Zug
# 2 genau eine Strafkarte
# 3 abgelegte Dame liegt offen und erzwingt (ausser Safe Phase / Rundenende)
# 4 kein Mitwerfen ausserhalb des eigenen Zuges
# 5 nach der Ansage genau ein Zug fuer jeden anderen Spieler;
#   falsche Ansage: naechste Ausgabe 5 statt 4

const PENALTY_CARD_COUNT := 1
const HAND_SIZE := 4
const SEAT_COUNT := 4
# Bis zu 6 Plaetze; Decks = ceil(Plaetze / 4) (CONCEPT_DECISIONS §9).
const MAX_SEATS := 6
const DECK_SIZE := 52
const SAFE_CIRCUITS := 2
const SUITS := ["hearts", "diamonds", "clubs", "spades"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const VALUES := {
	"A": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7,
	"8": 8, "9": 9, "10": 10, "J": 10, "Q": 0, "K": 10,
}
# Bube: README, beim Ausspielen eine beliebige verdeckte Karte ansehen, kein Tausch.
# Koenig: nicht die README-Fassung. Buxe: eigene verdeckte Karte ansehen,
# dann blind mit einer gegnerischen Karte tauschen. Gegnerkarte bleibt ungesehen.
# Danach bleiben beide verdeckt.
# Ass und Zehn: README nennt keine Sonderwirkung. Normale Raenge.
# Nicht uebernommen: applyJackEffect, applyKingEffect, applyAceEffect, applyTenEffect.
const STAGE1_PLAIN_RANKS := {
	"A": "Ass",
	"10": "Zehn",
}

const MIN_SEATS := 2
const SAVE_VERSION := 1
const DIFFICULTIES := ["easy", "medium", "hard"]
const DEFAULT_NAMES := {
	2: ["Spieler", "Gegenüber"],
	3: ["Spieler", "Links", "Rechts"],
	4: ["Spieler", "Links", "Gegenüber", "Rechts"],
	5: ["Spieler", "Platz 2", "Platz 3", "Platz 4", "Platz 5"],
	6: ["Spieler", "Platz 2", "Platz 3", "Platz 4", "Platz 5", "Platz 6"],
}
# Pflichtfelder fuer from_dict.
const REQUIRED_STATE_KEYS := [
	"players", "seat_count", "seed", "deal", "current_index", "round_start_index",
	"deck", "discard", "phase", "round", "safe_phase", "turn_step", "drawn_card",
	"dame_caller_index", "dame_turns_left", "winner_index", "last_action", "log",
]
const PHASES := ["play", "dame_called", "round_end", "game_over"]
const TURN_STEPS := ["draw", "play", "jack", "king", "extra"]

var state: Dictionary = {}
var zone_error := ""

func start_match(config: Dictionary = {}) -> void:
	var seed := int(config.get("seed", 1))
	var seat_count := clampi(int(config.get("seat_count", SEAT_COUNT)), MIN_SEATS, MAX_SEATS)
	var ai_seats: Array = config.get("ai_seats", [int(config.get("ai_seat", mini(2, seat_count - 1)))])
	var difficulties: Dictionary = config.get("difficulties", {})
	var names: Array = config.get("names", DEFAULT_NAMES[seat_count])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool := _fresh_pool(deck_count_for(seat_count))
	var hands: Array = []
	var preset_hands = config.get("preset_hands", null)
	var draw_first = config.get("draw_first", null)
	if preset_hands != null:
		for seat in range(seat_count):
			var built: Array = []
			for spec in preset_hands[seat]:
				built.append(_take_spec(pool, str(spec.suit), str(spec.rank)))
			hands.append(built)
	else:
		_shuffle(pool, rng)
		for seat in range(seat_count):
			var dealt: Array = []
			for _i in range(HAND_SIZE):
				dealt.append(pool.pop_back())
			hands.append(dealt)
	var deck: Array = []
	if draw_first != null:
		var first_cards: Array = []
		for spec in draw_first:
			first_cards.append(_take_spec(pool, str(spec.suit), str(spec.rank)))
		deck = pool.duplicate()
		# pop_back zieht vom Ende: erste Wunschkarte muss ganz hinten liegen.
		for i in range(first_cards.size() - 1, -1, -1):
			deck.append(first_cards[i])
	else:
		deck = pool
		if preset_hands != null:
			_shuffle(deck, rng)
	var players: Array = []
	for seat in range(seat_count):
		var known: Array = []
		if hands[seat].size() > 0:
			known.append(0)
		if hands[seat].size() > 1:
			known.append(1)
		var difficulty := str(difficulties.get(seat, "medium"))
		if not DIFFICULTIES.has(difficulty):
			difficulty = "medium"
		players.append({
			"seat": seat,
			"name": str(names[seat]) if seat < names.size() else "Platz %d" % (seat + 1),
			"is_ai": ai_seats.has(seat),
			"difficulty": difficulty,
			"hand": hands[seat],
			"known": known,
			"seen_ids": [],
			"deal_penalties": 0,
			"penalty_cards": [],
			"score": 0,
			"total_score": 0,
			"eliminated": false,
			"has_called_dame": false,
			"locked": false,
		})
	state = {
		"players": players,
		"seat_count": seat_count,
		"seed": seed,
		"deal": 1,
		"winner_index": -1,
		"current_index": 0,
		"round_start_index": 0,
		"deck": deck,
		"discard": [],
		"phase": "play",
		"round": 1,
		"safe_phase": true,
		"turn_step": "draw",
		"drawn_card": null,
		"dame_caller_index": -1,
		"dame_turns_left": 0,
		"last_action": "Runde gestartet. %d Plätze." % seat_count,
		"last_queen_penalty": null,
		"queen_penalties_given": 0,
		"false_call_penalties_given": 0,
		"last_round_false_call": false,
		# Vorbereitet, in V1 aus: Ass und Zehn ohne Wirkung (CONCEPT_DECISIONS §9).
		"power_effects": bool(config.get("power_effects", false)),
		"ai_turns_finished": 0,
		"last_look": null,
		"last_look_by": -1,
		"last_king_swap": null,
		"log": ["%d Plätze. Ausgabe 1, Runde 1, Safe Phase." % seat_count],
	}


func apply_action(action: Dictionary) -> Dictionary:
	var type := str(action.get("type", ""))
	var seat := int(action.get("seat", -1))
	if seat < 0:
		seat = int(state.current_index)
	if type == "start_next_round":
		return _start_next_round()
	if str(state.phase) == "round_end" or str(state.phase) == "game_over":
		return _fail("Runde ist vorbei")
	if seat != int(state.current_index):
		if type == "discard_extra":
			return _fail("Extra-Ablegen nur im eigenen Zug")
		return _fail("Nicht am Zug")
	var player: Dictionary = state.players[seat]
	if bool(player.locked) and type != "end_turn" and type != "timeout_penalty":
		return _fail("Karten des Ansagers sind gelockt")
	match type:
		"draw_deck":
			return _draw(false)
		"draw_discard":
			return _draw(true)
		"swap":
			return _swap(int(action.get("hand_index", -1)))
		"discard_drawn":
			return _discard_drawn()
		"discard_extra":
			return _discard_extra(int(action.get("hand_index", -1)))
		"look_card":
			return _look_card(int(action.get("target_seat", -1)), int(action.get("hand_index", -1)))
		"king_swap":
			return _king_swap(int(action.get("opponent_seat", -1)), int(action.get("opponent_index", -1)), int(action.get("chosen_index", -1)))
		"call_dame":
			return _call_dame()
		"end_turn":
			return _end_turn()
		"timeout_penalty":
			return _timeout_penalty()
		_:
			return _fail("Unbekannte Aktion")


func must_take_queen() -> bool:
	if str(state.turn_step) != "draw":
		return false
	if bool(state.safe_phase):
		return false
	if str(state.phase) == "round_end" or str(state.phase) == "game_over":
		return false
	var top = top_discard()
	return top != null and str(top.rank) == "Q"


func can_call_dame() -> bool:
	if bool(state.safe_phase):
		return false
	if str(state.phase) != "play":
		return false
	if int(state.dame_caller_index) >= 0:
		return false
	if str(state.turn_step) != "draw":
		return false
	if state.drawn_card != null:
		return false
	return true


func top_discard():
	var pile: Array = state.discard
	if pile.is_empty():
		return null
	return pile.back()


func current_player() -> Dictionary:
	return state.players[int(state.current_index)]


func seat_count() -> int:
	return int(state.get("seat_count", SEAT_COUNT))


# Jede Karten-ID genau einmal in Stapel, Ablage, gezogener Karte, Hand oder Strafkarten.
func assert_zones() -> bool:
	zone_error = ""
	var seen := {}
	var zones: Array = [["Stapel", state.deck], ["Ablage", state.discard]]
	if state.drawn_card != null:
		zones.append(["gezogen", [state.drawn_card]])
	for p in state.players:
		zones.append(["Hand %d" % int(p.seat), p.hand])
		zones.append(["Strafe %d" % int(p.seat), p.penalty_cards])
	for zone in zones:
		for card in zone[1]:
			var id := str(card.id)
			if seen.has(id):
				zone_error = "Karte %s in %s und %s" % [id, seen[id], zone[0]]
				return false
			seen[id] = zone[0]
	var total := DECK_SIZE * deck_count_for(seat_count())
	if seen.size() != total:
		zone_error = "%d statt %d Karten im Spiel" % [seen.size(), total]
		return false
	return true


func to_dict() -> Dictionary:
	return {"save_version": SAVE_VERSION, "state": state.duplicate(true)}


# Laedt einen Spielstand. Ungueltige Daten: false, Zustand bleibt unveraendert.
func from_dict(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		zone_error = "Spielstand ist kein Dictionary"
		return false
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		zone_error = "Spielstand-Version passt nicht"
		return false
	var incoming = data.get("state", null)
	if typeof(incoming) != TYPE_DICTIONARY:
		zone_error = "Spielstand ohne Zustand"
		return false
	for key in REQUIRED_STATE_KEYS:
		if not incoming.has(key):
			zone_error = "Spielstand ohne Feld %s" % key
			return false
	var n := int(incoming.seat_count)
	if n < MIN_SEATS or n > MAX_SEATS or typeof(incoming.players) != TYPE_ARRAY or incoming.players.size() != n:
		zone_error = "Spielstand mit falscher Platzzahl"
		return false
	if not PHASES.has(str(incoming.phase)) or not TURN_STEPS.has(str(incoming.turn_step)):
		zone_error = "Spielstand mit unbekannter Phase"
		return false
	var current := int(incoming.current_index)
	if current < 0 or current >= n:
		zone_error = "Spielstand mit ungueltigem Platz am Zug"
		return false
	var previous := state
	state = incoming.duplicate(true)
	if not assert_zones():
		var reason := zone_error
		state = previous
		zone_error = reason
		return false
	return true


# Winkel eines Platzes aus Sicht des Betrachters im 60-Grad-Raster (Grad, negativ = links).
# Wenige Spieler belegen symmetrische Teilmengen der 6 Plaetze.
const SEAT_ANGLES := {
	2: [180],
	3: [120, 240],
	4: [120, 180, 240],
	5: [60, 120, 240, 300],
	6: [60, 120, 180, 240, 300],
}

func seat_angle(viewer: int, seat: int) -> float:
	if seat == viewer:
		return 0.0
	var n := seat_count()
	var offset := (seat - viewer + n) % n
	var list: Array = SEAT_ANGLES.get(n, SEAT_ANGLES[4])
	return -float(list[clampi(offset - 1, 0, list.size() - 1)])


func _seat_role(viewer: int, seat: int) -> String:
	if seat == viewer:
		return "self"
	var n := seat_count()
	var offset := (seat - viewer + n) % n
	if n == 2:
		return "opposite"
	if n == 3:
		return "left" if offset == 1 else "right"
	if offset == 2:
		return "opposite"
	return "left" if offset == 1 else "right"


func _draw(from_discard: bool) -> Dictionary:
	if str(state.turn_step) != "draw":
		return _fail("Ziehen ist jetzt nicht dran")
	if state.drawn_card != null:
		return _fail("Es liegt schon eine gezogene Karte")
	if must_take_queen() and not from_discard:
		return _fail("Zwangszug: die offene Dame muss genommen werden")
	var card = null
	if from_discard:
		if state.discard.is_empty():
			return _fail("Ablage ist leer")
		card = state.discard.pop_back()
	else:
		card = _pull_deck()
		if card == null:
			return _fail("Keine Karten mehr im Stapel")
	card.face_up = true
	state.drawn_card = card
	state.drawn_from = "discard" if from_discard else "deck"
	state.turn_step = "play"
	# Verdeckt gezogene Karte nie ins oeffentliche Protokoll.
	if from_discard:
		return _ok("%s nimmt %s von der Ablage." % [_who(), card_label(card)])
	return _ok("%s zieht vom Stapel." % _who())


func _swap(hand_index: int) -> Dictionary:
	if str(state.turn_step) != "play" or state.drawn_card == null:
		return _fail("Kein Tausch ohne gezogene Karte")
	var player: Dictionary = current_player()
	if hand_index < 0 or hand_index >= player.hand.size():
		return _fail("Ungültiger Kartenindex")
	var discarded: Dictionary = player.hand[hand_index]
	var incoming: Dictionary = state.drawn_card
	incoming.face_up = false
	player.hand[hand_index] = incoming
	if not player.known.has(hand_index):
		player.known.append(hand_index)
	state.drawn_card = null
	_place_on_discard(discarded, player)
	return _ok(_played_message("%s tauscht und legt %s ab" % [_who(), card_label(discarded)]))


func _discard_drawn() -> Dictionary:
	if str(state.turn_step) != "play" or state.drawn_card == null:
		return _fail("Keine gezogene Karte zum Ablegen")
	var card: Dictionary = state.drawn_card
	state.drawn_card = null
	_place_on_discard(card, current_player())
	return _ok(_played_message("%s legt %s ab" % [_who(), card_label(card)]))


func _discard_extra(hand_index: int) -> Dictionary:
	# Abschnitt 1 und 4: nur der Spieler, der gerade am Zug ist.
	if str(state.turn_step) != "extra":
		return _fail("Extra-Ablegen nur im eigenen Zug nach dem Ablegen")
	var player: Dictionary = current_player()
	if hand_index < 0 or hand_index >= player.hand.size():
		return _fail("Ungültiger Kartenindex")
	var top = top_discard()
	if top == null:
		return _fail("Keine Ablage")
	var card: Dictionary = player.hand[hand_index]
	if str(card.rank) != str(top.rank):
		_give_one_penalty(player, "illegal_extra")
		return _fail("Passt nicht. Genau eine Strafkarte")
	player.hand.remove_at(hand_index)
	_shift_known(player, hand_index)
	var replacement = _pull_deck()
	if replacement != null:
		replacement.face_up = false
		player.hand.append(replacement)
	_place_on_discard(card, player)
	if player.hand.is_empty() and str(state.phase) == "play" and int(state.dame_caller_index) < 0:
		# Leere Hand: Dame wird automatisch gerufen.
		return _ok("Extra-Karte abgelegt, Hand leer. " + _call_dame_now())
	return _ok(_played_message("%s legt extra %s ab" % [_who(), card_label(card)]))


func _call_dame() -> Dictionary:
	if not can_call_dame():
		return _fail("Dame ist jetzt nicht rufbar")
	return _ok(_call_dame_now())


func _call_dame_now() -> String:
	var caller: Dictionary = current_player()
	caller.has_called_dame = true
	caller.locked = true
	var caller_index := int(state.current_index)
	state.dame_caller_index = caller_index
	state.phase = "dame_called"
	state.dame_turns_left = _other_active_count(caller_index)
	state.current_index = _next_active(caller_index)
	state.turn_step = "draw"
	state.drawn_card = null
	if bool(caller.is_ai):
		state.ai_turns_finished = int(state.ai_turns_finished) + 1
	return "%s hat Dame gerufen. Jeder andere Spieler hat noch genau einen Zug." % str(caller.name)


# Stapel und Ablage leer: Ziehen unmoeglich, der Zug darf ausgesetzt werden.
func nothing_to_draw() -> bool:
	return state.deck.is_empty() and state.discard.is_empty()


func _end_turn() -> Dictionary:
	if str(state.turn_step) == "draw" and state.drawn_card == null and nothing_to_draw():
		_log("%s kann nicht ziehen und setzt aus." % _who())
		state.turn_step = "extra"
	if state.drawn_card != null or str(state.turn_step) == "draw" or str(state.turn_step) == "play":
		return _fail("Der Zug ist noch nicht fertig")
	if str(state.turn_step) != "extra":
		return _fail("Zug kann jetzt nicht beendet werden")
	var finished: Dictionary = current_player()
	var finished_was_ai := bool(finished.is_ai)
	if str(state.phase) == "dame_called":
		state.dame_turns_left = int(state.dame_turns_left) - 1
		if int(state.dame_turns_left) <= 0:
			if finished_was_ai:
				state.ai_turns_finished = int(state.ai_turns_finished) + 1
			_resolve_round()
			return _ok("Letzter Zug nach der Ansage. Karten aufgedeckt.")
	state.current_index = _next_active(int(state.current_index))
	state.turn_step = "draw"
	state.drawn_card = null
	if str(state.phase) != "dame_called" and int(state.current_index) == int(state.round_start_index):
		state.round = int(state.round) + 1
		if int(state.round) > SAFE_CIRCUITS:
			state.safe_phase = false
	if finished_was_ai:
		state.ai_turns_finished = int(state.ai_turns_finished) + 1
	return _ok("Zug beendet. Am Zug: %s" % str(current_player().name))


func _resolve_round() -> void:
	var caller_index := int(state.dame_caller_index)
	var caller: Dictionary = state.players[caller_index]
	for p in state.players:
		for i in range(p.hand.size()):
			p.hand[i].face_up = true
			if not p.known.has(i):
				p.known.append(i)
	var caller_points := _points(caller)
	var lowest_other := 9999
	var any_other := false
	for p in state.players:
		if int(p.seat) == caller_index or bool(p.eliminated):
			continue
		any_other = true
		var pts := _points(p)
		if pts < lowest_other:
			lowest_other = pts
	# Abschnitt 5: gleich viele ODER weniger Punkte als der Ansager => falsch.
	var caller_wins := any_other and caller_points < lowest_other
	for p in state.players:
		if bool(p.eliminated):
			continue
		p.score = _points(p)
		p.total_score = int(p.total_score) + int(p.score)
		if int(p.total_score) == 50:
			p.total_score = 0
		elif int(p.total_score) > 50:
			p.eliminated = true
		# Gewertete Strafkarten unten in die Ablage, damit keine Karte verschwindet.
		for pen in p.penalty_cards:
			pen.face_up = true
			state.discard.push_front(pen)
		p.penalty_cards = []
		p.has_called_dame = false
	state.last_round_false_call = not caller_wins
	if not caller_wins:
		_give_one_penalty(caller, "false_call")
		state.false_call_penalties_given = int(state.false_call_penalties_given) + 1
		state.last_action = "%s lag falsch. Nächste Ausgabe: 5 statt 4 Karten." % str(caller.name)
	else:
		state.last_action = "%s hat Dame richtig gerufen." % str(caller.name)
	state.phase = "round_end"
	state.turn_step = "draw"
	state.drawn_card = null
	_log(str(state.last_action))
	_check_game_over()


func _check_game_over() -> void:
	var alive: Array = []
	var humans_total := 0
	var humans_alive := 0
	for p in state.players:
		if not bool(p.is_ai):
			humans_total += 1
		if bool(p.eliminated):
			continue
		alive.append(p)
		if not bool(p.is_ai):
			humans_alive += 1
	var over := alive.size() <= 1 or (humans_total > 0 and humans_alive == 0)
	if not over:
		return
	# Scheiden alle gleichzeitig aus, gewinnt der mit den wenigsten Punkten.
	var candidates: Array = alive if not alive.is_empty() else state.players
	var best = null
	for p in candidates:
		if best == null or int(p.total_score) < int(best.total_score):
			best = p
	state.phase = "game_over"
	state.winner_index = int(best.seat) if best != null else -1
	if best != null:
		state.last_action = "Spielende. %s gewinnt mit %d Punkten." % [str(best.name), int(best.total_score)]
	else:
		state.last_action = "Spielende. Niemand ist übrig."
	_log(str(state.last_action))


func _start_next_round() -> Dictionary:
	if str(state.phase) != "round_end":
		return _fail("Keine abgeschlossene Runde")
	var rng := RandomNumberGenerator.new()
	state.deal = int(state.deal) + 1
	rng.seed = int(state.seed) * 7919 + int(state.deal)
	# Strafkarten aus falscher Ansage wandern mit: aus dem neuen Blatt entfernen.
	# Ausgeschiedene spielen nicht mehr mit, ihre Strafkarten kommen zurueck ins Blatt.
	var carried := {}
	for p in state.players:
		if bool(p.eliminated):
			continue
		for pen in p.penalty_cards:
			carried[str(pen.id)] = true
	var deck: Array = []
	for card in _fresh_pool(deck_count_for(seat_count())):
		if not carried.has(str(card.id)):
			deck.append(card)
	_shuffle(deck, rng)
	for p in state.players:
		p.seen_ids = []
		p.deal_penalties = 0
		if bool(p.eliminated):
			p.hand = []
			p.known = []
			p.penalty_cards = []
			continue
		var hand: Array = []
		for _i in range(HAND_SIZE):
			var card: Dictionary = deck.pop_back()
			card.face_up = false
			hand.append(card)
		# Falsche Ansage haengt genau eine gezogene Strafkarte an: 5 statt 4.
		for pen in p.penalty_cards:
			pen.face_up = false
			hand.append(pen)
		p.hand = hand
		p.penalty_cards = []
		p.known = [0, 1] if hand.size() >= 2 else [0]
		p.locked = false
		p.score = 0
		p.has_called_dame = false
	state.deck = deck
	state.discard = []
	state.dame_caller_index = -1
	state.dame_turns_left = 0
	state.drawn_card = null
	state.turn_step = "draw"
	state.last_queen_penalty = null
	state.last_look = null
	state.last_look_by = -1
	state.last_king_swap = null
	state.round_start_index = _next_active(int(state.round_start_index))
	state.current_index = int(state.round_start_index)
	state.round = 1
	state.safe_phase = true
	state.phase = "play"
	return _ok("Neue Ausgabe. Am Zug: %s" % str(current_player().name))



func _private_look(viewer_seat: int):
	if state.last_look == null:
		return null
	if int(state.last_look_by) != viewer_seat:
		return null
	return state.last_look


func _played_message(base: String) -> String:
	if str(state.turn_step) == "jack":
		return base + ". Bube: eine verdeckte Karte ansehen, ohne Tausch."
	if str(state.turn_step) == "king":
		return base + ". König: eigene Karte ansehen, dann blind tauschen. Gegnerkarte bleibt ungesehen."
	return base


func _place_on_discard(card: Dictionary, player: Dictionary) -> void:
	# Ausspielen: die Karte liegt offen auf der Ablage. Nur README-Wirkungen.
	card.face_up = true
	state.discard.append(card)
	var rank := str(card.rank)
	if rank == "Q":
		_give_queen_penalty(player)
		state.turn_step = "extra"
	elif rank == "J":
		state.turn_step = "jack" if _has_jack_target() else "extra"
	elif rank == "K":
		state.turn_step = "king" if _has_king_target() else "extra"
	else:
		state.turn_step = "extra"


func _face_down_count(player: Dictionary) -> int:
	var n := 0
	for c in player.hand:
		if not bool(c.face_up):
			n += 1
	return n


func _has_jack_target() -> bool:
	for p in state.players:
		if not bool(p.eliminated) and _face_down_count(p) > 0:
			return true
	return false


func _has_king_target() -> bool:
	var me: Dictionary = current_player()
	if _face_down_count(me) == 0:
		return false
	for p in state.players:
		if int(p.seat) == int(me.seat) or bool(p.eliminated) or bool(p.locked):
			continue
		if _face_down_count(p) > 0:
			return true
	return false


func _look_card(target_seat: int, hand_index: int) -> Dictionary:
	# README: Bube schaut eine beliebige verdeckte Karte an. Kein Tausch.
	if str(state.turn_step) != "jack":
		return _fail("Bube: Anschauen ist jetzt nicht dran")
	if target_seat < 0 or target_seat >= seat_count():
		return _fail("Ungültiger Platz")
	var target: Dictionary = state.players[target_seat]
	if bool(target.eliminated):
		return _fail("Spieler ist ausgeschieden")
	var hand: Array = target.hand
	if hand_index < 0 or hand_index >= hand.size():
		return _fail("Ungültiger Kartenindex")
	var card: Dictionary = hand[hand_index]
	if bool(card.face_up):
		return _fail("Nur eine verdeckte Karte")
	var before_id := str(card.id)
	# Kurz ansehen, ohne die Karte aufzudecken oder zu verschieben.
	state.last_look = {
		"id": before_id,
		"rank": str(card.rank),
		"suit": str(card.suit),
		"seat": target_seat,
		"index": hand_index,
		"face_up": false,
	}
	state.last_look_by = int(state.current_index)
	state.last_king_swap = null
	var me: Dictionary = current_player()
	if target_seat == int(state.current_index):
		if not me.known.has(hand_index):
			me.known.append(hand_index)
	elif not me.seen_ids.has(before_id):
		me.seen_ids.append(before_id)
	if str(hand[hand_index].id) != before_id:
		return _fail("Bube hat die Position veraendert")
	if bool(hand[hand_index].face_up):
		return _fail("Bube hat die Karte aufgedeckt")
	state.turn_step = "extra"
	return _ok("Bube: verdeckte Karte angesehen. Kein Tausch.")


func _king_swap(opponent_seat: int, opponent_index: int, chosen_index: int) -> Dictionary:
	# Buxe, nicht README: eigene verdeckte Karte ansehen, dann blind tauschen.
	# Die gegnerische Karte wird weder vorher noch nachher gezeigt.
	if str(state.turn_step) != "king":
		return _fail("König: Tausch ist jetzt nicht dran")
	var me_seat := int(state.current_index)
	if opponent_seat < 0 or opponent_seat >= seat_count() or opponent_seat == me_seat:
		return _fail("König tauscht blind mit einer gegnerischen Karte")
	if bool(state.players[opponent_seat].locked):
		return _fail("Karten des Ansagers sind gelockt")
	if bool(state.players[opponent_seat].eliminated):
		return _fail("Spieler ist ausgeschieden")
	var me: Dictionary = state.players[me_seat]
	var opp: Dictionary = state.players[opponent_seat]
	var my_hand: Array = me.hand
	var opp_hand: Array = opp.hand
	if chosen_index < 0 or chosen_index >= my_hand.size():
		return _fail("Keine eigene Karte gewählt")
	if opponent_index < 0 or opponent_index >= opp_hand.size():
		return _fail("Keine gegnerische Karte")
	var chosen_card: Dictionary = my_hand[chosen_index]
	var opp_card: Dictionary = opp_hand[opponent_index]
	if bool(chosen_card.face_up) or bool(opp_card.face_up):
		return _fail("König tauscht nur verdeckte Karten")
	var seen_id := str(chosen_card.id)
	var seen_rank := str(chosen_card.rank)
	var seen_suit := str(chosen_card.suit)
	state.last_look = {
		"id": seen_id,
		"rank": seen_rank,
		"suit": seen_suit,
		"seat": me_seat,
		"index": chosen_index,
		"face_up": false,
		"own": true,
	}
	state.last_look_by = me_seat
	# Der Tauschende weiss, wohin seine angesehene Karte wandert.
	if not me.seen_ids.has(seen_id):
		me.seen_ids.append(seen_id)
	my_hand[chosen_index] = opp_card
	opp_hand[opponent_index] = chosen_card
	opp_card.face_up = false
	chosen_card.face_up = false
	# Beide neuen Besitzer sehen die eingetauschte Karte nicht.
	opp_card.unseen = true
	chosen_card.unseen = true
	_forget_known_index(me, chosen_index)
	_forget_known_index(opp, opponent_index)
	state.last_king_swap = {
		"look_own_id": seen_id,
		"look_rank": seen_rank,
		"look_suit": seen_suit,
		"from_seat": me_seat,
		"from_index": chosen_index,
		"to_seat": opponent_seat,
		"to_index": opponent_index,
		"blind_unseen": true,
		"self_face_up": bool(my_hand[chosen_index].face_up),
		"opp_face_up": bool(opp_hand[opponent_index].face_up),
	}
	if bool(my_hand[chosen_index].face_up) or bool(opp_hand[opponent_index].face_up):
		return _fail("König hat eine Karte offen gelassen")
	if str(opp_hand[opponent_index].id) != seen_id:
		return _fail("König hat die angesehene eigene Karte nicht getauscht")
	state.turn_step = "extra"
	return _ok("König: eigene Karte angesehen und blind getauscht. Beide bleiben verdeckt.")


func _forget_known_index(player: Dictionary, index: int) -> void:
	var next: Array = []
	for k in player.known:
		if int(k) != index:
			next.append(int(k))
	player.known = next


# Zugtimer abgelaufen (CONCEPT_DECISIONS §9): genau eine Strafkarte. Den Zug beendet der Tisch danach.
func _timeout_penalty() -> Dictionary:
	var player: Dictionary = current_player()
	var card := _give_one_penalty(player, "timeout")
	_log("%s: Zeit abgelaufen. Genau eine Strafkarte." % str(player.name))
	state.last_action = "Zeit abgelaufen – Strafkarte für %s." % str(player.name)
	return {"ok": true, "reason": "", "penalty": not card.is_empty()}


func _give_queen_penalty(player: Dictionary) -> void:
	# Abschnitt 2 und 3: genau eine Strafkarte, Dame bleibt offen auf der Ablage.
	var top = top_discard()
	if top != null:
		top.face_up = true
	var card := _give_one_penalty(player, "queen")
	state.last_queen_penalty = null if card.is_empty() else card
	state.queen_penalties_given = int(state.queen_penalties_given) + 1
	_log("Dame offen. Genau eine Strafkarte.")


func _give_one_penalty(player: Dictionary, source: String) -> Dictionary:
	var card = _pull_deck()
	if card == null:
		# Keine Karte mehr da: keine Strafe, nie eine erfundene Karte.
		_log("Keine Strafkarte mehr verfügbar (%s)." % source)
		return {}
	card.face_up = false
	player.deal_penalties = int(player.get("deal_penalties", 0)) + 1
	# Genau eine Karte, nie eine Schleife ueber mehrere.
	if PENALTY_CARD_COUNT != 1:
		push_error("PENALTY_CARD_COUNT muss 1 sein")
	player.penalty_cards.append(card)
	return card


func _pull_deck():
	if state.deck.is_empty():
		if state.discard.size() <= 1:
			return null
		var top = state.discard.pop_back()
		var rest: Array = state.discard.duplicate()
		state.discard = [top]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(state.seed) * 104729 + rest.size() + int(state.deal) * 131 + int(state.round) * 13
		_shuffle(rest, rng)
		state.deck = rest
	if state.deck.is_empty():
		return null
	return state.deck.pop_back()


func _points(player: Dictionary) -> int:
	var total := 0
	for card in player.hand:
		total += int(card.value)
	for card in player.penalty_cards:
		total += int(card.value)
	return total


func _other_active_count(caller_index: int) -> int:
	var n := 0
	for p in state.players:
		if int(p.seat) != caller_index and not bool(p.eliminated):
			n += 1
	return n


func _next_active(index: int) -> int:
	var n := index
	for _i in range(seat_count()):
		n = (n + 1) % seat_count()
		if not bool(state.players[n].eliminated):
			return n
	return index


func _shift_known(player: Dictionary, removed: int) -> void:
	var next: Array = []
	for k in player.known:
		var idx := int(k)
		if idx == removed:
			continue
		elif idx > removed:
			next.append(idx - 1)
		else:
			next.append(idx)
	player.known = next


static func deck_count_for(seats: int) -> int:
	return int(ceil(float(seats) / 4.0))


func _fresh_pool(decks: int = 1) -> Array:
	var pool: Array = []
	var n := 0
	for _d in range(maxi(decks, 1)):
		for suit in SUITS:
			for rank in RANKS:
				pool.append({
					"id": "%s-%s-%d" % [suit, rank, n],
					"suit": suit,
					"rank": rank,
					"value": int(VALUES[rank]),
					"face_up": false,
				})
				n += 1
	return pool


func _take_spec(pool: Array, suit: String, rank: String) -> Dictionary:
	for i in range(pool.size()):
		var card: Dictionary = pool[i]
		if str(card.suit) == suit and str(card.rank) == rank:
			pool.remove_at(i)
			return card
	push_error("Karte fehlt im Blatt: %s %s" % [rank, suit])
	return {"id": "missing", "suit": suit, "rank": rank, "value": int(VALUES.get(rank, 0)), "face_up": false}


func _shuffle(deck: Array, rng: RandomNumberGenerator) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp


const SUIT_NAMES := {"hearts": "Herz", "diamonds": "Karo", "clubs": "Kreuz", "spades": "Pik"}
const RANK_NAMES := {"J": "Bube", "Q": "Dame", "K": "König", "A": "Ass"}

static func card_label(card: Dictionary) -> String:
	var rank := str(card.rank)
	return "%s %s" % [SUIT_NAMES.get(str(card.suit), "?"), RANK_NAMES.get(rank, rank)]


func _who() -> String:
	return str(current_player().name)


func _ok(reason: String) -> Dictionary:
	state.last_action = reason
	_log(reason)
	return {"ok": true, "reason": reason}


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _log(line: String) -> void:
	var log: Array = state.log
	log.append(line)
	if log.size() > 14:
		log.pop_front()
