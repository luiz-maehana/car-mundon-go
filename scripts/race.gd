extends Node3D
## Orquestra a corrida: grid, contagem, itens, colisões, ranking, chegada e câmera.
## Toda a lógica roda em step(delta) — os testes chamam step() direto (RNF-02).

const TrackScript = preload("res://scripts/track.gd")
const KartScript = preload("res://scripts/kart.gd")
const HudScript = preload("res://scripts/hud.gd")
const Chars = preload("res://scripts/characters.gd")

const COUNTDOWN := 3.0
const BOX_RESPAWN := 3.0
const RESULTS_DELAY := 3.0

var use_game_settings := true
var autopilot_player := false
var player_chars: Array = ["fejaum"]  # um por jogador humano (1..4)
var laps := 3

var track: Node3D
var karts: Array = []
var players: Array = []   # karts humanos, na ordem J1..J4
var player: Node3D        # = players[0]
var cameras: Array = []
var huds: Array = []
var results_hud: CanvasLayer
var state := "countdown"  # countdown | racing | finished
var countdown := COUNTDOWN
var race_time := 0.0
var end_timer := 0.0
var results_shown := false
var boxes: Array = []    # {node, pos, cd}
var hazards: Array = []  # {node, type, pos, vel, life, owner, age, idx}
var boxes_picked := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if use_game_settings and game:
		player_chars = game.selected_chars.slice(0, game.num_players)
		laps = game.laps
	if player_chars.is_empty():
		player_chars = ["fejaum"]
	rng.randomize()
	_build_environment()
	track = TrackScript.new()
	add_child(track)
	_spawn_karts()
	_spawn_boxes()
	_build_views()
	_update_cameras(1.0, true)


func _make_camera(i: int) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.far = 1500.0
	cam.cull_mask &= ~(1 << (KartScript.LABEL_LAYER_BASE + i))  # RF-63
	return cam


## RF-61/62: 1 jogador usa a tela toda; 2 = em cima/embaixo; 3-4 = grade 2x2.
func _build_views() -> void:
	var n := players.size()
	if n == 1:
		var cam := _make_camera(0)
		add_child(cam)
		cameras.append(cam)
		var h: CanvasLayer = HudScript.new()
		add_child(h)
		h.setup(self, players[0], 1.0, true)
		huds.append(h)
		results_hud = h
		return
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 1 if n == 2 else 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(grid)
	var ui_scale := 0.7 if n == 2 else 0.55
	for i in n:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(svc)
		var vp := SubViewport.new()
		vp.msaa_3d = Viewport.MSAA_2X
		svc.add_child(vp)
		var cam := _make_camera(i)
		vp.add_child(cam)
		cameras.append(cam)
		var h: CanvasLayer = HudScript.new()
		vp.add_child(h)
		h.setup(self, players[i], ui_scale, false)
		huds.append(h)
	if n == 3:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.15)
		panel.add_theme_stylebox_override("panel", sb)
		grid.add_child(panel)
		var mm: Control = HudScript.MinimapScript.new()
		mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(mm)
		mm.setup(track, karts, null)
	results_hud = HudScript.new()
	results_hud.layer = 5
	add_child(results_hud)
	results_hud.setup(self, null, 1.0, false)


func _physics_process(delta: float) -> void:
	step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			to_menu()
		elif event.physical_keycode == KEY_R:
			restart()


func restart() -> void:
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func lap_of(k: Node3D) -> int:
	var n: int = track.sample_count()
	return clampi(floori(k.progress / n) + 1, 1, laps)


func all_finished() -> bool:
	for k in karts:
		if not k.finished:
			return false
	return true


# ---------------------------------------------------------------- setup

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.9)
	sky_mat.sky_horizon_color = Color(0.7, 0.82, 0.95)
	sky_mat.ground_horizon_color = Color(0.5, 0.6, 0.45)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _spawn_karts() -> void:
	var others := []
	for c in Chars.LIST:
		if not player_chars.has(c["id"]):
			others.append(c)
	others.shuffle()
	var ai_count := Chars.LIST.size() - player_chars.size()
	var order := others.slice(0, ai_count)
	for id in player_chars:
		order.append(Chars.find(id))  # humanos largam no fundo do grid (RF-30/64)
	var n: int = track.sample_count()
	players.resize(player_chars.size())
	for slot in order.size():
		var row := int(slot / 2.0)
		var col := slot % 2
		var idx := wrapi(-3 - row * 5 - col * 2, 0, n)
		var lat := -3.5 if col == 0 else 3.5
		var k: Node3D = KartScript.new()
		var p_index: int = slot - ai_count  # < 0 = IA
		add_child(k)
		k.setup(order[slot], p_index, track, self)
		k.ai_skill = rng.randf_range(0.9, 0.97)
		k.place(idx, lat)
		if p_index >= 0:
			players[p_index] = k
			k.autopilot = autopilot_player
			k.ai_skill = 1.0
		karts.append(k)
	player = players[0]


func _spawn_boxes() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 1.4, 1.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.6
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
		boxes.append({"node": node, "pos": p, "cd": 0.0})


# ---------------------------------------------------------------- loop

func step(delta: float) -> void:
	if state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "racing"
	else:
		race_time += delta
	var can_drive := state != "countdown"
	_update_rubber()
	for k in karts:
		k.step(delta, can_drive)
	if can_drive:
		_kart_collisions()
		_update_boxes(delta)
		_update_hazards(delta)
	_update_ranks()
	_check_finish(delta)
	_update_cameras(delta, false)
	for h in huds:
		h.update_hud(delta)


func humans_finished() -> bool:
	for p in players:
		if not p.finished:
			return false
	return true


## RF-43/66: referência = humano mais adiantado que ainda corre.
func _update_rubber() -> void:
	var ref := -INF
	for p in players:
		if not p.finished:
			ref = maxf(ref, p.rank_value())
	for k in karts:
		if k.is_player or ref == -INF or autopilot_player:
			k.rubber = 1.0
			continue
		var gap: float = k.rank_value() - ref
		k.rubber = clampf(1.0 - gap * 0.0006, 0.94, 1.08)


func _kart_collisions() -> void:
	var r2 := KartScript.RADIUS * 2.0
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: Node3D = karts[i]
			var b: Node3D = karts[j]
			var dv := b.position - a.position
			dv.y = 0.0
			var d := dv.length()
			if d >= r2 or d < 0.001:
				continue
			var nrm := dv / d
			var ov := r2 - d
			var wa: float = a.weight
			var wb: float = b.weight
			a.position -= nrm * ov * wb / (wa + wb)
			b.position += nrm * ov * wa / (wa + wb)
			var rel: float = (a.vel - b.vel).dot(nrm)
			if rel > 0.0:
				a.vel -= nrm * rel * wb / (wa + wb)
				b.vel += nrm * rel * wa / (wa + wb)


func _update_boxes(delta: float) -> void:
	for b in boxes:
		var node: Node3D = b["node"]
		node.rotate_y(delta * 1.5)
		if b["cd"] > 0.0:
			b["cd"] -= delta
			if b["cd"] <= 0.0:
				node.visible = true
			continue
		for k in karts:
			if k.position.distance_squared_to(b["pos"] - Vector3.UP * 1.2) < 2.6 * 2.6:
				if k.item == "" and k.spin_time <= 0.0:
					k.item = _roll_item(k.rank)
					k.item_hold = 0.0
					k.ai_item_delay = rng.randf_range(1.5, 5.0)
					boxes_picked += 1
				b["cd"] = BOX_RESPAWN
				node.visible = false
				break


func _roll_item(rank: int) -> String:
	var r := rng.randf()
	if rank <= 2:
		return "casca" if r < 0.6 else ("bomba" if r < 0.9 else "turbo")
	if rank <= 5:
		return "casca" if r < 0.3 else ("bomba" if r < 0.7 else "turbo")
	return "casca" if r < 0.1 else ("bomba" if r < 0.5 else "turbo")


func use_item(k: Node3D, it: String) -> void:
	match it:
		"turbo":
			k.boost_time = maxf(k.boost_time, KartScript.ITEM_BOOST)
		"casca":
			_spawn_hazard("casca", k.position - k.forward() * 2.4, Vector3.ZERO, 90.0, k)
		"bomba":
			var v: Vector3 = k.forward() * (maxf(k.speed, 0.0) + 40.0)
			_spawn_hazard("bomba", k.position + k.forward() * 2.5 + Vector3.UP * 0.5, v, 4.0, k)


func kart_in_sight(k: Node3D) -> bool:
	var f: Vector3 = k.forward()
	for o in karts:
		if o == k:
			continue
		var to: Vector3 = o.position - k.position
		var d := to.length()
		if d > 3.0 and d < 45.0 and f.angle_to(to / d) < 0.2:
			return true
	return false


func _spawn_hazard(type: String, pos: Vector3, v: Vector3, life: float, owner_kart: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if type == "casca":
		var m := SphereMesh.new()
		m.radius = 0.55
		m.height = 0.5
		mi.mesh = m
		mat.albedo_color = Color(1.0, 0.88, 0.15)
		pos.y = 0.25
	else:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		mi.mesh = m
		mat.albedo_color = Color(0.08, 0.08, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.05)
		mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	mi.reset_physics_interpolation()
	var idx: int = track.nearest_index(pos, owner_kart.track_idx, 12)
	hazards.append({"node": mi, "type": type, "pos": pos, "vel": v, "life": life, "owner": owner_kart, "age": 0.0, "idx": idx})


func _update_hazards(delta: float) -> void:
	var dead := []
	for h in hazards:
		h["age"] += delta
		h["life"] -= delta
		if h["life"] <= 0.0:
			dead.append(h)
			continue
		if h["type"] == "bomba":
			h["pos"] += h["vel"] * delta
			h["idx"] = track.nearest_index(h["pos"], h["idx"], 12)
			if absf(track.lateral_of(h["pos"], h["idx"])) > TrackScript.WALL - 0.4:
				dead.append(h)
				continue
			# bomba x casca: as duas somem
			for o in hazards:
				if o["type"] == "casca" and not dead.has(o) and o["pos"].distance_squared_to(h["pos"]) < 1.6 * 1.6:
					dead.append(o)
					dead.append(h)
					break
			if dead.has(h):
				continue
		h["node"].position = h["pos"]
		var radius := 1.7 if h["type"] == "bomba" else 1.5
		for k in karts:
			if k == h["owner"] and h["age"] < 0.6:
				continue
			var p: Vector3 = h["pos"]
			var kp: Vector3 = k.position
			if Vector2(p.x - kp.x, p.z - kp.z).length() < radius:
				k.hit()
				dead.append(h)
				break
	for h in dead:
		if hazards.has(h):
			hazards.erase(h)
			h["node"].queue_free()


func _update_ranks() -> void:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a, b):
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return a.rank_value() > b.rank_value())
	for i in sorted.size():
		sorted[i].rank = i + 1


func ranking() -> Array:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a, b): return a.rank < b.rank)
	return sorted


func _check_finish(delta: float) -> void:
	var n: int = track.sample_count()
	for k in karts:
		if not k.finished and k.progress >= laps * n:
			k.finished = true
			k.finish_time = race_time
			k.autopilot = true
	if state == "racing" and humans_finished():  # RF-65
		state = "finished"
		end_timer = RESULTS_DELAY
	if state == "finished" and not results_shown:
		end_timer -= delta
		if end_timer <= 0.0 or all_finished():
			results_shown = true
			if results_hud:
				results_hud.show_results()


func _update_cameras(delta: float, snap: bool) -> void:
	for i in cameras.size():
		var cam: Camera3D = cameras[i]
		var p: Node3D = players[i]
		var f: Vector3 = p.forward()
		var desired: Vector3 = p.position - f * 7.5 + Vector3.UP * 3.3
		if snap:
			cam.position = desired
		else:
			cam.position = cam.position.lerp(desired, 1.0 - exp(-8.0 * delta))
		cam.look_at(p.position + f * 5.0 + Vector3.UP * 1.2)
		var target_fov := 82.0 if p.boost_time > 0.0 else 72.0
		cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-5.0 * delta))
		if snap:
			cam.reset_physics_interpolation()
