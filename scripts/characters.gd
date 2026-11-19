extends RefCounted
## Dados dos pilotos (cor e número = o carro de cada um na arte da abertura, RF-380).
## RF-420: cada um tem um poder exclusivo ("power"), liberado com 10 queijinhos e recarga de 20 s. Stats de 1 a 5, soma 12 = balanceado (ver SPEC.md §3).
## Arte: assets/chars/<id>.png (corpo) e <id>_head.png (busto), gerados por tools/process_characters.gd.

const LIST := [
	{"id": "fejaum", "name": "FeJauM", "color": Color(0.12, 0.36, 0.95), "number": 1, "power": {"id": "slowmo", "name": "Câmera Lenta", "desc": "Todos os outros ficam 50% mais lentos por 1 s (com um anel azul em volta). O escudo protege."}, "speed": 4, "accel": 3, "handling": 3, "weight": 2,
		"ai": {"aggro": 0.5, "avoid": 0.6, "focus": 0.6, "drift": 0.6},
		"look": {"fur": Color(0.93, 0.83, 0.72), "hair": "messy", "hair_color": Color(0.06, 0.05, 0.05), "beard": "none", "glasses": "clear", "shirt": Color(0.1, 0.1, 0.11)}},
	{"id": "burcca", "name": "Burcca", "color": Color(0.9, 0.12, 0.12), "number": 2, "power": {"id": "bass", "name": "Grave no Talo", "desc": "Solta uma onda de som que derruba quem estiver a até 12 m. O escudo protege."}, "speed": 5, "accel": 2, "handling": 2, "weight": 3,
		"ai": {"aggro": 0.95, "avoid": 0.35, "focus": 0.45, "drift": 0.7},
		"look": {"fur": Color(0.86, 0.69, 0.52), "hair": "messy", "hair_color": Color(0.33, 0.2, 0.11), "beard": "full", "glasses": "clear", "headphones": true, "shirt": Color(0.58, 0.58, 0.6)}},
	{"id": "mugurin", "name": "Mugurin", "color": Color(0.2, 0.8, 0.25), "number": 4, "power": {"id": "ghost", "name": "Fantasma", "desc": "Fica transparente por 4 s: atravessa karts, itens e obstáculos sem ser atingido."}, "speed": 2, "accel": 4, "handling": 4, "weight": 2,
		"ai": {"aggro": 0.35, "avoid": 0.9, "focus": 0.6, "drift": 0.45},
		"look": {"fur": Color(0.88, 0.67, 0.46), "hair": "curly", "hair_color": Color(0.06, 0.05, 0.05), "beard": "full", "glasses": "none", "shirt": Color(0.08, 0.08, 0.1)}},
	{"id": "telles", "name": "Telles", "color": Color(0.72, 0.05, 0.2), "number": 7, "power": {"id": "drift", "name": "Drift Mestre", "desc": "Por 8 s todo drift já sai com o turbo máximo (faísca roxa)."}, "speed": 3, "accel": 3, "handling": 3, "weight": 3,
		"ai": {"aggro": 0.55, "avoid": 0.6, "focus": 0.9, "drift": 0.85},
		"look": {"fur": Color(0.9, 0.66, 0.43), "hair": "long", "hair_color": Color(0.13, 0.08, 0.06), "beard": "goatee", "beard_color": Color(0.06, 0.05, 0.05), "glasses": "sun", "shirt": Color(0.07, 0.07, 0.08)}},
	{"id": "ortiz", "name": "Ortiz", "color": Color(0.55, 0.2, 0.85), "number": 8, "power": {"id": "ram", "name": "Trombada", "desc": "Por 4 s fica maior e pesado: quem ele encosta roda e ninguém empurra ele."}, "speed": 4, "accel": 2, "handling": 2, "weight": 4,
		"ai": {"aggro": 0.9, "avoid": 0.4, "focus": 0.4, "drift": 0.6},
		"look": {"fur": Color(0.92, 0.8, 0.67), "hair": "messy", "hair_color": Color(0.1, 0.14, 0.1), "beard": "stubble", "beard_color": Color(0.3, 0.22, 0.16), "glasses": "none", "shirt": Color(0.08, 0.08, 0.1)}},
	{"id": "shinando", "name": "Shinando", "color": Color(0.25, 0.72, 1.0), "number": 6, "power": {"id": "guitar", "name": "Violão", "desc": "Toca o violão e fica com escudo por 5 s."}, "speed": 3, "accel": 4, "handling": 3, "weight": 2,
		"ai": {"aggro": 0.5, "avoid": 0.65, "focus": 0.85, "drift": 0.75},
		"look": {"fur": Color(0.9, 0.69, 0.5), "hair": "curly", "hair_color": Color(0.62, 0.27, 0.11), "beard": "full", "glasses": "none", "shirt": Color(0.08, 0.08, 0.1)}},
	{"id": "nanni", "name": "Nanni", "color": Color(1.0, 0.82, 0.1), "number": 3, "power": {"id": "plant", "name": "Planta Turbo", "desc": "Uma planta no kart com 5 mini-turbos: cada aperto é um turbo. A recarga começa quando acabam (ou em 10 s)."}, "speed": 2, "accel": 5, "handling": 3, "weight": 2,
		"ai": {"aggro": 0.3, "avoid": 0.95, "focus": 0.7, "drift": 0.4},
		"look": {"fur": Color(0.91, 0.75, 0.59), "hair": "short", "hair_color": Color(0.3, 0.19, 0.11), "beard": "stubble", "beard_color": Color(0.35, 0.25, 0.17), "glasses": "none", "shirt": Color(0.25, 0.25, 0.27)}},
	{"id": "digao", "name": "Digão", "color": Color(1.0, 0.5, 0.08), "number": 5, "power": {"id": "steal", "name": "Mão Leve", "desc": "Rouba o item de quem está logo à frente. Se ninguém tiver item, ganha um Queijo Triplo."}, "speed": 3, "accel": 2, "handling": 2, "weight": 5,
		"ai": {"aggro": 0.6, "avoid": 0.55, "focus": 0.55, "drift": 0.55},
		"look": {"fur": Color(0.92, 0.77, 0.61), "hair": "short", "hair_color": Color(0.06, 0.05, 0.05), "beard": "full", "glasses": "none", "shirt": Color(0.1, 0.12, 0.26)}},
]

static var _art_cache := {}


const POWER_CD := 20.0
const POWER_HOWTO := "Junte 10 queijinhos pra liberar o poder. Depois de usar, ele recarrega em 20 s (e você precisa ter 10 queijinhos de novo se perder algum)."


static func find(id: String) -> Dictionary:
	for c in LIST:
		if c["id"] == id:
			return c
	return LIST[0]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0


## kind = "head" (busto) ou "full" (corpo inteiro). null se não houver arte (RF-74).
## Usa o recurso importado; se ainda não foi importado pelo editor, lê o PNG direto.
static func art(id: String, kind := "head") -> Texture2D:
	var key := id + ":" + kind
	if _art_cache.has(key):
		return _art_cache[key]
	var path := "res://assets/chars/%s%s.png" % [id, "_head" if kind == "head" else ""]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_art_cache[key] = tex
	return tex


## TextureRect com a arte, mantendo a proporção, com altura fixa. null se não houver arte.
static func art_rect(id: String, height: float, kind := "head") -> TextureRect:
	var tex := art(id, kind)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := height * float(tex.get_width()) / float(tex.get_height())
	tr.custom_minimum_size = Vector2(w, height)
	tr.size = Vector2(w, height)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
