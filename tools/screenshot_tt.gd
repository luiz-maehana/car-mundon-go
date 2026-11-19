extends SceneTree
## Prints do contra o relógio (menu, 1ª corrida, 2ª corrida com fantasma, resultado).
## godot --path . --script tools/screenshot_tt.gd -- <saida_dir>
## Usa um arquivo de recordes à parte (não mexe nos recordes do jogador).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var Records = load("res://scripts/records.gd")
	Records.path = "user://shot_records.cfg"
	Records.clear_all()
	var game = root.get_node_or_null("Game")
	game.mode = "tt"
	game.num_players = 1
	game.selected_chars = ["burcca"]
	game.laps = 2
	game.track_id = "queijo"
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 10:
		await process_frame
	await _shot(out + "/tt_menu.png")
	menu.queue_free()
	for run in 2:
		var rr = load("res://scenes/race.tscn").instantiate()
		rr.autopilot_player = true
		root.add_child(rr)
		await process_frame
		if run == 1:
			# fica um pouco pra trás do fantasma pra ele aparecer na frente
			while rr.race_time < 6.0:
				rr.step(1.0 / 60.0)
				if rr.race_time < 2.5:
					rr.player.speed = minf(rr.player.speed, 20.0)
			for i in 20:
				await process_frame
			await _shot(out + "/tt_ghost.png")
		while not rr.results_shown:
			rr.step(1.0 / 60.0)
		for i in 30:
			await process_frame
		await _shot(out + "/tt_results%d.png" % (run + 1))
		rr.queue_free()
		await process_frame
	Records.clear_all()
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
