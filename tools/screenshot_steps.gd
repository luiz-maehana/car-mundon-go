extends SceneTree
## Prints de cada etapa do menu (abertura, MODO, PILOTO, PISTA, AJUSTES) pra revisão visual.
## godot --path . --resolution 1280x720 --script tools/screenshot_steps.gd -- <saida_dir> [sufixo]

func _initialize() -> void:
	_run.call_deferred()


func _pad(button: int) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var suf: String = args[1] if args.size() > 1 else ""
	var game = root.get_node("Game")
	game.mode = "race"
	game.num_players = 1
	var intro_scene := "res://scenes/intro.tscn"
	if ResourceLoader.exists(intro_scene):
		var intro = load(intro_scene).instantiate()
		root.add_child(intro)
		for i in 90:
			await process_frame
		await _shot("%s/step0_intro%s.png" % [out, suf])
		intro.queue_free()
		await process_frame
	var menu = load("res://scenes/menu.tscn").instantiate()
	menu.start_scene = false
	root.add_child(menu)
	for i in 60:
		await process_frame
	await _shot("%s/step1_mode%s.png" % [out, suf])
	menu._input(_pad(JOY_BUTTON_A))
	for i in 60:
		await process_frame
	await _shot("%s/step2_pilot%s.png" % [out, suf])
	menu._input(_pad(JOY_BUTTON_A))
	for i in 90:
		await process_frame
	await _shot("%s/step3_track%s.png" % [out, suf])
	menu._input(_pad(JOY_BUTTON_A))
	for i in 60:
		await process_frame
	await _shot("%s/step4_setup%s.png" % [out, suf])
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("print: ", path)
