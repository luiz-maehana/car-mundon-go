extends RefCounted
## RF-80/82/207: sons e músicas. Se existe arquivo em assets/audio/sfx/<nome> ou
## assets/audio/music/<estilo> (CC0, ver CREDITS.md), usa ele; senão sintetiza em código.
## get_sound(nome) carrega/gera uma vez e guarda em cache (vale entre cenas).

const RATE := 22050
const MUSIC_RATE := 16000
const NAMES := ["beep", "go", "item", "boost", "mini_turbo", "drop", "shoot", "hit", "lap", "finish", "start_turbo", "stall", "bump", "cheese", "pad", "trick", "slip", "engine", "meow", "shield", "shield_break", "snap", "crowd", "final_lap"]
const LOOPED := ["engine"]
const EXTS := ["ogg", "wav", "mp3"]

static var _cache := {}


static func get_sound(sound_name: String) -> AudioStream:
	if not _cache.has(sound_name):
		var f: AudioStream = null
		if sound_name.begins_with("music_"):
			f = from_file("music", sound_name.substr(6), true)
		else:
			f = from_file("sfx", sound_name, LOOPED.has(sound_name))
		_cache[sound_name] = f if f else _make(sound_name)
	return _cache[sound_name]


## Arquivo de áudio do projeto (ogg/wav/mp3), com loop ligado se pedido. null se não existe.
static func from_file(folder: String, base: String, loop: bool) -> AudioStream:
	for ext in EXTS:
		var p := "res://assets/audio/%s/%s.%s" % [folder, base, ext]
		if not ResourceLoader.exists(p):
			continue
		var s: AudioStream = load(p)
		if loop:
			s = s.duplicate()
			if s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
			elif "loop" in s:
				s.loop = true
		s.resource_name = p  # a cópia perde o resource_path
		return s
	return null


## Versão sintetizada (sem arquivo), usada se faltar o arquivo.
static func synth(sound_name: String) -> AudioStreamWAV:
	return _make(sound_name)


static func _make(sound_name: String) -> AudioStreamWAV:
	if sound_name == "final_lap":
		return _make("lap")
	if sound_name.begins_with("music_"):
		return _compose(sound_name.substr(6))
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
		"meow":
			_tone(b, r, 0.0, 0.18, 600.0, 1100.0, "tri", 0.3, 1.0)
			_tone(b, r, 0.16, 0.45, 1100.0, 520.0, "tri", 0.3, 2.5)
			_tone(b, r, 0.0, 0.6, 1200.0, 900.0, "pulse", 0.05, 3.0)
		"shield":
			for i in 5:
				_tone(b, r, i * 0.05, 0.25, 520.0 * pow(1.19, i), 520.0 * pow(1.19, i), "sine", 0.2, 2.0)
		"shield_break":
			_tone(b, r, 0.0, 0.35, 0.0, 0.0, "noise", 0.3, 5.0)
			_tone(b, r, 0.0, 0.3, 1800.0, 400.0, "tri", 0.25, 4.0)
		"snap":
			_tone(b, r, 0.0, 0.06, 0.0, 0.0, "noise", 0.6, 10.0)
			_tone(b, r, 0.0, 0.12, 2400.0, 300.0, "square", 0.3, 8.0)
			_tone(b, r, 0.05, 0.5, 90.0, 60.0, "square", 0.2, 5.0)
		"engine":
			return _engine_loop()
		"crowd":
			return _crowd()
		"music":
			return _compose("queijo")
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


## RF-220: trilhas por contexto. Acordes = [nota MIDI da fundamental, "M" maior | "m" menor].
## bass: "eighths" | "half" | "octaves" | "sync"; drums: "rock" | "soft" | "dance" | "darbuka".
const MUSIC_STYLES := {
	"menu": {"bpm": 118, "chords": [[48, "M"], [45, "m"], [41, "M"], [43, "M"]], "scale": [72, 74, 76, 79, 81, 84],
		"lead": "tri", "lead_vol": 0.07, "bass": "half", "drums": "soft", "seed": 11, "rest": 0.45},
	"queijo": {"bpm": 150, "chords": [[45, "m"], [41, "M"], [48, "M"], [43, "M"]], "scale": [69, 72, 74, 76, 79, 81],
		"lead": "pulse", "lead_vol": 0.06, "bass": "eighths", "drums": "rock", "seed": 2026, "rest": 0.3},
	"deserto": {"bpm": 136, "chords": [[38, "M"], [39, "M"], [38, "M"], [36, "m"]], "scale": [62, 63, 66, 67, 69, 70, 72, 74],
		"lead": "saw", "lead_vol": 0.045, "bass": "sync", "drums": "darbuka", "seed": 77, "rest": 0.35},
	"cozinha": {"bpm": 164, "chords": [[40, "m"], [36, "M"], [43, "M"], [38, "M"]], "scale": [64, 67, 69, 70, 71, 74, 76],
		"lead": "pulse", "lead_vol": 0.055, "bass": "octaves", "drums": "dance", "seed": 909, "rest": 0.35},
	"churrasco": {"bpm": 128, "chords": [[43, "M"], [40, "m"], [45, "m"], [38, "M"]], "scale": [67, 69, 71, 74, 76, 79],
		"lead": "tri", "lead_vol": 0.06, "bass": "sync", "drums": "dance", "seed": 31, "rest": 0.3},
	"fabrica": {"bpm": 150, "chords": [[40, "m"], [40, "m"], [43, "M"], [38, "M"]], "scale": [64, 67, 69, 71, 74, 76],
		"lead": "saw", "lead_vol": 0.04, "bass": "octaves", "drums": "dance", "seed": 1313, "rest": 0.4},
	"parquinho": {"bpm": 140, "chords": [[48, "M"], [43, "M"], [45, "m"], [41, "M"]], "scale": [72, 74, 76, 79, 81, 84],
		"lead": "square", "lead_vol": 0.055, "bass": "half", "drums": "rock", "seed": 808, "rest": 0.3},
	"geladeira": {"bpm": 124, "chords": [[45, "m"], [41, "M"], [43, "M"], [40, "m"]], "scale": [69, 72, 76, 79, 81, 84],
		"lead": "tri", "lead_vol": 0.06, "bass": "half", "drums": "soft", "seed": 4040, "rest": 0.35},
	"victory": {"bpm": 132, "chords": [[43, "M"], [48, "M"], [50, "M"], [43, "M"]], "scale": [67, 69, 71, 74, 76, 79],
		"lead": "square", "lead_vol": 0.06, "bass": "half", "drums": "rock", "seed": 5, "rest": 0.2},
}


static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## Trilha do estilo (gerada uma vez e guardada em cache).
static func music(style: String) -> AudioStream:
	return get_sound("music_" + (style if MUSIC_STYLES.has(style) else "queijo"))


## 8 compassos: baixo, acordes (tri), melodia com 4 compassos repetidos e variados, bateria.
static func _compose(style: String) -> AudioStreamWAV:
	var st: Dictionary = MUSIC_STYLES[style]
	var r := MUSIC_RATE
	var beat := 60.0 / float(st["bpm"])
	var eighth := beat / 2.0
	var bars := 8
	var b := PackedFloat32Array()
	b.resize(int(bars * 4 * beat * r))
	var scale: Array = st["scale"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(st["seed"])
	var melody := []
	for i in 32:
		melody.append(-1 if rng.randf() < float(st["rest"]) else rng.randi_range(0, scale.size() - 1))
	for bar in bars:
		var ch: Array = st["chords"][bar % 4]
		var root := float(ch[0])
		var third := 4.0 if ch[1] == "M" else 3.0
		var t0 := bar * 4 * beat
		# baixo
		match st["bass"]:
			"half":
				_tone(b, r, t0, beat * 1.9, midi(root), midi(root), "square", 0.09, 1.5)
				_tone(b, r, t0 + beat * 2, beat * 1.9, midi(root + 7), midi(root + 7), "square", 0.08, 1.5)
			"octaves":
				for e in 8:
					var n := root + (12.0 if e % 2 == 1 else 0.0)
					_tone(b, r, t0 + e * eighth, eighth * 0.8, midi(n), midi(n), "square", 0.085, 3.0)
			"sync":
				for e in [0, 3, 4, 6]:
					_tone(b, r, t0 + e * eighth, eighth * 1.2, midi(root), midi(root), "pulse", 0.1, 2.5)
			_:
				for e in 8:
					_tone(b, r, t0 + e * eighth, eighth * 0.9, midi(root), midi(root), "square", 0.09, 2.0)
		# acorde de fundo
		for iv in [0.0, third, 7.0]:
			var f := midi(root + 12.0 + iv)
			_tone(b, r, t0, beat * 4, f, f, "tri", 0.025, 1.0)
		# melodia
		for e in 8:
			var m: int = melody[(bar % 4) * 8 + e]
			if bar >= 4 and e == 7:
				m = rng.randi_range(0, scale.size() - 1)
			if m >= 0:
				var f := midi(float(scale[m]))
				_tone(b, r, t0 + e * eighth, eighth * 1.6, f, f, st["lead"], float(st["lead_vol"]), 2.5)
		# bateria
		match st["drums"]:
			"soft":
				for k in [0, 2]:
					_tone(b, r, t0 + k * beat, 0.12, 120.0, 45.0, "sine", 0.18, 4.0)
				for e in [1, 3, 5, 7]:
					_tone(b, r, t0 + e * eighth, 0.025, 0.0, 0.0, "noise", 0.03, 8.0)
			"dance":
				for k in 4:
					_tone(b, r, t0 + k * beat, 0.14, 150.0, 40.0, "sine", 0.32, 4.0)
				for s in [1, 3]:
					_tone(b, r, t0 + s * beat, 0.12, 0.0, 0.0, "noise", 0.13, 6.0)
				for e in 16:
					_tone(b, r, t0 + e * eighth * 0.5, 0.02, 0.0, 0.0, "noise", 0.025 if e % 2 == 0 else 0.04, 9.0)
			"darbuka":
				for e in [0, 3]:
					_tone(b, r, t0 + e * eighth, 0.1, 180.0, 70.0, "sine", 0.3, 5.0)
				for e in [2, 6]:
					_tone(b, r, t0 + e * eighth, 0.06, 0.0, 0.0, "noise", 0.12, 9.0)
				for e in [1, 5, 7]:
					_tone(b, r, t0 + e * eighth, 0.03, 900.0, 600.0, "tri", 0.05, 8.0)
			_:
				for k in [0, 2]:
					_tone(b, r, t0 + k * beat, 0.14, 140.0, 40.0, "sine", 0.3, 4.0)
				for s in [1, 3]:
					_tone(b, r, t0 + s * beat, 0.12, 0.0, 0.0, "noise", 0.13, 6.0)
				for e in [1, 3, 5, 7]:
					_tone(b, r, t0 + e * eighth, 0.03, 0.0, 0.0, "noise", 0.05, 8.0)
	b.resize(int(bars * 4 * beat * r))
	return _to_wav(b, r, true, 0.75)


## RF-222: torcida — ruído grave filtrado com "ondas" de volume + gritinhos.
static func _crowd() -> AudioStreamWAV:
	var r := RATE
	var dur := 2.4
	var n := int(dur * r)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / r
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.18)
		lp2 = lerpf(lp2, lp, 0.25)
		var env := minf(1.0, t / 0.25) * clampf((dur - t) / 1.2, 0.0, 1.0)
		var wave := 0.75 + 0.25 * sin(t * 7.0) * sin(t * 2.3)
		b[i] = lp2 * env * wave * 0.9
	for k in 14:
		var t0 := rng.randf_range(0.05, 1.6)
		var f0 := rng.randf_range(350.0, 650.0)
		_tone(b, r, t0, rng.randf_range(0.25, 0.5), f0, f0 * rng.randf_range(1.2, 1.6), "tri", 0.05, 3.0)
	return _to_wav(b, r, false, 0.8)


## Loop de motor (RF-81): 1 s com número inteiro de ciclos (emenda sem clique).
## O pitch é variado em tempo real pela corrida conforme a velocidade.
static func _engine_loop() -> AudioStreamWAV:
	var r := RATE
	var period := 400            # amostras por ciclo -> 55.125 Hz
	var n := period * 55          # 1 s exato
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rumble := 0.0
	for i in n:
		var ph := float(i % period) / period
		var ph2 := float(i % (period * 2)) / (period * 2)
		var saw := ph * 2.0 - 1.0
		var sub := 1.0 if ph2 < 0.5 else -1.0
		var pulse := 1.0 if ph < 0.18 else -0.2
		if i % 8 == 0:
			rumble = lerpf(rumble, rng.randf_range(-1.0, 1.0), 0.5)
		b[i] = saw * 0.45 + sub * 0.3 + pulse * 0.15 + rumble * 0.1
	return _to_wav(b, r, true, 0.8)
