extends "res://scripts/kart_ai.gd"
## Kart (RF-453): a classe é dividida em camadas, cada uma com um trabalho só:
##   kart_state.gd    todo o estado + consultas simples (base)
##   kart_physics.gd  movimento, drift, looping, ar, muro, batidas, resgate
##   kart_power.gd    poder do piloto (a lógica de cada poder mora em scripts/powers)
##   kart_ai.gd       pilotagem da IA
##   kart.gd          montagem do modelo, controle do jogador, passo e visual (este arquivo)


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
		_update_power(delta)  # RF-420
		if shield_time > 0.0:
			shield_time = maxf(0.0, shield_time - delta)
		if item != "" and item_roll <= 0.0:
			item_hold += delta
	prev_drift = in_drift
	_update_visuals(delta)



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
	in_power = false
	for p in sources:
		if InputMap.has_action(GameScript.action(p, "power")):
			in_power = in_power or Input.is_action_just_pressed(GameScript.action(p, "power"))
		in_throttle += Input.get_action_strength(GameScript.action(p, "accelerate")) - Input.get_action_strength(GameScript.action(p, "brake"))
		in_steer += Input.get_action_strength(GameScript.action(p, "steer_right")) - Input.get_action_strength(GameScript.action(p, "steer_left"))
		in_drift = in_drift or Input.is_action_pressed(GameScript.action(p, "drift"))
		in_item = in_item or Input.is_action_just_pressed(GameScript.action(p, "use_item"))
	in_throttle = clampf(in_throttle, -1.0, 1.0)
	in_steer = clampf(in_steer, -1.0, 1.0)


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
			sm.set_shader_parameter("mask", RecolorMask)
			sm.set_shader_parameter("tint", color)
			mi.material_override = sm
			kart_body = mi
	# número do grid nas laterais
	var number := str(int(Chars.find(char_id).get("number", Chars.index_of(char_id) + 1)))  # RF-380: o número do carro na arte
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
		num.visibility_range_end = 30.0  # RF-486: de longe não dá pra ler; são 2 desenhos a menos por kart
		model.add_child(num)
	# piloto
	var look: Dictionary = Chars.find(char_id).get("look", {})
	driver = MouseModel.build(look)
	Gfx.merge_meshes(driver)  # RF-479: 28 peças viram 1 malha (4 desenhos)
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
	if track and track.def.get("night", false):
		_build_headlights()  # RF-461


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
		var lu: Vector3 = (loop_up - loop_fwd * loop_up.dot(loop_fwd)).normalized()
		basis = Basis(loop_fwd.cross(lu).normalized(), lu, -loop_fwd)
	else:
		var tt: Vector3 = track.tangents[track_idx]
		var target := 0.0 if airborne else asin(clampf(tt.y, -1.0, 1.0)) * forward().dot(Vector3(tt.x, 0.0, tt.z).normalized())
		pitch = lerpf(pitch, target, 1.0 - exp(-10.0 * delta))
		rotation = Vector3(pitch, heading, 0.0)
	if model == null:
		return
	# RF-312: depois do resgate o kart pisca enquanto nada acerta
	model.visible = rescue_ghost <= 0.0 or fmod(rescue_ghost, 0.16) > 0.08
	_power_visuals(delta)
	# manobra no ar e pulinho: os tempos andam sempre (mesmo longe da câmera)
	if trick_spin > 0.0:
		trick_spin = maxf(0.0, trick_spin - delta * TAU * 2.2)
	if hop_time > 0.0:
		hop_time -= delta
	# RF-484: longe de todas as câmeras ninguém vê roda, inclinação nem faísca; só o kart anda
	var far: bool = race != null and race.has_method("far_from_cameras") and race.far_from_cameras(position)
	if far:
		if not vis_far:
			vis_far = true
			for s in sparks:
				s.emitting = false
			p_flame.emitting = false
			p_dust.emitting = false
			for f in flames:
				f.visible = false
		return
	vis_far = false
	if spin_time > 0.0:
		m_yaw += 14.0 * delta
	elif drifting:
		m_yaw = lerp_angle(m_yaw, drift_dir * -0.4, 1.0 - exp(-10.0 * delta))
	else:
		m_yaw = lerp_angle(m_yaw, 0.0, 1.0 - exp(-8.0 * delta))
	# RF-145: inclinação na curva, tremida na grama, rodas girando e esterçando
	var spd01 := clampf(absf(speed) / 30.0, 0.0, 1.0)
	m_roll = lerpf(m_roll, -in_steer * 0.09 * spd01 - (drift_dir * 0.06 if drifting else 0.0), 1.0 - exp(-8.0 * delta))
	var shake := 0.0
	if not airborne and absf(lateral) > track.road_half(track_idx) + TrackScript.CURB and absf(speed) > 4.0:
		shake = randf_range(-0.04, 0.04)
	var py := shake + (sin((1.0 - hop_time / 0.25) * PI) * 0.45 if hop_time > 0.0 else 0.0)
	# RF-484: um movimento só por passo (antes eram 4: giro, inclinação, manobra e pulo, e cada um
	# era repassado pras ~20 peças do kart)
	model.transform = Transform3D(Basis.from_euler(Vector3(-trick_spin, m_yaw, m_roll)) * Basis.from_scale(Vector3.ONE * m_scale), Vector3(model.position.x, py, model.position.z))
	wheel_spin = fmod(wheel_spin + speed * delta / (0.21 * KART_SCALE), TAU)
	for w in wheels:
		w.rotation = Vector3(wheel_spin, -in_steer * 0.45 if front_wheels.has(w) else 0.0, 0.0)
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
	p_dust.emitting = not airborne and absf(speed) > 5.0 and absf(lateral) > track.road_half(track_idx) + TrackScript.CURB
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


## RF-461: pista noturna — farol de verdade (ilumina a pista à frente), os dois faróis acesos
## no bico e a lanterna vermelha atrás. No gráfico BAIXO só os karts dos jogadores ganham a luz.
func _build_headlights() -> void:
	var warm := Color(1.0, 0.93, 0.78)
	var lamp_on := StandardMaterial3D.new()
	lamp_on.albedo_color = warm
	lamp_on.emission_enabled = true
	lamp_on.emission = warm
	lamp_on.emission_energy_multiplier = 4.0
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(1.0, 0.1, 0.08)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.1, 0.08)
	tail.emission_energy_multiplier = 3.0
	for x in [-0.5, 0.5]:
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.16
		hm.height = 0.24
		head.mesh = hm
		head.material_override = lamp_on
		head.position = Vector3(x, 0.62, -1.38)
		head.name = "Headlamp"
		model.add_child(head)
		var back := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.12, 0.06)
		back.mesh = bm
		back.material_override = tail
		back.position = Vector3(x, 0.66, 1.22)
		model.add_child(back)
	if not is_player and int(Gfx.setting("quality", 2)) == 0:
		return
	var spot := SpotLight3D.new()
	spot.name = "Headlight"
	spot.light_color = warm
	spot.light_energy = 5.0
	spot.spot_range = 32.0
	spot.spot_angle = 34.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = false
	spot.position = Vector3(0.0, 1.1, -1.5)
	spot.rotation.x = -0.14  # um pouco pra baixo: ilumina o asfalto
	add_child(spot)
