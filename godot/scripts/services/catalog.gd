extends RefCounted
class_name Catalog

# Shop-Artikel. Nur Kosmetik, nie ein Spielvorteil.
# Je Kategorie genau ein Gratis-Standard (price 0).

const CATEGORIES := {
	"card_back": "Kartenrücken",
	"accent": "Phosphor-Farbe",
	"table": "Tisch",
}

const ITEMS := [
	{"id": "back_raster", "category": "card_back", "name": "Raster", "price": 0, "data": {"back_style": "raster"}},
	{"id": "back_diagonal", "category": "card_back", "name": "Diagonal", "price": 120, "data": {"back_style": "diagonal"}},
	{"id": "back_punkte", "category": "card_back", "name": "Punkte", "price": 120, "data": {"back_style": "punkte"}},
	{"id": "back_rauten", "category": "card_back", "name": "Rauten", "price": 200, "data": {"back_style": "rauten"}},
	{"id": "back_scanline", "category": "card_back", "name": "Bildröhre", "price": 350, "data": {"back_style": "scanline"}},
	{"id": "accent_gruen", "category": "accent", "name": "Grün", "price": 0, "data": {"color": "8cff8c"}},
	{"id": "accent_bernstein", "category": "accent", "name": "Bernstein", "price": 200, "data": {"color": "ffb547"}},
	{"id": "accent_eisblau", "category": "accent", "name": "Eisblau", "price": 200, "data": {"color": "7fd8ff"}},
	{"id": "accent_weiss", "category": "accent", "name": "Papierweiß", "price": 300, "data": {"color": "e8f0e0"}},
	{"id": "accent_magenta", "category": "accent", "name": "Magenta", "price": 400, "data": {"color": "ff7ae0"}},
	{"id": "table_schwarz", "category": "table", "name": "Schwarz", "price": 0, "data": {"color": "050905"}},
	{"id": "table_filz", "category": "table", "name": "Filzgrün", "price": 150, "data": {"color": "0b2414"}},
	{"id": "table_mitternacht", "category": "table", "name": "Mitternacht", "price": 150, "data": {"color": "070b1e"}},
	{"id": "table_bordeaux", "category": "table", "name": "Bordeaux", "price": 250, "data": {"color": "1e070c"}},
]

# Verdienst in Chips je Ereignis.
const REWARD_ROUND := 5
const REWARD_CORRECT_CALL := 20
const REWARD_WIN := 50
const HARD_MULTIPLIER := 2

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if str(it.id) == id:
			return it
	return {}


static func items_in(category: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if str(it.category) == category:
			out.append(it)
	return out


static func default_for(category: String) -> String:
	for it in ITEMS:
		if str(it.category) == category and int(it.price) == 0:
			return str(it.id)
	return ""
