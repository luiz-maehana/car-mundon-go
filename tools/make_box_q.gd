extends SceneTree
## RF-486: gera assets/ui/box_q.png, o "?" pintado nas faces da caixa de item (antes era um
## Label3D por caixa = 2 desenhos cada). Precisa de janela (headless não desenha):
##   godot --path . --script tools/make_box_q.gd

const OUT := "res://assets/ui/box_q.png"
const SIZE := 128


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var l := Label.new()
	l.text = "?"
	l.add_theme_font_override("font", load("res://assets/kenney/fonts/Kenney Future Narrow.ttf"))
	l.add_theme_font_size_override("font_size", 104)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(SIZE, SIZE)
	vp.add_child(l)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("box_q: ", OUT, " ", error_string(err))
	quit()
