extends SceneTree

# Erzeugt alle Soundeffekte und die Musikschleife synthetisch als WAV.
# Keine fremden Audiodateien, keine Lizenzfragen.
# Aufruf: godot --headless --path godot --script res://tools/gen_audio.gd

const RATE := 22050
const OUT := "res://assets/audio/"

var _noise_state := 12345

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("draw", _draw_sound())
	_save("place", _place_sound())
	_save("flip", _flip_sound())
	_save("dame", _dame_sound())
	_save("win", _win_sound())
	_save("penalty", _penalty_sound())
	_save("click", _click_sound())
	_save("error", _error_sound())
	_save("music", _music())
	print("AUDIO_OK")
	quit(0)


func _noise() -> float:
	# Deterministisches Rauschen (xorshift), damit die Dateien reproduzierbar sind.
	_noise_state ^= (_noise_state << 13) & 0xFFFFFFFF
	_noise_state ^= _noise_state >> 17
	_noise_state ^= (_noise_state << 5) & 0xFFFFFFFF
	_noise_state &= 0xFFFFFFFF
	return float(_noise_state) / 2147483648.0 - 1.0


func _save(name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT + name + ".wav"))
	if err != OK:
		push_error("Speichern fehlgeschlagen: %s" % name)


func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _draw_sound() -> PackedFloat32Array:
	var b := _buffer(0.16)
	var lp := 0.0
	for i in range(b.size()):
		var t := float(i) / RATE
		var env := sin(PI * minf(t / 0.16, 1.0)) * exp(-t * 9.0)
		var cutoff := 0.15 + 0.5 * (t / 0.16)
		lp += cutoff * (_noise() - lp)
		b[i] = lp * env * 0.7
	return b


func _place_sound() -> PackedFloat32Array:
	var b := _buffer(0.14)
	var phase := 0.0
	for i in range(b.size()):
		var t := float(i) / RATE
		var f := lerpf(150.0, 80.0, minf(t / 0.1, 1.0))
		phase += TAU * f / RATE
		var env := exp(-t * 30.0)
		var click := _noise() * exp(-t * 400.0) * 0.3
		b[i] = (sin(phase) * env * 0.8) + click
	return b


func _flip_sound() -> PackedFloat32Array:
	var b := _buffer(0.05)
	var prev := 0.0
	for i in range(b.size()):
		var t := float(i) / RATE
		var n := _noise()
		var hp := n - prev
		prev = n
		b[i] = hp * exp(-t * 90.0) * 0.45
	return b


func _tone(b: PackedFloat32Array, start: float, freq: float, length: float, amp: float, decay: float) -> void:
	var s := int(start * RATE)
	var n := int(length * RATE)
	for i in range(n):
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		var attack := minf(t / 0.008, 1.0)
		var env := attack * exp(-t * decay)
		var v := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) + 0.12 * sin(TAU * freq * 3.0 * t)
		b[s + i] += v * env * amp


func _dame_sound() -> PackedFloat32Array:
	var b := _buffer(1.1)
	_tone(b, 0.0, 659.25, 1.1, 0.32, 3.5)
	_tone(b, 0.16, 987.77, 0.95, 0.3, 3.2)
	_tone(b, 0.32, 1318.5, 0.8, 0.18, 4.0)
	return b


func _win_sound() -> PackedFloat32Array:
	var b := _buffer(1.2)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in range(notes.size()):
		_tone(b, k * 0.12, notes[k], 1.2 - k * 0.12, 0.25, 3.0)
	return b


func _penalty_sound() -> PackedFloat32Array:
	var b := _buffer(0.4)
	var phase := 0.0
	for i in range(b.size()):
		var t := float(i) / RATE
		var f := lerpf(120.0, 70.0, t / 0.4)
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase + 0.5))
		var env := minf(t / 0.01, 1.0) * exp(-t * 6.0)
		b[i] = saw * env * 0.35
	return b


func _click_sound() -> PackedFloat32Array:
	var b := _buffer(0.035)
	for i in range(b.size()):
		var t := float(i) / RATE
		b[i] = sin(TAU * 1600.0 * t) * exp(-t * 160.0) * 0.35
	return b


func _error_sound() -> PackedFloat32Array:
	var b := _buffer(0.32)
	_tone(b, 0.0, 220.0, 0.12, 0.3, 12.0)
	_tone(b, 0.15, 196.0, 0.16, 0.3, 10.0)
	return b


# Ruhige Schleife: Am - F - C - G, je 6 s, weiche Ueberblendung.
# Alle Frequenzen sind Vielfache von 1/LOOP Hz, damit die Schleife nahtlos ist.
func _music() -> PackedFloat32Array:
	const LOOP := 24.0
	var chords := [
		[110.0, 220.0, 261.63, 329.63],
		[87.31, 174.61, 220.0, 261.63],
		[130.81, 196.0, 261.63, 329.63],
		[98.0, 196.0, 246.94, 293.66],
	]
	var snapped: Array = []
	for chord in chords:
		var row: Array = []
		for f in chord:
			row.append(roundf(f * LOOP) / LOOP)
		snapped.append(row)
	var b := _buffer(LOOP)
	var seg := LOOP / chords.size()
	var lfo_f := 2.0 / LOOP
	for i in range(b.size()):
		var t := float(i) / RATE
		var sample := 0.0
		for k in range(snapped.size()):
			var center := (k + 0.5) * seg
			var d := absf(t - center)
			d = minf(d, LOOP - d)
			# Fenster: voll in der eigenen Haelfte, weich 1.5 s ueberblendet.
			var env := clampf((seg * 0.5 + 1.5 - d) / 3.0, 0.0, 1.0)
			if env <= 0.0:
				continue
			env = env * env * (3.0 - 2.0 * env)
			var row: Array = snapped[k]
			var bass: float = row[0]
			var chord_sum := sin(TAU * bass * t) * 0.9
			for j in range(1, row.size()):
				chord_sum += sin(TAU * float(row[j]) * t) * 0.32 + sin(TAU * float(row[j]) * 2.0 * t) * 0.05
			sample += chord_sum * env
		var lfo := 0.82 + 0.18 * sin(TAU * lfo_f * t)
		b[i] = sample * 0.11 * lfo
	return b
