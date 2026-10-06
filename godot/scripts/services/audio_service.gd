extends Node
class_name AudioService

# Soundeffekte und Musik. Busse "Music" und "SFX" werden zur Laufzeit angelegt.
# Lautstaerke 0-100 aus den Einstellungen. Dateien: CC0, Quellen in assets/audio/CREDITS.txt.

# Name -> Varianten (zufaellig gewaehlt, damit Wiederholungen nicht mechanisch klingen).
const SOUNDS := {
	"draw": ["draw1", "draw2", "draw3"],
	"place": ["place1", "place2", "place3"],
	"flip": ["flip1", "flip2"],
	"shuffle": ["shuffle"],
	"chips": ["chips1", "chips2"],
	"dame": ["dame"],
	"win": ["win"],
	"lose": ["lose"],
	"penalty": ["penalty"],
	"click": ["click"],
	"error": ["error"],
}
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
		var list: Array = []
		for file in SOUNDS[name]:
			var s = load("res://assets/audio/%s.ogg" % file)
			if s != null:
				list.append(s)
		if not list.is_empty():
			_streams[name] = list
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	var m = load("res://assets/audio/music.ogg")
	if m is AudioStreamOggVorbis:
		(m as AudioStreamOggVorbis).loop = true
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
	var list: Array = _streams[name]
	p.stream = list[randi() % list.size()]
	p.pitch_scale = randf_range(0.96, 1.04) if list.size() > 1 else 1.0
	p.play()


func start_music() -> void:
	if _music != null and _music.stream != null and not _music.playing and music_enabled:
		_music.play()


func stop_music() -> void:
	if _music != null and _music.playing:
		_music.stop()


func is_music_playing() -> bool:
	return _music != null and _music.playing
