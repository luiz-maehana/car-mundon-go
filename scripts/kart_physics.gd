extends "res://scripts/kart_state.gd"
## Kart — física: aceleração, drift, looping no trilho, ar/rampas, muro, ilha, batidas, escudo e o resgate com balões.
## (camada de kart.gd — ver o topo de kart.gd)


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
	if trap_time > 0.0 or is_rescued() or ghost_time > 0.0 or _shield_absorbs():
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
	if spin_time > 0.0 or is_rescued() or ghost_time > 0.0 or _shield_absorbs():
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
	if slow_time > 0.0:  # RF-421: câmera lenta
		top *= SLOW_MULT
		speed = minf(speed, top)
	if not airborne and absf(lateral) > track.road_half(track_idx) + TrackScript.CURB and boost_time <= 0.0:
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
	if zone_kind == Ids.ZN_FAROFA and boost_time <= 0.0:
		top *= TrackScript.FAROFA_MULT
	elif zone_kind == Ids.ZN_SAND and boost_time <= 0.0:  # RF-301: caixa de areia
		top *= TrackScript.SAND_MULT
	elif zone_kind == Ids.ZN_BELT:
		top *= 1.15
	elif zone_kind == Ids.ZN_ICE:
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
		# RF-430: mesmo amortecimento de velocidade da curva normal (antes o drift girava ~30% a mais)
		var drift_damp := lerpf(1.0, 0.8, clampf(speed / max_speed, 0.0, 1.0))
		heading -= drift_dir * amount * turn_rate * drift_damp * delta
		drift_charge += delta * (0.6 + 0.8 * into)
		if drift_master_time > 0.0:  # RF-425: drift mestre do Telles
			drift_charge = maxf(drift_charge, MINI_TURBO_3)
	else:
		var high_speed_damp := lerpf(1.0, 0.8, clampf(speed / max_speed, 0.0, 1.0))
		var air_damp := 0.35 if airborne else 1.0
		heading -= steer * turn_rate * speed_factor * high_speed_damp * air_damp * delta

	var grip := DRIFT_GRIP if drifting else (1.5 if airborne else 9.0)  # RF-280: no drift a direção segue o bico; o "de lado" é só no modelo
	if zone_kind == Ids.ZN_ICE and not airborne:  # RF-323: gelo escorrega (a direção demora a obedecer)
		grip = ICE_GRIP * (0.75 if drifting else 1.0)
	vel = vel.lerp(forward() * speed, 1.0 - exp(-grip * delta))
	position += vel * delta
	# esteiras carregam o kart (mesmo parado)
	if zone_kind == Ids.ZN_BELT:
		position += track.tangents[track_idx] * TrackScript.BELT_SPEED * float(zone["dir"]) * delta
	elif zone_kind == Ids.ZN_BELT_SIDE:
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
	loop_fwd = track.tangents[i].slerp(track.tangents[k], f).normalized()
	loop_up = track.ups[i].slerp(track.ups[k], f).normalized()
	vel = loop_fwd * speed


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
		elif not on_loop and (track.gap_at(track_idx) or track.pit_at(position, track_idx)):
			# RF-330: acabou o telhado: começa a cair (rápido o bastante, a rampinha já te lançou)
			airborne = true
			vy = -7.0 if track.pit_at(position, track_idx) else 0.0  # RF-390: buraco puxa pra baixo
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
		if track.gap_at(track_idx) or track.pit_at(position, track_idx):
			return  # RF-330/390: em cima do vão (ou do buraco) não tem onde pousar
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
		loop_fwd = track.tangents[ni]
		loop_up = track.ups[ni]
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
	# RF-371: ilha de barracas no meio da pista (bate como num muro e sai pro lado mais perto)
	var isl: Dictionary = track.island_at(ni)
	if not isl.is_empty() and not airborne:
		var lo: float = float(isl["lat0"]) - RADIUS
		var hi: float = float(isl["lat1"]) + RADIUS
		if lateral > lo and lateral < hi:
			var to := lo if lateral - lo < hi - lateral else hi
			var r2: Vector3 = track.rights[ni]
			position += r2 * (to - lateral)
			var sgn := signf(to - (lo + hi) * 0.5)
			var vin := -vel.dot(r2) * sgn
			if vin > 0.0:
				vel += r2 * sgn * vin * 1.5
				speed *= clampf(1.0 - vin * 0.04, 0.4, 1.0)
				if vin > 6.0 and is_player and bump_cd <= 0.0:
					bump_cd = 0.4
					race.sfx("bump")
					race.shake(self, 0.3)
			lateral = to
	max_abs_lateral = maxf(max_abs_lateral, absf(lateral))

	# RF-311: último ponto seguro (no chão, na pista, andando pra frente num trecho sem perigo)
	var tan: Vector3 = track.tangents[ni]
	if not airborne and not on_ramp and not on_loop and absf(position.y - ground) < 0.3 and absf(lateral) < track.road_half(ni) - 1.0 and track.island_at(ni).is_empty() and vel.dot(tan) > 2.0 and (track.safe.is_empty() or track.safe[ni] == 1):
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
	m_yaw = 0.0
	m_roll = 0.0
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
