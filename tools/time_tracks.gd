extends SceneTree
## Mede quanto cada pista leva pra montar (cena da corrida até o _ready).
## godot --path . --script tools/time_tracks.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.num_players = 1
	game.mode = "race"
	for td in load("res://scripts/track.gd").TRACKS:
		game.track_id = td["id"]
		var t0 := Time.get_ticks_msec()
		var race = load("res://scenes/race.tscn").instantiate()
		root.add_child(race)
		var t1 := Time.get_ticks_msec()
		await process_frame
		await process_frame
		print("%-12s montar %5d ms, 1os quadros %5d ms" % [td["id"], t1 - t0, Time.get_ticks_msec() - t1])
		race.queue_free()
		await process_frame
	quit()
