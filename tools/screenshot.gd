extends SceneTree
## Tira prints do menu e da corrida com 1, 2 e 4 jogadores para revisão visual.
## godot --path . --script tools/screenshot.gd -- <saida_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var game = root.get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game.gd").new()
		game.name = "Game"
		root.add_child(game)
	game.num_players = 2
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._go_step(menu.STEP_PILOT, false)
	menu._confirm()  # J1 escolhe; tela fica no J2
	for i in 10:
		await process_frame
	await _shot(out + "/menu.png")
	menu.queue_free()
	var setups := [["race1", ["fejaum"]], ["race2", ["fejaum", "digao"]], ["race4", ["fejaum", "digao", "nanni", "ortiz"]]]
	# resultado: corrida de 1 volta acelerada até o fim
	game.num_players = 1
	game.selected_chars = ["burcca"]
	game.laps = 1
	var rr = load("res://scenes/race.tscn").instantiate()
	rr.autopilot_player = true
	root.add_child(rr)
	await process_frame
	while not rr.results_shown:
		rr.step(1.0 / 60.0)
	for i in 30:
		await process_frame
	await _shot(out + "/results.png")
	rr.queue_free()
	await process_frame
	game.laps = 3
	for s in setups:
		game.num_players = s[1].size()
		game.selected_chars = s[1]
		var race = load("res://scenes/race.tscn").instantiate()
		race.autopilot_player = true
		root.add_child(race)
		for i in 60 * 9:
			await physics_frame
		await _shot(out + "/" + s[0] + ".png")
		race.queue_free()
		await process_frame
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
