extends RefCounted
## Dados dos pilotos. Stats de 1 a 5, soma 12 = balanceado (ver SPEC.md §3).
## face_center/face_zoom: recorte circular da foto em assets/faces/<id>.jpg (RF-70).

const FaceCircleShader = preload("res://shaders/face_circle.gdshader")

const LIST := [
	{"id": "fejaum", "name": "FeJauM", "color": Color(1.0, 0.55, 0.1), "speed": 4, "accel": 3, "handling": 3, "weight": 2, "face_center": Vector2(0.5, 0.42), "face_zoom": 0.62},
	{"id": "burcca", "name": "Burcca", "color": Color(0.9, 0.12, 0.12), "speed": 5, "accel": 2, "handling": 2, "weight": 3, "face_center": Vector2(0.47, 0.44), "face_zoom": 0.6},
	{"id": "mugurin", "name": "Mugurin", "color": Color(0.2, 0.8, 0.25), "speed": 2, "accel": 4, "handling": 4, "weight": 2, "face_center": Vector2(0.51, 0.42), "face_zoom": 0.6},
	{"id": "telles", "name": "Telles", "color": Color(0.15, 0.4, 0.95), "speed": 3, "accel": 3, "handling": 3, "weight": 3, "face_center": Vector2(0.52, 0.47), "face_zoom": 0.58},
	{"id": "ortiz", "name": "Ortiz", "color": Color(0.55, 0.2, 0.85), "speed": 4, "accel": 2, "handling": 2, "weight": 4, "face_center": Vector2(0.32, 0.42), "face_zoom": 0.56},
	{"id": "shinando", "name": "Shinando", "color": Color(1.0, 0.85, 0.1), "speed": 3, "accel": 4, "handling": 3, "weight": 2, "face_center": Vector2(0.5, 0.45), "face_zoom": 0.62},
	{"id": "nanni", "name": "Nanni", "color": Color(1.0, 0.45, 0.75), "speed": 2, "accel": 5, "handling": 3, "weight": 2, "face_center": Vector2(0.45, 0.48), "face_zoom": 0.64},
	{"id": "digao", "name": "Digão", "color": Color(0.92, 0.92, 0.92), "speed": 3, "accel": 2, "handling": 2, "weight": 5, "face_center": Vector2(0.48, 0.44), "face_zoom": 0.6},
]

static var _face_cache := {}


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


## Foto do piloto (RF-70) ou null (RF-74). Usa o recurso importado; se a imagem
## ainda não foi importada pelo editor, lê o arquivo direto.
static func face_texture(id: String) -> Texture2D:
	if _face_cache.has(id):
		return _face_cache[id]
	var tex: Texture2D = null
	for ext in ["jpg", "png", "jpeg", "webp"]:
		var path := "res://assets/faces/%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			tex = load(path)
			break
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
				break
	_face_cache[id] = tex
	return tex


## TextureRect redondo com a foto (menu/HUD/resultado). null se não houver foto.
static func face_rect(id: String, size: float) -> TextureRect:
	var tex := face_texture(id)
	if tex == null:
		return null
	var c := find(id)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(size, size)
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FaceCircleShader
	mat.set_shader_parameter("ring", c["color"])
	mat.set_shader_parameter("center", c["face_center"])
	mat.set_shader_parameter("zoom", c["face_zoom"])
	tr.material = mat
	return tr
