extends SceneTree
## Prints de pontos de uma pista (largada, cruzamento, perigos) e da etapa PISTA do menu.
## godot --path . --script tools/screenshot_track.gd -- <saida_dir> <track_id>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var tid: String = args[1] if args.size() > 1 else "parquinho"
	var game = root.get_node_or_null("Game")
	game.num_players = 1
	game.mode = "race"
	game.track_id = tid
	game.selected_chars = ["fejaum"]
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 30:
		await process_frame
	race.state = "racing"
	race.countdown = 0.0
	var t = race.track
	var n: int = t.sample_count()
	var spots := {"start": 4}
	for c in t.crossings:
		spots["cross_a"] = wrapi(int(c[0]) - 7, 0, n)
		spots["cross_b"] = wrapi(int(c[1]) - 14, 0, n)
	for h in t.hazard_specs:
		spots[String(h["kind"])] = wrapi(int(h["idx"]) - 6, 0, n)
	for z in t.zones:
		spots[String(z["kind"])] = wrapi(int(z["i0"]) + 4, 0, n)
	if t.ramp_idx >= 0:
		spots["ramp"] = wrapi(t.ramp_idx - 6, 0, n)
	for l in t.loops:
		spots["loop_in"] = wrapi(int(l["i0"]) - 10, 0, n)
		spots["loop_top"] = int((int(l["i0"]) + int(l["i1"])) / 2)
	for o in t.overpasses:
		spots["over_low"] = wrapi(int(o[0]) - 12, 0, n)
		spots["over_high"] = wrapi(int(o[1]) - 12, 0, n)
	for tn in t.def.get("tunnels", []):
		spots["tunnel"] = int(n * float(tn[0])) - 4
	for name in spots:
		var k = race.player
		k.place(int(spots[name]), 0.0)
		if t.in_loop(int(spots[name])):
			k.on_loop = true
			k.loop_s = float(spots[name])
			k.speed = 0.0
		k.speed = 0.0
		k.vel = Vector3.ZERO
		# outro kart parado no meio do cruzamento da outra passada, pra ver a escala
		if name == "cross_a" and t.crossings.size() > 0:
			race.karts[1].place(int(t.crossings[0][1]), 0.0)
		for i in 90:
			race._update_track_hazards(1.0 / 60.0, false)
			await process_frame
		await _shot("%s/%s_%s.png" % [out, tid, name])
	race.queue_free()
	await process_frame
	var menu = load("res://scenes/menu.tscn").instantiate()
	menu.start_scene = false
	root.add_child(menu)
	await process_frame
	for i in TrackScript_ids().size():
		if TrackScript_ids()[i] == tid:
			menu.track_i = i
	menu._go_step(menu.STEP_TRACK, false)
	for i in 120:
		await process_frame
	await _shot("%s/%s_menu.png" % [out, tid])
	quit()


func TrackScript_ids() -> Array:
	return load("res://scripts/track.gd").TRACKS.map(func(d): return d["id"])


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("print: ", path)
