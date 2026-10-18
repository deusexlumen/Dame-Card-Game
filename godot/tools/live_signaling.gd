extends SceneTree

# Live-Test gegen das echte Supabase: Host und Gast betreten denselben Raum,
# Host schickt "invite", Gast antwortet mit "answer". Braucht freies Netz mit
# WebSockets (GitHub Actions ja, Cloud-Sandbox mit Proxy nein).
# Aufruf: godot --headless --path godot --script res://tools/live_signaling.gd
# Ergebnis: LIVE_SIGNALING_OK (Exit 0) oder LIVE_SIGNALING_FAIL <Grund> (Exit 1).

const Signaling = preload("res://scripts/net/signaling.gd")
const TIMEOUT_MS := 20000

var _host
var _guest
var _got := {}
var _errors: Array[String] = []


func _initialize() -> void:
	var room := Signaling.new_room_code()
	_host = Signaling.new()
	_guest = Signaling.new()
	_host.failed.connect(func(r): _errors.append("Host: " + r))
	_guest.failed.connect(func(r): _errors.append("Gast: " + r))
	_host.event.connect(func(n, p): _got["host:" + n] = p)
	_guest.event.connect(func(n, p): _got["guest:" + n] = p)
	_host.open(room)
	_guest.open(room)
	_run.call_deferred(room)


func _run(room: String) -> void:
	var start := Time.get_ticks_msec()
	var invite_sent := false
	var answer_sent := false
	while Time.get_ticks_msec() - start < TIMEOUT_MS and _errors.is_empty():
		_host.poll()
		_guest.poll()
		# Kurz warten nach dem Beitritt, damit der Gast-Kanal sicher abonniert ist.
		if not invite_sent and _host.is_joined() and _guest.is_joined():
			await create_timer(0.5).timeout
			_host.send_event("invite", {"code": "probe-" + room})
			invite_sent = true
		if not answer_sent and _got.has("guest:invite"):
			_guest.send_event("answer", {"code": "probe-answer"})
			answer_sent = true
		if _got.has("host:answer"):
			break
		await process_frame
	_host.close()
	_guest.close()
	var ok: bool = _got.has("guest:invite") and _got.has("host:answer") \
		and str(_got["guest:invite"].get("code", "")) == "probe-" + room
	if ok:
		print("LIVE_SIGNALING_OK room=%s ms=%d" % [room, Time.get_ticks_msec() - start])
		quit(0)
	else:
		var reason := ", ".join(_errors) if not _errors.is_empty() else "Zeitlimit, erhalten: %s" % str(_got.keys())
		print("LIVE_SIGNALING_FAIL ", reason)
		quit(1)
