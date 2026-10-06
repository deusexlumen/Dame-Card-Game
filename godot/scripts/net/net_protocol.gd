extends RefCounted

# Protokoll zwischen Host und Gaesten. Gaeste schicken nur Aktionen,
# der Host schickt jedem Platz seine eigene DameView.

const VERSION := 1
const HOST_PEER := 1

# Aktionen, die ein Spieler (Gast oder Host-Spieler) schicken darf.
# start_next_round und timeout_penalty steuert nur der Host selbst (Timer, Rundenende).
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
}
const SYSTEM_ACTIONS := ["start_next_round", "timeout_penalty"]


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


static func hello() -> Dictionary:
	return {"t": "hello", "v": VERSION}


static func action(a: Dictionary) -> Dictionary:
	return {"t": "action", "action": a}
