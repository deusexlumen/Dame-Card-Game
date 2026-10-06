extends RefCounted
class_name CardArt

# Kartengrafiken aus assets/cards (erzeugt von tools/assets/gen_cards.py).
# Bube und Dame tragen je Sprache eigene Buchstaben (de: B/D, en: J/Q).

const FACE_DIR := "res://assets/cards/faces/"
const BACK_DIR := "res://assets/cards/backs/"
const SUIT_NAMES := {"hearts": "Herz", "diamonds": "Karo", "clubs": "Kreuz", "spades": "Pik"}

static var _cache := {}

static func face(card: Dictionary, skin: String = "klassisch", lang: String = "de") -> Texture2D:
	var rank := str(card.get("rank", ""))
	var suit := str(card.get("suit", ""))
	if rank == "" or suit == "":
		return null
	var file := "%s%s%s.png" % [rank, suit, ("_" + lang) if rank in ["J", "Q"] else ""]
	return _load(FACE_DIR + skin + "/" + file, FACE_DIR + "klassisch/" + file)


static func back(skin: String = "bordeaux") -> Texture2D:
	return _load(BACK_DIR + skin + ".png", BACK_DIR + "bordeaux.png")


static func _load(path: String, fallback: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else load(fallback)
	_cache[path] = tex
	return tex
