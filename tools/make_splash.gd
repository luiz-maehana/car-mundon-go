extends SceneTree
## RF-351: gera assets/ui/splash.png (imagem de inicialização do Godot): a arte da abertura
## com uma faixa escura e "CARREGANDO..." na fonte do jogo.
## godot --path . --resolution 1280x720 --script tools/make_splash.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gm = root.get_node_or_null("Game")
	if gm and gm.fps_label:
		gm.fps_label.visible = false
		gm.set_process(false)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var art := TextureRect.new()
	art.texture = load("res://assets/ui/intro.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(art)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.55)
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -78
	band.offset_bottom = -12
	ui.add_child(band)
	var l := Label.new()
	l.text = "CARREGANDO..."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://assets/kenney/fonts/Kenney Future Narrow.ttf") if ResourceLoader.exists("res://assets/kenney/fonts/Kenney Future Narrow.ttf") else root.get_node("Game").theme.default_font)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 12)
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -70
	l.offset_bottom = -20
	ui.add_child(l)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://assets/ui/splash.png")
	print("splash: ", img.get_size())
	quit()
