extends Node3D
## Kart: física arcade (sem motor de física), drift + mini-turbo, IA e visual procedural.
## Frente do kart = -Z local. heading = rotação em Y.

const TrackScript = preload("res://scripts/track.gd")
const GameScript = preload("res://scripts/game.gd")
const Chars = preload("res://scripts/characters.gd")
const Gfx = preload("res://scripts/gfx.gd")
const LABEL_LAYER_BASE := 10  # camada do nome do jogador N = 10+N (escondida na câmera dele)

const DRIFT_MIN_SPEED := 12.0
const MINI_TURBO_1 := 0.7
const MINI_TURBO_2 := 1.5
const MINI_TURBO_3 := 2.4   # RF-143
const GRAVITY := 28.0
const PAD_BOOST := 0.8
const TRICK_BOOST := 0.7
const ITEM_ROLL := 1.0      # roleta (RF-130)
const MAX_CHEESE := 10
const ITEM_BOOST := 1.3
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
var prev_drift := false
var on_pad := false
var bump_cd := 0.0

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
var front_pivots: Array = []  # Node3D (esterçam)
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
	speed = 0.0
	vel = Vector3.ZERO
	lateral = lat
	reset_physics_interpolation()


func hit() -> void:
	if spin_time > 0.0:
		return
	spin_time = 1.1
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
			item = ""
			items_used += 1
		if item != "" and item_roll <= 0.0:
			item_hold += delta
	prev_drift = in_drift
	_update_visuals(delta)


# ---------------------------------------------------------------- movimento

func _move(delta: float) -> void:
	var throttle := in_throttle
	var steer := in_steer
	if spin_time > 0.0:
		spin_time -= delta
		throttle = 0.0
		steer = 0.0
		speed = move_toward(speed, 0.0, 30.0 * delta)
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
		var amount := lerpf(0.4, 1.3, into)
		heading -= drift_dir * amount * turn_rate * delta
		drift_charge += delta * (0.6 + 0.8 * into)
	else:
		var high_speed_damp := lerpf(1.0, 0.8, clampf(speed / max_speed, 0.0, 1.0))
		var air_damp := 0.35 if airborne else 1.0
		heading -= steer * turn_rate * speed_factor * high_speed_damp * air_damp * delta

	var grip := 2.5 if drifting else (1.5 if airborne else 9.0)
	vel = vel.lerp(forward() * speed, 1.0 - exp(-grip * delta))
	position += vel * delta


## RF-141: sobe a rampa, decola, gravidade, manobra no ar e pouso.
func _update_air(delta: float) -> void:
	if not airborne:
		var f: float = track.ramp_frac(track_idx, track.along_of(position, track_idx), lateral)
		if f >= 0.0:
			on_ramp = true
			position.y = f * TrackScript.RAMP_H
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
				position.y = 0.0
		return
	air_time += delta
	if not trick and not autopilot and in_drift and not prev_drift and air_time > 0.05:
		_start_trick()
	vy -= GRAVITY * delta
	position.y += vy * delta
	max_height = maxf(max_height, position.y)
	if position.y <= 0.0:
		position.y = 0.0
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

	# muro (RF-12)
	var lim := TrackScript.WALL - RADIUS
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

	# preso / fora dos limites (RF-16)
	if autopilot and absf(speed) < 3.0 and spin_time <= 0.0:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 2.5:
		respawn()


func respawn() -> void:
	position = track.points[track_idx]
	heading = track.heading_at(track_idx)
	rotation.y = heading
	speed = 0.0
	vel = Vector3.ZERO
	spin_time = 0.0
	drifting = false
	stuck_time = 0.0
	lateral = 0.0
	airborne = false
	on_ramp = false
	vy = 0.0
	reset_physics_interpolation()


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
	ai_lane_timer -= delta
	if ai_lane_timer <= 0.0:
		var m := TrackScript.ROAD_HALF - 2.5
		ai_lane = randf_range(-m, m)
		ai_lane_timer = randf_range(2.0, 5.0)
	# RF-140: às vezes mira na seta de turbo à frente
	for p in track.pads:
		var dp := wrapi(int(p["idx"]) - track_idx, 0, n)
		if dp > 4 and dp < 25 and ai_pad_target != int(p["idx"]):
			ai_pad_target = int(p["idx"])
			if randf() < 0.5:
				ai_lane = float(p["lat"])
				ai_lane_timer = 3.0
	var look := 5 + int(absf(speed) * 0.3)
	var ti := (track_idx + look) % n
	var target: Vector3 = track.points[ti] + track.rights[ti] * ai_lane
	var to := target - position
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - heading, -PI, PI)
	in_steer = clampf(-diff * 2.2, -1.0, 1.0)
	in_throttle = 0.4 if absf(diff) > 1.2 else 1.0
	if drifting:
		in_drift = absf(diff) > 0.08 and signf(-diff) == drift_dir
	else:
		in_drift = absf(diff) > 0.35 and speed > DRIFT_MIN_SPEED + 3.0

	# itens (RF-42)
	if item != "":
		match item:
			"turbo":
				in_item = item_hold > 0.8 and absf(diff) < 0.2
			"casca":
				in_item = item_hold > ai_item_delay
			"bomba":
				in_item = item_hold > 8.0 or (item_hold > 0.5 and race.kart_in_sight(self))


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


func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.35
	m.roughness = 0.28
	m.clearcoat_enabled = true
	m.clearcoat = 0.7
	m.clearcoat_roughness = 0.15
	return m


## RF-164: kart arredondado com pintura metálica, volante, escapamento e número.
func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var paint := _paint(color)
	var trim := _paint(color.darkened(0.35))
	var dark := _mat(Color(0.08, 0.08, 0.1))
	dark.roughness = 0.6
	var rubber := _mat(Color(0.06, 0.06, 0.07))
	rubber.roughness = 0.95
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.55, 0.56, 0.6)
	chrome.metallic = 1.0
	chrome.roughness = 0.32
	# chassi e carroceria
	_part(_box(Vector3(1.5, 0.16, 2.7)), dark, Vector3(0, 0.3, 0))
	var hull := CapsuleMesh.new()
	hull.radius = 0.5
	hull.height = 2.7
	_part(hull, paint, Vector3(0, 0.58, 0.05), Vector3(PI / 2, 0, 0)).scale = Vector3(1.3, 1.0, 0.6)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.16
	nose.bottom_radius = 0.42
	nose.height = 0.7
	_part(nose, paint, Vector3(0, 0.48, -1.5), Vector3(-PI / 2, 0, 0)).scale = Vector3(1.5, 1.0, 0.6)
	var bar := CapsuleMesh.new()
	bar.radius = 0.09
	bar.height = 1.9
	_part(bar, dark, Vector3(0, 0.34, -1.98), Vector3(0, 0, PI / 2))
	_part(bar, dark, Vector3(0, 0.34, 1.6), Vector3(0, 0, PI / 2))
	var pod := CapsuleMesh.new()
	pod.radius = 0.26
	pod.height = 1.3
	for x in [-0.74, 0.74]:
		_part(pod, trim, Vector3(x, 0.48, 0.25), Vector3(PI / 2, 0, 0))
	# motor + escapamento duplo
	_part(_box(Vector3(0.9, 0.42, 0.6)), _mat(Color(0.3, 0.3, 0.33)), Vector3(0, 0.78, 1.05))
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.09
	pipe.bottom_radius = 0.09
	pipe.height = 0.55
	for x in [-0.25, 0.25]:
		_part(pipe, chrome, Vector3(x, 0.78, 1.45), Vector3(PI / 2, 0, 0))
	# aerofólio
	_part(_box(Vector3(1.9, 0.08, 0.45)), paint, Vector3(0, 1.22, 1.32))
	_part(_box(Vector3(0.08, 0.42, 0.08)), dark, Vector3(-0.55, 0.98, 1.3))
	_part(_box(Vector3(0.08, 0.42, 0.08)), dark, Vector3(0.55, 0.98, 1.3))
	# banco e volante
	_part(_box(Vector3(0.62, 0.62, 0.14)), dark, Vector3(0, 1.0, 0.6))
	var wheel_ring := TorusMesh.new()
	wheel_ring.inner_radius = 0.13
	wheel_ring.outer_radius = 0.19
	_part(wheel_ring, dark, Vector3(0, 1.06, -0.28), Vector3(deg_to_rad(65), 0, 0))
	var column := CylinderMesh.new()
	column.top_radius = 0.03
	column.bottom_radius = 0.03
	column.height = 0.5
	_part(column, dark, Vector3(0, 0.88, -0.45), Vector3(deg_to_rad(-25), 0, 0))
	# número do grid (placa branca nos dois lados)
	var number := str(Chars.index_of(char_id) + 1)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.26
	plate.bottom_radius = 0.26
	plate.height = 0.02
	var white := _mat(Color(0.95, 0.95, 0.95))
	for side in [-1.0, 1.0]:
		_part(plate, white, Vector3(side * 0.66, 0.6, -0.35), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 1)
		var num := Label3D.new()
		num.text = number
		num.font_size = 72
		num.pixel_size = 0.005
		num.modulate = Color(0.05, 0.05, 0.05)
		num.outline_size = 0
		num.position = Vector3(side * 0.68, 0.6, -0.35)
		num.rotation.y = PI / 2.0 * side
		model.add_child(num)
	# rodas: pneu + aro cromado + faixa pra ver o giro (RF-145)
	var tire := CylinderMesh.new()
	tire.top_radius = 0.4
	tire.bottom_radius = 0.4
	tire.height = 0.38
	var rim := CylinderMesh.new()
	rim.top_radius = 0.24
	rim.bottom_radius = 0.24
	rim.height = 0.4
	var spoke := _box(Vector3(0.44, 0.42, 0.09))
	for x in [-0.95, 0.95]:
		for z in [-0.92, 0.92]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 0.4, z)
			model.add_child(pivot)
			var w := MeshInstance3D.new()
			w.mesh = tire
			w.material_override = rubber
			w.rotation = Vector3(0, 0, PI / 2)
			pivot.add_child(w)
			var r := MeshInstance3D.new()
			r.mesh = rim
			r.material_override = chrome
			w.add_child(r)
			var sp := MeshInstance3D.new()
			sp.mesh = spoke
			sp.material_override = dark
			w.add_child(sp)
			wheels.append(w)
			if z < 0.0:
				front_pivots.append(pivot)
	# piloto camundongo (RF-111) com braços no volante
	var torso := CapsuleMesh.new()
	torso.radius = 0.33
	torso.height = 0.8
	_part(torso, trim, Vector3(0, 1.05, 0.3))
	var arm := CapsuleMesh.new()
	arm.radius = 0.09
	arm.height = 0.62
	var glove := SphereMesh.new()
	glove.radius = 0.1
	glove.height = 0.2
	for x in [-0.25, 0.25]:
		_part(arm, trim, Vector3(x, 1.12, 0.0), Vector3(deg_to_rad(-70), 0, -x * 0.6))
		_part(glove, white, Vector3(x * 0.75, 1.08, -0.25))
	var fur := _mat(Color(0.86, 0.7, 0.55))
	var pink := _mat(Color(1.0, 0.55, 0.62))
	var head := SphereMesh.new()
	head.radius = 0.42
	head.height = 0.84
	_part(head, fur, Vector3(0, 1.8, 0.3))
	var helmet := SphereMesh.new()
	helmet.radius = 0.46
	helmet.height = 0.46
	helmet.is_hemisphere = true
	_part(helmet, paint, Vector3(0, 1.84, 0.3))
	_part(_box(Vector3(0.6, 0.16, 0.1)), dark, Vector3(0, 1.98, -0.12))
	var nose_m := SphereMesh.new()
	nose_m.radius = 0.09
	nose_m.height = 0.18
	_part(nose_m, pink, Vector3(0, 1.72, -0.13))
	var ear := SphereMesh.new()
	ear.radius = 0.34
	ear.height = 0.68
	var ear_in := SphereMesh.new()
	ear_in.radius = 0.24
	ear_in.height = 0.48
	for x in [-0.5, 0.5]:
		_part(ear, fur, Vector3(x, 2.25, 0.37)).scale = Vector3(1, 1, 0.3)
		_part(ear_in, pink, Vector3(x, 2.25, 0.3)).scale = Vector3(1, 1, 0.25)
	var head_top := 2.6
	var lbl := Label3D.new()
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
	# chama do turbo (cone) + partículas (RF-165)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.8
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.6, 0.7, 0.15)
	for x in [-0.25, 0.25]:
		var f := _part(cone, flame_mat, Vector3(x, 0.78, 1.95), Vector3(PI / 2, 0, 0))
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
	rotation.y = heading
	if model == null:
		return
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
	wheel_spin = fmod(wheel_spin + speed * delta / 0.38, TAU)
	for w in wheels:
		w.rotation.x = -wheel_spin
	for p in front_pivots:
		p.rotation.y = -in_steer * 0.45
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


static func drift_color(charge: float) -> Color:
	if charge >= MINI_TURBO_3:
		return Color(0.8, 0.3, 1.0)
	if charge >= MINI_TURBO_2:
		return Color(1.0, 0.5, 0.05)
	if charge >= MINI_TURBO_1:
		return Color(0.3, 0.7, 1.0)
	return Color(0.7, 0.7, 0.7)
