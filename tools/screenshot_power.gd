extends SceneTree
## Print do HUD com o poder pronto e um oponente lento (anel azul).
## godot --path . --resolution 1280x720 --script tools/screenshot_power.gd -- <saida_dir>
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var game = root.get_node("Game")
	game.num_players = 1
	game.mode = "race"
	game.track_id = "queijo"
	game.selected_chars = ["fejaum"]
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 30:
		await process_frame
	race.state = "racing"
	race.countdown = 0.0
	for i in 120:
		await physics_frame
	var p = race.player
	p.cheese = 10
	for o in race.karts:
		if o != p:
			o.apply_slow(3.0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/power_hud.png")
	quit()
