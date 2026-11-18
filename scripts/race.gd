extends Node3D
## Orquestra a corrida: grid, contagem, itens, colisões, ranking, chegada e câmera.
## Toda a lógica roda em step(delta) — os testes chamam step() direto (RNF-02).

const TrackScript = preload("res://scripts/track.gd")
const KartScript = preload("res://scripts/kart.gd")
const HudScript = preload("res://scripts/hud.gd")
const Chars = preload("res://scripts/characters.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Gfx = preload("res://scripts/gfx.gd")
const GameScript = preload("res://scripts/game.gd")
const CHEESE_MODEL := "res://assets/kenney/food/cheese.glb"
const BANANA_MODEL := "res://assets/kenney/food/banana.glb"


const COUNTDOWN := 3.0
const BOX_RESPAWN := 3.0
const RESULTS_DELAY := 3.0
const SLIP_TIME := 1.2
const CHEESE_RESPAWN := 8.0
## RF-151: skill = faixa de habilidade da IA; rubber = limites do rubber band.
const DIFFICULTY := [
	{"name": "FÁCIL", "skill": [0.84, 0.9], "rubber": [0.92, 1.04]},
	{"name": "NORMAL", "skill": [0.9, 0.97], "rubber": [0.94, 1.08]},
	{"name": "DIFÍCIL", "skill": [0.97, 1.02], "rubber": [0.96, 1.12]},
]

var use_game_settings := true
var audio_enabled := true
var engines_enabled := true
var autopilot_player := false
var player_chars: Array = ["fejaum"]  # um por jogador humano (1..4)
var laps := 3
var track_id := "queijo"
var difficulty := 1

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
var cheeses: Array = []  # {node, pos, cd}
var rng := RandomNumberGenerator.new()
var paused := false
var pause_layer: CanvasLayer
var pause_resume_btn: Button
var sfx_players: Array = []
var sfx_next := 0
var sfx_log: Array = []   # nomes tocados (usado pelos testes)
var engines: Array = []   # {kart, player, base_db} — um loop de motor por humano

var last_beep := 4
var human_laps: Array = []
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var subviewports: Array = []
var base_fov := 72.0
var shakes: Array = []    # tremida por câmera (RF-166)
var settings_overlay: Control
const SettingsMenu = preload("res://scripts/settings_menu.gd")


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if use_game_settings and game:
		player_chars = game.selected_chars.slice(0, game.num_players)
		laps = game.laps
		track_id = game.track_id
		difficulty = game.difficulty
	if player_chars.is_empty():
		player_chars = ["fejaum"]
	rng.randomize()
	track = TrackScript.new(track_id)
	_build_environment()
	add_child(track)
	_spawn_karts()
	_spawn_boxes()
	_spawn_cheese()
	_build_views()
	_update_cameras(1.0, true)
	if audio_enabled:
		_build_audio()
	_build_pause()
	apply_settings()
	for p in players:
		human_laps.append(1)


# ---------------------------------------------------------------- áudio (RF-80..83)

func _build_audio() -> void:
	for i in 8:
		var ap := AudioStreamPlayer.new()
		ap.volume_db = -4.0
		ap.bus = "SFX"
		add_child(ap)
		sfx_players.append(ap)
	if not engines_enabled:
		return
	# RF-81/RNF-04: motor = loop WAV pré-gerado com pitch variando pela velocidade.
	# (AudioStreamGenerator derrubava o Godot 4.7 com segfault ao criar/destruir corridas.)
	var base_db := -11.0 - 2.0 * (players.size() - 1)
	for p in players:
		var ap := AudioStreamPlayer.new()
		ap.stream = Sfx.get_sound("engine")
		ap.bus = "Engine"
		ap.volume_db = -60.0
		add_child(ap)
		ap.play()
		engines.append({"kart": p, "player": ap, "base_db": base_db})


func _exit_tree() -> void:
	for e in engines:
		e["player"].stop()
	for ap in sfx_players:
		ap.stop()


func sfx(sound_name: String) -> void:
	sfx_log.append(sound_name)
	if sfx_players.is_empty():
		return
	var ap: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	ap.stream = Sfx.get_sound(sound_name)
	ap.play()


## RF-81: o loop do motor (55 Hz) sobe de tom com a velocidade; volume segue o acelerador.
func _process(delta: float) -> void:
	for e in engines:
		var ap: AudioStreamPlayer = e["player"]
		var k: Node3D = e["kart"]
		var pitch := 0.7 + absf(k.speed) * 0.05
		if k.boost_time > 0.0:
			pitch *= 1.25
		ap.pitch_scale = lerpf(ap.pitch_scale, clampf(pitch, 0.5, 3.5), 1.0 - exp(-10.0 * delta))
		var target_db: float = -60.0 if paused else float(e["base_db"]) + 3.0 * clampf(k.in_throttle, 0.0, 1.0)
		ap.volume_db = lerpf(ap.volume_db, target_db, 1.0 - exp(-8.0 * delta))


# ---------------------------------------------------------------- pause (RF-90)

func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	var opts := [["Continuar", toggle_pause], ["Configurações", open_settings], ["Reiniciar (R)", restart], ["Menu", to_menu]]
	for o in opts:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(320, 60)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(o[1])
		vb.add_child(b)
		if pause_resume_btn == null:
			GameScript.make_primary(b)
			pause_resume_btn = b
	var hint := Label.new()
	hint.text = "M: liga/desliga o som"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(hint)


func toggle_pause() -> void:
	if results_shown:
		return
	paused = not paused
	pause_layer.visible = paused
	var game := get_node_or_null("/root/Game")
	if game and game.music:
		game.music.stream_paused = paused
	if paused:
		pause_resume_btn.grab_focus()


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
		vp.msaa_3d = Gfx.msaa_for(Gfx.quality())
		subviewports.append(vp)
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


func open_settings() -> void:
	if settings_overlay:
		return
	settings_overlay = SettingsMenu.new()
	pause_layer.add_child(settings_overlay)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		pause_resume_btn.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if settings_overlay:
		return
	var pause_pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pause_pressed = true
		elif event.physical_keycode == KEY_R:
			restart()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed:
		if results_shown:
			to_menu()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func _leave() -> void:
	var game := get_node_or_null("/root/Game")
	if game and game.music:
		game.music.stream_paused = false
		game.music.pitch_scale = 1.0


func restart() -> void:
	_leave()
	get_tree().reload_current_scene()


func to_menu() -> void:
	_leave()
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
	var d: Dictionary = track.def
	var q := Gfx.quality()
	world_env = WorldEnvironment.new()
	world_env.environment = Gfx.environment(d, q)  # RF-160/163
	add_child(world_env)
	sun_light = DirectionalLight3D.new()
	var sun := sun_light
	sun.rotation = Vector3(deg_to_rad(d["sun"][1]), deg_to_rad(-35), 0)
	sun.light_color = d["sun"][2]
	sun.light_energy = d["sun"][0]
	sun.shadow_enabled = true
	sun.shadow_blur = [0.5, 1.0, 1.5][q]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [60.0, 100.0, 140.0][q]
	add_child(sun)
	# RF-182: MSAA conforme a qualidade
	get_viewport().msaa_3d = Gfx.msaa_for(q)


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
		var sk: Array = DIFFICULTY[difficulty]["skill"]
		k.ai_skill = rng.randf_range(sk[0], sk[1])
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
		boxes.append({"node": node, "pos": p, "cd": 0.0})


# ---------------------------------------------------------------- loop

func step(delta: float) -> void:
	if paused:  # RF-90 / CA-12
		return
	if state == "countdown":
		var c := int(ceil(countdown))
		if c < last_beep and c > 0:
			last_beep = c
			sfx("beep")
		countdown -= delta
		if countdown <= 0.0:
			state = "racing"
			sfx("go")
			for k in karts:
				k.on_race_start()
				if k.is_player and k.start_result != "":
					sfx("start_turbo" if k.start_result == "turbo" else "stall")
	else:
		race_time += delta
		_human_lap_sounds()
		_final_lap_music()
	var can_drive := state != "countdown"
	_update_rubber()
	for k in karts:
		k.step(delta, can_drive)
	if can_drive:
		_kart_collisions()
		_update_boxes(delta)
		_update_hazards(delta)
		_update_cheese(delta)
		_update_slipstream(delta)
	_update_ranks()
	_check_finish(delta)
	_update_cameras(delta, false)
	for h in huds:
		h.update_hud(delta)


func _human_lap_sounds() -> void:
	for i in players.size():
		var p: Node3D = players[i]
		var lap := lap_of(p)
		if lap > human_laps[i] and not p.finished:
			sfx("lap")
		human_laps[i] = lap


## RF-134: na volta final de algum humano a música acelera 8%.
func _final_lap_music() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or game.music == null:
		return
	var fast := false
	for p in players:
		if not p.finished and lap_of(p) == laps and laps > 1:
			fast = true
	game.music.pitch_scale = 1.08 if fast else 1.0


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
		var rb: Array = DIFFICULTY[difficulty]["rubber"]
		k.rubber = clampf(1.0 - gap * 0.0006, rb[0], rb[1])


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
		var node := Gfx.prop(CHEESE_MODEL, 1.2)
		node.position = p - Vector3.UP * 0.35
		add_child(node)
		cheeses.append({"node": node, "pos": p, "cd": 0.0})


func _update_cheese(delta: float) -> void:
	for c in cheeses:
		var node: Node3D = c["node"]
		node.rotate_y(delta * 2.0)
		if c["cd"] > 0.0:
			c["cd"] -= delta
			if c["cd"] <= 0.0:
				node.visible = true
			continue
		var cp: Vector3 = c["pos"]
		for k in karts:
			var kp: Vector3 = k.position
			if Vector2(cp.x - kp.x, cp.z - kp.z).length() < 1.8 and k.position.y < 2.0:
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
		node.rotate_y(delta * 1.5)
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
	var r := rng.randf()
	if rank <= 2:
		return "casca" if r < 0.6 else ("bomba" if r < 0.9 else "turbo")
	if rank <= 5:
		return "casca" if r < 0.3 else ("bomba" if r < 0.7 else "turbo")
	return "casca" if r < 0.1 else ("bomba" if r < 0.5 else "turbo")


func use_item(k: Node3D, it: String) -> void:
	if k.is_player:
		sfx({"turbo": "boost", "casca": "drop", "bomba": "shoot"}[it])
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
	var mi: Node3D
	if type == "casca":
		# RF-172: banana do Food Kit (Kenney), deitada no chão
		mi = Gfx.prop(BANANA_MODEL, 1.5)
		mi.rotation.y = randf() * TAU
		pos.y = 0.0
	else:
		var bomb := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		bomb.mesh = m
		mat.albedo_color = Color(0.08, 0.08, 0.08)
		mat.metallic = 0.4
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.05)
		mat.emission_energy_multiplier = 0.8
		bomb.material_override = mat
		mi = bomb
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
			if k.is_player:
				sfx("finish")
				k.celebrate()
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
		var desired: Vector3 = p.position - f * 8.0 + Vector3.UP * 4.1
		# outro kart colado na câmera: sobe um pouco pra ele não tapar a visão
		var near := 99.0
		for o in karts:
			if o != p:
				near = minf(near, Vector2(o.position.x - desired.x, o.position.z - desired.z).length())
		if near < 4.5:
			desired += Vector3.UP * (4.5 - near) * 0.7
		if snap:
			cam.position = desired
		else:
			cam.position = cam.position.lerp(desired, 1.0 - exp(-8.0 * delta))
		cam.look_at(p.position + f * 9.0 + Vector3.UP * 1.0)
		var target_fov := base_fov + 10.0 if p.boost_time > 0.0 else base_fov
		cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-5.0 * delta))
		# RF-166: tremida (h/v_offset não atrapalha a suavização da posição)
		while shakes.size() <= i:
			shakes.append(0.0)
		shakes[i] = maxf(0.0, shakes[i] - delta * 2.5)
		var sh: float = shakes[i]
		cam.h_offset = randf_range(-1.0, 1.0) * sh * 0.35
		cam.v_offset = randf_range(-1.0, 1.0) * sh * 0.25
		if snap:
			cam.reset_physics_interpolation()


## RF-166: tremida da câmera do jogador dono do kart.
func shake(k: Node3D, amount: float) -> void:
	if not k.is_player:
		return
	var i: int = k.player_index
	while shakes.size() <= i:
		shakes.append(0.0)
	shakes[i] = maxf(shakes[i], amount * float(Gfx.setting("shake", 1.0)))  # RF-183


## RF-180..183: aplica as configurações na corrida (chamado no início e quando o jogador
## muda algo na tela de configurações, inclusive com o jogo pausado).
func apply_settings() -> void:
	if track == null or world_env == null:
		return
	var q := Gfx.quality()
	Gfx.apply_quality(world_env.environment, q)
	sun_light.shadow_blur = [0.5, 1.0, 1.5][q]
	sun_light.directional_shadow_max_distance = [60.0, 100.0, 140.0][q]
	get_viewport().msaa_3d = Gfx.msaa_for(q)
	var rs := float(Gfx.setting("render_scale", 1.0))
	for vp in subviewports:
		vp.msaa_3d = Gfx.msaa_for(q)
		vp.scaling_3d_scale = rs
	base_fov = float(Gfx.setting("fov", 72.0))
	var names: bool = Gfx.setting("show_names", true)
	for k in karts:
		if k.name_label:
			k.name_label.visible = names
	for h in huds:
		h.apply_settings()
