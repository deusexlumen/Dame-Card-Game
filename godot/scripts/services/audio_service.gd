extends Node
class_name AudioService

# Soundeffekte und Musik. Busse "Music" und "SFX" werden zur Laufzeit angelegt.
# Lautstaerke 0-100 aus den Einstellungen.

const SOUNDS := ["draw", "place", "flip", "dame", "win", "penalty", "click", "error"]
const POOL_SIZE := 6

var _streams := {}
var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var sound_enabled := true
var music_enabled := true

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for name in SOUNDS:
		var s = load("res://assets/audio/%s.wav" % name)
		if s != null:
			_streams[name] = s
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	# Schleife kommt aus den Import-Einstellungen (music.wav.import, loop_mode Forward).
	var m = load("res://assets/audio/music.wav")
	if m != null:
		_music.stream = m
	add_child(_music)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_settings(settings) -> void:
	sound_enabled = bool(settings.get_value("sound_enabled"))
	music_enabled = bool(settings.get_value("music_enabled"))
	_set_volume("SFX", int(settings.get_value("effects_volume")))
	_set_volume("Music", int(settings.get_value("music_volume")))
	if music_enabled:
		start_music()
	else:
		stop_music()


func _set_volume(bus_name: String, percent: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var lin := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, lin <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.001)))


func play(name: String) -> void:
	if not sound_enabled or not _streams.has(name) or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.play()


func start_music() -> void:
	if _music != null and _music.stream != null and not _music.playing and music_enabled:
		_music.play()


func stop_music() -> void:
	if _music != null and _music.playing:
		_music.stop()


func is_music_playing() -> bool:
	return _music != null and _music.playing
