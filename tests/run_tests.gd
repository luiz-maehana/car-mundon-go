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
	# configurações isoladas: não usa nem altera o arquivo do jogador
	var g = root.get_node_or_null("Game")
	if g:
		g.settings_path = "user://test_settings.cfg"
		g.reset_settings()
	_test_characters()
	_test_track()
	await _test_race()
	_test_inputs()
	await _test_multiplayer()
	_test_sounds()
	await _test_start()
	await _test_pause()
	await _test_intro()
	await _test_faces()
	await _test_all_tracks()
	await _test_v08()
	await _test_graphics()
	await _test_assets()
	await _test_settings()
	await _test_hud_layout()
	await _test_gp()
	await _test_new_items()
	await _test_smart_ai()
	_test_music()
	await _test_time_trial()
	await _test_ui_nav()
	await _test_layout()
	await _test_remap()
	await _test_char_select()
	await _test_new_tracks()
	await _test_drift_feel()
	await _test_parquinho()
	await _test_rescue()
	await _test_geladeira()
	await _test_telhados()
	await _test_menu_look()
	await _test_loading()
	await _test_results_live()
	await _test_feira()
	_test_char_colors()
	await _test_redone_tracks()
	await _test_stick_menu()
	await _test_powers()
	await _test_drift_vs_turn()
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
	print("CA-09 arte dos camundongos")
	var Chars = load("res://scripts/characters.gd")
	for c in chars:
		for kind in ["full", "head"]:
			var tex: Texture2D = Chars.art(c["id"], kind)
			var ok: bool = tex != null and tex.get_width() > 64
			if ok:
				var img := tex.get_image()
				if img.is_compressed():
					img.decompress()
				ok = img.get_pixel(0, 0).a < 0.05 or img.get_pixel(img.get_width() - 1, 0).a < 0.05
			check(ok, "%s: arte '%s' com fundo transparente" % [c["name"], kind])


func _test_track() -> void:
	var Track = load("res://scripts/track.gd")
	for td in Track.TRACKS:
		_test_one_track(td["id"])


## Par de amostras (i, j) dentro da região de um cruzamento declarado da pista?
func _at_crossing(t, i: int, j: int) -> bool:
	var n: int = t.sample_count()
	for c in t.crossings:
		var a := absi(wrapi(i - int(c[0]), -n / 2, n / 2)) < 20 and absi(wrapi(j - int(c[1]), -n / 2, n / 2)) < 20
		var b := absi(wrapi(j - int(c[0]), -n / 2, n / 2)) < 20 and absi(wrapi(i - int(c[1]), -n / 2, n / 2)) < 20
		if a or b:
			return true
	return false


func _test_one_track(track_id: String) -> void:
	var Track = load("res://scripts/track.gd")
	var t = Track.new(track_id)
	print("CA-02 pista: %s" % t.def["name"])
	check(t.def["id"] == track_id, "pista '%s' encontrada" % track_id)
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
			if _at_crossing(t, i, j):  # RF-300: o 8 se cruza de propósito, só ali
				continue
			if absf(t.points[i].y - t.points[j].y) >= 6.0:  # RF-322: andares diferentes (viaduto)
				continue
			# RF-320: muro estreito (looping, ponte) deixa os trechos chegarem mais perto
			worst = minf(worst, t.points[i].distance_to(t.points[j]) - (t.wall_at(i) + t.wall_at(j) - Track.WALL * 2.0))
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


func _new_race(chars: Array, auto: bool) -> Node:
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = auto
	race.player_chars = chars
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	return race


func _test_sounds() -> void:
	print("CA-10 sons")
	var Sfx = load("res://scripts/sfx.gd")
	var ok := true
	var files := 0
	for n in Sfx.NAMES:
		var s: AudioStream = Sfx.get_sound(n)
		if s == null or s.get_length() < 0.05:
			ok = false
			printerr("     som vazio: ", n)
		if s and s.resource_name.begins_with("res://assets/audio"):
			files += 1
	check(ok, "%d efeitos com conteúdo" % Sfx.NAMES.size())
	check(files == Sfx.NAMES.size(), "todos vêm de arquivo CC0 (%d/%d)" % [files, Sfx.NAMES.size()])
	var eng: AudioStream = Sfx.get_sound("engine")
	check(eng is AudioStreamWAV and eng.loop_mode == AudioStreamWAV.LOOP_FORWARD, "motor em loop")
	var m: AudioStreamWAV = Sfx.synth("music_menu")
	var secs: float = m.data.size() / 2.0 / m.mix_rate
	check(m.loop_mode == AudioStreamWAV.LOOP_FORWARD and secs > 8.0, "reserva sintetizada em loop (%.1f s)" % secs)


## Roda a contagem; press_at = countdown em que começa a segurar o acelerador (-1 = nunca).
func _run_start(press_at: float) -> String:
	var race = await _new_race(["telles"], false)
	var dt := 1.0 / 60.0
	while race.state == "countdown":
		if press_at >= 0.0 and race.countdown <= press_at:
			Input.action_press("p1_accelerate")
		race.step(dt)
	race.step(dt)
	var p = race.player
	var res := "%s|%s|%s" % [p.start_result, p.boost_time > 0.0, p.start_stall > 0.0]
	Input.action_release("p1_accelerate")
	var beeps: int = race.sfx_log.count("beep")
	var went: bool = race.sfx_log.has("go")
	race.queue_free()
	await process_frame
	return res + "|%d|%s" % [beeps, went]


func _test_start() -> void:
	print("CA-11 largada turbo")
	var r: String = await _run_start(1.2)
	check(r.begins_with("turbo|true|false"), "acelerar a 1.2 s do VAI dá turbo (%s)" % r)
	check(r.ends_with("|3|true"), "3 bipes + som do VAI")
	r = await _run_start(3.0)
	check(r.begins_with("queimou|false|true"), "acelerar desde o início queima (%s)" % r)
	r = await _run_start(-1.0)
	check(r.begins_with("|false|false"), "sem acelerar, largada normal (%s)" % r)


func _test_pause() -> void:
	print("CA-12 pause")
	var race = await _new_race(["telles"], true)
	var dt := 1.0 / 60.0
	for i in 60 * 6:
		race.step(dt)
	race.toggle_pause()
	var t0: float = race.race_time
	var p0: Vector3 = race.karts[0].position
	for i in 120:
		race.step(dt)
	check(race.paused and race.race_time == t0 and race.karts[0].position == p0, "pausado: tempo e karts parados")
	race.toggle_pause()
	for i in 60:
		race.step(dt)
	check(not race.paused and race.race_time > t0, "despausou: corrida continua")
	race.queue_free()
	await process_frame


func _test_intro() -> void:
	print("CA-13 tela de abertura")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/intro.tscn", "intro é a cena principal")
	var intro = load("res://scenes/intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	var tex: Texture2D = intro.art.texture
	check(tex != null and tex.get_width() >= 1280, "arte da abertura carregada (%s)" % (str(tex.get_size()) if tex else "null"))
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	intro._unhandled_input(ev)
	check(intro.leaving, "tecla leva pro menu")
	await process_frame
	await process_frame
	var cur := current_scene
	check(cur != null and cur.scene_file_path == "res://scenes/menu.tscn", "menu carregado depois da abertura")
	if cur:
		cur.queue_free()
	await process_frame


func _test_faces() -> void:
	print("CA-14 caras só no mapa/HUD")
	var race = await _new_race(["fejaum"], true)
	var textured := 0
	for k in race.karts:
		for n in k.find_children("*", "MeshInstance3D", true, false):
			var m = n.material_override
			if m is StandardMaterial3D and m.albedo_texture != null:
				textured += 1
	check(textured == 0, "nenhum kart com a arte do rosto (%d)" % textured)
	for i in 120:
		race.step(1.0 / 60.0)
	var hud = race.huds[0]
	hud.update_hud(1.0 / 60.0)
	var order: Array = race.ranking()
	var names_ok: bool = hud.rank_rows.size() == 8
	for i in mini(8, hud.rank_rows.size()):
		if hud.rank_rows[i]["name"].text != order[i].display_name or hud.rank_rows[i]["head"].texture == null:
			names_ok = false
	check(names_ok, "HUD lista os 8 pilotos com busto, na ordem do ranking")
	hud.minimap.queue_redraw()
	await process_frame
	await process_frame
	check(hud.minimap.heads_drawn == 8, "minimapa desenha 8 bustos (%d)" % hud.minimap.heads_drawn)
	race.queue_free()
	await process_frame


func _test_all_tracks() -> void:
	print("CA-15 corrida de 1 volta em cada pista")
	var Track = load("res://scripts/track.gd")
	for td in Track.TRACKS:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.player_chars = ["nanni"]
		race.track_id = td["id"]
		race.laps = 1
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		var t := 0.0
		while t < 150.0 and not race.all_finished():
			race.step(1.0 / 60.0)
			t += 1.0 / 60.0
		var max_lat := 0.0
		for k in race.karts:
			max_lat = maxf(max_lat, k.max_abs_lateral)
		check(race.track.def["id"] == td["id"] and race.all_finished(), "%s: 8 terminaram em %.1f s" % [td["name"], t])
		check(max_lat <= Track.WALL + 0.5, "%s: ninguém atravessou o muro (%.2f)" % [td["name"], max_lat])
		race.queue_free()
		await process_frame


## Coloca o kart k na amostra idx/lateral, andando reto a `spd`.
func _put(k, idx: int, lat: float, spd: float) -> void:
	k.place(idx, lat)
	k.speed = spd
	k.vel = k.forward() * spd
	k.boost_time = 0.0


func _test_v08() -> void:
	var dt := 1.0 / 60.0
	var race = await _new_race(["telles"], true)
	race.state = "racing"
	race.countdown = 0.0
	var tr = race.track
	var n: int = tr.sample_count()
	var a = race.karts[0]
	var b = race.karts[1]
	# afasta todo mundo pra não interferir
	for i in race.karts.size():
		_put(race.karts[i], (i * 60) % n, 0.0, 0.0)

	print("CA-16 seta de turbo")
	var pad: Dictionary = tr.pads[0]
	_put(a, wrapi(int(pad["idx"]) - 3, 0, n), float(pad["lat"]), 20.0)
	a.ai_lane = float(pad["lat"])
	var got_pad := false
	for i in 30:
		a.step(dt, true)
		if a.boost_time > 0.0:
			got_pad = true
	check(got_pad, "passou na seta e ganhou turbo")

	print("CA-17 rampa e manobra")
	_put(a, wrapi(tr.ramp_idx - 4, 0, n), 0.0, 26.0)
	a.ai_lane = 0.0
	a.ai_trick_chance = 1.0
	a.max_height = 0.0
	var landed_with_boost := false
	var was_air := false
	for i in 180:
		a.step(dt, true)
		if a.airborne:
			was_air = true
		elif was_air and not landed_with_boost:
			landed_with_boost = a.boost_time > 0.0
			break
	check(was_air and a.max_height > 1.0, "decolou (altura máx %.2f m)" % a.max_height)
	check(not a.airborne and a.position.y == 0.0, "voltou ao chão")
	check(landed_with_boost, "manobra no ar deu turbo no pouso")

	print("CA-18 vácuo")
	var si := int(n * 0.0) + 5
	_put(a, si + 4, 0.0, 25.0)   # na frente
	_put(b, si, 0.0, 25.0)       # 8 m atrás, alinhado
	var slip := false
	var t := 0.0
	while t < 2.0:
		race._update_slipstream(dt)
		if b.boost_time > 0.0:
			slip = true
			break
		t += dt
	check(slip, "atrás e alinhado: turbo de vácuo em %.2f s" % t)
	_put(b, si + 4, 6.0, 25.0)   # do lado
	b.slip_time = 0.0
	var side_slip := false
	for i in 150:
		race._update_slipstream(dt)
		if b.boost_time > 0.0:
			side_slip = true
	check(not side_slip, "do lado: sem vácuo")

	print("CA-19 queijinhos")
	a.cheese = 0
	var top0: float = a.top_speed()
	var c0: Dictionary = race.cheeses[0]
	c0["cd"] = 0.0
	a.position = c0["pos"] - Vector3.UP * 0.7
	race._update_cheese(dt)
	check(a.cheese == 1 and a.top_speed() > top0, "pegou 1 queijo e ficou mais rápido")
	a.cheese = 10
	var c1: Dictionary = race.cheeses[1]
	c1["cd"] = 0.0
	a.position = c1["pos"] - Vector3.UP * 0.7
	race._update_cheese(dt)
	check(a.cheese == 10, "máximo de 10")
	a.spin_time = 0.0
	a.hit()
	check(a.cheese == 7, "casca tira 3 (%d)" % a.cheese)

	print("CA-21 roleta")
	a.spin_time = 0.0
	a.item = ""
	a.give_item("turbo")
	check(not a.can_use_item(), "item recém-pego bloqueado")
	for i in 70:
		a.item_roll -= dt
	check(a.can_use_item(), "liberado depois de 1 s")

	print("CA-22 drift nível 3")
	_put(a, 20, 0.0, 22.0)
	a.drifting = true
	a.drift_dir = 1.0
	a.drift_charge = 2.5
	a.in_drift = false
	a._move(dt)
	check(not a.drifting and a.boost_time >= 1.5, "turbo roxo %.2f s" % a.boost_time)
	race.queue_free()
	await process_frame

	print("CA-20 dificuldade")
	var ranges := []
	for d in 3:
		var r = load("res://scripts/race.gd").new()
		r.use_game_settings = false
		r.autopilot_player = true
		r.player_chars = ["telles"]
		r.difficulty = d
		root.add_child(r)
		if r.karts.is_empty():
			await process_frame
		var lo := INF
		var hi := -INF
		for k in r.karts:
			if not k.is_player:
				lo = minf(lo, k.ai_skill)
				hi = maxf(hi, k.ai_skill)
		var sk: Array = r.DIFFICULTY[d]["skill"]
		ranges.append(lo >= sk[0] - 0.0001 and hi <= sk[1] + 0.0001)
		r.queue_free()
		await process_frame
	check(ranges == [true, true, true], "habilidade da IA dentro da faixa em fácil/normal/difícil")


func _test_graphics() -> void:
	var Gfx = load("res://scripts/gfx.gd")
	var Track = load("res://scripts/track.gd")
	print("CA-23 qualidade gráfica")
	var d: Dictionary = Track.TRACKS[0]
	var hi: Environment = Gfx.environment(d, 2)
	var lo: Environment = Gfx.environment(d, 0)
	check(hi.glow_enabled and hi.ssao_enabled, "ALTO: glow e SSAO ligados")
	check(not lo.glow_enabled and not lo.ssao_enabled, "BAIXO: glow e SSAO desligados")
	var game = root.get_node_or_null("Game")
	if game:
		game.graphics_high = false
		var r_lo = await _new_race(["telles"], true)
		check(r_lo.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "BAIXO: MSAA desligado")
		r_lo.queue_free()
		await process_frame
		game.graphics_high = true

	print("CA-24 partículas")
	var race = await _new_race(["telles"], true)
	var k = race.karts[0]
	check(k.sparks.size() == 2 and k.p_flame != null and k.p_dust != null and k.p_confetti != null, "kart tem emissores")
	race.state = "racing"
	k.drifting = true
	k.drift_charge = 1.0
	k.boost_time = 1.0
	k.lateral = 12.0
	k.speed = 20.0
	k._update_visuals(1.0 / 60.0)
	check(k.sparks[0].emitting and k.p_flame.emitting and k.p_dust.emitting, "drift → faíscas, turbo → fogo, grama → poeira")

	print("CA-25 texturas e cenário")
	var tm: StandardMaterial3D = race.track.get_node("TrackMesh").material_override
	var gm: StandardMaterial3D = race.track.get_node("Ground").material_override
	check(tm.albedo_texture != null and tm.normal_texture != null and tm.uv1_triplanar, "pista com granulado + relevo triplanar")
	check(gm.albedo_texture != null, "chão com textura")
	check(race.track.get_node_or_null("Grandstand") != null and race.track.scenery_count > 100, "arquibancada + cenário (%d instâncias)" % race.track.scenery_count)
	race.queue_free()
	await process_frame


func _has_part(n: Node, part: String) -> bool:
	return n.find_child(part, true, false) != null


func _test_assets() -> void:
	var race = await _new_race(["burcca"], true)
	print("CA-26 kart do Kenney")
	var ok := true
	for k in race.karts:
		var kk = k.model.get_node_or_null("KenneyKart")
		var ch = kk.find_child("character", true, false) if kk else null
		if kk == null or ch == null or ch.visible or k.wheels.size() != 4 or k.front_wheels.size() != 2 or k.kart_body == null:
			ok = false
	check(ok, "8 karts com GLB do Car Kit, piloto original escondido, 4 rodas (2 dianteiras)")
	var sm = race.karts[0].kart_body.material_override
	check(sm is ShaderMaterial and sm.get_shader_parameter("tint") == race.karts[0].color, "carroceria recolorida na cor do piloto")

	print("CA-27 visual de cada amigo")
	var Chars = load("res://scripts/characters.gd")
	var looks_ok := true
	for c in Chars.LIST:
		var lk: Dictionary = c.get("look", {})
		for key in ["fur", "hair", "hair_color", "beard", "glasses", "shirt"]:
			if not lk.has(key):
				looks_ok = false
	check(looks_ok, "8 pilotos com look completo")
	var by_id := {}
	for k in race.karts:
		by_id[k.char_id] = k.driver
	var b = by_id["burcca"]
	var t = by_id["telles"]
	check(_has_part(b, "Glasses") and _has_part(b, "Beard") and _has_part(b, "Headphones"), "Burcca: óculos + barba + fone")
	check(_has_part(t, "Glasses") and _has_part(t, "Beard") and not _has_part(t, "Headphones"), "Telles: óculos escuros + cavanhaque, sem fone")
	check(not _has_part(by_id["mugurin"], "Glasses") and not _has_part(by_id["digao"], "Glasses"), "Mugurin e Digão sem óculos")

	print("CA-28 itens e cenário do Kenney")
	check(race.cheeses.size() > 0 and race.cheeses[0]["node"].name == "cheese", "queijinhos com o queijo do Food Kit")
	var k0 = race.karts[0]
	race._spawn_hazard("casca", k0.position, Vector3.ZERO, 5.0, k0)
	check(race.hazards[-1]["node"].name == "banana", "casca é a banana do Food Kit")
	var tr = race.track
	check(tr.get_node_or_null("StartGantry") != null, "pórtico de largada do Racing Kit")
	var props := 0
	for c in tr.get_children():
		if c.name.begins_with("pits") or c.name.begins_with("tent") or c.name.begins_with("banner") or c.name.begins_with("billboard"):
			props += 1
	check(props >= 4, "props do Racing Kit no cenário (%d)" % props)
	var tank := 0
	var zaw := 0
	for mi in tr.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m = mi.get_active_material(s)
			if m and m.resource_name.to_lower().contains("tankco"):
				tank += 1
			if m and m.resource_name == "zawsze":
				zaw += 1
	check(tank == 0 and zaw > 0, "marca ZAWSZE no lugar de TANKCO (%d banners)" % zaw)
	race.queue_free()
	await process_frame

	print("CA-29 fonte e tema")
	var Game = load("res://scripts/game.gd")
	var th: Theme = Game.build_theme()
	var f: Font = th.default_font
	check(f != null and f.resource_path.ends_with("Kenney Future Narrow.ttf"), "tema usa Kenney Future Narrow")
	var need := "Car Mundon'GO Digão CONTRAMÃO VÁCUO 1º/8 Começar · ç ã õ é í ó ú"
	var missing := ""
	for ch in need:
		if ch != " " and not f.has_char(ch.unicode_at(0)):
			missing += ch
	check(missing == "", "fonte tem todos os caracteres do jogo%s" % ("" if missing == "" else " (faltam: %s)" % missing))


func _test_settings() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		check(false, "autoload Game presente")
		return
	print("CA-30 salvar/carregar configurações")
	game.reset_settings()
	game.settings["vol_music"] = 0.35
	game.settings["fov"] = 80.0
	game.settings["show_names"] = false
	game.settings["speed_unit"] = "mph"
	game.save_settings()
	game.settings = game.DEFAULTS.duplicate()
	game.load_settings()
	check(is_equal_approx(game.settings["vol_music"], 0.35) and game.settings["fov"] == 80.0 and game.settings["show_names"] == false and game.settings["speed_unit"] == "mph", "valores voltam iguais do arquivo")
	var cfg := ConfigFile.new()
	cfg.load(game.settings_path)
	cfg.erase_section_key("settings", "quality")
	cfg.save(game.settings_path)
	game.load_settings()
	check(game.settings["quality"] == game.DEFAULTS["quality"], "chave faltando usa o padrão")

	print("CA-31 volumes nos buses")
	game.set_setting("vol_sfx", 0.5)
	game.set_setting("vol_engine", 0.0)
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	var eng_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Engine"))
	check(absf(sfx_db - linear_to_db(0.5)) < 0.1 and eng_db <= -79.0, "SFX %.1f dB, Engine %.1f dB (silêncio)" % [sfx_db, eng_db])

	print("CA-32 tela de configurações")
	var SM = load("res://scripts/settings_menu.gd")
	var sm = SM.new()
	root.add_child(sm)
	await process_frame
	check(sm.tabs.get_tab_count() == 4, "4 abas (ÁUDIO, VÍDEO, JOGO, CONTROLES)")
	check(sm.controls.size() >= 15, "%d opções configuráveis" % sm.controls.size())
	sm.controls["vol_master"]["node"].value = 0.2
	check(is_equal_approx(game.settings["vol_master"], 0.2), "mexer no slider muda a configuração")
	sm._reset()
	check(game.settings == game.DEFAULTS and is_equal_approx(sm.controls["vol_master"]["node"].value, game.DEFAULTS["vol_master"]), "PADRÃO restaura tudo (e a tela)")
	sm.close()
	await process_frame

	print("CA-33 configurações na corrida")
	var race = await _new_race(["nanni"], true)
	game.set_setting("show_names", false)
	game.set_setting("show_minimap", false)
	game.set_setting("show_ranking", false)
	game.set_setting("fov", 64.0)
	race.apply_settings()
	var names_off := true
	for k in race.karts:
		if k.name_label.visible:
			names_off = false
	check(names_off and not race.huds[0].minimap.visible and not race.huds[0].ranking_box.visible, "nomes, minimapa e lista escondidos")
	check(race.base_fov == 64.0, "campo de visão base = 64°")
	game.reset_settings()
	race.apply_settings()
	check(race.karts[0].name_label.visible and race.huds[0].minimap.visible, "voltam ao ligar de novo")
	race.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))


## Regressão: com 1 jogador a contagem ficava num canto (label não esticava pra tela toda).
func _test_hud_layout() -> void:
	print("CA-34 contagem no centro da tela")
	for chars in [["telles"], ["telles", "nanni"]]:
		var race = await _new_race(chars, true)
		for i in 3:
			await process_frame
		race.step(1.0 / 60.0)
		var h = race.huds[0]
		var c: Vector2 = h.lbl_center.position + h.lbl_center.size * 0.5
		var mid: Vector2 = h.root.size * 0.5
		check(h.lbl_center.text == "3" and c.distance_to(mid) < 2.0 and h.lbl_center.size.x >= h.root.size.x - 2.0, "%d jogador(es): '3' centralizado (%s vs %s)" % [chars.size(), c, mid])
		race.queue_free()
		await process_frame


func _test_gp() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	print("CA-35 pontuação do Grand Prix")
	game.start_gp()
	var ids := []
	for c in load("res://scripts/characters.gd").LIST:
		ids.append(c["id"])
	var got: Dictionary = game.gp_award(ids)
	var sum := 0
	for v in got.values():
		sum += v
	check(sum == 58 and got[ids[0]] == 15 and got[ids[7]] == 1, "uma corrida distribui 58 pontos (15..1)")
	check(game.gp_award(ids).is_empty(), "mesma corrida não pontua duas vezes")
	# desempate: empata em pontos, decide por vitórias / última corrida
	game.start_gp()
	game.gp_points = {"a": 20, "b": 20, "c": 20, "d": 5}
	game.gp_wins = {"a": 0, "b": 1, "c": 0, "d": 0}
	game.gp_last_pos = {"a": 5, "b": 3, "c": 2, "d": 1}
	check(game.gp_standings() == ["b", "c", "a", "d"], "classificação: pontos → vitórias → última corrida (%s)" % str(game.gp_standings()))

	print("CA-36 Grand Prix completo simulado")
	game.start_gp()
	game.laps = 1
	var tracks_seen := []
	for r in 3:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.player_chars = ["shinando"]
		race.track_id = game.track_id
		race.laps = 1
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		tracks_seen.append(race.track.def["id"])
		var t := 0.0
		while t < 200.0 and not race.results_shown:
			race.step(1.0 / 60.0)
			t += 1.0 / 60.0
		race._award_gp()  # chamar de novo não pode pontuar 2x
		race.queue_free()
		await process_frame
		if r < 2:
			check(game.gp_next(), "avança pra corrida %d" % (r + 2))
	var total := 0
	for v in game.gp_points.values():
		total += v
	check(tracks_seen == game.gp_tracks(), "pistas na ordem %s" % str(tracks_seen))
	check(total == 174, "174 pontos distribuídos em 3 corridas (%d)" % total)
	check(game.gp_is_over() and not game.gp_next(), "GP termina depois da 3ª corrida")

	print("CA-37 tela final do Grand Prix")
	var fin = load("res://scenes/gp_final.tscn").instantiate()
	root.add_child(fin)
	await process_frame
	var st: Array = game.gp_standings()
	check(fin.podium_ids.size() == 3 and fin.podium_ids.has(st[0]) and fin.podium_ids.has(st[1]) and fin.podium_ids.has(st[2]), "pódio com os 3 líderes (%s)" % str(st.slice(0, 3)))
	fin.queue_free()
	game.mode = "race"
	game.laps = 3
	await process_frame


func _test_new_items() -> void:
	print("CA-38 itens novos")
	var dt := 1.0 / 60.0
	var race = await _new_race(["telles"], true)
	race.state = "racing"
	var n: int = race.track.sample_count()
	for i in race.karts.size():
		_put(race.karts[i], (i * 70 + 10) % n, 0.0, 0.0)
	var a = race.karts[0]
	var b = race.karts[1]
	# gato: b na frente (líder), a solta o gato
	_put(a, 20, 0.0, 0.0)
	_put(b, 80, 0.0, 0.0)
	a.progress = 20.0
	b.progress = 500.0
	race._update_ranks()
	race.use_item(a, "gato")
	check(race.gato_active() and race.hazards[-1]["target"] == b, "gato mira no líder")
	var hit := false
	for i in 300:
		race._update_hazards(dt)
		if b.spin_time > 0.0:
			hit = true
			break
	check(hit and not race.gato_active() and b.spin_time > 1.3, "gato alcança e derruba o líder (rodada %.2f s)" % b.spin_time)
	# sorteio: nunca gato pros 4 primeiros nem com gato ativo
	var bad := 0
	for i in 400:
		if race._roll_item(1 + i % 4) == "gato":
			bad += 1
	race.use_item(a, "gato")
	for i in 400:
		if race._roll_item(8) == "gato":
			bad += 1
	check(bad == 0, "sem gato pros 4 primeiros nem gato duplicado")
	for h in race.hazards.duplicate():
		h["node"].queue_free()
	race.hazards.clear()
	# ratoeira
	b.spin_time = 0.0
	_put(b, 120, 0.0, 20.0)
	b.cheese = 5
	b.trap()
	var stuck := true
	for i in 60:
		b._move(dt)
		if b.speed > 0.01:
			stuck = false
	check(stuck and b.cheese == 2, "ratoeira prende (velocidade 0 por 1 s) e tira 3 queijos")
	for i in 20:
		b.in_throttle = 1.0
		b._move(dt)
	check(b.trap_time <= 0.0 and b.speed > 0.0, "solta depois de 1.2 s")
	# escudo
	b.shield_time = 8.0
	b.spin_time = 0.0
	b.hit()
	check(b.spin_time == 0.0 and b.shield_time == 0.0, "escudo absorve o ataque e some")
	b.hit()
	check(b.spin_time > 0.0, "sem escudo, o ataque pega")
	# triplo
	b.spin_time = 0.0
	b.give_item("triplo")
	b.item_roll = 0.0
	var uses := 0
	for i in 3:
		b.in_item = true
		if b.can_use_item():
			race.use_item(b, b.item)
			b.item_charges -= 1
			if b.item_charges <= 0:
				b.item = ""
			uses += 1
	check(uses == 3 and b.item == "", "queijo triplo dá 3 turbos e acaba")
	race.queue_free()
	await process_frame


## Corre o kart `k` em linha reta até passar da casca; devolve se bateu.
func _run_at_banana(race, k, avoid: float) -> bool:
	var dt := 1.0 / 60.0
	for h in race.hazards.duplicate():
		h["node"].queue_free()
	race.hazards.clear()
	var tr = race.track
	var i0 := 30
	# o trecho mais reto da pista (o teste não pode depender do traçado)
	var best_c := INF
	for cand in range(10, tr.sample_count() - 40, 3):
		var c: float = tr.curvature_at(cand) + tr.curvature_at(cand + 18)
		if c < best_c:
			best_c = c
			i0 = cand
	_put(k, i0, 0.0, 24.0)
	k.ai_lane = 0.0
	k.ai_lane_timer = 99.0
	k.ai_avoid = avoid
	k.ai_seen.clear()
	k.spin_time = 0.0
	k.item = "x"  # não desvia pra caixa
	race._spawn_hazard("casca", tr.points[i0 + 18], Vector3.ZERO, 30.0, race.karts[1])
	for i in 150:
		k.step(dt, true)
		race._update_hazards(dt)
		if k.spin_time > 0.0:
			return true
	return false


func _test_smart_ai() -> void:
	print("CA-39 IA desvia de casca")
	var race = await _new_race(["telles"], true)
	race.track.pits.clear()  # só casca aqui (os buracos do Queijo têm teste próprio, CA-92)
	race.state = "racing"
	var n: int = race.track.sample_count()
	for i in race.karts.size():
		_put(race.karts[i], (i * 45 + 200) % n, 0.0, 0.0)  # longe do trecho do teste (amostras 200..515)
	var k = race.karts[0]
	seed(20261118)  # determinístico: com cuidado 0 a IA ainda reage 25% das vezes
	var dodged := 0
	var hit_without := 0
	for trial in 5:
		if not _run_at_banana(race, k, 1.0):
			dodged += 1
		if _run_at_banana(race, k, 0.0):
			hit_without += 1
	check(dodged >= 4, "cuidado máximo: desviou %d/5" % dodged)
	check(hit_without >= 3, "cuidado zero: bateu %d/5 (o desvio vem da IA)" % hit_without)
	for h in race.hazards.duplicate():
		h["node"].queue_free()
	race.hazards.clear()

	print("CA-40 caixas e ultrapassagem")
	var b0: Dictionary = race.boxes[0]
	for b in race.boxes:
		b["cd"] = 99.0
	b0["cd"] = 0.0
	_put(k, wrapi(int(b0["idx"]) - 15, 0, n), -float(b0["lat"]), 20.0)
	k.item = ""
	k.ai_box_skip = false
	k.ai_lane = -float(b0["lat"])
	k._ai_tactics(n, 5.5)
	check(absf(k.ai_lane - clampf(b0["lat"], -5.5, 5.5)) < 0.01, "sem item, mira na caixa (faixa %.1f → %.1f)" % [-float(b0["lat"]), k.ai_lane])
	for b in race.boxes:
		b["cd"] = 99.0
	var slow = race.karts[1]
	_put(k, 100, 2.0, 25.0)
	_put(slow, 103, 2.0, 12.0)
	k.ai_lane = 2.0
	k.item = "x"
	k._ai_tactics(n, 5.5)
	check(absf(k.ai_lane - 2.0) > 3.0, "kart lento na frente: abre pra ultrapassar (faixa 2.0 → %.1f)" % k.ai_lane)
	race.queue_free()
	await process_frame

	print("CA-41 personalidades")
	var Chars = load("res://scripts/characters.gd")
	var sigs := {}
	var ok := true
	for c in Chars.LIST:
		var ai: Dictionary = c.get("ai", {})
		for key in ["aggro", "avoid", "focus", "drift"]:
			if not ai.has(key):
				ok = false
		sigs[str(ai)] = true
	check(ok and sigs.size() == 8, "8 personalidades completas e diferentes")


func _test_music() -> void:
	print("CA-42 música por pista e torcida")
	var Sfx = load("res://scripts/sfx.gd")
	var Track = load("res://scripts/track.gd")
	var sigs := {}
	var ok := true
	for style in ["menu", "queijo", "deserto", "cozinha", "churrasco", "fabrica", "parquinho", "geladeira", "telhados", "feira", "victory"]:
		var t0 := Time.get_ticks_msec()
		var w: AudioStream = Sfx.music(style)
		var secs: float = w.get_length()
		print("     %-8s %.1f s de música (%s), %d ms" % [style, secs, w.resource_name.get_file(), Time.get_ticks_msec() - t0])
		var looped: bool = w.loop if "loop" in w else (w is AudioStreamWAV and w.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if not looped or secs < 8.0:
			ok = false
		sigs[w.resource_name] = true
	check(ok and sigs.size() == 11, "11 trilhas em loop, > 8 s e diferentes entre si")
	var tracks_ok := true
	for td in Track.TRACKS:
		if not Sfx.MUSIC_STYLES.has(td.get("music", td["id"])):
			tracks_ok = false
	check(tracks_ok, "cada pista tem a sua trilha")
	var game = root.get_node_or_null("Game")
	if game:
		game.play_music("deserto")
		var s1 = game.music.stream
		var pos_before: float = game.music.get_playback_position()
		game.play_music("deserto")
		check(game.music.stream == s1 and game.current_music == "deserto", "mesmo estilo não reinicia")
		game.play_music("menu")
		check(game.music.stream != s1 and game.current_music == "menu", "estilo novo troca a trilha")
	var crowd: AudioStream = Sfx.get_sound("crowd")
	check(crowd != null and crowd.get_length() > 1.0, "torcida existe (%.1f s)" % crowd.get_length())


func _tt_race(laps: int) -> Node:
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.time_trial = true
	race.player_chars = ["burcca", "telles"]  # o 2º tem que ser ignorado
	race.track_id = "queijo"
	race.laps = laps
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	return race


func _test_time_trial() -> void:
	var Records = load("res://scripts/records.gd")
	Records.path = "user://test_records.cfg"
	Records.clear_all()

	print("CA-43 recordes")
	var g1 := PackedFloat32Array([1, 2, 3, 0.5, 4, 5, 6, 0.7])
	var got: Dictionary = Records.submit("pista_x", "nanni", 61.5, 20.25, g1)
	check(got["race"] and got["lap"], "primeiro tempo vira recorde de corrida e de volta")
	var rec: Dictionary = Records.get_record("pista_x")
	check(is_equal_approx(rec["race_time"], 61.5) and is_equal_approx(rec["lap_time"], 20.25) and rec["race_char"] == "nanni" and rec["ghost"] == g1, "ler devolve os mesmos tempos, piloto e fantasma")
	got = Records.submit("pista_x", "ortiz", 62.0, 21.0, PackedFloat32Array())
	check(not got["race"] and not got["lap"] and Records.get_record("pista_x")["race_char"] == "nanni", "tempo pior não substitui")
	got = Records.submit("pista_x", "ortiz", 63.0, 19.0, PackedFloat32Array())
	rec = Records.get_record("pista_x")
	check(not got["race"] and got["lap"] and rec["lap_char"] == "ortiz" and rec["race_char"] == "nanni" and rec["ghost"] == g1, "só a melhor volta muda quando só ela é melhor")
	var s: Dictionary = Records.ghost_sample(g1, 0.05)
	check(s["pos"].is_equal_approx(Vector3(2.5, 3.5, 4.5)), "fantasma interpola entre quadros")
	Records.clear_all()

	print("CA-44 corrida contra o relógio")
	var race = await _tt_race(2)
	check(race.karts.size() == 1 and race.players.size() == 1, "1 kart só (%d)" % race.karts.size())
	check(race.boxes.is_empty(), "nenhuma caixa de item")
	check(not race.cheeses.is_empty(), "queijinhos continuam")
	check(race.tt_ghost == null, "sem recorde = sem fantasma")
	var dt := 1.0 / 60.0
	while race.state == "countdown":
		race.step(dt)
	check(race.player.item == "triplo" or race.player.items_used > 0, "Queijo Triplo no VAI! (item=%s)" % race.player.item)
	var marks := {}  # race_time (quadro) -> posição real, pra comparar com o fantasma
	var t := 0.0
	while t < 300.0 and not race.results_shown:
		race.step(dt)
		t += dt
		var f := int(round(race.race_time / dt))
		if f % 90 == 0 and not race.player.finished:
			marks[f] = race.player.position
	check(race.results_shown and race.tt_submitted, "terminou e mostrou o resultado")
	check(race.tt_laps.size() == 2, "2 voltas registradas (%s)" % str(race.tt_laps))
	var sum := 0.0
	for l in race.tt_laps:
		sum += l
	check(absf(sum - race.player.finish_time) < 0.05, "voltas somam o tempo total (%.2f / %.2f)" % [sum, race.player.finish_time])
	rec = Records.get_record("queijo")
	check(race.tt_result.get("race", false) and is_equal_approx(rec.get("race_time", 0.0), race.player.finish_time) and rec.get("race_char") == "burcca", "recorde gravado (%s)" % str(rec.get("race_time")))
	check(is_equal_approx(rec.get("lap_time", 0.0), race.tt_best_lap()), "melhor volta gravada")
	var frames: int = rec.get("ghost", PackedFloat32Array()).size() / 4
	check(absf(frames * Records.GHOST_STEP - race.player.finish_time) < 0.25, "fantasma cobre a corrida (%d quadros)" % frames)
	race.queue_free()
	await process_frame

	print("CA-45 fantasma na tentativa seguinte")
	race = await _tt_race(2)
	check(race.tt_ghost != null and not race.karts.has(race.tt_ghost), "fantasma existe e não é um kart da corrida")
	while race.state == "countdown":
		race.step(dt)
	var worst := 0.0
	var checked := 0
	t = 0.0
	while t < 300.0 and not race.results_shown:
		race.step(dt)
		t += dt
		var f := int(round(race.race_time / dt))
		if marks.has(f) and race.tt_ghost.visible:
			worst = maxf(worst, race.tt_ghost.position.distance_to(marks[f]))
			checked += 1
	check(checked > 10 and worst < 1.0, "fantasma passa nos mesmos pontos (%d pontos, erro máx %.2f m)" % [checked, worst])
	race.queue_free()
	Records.clear_all()
	Records.path = Records.DEFAULT_PATH
	await process_frame


func _pad(button: int) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	e.device = 0
	return e


func _key(code: int) -> InputEvent:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _new_menu() -> Node:
	var menu = load("res://scenes/menu.tscn").instantiate()
	menu.start_scene = false
	root.add_child(menu)
	await process_frame
	return menu


func _test_ui_nav() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	game.mode = "race"
	game.num_players = 1
	game.laps = 3
	game.track_id = "queijo"
	game.difficulty = 1
	print("CA-46 menu em etapas só com controle")
	check(_pad(JOY_BUTTON_A).is_action_pressed("ui_accept") and _pad(JOY_BUTTON_B).is_action_pressed("ui_cancel"), "A = ui_accept e B = ui_cancel (botões focados funcionam no controle)")
	var menu = await _new_menu()
	var up := JOY_BUTTON_DPAD_UP
	var down := JOY_BUTTON_DPAD_DOWN
	var right := JOY_BUTTON_DPAD_RIGHT
	var left := JOY_BUTTON_DPAD_LEFT
	var a := JOY_BUTTON_A
	check(menu.step == menu.STEP_MODE and menu.get_viewport().gui_get_focus_owner() == menu.mode_cards[0], "começa na etapa MODO com foco no cartão")
	menu._input(_pad(right))
	menu._input(_pad(right))
	check(menu.MODE_IDS[menu.mode_i] == "tt", "→→ escolhe CONTRA O RELÓGIO")
	menu._input(_pad(down))
	check(menu.nav_r == 2 and menu.player_btns[1].disabled, "↓ vai pros jogadores (só 1 no contra o relógio)")
	menu._input(_pad(up))
	menu._input(_pad(left))
	menu._input(_pad(down))
	menu._input(_pad(right))
	menu._input(_pad(a))
	check(menu.MODE_IDS[menu.mode_i] == "gp" and menu.num_players == 2, "GRAND PRIX com 2 jogadores")
	menu._input(_pad(up))
	menu._input(_pad(up))
	menu._input(_pad(right))
	menu._input(_pad(a))
	check(menu.settings_overlay != null, "↑ até a barra de cima e A em CONFIGURAÇÕES abre")
	if menu.settings_overlay:
		menu.settings_overlay._unhandled_input(_pad(JOY_BUTTON_B))
	await process_frame
	check(menu.settings_overlay == null, "B fecha as configurações")
	menu._input(_pad(down))
	menu._input(_pad(right))
	menu._input(_pad(right))
	menu._input(_pad(right))  # volta pro GRAND PRIX (3 cartões, dá a volta)
	menu._input(_pad(a))
	check(menu.step == menu.STEP_PILOT, "A no cartão vai pra etapa PILOTO")
	menu._input(_pad(right))
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.picks.size() == 2 and menu.step == menu.STEP_TRACK, "J1 e J2 escolhem e vai pra PISTA")
	check(menu.track_btns[2].visible and not menu.track_btns[3].visible, "no Grand Prix a etapa PISTA mostra as 3 copas")
	menu._input(_pad(a))
	check(menu.step == menu.STEP_SETUP and menu.get_viewport().gui_get_focus_owner() == menu.go_btn, "A na copa vai pra AJUSTES com foco no CORRER!")
	menu._input(_pad(up))
	menu._input(_pad(up))
	var laps0: int = menu.laps_i
	menu._input(_pad(right))
	check(menu.laps_i == (laps0 + 1) % menu.LAP_OPTIONS.size(), "→ em VOLTAS muda o valor")
	menu._input(_pad(down))
	var diff0: int = menu.diff_i
	menu._input(_pad(left))
	check(menu.diff_i != diff0, "← em IA muda a dificuldade")
	menu._input(_pad(down))
	menu._input(_pad(a))
	check(menu.started and game.is_gp() and game.num_players == 2 and game.selected_chars.size() == 2, "A em CORRER! começa o GP com 2 jogadores")
	menu.queue_free()
	await process_frame

	game.mode = "race"
	game.num_players = 1
	menu = await _new_menu()
	menu._input(_pad(a))       # CORRIDA
	menu._input(_pad(a))       # piloto
	menu._input(_pad(down))   # grade 3x3: ↓ pula uma linha (4ª pista)
	menu._input(_pad(right))  # → 5ª pista
	check(menu.TrackScript.TRACKS[menu.track_i]["id"] == "fabrica" and menu.track_map.track_id == "fabrica", "↓ na lista troca a pista e o trajeto")
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.started and game.track_id == "fabrica" and game.mode == "race", "corrida na pista escolhida (%s)" % game.track_id)
	menu.queue_free()
	await process_frame

	print("CA-47 voltar (B)")
	game.mode = "race"
	game.num_players = 2
	menu = await _new_menu()
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.picks.size() == 1, "J1 confirmou")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.picks.is_empty() and menu.step == menu.STEP_PILOT, "B desfaz o piloto")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.step == menu.STEP_MODE, "B sem piloto escolhido volta pra MODO")
	menu._input(_pad(a))
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.step == menu.STEP_TRACK, "de volta na PISTA")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.step == menu.STEP_PILOT and menu.picks.size() == 1, "B na PISTA volta pro PILOTO reabrindo o último")
	menu.queue_free()
	game.num_players = 1
	await process_frame
	var race = await _new_race(["nanni"], true)
	race.toggle_pause()
	race._unhandled_input(_pad(JOY_BUTTON_B))
	check(not race.paused, "B no pause continua a corrida")
	race.queue_free()
	await process_frame

	print("CA-48 dicas por dispositivo")
	game.note_device(_key(KEY_W))
	menu = await _new_menu()
	var kbd_text: String = menu.help.text
	game.note_device(_pad(a))
	check(game.last_device == "pad" and menu.help.text != kbd_text and "A:" in menu.help.text, "controle → dicas de botão")
	game.note_device(_key(KEY_W))
	check(game.last_device == "kbd" and menu.help.text == kbd_text, "tecla → dicas de teclado")
	menu.queue_free()
	await process_frame
	race = await _new_race(["nanni"], true)
	game.note_device(_pad(a))
	check(race.huds[0].lbl_hint.text.begins_with("Analógico"), "dica da corrida muda pro controle")
	game.note_device(_key(KEY_W))
	race.queue_free()
	await process_frame

	print("CA-50 confirmação ao sair do GP")
	game.start_gp()
	game.laps = 1
	race = load("res://scripts/race.gd").new()
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	race.toggle_pause()
	race.menu_from_pause()
	check(race.confirm_box.visible and race.get_viewport().gui_get_focus_owner() == race.confirm_no_btn, "Menu no pause do GP pergunta (foco no NÃO)")
	race._unhandled_input(_pad(JOY_BUTTON_B))
	check(not race.confirm_box.visible and race.paused and game.is_gp(), "B/NÃO fecha e o GP continua")
	var conns: Array = race.confirm_yes_btn.pressed.get_connections()
	check(conns.any(func(c): return c["callable"].get_method() == "to_menu"), "SIM vai pro menu")
	race.queue_free()
	game.mode = "race"
	game.laps = 3
	await process_frame


## CA-49: tudo dentro da área visível em 16:9, 4:3 e 21:9 (tamanho lógico com stretch "expand").
func _all_inside(n: Node, area: Rect2, bad: Array) -> void:
	if n is Control and n.is_visible_in_tree() and (n is Button or n is PanelContainer or n is Label):
		var r: Rect2 = n.get_global_rect()
		if r.size.x > 0.0 and not area.grow(1.0).encloses(r):
			bad.append("%s '%s' %s" % [n.get_class(), (n.text if "text" in n else n.name), r])
	for c in n.get_children():
		_all_inside(c, area, bad)


func _test_layout() -> void:
	print("CA-49 interface dentro da tela")
	var game = root.get_node_or_null("Game")
	for sz in [Vector2(1280, 720), Vector2(1280, 960), Vector2(1707, 720)]:
		var label := "%dx%d" % [sz.x, sz.y]
		for mode in ["race", "gp", "tt"]:
			if game:
				game.mode = mode
			var box := Control.new()
			box.size = sz
			root.add_child(box)
			var menu = load("res://scenes/menu.tscn").instantiate()
			menu.start_scene = false
			box.add_child(menu)
			var bad := []
			for s in 4:  # cada etapa
				menu._go_step(s, false)
				await process_frame
				await process_frame
				_all_inside(menu, Rect2(Vector2.ZERO, sz), bad)
			check(bad.is_empty(), "menu (%s, 4 etapas) em %s %s" % [mode, label, str(bad.slice(0, 3))])
			menu._go_step(menu.STEP_PILOT, false)
			await process_frame
			var heads_ok := true
			for card in menu.cards:
				var cr: Rect2 = card.get_global_rect()
				var hr: Rect2 = card.get_node("Head").get_global_rect()
				var band_top: float = card.get_node("Band").get_global_rect().position.y
				# carta recorta (clip_contents); topo da arte dentro e o corte reto escondido atrás da faixa
				if not card.clip_contents or hr.position.y < cr.position.y or hr.end.y < band_top + 4.0 or hr.end.y > cr.end.y:
					heads_ok = false
			check(heads_ok, "CA-55 arte recortada na carta, corte escondido na faixa (%s, %s)" % [mode, label])
			if mode == "race":
				menu.open_settings()
				await process_frame
				await process_frame
				bad = []
				_all_inside(menu.settings_overlay, Rect2(Vector2.ZERO, sz), bad)
				check(bad.is_empty(), "configurações em %s %s" % [label, str(bad.slice(0, 3))])
			box.queue_free()
			await process_frame
	if game:
		game.mode = "race"
	# resultados (corrida e contra o relógio) e pause na tela real
	var Records = load("res://scripts/records.gd")
	Records.path = "user://test_records.cfg"
	for tt in [false, true]:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.time_trial = tt
		race.player_chars = ["digao"]
		race.laps = 2
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		race.toggle_pause()
		await process_frame
		var area: Rect2 = race.get_viewport().get_visible_rect()
		var bad := []
		if game:
			game.note_device(_pad(JOY_BUTTON_A))
			await process_frame
			_all_inside(race.huds[0].root, area, bad)
			check(bad.is_empty(), "HUD com dicas de controle dentro da tela %s" % str(bad.slice(0, 3)))
			game.note_device(_key(KEY_W))
			bad = []
		_all_inside(race.pause_layer, area, bad)
		check(bad.is_empty(), "pause dentro da tela %s" % str(bad.slice(0, 3)))
		race.toggle_pause()
		while not race.results_shown:
			race.step(1.0 / 60.0)
		await process_frame
		await process_frame
		bad = []
		var res: Control = race.results_hud.results
		var need: Vector2 = res.get_combined_minimum_size()
		if need.x > 1280.0 or need.y > 720.0:
			bad.append("painel precisa de %s" % need)
		_all_inside(res, area, bad)
		check(bad.is_empty(), "resultado %s dentro da tela (%s) %s" % ["contra o relógio" if tt else "da corrida", area.size, str(bad.slice(0, 3))])
		race.queue_free()
		await process_frame
	Records.clear_all()
	Records.path = Records.DEFAULT_PATH


func _keyev(code: int, loc := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.location = loc
	e.pressed = true
	return e


func _test_remap() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	game.reset_settings()
	print("CA-51 trocar tecla")
	var res: Dictionary = game.rebind_key(0, "drift", _keyev(KEY_J))
	check(res["ok"], "J1 drift → J")
	check(_keyev(KEY_J).is_action("p1_drift") and not _keyev(KEY_SPACE).is_action("p1_drift"), "J aciona o drift; Espaço não")
	check(not _keyev(KEY_SHIFT, KEY_LOCATION_LEFT).is_action("p1_drift"), "alternativa (Shift esq.) saiu")
	game.load_settings()
	check(_keyev(KEY_J).is_action("p1_drift") and game.key_label(0, "drift") == "J", "salvo e recarregado (%s)" % game.key_label(0, "drift"))

	print("CA-52 conflito e tecla reservada")
	res = game.rebind_key(0, "accelerate", _keyev(KEY_S))  # S era o frear do J1
	check(res["ok"] and _keyev(KEY_S).is_action("p1_accelerate") and _keyev(KEY_W).is_action("p1_brake"), "W↔S trocaram (%s)" % res["msg"])
	check(res["msg"] != "", "aviso de troca")
	res = game.rebind_key(0, "use_item", _keyev(KEY_UP))  # ↑ é acelerar do J2
	check(_keyev(KEY_UP).is_action("p1_use_item") and _keyev(KEY_E).is_action("p2_accelerate"), "conflito com o outro jogador troca (%s)" % res["msg"])
	res = game.rebind_key(1, "drift", _keyev(KEY_CTRL, KEY_LOCATION_RIGHT))  # Ctrl dir. era alternativa do item do J2
	check(_keyev(KEY_CTRL, KEY_LOCATION_RIGHT).is_action("p2_drift") and _keyev(KEY_ENTER).is_action("p2_use_item") and not _keyev(KEY_CTRL, KEY_LOCATION_RIGHT).is_action("p2_use_item"), "alternativa sai só dela, o resto fica")
	var before: String = game.key_label(0, "steer_left")
	for k in [KEY_ESCAPE, KEY_M, KEY_R]:
		res = game.rebind_key(0, "steer_left", _keyev(k))
		check(not res["ok"] and game.key_label(0, "steer_left") == before, "%s recusada" % OS.get_keycode_string(k))

	print("CA-53 controle e restaurar")
	res = game.rebind_pad("drift", JOY_BUTTON_Y)
	var all_ok := true
	for p in 4:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_Y
		e.device = p
		e.pressed = true
		if not e.is_action("p%d_drift" % (p + 1)):
			all_ok = false
	check(res["ok"] and all_ok, "Y vira drift nos 4 controles")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	game.rebind_pad("accelerate", JOY_BUTTON_X)  # X era alternativa do item
	check(rt.is_action("p1_accelerate") and game.pad_label("use_item") == "LB", "gatilho RT continua; item fica só com LB (%s)" % game.pad_label("use_item"))
	check(not game.rebind_pad("drift", JOY_BUTTON_START)["ok"], "Start recusado")
	game.reset_bindings()
	check(_keyev(KEY_SPACE).is_action("p1_drift") and _keyev(KEY_W).is_action("p1_accelerate") and game.pad_label("drift") == "RB" and game.key_binds.is_empty(), "RESTAURAR volta ao padrão")
	game.load_settings()
	check(_keyev(KEY_SPACE).is_action("p1_drift") and not _keyev(KEY_J).is_action("p1_drift"), "padrão também fica salvo")

	print("CA-54 tela de configurações")
	var sm = load("res://scripts/settings_menu.gd").new()
	root.add_child(sm)
	await process_frame
	sm.start_capture(0, "use_item")
	check(sm.bind_buttons["0:use_item"].text.begins_with("APERTE"), "botão mostra APERTE...")
	sm._input(_keyev(KEY_ESCAPE))
	check(sm.capture.is_empty() and _keyev(KEY_E).is_action("p1_use_item") and is_instance_valid(sm) and sm.is_inside_tree(), "Esc cancela sem mudar e sem fechar a tela")
	sm.start_capture(0, "use_item")
	sm._input(_keyev(KEY_Q))
	check(_keyev(KEY_Q).is_action("p1_use_item") and sm.bind_buttons["0:use_item"].text == "Q", "tecla nova aplicada (%s)" % sm.bind_buttons["0:use_item"].text)
	sm.start_capture(-1, "brake")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_Y
	jb.pressed = true
	sm._input(jb)
	check(game.pad_label("brake").begins_with("Y"), "coluna do controle aceita botão (%s)" % game.pad_label("brake"))
	check(sm.bind_buttons["pad:steer_left"].disabled, "virar no controle não é trocável (analógico)")
	sm.queue_free()
	await process_frame
	var race = await _new_race(["nanni"], true)
	game.note_device(_keyev(KEY_W))
	race.huds[0].refresh_hint()
	check(" Q: item" in race.huds[0].lbl_hint.text, "dica da corrida mostra a tecla nova (%s)" % race.huds[0].lbl_hint.text)
	race.queue_free()
	game.reset_settings()
	await process_frame


func _test_char_select() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	print("CA-56 painel do piloto e confirmação")
	game.mode = "race"
	game.num_players = 2
	var menu = await _new_menu()
	var Chars = load("res://scripts/characters.gd")
	menu._go_step(menu.STEP_PILOT, false)
	menu._select(3)
	await create_timer(0.6).timeout
	var c: Dictionary = Chars.LIST[3]
	check(menu.preview_name.text == c["name"], "painel mostra %s" % c["name"])
	var bars_ok := true
	for k in menu.STATS.size():
		var want: float = menu.BAR_W * int(c[menu.STATS[k][0]]) / 5.0
		if absf(menu.preview_bars[k].size.x - want) > 1.0:
			bars_ok = false
	check(bars_ok, "barras chegam no valor do piloto")
	menu._input(_pad(JOY_BUTTON_A))
	await process_frame
	check(menu.card_tags[3].text == "J1" and menu.picks == [3], "confirmar marca a carta com J1")
	await create_timer(0.6).timeout
	check(menu.card_flash[3].color.a < 0.05 and menu.card_tags[3].scale.is_equal_approx(Vector2.ONE), "brilho e selo terminam a animação")
	menu.queue_free()
	game.num_players = 1
	await process_frame


func _race_on(track_id: String) -> Node:
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = false
	race.player_chars = ["nanni"]
	race.track_id = track_id
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	race.state = "racing"
	race.countdown = 0.0
	return race


## Anda só o kart k por `secs` segundos (sem os outros atrapalharem).
func _drive(k, secs: float) -> void:
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < secs:
		k.step(dt, true)
		t += dt


func _test_new_tracks() -> void:
	print("CA-57 zonas de superfície")
	var race = await _race_on("churrasco")
	var k = race.player
	var fz: Dictionary = {}
	for z in race.track.zones:
		if z["kind"] == "farofa":
			fz = z
			break
	var mid_lat: float = (fz["lat0"] + fz["lat1"]) * 0.5
	Input.action_press("p1_accelerate")
	_put(k, int(fz["i0"]) + 2, mid_lat, 0.0)
	_drive(k, 1.6)
	var on_farofa: float = k.speed
	var kind_seen: String = k.zone_kind
	_put(k, int(fz["i0"]) + 2, -mid_lat, 0.0)  # o outro lado da pista não tem farofa
	_drive(k, 1.6)
	var clean: float = k.speed
	Input.action_release("p1_accelerate")
	check(kind_seen == "farofa" and on_farofa <= k.top_speed() * 0.62 + 0.5 and clean > on_farofa + 2.0, "farofa segura (%.1f m/s na farofa x %.1f fora)" % [on_farofa, clean])
	race.queue_free()
	await process_frame

	race = await _race_on("fabrica")
	k = race.player
	var belt: Dictionary = {}
	var side: Dictionary = {}
	for z in race.track.zones:
		if z["kind"] == "belt":
			belt = z
		elif z["kind"] == "belt_side":
			side = z
	_put(k, int(belt["i0"]) + 2, 0.0, 0.0)
	var p0: Vector3 = k.position
	var i0: int = k.track_idx
	_drive(k, 1.0)
	var moved: float = (k.position - p0).dot(race.track.tangents[i0])
	check(k.zone_kind == "belt" and moved > 7.0, "esteira leva o kart parado pra frente (%.1f m em 1 s)" % moved)
	_put(k, int(side["i0"]) + 3, 0.0, 0.0)
	_drive(k, 0.6)
	check(k.zone_kind == "belt_side" and k.lateral < -2.0, "esteira lateral empurra pro lado (lateral %.1f)" % k.lateral)
	_put(k, int(belt["i0"]) + 2, 0.0, 0.0)
	k.airborne = true
	k.position.y = 4.0
	k.step(1.0 / 60.0, true)
	check(k.zone_kind == "", "no ar a esteira não vale")
	race.queue_free()
	await process_frame

	print("CA-58 perigos da pista")
	race = await _race_on("churrasco")
	k = race.player
	var fh: Dictionary = race.track_hazards[0]
	var fs: Dictionary = fh["spec"]
	var flame: Node3D = fh["flames"][1]
	var dt := 1.0 / 60.0
	# aceso: ajusta o relógio da corrida pro meio da janela de fogo
	race.race_time = race.FLAME_WARN + 0.3 - float(fs["phase"])
	_put(k, int(fs["idx"]), float(fs["lats"][1]), 0.0)
	k.spin_time = 0.0
	race._update_track_hazards(dt, true)
	check(fh["state"] == "on" and k.spin_time > 0.0, "labareda acesa roda o kart")
	race.race_time = race.FLAME_WARN + float(fs["on"]) + 0.3 - float(fs["phase"])
	k.spin_time = 0.0
	race._update_track_hazards(dt, true)
	check(fh["state"] == "off" and k.spin_time == 0.0, "labareda apagada não faz nada")
	race.state = "countdown"
	race.race_time = race.FLAME_WARN + 0.3 - float(fs["phase"])
	race._update_track_hazards(dt, false)
	check(k.spin_time == 0.0 and not flame.visible, "antes do VAI! o fogo não acende")
	race.queue_free()
	await process_frame

	race = await _race_on("fabrica")
	k = race.player
	var wheel: Dictionary = {}
	var press: Dictionary = {}
	for h in race.track_hazards:
		if h["spec"]["kind"] == "wheel" and wheel.is_empty():
			wheel = h
		elif h["spec"]["kind"] == "press" and press.is_empty():
			press = h
	race._update_track_hazards(dt, false)
	var wpos: Vector3 = wheel["node"].position
	k.place(race.track.nearest_index(wpos), race.track.lateral_of(wpos, race.track.nearest_index(wpos)))
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0, "roda de queijo roda quem encosta")
	# prensa: procura no relógio um instante "down" e um "up"
	var ps: Dictionary = press["spec"]
	_put(k, int(ps["idx"]), float(press["mid"]), 0.0)
	var got_down := false
	var got_up := false
	for step_i in 400:
		k.spin_time = 0.0
		race._update_track_hazards(1.0 / 60.0, true)
		if press["state"] == "down" and k.spin_time > 0.0:
			got_down = true
		if press["state"] == "up" and k.spin_time > 0.0:
			got_up = true
	check(got_down and not got_up, "prensa pega embaixo e em cima não")
	race.queue_free()
	await process_frame

	print("CA-59 IA desvia de labareda")
	race = await _race_on("churrasco")
	var ai = race.karts[0]
	fh = race.track_hazards[0]
	fs = fh["spec"]
	race.race_time = 0.1 - float(fs["phase"])  # aviso (brasa)
	race._update_track_hazards(0.0, true)
	_put(ai, int(fs["idx"]) - 14, 0.0, 15.0)
	ai.ai_avoid = 1.0
	ai.ai_lane = 0.0
	ai.ai_lane_timer = 10.0
	ai.ai_seen.clear()
	ai._ai_tactics(race.track.sample_count(), race.track.ROAD_HALF - 2.5)
	check(fh["state"] == "warn" and absf(ai.ai_lane) > 2.8, "IA troca de faixa antes do fogo (faixa %.1f)" % ai.ai_lane)
	race.queue_free()
	await process_frame

	print("CA-60 voltas da IA nas pistas novas")
	for tid in ["churrasco", "fabrica", "parquinho"]:
		race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.player_chars = ["nanni"]
		race.track_id = tid
		race.laps = 2
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		var t := 0.0
		var hits := 0
		while t < 200.0 and not race.all_finished():
			race.step(1.0 / 60.0)
			t += 1.0 / 60.0
		var best := INF
		var worst := 0.0
		for kk in race.karts:
			if kk.finished:
				best = minf(best, kk.finish_time / 2.0)
				worst = maxf(worst, kk.finish_time / 2.0)
		check(race.all_finished() and best > 30.0 and worst < 60.0, "%s: volta da IA %.1f..%.1f s" % [race.track.def["name"], best, worst])
		race.queue_free()
		await process_frame


func _test_drift_feel() -> void:
	print("CA-61 drift arcade")
	var race = await _race_on("queijo")
	var k = race.player
	var Kart = load("res://scripts/kart.gd")
	_put(k, 0, 0.0, 26.0)
	for a in ["p1_accelerate", "p1_steer_left", "p1_drift"]:
		Input.action_press(a)
	var dt := 1.0 / 60.0
	var max_rate := 0.0
	var prev: float = k.heading
	for i in 75:
		k.step(dt, true)
		if k.drifting:
			max_rate = maxf(max_rate, absf(wrapf(k.heading - prev, -PI, PI)) / dt)
		prev = k.heading
	var charge: float = k.drift_charge
	var was: bool = k.drifting
	Input.action_release("p1_drift")
	k.step(dt, true)
	var ang := rad_to_deg(k.vel.angle_to(k.forward()))
	Input.action_release("p1_steer_left")
	Input.action_release("p1_accelerate")
	check(was and max_rate <= k.turn_rate * Kart.DRIFT_TURN_MAX + 0.01, "giro máx no drift %.2f rad/s <= %.2f" % [max_rate, k.turn_rate * Kart.DRIFT_TURN_MAX])
	check(ang < 3.0, "ao soltar sai alinhado (%.1f°)" % ang)
	check(charge >= Kart.MINI_TURBO_1 and k.boost_time > 0.0, "mini-turbo saiu (carga %.2f)" % charge)
	race.queue_free()
	await process_frame


func _test_parquinho() -> void:
	print("CA-64 cruzamento do 8")
	var race = await _race_on("parquinho")
	var t = race.track
	var n: int = t.sample_count()
	check(t.crossings.size() == 1, "um cruzamento (passado 2x por volta): %s" % str(t.crossings))
	var c0: int = t.crossings[0][0]
	var c1: int = t.crossings[0][1]
	var ang := rad_to_deg(t.tangents[c0].angle_to(t.tangents[c1]))
	check(ang > 60.0 and ang < 120.0, "as passadas se cruzam de lado (%.0f°)" % ang)
	check(t._in_other_road(c0, t.WALL, t.WALL + t.WALL_T + 1.0) and t._in_other_road(c0, -t.WALL, t.WALL + t.WALL_T + 1.0), "muro aberto no cruzamento")
	check(not t._in_other_road(wrapi(c0 + 60, 0, n), t.WALL, t.WALL + t.WALL_T + 1.0), "muro normal longe do cruzamento")
	check(t.crossing_top[c1] and not t.crossing_top[c0], "uma passada por cima da outra (sem piscar)")
	# o kart atravessa o cruzamento seguindo a própria passada
	var k = race.player
	Input.action_press("p1_accelerate")
	_put(k, wrapi(c0 - 10, 0, n), 0.0, 25.0)
	var p0: int = k.progress
	_drive(k, 2.0)
	Input.action_release("p1_accelerate")
	var ahead := wrapi(k.track_idx - c0, 0, n)
	check(ahead > 5 and ahead < 60 and k.progress - p0 > 15, "kart cruza e segue na mesma passada (idx +%d)" % ahead)
	# quem cruza bate de lado em quem vem pela outra passada
	var a = race.karts[0]
	var b = race.karts[1]
	_put(a, c0, 0.0, 0.0)
	_put(b, c1, 0.0, 0.0)
	b.position += Vector3(0.5, 0, 0)
	race._kart_collisions()
	var d: float = Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
	check(d >= a.RADIUS * 2.0 - 0.05, "karts de passadas diferentes colidem no cruzamento (%.2f m)" % d)
	race.queue_free()
	await process_frame

	print("CA-65 caixa de areia")
	race = await _race_on("parquinho")
	k = race.player
	var sz: Dictionary = {}
	for z in race.track.zones:
		if z["kind"] == "sand":
			sz = z
	var in_lat: float = (sz["lat0"] + sz["lat1"]) * 0.5
	Input.action_press("p1_accelerate")
	_put(k, int(sz["i0"]) + 2, in_lat, 0.0)
	_drive(k, 1.6)
	var on_sand: float = k.speed
	var kind_seen: String = k.zone_kind
	_put(k, int(sz["i0"]) + 2, -in_lat, 0.0)
	_drive(k, 1.6)
	var clean: float = k.speed
	Input.action_release("p1_accelerate")
	check(kind_seen == "sand" and on_sand <= k.top_speed() * race.track.SAND_MULT + 0.5 and clean > on_sand + 1.5, "areia segura (%.1f m/s na areia x %.1f fora)" % [on_sand, clean])
	check(race.track.SAND_MULT > race.track.FAROFA_MULT, "areia segura menos que farofa (é atalho)")
	race.queue_free()
	await process_frame

	print("CA-66 gangorra")
	race = await _race_on("parquinho")
	k = race.player
	var ss: Dictionary = {}
	for h in race.track_hazards:
		if h["spec"]["kind"] == "seesaw":
			ss = h
			break
	var sp: Dictionary = ss["spec"]
	var si: int = sp["idx"]
	var period: float = sp["period"]
	var phase: float = sp["phase"]
	# relógio no meio de cada lado: sin = +1 (rampa) e sin = -1 (parede)
	race.hazard_clock = period * 0.25 - phase
	race._update_track_hazards(0.0, false)
	check(ss["state"] == "ramp", "ponta de trás no chão = rampa")
	_put(k, si, float(ss["mid"]), 22.0)
	k.position -= race.track.tangents[si] * (race.SEESAW_HALF - 0.2)
	k.airborne = false
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.airborne and k.vy > 5.0 and k.spin_time == 0.0, "gangorra na rampa lança o kart (vy %.1f)" % k.vy)
	race.hazard_clock = period * 0.75 - phase
	race._update_track_hazards(0.0, false)
	check(ss["state"] == "wall", "ponta de trás no alto = parede")
	_put(k, si, float(ss["mid"]), 22.0)
	k.position -= race.track.tangents[si] * (race.SEESAW_HALF - 0.2)
	k.airborne = false
	k.position.y = 0.0
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0 and not k.airborne, "gangorra levantada derruba o kart")
	_put(k, si, -float(ss["mid"]), 22.0)
	k.position -= race.track.tangents[si] * (race.SEESAW_HALF - 0.2)
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time == 0.0 and not k.airborne, "do outro lado da pista a gangorra não pega")
	var out: Array = []
	k.track_idx = wrapi(si - 20, 0, race.track.sample_count())
	race._track_hazards_ahead(k, 40, out)
	var warned := out.any(func(o): return absf(float(o["lat"]) - float(ss["mid"])) < 0.01)
	check(warned, "IA vê a gangorra levantada à frente")
	race.queue_free()
	await process_frame

	print("CA-67 escorregador")
	race = await _race_on("parquinho")
	k = race.player
	var rt = race.track
	check(rt.ramp_h > rt.RAMP_H * 1.8, "escorregador mais alto que a rampa comum (%.1f m)" % rt.ramp_h)
	_put(k, wrapi(rt.ramp_idx - 4, 0, rt.sample_count()), 0.0, 24.0)
	k.max_height = 0.0
	Input.action_press("p1_accelerate")
	_drive(k, 2.5)
	Input.action_release("p1_accelerate")
	check(k.max_height > 3.0, "pulo do escorregador sobe %.1f m" % k.max_height)
	var far := true
	for c in rt.crossings:
		for ci in c:
			far = far and absi(wrapi(rt.ramp_idx - int(ci), -rt.sample_count() / 2, rt.sample_count() / 2)) > 30
	for p in rt.pads:
		for c in rt.crossings:
			for ci in c:
				far = far and absi(wrapi(int(p["idx"]) - int(ci), -rt.sample_count() / 2, rt.sample_count() / 2)) > 30
	check(far, "rampa e setas longe do cruzamento")
	race.queue_free()
	await process_frame

	print("CA-68 Copa Farofa no Grand Prix")
	var game = root.get_node_or_null("Game")
	check(game.CUPS.size() == 3 and game.CUPS[1]["tracks"].has("parquinho") and game.CUPS[1]["tracks"].size() == 4, "Copa Farofa com 4 pistas, incluindo o Parquinho")
	game.mode = "race"
	game.num_players = 1
	var menu = await _new_menu()
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))  # GRAND PRIX
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))           # piloto
	check(menu.step == menu.STEP_TRACK, "etapa PISTA")
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))  # copas lado a lado na grade
	check(menu.cup_i == 1 and menu.track_map.track_id == "churrasco" and menu.track_title.text == "COPA FAROFA", "→ escolhe a Copa Farofa e mostra a 1ª pista dela")
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))           # CORRER!
	check(menu.started and game.is_gp() and game.gp_cup == 1 and game.track_id == "churrasco", "GP começa na Churrascada")
	game.gp_index = 0
	check(game.gp_next() and game.track_id == "parquinho", "2ª corrida da copa: Parquinho")
	menu.queue_free()
	game.mode = "race"
	game.gp_cup = 0
	await process_frame


## Gira o kart pra encarar o muro da direita (lateral +).
func _face_wall(k, idx: int) -> void:
	var t = k.track
	_put(k, idx, 13.5, 0.0)
	for h in [t.heading_at(idx) - PI / 2.0, t.heading_at(idx) + PI / 2.0]:
		k.heading = h
		if k.forward().dot(t.rights[idx]) > 0.9:
			break
	k.rotation.y = k.heading
	k.last_pos = k.position


func _test_rescue() -> void:
	var dt := 1.0 / 60.0
	print("CA-69 kart preso volta pra pista")
	var race = await _race_on("queijo")
	var k = race.player
	var t = race.track
	var n: int = t.sample_count()
	var idx := 120
	_face_wall(k, idx)
	k.safe_idx = idx
	var prog0: float = k.progress
	Input.action_press("p1_accelerate")
	var secs := 0.0
	while k.rescues == 0 and secs < 6.0:
		k.step(dt, true)
		secs += dt
	check(k.rescues == 1 and secs > k.STUCK_PLAYER_TIME - 0.1 and secs < k.STUCK_PLAYER_TIME + 0.6, "acelerando contra o muro, os balões pegam em %.1f s" % secs)
	check(k.balloons != null and k.balloons.visible, "balões aparecem")
	var top := 0.0
	while k.rescue_time > 0.0:
		k.step(dt, true)
		top = maxf(top, k.position.y)
	Input.action_release("p1_accelerate")
	var back := wrapi(idx - k.track_idx, -n / 2, n / 2)
	check(back >= 0 and back < 40 and absf(k.lateral) < 0.5 and k.position.y == 0.0, "pousa no centro da pista, no mesmo lugar ou pra trás (%d amostras)" % back)
	check(top > 4.0, "sobe pendurado (%.1f m)" % top)
	check(k.forward().dot(t.tangents[k.track_idx]) > 0.99, "de frente pro sentido da pista")
	check(absf((k.progress - prog0) + back) < 1.5, "progresso da volta acompanha o lugar (%.1f)" % (k.progress - prog0))
	check(not k.balloons.visible and k.rescue_ghost > 0.0, "balões somem e o kart fica piscando")
	k.hit(1.0)
	k.trap()
	check(k.spin_time == 0.0 and k.trap_time == 0.0, "piscando nada acerta")
	for i in 90:
		k.step(dt, true)
	check(k.rescue_ghost == 0.0 and k.model.visible, "depois volta ao normal")
	# parado sem acelerar não é "preso"
	_face_wall(k, idx)
	for i in 300:
		k.step(dt, true)
	check(k.rescues == 1, "parado sem acelerar não chama os balões")
	race.queue_free()
	await process_frame

	print("CA-70 caiu = volta e perde queijinhos")
	race = await _race_on("queijo")
	k = race.player
	_put(k, 200, 3.0, 20.0)
	k.safe_idx = 196
	k.cheese = 5
	k.position.y = -5.0
	k.step(dt, true)
	check(k.rescue_time > 0.0 and k.cheese == 2, "abaixo do chão: resgate e -3 queijinhos (%d)" % k.cheese)
	while k.rescue_time > 0.0:
		k.step(dt, true)
	check(k.track_idx == 196 and k.position.y == 0.0, "volta no último ponto seguro (%d)" % k.track_idx)
	race.queue_free()
	await process_frame

	print("CA-71 pontos seguros")
	race = await _race_on("churrasco")
	t = race.track
	n = t.sample_count()
	var bad := 0
	for h in t.hazard_specs:
		bad += t.safe[int(h["idx"])]
	for z in t.zones:
		bad += t.safe[int(z["i0"]) + 2]
	bad += t.safe[t.ramp_idx + 1]
	check(bad == 0, "nunca devolve em cima de fogo, farofa, grelha ou rampa")
	var gi: int = t.zones[1]["i0"] + 5  # meio da grelha
	var si: int = t.safe_before(gi)
	check(t.safe[si] == 1 and wrapi(gi - si, 0, n) > 0 and wrapi(gi - si, 0, n) < 40, "da grelha volta pra antes dela (%d amostras)" % wrapi(gi - si, 0, n))
	var cnt := 0
	for v in t.safe:
		cnt += v
	check(cnt > n * 0.6, "a maior parte da pista é segura (%d de %d)" % [cnt, n])
	race.queue_free()
	await process_frame
	race = await _race_on("parquinho")
	t = race.track
	var c0: int = t.crossings[0][0]
	check(t.safe[c0] == 0 and t.safe[t.crossings[0][1]] == 0, "nem no meio do cruzamento")
	race.queue_free()
	await process_frame

	print("CA-72 contramão")
	race = await _race_on("queijo")
	k = race.player
	_put(k, 150, 0.0, 0.0)
	k.heading += PI
	k.rotation.y = k.heading
	Input.action_press("p1_accelerate")
	for i in 90:
		race.step(dt)
	Input.action_release("p1_accelerate")
	var hud = race.huds[0]
	hud.update_hud(dt)
	check(k.wrong_way_time > k.WRONG_WAY_SHOW and hud.lbl_msg.text == "CONTRAMÃO!", "andando ao contrário aparece CONTRAMÃO! (%.1f s)" % k.wrong_way_time)
	k.heading -= PI
	k.vel = k.forward() * 10.0
	k.speed = 10.0
	for i in 40:
		race.step(dt)
	check(k.wrong_way_time == 0.0, "virou pro lado certo, some")
	race.queue_free()
	await process_frame

	print("CA-73 IA presa também usa os balões")
	race = await _race_on("queijo")
	var ai = race.karts[1]
	_face_wall(ai, 300)
	ai.ai_lane_timer = 99.0
	var s2 := 0.0
	while ai.rescues == 0 and s2 < 8.0:
		ai.speed = 0.0  # segura parada (simula enroscada)
		ai.vel = Vector3.ZERO
		ai.step(dt, true)
		s2 += dt
	check(ai.rescues == 1 and s2 < ai.STUCK_AI_TIME + 0.5, "IA parada: balões em %.1f s" % s2)
	race.queue_free()
	await process_frame


func _test_geladeira() -> void:
	var dt := 1.0 / 60.0
	print("CA-74 andares, viaduto e looping na geometria")
	var race = await _race_on("geladeira")
	var t = race.track
	var n: int = t.sample_count()
	var ymin := INF
	var ymax := -INF
	for p in t.points:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	check(ymin >= 0.0 and ymax > 15.0, "do fundo (%.1f m) ao congelador e acima (%.1f m)" % [ymin, ymax])
	check(t.overpasses.size() == 1, "um viaduto: %s" % str(t.overpasses))
	var ov: Array = t.overpasses[0]
	check(t.points[ov[1]].y - t.points[ov[0]].y > 6.0, "vão livre do viaduto %.1f m" % (t.points[ov[1]].y - t.points[ov[0]].y))
	check(t.wall_at(ov[1]) < t.WALL and t.wall_at(ov[0]) == t.WALL, "ponte estreita em cima, pista normal embaixo")
	check(t.loops.size() == 1, "um looping")
	var lp: Dictionary = t.loops[0]
	var top_i := int(lp["i0"])
	for i in range(int(lp["i0"]), int(lp["i1"]) + 1):
		if t.points[i].y > t.points[top_i].y:
			top_i = i
	check(t.ups[top_i].y < -0.9, "no alto do looping a pista está de cabeça pra baixo (up.y %.2f)" % t.ups[top_i].y)
	check(t.wall_at(int(lp["i0"]) - 3) < t.WALL and t.wall_at(int(lp["i1"]) + 3) < t.WALL, "muro estreito na entrada e na saída do looping")
	var safe_in_loop := 0
	for i in range(int(lp["i0"]), int(lp["i1"]) + 1):
		safe_in_loop += t.safe[i]
	check(safe_in_loop == 0, "resgate nunca devolve dentro do looping")

	print("CA-75 subida acompanha o chão")
	var k = race.player
	var climb := -1
	for i in n:
		if t.points[i].y < 1.0 and t.points[(i + 40) % n].y > 5.0:
			climb = i
			break
	check(climb >= 0, "achou a subida do fundo pra prateleira (%d)" % climb)
	_put(k, climb, 0.0, 22.0)
	Input.action_press("p1_accelerate")
	var worst := 0.0
	for s in 240:
		k.step(dt, true)
		if not k.airborne and not k.on_ramp:
			worst = maxf(worst, absf(k.position.y - k.ground))
	Input.action_release("p1_accelerate")
	check(k.position.y > 3.0 and worst < 0.05, "subiu rumo à prateleira (%.1f m) colado no chão (erro %.2f m)" % [k.position.y, worst])
	check(k.pitch > 0.02 or t.tangents[k.track_idx].y < 0.02, "kart empina na subida (%.2f rad)" % k.pitch)

	print("CA-76 looping")
	var i0 := int(lp["i0"])
	_put(k, i0 - 12, 0.0, 26.0)
	Input.action_press("p1_accelerate")
	var seen := false
	var top_y := 0.0
	var upside := false
	var secs := 0.0
	while secs < 6.0 and k.loops_done == 0:
		k.step(dt, true)
		secs += dt
		if k.on_loop:
			seen = true
			top_y = maxf(top_y, k.position.y - t.points[i0].y)
			if k.basis.y.y < -0.8:
				upside = true
	for s in 30:
		k.step(dt, true)
	Input.action_release("p1_accelerate")
	var r: float = lp["r"]
	check(seen and k.loops_done == 1, "entrou no trilho e saiu (%.1f s)" % secs)
	check(top_y > r * 2.0 - 1.0 and upside, "deu a volta inteira de cabeça pra baixo (subiu %.1f m)" % top_y)
	check(not k.on_loop and absf(k.position.y - k.ground) < 0.1 and wrapi(k.track_idx - int(lp["i1"]), 0, n) < 40, "voltou pro chão depois do looping (idx +%d)" % wrapi(k.track_idx - int(lp["i1"]), 0, n))
	check(k.forward().dot(Vector3(t.tangents[k.track_idx].x, 0, t.tangents[k.track_idx].z).normalized()) > 0.95, "saiu alinhado com a pista")
	# devagar também passa (trilho com velocidade mínima)
	_put(k, i0 - 2, 0.0, 4.0)
	var done0: int = k.loops_done
	secs = 0.0
	Input.action_press("p1_accelerate")
	while secs < 8.0 and k.loops_done == done0:
		k.step(dt, true)
		secs += dt
	Input.action_release("p1_accelerate")
	check(k.loops_done == done0 + 1 and k.rescues == 0, "entrando devagar não fica preso no looping (%.1f s)" % secs)
	# trocar de faixa dentro do looping
	_put(k, i0 - 2, 0.0, 22.0)
	Input.action_press("p1_steer_right")
	for s in 40:
		k.step(dt, true)
	var lat_in: float = k.lateral
	Input.action_release("p1_steer_right")
	check(k.on_loop and lat_in > 2.0, "direcional troca de faixa no looping (%.1f m)" % lat_in)
	# RF-321: giro contínuo (sem degraus de 10° entre amostras)
	_put(k, i0 - 6, 0.0, 26.0)
	var prev_z: Vector3 = k.basis.z
	var max_step := 0.0
	var in_frames := 0
	for s in 120:
		k.step(dt, true)
		if k.on_loop:
			in_frames += 1
			if in_frames > 1:
				max_step = maxf(max_step, rad_to_deg(prev_z.angle_to(k.basis.z)))
		prev_z = k.basis.z
	check(in_frames > 20 and max_step < 4.0, "kart gira liso no looping (máx %.1f° por quadro)" % max_step)
	_put(k, i0 - 2, 0.0, 22.0)
	Input.action_press("p1_steer_right")
	for s in 40:
		k.step(dt, true)
	Input.action_release("p1_steer_right")
	var fr: Array = k.cam_frame()
	check((fr[1] as Vector3).distance_to(t.ups[k.track_idx]) < 0.25, "câmera gira com a pista no looping")
	race.queue_free()
	await process_frame

	print("CA-77 gelo escorrega")
	race = await _race_on("geladeira")
	k = race.player
	t = race.track
	var iz: Dictionary = {}
	for z in t.zones:
		if z["kind"] == "ice":
			iz = z
	var slip := []
	for where in [int(iz["i0"]) + 4, 30]:
		_put(k, where, 0.0, 24.0)
		Input.action_press("p1_accelerate")
		Input.action_press("p1_steer_left")
		for s in 25:
			k.step(dt, true)
		Input.action_release("p1_steer_left")
		Input.action_release("p1_accelerate")
		slip.append(rad_to_deg(k.vel.normalized().angle_to(k.forward())))
	check(slip[0] > slip[1] * 2.0 and slip[0] > 8.0, "no gelo o kart derrapa mais (%.0f° x %.0f° no asfalto)" % [slip[0], slip[1]])
	race.queue_free()
	await process_frame

	print("CA-78 viaduto")
	race = await _race_on("geladeira")
	t = race.track
	var lo = race.karts[0]
	var hi = race.karts[1]
	_put(lo, int(t.overpasses[0][0]), 0.0, 0.0)
	_put(hi, int(t.overpasses[0][1]), 0.0, 0.0)
	var before: Vector3 = lo.position
	race._kart_collisions()
	check(lo.position == before and hi.position.y - lo.position.y > 6.0, "kart de cima não bate no de baixo")
	hi.cheese = 0
	race.cheeses[0]["pos"] = lo.position + Vector3.UP * 0.7
	race.cheeses[0]["cd"] = 0.0
	race._update_cheese(dt)
	check(hi.cheese == 0, "queijinho de baixo não é pego por quem passa em cima")
	# resgate no congelador devolve no congelador
	k = race.player
	var up_i := int(t.overpasses[0][1]) - 30
	_face_wall(k, up_i)
	k.safe_idx = up_i
	Input.action_press("p1_accelerate")
	var guard := 0.0
	while k.rescues == 0 and guard < 6.0:
		k.step(dt, true)
		guard += dt
	while k.rescue_time > 0.0:
		k.step(dt, true)
	Input.action_release("p1_accelerate")
	check(k.rescues == 1 and k.position.y > 12.0, "resgate no alto pousa no alto (%.1f m)" % k.position.y)
	race.queue_free()
	await process_frame

	print("CA-79 IA na Geladeira")
	race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "geladeira"
	race.laps = 2
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	var tt := 0.0
	while tt < 200.0 and not race.all_finished():
		race.step(dt)
		tt += dt
	var best := INF
	var worst_l := 0.0
	var loops_ok := true
	var resc := 0
	for kk in race.karts:
		if kk.finished:
			best = minf(best, kk.finish_time / 2.0)
			worst_l = maxf(worst_l, kk.finish_time / 2.0)
		loops_ok = loops_ok and kk.loops_done >= 2
		resc += kk.rescues
	check(race.all_finished() and best > 30.0 and worst_l < 60.0, "volta da IA %.1f..%.1f s" % [best, worst_l])
	check(loops_ok, "todos os karts passaram pelo looping nas 2 voltas")
	check(resc <= 2, "IA quase nunca precisa de resgate (%d)" % resc)
	race.queue_free()
	await process_frame


func _test_telhados() -> void:
	var dt := 1.0 / 60.0
	print("CA-80 vãos entre prédios")
	var race = await _race_on("telhados")
	var t = race.track
	var n: int = t.sample_count()
	check(t.gaps.size() == 3 and t.gap_ramps.size() == 3, "3 vãos, cada um com rampinha de beirada")
	var ok := true
	for g in t.gaps:
		var gi: int = g["i0"]
		ok = ok and t.gap_at(gi) and not t.gap_at(gi - 1) and t.ramp_frac(gi - 2, 0.0, 0.0) > 0.0
		ok = ok and t.safe[gi] == 0 and t.safe[gi - 2] == 0 and t.safe[gi + int(g["len"]) + 2] == 0
	check(ok, "rampinha logo antes do vão; resgate nunca devolve na rampinha, no vão ou no pouso")
	var ymin := INF
	for p in t.points:
		ymin = minf(ymin, p.y)
	check(ymin > 15.0 and t.get_node_or_null("Moon") != null, "tudo lá no alto (%.0f m) e com lua" % ymin)

	print("CA-81 pulo do vão")
	var k = race.player
	var g0: Dictionary = t.gaps[0]
	var gi0: int = g0["i0"]
	_put(k, gi0 - 12, 0.0, 25.0)
	Input.action_press("p1_accelerate")
	var flew := false
	for s in 120:
		k.step(dt, true)
		if t.gap_at(k.track_idx) and k.airborne:
			flew = true
	Input.action_release("p1_accelerate")
	var past := wrapi(k.track_idx - (gi0 + int(g0["len"])), 0, n)
	check(flew and k.rescues == 0 and past > 0 and past < 120 and not k.airborne and absf(k.position.y - k.ground) < 0.1, "rápido: voa por cima do vão e pousa no outro prédio (+%d)" % past)

	print("CA-82 caiu no vão")
	_put(k, gi0 - 6, 0.0, 7.0)
	k.cheese = 4
	var secs := 0.0
	while k.rescues == 1 - 1 and secs < 5.0:
		k.speed = 7.0
		k.step(dt, true)
		secs += dt
	check(k.rescues == 1 and k.cheese == 1, "devagar: cai no vão, balões e -3 queijinhos")
	while k.rescue_time > 0.0:
		k.step(dt, true)
	check(wrapi(gi0 - k.track_idx, 0, n) > 0 and wrapi(gi0 - k.track_idx, 0, n) < 40 and absf(k.position.y - t.points[k.track_idx].y) < 0.1, "volta no telhado antes do vão (%d amostras antes)" % wrapi(gi0 - k.track_idx, 0, n))
	# pulo curto: bate na parede do prédio da frente
	_put(k, gi0 + int(g0["len"]) - 1, 0.0, 15.0)
	k.airborne = true
	k.position.y = t.points[gi0].y - 1.6
	k.vy = 0.0
	var r0: int = k.rescues
	for s in 30:
		k.step(dt, true)
		if k.rescues > r0:
			break
	check(k.rescues == r0 + 1, "pulo curto bate na parede do prédio e chama os balões")
	race.queue_free()
	await process_frame

	print("CA-83 gatão no telhado")
	race = await _race_on("telhados")
	t = race.track
	k = race.player
	var cat: Dictionary = {}
	for h in race.track_hazards:
		if h["spec"]["kind"] == "roofcat":
			cat = h
	race._update_track_hazards(0.0, false)
	var cp: Vector3 = cat["node"].position
	var ci: int = cat["spec"]["idx"]
	k.place(ci, t.lateral_of(cp, ci))
	k.spin_time = 0.0
	k.rescue_ghost = 0.0  # acabou de sair do buraco (CA-92): tira a imunidade
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0, "gato derruba quem encosta")
	var out: Array = []
	k.track_idx = wrapi(ci - 15, 0, t.sample_count())
	race._track_hazards_ahead(k, 40, out)
	check(out.any(func(o): return absf(float(o["lat"]) - float(cat["lat"])) < 0.01), "IA vê o gato à frente")
	var lat0: float = cat["lat"]
	race._update_track_hazards(1.0, false)
	check(absf(float(cat["lat"]) - lat0) > 0.5, "gato anda de um lado pro outro")
	race.queue_free()
	await process_frame

	print("CA-84 IA nos Telhados")
	race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "telhados"
	race.laps = 2
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	var tt := 0.0
	while tt < 200.0 and not race.all_finished():
		race.step(dt)
		tt += dt
	var best := INF
	var worst := 0.0
	var resc := 0
	for kk in race.karts:
		if kk.finished:
			best = minf(best, kk.finish_time / 2.0)
			worst = maxf(worst, kk.finish_time / 2.0)
		resc += kk.rescues
	check(race.all_finished() and best > 30.0 and worst < 60.0, "volta da IA %.1f..%.1f s" % [best, worst])
	check(resc <= 4, "IA quase sempre acerta os pulos (%d quedas em 16 voltas)" % resc)
	race.queue_free()
	await process_frame


func _test_menu_look() -> void:
	print("CA-85 visual do menu")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	game.num_players = 2
	var menu = await _new_menu()
	check(menu.get_node_or_null("BgArt") != null, "fundo com a arte da abertura")
	var th: Theme = root.theme
	check(th.get_stylebox("normal", "Button") is StyleBoxFlat and th.get_stylebox("focus", "Button") is StyleBoxFlat, "botões do tema novo (sem a textura branca)")
	check(menu.crumb_chips.size() == 4, "4 chips de etapa")
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))
	await process_frame
	check(menu.step == menu.STEP_SETUP and menu.sum_pilots.get_child_count() == 2 and menu.sum_map.track_id != "", "AJUSTES mostra os 2 retratos e o trajeto")
	var cur: StyleBoxFlat = menu.crumb_chips[menu.STEP_SETUP].get_theme_stylebox("panel")
	var done: StyleBoxFlat = menu.crumb_chips[0].get_theme_stylebox("panel")
	check(cur.bg_color != done.bg_color, "chip da etapa atual destacado")
	menu.queue_free()
	game.num_players = 1
	await process_frame


func _test_loading() -> void:
	print("CA-86 tela de carregamento")
	var game = root.get_node_or_null("Game")
	check(ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/ui/splash.png" and ResourceLoader.exists("res://assets/ui/splash.png"), "imagem de inicialização configurada")
	game.track_id = "geladeira"
	game.mode = "race"
	game.show_loading(game.loading_text())
	check(game.is_loading() and game.loading_name.text == "Geladeira Polar" and game.loading.layer >= 100, "CARREGANDO com o nome da pista, por cima de tudo")
	game.gp_cup = 1
	game.start_gp()
	check("Copa Farofa" in game.loading_text() and "1/4" in game.loading_text(), "no GP mostra a copa e a corrida (%s)" % game.loading_text().replace("\n", " / "))
	game.mode = "race"
	game.gp_cup = 0
	# a corrida tira a tela quando o primeiro quadro dela fica pronto
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "queijo"
	root.add_child(race)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	check(not game.is_loading(), "a corrida tira o CARREGANDO sozinha")
	race.queue_free()
	await process_frame


## Textos das linhas do placar (pra achar "correndo" e os tempos).
func _result_texts(hud) -> Array:
	var out := []
	for row in hud.results_rows.get_children():
		for c in row.get_children():
			if c is Label:
				out.append(c.text)
	return out


func _test_results_live() -> void:
	print("CA-87 placar atualiza quando as IAs terminam")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["shinando"]
	race.track_id = "cozinha"
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	# o jogador é rapidíssimo: termina bem antes da maioria
	race.player.max_speed = 60.0
	race.player.accel = 60.0
	var t := 0.0
	while t < 200.0 and not race.results_shown:
		race.step(1.0 / 60.0)
		t += 1.0 / 60.0
	var hud = race.results_hud
	var before := _result_texts(hud)
	var running := before.count("correndo")
	check(race.results_shown and running > 0, "placar abre com quem ainda está correndo (%d)" % running)
	while t < 260.0 and not race.all_finished():
		race.step(1.0 / 60.0)
		t += 1.0 / 60.0
	race.step(1.0 / 60.0)
	var after := _result_texts(hud)
	var times := after.filter(func(s): return ":" in s and "." in s).size()
	check(race.all_finished() and after.count("correndo") == 0 and times == race.karts.size(), "quando todos terminam, todos têm tempo no placar (%d tempos)" % times)
	race.queue_free()
	await process_frame


func _test_feira() -> void:
	var dt := 1.0 / 60.0
	print("CA-88 largura variável")
	var race = await _race_on("feira")
	var t = race.track
	var n: int = t.sample_count()
	var hmin := INF
	var hmax := 0.0
	var jump := 0.0
	for i in n:
		hmin = minf(hmin, t.road_half(i))
		hmax = maxf(hmax, t.road_half(i))
		jump = maxf(jump, absf(t.wall_at(i) - t.wall_at((i + 1) % n)))
	check(hmin <= 5.1 and hmax >= 15.5, "pista afunila (%.1f m) e abre (%.1f m)" % [hmin * 2.0, hmax * 2.0])
	check(jump < 1.0, "muro acompanha a largura sem degrau (%.2f m)" % jump)
	var narrow := 0
	for i in n:
		if t.road_half(i) < 5.5:
			narrow = i
			break
	check(t.wall_at(narrow) < t.road_half(narrow) + 2.0, "no beco o muro (barraca) cola na zebra")
	var k = race.player
	_put(k, narrow, 0.0, 0.0)
	k.lateral = 0.0
	var off_before: float = k.top_speed()
	Input.action_press("p1_accelerate")
	_drive(k, 1.5)
	Input.action_release("p1_accelerate")
	check(absf(k.lateral) < t.wall_at(k.track_idx), "beco: kart segue dentro das barracas")

	print("CA-89 atalho por baixo das barracas")
	var isl: Dictionary = t.islands[0]
	var mid_i: int = int(isl["i0"]) + int(isl["len"]) / 2
	_put(k, mid_i, (float(isl["lat0"]) + float(isl["lat1"])) * 0.5, 0.0)
	k.step(dt, true)
	check(k.lateral <= float(isl["lat0"]) - 0.5 or k.lateral >= float(isl["lat1"]) + 0.5, "ninguém atravessa a ilha de barracas (lateral %.1f)" % k.lateral)
	# atalho (lado de dentro) é mais curto que a faixa larga
	var short_len := 0.0
	var long_len := 0.0
	var sl: float = (-t.road_half(mid_i) + float(isl["lat0"])) * 0.5 if float(isl["side"]) < 0 else (t.road_half(mid_i) + float(isl["lat1"])) * 0.5
	var ll: float = (t.road_half(mid_i) + float(isl["lat1"])) * 0.5 if float(isl["side"]) < 0 else (-t.road_half(mid_i) + float(isl["lat0"])) * 0.5
	for q in int(isl["len"]):
		var a: int = (int(isl["i0"]) + q) % n
		var b: int = (a + 1) % n
		short_len += (t.points[b] + t.rights[b] * sl).distance_to(t.points[a] + t.rights[a] * sl)
		long_len += (t.points[b] + t.rights[b] * ll).distance_to(t.points[a] + t.rights[a] * ll)
	check(short_len < long_len * 0.85, "atalho %.0f m x faixa larga %.0f m" % [short_len, long_len])
	race.queue_free()
	await process_frame

	print("CA-90 IA na Feira")
	race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "feira"
	race.laps = 2
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	t = race.track
	isl = t.islands[0]
	var short_users := {}
	var long_users := {}
	var tt := 0.0
	while tt < 200.0 and not race.all_finished():
		race.step(dt)
		tt += dt
		for kk in race.karts:
			if not t.island_at(kk.track_idx).is_empty():
				if (kk.lateral < float(isl["lat0"])) == (float(isl["side"]) < 0):
					short_users[kk.char_id] = true
				else:
					long_users[kk.char_id] = true
	var best := INF
	var worst := 0.0
	for kk in race.karts:
		if kk.finished:
			best = minf(best, kk.finish_time / 2.0)
			worst = maxf(worst, kk.finish_time / 2.0)
	check(race.all_finished() and best > 30.0 and worst < 60.0, "volta da IA %.1f..%.1f s" % [best, worst])
	check(short_users.size() >= 2 and long_users.size() >= 2, "IA usa as duas faixas (%d pelo atalho, %d por fora)" % [short_users.size(), long_users.size()])
	race.queue_free()
	await process_frame


func _test_char_colors() -> void:
	print("CA-91 cor e número de cada piloto = o carro dele na arte")
	var chars: Array = load("res://scripts/characters.gd").LIST
	var nums := {}
	for c in chars:
		nums[int(c.get("number", 0))] = true
	check(nums.size() == 8 and nums.has(1) and nums.has(8) and not nums.has(0), "números de 1 a 8 sem repetir")
	# na arte: 1 azul, 2 vermelho, 3 amarelo, 4 verde, 5 laranja, 6 azul-claro, 7 vermelho, 8 roxo
	var want := {"fejaum": "azul", "burcca": "vermelho", "nanni": "amarelo", "mugurin": "verde", "digao": "laranja", "shinando": "azul-claro", "telles": "vermelho", "ortiz": "roxo"}
	var bad := []
	for c in chars:
		var col: Color = c["color"]
		var h := col.h * 360.0
		var name := ""
		if col.s < 0.3:
			name = "cinza"
		elif h < 15.0 or h >= 330.0:
			name = "vermelho"
		elif h < 40.0:
			name = "laranja"
		elif h < 65.0:
			name = "amarelo"
		elif h < 160.0:
			name = "verde"
		elif h < 210.0:
			name = "azul-claro"
		elif h < 250.0:
			name = "azul"
		else:
			name = "roxo"
		if name != want[c["id"]]:
			bad.append("%s=%s" % [c["id"], name])
	check(bad.is_empty(), "cores batem com a arte %s" % str(bad))


func _test_redone_tracks() -> void:
	var dt := 1.0 / 60.0
	print("CA-92 buracos de queijo suíço")
	var race = await _race_on("queijo")
	var t = race.track
	var n: int = t.sample_count()
	check(t.pits.size() >= 3 and t.def.get("rev", 1) == 2, "Queijo refeito com %d buracos" % t.pits.size())
	var pit: Dictionary = t.pits[0]
	var k = race.player
	_put(k, wrapi(int(pit["idx"]) - 4, 0, n), float(pit["lat"]), 22.0)
	k.cheese = 6
	Input.action_press("p1_accelerate")
	var s := 0.0
	while k.rescues == 0 and s < 3.0:
		k.step(dt, true)
		s += dt
	Input.action_release("p1_accelerate")
	check(k.rescues == 1 and k.cheese == 3, "passou por cima do buraco: cai, balões e -3 queijinhos")
	while k.rescue_time > 0.0:
		k.step(dt, true)
	k.rescue_ghost = 0.0
	check(t.safe[int(pit["idx"])] == 0, "resgate nunca devolve em cima do buraco")
	var out: Array = []
	k.track_idx = wrapi(int(pit["idx"]) - 10, 0, n)
	race._track_hazards_ahead(k, 30, out)
	check(out.any(func(o): return o.get("pit", false) and o.has("r")), "IA enxerga o buraco (com o tamanho)")

	print("CA-93 ponte sobre o rio e vacas")
	check(not t.bridges.is_empty() and t.get_node_or_null("River") != null, "Queijo tem ponte e rio")
	var bi: int = (int(t.bridges[0]["i0"]) + int(t.bridges[0]["len"]) / 2) % n
	check(t.points[bi].y > 3.0 and t.wall_at(bi) < t.road_half(bi) + 2.0, "ponte alta (%.1f m) com corrimão colado" % t.points[bi].y)
	var cow: Dictionary = {}
	for h in race.track_hazards:
		if h["spec"].get("model", "") == "cow":
			cow = h
			break
	race._update_track_hazards(0.0, false)
	var cp: Vector3 = cow["node"].position
	var ci: int = cow["spec"]["idx"]
	k.place(ci, t.lateral_of(cp, ci))
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0, "vaca atravessando derruba quem encosta")
	race.queue_free()
	await process_frame

	print("CA-94 salto no cânion e bolas de feno")
	race = await _race_on("deserto")
	t = race.track
	n = t.sample_count()
	check(t.gaps.size() == 1 and t.get_node_or_null("GapFloor") != null, "Deserto tem um cânion pra pular")
	k = race.player
	var g: Dictionary = t.gaps[0]
	_put(k, wrapi(int(g["i0"]) - 14, 0, n), 0.0, 26.0)
	Input.action_press("p1_accelerate")
	for q in 150:
		k.step(dt, true)
	Input.action_release("p1_accelerate")
	check(k.rescues == 0 and wrapi(k.track_idx - int(g["i0"]), 0, n) > int(g["len"]), "rápido: passa o cânion voando")
	var tw: int = 0
	for h in race.track_hazards:
		if h["spec"].get("model", "") == "tumbleweed":
			tw += 1
	check(tw >= 2, "%d bolas de feno rolando" % tw)
	race.queue_free()
	await process_frame

	print("CA-95 robô aspirador e colher na cozinha")
	race = await _race_on("cozinha")
	t = race.track
	n = t.sample_count()
	var rover: Dictionary = {}
	for h in race.track_hazards:
		if h["spec"]["kind"] == "rover":
			rover = h
			break
	race._update_track_hazards(0.0, false)
	var a0: int = rover["at"]
	race._update_track_hazards(1.5, false)
	check(a0 != int(rover["at"]), "robô anda ao longo da pista (%d → %d)" % [a0, int(rover["at"])])
	k = race.player
	var rp: Vector3 = rover["node"].position
	k.place(int(rover["at"]), t.lateral_of(rp, int(rover["at"])))
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0, "robô derruba quem encosta")
	var bm: int = (int(t.bridges[0]["i0"]) + int(t.bridges[0]["len"]) / 2) % n
	check(t.points[bm].y > 5.0 and t.get_node_or_null("River") == null, "colher no alto, entre as bancadas (sem rio)")
	race.queue_free()
	await process_frame

	print("CA-96 recorde por versão do traçado")
	var Records = load("res://scripts/records.gd")
	check(Records.section("queijo") == "queijo@2" and Records.section("churrasco") == "churrasco", "pista refeita guarda recorde à parte (%s)" % Records.section("queijo"))


func _stick(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = v
	e.device = 0
	return e


func _test_stick_menu() -> void:
	print("CA-97 analógico no menu: uma casa por empurrão")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	game.num_players = 1
	var menu = await _new_menu()
	var has_axis := false
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadMotion:
				has_axis = true
	check(not has_axis, "analógico fora das ações de menu (o Game converte)")
	var m0: int = menu.mode_i
	# um empurrão "tremido" chega como vários eventos acima do limite
	for v in [0.4, 0.65, 0.8, 0.95, 1.0, 0.9, 0.7, 0.62]:
		Input.parse_input_event(_stick(v))
	await process_frame
	await process_frame
	check(menu.mode_i == (m0 + 1) % 3, "um empurrão = uma casa (%d → %d)" % [m0, menu.mode_i])
	Input.parse_input_event(_stick(0.5))  # ainda inclinado: não conta de novo
	await process_frame
	check(menu.mode_i == (m0 + 1) % 3, "voltar só um pouco não dá outro passo")
	Input.parse_input_event(_stick(0.05))
	Input.parse_input_event(_stick(0.9))
	await process_frame
	await process_frame
	check(menu.mode_i == (m0 + 2) % 3, "soltou e empurrou de novo: mais uma casa")
	# segurando: repete devagar
	var before: int = menu.mode_i
	for s in 60:  # 1 s segurado
		game._stick_repeat(1.0 / 60.0)
	await process_frame
	await process_frame
	var steps := wrapi(menu.mode_i - before, 0, 3)
	check(steps >= 1, "segurando 1 s repete (%d passos a mais)" % steps)
	Input.parse_input_event(_stick(0.0))
	await process_frame
	menu.queue_free()
	await process_frame


## Corrida de teste com os pilotos dados (o 1º é o jogador) e todo mundo parado na pista.
func _power_race(chars: Array) -> Node:
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = false
	race.player_chars = [chars[0]]
	race.track_id = "cozinha"
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	race.state = "racing"
	race.countdown = 0.0
	race.track_hazards.clear()  # sem robô atrapalhando
	return race


func _press_power(k) -> void:
	k.in_power = true
	k._update_power(1.0 / 60.0)
	k.in_power = false


func _kart_of(race, id: String):
	for k in race.karts:
		if k.char_id == id:
			return k
	return null


func _test_powers() -> void:
	print("CA-98 poder: 10 queijinhos libera, recarga de 20 s")
	var race = await _power_race(["fejaum"])
	var k = race.player
	var others: Array = race.karts.filter(func(o): return o != k)
	for i in race.karts.size():
		_put(race.karts[i], 100 + i * 6, 0.0, 20.0)
	k.cheese = 9
	check(not k.power_ready() and k.power_state() == "charge", "com 9 queijinhos ainda não")
	k.cheese = 10
	check(k.power_ready() and k.power_state() == "ready", "com 10 fica pronto")
	others[0].shield_time = 5.0
	_press_power(k)
	check(k.power_cd > 19.0 and k.power_state() == "cooldown" and not k.power_ready(), "usou: recarga de 20 s")
	print("CA-99 FeJauM — Câmera Lenta")
	var slowed: int = others.filter(func(o): return o.slow_time > 0.0).size()
	check(slowed == others.size() - 1 and others[0].slow_time == 0.0 and others[0].shield_time == 0.0, "todos os outros lentos; o do escudo não (e perde o escudo)")
	var o1 = others[1]
	o1.speed = 25.0
	o1.in_throttle = 1.0
	o1.step(1.0 / 60.0, true)
	check(o1.speed <= o1.top_speed() * 0.5 + 0.01 and o1.fx_slow != null and o1.fx_slow.visible, "lento = metade da velocidade, com anel azul visível")
	for s in 70:
		o1._update_power(1.0 / 60.0)
	check(o1.slow_time == 0.0, "passa em 1 s")
	k.cheese = 10
	k.power_cd = 0.0
	race.queue_free()
	await process_frame

	print("CA-100 Shinando — Violão")
	race = await _power_race(["shinando"])
	k = race.player
	k.cheese = 10
	_press_power(k)
	check(k.shield_time >= 4.9 and k.power_cd > 19.0, "escudo por 5 s")
	race.queue_free()
	await process_frame

	print("CA-101 Nanni — Planta Turbo")
	race = await _power_race(["nanni"])
	k = race.player
	k.cheese = 10
	_put(k, 100, 0.0, 10.0)
	_press_power(k)
	check(k.power_charges == 4 and k.boost_time > 0.5 and k.power_cd == 0.0, "ativou a planta: 1º turbo já sai (sobram 4)")
	var turbos := 1
	for t in 4:
		k.boost_time = 0.0
		_press_power(k)
		if k.boost_time > 0.5:
			turbos += 1
	check(turbos == 5 and k.power_charges == 0 and k.power_cd > 19.0, "5 mini-turbos e depois a recarga")
	race.queue_free()
	await process_frame

	print("CA-102 Burcca — Grave no Talo")
	race = await _power_race(["burcca"])
	k = race.player
	_put(k, 200, 0.0, 0.0)
	var close_k = race.karts[0]
	var far_k = race.karts[1]
	_put(close_k, 204, 2.0, 0.0)
	_put(far_k, 230, 0.0, 0.0)
	k.cheese = 10
	_press_power(k)
	check(close_k.spin_time > 0.0 and far_k.spin_time == 0.0 and race.get_node_or_null("BassRing") != null, "derruba quem está perto (12 m), não quem está longe; onda visível")
	race.queue_free()
	await process_frame

	print("CA-103 Mugurin — Fantasma")
	race = await _power_race(["mugurin"])
	k = race.player
	k.cheese = 10
	_press_power(k)
	k.hit(1.0)
	k.trap()
	check(k.ghost_time > 3.9 and k.spin_time == 0.0 and k.trap_time == 0.0, "nada acerta o fantasma")
	var other = race.karts[0]
	_put(k, 300, 0.0, 0.0)
	_put(other, 300, 0.5, 0.0)
	var before: Vector3 = other.position
	race._kart_collisions()
	check(other.position == before, "atravessa os outros karts")
	k.step(1.0 / 60.0, true)
	check(k.ghost_meshes.size() > 0 and k.ghost_meshes[0].transparency > 0.5, "fica transparente")
	race.queue_free()
	await process_frame

	print("CA-104 Telles — Drift Mestre")
	race = await _power_race(["telles"])
	k = race.player
	k.cheese = 10
	_press_power(k)
	_put(k, 100, 0.0, 26.0)
	Input.action_press("p1_accelerate")
	Input.action_press("p1_steer_left")
	Input.action_press("p1_drift")
	for s in 12:
		k.step(1.0 / 60.0, true)
	Input.action_release("p1_drift")
	Input.action_release("p1_steer_left")
	var charged: bool = k.drift_charge >= k.MINI_TURBO_3 or k.boost_time > 1.2
	k.step(1.0 / 60.0, true)
	Input.action_release("p1_accelerate")
	check(charged and k.boost_time > 1.2, "drift curtinho já sai com o turbo máximo")
	race.queue_free()
	await process_frame

	print("CA-105 Ortiz — Trombada")
	race = await _power_race(["ortiz"])
	k = race.player
	k.cheese = 10
	_press_power(k)
	other = race.karts[0]
	_put(k, 300, 0.0, 0.0)
	_put(other, 300, 1.5, 0.0)
	var kpos: Vector3 = k.position
	race._kart_collisions()
	check(k.ram_time > 3.9 and other.spin_time > 0.0 and k.position.distance_to(kpos) < 0.2, "quem encosta roda e o Ortiz quase não se mexe")
	race.queue_free()
	await process_frame

	print("CA-106 Digão — Mão Leve")
	race = await _power_race(["digao"])
	k = race.player
	k.cheese = 10
	k.rank = 5
	var victim = race.karts[0]
	for o in race.karts:
		if o != k:
			o.item = ""
			o.rank = 8
	victim.rank = 4
	victim.give_item("bomba")
	victim.item_roll = 0.0
	_press_power(k)
	check(k.item == "bomba" and victim.item == "", "rouba o item de quem está logo à frente")
	k.item = ""
	k.power_cd = 0.0
	k.cheese = 10
	_press_power(k)
	check(k.item == "triplo", "ninguém com item: ganha Queijo Triplo")
	race.queue_free()
	await process_frame

	print("CA-107 IA usa os poderes")
	var r2 = load("res://scripts/race.gd").new()
	r2.use_game_settings = false
	r2.autopilot_player = true
	r2.player_chars = ["nanni"]
	r2.track_id = "queijo"
	r2.laps = 3
	root.add_child(r2)
	if r2.karts.is_empty():
		await process_frame
	r2.state = "racing"
	r2.countdown = 0.0
	var tt := 0.0
	while tt < 40.0:
		for kk in r2.karts:
			kk.cheese = 10
		r2.step(1.0 / 60.0)
		tt += 1.0 / 60.0
	var users: int = r2.karts.filter(func(kk): return kk.powers_used > 0).size()
	check(users >= 6, "%d de 8 pilotos da IA usaram o poder em 40 s" % users)
	var hud = r2.huds[0]
	hud.update_hud(1.0 / 60.0)
	check(hud.lbl_power.text != "" and r2.player.power_name().to_upper() in hud.lbl_power.text, "HUD mostra o poder (%s)" % hud.lbl_power.text)
	r2.queue_free()
	await process_frame


## Giro (rad/s) medido em 0,5 s: drift (com o direcional "dentro", neutro) ou curva normal.
func _yaw_rate(race, drift: bool, steer: float) -> float:
	var k = race.player
	_put(k, 60, 0.0, 26.0)
	k.speed = 26.0
	var h0: float = k.heading
	Input.action_press("p1_accelerate")
	if drift:
		Input.action_press("p1_steer_left")
		Input.action_press("p1_drift")
		for s in 4:  # entra no drift
			k.step(1.0 / 60.0, true)
		Input.action_release("p1_steer_left")
		if steer < 0.0:
			Input.action_press("p1_steer_left")
		h0 = k.heading
	else:
		Input.action_press("p1_steer_left")
	for s in 30:
		k.speed = 26.0
		k.step(1.0 / 60.0, true)
	var rate := absf(wrapf(k.heading - h0, -PI, PI)) / 0.5
	for a in ["p1_accelerate", "p1_steer_left", "p1_drift"]:
		Input.action_release(a)
	return rate


func _test_drift_vs_turn() -> void:
	print("CA-108 drift não gira mais que uma curva normal (estilo Mario Kart)")
	var race = await _power_race(["telles"])
	var normal := _yaw_rate(race, false, -1.0)
	var drift_in := _yaw_rate(race, true, -1.0)
	var drift_mid := _yaw_rate(race, true, 0.0)
	check(drift_in <= normal * 0.92, "fechando o drift: %.2f rad/s x curva normal %.2f" % [drift_in, normal])
	check(drift_mid <= normal * 0.65 and drift_mid > 0.1, "drift solto (sem direcional) é um arco aberto: %.2f rad/s" % drift_mid)
	race.queue_free()
	await process_frame
