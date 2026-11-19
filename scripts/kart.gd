extends Node3D
## Kart: física arcade (sem motor de física), drift + mini-turbo, IA e visual procedural.
## Frente do kart = -Z local. heading = rotação em Y.

const TrackScript = preload("res://scripts/track.gd")
const GameScript = preload("res://scripts/game.gd")
const Chars = preload("res://scripts/characters.gd")
const Gfx = preload("res://scripts/gfx.gd")
const MouseModel = preload("res://scripts/mouse_model.gd")
const KenneyKart = preload("res://assets/kenney/karts/kart-oopi.glb")
const RecolorShader = preload("res://shaders/kart_recolor.gdshader")
const KART_SCALE := 2.3
const ShieldShader = preload("res://shaders/shield.gdshader")
const LABEL_LAYER_BASE := 10  # camada do nome do jogador N = 10+N (escondida na câmera dele)

const DRIFT_MIN_SPEED := 12.0
const MINI_TURBO_1 := 0.7
const MINI_TURBO_2 := 1.5
const MINI_TURBO_3 := 2.4   # RF-143
const GRAVITY := 28.0
const PAD_BOOST := 0.8
const TRICK_BOOST := 0.7
const ITEM_ROLL := 1.0      # roleta (RF-130)
const SHIELD_TIME := 8.0    # RF-203
const TRAP_TIME := 1.2      # RF-202
const MAX_CHEESE := 10
const ITEM_BOOST := 1.3
const DRIFT_TURN_MIN := 0.45  # RF-280: giro no drift (× turn_rate) abrindo a curva...
const DRIFT_TURN_MAX := 1.05  # ...e fechando
const DRIFT_GRIP := 6.0
const BOOST_MULT := 1.3
const OFFROAD_MULT := 0.5
const RADIUS := 1.0

var track: Node3D
var race: Node

var char_id := ""
var display_name := ""
var color := Color.WHITE
var is_player := false
var player_index := -1  # 0..3 para humanos, -1 para IA
var autopilot := true

# stats (SPEC §3)
var max_speed := 28.0
var accel := 16.0
var turn_rate := 2.0
var weight := 3.0
var ai_skill := 1.0
var rubber := 1.0

# estado
var heading := 0.0
var speed := 0.0
var vel := Vector3.ZERO
var track_idx := 0
var lateral := 0.0
var progress := 0.0
var finished := false
var finish_time := 0.0
var rank := 1
var max_abs_lateral := 0.0

var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var spin_time := 0.0
var hop_time := 0.0
var item := ""
var item_hold := 0.0
var items_used := 0
var stuck_time := 0.0
var ai_lane := 0.0
var ai_lane_timer := 0.0
var ai_item_delay := 3.0

# largada (RF-85..87)
const START_WINDOW_EARLY := 1.6
const START_WINDOW_LATE := 0.6
var start_hold := -1.0     # countdown no momento em que começou a segurar o acelerador
var start_stall := 0.0
var start_result := ""     # "" | "turbo" | "queimou"
var zone_kind := ""         # RF-270: farofa | sand | belt | belt_side | grill | ""

# RF-310..313: resgate — um cacho de balões leva o kart preso (ou que caiu) de volta pra pista
const RESCUE_TIME := 1.3       # total, sem controle
const RESCUE_LIFT := 0.5       # subindo no lugar; depois desce no ponto seguro
const RESCUE_HEIGHT := 6.0
const RESCUE_GHOST := 1.2      # depois de pousar: pisca e nada acerta
const STUCK_AI_TIME := 2.5
const STUCK_PLAYER_TIME := 3.0
const STUCK_MOVE := 1.5        # m/s: andando menos que isso querendo andar = preso
const FALL_Y := -3.0           # abaixo disso caiu (vãos das pistas futuras)
const WRONG_WAY_SHOW := 1.0
var rescue_time := 0.0
var rescue_ghost := 0.0
var rescue_from := Vector3.ZERO
var rescue_idx := 0
var rescue_moved := false
var rescues := 0
var safe_idx := 0
var wrong_way_time := 0.0
var last_pos := Vector3.ZERO
var balloons: Node3D

# RF-320..323: altura, looping (trilho) e gelo
const LOOP_MIN_SPEED := 20.0   # no looping o kart vai grudado e nunca para
const LOOP_STEER := 7.0        # m/s de troca de faixa dentro do looping
const ICE_GRIP := 1.6
var ground := 0.0              # altura do chão da pista embaixo do kart
var on_loop := false
var loop_s := 0.0              # posição no looping em amostras (com fração)
var loops_done := 0
var pitch := 0.0

# v0.8: ar/rampa, manobra, queijinhos, vácuo, roleta
var vy := 0.0
var airborne := false
var on_ramp := false
var trick := false
var trick_spin := 0.0
var air_time := 0.0
var max_height := 0.0
var cheese := 0
var slip_time := 0.0
var slip_flash := 0.0
var item_roll := 0.0
var ai_trick_chance := 0.7
var ai_pad_target := -1
# RF-213: personalidade (0..1)
var ai_aggro := 0.5
var ai_avoid := 0.5
var ai_focus := 0.5
var ai_drift := 0.5
var ai_box_skip := false
var ai_evading := 0.0
var ai_seen := {}   # perigo (instance id) -> se a IA decidiu desviar
var prev_drift := false
var on_pad := false
var bump_cd := 0.0
var shield_time := 0.0
var trap_time := 0.0
var item_charges := 0
var shield_bubble: MeshInstance3D

# input do frame
var in_throttle := 0.0
var in_steer := 0.0
var in_drift := false
var in_item := false

# visual
var model: Node3D
var sparks: Array = []
var flames: Array = []
var p_flame: CPUParticles3D
var p_dust: CPUParticles3D
var p_smoke: CPUParticles3D
var p_stars: CPUParticles3D
var p_land: CPUParticles3D
var p_confetti: CPUParticles3D

var wheels: Array = []        # MeshInstance3D (giram)
var front_wheels: Array = []  # MeshInstance3D (esterçam)
var kart_body: MeshInstance3D
var driver: Node3D
var name_label: Label3D
var wheel_spin := 0.0


func setup(data: Dictionary, p_index: int, track_ref: Node3D, race_ref: Node) -> void:
	track = track_ref
	race = race_ref
	char_id = data["id"]
	display_name = data["name"]
	color = data["color"]
	player_index = p_index
	is_player = p_index >= 0
	autopilot = not is_player
	max_speed = 22.0 + float(data["speed"]) * 1.6
	accel = 9.0 + float(data["accel"]) * 2.2
	turn_rate = 1.55 + float(data["handling"]) * 0.16
	weight = 1.0 + float(data["weight"])
	var ai: Dictionary = data.get("ai", {})
	ai_aggro = float(ai.get("aggro", 0.5))
	ai_avoid = float(ai.get("avoid", 0.5))
	ai_focus = float(ai.get("focus", 0.5))
	ai_drift = float(ai.get("drift", 0.5))
	_build_model()


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func rank_value() -> float:
	return progress + track.along_of(position, track_idx) / TrackScript.SPACING


func place(idx: int, lat: float) -> void:
	var n: int = track.sample_count()
	track_idx = idx
	position = track.points[idx] + track.rights[idx] * lat
	heading = track.heading_at(idx)
	rotation.y = heading
	progress = float(idx - n) if idx > n / 2 else float(idx)
	safe_idx = idx
	last_pos = position
	on_loop = false
	ground = position.y
	wrong_way_time = 0.0
	stuck_time = 0.0
	speed = 0.0
	vel = Vector3.ZERO
	lateral = lat
	reset_physics_interpolation()


## RF-203: o escudo segura um ataque. Devolve true se absorveu.
func _shield_absorbs() -> bool:
	if shield_time <= 0.0:
		return false
	shield_time = 0.0
	if is_player:
		race.sfx("shield_break")
	return true


## RF-202: preso na ratoeira — para na hora e fica TRAP_TIME sem andar.
func trap() -> void:
	if trap_time > 0.0 or is_rescued() or _shield_absorbs():
		return
	trap_time = TRAP_TIME
	drifting = false
	boost_time = 0.0
	speed = 0.0
	vel = Vector3.ZERO
	cheese = maxi(0, cheese - 3)
	race.shake(self, 0.4)
	if is_player:
		race.sfx("snap")


func hit(strength := 1.0) -> void:
	if spin_time > 0.0 or is_rescued() or _shield_absorbs():
		return
	spin_time = 1.1 * strength
	drifting = false
	boost_time = 0.0
	speed *= 0.35
	cheese = maxi(0, cheese - 3)  # RF-150
	if p_smoke:
		p_smoke.restart()
		p_stars.restart()
	race.shake(self, 0.5)
	if is_player:
		race.sfx("hit")


## Velocidade máxima atual sem turbo/grama (stats + queijinhos + IA).
func top_speed() -> float:
	var top := max_speed * (1.0 + 0.01 * cheese)
	if autopilot and not is_player:
		top *= ai_skill * rubber
	return top


func give_item(it: String) -> void:
	item = it
	item_hold = 0.0
	item_roll = ITEM_ROLL
	item_charges = 3 if it == "triplo" else 1  # RF-204


func can_use_item() -> bool:
	return item != "" and item_roll <= 0.0 and spin_time <= 0.0


## Chamado pela corrida no VAI! (RF-85..87).
func on_race_start() -> void:
	if autopilot:
		if randf() < 0.35:
			start_result = "turbo"
	elif start_hold > START_WINDOW_EARLY:
		start_result = "queimou"
	elif start_hold >= START_WINDOW_LATE:
		start_result = "turbo"
	if start_result == "turbo":
		boost_time = maxf(boost_time, 1.0)
	elif start_result == "queimou":
		start_stall = 0.7


func _track_start_hold() -> void:
	if autopilot or race.state != "countdown":
		return
	if in_throttle > 0.5:
		if start_hold < 0.0:
			start_hold = race.countdown
	else:
		start_hold = -1.0


func step(delta: float, can_drive: bool) -> void:
	in_item = false
	if can_drive and rescue_time > 0.0:
		_update_rescue(delta)
		_update_visuals(delta)
		return
	if can_drive and rescue_ghost > 0.0:
		rescue_ghost = maxf(0.0, rescue_ghost - delta)
	if autopilot:
		_ai_input(delta)
	else:
		_player_input()
	if not can_drive:
		_track_start_hold()
	if can_drive:
		_move(delta)
		_update_track(delta)
		_update_air(delta)
		bump_cd = maxf(0.0, bump_cd - delta)
		if item_roll > 0.0:
			item_roll -= delta
		if in_item and can_use_item():
			race.use_item(self, item)
			items_used += 1
			item_charges -= 1
			if item_charges <= 0:
				item = ""
				ai_box_skip = randf() > 0.4 + 0.6 * ai_aggro  # RF-212
			else:
				item_hold = 0.0
		if shield_time > 0.0:
			shield_time = maxf(0.0, shield_time - delta)
		if item != "" and item_roll <= 0.0:
			item_hold += delta
	prev_drift = in_drift
	_update_visuals(delta)


# ---------------------------------------------------------------- movimento

func _move(delta: float) -> void:
	if on_loop:
		_move_loop(delta)
		return
	var throttle := in_throttle
	var steer := in_steer
	if spin_time > 0.0:
		spin_time -= delta
		throttle = 0.0
		steer = 0.0
		speed = move_toward(speed, 0.0, 30.0 * delta)
	if trap_time > 0.0:  # RF-202: preso
		trap_time -= delta
		throttle = 0.0
		steer = 0.0
		speed = 0.0
	if start_stall > 0.0:
		start_stall -= delta
		throttle = 0.0

	var top := top_speed()
	if not airborne and absf(lateral) > TrackScript.ROAD_HALF + TrackScript.CURB and boost_time <= 0.0:
		top *= OFFROAD_MULT
	# seta de turbo (RF-140)
	var pad_now: bool = not airborne and track.on_pad(track_idx, lateral)
	if pad_now and not on_pad:
		boost_time = maxf(boost_time, PAD_BOOST)
		if is_player:
			race.sfx("pad")
	on_pad = pad_now
	# RF-270: zonas de superfície (no ar não valem)
	var zone: Dictionary = {} if airborne else track.zone_at(track_idx, lateral)
	zone_kind = String(zone.get("kind", ""))
	if zone_kind == "farofa" and boost_time <= 0.0:
		top *= TrackScript.FAROFA_MULT
	elif zone_kind == "sand" and boost_time <= 0.0:  # RF-301: caixa de areia
		top *= TrackScript.SAND_MULT
	elif zone_kind == "belt":
		top *= 1.15
	elif zone_kind == "ice":
		top *= 1.05
	if boost_time > 0.0:
		boost_time -= delta
		top *= BOOST_MULT
		speed = move_toward(speed, top, 60.0 * delta)

	if throttle > 0.0:
		if speed < top:
			speed = minf(speed + accel * throttle * delta, top)
	elif throttle < 0.0:
		if speed > 0.0:
			speed = maxf(speed + 35.0 * throttle * delta, 0.0)
		else:
			speed = maxf(speed + accel * 0.5 * throttle * delta, -8.0)
	else:
		speed = move_toward(speed, 0.0, 6.0 * delta)
	if speed > top:
		speed = move_toward(speed, top, 25.0 * delta)

	# drift (RF-13/14)
	if not drifting and not airborne and in_drift and absf(steer) > 0.3 and speed > DRIFT_MIN_SPEED and spin_time <= 0.0:
		drifting = true
		drift_dir = signf(steer)
		drift_charge = 0.0
		hop_time = 0.25
	if drifting and (not in_drift or speed < DRIFT_MIN_SPEED * 0.6 or spin_time > 0.0):
		drifting = false
		# RF-280: ao soltar, o kart sai alinhado pra onde aponta (o turbo empurra reto)
		vel = forward() * speed
		if spin_time <= 0.0:
			if drift_charge >= MINI_TURBO_1 and is_player:
				race.sfx("mini_turbo")
			if drift_charge >= MINI_TURBO_3:
				boost_time = maxf(boost_time, 1.6)
			elif drift_charge >= MINI_TURBO_2:
				boost_time = maxf(boost_time, 1.1)
			elif drift_charge >= MINI_TURBO_1:
				boost_time = maxf(boost_time, 0.6)
		drift_charge = 0.0

	var speed_factor := clampf(absf(speed) / 8.0, 0.0, 1.0) * signf(speed)
	if drifting:
		var into := (steer * drift_dir + 1.0) * 0.5
		var amount := lerpf(DRIFT_TURN_MIN, DRIFT_TURN_MAX, into)  # RF-280: mais suave
		heading -= drift_dir * amount * turn_rate * delta
		drift_charge += delta * (0.6 + 0.8 * into)
	else:
		var high_speed_damp := lerpf(1.0, 0.8, clampf(speed / max_speed, 0.0, 1.0))
		var air_damp := 0.35 if airborne else 1.0
		heading -= steer * turn_rate * speed_factor * high_speed_damp * air_damp * delta

	var grip := DRIFT_GRIP if drifting else (1.5 if airborne else 9.0)  # RF-280: no drift a direção segue o bico; o "de lado" é só no modelo
	if zone_kind == "ice" and not airborne:  # RF-323: gelo escorrega (a direção demora a obedecer)
		grip = ICE_GRIP * (0.75 if drifting else 1.0)
	vel = vel.lerp(forward() * speed, 1.0 - exp(-grip * delta))
	position += vel * delta
	# esteiras carregam o kart (mesmo parado)
	if zone_kind == "belt":
		position += track.tangents[track_idx] * TrackScript.BELT_SPEED * float(zone["dir"]) * delta
	elif zone_kind == "belt_side":
		position += track.rights[track_idx] * TrackScript.BELT_SIDE_SPEED * float(zone["dir"]) * delta


## RF-321: dentro do looping o kart anda no trilho (grudado, como pista de carrinho):
## acelera/freia sem parar abaixo de LOOP_MIN_SPEED e troca de faixa com o direcional.
func _move_loop(delta: float) -> void:
	var n: int = track.sample_count()
	if spin_time > 0.0:
		spin_time -= delta
	var top := maxf(top_speed(), LOOP_MIN_SPEED)
	if boost_time > 0.0:
		boost_time -= delta
		top *= BOOST_MULT
		speed = move_toward(speed, top, 60.0 * delta)
	speed = clampf(speed + accel * maxf(in_throttle, 0.0) * delta, LOOP_MIN_SPEED, maxf(top, speed - 25.0 * delta))
	var steer := in_steer if not autopilot else clampf((ai_lane - lateral) * 0.4, -1.0, 1.0)
	var m := TrackScript.ROAD_HALF - 1.0
	lateral = clampf(lateral + steer * LOOP_STEER * delta, -m, m)
	loop_s += speed * delta / TrackScript.SPACING
	var i := int(loop_s)
	var f := loop_s - float(i)
	i = i % n
	if not track.in_loop(i):
		# saiu: volta pro chão alinhado com a pista
		on_loop = false
		loops_done += 1
		heading = track.heading_at(i)
		position = track.points[i] + track.rights[i] * lateral
		ground = position.y
		vel = forward() * speed
		return
	var k := (i + 1) % n
	position = track.points[i].lerp(track.points[k], f) + track.rights[i].lerp(track.rights[k], f) * lateral
	vel = track.tangents[i] * speed


## Frente e "pra cima" do kart (no looping seguem a pista; fora, o plano). A câmera usa.
func cam_frame() -> Array:
	if on_loop:
		var i: int = track_idx
		return [track.tangents[i], track.ups[i]]
	return [forward(), Vector3.UP]


## RF-141: sobe a rampa, decola, gravidade, manobra no ar e pouso.
func _update_air(delta: float) -> void:
	if not airborne:
		var f: float = track.ramp_frac(track_idx, track.along_of(position, track_idx), lateral)
		if f >= 0.0:
			on_ramp = true
			position.y = ground + f * track.ramp_height(track_idx)
		elif on_ramp:
			on_ramp = false
			if speed > 8.0:
				airborne = true
				vy = 5.0 + speed * 0.18
				air_time = 0.0
				trick = false
				if autopilot and randf() < ai_trick_chance:
					_start_trick()
			else:
				position.y = ground
		elif not on_loop and track.gap_at(track_idx):
			# RF-330: acabou o telhado: começa a cair (rápido o bastante, a rampinha já te lançou)
			airborne = true
			vy = 0.0
			air_time = 0.0
		elif not on_loop:
			position.y = ground  # RF-320: acompanha a subida e a descida da pista
		return
	air_time += delta
	if not trick and not autopilot and in_drift and not prev_drift and air_time > 0.05:
		_start_trick()
	vy -= GRAVITY * delta
	position.y += vy * delta
	max_height = maxf(max_height, position.y - ground)
	if position.y <= ground:
		if track.gap_at(track_idx):
			return  # RF-330: em cima do vão não tem onde pousar
		if position.y < ground - 0.9:
			start_rescue(true)  # bateu na parede do prédio: caiu
			return
		position.y = ground
		vy = 0.0
		airborne = false
		if air_time > 0.3:
			if p_land:
				p_land.restart()
			race.shake(self, 0.25)
		if trick:
			boost_time = maxf(boost_time, TRICK_BOOST)
			if is_player:
				race.sfx("trick")
		trick = false


func _start_trick() -> void:
	trick = true
	trick_spin = TAU
	if is_player:
		race.sfx("drop")


func _update_track(delta: float) -> void:
	var n: int = track.sample_count()
	var ni: int = track.nearest_index(position, track_idx, 12)
	var d := ni - track_idx
	if d > n / 2:
		d -= n
	elif d < -n / 2:
		d += n
	progress += d
	track_idx = ni
	lateral = track.lateral_of(position, ni)
	ground = track.ground_y(ni, track.along_of(position, ni))
	# RF-321: entrou no looping andando pra frente = vai no trilho até sair
	if not on_loop and not airborne and track.in_loop(ni) and vel.dot(track.tangents[ni]) > 0.0:
		on_loop = true
		loop_s = float(ni) + clampf(track.along_of(position, ni) / TrackScript.SPACING, 0.0, 0.99)
		drifting = false

	# muro (RF-12)
	var lim: float = track.wall_at(ni) - RADIUS
	if absf(lateral) > lim:
		var s := signf(lateral)
		var r: Vector3 = track.rights[ni]
		position -= r * s * (absf(lateral) - lim)
		var vout := vel.dot(r) * s
		if vout > 0.0:
			vel -= r * s * vout * 1.5
			speed *= clampf(1.0 - vout * 0.04, 0.4, 1.0)
			if vout > 6.0 and is_player and bump_cd <= 0.0:  # RF-144
				bump_cd = 0.4
				race.sfx("bump")
				race.shake(self, 0.3)
		speed *= 0.995
		lateral = s * lim
	max_abs_lateral = maxf(max_abs_lateral, absf(lateral))

	# RF-311: último ponto seguro (no chão, na pista, andando pra frente num trecho sem perigo)
	var tan: Vector3 = track.tangents[ni]
	if not airborne and not on_ramp and not on_loop and absf(position.y - ground) < 0.3 and absf(lateral) < TrackScript.ROAD_HALF - 1.0 and vel.dot(tan) > 2.0 and (track.safe.is_empty() or track.safe[ni] == 1):
		safe_idx = ni
	# RF-313: contramão (andando contra o sentido da pista)
	if not airborne and vel.dot(tan) < -3.0:
		wrong_way_time += delta
	else:
		wrong_way_time = maxf(0.0, wrong_way_time - delta * 3.0)
	# RF-310 (antes RF-16): preso = quer andar e não sai do lugar; caiu = abaixo do chão
	var moved := Vector2(position.x - last_pos.x, position.z - last_pos.z).length() / maxf(delta, 0.0001)
	last_pos = position
	var wants := (autopilot or absf(in_throttle) > 0.5) and not on_loop
	if wants and moved < STUCK_MOVE and spin_time <= 0.0 and trap_time <= 0.0 and start_stall <= 0.0 and not airborne:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if position.y < ground + FALL_Y:
		start_rescue(true)
	elif stuck_time > (STUCK_AI_TIME if autopilot else STUCK_PLAYER_TIME):
		start_rescue(false)


## Durante o resgate e logo depois (piscando) nada acerta o kart.
func is_rescued() -> bool:
	return rescue_time > 0.0 or rescue_ghost > 0.0


## RF-310: os balões pegam o kart. Caiu = perde 3 queijinhos; preso = sem castigo.
func start_rescue(fell := false) -> void:
	if rescue_time > 0.0:
		return
	rescue_time = RESCUE_TIME
	rescue_from = position
	rescue_idx = track.safe_before(safe_idx)
	rescue_moved = false
	rescues += 1
	on_loop = false
	speed = 0.0
	vel = Vector3.ZERO
	drifting = false
	drift_charge = 0.0
	boost_time = 0.0
	spin_time = 0.0
	trap_time = 0.0
	airborne = false
	on_ramp = false
	vy = 0.0
	trick = false
	trick_spin = 0.0
	stuck_time = 0.0
	wrong_way_time = 0.0
	if fell:
		cheese = maxi(0, cheese - 3)
	_show_balloons(true)
	if is_player:
		race.sfx("drop")


func _update_rescue(delta: float) -> void:
	rescue_time -= delta
	var t := RESCUE_TIME - rescue_time
	if t < RESCUE_LIFT:
		var f := t / RESCUE_LIFT
		position = rescue_from + Vector3.UP * RESCUE_HEIGHT * f * f
	else:
		if not rescue_moved:
			rescue_moved = true
			_jump_to(rescue_idx)
		var f := clampf((t - RESCUE_LIFT) / (RESCUE_TIME - RESCUE_LIFT), 0.0, 1.0)
		position.y = track.points[rescue_idx].y + RESCUE_HEIGHT * (1.0 - f) * (1.0 - f)
	if rescue_time <= 0.0:
		rescue_time = 0.0
		position.y = track.points[rescue_idx].y
		ground = position.y
		rescue_ghost = RESCUE_GHOST
		last_pos = position
		_show_balloons(false)


## Põe o kart no centro da amostra idx, de frente pra pista, sem estragar o progresso da volta.
func _jump_to(idx: int) -> void:
	var n: int = track.sample_count()
	var d := wrapi(idx - track_idx, -n / 2, n / 2)
	progress += d
	track_idx = idx
	position = track.points[idx] + Vector3.UP * RESCUE_HEIGHT
	heading = track.heading_at(idx)
	rotation.y = heading
	lateral = 0.0
	if model:
		model.rotation = Vector3.ZERO
	reset_physics_interpolation()


func _show_balloons(on: bool) -> void:
	if balloons == null:
		if not on:
			return
		balloons = Node3D.new()
		balloons.name = "RescueBalloons"
		var cols := [Color(0.95, 0.25, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 0.6, 1.0)]
		var spots := [Vector3(-0.9, 5.2, 0.2), Vector3(0.0, 5.9, -0.3), Vector3(0.9, 5.3, 0.25)]
		for b in 3:
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.75
			sm.height = 1.8
			ball.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = cols[b]
			mat.roughness = 0.25
			ball.material_override = mat
			ball.position = spots[b]
			balloons.add_child(ball)
			var str_mesh := CylinderMesh.new()
			str_mesh.top_radius = 0.03
			str_mesh.bottom_radius = 0.03
			var from := Vector3(0, 1.4, 0)
			var to: Vector3 = spots[b] - Vector3(0, 0.85, 0)
			str_mesh.height = from.distance_to(to)
			var string := MeshInstance3D.new()
			string.mesh = str_mesh
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.95, 0.95, 0.95)
			string.material_override = smat
			string.position = (from + to) * 0.5
			var dir := (to - from).normalized()
			var axis := Vector3.UP.cross(dir)
			if axis.length() > 0.001:
				string.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
			balloons.add_child(string)
		add_child(balloons)
	balloons.visible = on



# ---------------------------------------------------------------- input

func _player_input() -> void:
	if not InputMap.has_action(GameScript.action(player_index, "accelerate")):
		return
	# RF-67: sozinho, o J1 também usa as teclas/controle do J2
	var sources: Array = [player_index]
	if race.players.size() == 1:
		sources = [0, 1]
	in_throttle = 0.0
	in_steer = 0.0
	in_drift = false
	in_item = false
	for p in sources:
		in_throttle += Input.get_action_strength(GameScript.action(p, "accelerate")) - Input.get_action_strength(GameScript.action(p, "brake"))
		in_steer += Input.get_action_strength(GameScript.action(p, "steer_right")) - Input.get_action_strength(GameScript.action(p, "steer_left"))
		in_drift = in_drift or Input.is_action_pressed(GameScript.action(p, "drift"))
		in_item = in_item or Input.is_action_just_pressed(GameScript.action(p, "use_item"))
	in_throttle = clampf(in_throttle, -1.0, 1.0)
	in_steer = clampf(in_steer, -1.0, 1.0)


func _ai_input(delta: float) -> void:
	var n: int = track.sample_count()
	var m := TrackScript.ROAD_HALF - 2.5
	ai_lane_timer -= delta
	if ai_lane_timer <= 0.0:
		# RF-213: quem tem mais "foco" troca menos de faixa à toa
		ai_lane = clampf(lerpf(randf_range(-m, m), ai_lane, ai_focus * 0.6), -m, m)
		ai_lane_timer = randf_range(2.0, 5.0) * (1.0 + ai_focus)
	_ai_tactics(n, m)
	# desviando: olha mais perto pra esterçar mais rápido (RF-210)
	ai_evading = maxf(0.0, ai_evading - delta)
	var look := (3 + int(absf(speed) * 0.12)) if ai_evading > 0.0 else (5 + int(absf(speed) * 0.3))
	var ti := (track_idx + look) % n
	# RF-321: o alvo no meio do looping fica "atrás" no plano; mira a entrada dele
	if not on_loop and track.in_loop(ti):
		ti = int(track.loops[track.loop_id[ti]]["i0"])
	var target: Vector3 = track.points[ti] + track.rights[ti] * ai_lane
	var to := target - position
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - heading, -PI, PI)
	in_steer = clampf(-diff * 2.2, -1.0, 1.0)
	in_throttle = 0.4 if absf(diff) > 1.2 else 1.0
	var drift_start := lerpf(0.45, 0.25, ai_drift)  # RF-213: quem gosta de drift começa antes
	if drifting:
		in_drift = absf(diff) > 0.08 and signf(-diff) == drift_dir
	else:
		in_drift = absf(diff) > drift_start and speed > DRIFT_MIN_SPEED + 3.0

	# itens (RF-42 + RF-205), agressividade adianta o uso (RF-213)
	if item != "" and item_roll <= 0.0:
		var eager := lerpf(1.5, 0.5, ai_aggro)
		match item:
			"turbo", "triplo":
				in_item = item_hold > (0.8 if item == "turbo" else 1.2) * eager and absf(diff) < 0.2
			"casca", "ratoeira":
				in_item = item_hold > ai_item_delay * eager or race.kart_behind(self, 12.0 + 12.0 * ai_aggro)
			"bomba":
				in_item = item_hold > 8.0 * eager or (item_hold > 0.5 and race.kart_in_sight(self, 30.0 + 30.0 * ai_aggro))
			"escudo":
				in_item = item_hold > 1.0
			"gato":
				in_item = item_hold > 0.6 * eager


## RF-210..212: desviar > caixa > ultrapassar > setas de turbo.
func _ai_tactics(n: int, m: float) -> void:
	# desvio de casca/ratoeira
	var reach := int(10 + 14 * ai_avoid)
	for hz in race.ground_hazards_ahead(self, reach):
		var id: int = hz["id"]
		if not ai_seen.has(id):
			ai_seen[id] = randf() < 0.25 + 0.75 * ai_avoid
		if ai_seen[id] and absf(float(hz["lat"]) - ai_lane) < 2.8:
			var lat: float = hz["lat"]
			var side := -1.0 if lat > 0.0 else 1.0
			ai_lane = clampf(lat + side * 4.5, -m, m)
			ai_evading = 1.0
			ai_lane_timer = maxf(ai_lane_timer, 1.2)
			return
	# caixa de item
	if item == "" and not ai_box_skip:
		var box_lat: float = race.box_ahead(self, 30)
		if not is_nan(box_lat):
			ai_lane = clampf(box_lat, -m, m)
			ai_lane_timer = maxf(ai_lane_timer, 0.8)
			return
	# ultrapassagem
	var slow_lat: float = race.slow_kart_ahead(self, 10.0, 2.5)
	if not is_nan(slow_lat):
		var side := 1.0 if slow_lat < 0.0 else -1.0
		ai_lane = clampf(slow_lat + side * 4.0, -m, m)
		ai_lane_timer = maxf(ai_lane_timer, 1.5)
		return
	# RF-140: às vezes mira na seta de turbo à frente
	for p in track.pads:
		var dp := wrapi(int(p["idx"]) - track_idx, 0, n)
		if dp > 4 and dp < 25 and ai_pad_target != int(p["idx"]):
			ai_pad_target = int(p["idx"])
			if randf() < 0.5:
				ai_lane = float(p["lat"])
				ai_lane_timer = 3.0


# ---------------------------------------------------------------- visual

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	model.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## RF-170: kart do Car Kit (Kenney, CC0) recolorido + camundongo do RF-171 no assento.
func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var kart_root: Node3D = KenneyKart.instantiate()
	kart_root.name = "KenneyKart"
	kart_root.rotation.y = PI  # o modelo olha pra +Z; o nosso kart olha pra -Z
	kart_root.scale = Vector3.ONE * KART_SCALE
	model.add_child(kart_root)
	for mi in kart_root.find_children("*", "MeshInstance3D", true, false):
		var n: String = mi.name
		if n == "character":
			mi.visible = false  # piloto original do kit
		elif n.begins_with("wheel"):
			wheels.append(mi)
			if n.contains("front"):
				front_wheels.append(mi)
		elif n.begins_with("kart"):
			var src: Material = mi.mesh.surface_get_material(0)
			var sm := ShaderMaterial.new()
			sm.shader = RecolorShader
			if src is BaseMaterial3D:
				sm.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture)
			sm.set_shader_parameter("tint", color)
			mi.material_override = sm
			kart_body = mi
	# número do grid nas laterais
	var number := str(Chars.index_of(char_id) + 1)
	for side in [-1.0, 1.0]:
		var num := Label3D.new()
		num.text = number
		num.font_size = 96
		num.pixel_size = 0.005
		num.modulate = Color(1, 1, 1)
		num.outline_size = 18
		num.outline_modulate = Color(0.05, 0.05, 0.08)
		num.position = Vector3(side * 1.08, 0.55, 0.35)
		num.rotation.y = PI / 2.0 * side
		num.double_sided = false  # sem número espelhado
		model.add_child(num)
	# piloto
	var look: Dictionary = Chars.find(char_id).get("look", {})
	driver = MouseModel.build(look)
	driver.position = Vector3(0, 0.62, 0.2)
	model.add_child(driver)
	var head_top := 2.75
	var lbl := Label3D.new()
	name_label = lbl
	lbl.text = display_name
	lbl.font_size = 40
	lbl.outline_size = 14
	lbl.pixel_size = 0.0009
	lbl.fixed_size = true
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color.lightened(0.25)
	lbl.position = Vector3(0, head_top + 0.35, 0)
	if is_player:
		lbl.layers = 1 << (LABEL_LAYER_BASE + player_index)  # RF-63
	add_child(lbl)
	# chama do turbo + partículas (RF-165)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.8
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.6, 0.7, 0.15)
	for x in [-0.3, 0.3]:
		var f := _part(cone, flame_mat, Vector3(x, 0.75, 1.85), Vector3(PI / 2, 0, 0))
		f.visible = false
		flames.append(f)
	_build_particles()


func _build_particles() -> void:
	for x in [-0.95, 0.95]:
		var s := Gfx.particles("sparks")
		s.position = Vector3(x, 0.15, 1.1)
		model.add_child(s)
		sparks.append(s)
	p_flame = Gfx.particles("flame")
	p_flame.position = Vector3(0, 0.78, 1.75)
	model.add_child(p_flame)
	var dust_c: Color = track.def.get("offroad", Color(0.5, 0.45, 0.3)) if track else Color(0.5, 0.45, 0.3)
	p_dust = Gfx.particles("dust", dust_c.lightened(0.2))
	p_dust.position = Vector3(0, 0.2, 1.2)
	model.add_child(p_dust)
	p_smoke = Gfx.particles("smoke")
	p_smoke.position = Vector3(0, 1.0, 0)
	add_child(p_smoke)
	p_stars = Gfx.particles("stars")
	p_stars.position = Vector3(0, 2.6, 0)
	add_child(p_stars)
	p_land = Gfx.particles("landing", dust_c.lightened(0.3))
	p_land.position = Vector3(0, 0.2, 0)
	add_child(p_land)
	p_confetti = Gfx.particles("confetti")
	p_confetti.position = Vector3(0, 2.0, 0)
	add_child(p_confetti)


func celebrate() -> void:
	if p_confetti:
		p_confetti.restart()


func _update_visuals(delta: float) -> void:
	# RF-320/321: no looping o kart segue a normal da pista; no chão inclina o bico na subida/descida
	if on_loop:
		var lt: Vector3 = track.tangents[track_idx]
		var lu: Vector3 = track.ups[track_idx]
		basis = Basis(lt.cross(lu).normalized(), lu, -lt)
	else:
		var tt: Vector3 = track.tangents[track_idx]
		var target := 0.0 if airborne else asin(clampf(tt.y, -1.0, 1.0)) * forward().dot(Vector3(tt.x, 0.0, tt.z).normalized())
		pitch = lerpf(pitch, target, 1.0 - exp(-10.0 * delta))
		rotation = Vector3(pitch, heading, 0.0)
	if model == null:
		return
	# RF-312: depois do resgate o kart pisca enquanto nada acerta
	model.visible = rescue_ghost <= 0.0 or fmod(rescue_ghost, 0.16) > 0.08
	var yaw := 0.0
	if spin_time > 0.0:
		yaw = model.rotation.y + 14.0 * delta
	elif drifting:
		yaw = lerp_angle(model.rotation.y, drift_dir * -0.4, 1.0 - exp(-10.0 * delta))
	else:
		yaw = lerp_angle(model.rotation.y, 0.0, 1.0 - exp(-8.0 * delta))
	model.rotation.y = yaw
	# RF-145: inclinação na curva, tremida na grama, rodas girando e esterçando
	var spd01 := clampf(absf(speed) / 30.0, 0.0, 1.0)
	model.rotation.z = lerpf(model.rotation.z, -in_steer * 0.09 * spd01 - (drift_dir * 0.06 if drifting else 0.0), 1.0 - exp(-8.0 * delta))
	var shake := 0.0
	if not airborne and absf(lateral) > TrackScript.ROAD_HALF + TrackScript.CURB and absf(speed) > 4.0:
		shake = randf_range(-0.04, 0.04)
	wheel_spin = fmod(wheel_spin + speed * delta / (0.21 * KART_SCALE), TAU)
	for w in wheels:
		w.rotation = Vector3(wheel_spin, -in_steer * 0.45 if front_wheels.has(w) else 0.0, 0.0)
	# manobra no ar: um giro completo no eixo X
	if trick_spin > 0.0:
		trick_spin = maxf(0.0, trick_spin - delta * TAU * 2.2)
	model.rotation.x = -trick_spin
	if hop_time > 0.0:
		hop_time -= delta
		model.position.y = sin((1.0 - hop_time / 0.25) * PI) * 0.45 + shake
	else:
		model.position.y = shake
	# RF-165: partículas
	var show_sparks := drifting and drift_charge >= MINI_TURBO_1
	for s in sparks:
		s.emitting = show_sparks
		if show_sparks:
			s.color = drift_color(drift_charge) * 1.6
	var boosting := boost_time > 0.0
	p_flame.emitting = boosting
	for f in flames:
		f.visible = boosting
		if boosting:
			f.scale = Vector3.ONE * randf_range(0.8, 1.3)
	p_dust.emitting = not airborne and absf(speed) > 5.0 and absf(lateral) > TrackScript.ROAD_HALF + TrackScript.CURB
	_update_shield_fx()


static func drift_color(charge: float) -> Color:
	if charge >= MINI_TURBO_3:
		return Color(0.8, 0.3, 1.0)
	if charge >= MINI_TURBO_2:
		return Color(1.0, 0.5, 0.05)
	if charge >= MINI_TURBO_1:
		return Color(0.3, 0.7, 1.0)
	return Color(0.7, 0.7, 0.7)


## RF-203: bolha do escudo (pisca nos últimos 1.5 s).
func _update_shield_fx() -> void:
	if shield_time > 0.0 and shield_bubble == null:
		shield_bubble = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 2.1
		s.height = 4.2
		shield_bubble.mesh = s
		var m := ShaderMaterial.new()
		m.shader = ShieldShader
		shield_bubble.material_override = m
		shield_bubble.position = Vector3(0, 1.3, 0)
		shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shield_bubble)
	if shield_bubble:
		var on := shield_time > 0.0
		if on and shield_time < 1.5:
			on = int(shield_time * 8.0) % 2 == 0
		shield_bubble.visible = on
