extends Node3D
## Kart: física arcade (sem motor de física), drift + mini-turbo, IA e visual procedural.
## Frente do kart = -Z local. heading = rotação em Y.

const TrackScript = preload("res://scripts/track.gd")
const GameScript = preload("res://scripts/game.gd")
const Chars = preload("res://scripts/characters.gd")
const LABEL_LAYER_BASE := 10  # camada do nome do jogador N = 10+N (escondida na câmera dele)

const DRIFT_MIN_SPEED := 12.0
const MINI_TURBO_1 := 0.7
const MINI_TURBO_2 := 1.5
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

# input do frame
var in_throttle := 0.0
var in_steer := 0.0
var in_drift := false
var in_item := false

# visual
var model: Node3D
var sparks: Array = []
var spark_mat: StandardMaterial3D
var flame: MeshInstance3D


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


func step(delta: float, can_drive: bool) -> void:
	in_item = false
	if autopilot:
		_ai_input(delta)
	else:
		_player_input()
	if can_drive:
		_move(delta)
		_update_track(delta)
		if in_item and item != "" and spin_time <= 0.0:
			race.use_item(self, item)
			item = ""
			items_used += 1
		if item != "":
			item_hold += delta
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

	var top := max_speed
	if autopilot and not is_player:
		top *= ai_skill * rubber
	if absf(lateral) > TrackScript.ROAD_HALF + TrackScript.CURB and boost_time <= 0.0:
		top *= OFFROAD_MULT
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
	if not drifting and in_drift and absf(steer) > 0.3 and speed > DRIFT_MIN_SPEED and spin_time <= 0.0:
		drifting = true
		drift_dir = signf(steer)
		drift_charge = 0.0
		hop_time = 0.25
	if drifting and (not in_drift or speed < DRIFT_MIN_SPEED * 0.6 or spin_time > 0.0):
		drifting = false
		if spin_time <= 0.0:
			if drift_charge >= MINI_TURBO_2:
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
		heading -= steer * turn_rate * speed_factor * high_speed_damp * delta

	var grip := 2.5 if drifting else 9.0
	vel = vel.lerp(forward() * speed, 1.0 - exp(-grip * delta))
	position += vel * delta


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


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var body_mat := _mat(color)
	var dark := _mat(Color(0.1, 0.1, 0.12))
	var trim := _mat(color.darkened(0.35))
	_part(_box(Vector3(1.6, 0.45, 2.6)), body_mat, Vector3(0, 0.5, 0))
	_part(_box(Vector3(1.2, 0.3, 0.9)), trim, Vector3(0, 0.45, -1.55))
	_part(_box(Vector3(1.8, 0.1, 0.45)), dark, Vector3(0, 1.1, 1.25))
	_part(_box(Vector3(0.1, 0.4, 0.1)), dark, Vector3(-0.6, 0.85, 1.25))
	_part(_box(Vector3(0.1, 0.4, 0.1)), dark, Vector3(0.6, 0.85, 1.25))
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.38
	wheel.bottom_radius = 0.38
	wheel.height = 0.36
	for x in [-0.95, 0.95]:
		for z in [-0.9, 0.9]:
			_part(wheel, dark, Vector3(x, 0.38, z), Vector3(0, 0, PI / 2))
	# piloto
	var torso := CapsuleMesh.new()
	torso.radius = 0.33
	torso.height = 0.8
	_part(torso, trim, Vector3(0, 1.0, 0.25))
	var head_top := 2.4
	var head_tex: Texture2D = Chars.art(char_id, "head")
	if head_tex:
		# RF-71: busto do camundongo como sticker sempre virado pra câmera
		var w := 2.1
		var h := w * float(head_tex.get_height()) / float(head_tex.get_width())
		var quad := QuadMesh.new()
		quad.size = Vector2(w, h)
		var hm := StandardMaterial3D.new()
		hm.albedo_texture = head_tex
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		hm.alpha_scissor_threshold = 0.5
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		hm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var head := _part(quad, hm, Vector3(0, 1.3 + h * 0.5, 0.25))
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head_top = 1.3 + h
	else:
		# RF-74: sem arte, capacete colorido com orelhinhas
		var head := SphereMesh.new()
		head.radius = 0.4
		head.height = 0.8
		_part(head, body_mat, Vector3(0, 1.8, 0.25))
		_part(_box(Vector3(0.55, 0.2, 0.12)), dark, Vector3(0, 1.82, -0.12))
		var ear := SphereMesh.new()
		ear.radius = 0.24
		ear.height = 0.48
		var ear_in := SphereMesh.new()
		ear_in.radius = 0.15
		ear_in.height = 0.3
		var pink := _mat(Color(1.0, 0.6, 0.7))
		for x in [-0.32, 0.32]:
			_part(ear, body_mat, Vector3(x, 2.17, 0.3), Vector3.ZERO).scale = Vector3(1, 1, 0.35)
			_part(ear_in, pink, Vector3(x, 2.17, 0.21), Vector3.ZERO).scale = Vector3(1, 1, 0.3)
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
	# faíscas do drift
	spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(0.3, 0.7, 1.0)
	var spark := SphereMesh.new()
	spark.radius = 0.22
	spark.height = 0.44
	for x in [-0.9, 0.9]:
		var s := _part(spark, spark_mat, Vector3(x, 0.25, 1.35))
		s.visible = false
		sparks.append(s)
	# chama do turbo
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.32
	cone.height = 1.0
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.55, 0.1)
	flame = _part(cone, flame_mat, Vector3(0, 0.55, 1.8), Vector3(PI / 2, 0, 0))
	flame.visible = false


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
	model.rotation.z = -in_steer * 0.05
	if hop_time > 0.0:
		hop_time -= delta
		model.position.y = sin((1.0 - hop_time / 0.25) * PI) * 0.45
	else:
		model.position.y = 0.0
	var show_sparks := drifting and drift_charge >= MINI_TURBO_1
	for s in sparks:
		s.visible = show_sparks
	if show_sparks:
		spark_mat.albedo_color = Color(1.0, 0.5, 0.05) if drift_charge >= MINI_TURBO_2 else Color(0.3, 0.7, 1.0)
	flame.visible = boost_time > 0.0
	if flame.visible:
		flame.scale = Vector3.ONE * randf_range(0.8, 1.25)
