extends "res://scripts/race_track_hazards.gd"
## Corrida — itens, caixas, queijinhos, vácuo, batidas entre karts e poderes.
## (camada de race.gd — ver o topo de race.gd)


func _spawn_boxes() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 1.4, 1.4)
	var mat := Gfx.rainbow_material()  # RF-168
	for p in track.item_box_positions():
		var node := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		node.add_child(mi)
		var q := Label3D.new()
		q.text = "?"
		q.font_size = 96
		q.pixel_size = 0.012
		q.outline_size = 12
		q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		q.no_depth_test = true
		node.add_child(q)
		node.position = p
		add_child(node)
		var bi: int = track.nearest_index(p)
		boxes.append({"node": node, "pos": p, "cd": 0.0, "idx": bi, "lat": track.lateral_of(p, bi)})


func _kart_collisions() -> void:
	var r2 := KartScript.RADIUS * 2.0
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: Node3D = karts[i]
			var b: Node3D = karts[j]
			if a.rescue_time > 0.0 or b.rescue_time > 0.0:  # RF-310: pendurado nos balões
				continue
			if a.ghost_time > 0.0 or b.ghost_time > 0.0:  # RF-423: fantasma atravessa
				continue
			if absf(a.position.y - b.position.y) > 2.0:  # RF-320: andares diferentes (ou um no looping)
				continue
			var dv := b.position - a.position
			dv.y = 0.0
			var d := dv.length()
			var rr := r2 * (1.3 if a.ram_time > 0.0 or b.ram_time > 0.0 else 1.0)
			if d >= rr or d < 0.001:
				continue
			var nrm := dv / d
			var ov := rr - d
			var wa: float = a.weight * (25.0 if a.ram_time > 0.0 else 1.0)  # RF-426: trombada — ninguém empurra
			var wb: float = b.weight * (25.0 if b.ram_time > 0.0 else 1.0)
			if a.ram_time > 0.0 and b.ram_time <= 0.0:
				b.hit(1.0)
			elif b.ram_time > 0.0 and a.ram_time <= 0.0:
				a.hit(1.0)
			a.position -= nrm * ov * wb / (wa + wb)
			b.position += nrm * ov * wa / (wa + wb)
			var rel: float = (a.vel - b.vel).dot(nrm)
			if rel > 0.0:
				a.vel -= nrm * rel * wb / (wa + wb)
				b.vel += nrm * rel * wa / (wa + wb)
				# RF-144: impacto — o mais leve perde mais velocidade
				if rel > 4.0:
					a.speed *= 1.0 - clampf(rel * 0.025 * wb / (wa + wb), 0.0, 0.4)
					b.speed *= 1.0 - clampf(rel * 0.025 * wa / (wa + wb), 0.0, 0.4)
					if (a.is_player or b.is_player) and a.bump_cd <= 0.0 and b.bump_cd <= 0.0:
						a.bump_cd = 0.4
						b.bump_cd = 0.4
						sfx("bump")
						shake(a, 0.35)
						shake(b, 0.35)


## RF-142: vácuo — logo atrás de outro kart por 1.2 s dá turbo.
func _update_slipstream(delta: float) -> void:
	for k in karts:
		var f: Vector3 = k.forward()
		var behind := false
		if k.speed > 15.0 and not k.airborne:
			for o in karts:
				if o == k or o.speed < 15.0:
					continue
				var to: Vector3 = o.position - k.position
				to.y = 0.0
				var d := to.length()
				if d > 4.0 and d < 14.0 and f.angle_to(to / d) < deg_to_rad(15.0):
					behind = true
					break
		if behind:
			k.slip_time += delta
			if k.slip_time >= SLIP_TIME:
				k.slip_time = 0.0
				k.boost_time = maxf(k.boost_time, 0.8)
				if k.is_player:
					sfx("slip")
					k.slip_flash = 1.2
		else:
			k.slip_time = maxf(0.0, k.slip_time - delta * 2.0)
		k.slip_flash = maxf(0.0, k.slip_flash - delta)


## RF-150: queijinhos.
func _spawn_cheese() -> void:
	# RF-172: queijo do Food Kit (Kenney)
	for p in track.cheese_positions():
		var node := Gfx.prop_merged(CHEESE_MODEL, 1.2)  # RF-483: 12 peças viram 1
		node.position = p - Vector3.UP * 0.35
		add_child(node)
		cheeses.append({"node": node, "pos": p, "cd": 0.0})


func _update_cheese(delta: float) -> void:
	for c in cheeses:
		var node: Node3D = c["node"]
		if node.visible and not far_from_cameras(c["pos"]):
			node.rotate_y(delta * 2.0)  # RF-484: só gira perto da câmera
		if c["cd"] > 0.0:
			c["cd"] -= delta
			if c["cd"] <= 0.0:
				node.visible = true
			continue
		var cp: Vector3 = c["pos"]
		for k in karts:
			var kp: Vector3 = k.position
			if Vector2(cp.x - kp.x, cp.z - kp.z).length() < 1.8 and absf(kp.y - cp.y) < 2.0:
				if k.cheese < KartScript.MAX_CHEESE:
					k.cheese += 1
					if k.is_player:
						sfx("cheese")
				c["cd"] = CHEESE_RESPAWN
				node.visible = false
				break


func _update_boxes(delta: float) -> void:
	for b in boxes:
		var node: Node3D = b["node"]
		if node.visible and not far_from_cameras(b["pos"]):
			node.rotate_y(delta * 1.5)  # RF-484: só gira perto da câmera
		if b["cd"] > 0.0:
			b["cd"] -= delta
			if b["cd"] <= 0.0:
				node.visible = true
			continue
		for k in karts:
			if k.position.distance_squared_to(b["pos"] - Vector3.UP * 1.2) < 2.6 * 2.6:
				if k.item == "" and k.spin_time <= 0.0:
					k.give_item(_roll_item(k.rank))  # roleta de 1 s (RF-130)
					k.ai_item_delay = rng.randf_range(1.5, 5.0)
					boxes_picked += 1
					if k.is_player:
						sfx("item")
				b["cd"] = BOX_RESPAWN
				node.visible = false
				break


func _roll_item(rank: int) -> String:
	var table: Array = ITEM_TABLE["front"] if rank <= 2 else (ITEM_TABLE["mid"] if rank <= 4 else ITEM_TABLE["back"])
	if gato_active():
		table = table.filter(func(e): return e[0] != "gato")
	var total := 0
	for e in table:
		total += int(e[1])
	var r := rng.randi_range(1, total)
	for e in table:
		r -= int(e[1])
		if r <= 0:
			return e[0]
	return "turbo"


func gato_active() -> bool:
	for h in hazards:
		if h["type"] == "gato":
			return true
	return false


## Alvo do GATO: o 1º colocado (se quem soltou é o 1º, vai no 2º).
func gato_target(owner_kart: Node3D) -> Node3D:
	var order: Array = ranking()
	for k in order:
		if k != owner_kart and not k.finished:
			return k
	return null


func use_item(k: Node3D, it: String) -> void:
	if k.is_player:
		sfx(ITEM_SFX.get(it, "boost"))
	match it:
		"turbo", "triplo":
			k.boost_time = maxf(k.boost_time, KartScript.ITEM_BOOST)
		"casca", "ratoeira":
			_spawn_hazard(it, k.position - k.forward() * 2.4, Vector3.ZERO, 90.0, k)
		"bomba":
			var v: Vector3 = k.forward() * (maxf(k.speed, 0.0) + 40.0)
			_spawn_hazard("bomba", k.position + k.forward() * 2.5 + Vector3.UP * 0.5, v, 4.0, k)
		"escudo":
			k.shield_time = KartScript.SHIELD_TIME
		"gato":
			var target := gato_target(k)
			if target:
				_spawn_hazard("gato", k.position + k.forward() * 2.5, Vector3.ZERO, GATO_LIFE, k)
				var h: Dictionary = hazards[-1]
				h["target"] = target
				h["prog"] = float(k.track_idx)
				h["lat"] = k.lateral
				if target.is_player:
					sfx("meow")


## Tem kart vindo logo atrás (até `dist` m, num cone de ~25°)? (IA solta casca/ratoeira)
func kart_behind(k: Node3D, dist: float) -> bool:
	var back: Vector3 = -k.forward()
	for o in karts:
		if o == k:
			continue
		var to: Vector3 = o.position - k.position
		var d := to.length()
		if d > 2.0 and d < dist and back.angle_to(to / d) < 0.45:
			return true
	return false


func kart_in_sight(k: Node3D, max_dist := 45.0) -> bool:
	var f: Vector3 = k.forward()
	for o in karts:
		if o == k:
			continue
		var to: Vector3 = o.position - k.position
		var d := to.length()
		if d > 3.0 and d < max_dist and f.angle_to(to / d) < 0.2:
			return true
	return false


func _spawn_hazard(type: String, pos: Vector3, v: Vector3, life: float, owner_kart: Node3D) -> void:
	var mi: Node3D
	match type:
		"casca":
			# RF-172: banana do Food Kit (Kenney), deitada no chão
			mi = Gfx.prop_merged(BANANA_MODEL, 1.5)  # RF-483
			mi.rotation.y = randf() * TAU
			pos.y = track.points[owner_kart.track_idx].y
		"ratoeira":
			mi = HazardModels.mousetrap()
			mi.rotation.y = randf() * TAU
			pos.y = track.points[owner_kart.track_idx].y
		"gato":
			mi = HazardModels.cat()
			pos.y = track.points[owner_kart.track_idx].y
		_:
			mi = HazardModels.bomb()
	Gfx.simplify_meshes(mi)  # RF-478
	mi.position = pos
	add_child(mi)
	mi.reset_physics_interpolation()
	var idx: int = track.nearest_index(pos, owner_kart.track_idx, 12)
	if track.points[idx].distance_to(Vector3(pos.x, 0, pos.z)) > 6.0:
		idx = track.nearest_index(pos)  # dono longe do ponto (ex.: testes): busca global
	hazards.append({"node": mi, "type": type, "pos": pos, "vel": v, "life": life, "owner": owner_kart, "age": 0.0, "idx": idx})


func _update_hazards(delta: float) -> void:
	var dead := []
	for h in hazards:
		h["age"] += delta
		h["life"] -= delta
		if h["life"] <= 0.0:
			dead.append(h)
			continue
		match h["type"]:
			"bomba":
				h["pos"] += h["vel"] * delta
				h["idx"] = track.nearest_index(h["pos"], h["idx"], 12)
				if absf(track.lateral_of(h["pos"], h["idx"])) > TrackScript.WALL - 0.4:
					dead.append(h)
					continue
				# bomba x casca/ratoeira: os dois somem
				for o in hazards:
					if GROUND_HAZARDS.has(o["type"]) and not dead.has(o) and o["pos"].distance_squared_to(h["pos"]) < 1.6 * 1.6:
						dead.append(o)
						dead.append(h)
						break
				if dead.has(h):
					continue
			"gato":
				if _move_gato(h, delta):
					dead.append(h)
				continue
		h["node"].position = h["pos"]
		var radius := 1.7 if h["type"] == "bomba" else 1.5
		for k in karts:
			if k == h["owner"] and h["age"] < 0.6:
				continue
			var p: Vector3 = h["pos"]
			var kp: Vector3 = k.position
			if Vector2(p.x - kp.x, p.z - kp.z).length() < radius and absf(kp.y - p.y) < 1.5:
				if h["type"] == "ratoeira":
					k.trap()
				else:
					k.hit()
				dead.append(h)
				break
	for h in dead:
		if hazards.has(h):
			hazards.erase(h)
			h["node"].queue_free()


## RF-201: o GATO corre pela pista atrás do alvo e, quando chega perto, dá o bote.
## Devolve true quando acabou (pegou o alvo ou o alvo terminou a corrida).
func _move_gato(h: Dictionary, delta: float) -> bool:
	var target: Node3D = h.get("target")
	if target == null or not is_instance_valid(target) or target.finished:
		return true
	var n: int = track.sample_count()
	var tp: Vector3 = target.position
	var pos: Vector3 = h["pos"]
	if Vector2(tp.x - pos.x, tp.z - pos.z).length() < 18.0:
		pos = pos.move_toward(Vector3(tp.x, tp.y, tp.z), GATO_SPEED * 1.2 * delta)
	else:
		h["prog"] = float(h["prog"]) + GATO_SPEED * delta / TrackScript.SPACING
		h["lat"] = lerpf(float(h["lat"]), target.lateral, 1.0 - exp(-1.5 * delta))
		var i := int(floor(h["prog"])) % n
		var j := (i + 1) % n
		var f: float = fmod(h["prog"], 1.0)
		var c: Vector3 = track.points[i].lerp(track.points[j], f)
		var r: Vector3 = track.rights[i]
		pos = c + r * float(h["lat"])
	var dir: Vector3 = pos - h["pos"]
	if dir.length() > 0.01:
		h["node"].rotation.y = atan2(-dir.x, -dir.z)
	h["pos"] = pos
	h["node"].position = pos + Vector3.UP * absf(sin(h["age"] * 14.0)) * 0.35  # pulinhos
	if Vector2(tp.x - pos.x, tp.z - pos.z).length() < 2.0:
		target.hit(1.6)
		shake(target, 0.7)
		return true
	return false


# ---------------------------------------------------------------- sensores da IA (RF-210..212)

## Cascas/ratoeiras até `samples` amostras à frente do kart: [{id, lat}].
func ground_hazards_ahead(k: Node3D, samples: int) -> Array:
	var out := []
	var n: int = track.sample_count()
	_track_hazards_ahead(k, samples, out)  # RF-272
	for h in hazards:
		if not GROUND_HAZARDS.has(h["type"]):
			continue
		var ds := wrapi(int(h["idx"]) - k.track_idx, 0, n)
		if ds > 0 and ds < samples:
			out.append({"id": h["node"].get_instance_id(), "lat": track.lateral_of(h["pos"], h["idx"])})
	return out


## Lateral da caixa ativa mais acessível na próxima fileira (até `samples` à frente), ou NAN.
func box_ahead(k: Node3D, samples: int) -> float:
	var n: int = track.sample_count()
	var best := NAN
	var best_ds := 1 << 30
	var best_dl := INF
	for b in boxes:
		if b["cd"] > 0.0:
			continue
		var ds := wrapi(int(b["idx"]) - k.track_idx, 0, n)
		if ds <= 2 or ds >= samples:
			continue
		var dl := absf(float(b["lat"]) - k.lateral)
		if ds < best_ds - 3 or (absf(ds - best_ds) <= 3 and dl < best_dl):
			best_ds = ds
			best_dl = dl
			best = b["lat"]
	return best


## Lateral de um kart mais lento até `dist` m à frente na faixa do kart (± lane_tol), ou NAN.
func slow_kart_ahead(k: Node3D, dist: float, lane_tol: float) -> float:
	var n: int = track.sample_count()
	for o in karts:
		if o == k:
			continue
		var ds := wrapi(o.track_idx - k.track_idx, 0, n)
		if ds > 0 and ds * TrackScript.SPACING < dist and absf(o.lateral - k.ai_lane) < lane_tol and o.speed < k.speed - 1.0:
			return o.lateral
	return NAN


## O kart k usa o poder dele (já conferido: 10 queijinhos e sem recarga).
func use_power(k: Node3D) -> void:
	var id: String = k.power_id()
	var impl := PowerRegistry.of(id)
	if impl == null:
		return
	var msg: String = impl.use(self, k)
	if msg == "":
		msg = k.power_name().to_upper() + "!"
	if not PowerRegistry.COOLDOWN_LATER.has(id):
		k.power_cd = Chars.POWER_CD
	if k.is_player:
		sfx("bump" if id == Ids.PW_BASS else "trick")
	power_used.emit(k, id, msg)


## Quem está à frente (o mais perto na classificação) e tem item na mão; ou null.
func kart_ahead_with_item(k: Node3D):
	var best = null
	for o in karts:
		if o == k or o.item == "" or o.item_roll > 0.0 or o.rank >= k.rank:
			continue
		if best == null or o.rank > best.rank:
			best = o
	return best
