extends SceneTree
## Testes — base: contador de falhas, check() e os ajudantes (corrida, menu, eventos de entrada, karts).
## (camada de run_tests.gd — ver o topo de run_tests.gd)


const HzFlame = preload("res://scripts/hazards/flame.gd")
const HzSeesaw = preload("res://scripts/hazards/seesaw.gd")
## Testes headless dos critérios de aceite (SPEC.md §8).
## godot --headless --path . --script tests/run_tests.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		printerr("  FAIL ", msg)


## Par de amostras (i, j) dentro da região de um cruzamento declarado da pista?
func _at_crossing(t, i: int, j: int) -> bool:
	var n: int = t.sample_count()
	for c in t.crossings:
		var a := absi(wrapi(i - int(c[0]), -n / 2, n / 2)) < 20 and absi(wrapi(j - int(c[1]), -n / 2, n / 2)) < 20
		var b := absi(wrapi(j - int(c[0]), -n / 2, n / 2)) < 20 and absi(wrapi(i - int(c[1]), -n / 2, n / 2)) < 20
		if a or b:
			return true
	return false


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


## Coloca o kart k na amostra idx/lateral, andando reto a `spd`.
func _put(k, idx: int, lat: float, spd: float) -> void:
	k.place(idx, lat)
	k.speed = spd
	k.vel = k.forward() * spd
	k.boost_time = 0.0


func _has_part(n: Node, part: String) -> bool:
	# o piloto da corrida tem as peças juntadas numa malha só (RF-479): os nomes ficam em meta("parts")
	return n.find_child(part, true, false) != null or part in n.get_meta("parts", [])


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


## CA-49: tudo dentro da área visível em 16:9, 4:3 e 21:9 (tamanho lógico com stretch "expand").
func _all_inside(n: Node, area: Rect2, bad: Array) -> void:
	if n is Control and n.is_visible_in_tree() and (n is Button or n is PanelContainer or n is Label):
		var r: Rect2 = n.get_global_rect()
		if r.size.x > 0.0 and not area.grow(1.0).encloses(r):
			bad.append("%s '%s' %s" % [n.get_class(), (n.text if "text" in n else n.name), r])
	for c in n.get_children():
		_all_inside(c, area, bad)


func _keyev(code: int, loc := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.location = loc
	e.pressed = true
	return e


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


## Textos das linhas do placar (pra achar "correndo" e os tempos).
func _result_texts(hud) -> Array:
	var out := []
	for row in hud.results_rows.get_children():
		for c in row.get_children():
			if c is Label:
				out.append(c.text)
	return out


func _stick(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = v
	e.device = 0
	return e


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


func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()
