extends SceneTree
## Prints da navegação por controle (menu com foco nas opções/topo, pause e confirmação do GP).
## godot --path . --script tools/screenshot_ui.gd -- <saida_dir>

func _initialize() -> void:
	_run.call_deferred()


func _pad(button: int) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var game = root.get_node("Game")
	game.mode = "race"
	game.num_players = 1
	var menu = load("res://scenes/menu.tscn").instantiate()
	menu.start_scene = false
	root.add_child(menu)
	await process_frame
	game.note_device(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_DPAD_DOWN))
	menu._input(_pad(JOY_BUTTON_DPAD_DOWN))
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	for i in 5:
		await process_frame
	await _shot(out + "/ui_menu_opts.png")
	menu._focus_zone(0, 0)
	for i in 5:
		await process_frame
	await _shot(out + "/ui_menu_top.png")
	menu.queue_free()
	game.start_gp()
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 30:
		await physics_frame
	race.toggle_pause()
	for i in 5:
		await process_frame
	await _shot(out + "/ui_pause.png")
	race.menu_from_pause()
	for i in 5:
		await process_frame
	await _shot(out + "/ui_confirm.png")
	game.note_device(InputEventKey.new())
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
