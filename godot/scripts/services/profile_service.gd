extends RefCounted
class_name ProfileService

# Chips, Besitz und ausgeruestete Kosmetik in user://profile.json.
# Jede Belohnung hat eine Ereignis-ID und wird genau einmal gutgeschrieben.

signal changed

const JsonStoreScript = preload("res://scripts/services/json_store.gd")
const CatalogScript = preload("res://scripts/services/catalog.gd")
const MAX_EVENTS := 500
# Katalog 2 = Casino-Shop (2026-10-06). Alte Kaeufe werden erstattet.
const CATALOG_VERSION := 2
const LEGACY_REFUNDS := {
	"back_diagonal": 120, "back_punkte": 120, "back_rauten": 200, "back_scanline": 350,
	"accent_bernstein": 200, "accent_eisblau": 200, "accent_weiss": 300, "accent_magenta": 400,
	"table_filz": 150, "table_mitternacht": 150,
}

var path := "user://profile.json"
var data: Dictionary = {}

func _init(p_path: String = "user://profile.json") -> void:
	path = p_path
	_load()


func _load() -> void:
	data = {"chips": 0, "owned": [], "equipped": {}, "events": [], "catalog_version": CATALOG_VERSION}
	var stored := JsonStoreScript.read_json(path)
	if typeof(stored.get("chips")) in [TYPE_INT, TYPE_FLOAT]:
		data.chips = maxi(0, int(stored.chips))
	var old_catalog: bool = not stored.is_empty() and int(stored.get("catalog_version", 1)) < CATALOG_VERSION
	if typeof(stored.get("owned")) == TYPE_ARRAY:
		for id in stored.owned:
			var sid := str(id)
			# Artikel aus dem alten Terminal-Shop: Chips zurueck statt verlorener Kauf.
			if old_catalog and LEGACY_REFUNDS.has(sid):
				data.chips = int(data.chips) + int(LEGACY_REFUNDS[sid])
				continue
			if old_catalog and sid == "table_schwarz":
				continue
			if not CatalogScript.item(sid).is_empty() and not data.owned.has(sid):
				data.owned.append(sid)
	if typeof(stored.get("events")) == TYPE_ARRAY:
		for e in stored.events:
			data.events.append(str(e))
	for cat in CatalogScript.CATEGORIES:
		var def := CatalogScript.default_for(cat)
		if not data.owned.has(def):
			data.owned.append(def)
		data.equipped[cat] = def
	if typeof(stored.get("equipped")) == TYPE_DICTIONARY:
		for cat in stored.equipped:
			var id := str(stored.equipped[cat])
			var it := CatalogScript.item(id)
			if not it.is_empty() and str(it.category) == str(cat) and data.owned.has(id):
				data.equipped[str(cat)] = id
	if old_catalog:
		# Sofort sichern, damit die Erstattung nur einmal passiert.
		_save()


func chips() -> int:
	return int(data.chips)


func owns(id: String) -> bool:
	return data.owned.has(id)


func equipped(category: String) -> String:
	return str(data.equipped.get(category, CatalogScript.default_for(category)))


func equipped_data(category: String) -> Dictionary:
	return CatalogScript.item(equipped(category)).get("data", {})


# Gibt true zurueck, wenn neu gutgeschrieben.
func award(event_id: String, amount: int) -> bool:
	if amount <= 0 or data.events.has(event_id):
		return false
	data.events.append(event_id)
	while data.events.size() > MAX_EVENTS:
		data.events.pop_front()
	data.chips = int(data.chips) + amount
	_save()
	return true


func spend(amount: int) -> void:
	data.chips = maxi(0, int(data.chips) - amount)
	_save()


func grant(id: String) -> void:
	if not data.owned.has(id):
		data.owned.append(id)
	_save()


func equip(id: String) -> bool:
	var it := CatalogScript.item(id)
	if it.is_empty() or not owns(id):
		return false
	data.equipped[str(it.category)] = id
	_save()
	return true


func _save() -> void:
	JsonStoreScript.write_json(path, data)
	changed.emit()
