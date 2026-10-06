extends SceneTree

# Laedt jedes Skript einmal und meldet Parse-Fehler. Aufruf mit --script.

func _initialize() -> void:
	var bad := 0
	for path in _collect("res://"):
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate()):
			print("PARSE_FAIL ", path)
			bad += 1
	print("CHECK_DONE bad=%d" % bad)
	quit(1 if bad > 0 else 0)


func _collect(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		out.append_array(_collect(dir.path_join(d)))
	return out
