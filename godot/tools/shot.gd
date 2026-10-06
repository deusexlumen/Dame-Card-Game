extends SceneTree

# Screenshot einer Szene: godot --path godot --script res://tools/shot.gd -- <scene> <out.png> [frames] [setup]
# setup "turn": spielt einen Menschenzug bis zur gezogenen Karte.

var _frames := 0
var _target := 30
var _out := ""
var _setup := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/table.tscn"
	_out = args[1] if args.size() > 1 else "user://shot.png"
	_target = int(args[2]) if args.size() > 2 else 30
	_setup = args[3] if args.size() > 3 else ""
	# Nie echte Spielstaende, Statistik oder Chips anfassen.
	var app := root.get_node_or_null("App")
	if app != null:
		app.use_test_storage()
		# setup "en": alles auf Englisch.
		if _setup == "en":
			app.settings.set_value("language", "en")
			load("res://scripts/i18n.gd").install("en")
	change_scene_to_file(scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10 and _setup != "":
		_apply_setup()
	if _frames >= _target:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("SHOT ", _out)
		quit(0)
	return false


func _apply_setup() -> void:
	var scene := current_scene
	if scene == null or not scene.has_method("run_ai_until_human"):
		return
	scene.instant_ai = true
	scene.run_ai_until_human()
	match _setup:
		"fxdame":
			scene._fx.animate = true
			scene._fx.dame_called("Bruno")
		"fxwin":
			scene._fx.animate = true
			scene._fx.confetti()
			scene._fx.winner("Du gewinnst!")
			scene._fx.set_dame_active(true, 2)
		"think":
			# Echte KI-Zeit: Platz 1 ist am Zug und "denkt nach".
			scene.instant_ai = false
			scene.rules.state.current_index = 1
			scene._after_change()
		"six":
			scene.start({"seed": 5, "seat_count": 6, "ai_seats": [1, 2, 3, 4, 5], "names": ["Spieler", "Lotte", "Bruno", "Erika", "Kurt", "Hilde"]})
			scene.run_ai_until_human()
		"turn":
			scene._on_deck()
		"round":
			var r = scene.rules
			r.state.dame_caller_index = 0
			r._resolve_round()
			scene._after_change()
		"over":
			var r2 = scene.rules
			r2.state.players[1].total_score = 60
			r2.state.players[2].total_score = 60
			r2.state.players[3].total_score = 60
			r2.state.players[1].eliminated = true
			r2.state.players[2].eliminated = true
			r2.state.dame_caller_index = 0
			r2._resolve_round()
			scene._after_change()
		"pause":
			scene.toggle_pause()
		"hotseat":
			scene.start({"seed": 9, "seat_count": 3, "ai_seats": [2], "names": ["Anna", "Ben", "Kurt"]})
		"king":
			scene.rules.state.turn_step = "king"
			scene.king_own = 1
			scene.selected = 1
			scene._refresh()
