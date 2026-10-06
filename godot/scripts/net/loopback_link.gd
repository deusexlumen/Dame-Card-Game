extends RefCounted

# Netz im Speicher fuer Tests. Jede Nachricht laeuft durch den echten Codec,
# damit Typfehler wie im Netz auffallen. Ein Hub verbindet mehrere Links.

class Hub:
	extends RefCounted
	var queues := {}

	func link(peer_id: int):
		queues[peer_id] = []
		return LoopbackLinkImpl.new(self, peer_id)

	func deliver(from: int, to: int, bytes: PackedByteArray) -> void:
		if queues.has(to):
			queues[to].append({"from": from, "bytes": bytes})

	func disconnect_peer(peer_id: int) -> void:
		queues.erase(peer_id)


class LoopbackLinkImpl:
	extends RefCounted
	var hub
	var id: int

	func _init(h, peer_id: int) -> void:
		hub = h
		id = peer_id

	func my_id() -> int:
		return id

	func send(to: int, bytes: PackedByteArray) -> void:
		hub.deliver(id, to, bytes)

	# Liefert alle wartenden Pakete als [{from, bytes}].
	func receive() -> Array:
		if not hub.queues.has(id):
			return []
		var out: Array = hub.queues[id]
		hub.queues[id] = []
		return out


static func new_hub():
	return Hub.new()
