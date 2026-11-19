extends SceneTree
## Quanto cada parte do passo da corrida (race.step) gasta, numa corrida de 8 karts andando.
## No navegador do celular a CPU é o gargalo (RF-479).
##   godot --path . --script tools/profile_race.gd -- [pista]

const N := 300


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var game = root.get_node("Game")
	game.num_players = 1
	game.track_id = args[0] if args.size() > 0 else "queijo"
	game.selected_chars = ["mugurin"]
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 500:
		await physics_frame
	race.set_physics_process(false)
	var dt := 1.0 / 60.0
	var t := {}
	var parts := {
		"karts (física+IA)": func(): for k in race.karts: k.step(dt, true),
		"perigos da pista": func(): race._update_track_hazards(dt, true),
		"batidas": func(): race._kart_collisions(),
		"caixas": func(): race._update_boxes(dt),
		"itens no chão": func(): race._update_hazards(dt),
		"queijos": func(): race._update_cheese(dt),
		"vácuo": func(): race._update_slipstream(dt),
		"posições": func(): race._update_ranks(),
		"rubber": func(): race._update_rubber(),
		"câmeras": func(): race._update_cameras(dt, false),
		"HUD": func(): for h in race.huds: h.update_hud(dt),
	}
	for i in N:
		for k in parts:
			var t0 := Time.get_ticks_usec()
			parts[k].call()
			t[k] = t.get(k, 0) + Time.get_ticks_usec() - t0
	# kart a kart: jogador x IA
	var tk := {}
	for i in N:
		for k in race.karts:
			var t0 := Time.get_ticks_usec()
			k.step(dt, true)
			var key: String = "jogador" if k.is_player else "IA"
			tk[key] = tk.get(key, 0) + Time.get_ticks_usec() - t0
	# dentro do kart (IA): cada parte do step
	var tp := {}
	var ai: Array = race.karts.filter(func(k): return not k.is_player)
	for i in N:
		for k in ai:
			for m in ["_ai_input", "_move", "_update_track", "_update_air", "_update_power", "_update_visuals"]:
				var t0 := Time.get_ticks_usec()
				k.call(m, dt)
				tp[m] = tp.get(m, 0) + Time.get_ticks_usec() - t0
	for m in tp:
		print("%8.3f ms  IA %s (soma dos %d)" % [tp[m] / float(N) / 1000.0, m, ai.size()])
	var total := 0.0
	for k in t: total += t[k]
	print("PASSO %.3f ms" % (total / N / 1000.0))
	var keys := t.keys()
	keys.sort_custom(func(a, b): return t[a] > t[b])
	for k in keys:
		print("%8.3f ms  %s" % [t[k] / float(N) / 1000.0, k])
	for k in tk:
		print("%8.3f ms  kart %s (soma)" % [tk[k] / float(N) / 1000.0, k])
	quit()
