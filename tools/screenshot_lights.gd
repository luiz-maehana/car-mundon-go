extends SceneTree
## Prints do semáforo na contagem (Queijo) e dos faróis à noite (Telhados).
## godot --path . --resolution 1280x720 --script tools/screenshot_lights.gd -- <saida_dir>
func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var game = root.get_node("Game")
	game.num_players = 1
	game.mode = "race"
	game.selected_chars = ["fejaum"]
	game.track_id = "queijo"
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	while race.countdown > 1.6:  # contagem no "2"
		await physics_frame
	for i in 5:
		await process_frame
	await _shot(out + "/lights_countdown.png")
	race.queue_free()
	await process_frame
	game.track_id = "telhados"
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	while race.state == "countdown":
		await physics_frame
	race.player.autopilot = true
	for i in 200:
		await physics_frame
	await _shot(out + "/lights_night.png")
	quit()
