extends "res://tests/suites/t3_ui.gd"
## Testes — pistas e pilotagem: zonas e perigos, drift, Parquinho, resgate, Geladeira, Telhados, Feira, pistas refeitas.
## (camada de run_tests.gd — ver o topo de run_tests.gd)


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
	race.race_time = HzFlame.WARN + 0.3 - float(fs["phase"])
	_put(k, int(fs["idx"]), float(fs["lats"][1]), 0.0)
	k.spin_time = 0.0
	race._update_track_hazards(dt, true)
	check(fh["state"] == "on" and k.spin_time > 0.0, "labareda acesa roda o kart")
	race.race_time = HzFlame.WARN + float(fs["on"]) + 0.3 - float(fs["phase"])
	k.spin_time = 0.0
	race._update_track_hazards(dt, true)
	check(fh["state"] == "off" and k.spin_time == 0.0, "labareda apagada não faz nada")
	race.state = "countdown"
	race.race_time = HzFlame.WARN + 0.3 - float(fs["phase"])
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
		seed(20261119)  # IA determinística: o teste não oscila com a sorte
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
	k.position -= race.track.tangents[si] * (HzSeesaw.HALF - 0.2)
	k.airborne = false
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.airborne and k.vy > 5.0 and k.spin_time == 0.0, "gangorra na rampa lança o kart (vy %.1f)" % k.vy)
	race.hazard_clock = period * 0.75 - phase
	race._update_track_hazards(0.0, false)
	check(ss["state"] == "wall", "ponta de trás no alto = parede")
	_put(k, si, float(ss["mid"]), 22.0)
	k.position -= race.track.tangents[si] * (HzSeesaw.HALF - 0.2)
	k.airborne = false
	k.position.y = 0.0
	k.spin_time = 0.0
	race._update_track_hazards(0.0, true)
	check(k.spin_time > 0.0 and not k.airborne, "gangorra levantada derruba o kart")
	_put(k, si, -float(ss["mid"]), 22.0)
	k.position -= race.track.tangents[si] * (HzSeesaw.HALF - 0.2)
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
	seed(20261119)
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
	seed(20261119)
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
	seed(20261119)
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


func _test_start_lights() -> void:
	print("CA-110 semáforo da largada acompanha a contagem")
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "queijo"
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	var t = race.track
	check(t.start_lamps.size() == 3 and t.get_node_or_null("StartGantry/StartLights") != null, "pórtico com 3 lâmpadas")
	var seen := []
	var dt := 1.0 / 60.0
	for i in 240:
		race.step(dt)
		var lit := 0
		var green := true
		for m in t.start_lamps:
			if m.emission_energy_multiplier > 0.0:
				lit += 1
			if not m.albedo_color.is_equal_approx(t.LAMP_GREEN):
				green = false
		var tag := "verde" if green and lit == 3 else "%d" % lit
		if seen.is_empty() or seen[-1] != tag:
			seen.append(tag)
	check(seen.slice(0, 4) == ["1", "2", "3", "verde"], "acende 1, 2, 3 vermelhas e fica verde no VAI! %s" % str(seen))
	for i in 150:
		race.step(dt)
	var off: bool = t.start_lamps.all(func(m): return m.emission_energy_multiplier == 0.0)
	check(off, "depois de 2 s de corrida apaga")
	race.queue_free()
	await process_frame


func _test_headlights() -> void:
	print("CA-111 farol nas pistas noturnas")
	for pair in [["cozinha", true], ["telhados", true], ["fabrica", true], ["queijo", false], ["geladeira", false]]:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.player_chars = ["nanni"]
		race.track_id = pair[0]
		race.laps = 1
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		var lit: int = race.karts.filter(func(k): return k.get_node_or_null("Headlight") is SpotLight3D).size()
		if pair[1]:
			check(lit >= 1 and race.player.get_node_or_null("Headlight") != null, "%s: farol aceso (%d karts)" % [pair[0], lit])
		else:
			check(lit == 0, "%s: de dia sem farol" % pair[0])
		race.queue_free()
		await process_frame


## Triângulos que a cena manda desenhar (multimesh e partículas contam cada cópia).
func _scene_tris(node: Node) -> int:
	var total := 0
	for n in node.find_children("*", "", true, false):
		var m: Mesh = null
		var copies := 1
		if n is MeshInstance3D:
			m = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			m = n.multimesh.mesh
			copies = n.multimesh.instance_count
		if m == null:
			continue
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			total += copies * ((idx as PackedInt32Array).size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _test_mesh_budget() -> void:
	print("CA-115 pista leve pro celular e pro navegador")
	var Gfx = load("res://scripts/gfx.gd")
	var sp := SphereMesh.new()
	var big := SphereMesh.new()
	big.radius = 8.0
	var mine := CylinderMesh.new()
	mine.radial_segments = 6
	var holder := Node3D.new()
	for m in [sp, big, mine]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		holder.add_child(mi)
	Gfx.simplify_meshes(holder)
	holder.free()
	check(sp.radial_segments == 16 and sp.rings == 8 and big.radial_segments == 32, "esfera padrão (64 lados) baixa pelo tamanho: %d/%d e grande %d" % [sp.radial_segments, sp.rings, big.radial_segments])
	check(mine.radial_segments == 6, "quem já pediu poucos lados fica como está")
	var game = root.get_node("Game")
	var q_was = game.settings["quality"]
	var worst := 0
	var worst_id := ""
	for tid in ["queijo", "deserto", "geladeira", "feira", "cozinha"]:
		game.settings["quality"] = 0 if tid == "queijo" else 2
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.player_chars = ["nanni"]
		race.track_id = tid
		race.laps = 1
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		var tris := _scene_tris(race)
		if tris > worst:
			worst = tris
			worst_id = tid
		if tid == "queijo":
			check(not race.sun_light.shadow_enabled, "gráfico BAIXO (padrão do navegador): sem sombra do sol")
		race.queue_free()
		await process_frame
	game.settings["quality"] = q_was
	check(worst < 700000, "a pista mais pesada tem %d triângulos (%s; antes passava de 2 milhões)" % [worst, worst_id])
