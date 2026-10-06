extends RefCounted
class_name JsonStore

# Kleine Hilfe fuer Dateien unter user://. Schreibt atomar (tmp + rename).
# Kaputte Datei: wird als .bak gesichert, bevor sie je ueberschrieben wird.

static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Kann %s nicht schreiben" % tmp)
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func backup_corrupt(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var bak := path + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	DirAccess.rename_absolute(path, bak)
	push_warning("Beschaedigte Datei gesichert: %s" % bak)


# Liest ein JSON-Objekt. Fehlt die Datei: {}. Kaputt: sichern, dann {}.
static func read_json(path: String) -> Dictionary:
	var text := read_text(path)
	if text == "":
		return {}
	# JSON-Instanz statt parse_string: meldet Fehler still ueber den Rueckgabewert.
	var json := JSON.new()
	var parsed = json.data if json.parse(text) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY:
		backup_corrupt(path)
		return {}
	return parsed


static func write_json(path: String, data: Dictionary) -> bool:
	return write_text(path, JSON.stringify(data, "\t"))


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
