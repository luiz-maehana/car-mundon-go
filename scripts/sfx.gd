extends RefCounted
## Sons 100% sintetizados em código, sem arquivos de áudio (RF-80/82).
## get_sound(nome) gera uma vez e guarda em cache (vale entre cenas).

const RATE := 22050
const MUSIC_RATE := 16000
const NAMES := ["beep", "go", "item", "boost", "mini_turbo", "drop", "shoot", "hit", "lap", "finish", "start_turbo", "stall", "bump", "cheese", "pad", "trick", "slip"]

static var _cache := {}


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _make(sound_name)
	return _cache[sound_name]


static func _make(sound_name: String) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	var r := RATE
	match sound_name:
		"beep":
			_tone(b, r, 0.0, 0.18, 523.0, 523.0, "square", 0.3)
		"go":
			_tone(b, r, 0.0, 0.5, 1046.0, 1046.0, "square", 0.3)
		"item":
			for i in 4:
				_tone(b, r, i * 0.05, 0.09, 660.0 * pow(1.26, i), 660.0 * pow(1.26, i), "square", 0.18)
		"boost":
			_tone(b, r, 0.0, 0.6, 180.0, 700.0, "saw", 0.22)
			_tone(b, r, 0.0, 0.6, 0.0, 0.0, "noise", 0.08)
		"mini_turbo":
			_tone(b, r, 0.0, 0.35, 300.0, 900.0, "saw", 0.18)
		"start_turbo":
			_tone(b, r, 0.0, 0.25, 523.0, 523.0, "square", 0.2)
			_tone(b, r, 0.12, 0.7, 200.0, 900.0, "saw", 0.22)
		"stall":
			_tone(b, r, 0.0, 0.5, 140.0, 50.0, "square", 0.25)
		"drop":
			_tone(b, r, 0.0, 0.14, 500.0, 220.0, "square", 0.2)
		"shoot":
			_tone(b, r, 0.0, 0.25, 900.0, 200.0, "square", 0.2)
			_tone(b, r, 0.0, 0.2, 0.0, 0.0, "noise", 0.12)
		"hit":
			_tone(b, r, 0.0, 0.45, 0.0, 0.0, "noise", 0.35)
			_tone(b, r, 0.0, 0.6, 600.0, 90.0, "square", 0.2)
		"lap":
			_tone(b, r, 0.0, 0.12, 784.0, 784.0, "square", 0.22)
			_tone(b, r, 0.13, 0.25, 1046.0, 1046.0, "square", 0.22)
		"bump":
			_tone(b, r, 0.0, 0.18, 0.0, 0.0, "noise", 0.4, 9.0)
			_tone(b, r, 0.0, 0.2, 110.0, 55.0, "square", 0.3, 6.0)
		"cheese":
			_tone(b, r, 0.0, 0.07, 988.0, 988.0, "square", 0.2)
			_tone(b, r, 0.06, 0.12, 1319.0, 1319.0, "square", 0.2)
		"pad":
			_tone(b, r, 0.0, 0.3, 400.0, 1200.0, "pulse", 0.22, 2.0)
		"trick":
			for i in 3:
				_tone(b, r, i * 0.06, 0.1, 784.0 * pow(1.19, i), 784.0 * pow(1.19, i), "pulse", 0.2)
			_tone(b, r, 0.15, 0.4, 300.0, 900.0, "saw", 0.18)
		"slip":
			_tone(b, r, 0.0, 0.5, 0.0, 0.0, "noise", 0.15, 1.5)
			_tone(b, r, 0.1, 0.4, 250.0, 750.0, "saw", 0.15)
		"finish":
			var notes := [523.0, 659.0, 784.0, 1046.0, 784.0, 1046.0]
			for i in notes.size():
				_tone(b, r, i * 0.12, 0.2 if i < 5 else 0.6, notes[i], notes[i], "square", 0.22)
		"music":
			return _music()
	return _to_wav(b, r, false)


## Soma um tom em b. wave: square, pulse (25%), saw, tri, sine, noise. Envelope ataque curto + decaimento.
static func _tone(b: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, wave: String, vol: float, decay := 3.0) -> void:
	var i0 := int(start * rate)
	var n := int(dur * rate)
	if b.size() < i0 + n:
		b.resize(i0 + n)
	var phase := 0.0
	var noise_val := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase = fmod(phase + f / rate, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"pulse":
				s = 1.0 if phase < 0.25 else -1.0
			"saw":
				s = phase * 2.0 - 1.0
			"tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"sine":
				s = sin(phase * TAU)
			"noise":
				if i % 2 == 0:
					noise_val = randf() * 2.0 - 1.0
				s = noise_val
		var env := minf(1.0, i / (0.004 * rate)) * exp(-decay * t)
		b[i0 + i] += s * vol * env


## Normaliza o pico para `target` (efeitos 0.9, música 0.75) antes de converter pra 16 bits.
static func _to_wav(b: PackedFloat32Array, rate: int, loop: bool, target := 0.9) -> AudioStreamWAV:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var gain := target / peak
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


## Chiptune em lá menor, 150 bpm, 8 compassos (Am F C G x2) com baixo, melodia e bateria.
static func _music() -> AudioStreamWAV:
	var r := MUSIC_RATE
	var beat := 60.0 / 150.0
	var eighth := beat / 2.0
	var bars := 8
	var b := PackedFloat32Array()
	b.resize(int(bars * 4 * beat * r))
	var roots := [110.0, 87.31, 130.81, 98.0]
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	var scale := [440.0, 523.25, 587.33, 659.26, 783.99, 880.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var melody := []
	for i in 32:  # 4 compassos de melodia, repetidos com variação
		melody.append(-1 if rng.randf() < 0.3 else rng.randi_range(0, scale.size() - 1))
	for bar in bars:
		var c := bar % 4
		var t0 := bar * 4 * beat
		for e in 8:
			var t := t0 + e * eighth
			_tone(b, r, t, eighth * 0.9, roots[c], roots[c], "square", 0.09, 2.0)
			if e % 2 == 1:
				_tone(b, r, t, 0.03, 0.0, 0.0, "noise", 0.05, 8.0)
			var m: int = melody[(bar % 4) * 8 + e]
			if bar >= 4 and e == 7:
				m = rng.randi_range(0, scale.size() - 1)
			if m >= 0:
				_tone(b, r, t, eighth * 1.6, scale[m], scale[m], "pulse", 0.06, 2.5)
		for k in [0, 2]:
			_tone(b, r, t0 + k * beat, 0.14, 140.0, 40.0, "sine", 0.3, 4.0)
		for s in [1, 3]:
			_tone(b, r, t0 + s * beat, 0.12, 0.0, 0.0, "noise", 0.13, 6.0)
		for note in chords[c]:
			_tone(b, r, t0, beat * 4, note, note, "tri", 0.025, 1.0)
	b.resize(int(bars * 4 * beat * r))
	return _to_wav(b, r, true, 0.75)
