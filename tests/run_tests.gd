extends SceneTree
## Testes headless dos critérios de aceite (SPEC.md §8).
## godot --headless --path . --script tests/run_tests.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(42)
	_test_characters()
	_test_track()
	await _test_race()
	_test_inputs()
	await _test_multiplayer()
	print("\n%s (%d falha(s))" % ["PASSOU" if fails == 0 else "FALHOU", fails])
	quit(1 if fails > 0 else 0)


func _test_characters() -> void:
	print("CA-01 pilotos")
	var chars: Array = load("res://scripts/characters.gd").LIST
	check(chars.size() == 8, "8 pilotos")
	var ids := {}
	for c in chars:
		ids[c["id"]] = true
		var total := 0
		for s in ["speed", "accel", "handling", "weight"]:
			check(c[s] >= 1 and c[s] <= 5, "%s.%s em 1..5" % [c["name"], s])
			total += c[s]
		check(total == 12, "%s soma 12 (=%d)" % [c["name"], total])
	check(ids.size() == 8, "IDs únicos")
	print("CA-09 fotos")
	var Chars = load("res://scripts/characters.gd")
	for c in chars:
		var tex: Texture2D = Chars.face_texture(c["id"])
		check(tex != null and tex.get_width() > 64, "%s tem foto" % c["name"])
		var ctr: Vector2 = c["face_center"]
		var half: float = c["face_zoom"] * 0.5
		check(ctr.x - half >= 0.0 and ctr.x + half <= 1.0 and ctr.y - half >= 0.0 and ctr.y + half <= 1.0, "%s recorte dentro da imagem" % c["name"])


func _test_track() -> void:
	print("CA-02 pista")
	var Track = load("res://scripts/track.gd")
	var t = Track.new()
	var n: int = t.sample_count()
	check(t.length > 800.0, "comprimento %.0f m > 800" % t.length)
	var min_s := INF
	var max_s := 0.0
	for i in n:
		var d: float = t.points[i].distance_to(t.points[(i + 1) % n])
		min_s = minf(min_s, d)
		max_s = maxf(max_s, d)
	check(min_s > 1.8 and max_s < 2.2, "espaçamento %.2f..%.2f m" % [min_s, max_s])
	# sem sobreposição: amostras longe no índice devem estar longe no espaço
	var gap := int(80.0 / Track.SPACING)
	var worst := INF
	for i in n:
		for j in range(i + gap, n):
			if n - (j - i) < gap:
				continue
			worst = minf(worst, t.points[i].distance_to(t.points[j]))
	check(worst > Track.WALL * 2.0 + 2.0, "menor distância entre trechos %.1f m > %.1f" % [worst, Track.WALL * 2.0 + 2.0])
	t.free()


func _test_race() -> void:
	print("CA-03..06 corrida simulada")
	var Race = load("res://scripts/race.gd")
	var race = Race.new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["telles"]
	race.laps = 3
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	check(race.karts.size() == 8, "8 karts no grid")
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < 360.0 and not race.all_finished():
		race.step(dt)
		t += dt
	check(race.all_finished(), "todos terminaram (%.1f s simulados)" % t)
	var ranking: Array = race.ranking()
	var ranks := {}
	var last_time := -1.0
	var ordered := true
	var max_lat := 0.0
	var fastest := INF
	for k in ranking:
		ranks[k.rank] = true
		if k.finish_time < last_time:
			ordered = false
		last_time = k.finish_time
		max_lat = maxf(max_lat, k.max_abs_lateral)
		fastest = minf(fastest, k.finish_time)
		print("     %dº %-9s %s" % [k.rank, k.display_name, "%.2f s" % k.finish_time if k.finished else "--"])
	check(ranks.size() == 8, "posições 1..8 sem repetição")
	check(ordered, "tempos de chegada crescentes")
	var Track = load("res://scripts/track.gd")
	check(max_lat <= Track.WALL + 0.5, "lateral máx %.2f <= muro+0.5" % max_lat)
	var min_possible: float = race.laps * race.track.length / 45.0
	check(fastest > min_possible, "corrida mais rápida %.1f s > limite físico %.1f s" % [fastest, min_possible])
	var used := 0
	for k in race.karts:
		used += k.items_used
	check(race.boxes_picked > 0 and used > 0, "itens pegos=%d usados=%d" % [race.boxes_picked, used])
	check(race.results_shown, "tela de resultado apareceu")
	race.queue_free()
	await process_frame


func _test_inputs() -> void:
	print("CA-08 controles por jogador")
	var Game = load("res://scripts/game.gd")
	Game.setup_inputs()
	var all_ok := true
	var pads_ok := true
	for p in 4:
		for a in Game.ACTIONS:
			var act: String = Game.action(p, a)
			if not InputMap.has_action(act):
				all_ok = false
				continue
			for e in InputMap.action_get_events(act):
				if (e is InputEventJoypadButton or e is InputEventJoypadMotion) and e.device != p:
					pads_ok = false
	check(all_ok, "todas as ações existem para J1..J4")
	check(pads_ok, "eventos de controle presos ao device do jogador")
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	check(InputMap.event_is_action(w, "p1_accelerate") and not InputMap.event_is_action(w, "p2_accelerate"), "W acelera só o J1")
	check(InputMap.event_is_action(up, "p2_accelerate") and not InputMap.event_is_action(up, "p1_accelerate"), "↑ acelera só o J2")
	var rshift := InputEventKey.new()
	rshift.physical_keycode = KEY_SHIFT
	rshift.location = KEY_LOCATION_RIGHT
	var lshift := InputEventKey.new()
	lshift.physical_keycode = KEY_SHIFT
	lshift.location = KEY_LOCATION_LEFT
	check(InputMap.event_is_action(rshift, "p2_drift") and not InputMap.event_is_action(rshift, "p1_drift"), "Shift direito = drift do J2")
	check(InputMap.event_is_action(lshift, "p1_drift") and not InputMap.event_is_action(lshift, "p2_drift"), "Shift esquerdo = drift do J1")
	var pad2 := InputEventJoypadButton.new()
	pad2.button_index = JOY_BUTTON_A
	pad2.device = 1
	pad2.pressed = true
	check(InputMap.event_is_action(pad2, "p2_accelerate") and not InputMap.event_is_action(pad2, "p1_accelerate"), "controle 2 acelera só o J2")


func _test_multiplayer() -> void:
	print("CA-07 tela dividida com 4 jogadores")
	var Race = load("res://scripts/race.gd")
	var race = Race.new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["digao", "nanni", "burcca", "mugurin"]
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	check(race.players.size() == 4 and race.cameras.size() == 4 and race.huds.size() == 4, "4 jogadores, 4 câmeras, 4 HUDs")
	var back_ok := true
	for i in 4:
		if race.karts.find(race.players[i]) != 4 + i or race.players[i].char_id != race.player_chars[i]:
			back_ok = false
	check(back_ok, "humanos nas 4 últimas posições do grid, na ordem J1..J4")
	var ids := {}
	for k in race.karts:
		ids[k.char_id] = true
	check(ids.size() == 8, "8 pilotos diferentes no grid")
	var masks_ok := true
	for i in 4:
		var bit := 1 << (10 + i)
		if race.cameras[i].cull_mask & bit != 0:
			masks_ok = false
	check(masks_ok, "cada câmera esconde só o nome do próprio jogador")
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < 200.0 and not race.all_finished():
		race.step(dt)
		t += dt
	check(race.all_finished(), "todos terminaram (%.1f s simulados)" % t)
	check(race.results_shown, "resultado apareceu após todos os humanos terminarem")
	race.queue_free()
	await process_frame
