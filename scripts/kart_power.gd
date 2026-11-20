extends "res://scripts/kart_physics.gd"
## Kart — poder do piloto: pronto/recarga, planta (turbos), lento e os efeitos visuais dos poderes.
## (camada de kart.gd — ver o topo de kart.gd)


func power_id() -> String:
	return String(Chars.find(char_id).get("power", {}).get("id", ""))


func power_name() -> String:
	return String(Chars.find(char_id).get("power", {}).get("name", ""))


## Pronto pra usar: 10 queijinhos, sem recarga e sem efeito rolando.
func power_ready() -> bool:
	return cheese >= MAX_CHEESE and power_cd <= 0.0 and power_time <= 0.0 and power_charges <= 0 and spin_time <= 0.0 and rescue_time <= 0.0 and not finished


## Estado pro HUD: "charge" (juntando queijinho), "ready", "active", "cooldown".
func power_state() -> String:
	if power_charges > 0 or power_time > 0.0:
		return "active"
	if power_cd > 0.0:
		return "cooldown"
	return "ready" if cheese >= MAX_CHEESE else "charge"


func _update_power(delta: float) -> void:
	power_cd = maxf(0.0, power_cd - delta)
	slow_time = maxf(0.0, slow_time - delta)
	ghost_time = maxf(0.0, ghost_time - delta)
	ram_time = maxf(0.0, ram_time - delta)
	drift_master_time = maxf(0.0, drift_master_time - delta)
	if power_time > 0.0:
		power_time -= delta
		if power_time <= 0.0:
			power_time = 0.0
			if power_charges > 0:  # planta: janela acabou com turbo sobrando
				power_charges = 0
				power_cd = Chars.POWER_CD
	if not in_power:
		return
	if power_charges > 0:  # RF-422: planta da Nanni — cada aperto um mini-turbo
		power_charges -= 1
		boost_time = maxf(boost_time, PLANT_BOOST)
		if is_player:
			race.sfx("mini_turbo")
		if power_charges <= 0:
			power_time = 0.0
			power_cd = Chars.POWER_CD
	elif power_ready():
		race.use_power(self)
		powers_used += 1


## RF-421: câmera lenta do FeJauM (o escudo e o fantasma protegem).
func apply_slow(t: float) -> void:
	if ghost_time > 0.0 or is_rescued():
		return
	if _shield_absorbs():
		return
	slow_time = maxf(slow_time, t)
	if is_player:
		race.sfx("snap")


## Visuais dos poderes: anel azul de lento, transparência do fantasma, tamanho da trombada, planta.
func _power_visuals(delta: float) -> void:
	if slow_time > 0.0 and fx_slow == null:
		fx_slow = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.5
		tm.outer_radius = 1.8
		fx_slow.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.7, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.3, 0.7, 1.0)
		m.emission_energy_multiplier = 2.0
		fx_slow.material_override = m
		fx_slow.position.y = 1.2
		fx_slow.name = "SlowRing"
		add_child(fx_slow)
	if fx_slow:
		fx_slow.visible = slow_time > 0.0
		if fx_slow.visible:
			fx_slow.rotate_y(delta * 6.0)
			fx_slow.position.y = 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
	if model:
		var big := 1.35 if ram_time > 0.0 else 1.0
		m_scale = lerpf(m_scale, big, 1.0 - exp(-10.0 * delta))  # aplicado no movimento único do modelo (RF-484)
		if absf(m_scale - big) < 0.002:
			m_scale = big
		if ghost_meshes.is_empty():
			for mi in model.find_children("*", "GeometryInstance3D", true, false):
				ghost_meshes.append(mi)
		var tr := 0.65 if ghost_time > 0.0 else 0.0
		if tr != ghost_tr:  # RF-484: só quando muda (antes, todas as peças todo passo)
			ghost_tr = tr
			for mi in ghost_meshes:
				(mi as GeometryInstance3D).transparency = tr
	if power_charges > 0 and fx_plant == null:
		fx_plant = Node3D.new()
		fx_plant.name = "Plant"
		var stem := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.08
		sm.bottom_radius = 0.1
		sm.height = 1.0
		stem.mesh = sm
		stem.material_override = _flat(Color(0.2, 0.7, 0.25))
		stem.position.y = 0.5
		fx_plant.add_child(stem)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.45
		hm.height = 0.8
		head.mesh = hm
		head.material_override = _flat(Color(0.9, 0.15, 0.15))
		head.position.y = 1.2
		fx_plant.add_child(head)
		for k in 5:
			var dot := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.09
			dm.height = 0.18
			dot.mesh = dm
			dot.material_override = _flat(Color(1, 1, 1))
			dot.position = Vector3(cos(k * 1.3) * 0.4, 1.25 + sin(k * 2.1) * 0.15, sin(k * 1.3) * 0.4)
			fx_plant.add_child(dot)
		fx_plant.position = Vector3(0, 0.9, -1.6)
		add_child(fx_plant)
	if fx_plant:
		fx_plant.visible = power_charges > 0
		if fx_plant.visible:
			fx_plant.rotation.y = 0.4 * sin(Time.get_ticks_msec() * 0.006)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
