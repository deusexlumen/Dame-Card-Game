extends RefCounted

# Bitgleichheit: dieselben Eingaben ergeben vor und nach dem Umbau denselben Zustand.

const TableScene = preload("res://scenes/table.tscn")
const FIXTURE := "res://tests/fixtures/golden_offline.txt"
# Nur zum Neuaufnehmen auf true setzen, nie committen.
const RECORD := false

var t


func run(ctx) -> void:
	t = ctx
	var a := _play({"seed": 2024, "seat_count": 4, "ai_seats": [1, 2, 3]}, "A")
	var b := _play({"seed": 2025, "seat_count": 3, "ai_seats": [2]}, "B")
	var got := a + "\n---\n" + b
	if RECORD:
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(got)
		f.close()
		return
	var want := FileAccess.get_file_as_string(FIXTURE)
	t.expect(want != "", "Golden-Fixture fehlt")
	t.expect(got.replace("\r\n", "\n") == want.replace("\r\n", "\n"), "Offline-Spiel weicht vom Golden-Stand ab")


func _play(cfg: Dictionary, label: String) -> String:
	var table = TableScene.instantiate()
	table.instant_ai = true
	table.settings_override = {"memory_aid": true, "animations": false, "turn_timer": false}
	table.pending_config = cfg
	t.root.add_child(table)
	var guard := 0
	var counters := {"handoffs": 0, "deals": 0, "jacks": 0}
	while guard < 3000:
		guard += 1
		var phase := str(table.rules.state.phase)
		if phase == "game_over" or int(table.rules.state.deal) > 3:
			break
		if phase == "round_end":
			counters.deals += 1
			table.next_deal()
			continue
		if table.handoff_pending:
			counters.handoffs += 1
			table.confirm_handoff()
			continue
		table.run_ai_until_human()
		if not table._human_turn():
			continue
		_human_step(table, counters)
	print("GOLDEN %s h=%d d=%d j=%d" % [label, counters.handoffs, counters.deals, counters.jacks])
	t.expect(guard < 3000, "Golden-Spiel %s kam nicht zum Ende (Endlosschleife)" % label)
	if label == "B":
		t.expect(counters.handoffs > 0, "Golden-Spiel %s: keine Handoffs ausgefuehrt" % label)
	var out := var_to_str(table.rules.state)
	t.root.remove_child(table)
	table.free()
	return out


func _human_step(table, counters: Dictionary) -> void:
	var seat: int = table.viewer_seat
	var opp := (seat + 1) % int(table.rules.seat_count())
	match str(table.rules.state.turn_step):
		"draw":
			# Offene Dame auf der Ablage erzwingt das Nehmen von dort.
			if table.rules.must_take_queen():
				table._on_discard()
			else:
				table._on_deck()
		"play":
			table._on_card(seat, int(table.rules.state.deal) % 4)
		"jack":
			counters.jacks += 1
			table._on_card(seat, 0)
		"king":
			table._on_card(seat, 0)
			table._on_card(opp, 0)
		_:
			table.end_turn()
