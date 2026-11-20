extends SceneTree
## RF-484: custo real de um passo da corrida COM janela (inclui o trabalho do motor quando karts,
## rodas e caixas se mexem, que o headless não mostra). Compara o tempo por quadro com o passo
## ligado e desligado.  godot --path . --resolution 1280x720 --rendering-method gl_compatibility --script tools/measure_tick.gd -- [pista]

func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> Array:
	var t := Time.get_ticks_usec()
	var ticks := Engine.get_physics_frames()
	for i in n:
		await process_frame
	return [float(Time.get_ticks_usec() - t) / n / 1000.0, float(Engine.get_physics_frames() - ticks) / n]


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 480  # muitos passos por quadro: o custo do passo aparece acima do ruído
	Engine.max_physics_steps_per_frame = 16
	var args := OS.get_cmdline_user_args()
	var game = root.get_node("Game")
	game.num_players = 1
	game.track_id = args[0] if args.size() > 0 else "queijo"
	game.selected_chars = ["mugurin"]
	game.settings["quality"] = 0
	var race = load("res://scenes/race.tscn").instantiate()
	race.autopilot_player = true
	root.add_child(race)
	for i in 500:
		await process_frame
	var best_on := INF
	var best_off := INF
	var tpf := 0.0
	for rep in 6:
		race.set_physics_process(true)
		var on: Array = await _frames(600)
		race.set_physics_process(false)
		var off: Array = await _frames(600)
		best_on = minf(best_on, on[0])
		best_off = minf(best_off, off[0])
		tpf = on[1]
	race.set_physics_process(true)
	print("PASSO com janela: %.2f ms por passo (quadro %.2f ms ligado, %.2f desligado, %.2f passos/quadro)" % [(best_on - best_off) / maxf(tpf, 0.001), best_on, best_off, tpf])
	quit()
