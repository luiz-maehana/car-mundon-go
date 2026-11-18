extends SceneTree
## Teste de estresse: cria e destrói 12 corridas seguidas (motores ligados).
## Rode COM janela (driver de áudio real): godot --path . --script tools/stress_races.gd -- mp
## Modos: input | auto | mp | mp_noengine | mp_noaudio
func _initialize():
	_run.call_deferred()
func _run():
	var mode: String = OS.get_cmdline_user_args()[0]
	load("res://scripts/game.gd").setup_inputs()
	for i in 12:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = mode != "input"
		if mode == "mp_noengine":
			race.engines_enabled = false
		if mode == "mp_noaudio":
			race.audio_enabled = false
		race.player_chars = ["digao", "nanni", "burcca", "mugurin"] if mode.begins_with("mp") else ["telles"]
		race.laps = 1
		root.add_child(race)
		await process_frame
		for s in 200:
			if mode == "input" and race.countdown <= 1.2:
				Input.action_press("p1_accelerate")
			race.step(1.0 / 60.0)
		Input.action_release("p1_accelerate")
		race.queue_free()
		await process_frame
		print("iter ", i)
	print("OK")
	quit()
