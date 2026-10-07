extends RefCounted

# Link-Adapter ueber jedes Godot-MultiplayerPeer (ENet im Test, WebRTC spaeter).
# Gleiche Schnittstelle wie der Loopback-Link: my_id(), send(), receive().
# Wichtig: Den Peer nie multiplayer.multiplayer_peer zuweisen, sonst frisst
# SceneMultiplayer die Rohpakete. Nur dieser Link ruft poll().

signal peer_connected(id: int)
signal peer_disconnected(id: int)

# Groessere Pakete sind kein gueltiges Spielpaket und werden vor dem Dekodieren verworfen.
const MAX_PACKET := 64 * 1024

var peer: MultiplayerPeer


func _init(multiplayer_peer: MultiplayerPeer) -> void:
	peer = multiplayer_peer
	peer.peer_connected.connect(func(id: int): peer_connected.emit(id))
	peer.peer_disconnected.connect(func(id: int): peer_disconnected.emit(id))


func my_id() -> int:
	return peer.get_unique_id()


func send(to: int, bytes: PackedByteArray) -> void:
	if not is_open():
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.set_target_peer(to)
	peer.put_packet(bytes)


# Liefert alle wartenden Pakete als [{from, bytes}].
func receive() -> Array:
	# Geschlossener oder verlorener Peer: nichts mehr pollen (sonst Engine-Fehler).
	if not is_open():
		return []
	peer.poll()
	var out: Array = []
	while peer.get_available_packet_count() > 0:
		# Reihenfolge ist sicherheitsrelevant: get_packet_peer() meldet den
		# Absender des naechsten Pakets, also vor get_packet() lesen.
		var from := peer.get_packet_peer()
		var bytes := peer.get_packet()
		if bytes.size() > MAX_PACKET:
			continue
		out.append({"from": from, "bytes": bytes})
	return out


func is_open() -> bool:
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


# Idempotent: ein schon getrennter Peer wird nicht noch einmal geschlossen.
func close() -> void:
	if is_open():
		peer.close()
