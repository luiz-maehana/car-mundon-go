extends SceneTree
## Relatório da IA numa pista: tempo de volta, resgates (e onde) de cada kart.
## godot --headless --path . --script tools/ai_report.gd -- <pista> [voltas]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = args[0]
	race.laps = int(args[1]) if args.size() > 1 else 2
	root.add_child(race)
	await process_frame
	var n: int = race.track.sample_count()
	var where := {}
	var last := {}
	var t := 0.0
	while t < 300.0 and not race.all_finished():
		race.step(1.0 / 60.0)
		t += 1.0 / 60.0
		for k in race.karts:
			if k.rescues != int(last.get(k.char_id, 0)):
				last[k.char_id] = k.rescues
				var f := snappedf(float(k.track_idx) / n, 0.01)
				where[f] = int(where.get(f, 0)) + 1
	for k in race.karts:
		print("%-9s %s resgates %d" % [k.char_id, ("%.1f s/volta" % (k.finish_time / race.laps)) if k.finished else "NÃO TERMINOU", k.rescues])
	print("resgates por trecho: ", where)
	quit()
