extends RefCounted
class_name Catalog

# Shop-Artikel. Nur Kosmetik, nie ein Spielvorteil.
# Je Kategorie genau ein Gratis-Standard (price 0).

const CATEGORIES := {
	"card_back": "Kartenrücken",
	"card_face": "Kartenvorderseite",
	"table": "Tischfilz",
}

const ITEMS := [
	{"id": "back_bordeaux", "category": "card_back", "name": "Bordeaux", "price": 0, "data": {"skin": "bordeaux"}},
	{"id": "back_royal", "category": "card_back", "name": "Royal", "price": 120, "data": {"skin": "royal"}},
	{"id": "back_smaragd", "category": "card_back", "name": "Smaragd", "price": 150, "data": {"skin": "smaragd"}},
	{"id": "back_karo", "category": "card_back", "name": "Karo", "price": 200, "data": {"skin": "karo"}},
	{"id": "back_deco", "category": "card_back", "name": "Art déco", "price": 350, "data": {"skin": "deco"}},
	{"id": "face_klassisch", "category": "card_face", "name": "Klassisch", "price": 0, "data": {"skin": "klassisch"}},
	{"id": "face_vierfarben", "category": "card_face", "name": "Vierfarben", "price": 150, "data": {"skin": "vierfarben"}},
	{"id": "face_jumbo", "category": "card_face", "name": "Jumbo", "price": 150, "data": {"skin": "jumbo"}},
	{"id": "face_noir", "category": "card_face", "name": "Noir", "price": 300, "data": {"skin": "noir"}},
	{"id": "table_gruen", "category": "table", "name": "Casino-Grün", "price": 0, "data": {"color": "1f5a3a"}},
	{"id": "table_blau", "category": "table", "name": "Mitternachtsblau", "price": 150, "data": {"color": "1d3358"}},
	{"id": "table_bordeaux", "category": "table", "name": "Bordeaux", "price": 150, "data": {"color": "5a1a24"}},
	{"id": "table_schwarz", "category": "table", "name": "Anthrazit", "price": 250, "data": {"color": "26262b"}},
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
