extends SceneTree

# Speichert nur die genutzten Animationen aus UAL1_Standard.glb als kleine Bibliothek.
# Aufruf: godot --headless --path godot --script res://tools/strip_anims.gd
const KEEP := ["Sitting_Idle", "Sitting_Talking"]

func _initialize() -> void:
	var src: Node = (load("res://assets/characters/anim/UAL1_Standard.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = src.get_node("AnimationPlayer")
	var full: AnimationLibrary = ap.get_animation_library("")
	var lib := AnimationLibrary.new()
	for n in KEEP:
		var a: Animation = full.get_animation(n).duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(n, a)
	var err := ResourceSaver.save(lib, "res://assets/characters/anim/sitting.res", ResourceSaver.FLAG_COMPRESS)
	print("ANIMS_SAVED ", err)
	src.free()
	quit()
