extends Node

# Headless-Einstieg: alle Suites laufen lassen, dann mit Exit-Code beenden.
# Aufruf: godot --headless --path godot res://tests/run_all.tscn

const TestContext = preload("res://tests/test_context.gd")
const SUITES := [
	"res://tests/test_stage1.gd",
	"res://tests/test_rules_core.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_table_ui.gd",
	"res://tests/test_meta.gd",
	"res://tests/test_online.gd",
]

func _ready() -> void:
	var app := get_node_or_null("/root/App")
	if app != null:
		app.use_test_storage()
	var ctx = TestContext.new()
	ctx.root = self
	for path in SUITES:
		ctx.current_suite = path.get_file().get_basename()
		var script: GDScript = load(path)
		if script == null:
			ctx.failures.append("%s: Suite nicht ladbar" % path)
			continue
		var suite = script.new()
		suite.run(ctx)
	if ctx.failures.is_empty():
		print("ALL_TESTS_OK checks=%d suites=%d" % [ctx.checks, SUITES.size()])
		call_deferred("_quit", 0)
	else:
		for line in ctx.failures:
			print("TEST_FAIL ", line)
		call_deferred("_quit", 1)

func _quit(code: int) -> void:
	get_tree().quit(code)
