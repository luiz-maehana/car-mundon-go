extends Control
## Tela de abertura (RF-100..102): arte cobrindo a tela, "aperte enter" piscando.

const ART := "res://assets/ui/intro.jpg"

var art: TextureRect
var prompt: Label
var t := 0.0
var leaving := false


func _ready() -> void:
	var gm := get_node_or_null("/root/Game")
	if gm:
		gm.play_music("menu")  # RF-221
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	art = TextureRect.new()
	art.texture = _load_art()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate.a = 0.0
	add_child(art)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.5)
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -78
	band.offset_bottom = -12
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	prompt = Label.new()
	prompt.text = "TOQUE PARA COMEÇAR" if (gm and gm.touch_on()) else "APERTE ENTER PARA COMEÇAR"  # RF-472
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 34)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 12)
	prompt.anchor_left = 0.0
	prompt.anchor_right = 1.0
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_top = -70
	prompt.offset_bottom = -20
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	# RF-473: tela cheia no navegador / celular (o navegador só deixa a partir de um toque)
	if OS.has_feature("web") or (gm and gm.touch_on()):
		var fs := Button.new()
		fs.text = "TELA CHEIA"
		fs.add_theme_font_size_override("font_size", 18)
		fs.anchor_left = 1.0
		fs.anchor_right = 1.0
		fs.offset_left = -200
		fs.offset_right = -20
		fs.offset_top = 20
		fs.offset_bottom = 68
		fs.name = "Fullscreen"
		fs.pressed.connect(func(): if gm: gm.toggle_fullscreen())
		add_child(fs)


func _load_art() -> Texture2D:
	if ResourceLoader.exists(ART):
		return load(ART)
	var p := ProjectSettings.globalize_path(ART)
	if FileAccess.file_exists(p):
		return ImageTexture.create_from_image(Image.load_from_file(p))
	return null


func _process(delta: float) -> void:
	t += delta
	if t == delta:
		print("[boot] abertura na tela em %d ms" % Time.get_ticks_msec())
	art.modulate.a = minf(1.0, t / 0.6)
	# zoom lento a partir do centro (RF-102)
	var z := 1.0 + 0.04 * (0.5 - 0.5 * cos(t * 0.35))
	art.pivot_offset = size * 0.5
	art.scale = Vector2(z, z)
	prompt.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 4.0)) if t > 0.6 else 0.0


func _input(event: InputEvent) -> void:
	# RF-472: no navegador o clique emulado do toque nem sempre chega (e a interface pode ficar com
	# ele); o próprio toque vale, menos em cima do botão TELA CHEIA (que tem o seu)
	if leaving or not (event is InputEventScreenTouch) or event.pressed:
		return
	var fs := get_node_or_null("Fullscreen") as Control
	if fs == null or not fs.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		go()


func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
			return
		if event.physical_keycode == KEY_M:
			return  # M é o mute global
		go()
	elif (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
		go()  # RF-472: o toque chega como clique (emulado) — e o botão TELA CHEIA consome o dele


func go() -> void:
	leaving = true
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
