extends SceneTree
## Reproduz o fluxo real com teclas simuladas e mede cada passo (procura travadas).
## godot --path . --script tools/esc_flow.gd

var t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	printraw("[%6d ms] %s\n" % [Time.get_ticks_msec() - t0, s])
	OS.get_stdout_type()  # força flush indireto


func _press(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scene() -> String:
	return current_scene.scene_file_path if current_scene else "?"


func _run() -> void:
	t0 = Time.get_ticks_msec()
	var game = root.get_node("Game")
	game.settings_path = "user://test_settings.cfg"
	change_scene_to_file("res://scenes/intro.tscn")
	await _frames(30)
	_log("intro: " + _scene())
	await _press(KEY_ENTER)
	await _frames(20)
	_log("menu: " + _scene())
	await _press(KEY_ENTER)
	await _frames(60)
	_log("corrida: " + _scene())
	var race = current_scene
	race.player.autopilot = true
	await _frames(400)
	_log("correndo t=%.1f" % race.race_time)
	await _press(KEY_ESCAPE)
	await _frames(30)
	_log("pause: paused=%s" % race.paused)
	await _press(KEY_ESCAPE)
	await _frames(30)
	_log("despausou: paused=%s t=%.1f" % [race.paused, race.race_time])
	await _press(KEY_ESCAPE)
	await _frames(10)
	_log("pause de novo; aperta Menu")
	race.pause_layer.get_child(1).get_child(0).get_child(4).pressed.emit()
	await _frames(30)
	_log("menu: " + _scene())
	await _press(KEY_ENTER)
	await _frames(60)
	race = current_scene
	_log("corrida 2: " + _scene())
	race.player.autopilot = true
	while not race.results_shown:
		race.step(1.0 / 60.0)
	await _frames(60)
	_log("resultado")
	await _press(KEY_ESCAPE)
	await _frames(30)
	_log("Esc no resultado -> " + _scene())
	await _press(KEY_ESCAPE)
	await _frames(30)
	_log("Esc no menu -> " + _scene())
	_log("Esc na abertura (deve fechar)")
	await _press(KEY_ESCAPE)
	await _frames(120)
	_log("AINDA ABERTO depois do Esc na abertura?")
	quit()
