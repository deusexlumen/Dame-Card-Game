extends RefCounted

# Protokoll zwischen Host und Gaesten. Gaeste schicken nur Aktionen,
# der Host schickt jedem Platz seine eigene DameView.

const VERSION := 1
const HOST_PEER := 1

# Aktionen, die ein Spieler (Gast oder Host-Spieler) schicken darf.
# start_next_round, timeout_penalty und peek_timeout steuert nur der Host selbst (Timer, Rundenende, Merkphase).
const PLAYER_ACTIONS := {
	"draw_deck": [],
	"draw_discard": [],
	"swap": ["hand_index"],
	"discard_drawn": [],
	"discard_extra": ["hand_index"],
	"look_card": ["target_seat", "hand_index"],
	"king_swap": ["opponent_seat", "opponent_index", "chosen_index"],
	"call_dame": [],
	"end_turn": [],
	"peek_ready": [],
}
const SYSTEM_ACTIONS := ["start_next_round", "timeout_penalty", "peek_timeout"]


# Baut aus einer fremden Aktion eine saubere: nur bekannte Typen, nur bekannte
# Felder, alles als int. Der Platz wird hier bewusst nicht uebernommen.
static func sanitize_action(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var type := str(raw.get("type", ""))
	if not PLAYER_ACTIONS.has(type):
		return {}
	var clean := {"type": type}
	for field in PLAYER_ACTIONS[type]:
		var v = raw.get(field, -1)
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return {}
		clean[field] = int(v)
	return clean


# Oeffentliche Form einer angenommenen Aktion fuer alle Tische (Animation, Toene).
# Nur Whitelist-Felder; der Platz kommt vom Aufrufer, nie aus der Aktion.
static func public_action(a: Dictionary, seat: int) -> Dictionary:
	var type := str(a.get("type", ""))
	var out := {"type": type, "seat": seat}
	if PLAYER_ACTIONS.has(type):
		for field in PLAYER_ACTIONS[type]:
			out[field] = int(a.get(field, -1))
	return out


const MAX_NAME := 20


# name: Spielername des Gastes (leer = Platzhalter des Hosts bleibt).
static func hello(name: String = "") -> Dictionary:
	var msg := {"t": "hello", "v": VERSION}
	if not name.is_empty():
		msg["name"] = name
	return msg


# Fremden Namen säubern: nur Text, ohne Steuerzeichen, getrimmt, höchstens MAX_NAME Zeichen.
static func clean_name(raw) -> String:
	if typeof(raw) != TYPE_STRING:
		return ""
	var out := ""
	for ch in (raw as String):
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().left(MAX_NAME).strip_edges()


static func action(a: Dictionary) -> Dictionary:
	return {"t": "action", "action": a}


# Host verlaesst die Partie absichtlich: Gaeste versuchen dann keinen Wiedereintritt.
static func bye() -> Dictionary:
	return {"t": "bye"}
