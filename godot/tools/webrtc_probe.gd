extends SceneTree
## Prueft, ob WebRTC verfuegbar ist (Browser eingebaut, sonst webrtc-native).
## Ohne Erweiterung liefert Godots Stub faelschlich OK, daher zusaetzlich die
## Klasse der Erweiterung pruefen (nur ausserhalb des Browsers).
## Aufruf: Godot --headless --path godot --script res://tools/webrtc_probe.gd


func _init() -> void:
	var has_impl: bool = OS.has_feature("web") or ClassDB.class_exists("WebRTCLibPeerConnection")
	if not has_impl:
		print("WEBRTC_MISSING")
		quit()
		return
	var pc: WebRTCPeerConnection = WebRTCPeerConnection.new()
	var err: int = pc.initialize({})
	pc.close()
	print("WEBRTC_OK" if err == OK else "WEBRTC_MISSING")
	quit()
