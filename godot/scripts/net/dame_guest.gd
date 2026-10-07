extends RefCounted

# Gast einer Online-Partie. Kennt keine Regeln und keinen Zustand, nur die
# eigene DameView vom Host. Gleiche Schnittstelle wie der Host-Spieler.

const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")

signal view_changed(view: Dictionary, action: Dictionary)
signal action_result(result: Dictionary)
signal welcomed
signal rejected(reason: String)

var link
var rev := 0
var latest_view: Dictionary = {}


func _init(net_link) -> void:
	link = net_link


func is_authority() -> bool:
	return false


func connect_to_host() -> void:
	link.send(Protocol.HOST_PEER, Codec.encode(Protocol.hello()))


func send_action(action: Dictionary) -> void:
	link.send(Protocol.HOST_PEER, Codec.encode(Protocol.action(action)))


func poll() -> void:
	for pkt in link.receive():
		if int(pkt.from) != Protocol.HOST_PEER:
			continue
		var msg := Codec.decode(pkt.bytes)
		match str(msg.get("t", "")):
			"welcome":
				welcomed.emit()
			"reject":
				rejected.emit(str(msg.get("reason", "")))
			"view":
				# Veraltete oder doppelte Sichten verwerfen.
				if int(msg.get("rev", 0)) <= rev:
					continue
				rev = int(msg.rev)
				latest_view = msg.get("view", {})
				view_changed.emit(latest_view, msg.get("action", {}))
			"result":
				action_result.emit(msg)
