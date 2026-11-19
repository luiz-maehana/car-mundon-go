extends SceneTree
## RF-481: a corrida dá o mesmo resultado a 60 e a 30 passos de física por segundo? (a web roda a 30)
## Simula todos os karts no piloto automático e compara tempos de chegada, quedas e resgates.
##   godot --headless --path . --script tools/tick_parity.gd

func _initialize() -> void:
	_run.call_deferred()


func _sim(tid: String, hz: float, sd: int) -> Dictionary:
	seed(sd)
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.audio_enabled = false
	race.player_chars = ["nanni"]
	race.track_id = tid
	race.laps = 2
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	var dt := 1.0 / hz
	var t := 0.0
	while t < 260.0 and race.karts.any(func(k): return not k.finished):
		race.step(dt)
		t += dt
	var times := []
	var rescues := 0
	for k in race.karts:
		times.append(k.finish_time if k.finished else 999.0)
		rescues += int(k.rescues)
	times.sort()
	race.queue_free()
	return {"times": times, "rescues": rescues}


func _run() -> void:
	for tid in ["queijo", "geladeira", "telhados", "feira", "parquinho"]:
		var r := {}
		for hz in [60.0, 30.0]:
			var avg := 0.0
			var best := 999.0
			var dnf := 0
			var res := 0
			for sd in [11, 22, 33]:
				var o := _sim(tid, hz, sd)
				for x in o["times"]:
					if x >= 999.0:
						dnf += 1
					else:
						avg += x
				best = minf(best, o["times"][0])
				res += o["rescues"]
			r[hz] = [avg / maxf(1.0, 24.0 - dnf), best, dnf, res]
			await process_frame
		print("%-10s 60Hz: média %.1f s · melhor %.1f · não chegou %d · resgates %d   |   30Hz: média %.1f s · melhor %.1f · não chegou %d · resgates %d" % [tid, r[60.0][0], r[60.0][1], r[60.0][2], r[60.0][3], r[30.0][0], r[30.0][1], r[30.0][2], r[30.0][3]])
	quit()
