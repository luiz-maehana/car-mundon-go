extends SceneTree
## Prints do resgate (balões subindo e kart pousando piscando).
## godot --path . --script tools/screenshot_rescue.gd -- <saida_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var game = root.get_node_or_null("Game")
	game.num_players = 1
	game.mode = "race"
	game.track_id = "queijo"
	game.selected_chars = ["nanni"]
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 30:
		await process_frame
	race.state = "racing"
	race.countdown = 0.0
	var k = race.player
	k.place(120, 4.0)
	for i in 60:
		await process_frame
	k.start_rescue(false)
	for i in 22:
		k.step(1.0 / 60.0, true)
		await process_frame
	await _shot(out + "/rescue_lift.png")
	while k.rescue_time > 0.25:
		k.step(1.0 / 60.0, true)
		await process_frame
	await _shot(out + "/rescue_drop.png")
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("print: ", path)
