extends "res://tests/suites/t4_tracks.gd"
## Testes — poderes dos pilotos e segurança dos arquivos do jogador.
## (camada de run_tests.gd — ver o topo de run_tests.gd)


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


func _test_safe_files() -> void:
	print("CA-109 arquivo trocado não roda código (settings e recordes)")
	var game = root.get_node_or_null("Game")
	var evil_gd := "user://_evil.gd"
	var pwned := "user://_pwned.txt"
	if FileAccess.file_exists(pwned):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pwned))
	_write(evil_gd, "extends Node\nfunc _init():\n\tvar f := FileAccess.open(\"%s\", FileAccess.WRITE)\n\tf.store_string(\"x\")\n" % pwned)
	var payload := "Object(Node,\"script\":Resource(\"%s\"))" % ProjectSettings.globalize_path(evil_gd)
	# configurações
	var old_path: String = game.settings_path
	var sp := "user://_evil_settings.cfg"
	_write(sp, "[settings]\nfov=70.0\nhack=%s\n" % payload)
	game.settings_path = sp
	game.load_settings()
	check(not FileAccess.file_exists(pwned), "settings.cfg com script embutido: o código NÃO rodou")
	check(FileAccess.file_exists(sp + ".bloqueado") and not FileAccess.file_exists(sp), "arquivo suspeito vira .bloqueado")
	check(is_equal_approx(float(game.settings["fov"]), float(game.DEFAULTS["fov"])), "e o jogo segue com o padrão")
	# valores fora da faixa e teclas lixo
	_write(sp, "[settings]\nfov=9999.0\nrender_scale=-5.0\nvol_music=3.0\nspeed_unit=\"xyz\"\n[keys]\np1_drift=\"lixo\"\np1_hackear=[[65]]\n")
	game.load_settings()
	check(float(game.settings["fov"]) <= 110.0 and float(game.settings["render_scale"]) >= 0.5 and float(game.settings["vol_music"]) <= 1.0 and game.settings["speed_unit"] == "kmh", "números fora da faixa são corrigidos")
	check(not game.key_binds.has("p1_drift") and not game.key_binds.has("p1_hackear"), "teclas inválidas são ignoradas")
	game.settings_path = old_path
	game.load_settings()
	# recordes
	var Records = load("res://scripts/records.gd")
	var old_rec: String = Records.path
	var rp := "user://_evil_records.cfg"
	_write(rp, "[queijo@2]\nrace_time=50.0\nghost=%s\n" % payload)
	Records.path = rp
	var rec: Dictionary = Records.get_record("queijo")
	check(not FileAccess.file_exists(pwned) and rec.is_empty(), "records.cfg com script embutido: não roda e não é usado")
	_write(rp, "[queijo@2]\nrace_time=-3.0\nlap_time=40.0\nrace_char=\"ninguem\"\nghost=PackedFloat32Array(1, 2, 3)\n")
	rec = Records.get_record("queijo")
	check(not rec.has("race_time") and rec.get("lap_time", 0.0) == 40.0 and not rec.has("race_char") and not rec.has("ghost"), "recorde com campos inválidos: só o que é válido passa")
	Records.path = old_rec
	for p in [sp, sp + ".bloqueado", rp, rp + ".bloqueado", evil_gd, pwned]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
