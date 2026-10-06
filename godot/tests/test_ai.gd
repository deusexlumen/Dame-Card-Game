extends RefCounted

# M2: Sicht verraet nichts, KI liest nur die Sicht, drei Stufen spielen ganze Partien.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")

var t

func run(ctx) -> void:
	t = ctx
	_check_view_hides_foreign()
	_check_drawn_card_privacy()
	_check_jack_memory_in_view()
	_check_view_geometry()
	_check_policy_reads_view_only()
	_check_ai_games()
	_check_hard_beats_easy()


func _new_rules(config: Dictionary):
	var rules = DameRulesScript.new()
	rules.start_match(config)
	return rules


func _check_view_hides_foreign() -> void:
	var rules = _new_rules({"seed": 31, "seat_count": 4, "ai_seats": [2]})
	var view: Dictionary = DameViewScript.for_viewer(rules, 0)
	var own: Array = view.players[0].cards
	t.expect(bool(own[0].known) and bool(own[1].known), "eigene Karten 0/1 nicht bekannt")
	t.expect(not bool(own[2].known) and not bool(own[3].known), "eigene Karten 2/3 sichtbar")
	t.expect(str(own[2].rank) == "" and int(own[2].value) == -1, "unbekannte eigene Karte verraet Rang/Wert")
	var text := var_to_str(view)
	for seat in [1, 2, 3]:
		for card in view.players[seat].cards:
			t.expect(not bool(card.known), "fremde Karte sichtbar Sitz %d" % seat)
		for card in rules.state.players[seat].hand:
			t.expect(str(card.id) not in text, "Sicht enthaelt fremde Karten-ID")
	for card in rules.state.deck:
		t.expect(str(card.id) not in text, "Sicht enthaelt Stapel-ID")
	t.expect(int(view.deck_count) == rules.state.deck.size(), "Stapelzaehler falsch")
	t.expect(str(view.players[1].role) == "left" and str(view.players[2].role) == "opposite", "Rollen falsch")


func _check_drawn_card_privacy() -> void:
	var rules = _new_rules({"seed": 32, "seat_count": 3})
	rules.apply_action({"type": "draw_deck", "seat": 0})
	var mine: Dictionary = DameViewScript.for_viewer(rules, 0)
	var other: Dictionary = DameViewScript.for_viewer(rules, 1)
	t.expect(mine.drawn != null and bool(mine.drawn.known), "Ziehender sieht eigene Karte nicht")
	t.expect(other.drawn != null and not bool(other.drawn.known), "Mitspieler sieht verdeckt gezogene Karte")
	var label: String = rules.card_label(rules.state.drawn_card)
	t.expect(label not in var_to_str(other.log) and label not in str(other.last_action), "Protokoll verraet die gezogene Karte: " + label)
	rules.apply_action({"type": "discard_drawn", "seat": 0})
	while str(rules.state.turn_step) != "extra":
		var step := str(rules.state.turn_step)
		if step == "jack":
			rules.apply_action({"type": "look_card", "seat": 0, "target_seat": 0, "hand_index": 2})
		elif step == "king":
			rules.apply_action({"type": "king_swap", "seat": 0, "opponent_seat": 1, "opponent_index": 0, "chosen_index": 0})
	rules.apply_action({"type": "end_turn", "seat": 0})
	rules.apply_action({"type": "draw_discard", "seat": 1})
	var watch: Dictionary = DameViewScript.for_viewer(rules, 0)
	t.expect(watch.drawn != null and bool(watch.drawn.known), "von der Ablage gezogene Karte nicht oeffentlich")


func _check_jack_memory_in_view() -> void:
	var rules = _new_rules({
		"seed": 33,
		"seat_count": 3,
		"draw_first": [{"suit": "diamonds", "rank": "J"}],
	})
	rules.apply_action({"type": "draw_deck", "seat": 0})
	rules.apply_action({"type": "discard_drawn", "seat": 0})
	t.expect(str(rules.state.turn_step) == "jack", "Bube-Schritt fehlt")
	var target_id := str(rules.state.players[1].hand[2].id)
	rules.apply_action({"type": "look_card", "seat": 0, "target_seat": 1, "hand_index": 2})
	var v0: Dictionary = DameViewScript.for_viewer(rules, 0)
	var v2: Dictionary = DameViewScript.for_viewer(rules, 2)
	t.expect(bool(v0.players[1].cards[2].known), "angesehene fremde Karte nicht im Gedaechtnis")
	t.expect(not bool(v2.players[1].cards[2].known), "Unbeteiligter kennt die angesehene Karte")
	t.expect(not bool(v0.players[1].cards[1].known), "Nachbarkarte wurde mit aufgedeckt")
	t.expect(target_id not in var_to_str(v2), "ID der angesehenen Karte beim Unbeteiligten")


func _check_policy_reads_view_only() -> void:
	var found := false
	for m in DamePolicyScript.new().get_script().get_script_method_list():
		if str(m.name) == "choose":
			found = true
			t.expect(int(m.args[0].type) == TYPE_DICTIONARY, "Policy nimmt keine Sicht (Dictionary)")
	t.expect(found, "DamePolicy.choose fehlt")
	for diff in ["easy", "medium", "hard"]:
		var rules = _new_rules({"seed": 34, "seat_count": 4, "ai_seats": [0, 1, 2, 3], "difficulties": {0: diff}})
		for _i in range(4):
			DameAIScript.new(1).complete_turn(rules)
		while int(rules.state.current_index) != 0:
			DameAIScript.new(1).complete_turn(rules)
		var rng_a := RandomNumberGenerator.new()
		rng_a.seed = 77
		var a: Dictionary = DamePolicyScript.choose(DameViewScript.for_viewer(rules, 0), rng_a)
		# Fremde unbekannte Karten veraendern: Entscheidung muss gleich bleiben.
		var seen: Array = rules.state.players[0].seen_ids
		for seat in [1, 2, 3]:
			for card in rules.state.players[seat].hand:
				if not seen.has(str(card.id)):
					card.rank = "K"
					card.value = 10
		var rng_b := RandomNumberGenerator.new()
		rng_b.seed = 77
		var b: Dictionary = DamePolicyScript.choose(DameViewScript.for_viewer(rules, 0), rng_b)
		t.expect(var_to_str(a) == var_to_str(b), "%s: KI-Entscheidung haengt von fremden Karten ab" % diff)


func _check_ai_games() -> void:
	var setups := [
		{0: "easy", 1: "medium", 2: "hard", 3: "medium"},
		{0: "hard", 1: "hard", 2: "hard", 3: "hard"},
		{0: "medium", 1: "medium", 2: "easy", 3: "easy"},
	]
	for si in range(setups.size()):
		for seed in [1, 2, 3]:
			var rules = _new_rules({"seed": seed * 10 + si, "seat_count": 4, "ai_seats": [0, 1, 2, 3], "difficulties": setups[si]})
			var ai = DameAIScript.new(seed)
			var guard := 0
			var policy_errors := 0
			var zones_ok := true
			while str(rules.state.phase) != "game_over" and guard < 20000:
				guard += 1
				if str(rules.state.phase) == "round_end":
					rules.apply_action({"type": "start_next_round"})
					continue
				ai.last_error = ""
				var r: Dictionary = ai.step(rules)
				if ai.last_error != "":
					policy_errors += 1
					if policy_errors == 1:
						t.expect(false, "Setup %d Seed %d: ungueltige KI-Aktion: %s" % [si, seed, ai.last_error])
				if not bool(r.ok):
					t.expect(false, "Setup %d Seed %d: KI haengt: %s" % [si, seed, str(r.reason)])
					break
				if not rules.assert_zones():
					zones_ok = false
					break
			t.expect(zones_ok, "Setup %d Seed %d: Zonen kaputt: %s" % [si, seed, rules.zone_error])
			t.expect(str(rules.state.phase) == "game_over", "Setup %d Seed %d: Partie endet nicht" % [si, seed])
			t.expect(policy_errors == 0, "Setup %d Seed %d: %d ungueltige KI-Aktionen" % [si, seed, policy_errors])


func _check_hard_beats_easy() -> void:
	var hard_wins := 0
	var games := 30
	for seed in range(games):
		# Plaetze tauschen, damit der Startvorteil sich ausgleicht.
		var hard_seat := seed % 2
		var diffs := {hard_seat: "hard", 1 - hard_seat: "easy"}
		var rules = _new_rules({"seed": 500 + seed, "seat_count": 2, "ai_seats": [0, 1], "difficulties": diffs})
		var ai = DameAIScript.new(seed)
		var guard := 0
		while str(rules.state.phase) != "game_over" and guard < 20000:
			guard += 1
			if str(rules.state.phase) == "round_end":
				rules.apply_action({"type": "start_next_round"})
				continue
			if not bool(ai.step(rules).ok):
				break
		if int(rules.state.winner_index) == hard_seat:
			hard_wins += 1
	print("FACT hard_vs_easy wins=%d/%d" % [hard_wins, games])
	t.expect(hard_wins >= 20, "Schwer gewinnt zu selten gegen Einfach: %d/%d" % [hard_wins, games])


func _check_view_geometry() -> void:
	var rules = _new_rules({"seed": 5, "seat_count": 6, "ai_seats": []})
	var view: Dictionary = DameViewScript.for_viewer(rules, 2)
	for p in view.players:
		t.expect(str(p.role) == DameRulesScript.seat_role_for(2, int(p.seat), 6), "Rolle ungleich statischer Funktion")
		t.expect(is_equal_approx(float(p.angle), rules.seat_angle(2, int(p.seat))), "Winkel fehlt in der Sicht")
		t.expect(p.has("deal_penalties"), "deal_penalties fehlt in der Sicht")
