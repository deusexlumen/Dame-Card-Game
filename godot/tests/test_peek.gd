extends RefCounted

# Merkphase: vor dem ersten Zug sieht jeder seine zwei Startkarten und bestaetigt "gemerkt".
# Erst wenn alle bestaetigt haben, beginnt das Spiel. Hardcore: kein Blick, sofort Spiel.

const TableScene = preload("res://scenes/table.tscn")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const DameProtocol = preload("res://scripts/net/net_protocol.gd")
const DameHostScript = preload("res://scripts/net/dame_host.gd")

var t


func run(ctx) -> void:
	t = ctx
	_check_rules_single_human()
	_check_rules_two_humans()
	_check_rules_hardcore()
	_check_rules_timeout()
	_check_next_deal_peeks_again()
	_check_old_save_loads()
	_check_protocol_and_host()
	_check_table_flow()
	_check_table_hardcore()
	_check_table_beginner_aid()
	_check_table_enter_key()
	_check_table_hotseat()


func _rules(extra: Dictionary):
	var cfg := {"seed": 7, "seat_count": 4, "ai_seats": [1, 2, 3], "peek_phase": true}
	cfg.merge(extra, true)
	var r = DameRulesScript.new()
	r.start_match(cfg)
	return r


func _known_cards(rules, seat: int) -> int:
	var view: Dictionary = DameViewScript.for_viewer(rules, seat)
	var n := 0
	for c in view.players[seat].cards:
		if bool(c.known):
			n += 1
	return n


func _check_rules_single_human() -> void:
	var r = _rules({})
	t.expect(str(r.state.phase) == "peek", "Merkphase beginnt nicht")
	t.expect(int(r.state.current_index) == 0, "Mensch nicht am Platz fuer die Merkphase")
	t.expect(not bool(r.state.players[0].peek_ready), "Mensch ist von Anfang an bereit")
	for seat in [1, 2, 3]:
		t.expect(bool(r.state.players[seat].peek_ready), "KI ist nicht sofort bereit")
	t.expect(_known_cards(r, 0) == 2, "Mensch sieht in der Merkphase nicht genau zwei Karten")
	t.expect(_known_cards(r, 1) == 2, "Die Sicht der KI zeigt ihr nicht ihre zwei Karten")
	# Waehrend der Merkphase ist jede Spielaktion gesperrt und aendert nichts.
	var before := var_to_str(r.state)
	var res: Dictionary = r.apply_action({"type": "draw_deck", "seat": 0})
	t.expect(not bool(res.ok), "Ziehen in der Merkphase erlaubt")
	t.expect(var_to_str(r.state) == before, "abgelehnte Aktion in der Merkphase aendert den Zustand")
	res = r.apply_action({"type": "peek_ready", "seat": 0})
	t.expect(bool(res.ok), "gemerkt wird abgelehnt: %s" % str(res.get("reason", "")))
	t.expect(str(r.state.phase) == "play", "nach dem Merken beginnt das Spiel nicht")
	t.expect(int(r.state.current_index) == int(r.state.round_start_index), "falscher Spieler beginnt")
	res = r.apply_action({"type": "peek_ready", "seat": 0})
	t.expect(not bool(res.ok), "zweites gemerkt ausserhalb der Merkphase erlaubt")
	res = r.apply_action({"type": "draw_deck", "seat": 0})
	t.expect(bool(res.ok), "Ziehen nach der Merkphase nicht erlaubt")


func _check_rules_two_humans() -> void:
	var r = _rules({"ai_seats": [2, 3]})
	t.expect(int(r.state.current_index) == 0, "Hot-Seat: Merkphase beginnt nicht bei Platz 0")
	# Reihenfolge ist egal: Platz 1 darf zuerst bestaetigen.
	var res: Dictionary = r.apply_action({"type": "peek_ready", "seat": 1})
	t.expect(bool(res.ok) and str(r.state.phase) == "peek", "Platz 1 kann nicht zuerst bestaetigen")
	t.expect(int(r.state.current_index) == 0, "Hot-Seat: nach Platz 1 ist nicht Platz 0 dran")
	r.apply_action({"type": "peek_ready", "seat": 0})
	t.expect(str(r.state.phase) == "play", "Spiel beginnt nicht, obwohl alle Menschen bestaetigt haben")
	# Hot-Seat-Reihenfolge: nach Platz 0 ist Platz 1 an der Reihe.
	var h = _rules({"ai_seats": [2, 3]})
	h.apply_action({"type": "peek_ready", "seat": 0})
	t.expect(str(h.state.phase) == "peek" and int(h.state.current_index) == 1, "Hot-Seat: nach Platz 0 nicht Platz 1 dran")


func _check_rules_hardcore() -> void:
	var r = _rules({"blind": true})
	t.expect(str(r.state.phase) == "play", "Hardcore beginnt mit Merkphase")
	for seat in range(4):
		t.expect(_known_cards(r, seat) == 0, "Hardcore: Platz %d kennt Karten" % seat)
		t.expect(r.state.players[seat].known.is_empty(), "Hardcore: bekannte Karten gespeichert")


func _check_rules_timeout() -> void:
	var r = _rules({"ai_seats": [2, 3]})
	var res: Dictionary = r.apply_action({"type": "peek_timeout"})
	t.expect(bool(res.ok) and str(r.state.phase) == "play", "Zeitablauf beendet die Merkphase nicht")
	res = r.apply_action({"type": "peek_timeout"})
	t.expect(not bool(res.ok), "Zeitablauf ausserhalb der Merkphase erlaubt")


func _check_next_deal_peeks_again() -> void:
	for blind in [false, true]:
		var r = _rules({"blind": blind})
		if not blind:
			r.apply_action({"type": "peek_ready", "seat": 0})
		r.state.phase = "round_end"
		var res: Dictionary = r.apply_action({"type": "start_next_round"})
		t.expect(bool(res.ok), "naechste Ausgabe startet nicht")
		if blind:
			t.expect(str(r.state.phase) == "play" and _known_cards(r, 0) == 0, "Hardcore: neue Ausgabe nicht blind")
		else:
			t.expect(str(r.state.phase) == "peek", "neue Ausgabe ohne Merkphase")
			t.expect(not bool(r.state.players[0].peek_ready) and bool(r.state.players[1].peek_ready), "neue Ausgabe: falsche Bereitschaft")
			t.expect(_known_cards(r, 0) == 2, "neue Ausgabe: Mensch sieht nicht zwei Karten")


func _check_old_save_loads() -> void:
	# Spielstaende vor der Merkphase kennen weder peek_phase noch peek_ready.
	var r = _rules({"peek_phase": false})
	var data: Dictionary = r.to_dict()
	data.state.erase("peek_phase")
	data.state.erase("blind")
	for p in data.state.players:
		p.erase("peek_ready")
	var loaded = DameRulesScript.new()
	t.expect(loaded.from_dict(data), "alter Spielstand laedt nicht")
	t.expect(str(loaded.state.phase) == "play", "alter Spielstand nicht im Spiel")
	t.expect(bool(DameViewScript.for_viewer(loaded, 0).players[0].peek_ready), "alter Spielstand: Sicht ohne Bereitschaft")
	# Ein Spielstand mitten in der Merkphase laedt und laeuft weiter.
	var mid = _rules({})
	var again = DameRulesScript.new()
	t.expect(again.from_dict(mid.to_dict()) and str(again.state.phase) == "peek", "Spielstand in der Merkphase laedt nicht")


func _check_protocol_and_host() -> void:
	t.expect(not DameProtocol.sanitize_action({"type": "peek_ready"}).is_empty(), "Gast darf nicht 'gemerkt' senden")
	t.expect(DameProtocol.sanitize_action({"type": "peek_timeout"}).is_empty(), "Gast darf die Merkphase beenden")
	var r = _rules({"seat_count": 3, "ai_seats": [2]})
	var host = DameHostScript.new(r, null)
	host.assign_seat(DameProtocol.HOST_PEER, 0)
	var out: Array = host.submit(DameProtocol.HOST_PEER, {"type": "peek_ready"})
	t.expect(bool(out[0].msg.ok), "Host-Platz kann nicht bestaetigen")
	t.expect(str(r.state.phase) == "peek", "Spiel beginnt, obwohl ein Mensch fehlt")
	var res: Dictionary = host.peek_timeout()
	t.expect(bool(res.ok) and str(r.state.phase) == "play", "Host beendet die Merkphase nicht per Zeitablauf")


# ---- Tisch

func _table(cfg: Dictionary, settings: Dictionary = {}):
	var table = TableScene.instantiate()
	table.instant_ai = true
	var s := {"memory_aid": false, "turn_timer": false, "animations": false}
	s.merge(settings, true)
	table.settings_override = s
	var c := {"seed": 101, "seat_count": 4, "ai_seats": [1, 2, 3], "names": ["Spieler", "A", "B", "C"]}
	c.merge(cfg, true)
	table.pending_config = c
	t.root.add_child(table)
	table.run_ai_until_human()
	return table


func _faces(table, seat: int) -> Array:
	var out: Array = []
	for cv in table._seats[seat].cards():
		if cv.shows_face():
			out.append(int(cv.index))
	return out


func _free(table) -> void:
	t.root.remove_child(table)
	table.free()


func _check_table_flow() -> void:
	# Ohne Angabe beginnt eine echte Partie mit der Merkphase.
	var table = _table({})
	t.expect(str(table._view.phase) == "peek", "Tisch startet nicht in der Merkphase")
	t.expect(_faces(table, 0) == [0, 1], "Merkphase: eigene Startkarten nicht offen: %s" % str(_faces(table, 0)))
	for seat in [1, 2, 3]:
		t.expect(_faces(table, seat).is_empty(), "Merkphase: fremde Karte sichtbar (Platz %d)" % seat)
	t.expect(table._peek_panel.visible, "Merkphase: Bestaetigungsknopf fehlt")
	t.expect("Merke dir" in table._prompt.text, "Merkphase: Hinweis fehlt: " + table._prompt.text)
	t.expect(not table._human_turn(), "Merkphase: Mensch darf schon ziehen")
	var deck_before := int(table._view.deck_count)
	table._on_deck()
	t.expect(int(table._view.deck_count) == deck_before, "Merkphase: Stapel ziehbar")
	table.peek_done()
	table.run_ai_until_human()
	t.expect(str(table._view.phase) == "play", "Spiel beginnt nach dem Merken nicht")
	t.expect(_faces(table, 0).is_empty(), "Nach dem Merken liegen die Karten noch offen: %s" % str(_faces(table, 0)))
	t.expect(not table._peek_panel.visible, "Bestaetigungsknopf bleibt nach dem Merken")
	t.expect(table._human_turn(), "Nach dem Merken ist der Mensch nicht am Zug")
	_free(table)


func _check_table_hardcore() -> void:
	var table = _table({"blind": true})
	t.expect(str(table._view.phase) == "play", "Hardcore: Tisch startet mit Merkphase")
	t.expect(_faces(table, 0).is_empty(), "Hardcore: Karten offen")
	t.expect(not table._peek_panel.visible, "Hardcore: Bestaetigungsknopf sichtbar")
	t.expect(table._human_turn(), "Hardcore: Mensch nicht am Zug")
	_free(table)


func _check_table_beginner_aid() -> void:
	# Anfaengerhilfe: bekannte Karten bleiben auch nach dem Merken offen.
	var table = _table({}, {"memory_aid": true})
	table.peek_done()
	table.run_ai_until_human()
	t.expect(_faces(table, 0) == [0, 1], "Anfaengerhilfe: Karten nach dem Merken nicht offen")
	_free(table)


func _check_table_enter_key() -> void:
	var table = _table({})
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	table._unhandled_input(ev)
	table.run_ai_until_human()
	t.expect(str(table._view.phase) == "play", "Enter bestaetigt die Merkphase nicht")
	_free(table)


func _check_table_hotseat() -> void:
	# Zwei Menschen an einem Geraet: jeder merkt sich seine Karten hinter dem Uebergabe-Schirm.
	var table = _table({"seed": 104, "seat_count": 3, "ai_seats": [2], "names": ["Anna", "Ben", "KI"]})
	t.expect(table.is_hotseat() and str(table._view.phase) == "peek", "Hot-Seat startet nicht in der Merkphase")
	t.expect(table.handoff_pending, "Hot-Seat: Start ohne Uebergabe-Schirm")
	for seat in [0, 1, 2]:
		t.expect(_faces(table, seat).is_empty(), "Hot-Seat: vor der Uebergabe sichtbare Karte Platz %d" % seat)
	table.confirm_handoff()
	t.expect(table.viewer_seat == 0 and _faces(table, 0) == [0, 1], "Anna sieht ihre Karten in der Merkphase nicht")
	t.expect(_faces(table, 1).is_empty(), "Anna sieht Bens Karten")
	table.peek_done()
	t.expect(str(table._view.phase) == "peek", "Spiel beginnt, obwohl Ben sich noch nicht gemerkt hat")
	t.expect(table.handoff_pending, "Hot-Seat: nach Anna kommt kein Uebergabe-Schirm fuer Ben")
	for seat in [0, 1, 2]:
		t.expect(_faces(table, seat).is_empty(), "Hot-Seat: Karten offen waehrend der Uebergabe an Ben (Platz %d)" % seat)
	table.confirm_handoff()
	t.expect(table.viewer_seat == 1 and _faces(table, 1) == [0, 1], "Ben sieht seine Karten in der Merkphase nicht")
	t.expect(_faces(table, 0).is_empty(), "Ben sieht Annas Karten")
	table.peek_done()
	table.run_ai_until_human()
	t.expect(str(table._view.phase) == "play", "Spiel beginnt nicht, nachdem beide sich gemerkt haben")
	t.expect(table.handoff_pending, "Hot-Seat: kein Uebergabe-Schirm fuer den ersten Zug")
	_free(table)
