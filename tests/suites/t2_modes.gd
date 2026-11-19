extends "res://tests/suites/t1_core.gd"
## Testes — modos e itens: Grand Prix, itens novos, IA esperta, música, contra o relógio.
## (camada de run_tests.gd — ver o topo de run_tests.gd)


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
