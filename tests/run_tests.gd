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
	var need := "CAR'MUNDON'GO! Digão CONTRAMÃO VÁCUO 1º/8 Começar · ç ã õ é í ó ú"
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
	check(tracks_seen == game.GP_TRACKS, "pistas na ordem %s" % str(tracks_seen))
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
	race.state = "racing"
	var n: int = race.track.sample_count()
	for i in race.karts.size():
		_put(race.karts[i], (i * 70 + 200) % n, 0.0, 0.0)
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
	for style in ["menu", "queijo", "deserto", "cozinha", "victory"]:
		var t0 := Time.get_ticks_msec()
		var w: AudioStream = Sfx.music(style)
		var secs: float = w.get_length()
		print("     %-8s %.1f s de música (%s), %d ms" % [style, secs, w.resource_name.get_file(), Time.get_ticks_msec() - t0])
		var looped: bool = w.loop if "loop" in w else (w is AudioStreamWAV and w.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if not looped or secs < 8.0:
			ok = false
		sigs[w.resource_name] = true
	check(ok and sigs.size() == 5, "5 trilhas em loop, > 8 s e diferentes entre si")
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
	print("CA-46 menu só com controle")
	check(_pad(JOY_BUTTON_A).is_action_pressed("ui_accept") and _pad(JOY_BUTTON_B).is_action_pressed("ui_cancel"), "A = ui_accept e B = ui_cancel (botões focados funcionam no controle)")
	var menu = await _new_menu()
	var up := JOY_BUTTON_DPAD_UP
	var down := JOY_BUTTON_DPAD_DOWN
	var right := JOY_BUTTON_DPAD_RIGHT
	var a := JOY_BUTTON_A
	# cartas -> opções (fileira de baixo leva pra linha de opções)
	menu._input(_pad(down))
	menu._input(_pad(down))
	check(menu.nav_zone == 2 and menu.get_viewport().gui_get_focus_owner() == menu.nav_rows[2][menu.nav_i], "↓↓ leva o foco pra linha de opções")
	menu._focus_zone(2, 1)  # VOLTAS
	var laps0: int = menu.laps_i
	menu._input(_pad(a))
	check(menu.laps_i == (laps0 + 1) % menu.LAP_OPTIONS.size(), "A em VOLTAS troca as voltas")
	menu._input(_pad(right))
	var diff0: int = menu.diff_i
	menu._input(_pad(a))
	check(menu.nav_i == 2 and menu.diff_i != diff0, "→ vai pra IA e A troca a dificuldade")
	menu._input(_pad(right))
	var tr0: int = menu.track_i
	menu._input(_pad(a))
	check(menu.track_i != tr0, "→ PISTA e A troca a pista")
	menu._input(_pad(up))
	check(menu.nav_zone == 1, "↑ volta pras cartas")
	menu._input(_pad(up))
	menu._input(_pad(up))
	check(menu.nav_zone == 0, "↑ da fileira de cima vai pra MODO/CONFIGURAÇÕES")
	menu._focus_zone(0, 0)
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.MODE_IDS[menu.mode_i] == "tt" and menu.players_btn.disabled, "A em MODO chega no CONTRA O RELÓGIO (JOGADORES travado)")
	menu._input(_pad(right))
	menu._input(_pad(a))
	check(menu.settings_overlay != null, "A em CONFIGURAÇÕES abre a tela")
	if menu.settings_overlay:
		menu.settings_overlay._unhandled_input(_pad(JOY_BUTTON_B))
	await process_frame
	check(menu.settings_overlay == null, "B fecha as configurações")
	menu._focus_zone(2, 0)
	check(menu.nav_rows[2][menu.nav_i] != menu.players_btn, "foco pula botão desativado")
	menu._focus_zone(2, 4)
	menu._input(_pad(a))
	check(menu.started and game.is_tt() and game.track_id == menu.TrackScript.TRACKS[menu.track_i]["id"], "A em CORRER! começa (modo %s, pista %s)" % [game.mode, game.track_id])
	menu.queue_free()
	await process_frame

	print("CA-47 voltar (B)")
	game.mode = "race"
	game.num_players = 2
	menu = await _new_menu()
	menu._input(_pad(a))
	check(menu.picks.size() == 1, "J1 confirmou")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.picks.is_empty() and menu.nav_zone == 1, "B desfaz o piloto")
	menu._focus_zone(2, 1)
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.nav_zone == 1 and menu.get_viewport().gui_get_focus_owner() == null, "B sai das opções pras cartas")
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
			for t in menu.TrackScript.TRACKS.size():  # o nome de pista mais longo
				if menu.TrackScript.TRACKS[t]["name"].length() > menu.TrackScript.TRACKS[menu.track_i]["name"].length():
					menu.track_i = t
			menu._refresh()
			await process_frame
			await process_frame
			var bad := []
			_all_inside(menu, Rect2(Vector2.ZERO, sz), bad)
			check(bad.is_empty(), "menu (%s) em %s %s" % [mode, label, str(bad.slice(0, 3))])
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
