extends SceneTree

# Echter Szenenfluss mit Szenenwechseln (kein test_mode):
# Menue -> Setup -> Tisch -> Zug -> Hauptmenue -> Fortsetzen -> gleicher Stand.
# Aufruf: godot --headless --path godot --script res://tools/flow_smoke.gd

var _step := 0
var _wait := 0
var _snapshot := ""
var _fail := ""

func _initialize() -> void:
	var app := root.get_node("App")
	app.use_test_storage()
	app.test_mode = false
	change_scene_to_file("res://scenes/main_menu.tscn")


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	var app := root.get_node("App")
	var scene := current_scene
	match _step:
		0:
			if scene == null or scene.name != "MainMenu":
				return _abort("Menue nicht geladen")
			if scene.resume_button.visible:
				return _abort("Fortsetzen ohne Spielstand sichtbar")
			scene.buttons[1].pressed.emit()
		1:
			if scene == null or scene.name != "Setup":
				return _abort("Setup nicht geladen")
			scene.start_button.pressed.emit()
		2:
			if scene == null or scene.name != "Table" or scene.rules == null:
				return _abort("Tisch nicht geladen")
			if scene.rules.seat_count() != 4 or scene.local_seats != [0]:
				return _abort("Setup-Konfiguration kam nicht am Tisch an")
			scene.instant_ai = true
			scene.run_ai_until_human()
			scene._on_deck()
			scene._on_drawn()
			var step := str(scene.rules.state.turn_step)
			if step == "jack":
				scene._on_card(1, 0)
			elif step == "king":
				scene._on_card(0, 0)
				scene._on_card(1, 0)
			scene.end_turn()
			scene.run_ai_until_human()
			_snapshot = var_to_str(scene.rules.state)
			scene.toggle_pause()
			scene._on_main_menu()
		3:
			if scene == null or scene.name != "MainMenu":
				return _abort("Zurueck ins Menue fehlgeschlagen")
			if not scene.resume_button.visible:
				return _abort("Fortsetzen fehlt nach gespeichertem Spiel")
			scene.resume_button.pressed.emit()
		4:
			if scene == null or scene.name != "Table" or scene.rules == null:
				return _abort("Fortsetzen laedt keinen Tisch")
			if var_to_str(scene.rules.state) != _snapshot:
				return _abort("Fortgesetzter Stand weicht ab")
			app.saves.clear()
			print("FLOW_OK")
			quit(0)
	_step += 1
	return false


func _abort(reason: String) -> bool:
	print("FLOW_FAIL ", reason)
	quit(1)
	return true
