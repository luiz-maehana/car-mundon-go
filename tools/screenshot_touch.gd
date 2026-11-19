extends SceneTree
## Print da corrida com os controles de toque (rode com --rendering-method gl_compatibility pra
## ver como fica no navegador).
## godot --path . --resolution 1280x720 [--rendering-method gl_compatibility] --script tools/screenshot_touch.gd -- <saida_dir> [pista]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var game = root.get_node("Game")
	game.settings["touch_controls"] = "on"
	game.num_players = 1
	game.mode = "race"
	game.track_id = args[1] if args.size() > 1 else "parquinho"
	game.selected_chars = ["nanni"]
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	while race.state == "countdown":
		await physics_frame
	for i in 120:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/touch_%s.png" % [out, game.track_id])
	game.settings["touch_controls"] = "auto"
	quit()
