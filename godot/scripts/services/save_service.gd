extends RefCounted
class_name SaveService

# Laufende Partie in user://save.dat. var_to_str erhaelt die Typen exakt
# (JSON wuerde aus int float machen).

const JsonStoreScript = preload("res://scripts/services/json_store.gd")
const VERSION := 1

var path := "user://save.dat"

func _init(p_path: String = "user://save.dat") -> void:
	path = p_path


func has_save() -> bool:
	return not load_match().is_empty()


# match: {"rules": rules.to_dict(), "meta": {...}}
func save_match(rules_data: Dictionary, meta: Dictionary) -> bool:
	var payload := {"version": VERSION, "rules": rules_data, "meta": meta}
	return JsonStoreScript.write_text(path, var_to_str(payload))


# Gibt {} zurueck, wenn nichts oder nur Unbrauchbares da ist.
func load_match() -> Dictionary:
	var text := JsonStoreScript.read_text(path)
	if text == "":
		return {}
	var parsed = str_to_var(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", -1)) != VERSION:
		return {}
	if typeof(parsed.get("rules")) != TYPE_DICTIONARY or typeof(parsed.get("meta")) != TYPE_DICTIONARY:
		return {}
	return parsed


func clear() -> void:
	JsonStoreScript.remove(path)


# Kaputter Spielstand beim Laden: sichern statt loeschen.
func quarantine() -> void:
	JsonStoreScript.backup_corrupt(path)
