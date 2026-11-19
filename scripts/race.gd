extends Node3D
## Orquestra a corrida: grid, contagem, itens, colisões, ranking, chegada e câmera.
## Toda a lógica roda em step(delta) — os testes chamam step() direto (RNF-02).

const TrackScript = preload("res://scripts/track.gd")
const KartScript = preload("res://scripts/kart.gd")
const HudScript = preload("res://scripts/hud.gd")
const Chars = preload("res://scripts/characters.gd")
const Ids = preload("res://scripts/ids.gd")
const HazardRegistry = preload("res://scripts/hazards/registry.gd")
const PowerRegistry = preload("res://scripts/powers/registry.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Gfx = preload("res://scripts/gfx.gd")
const GameScript = preload("res://scripts/game.gd")
const HazardModels = preload("res://scripts/hazard_models.gd")
const Records = preload("res://scripts/records.gd")
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
var time_trial := false  # RF-230..234: contra o relógio

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
	if game and game.has_method("hide_loading"):
		get_tree().process_frame.connect(game.hide_loading, CONNECT_ONE_SHOT)  # RF-350: tira o "Carregando"
	if use_game_settings and game:
		player_chars = game.selected_chars.slice(0, game.num_players)
		laps = game.laps
		track_id = game.track_id
		difficulty = game.difficulty
		time_trial = game.is_tt()
	if player_chars.is_empty():
		player_chars = ["fejaum"]
	if time_trial:
		player_chars = player_chars.slice(0, 1)  # RF-230: sempre 1 jogador
	rng.randomize()
	track = TrackScript.new(track_id)
	_build_environment()
	add_child(track)
	_spawn_karts()
	if not time_trial:
		_spawn_boxes()  # RF-231: sem caixas no contra o relógio
	_spawn_cheese()
	_spawn_track_hazards()  # RF-271
	if time_trial:
		_tt_setup()
	_build_views()
	_update_cameras(1.0, true)
	if audio_enabled:
		_build_audio()
	_build_pause()
	var game_m := get_node_or_null("/root/Game")
	if game_m:
		game_m.play_music(track.def.get("music", track.def["id"]))  # RF-221
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
		# motor gravado (CC0): 0.75 parado → ~1.45 no máximo; turbo +12%
		var pitch := 0.75 + absf(k.speed) * 0.022
		if k.boost_time > 0.0:
			pitch *= 1.12
		ap.pitch_scale = lerpf(ap.pitch_scale, clampf(pitch, 0.6, 2.0), 1.0 - exp(-10.0 * delta))
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
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var opts := [["Continuar", toggle_pause], ["Configurações", open_settings], ["Reiniciar (R)", restart], ["Menu", menu_from_pause]]
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
	_build_confirm()
	var hint := Label.new()
	hint.text = "M: liga/desliga o som"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(hint)
	_theme_pause(pause_layer)


## CanvasLayer não herda o tema da janela: aplica o tema do jogo (Kenney) no pause.
func _theme_pause(n: Node) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or game.theme == null:
		return
	for c in n.get_children():
		if c is Control:
			c.theme = game.theme


# ---------------------------------------------------------------- confirmação de abandonar o GP (RF-243)

var confirm_box: Control
var confirm_no_btn: Button
var confirm_yes_btn: Button


func _build_confirm() -> void:
	confirm_box = ColorRect.new()
	confirm_box.color = Color(0, 0, 0, 0.6)
	confirm_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_box.visible = false
	pause_layer.add_child(confirm_box)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_box.add_child(center)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.08, 0.14)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1.0, 0.82, 0.2, 0.8)
	st.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var q := Label.new()
	q.text = "ABANDONAR O GRAND PRIX?"
	q.add_theme_font_size_override("font_size", 36)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(q)
	var sub := Label.new()
	sub.text = "Os pontos desse GP vão ser perdidos."
	sub.modulate = Color(1, 1, 1, 0.75)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	confirm_yes_btn = Button.new()
	confirm_yes_btn.text = "SIM, SAIR"
	confirm_yes_btn.custom_minimum_size = Vector2(220, 56)
	confirm_yes_btn.pressed.connect(to_menu)
	row.add_child(confirm_yes_btn)
	confirm_no_btn = Button.new()
	confirm_no_btn.text = "NÃO"
	confirm_no_btn.custom_minimum_size = Vector2(220, 56)
	GameScript.make_primary(confirm_no_btn)
	confirm_no_btn.pressed.connect(confirm_no)
	row.add_child(confirm_no_btn)


## Botão Menu do pause: no GP pergunta antes.
func menu_from_pause() -> void:
	if not is_gp():
		to_menu()
		return
	confirm_box.visible = true
	confirm_no_btn.grab_focus()


func confirm_no() -> void:
	confirm_box.visible = false
	pause_resume_btn.grab_focus()


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
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 1 if n == 2 else 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_theme_pause(pause_layer)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		pause_resume_btn.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if settings_overlay:
		return
	if confirm_box and confirm_box.visible:
		if GameScript.is_back(event):
			confirm_no()
			get_viewport().set_input_as_handled()
		return
	var pause_pressed := false
	if (paused or results_shown) and GameScript.is_back(event):  # RF-241: B / Backspace
		pause_pressed = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pause_pressed = true
		elif event.physical_keycode == KEY_R and not (results_shown and is_gp()):  # RF-194
			restart()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed:
		get_viewport().set_input_as_handled()  # antes: to_menu tira a corrida da árvore
		if results_shown:
			to_menu()
		else:
			toggle_pause()


func _leave() -> void:
	var game := get_node_or_null("/root/Game")
	if game and game.music:
		game.music.stream_paused = false
		game.music.pitch_scale = 1.0


func restart() -> void:
	_leave()
	var game := get_node_or_null("/root/Game")
	if game:
		game.go_race(true)  # RF-350: "Carregando" enquanto a pista remonta
	else:
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
	var ai_count := 0 if time_trial else Chars.LIST.size() - player_chars.size()
	var order := others.slice(0, ai_count)
	for id in player_chars:
		order.append(Chars.find(id))  # humanos largam no fundo do grid (RF-30/64)
	var n: int = track.sample_count()
	players.resize(player_chars.size())
	for slot in order.size():
		var row := int(slot / 2.0)
		var col := slot % 2
		var idx := wrapi(-3 - row * 5 - col * 2, 0, n)
		var lat := 0.0 if time_trial else (-3.5 if col == 0 else 3.5)
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
		var bi: int = track.nearest_index(p)
		boxes.append({"node": node, "pos": p, "cd": 0.0, "idx": bi, "lat": track.lateral_of(p, bi)})


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
			sfx("crowd")  # RF-222
			for k in karts:
				k.on_race_start()
				if k.is_player and k.start_result != "":
					sfx("start_turbo" if k.start_result == "turbo" else "stall")
			if time_trial:
				player.give_item("triplo")  # RF-231
				player.item_roll = 0.0
	else:
		race_time += delta
		_human_lap_sounds()
		_final_lap_music()
	var can_drive := state != "countdown"
	_update_rubber()
	for k in karts:
		k.step(delta, can_drive)
	_update_track_hazards(delta, can_drive)
	if can_drive:
		_kart_collisions()
		_update_boxes(delta)
		_update_hazards(delta)
		_update_cheese(delta)
		_update_slipstream(delta)
	_update_ranks()
	if time_trial:
		_tt_step()  # antes do _check_finish: grava o último trecho antes do recorde
	_check_finish(delta)
	_update_cameras(delta, false)
	for h in huds:
		h.update_hud(delta)
	if results_shown and results_hud:
		results_hud.refresh_results()  # RF-360: quem termina depois entra no placar


func _human_lap_sounds() -> void:
	for i in players.size():
		var p: Node3D = players[i]
		var lap := lap_of(p)
		if lap > human_laps[i] and not p.finished:
			sfx("final_lap" if lap == laps and laps > 1 else "lap")  # RF-207: vinheta da volta final
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


## RF-200: sorteio ponderado pela posição. O GATO só sai de 5º pra trás e só um por vez.
const ITEM_TABLE := {
	"front": [["casca", 35], ["ratoeira", 20], ["escudo", 25], ["bomba", 15], ["turbo", 5]],
	"mid": [["casca", 15], ["ratoeira", 15], ["escudo", 15], ["bomba", 25], ["turbo", 20], ["triplo", 10]],
	"back": [["bomba", 20], ["turbo", 20], ["triplo", 30], ["escudo", 10], ["casca", 5], ["gato", 15]],
}
const ITEM_SFX := {"turbo": "boost", "triplo": "boost", "casca": "drop", "ratoeira": "drop", "bomba": "shoot", "gato": "meow", "escudo": "shield"}
const GATO_SPEED := 50.0
const GATO_LIFE := 15.0


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
			mi = Gfx.prop(BANANA_MODEL, 1.5)
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
	mi.position = pos
	add_child(mi)
	mi.reset_physics_interpolation()
	var idx: int = track.nearest_index(pos, owner_kart.track_idx, 12)
	if track.points[idx].distance_to(Vector3(pos.x, 0, pos.z)) > 6.0:
		idx = track.nearest_index(pos)  # dono longe do ponto (ex.: testes): busca global
	hazards.append({"node": mi, "type": type, "pos": pos, "vel": v, "life": life, "owner": owner_kart, "age": 0.0, "idx": idx})


## Perigos que ficam no chão (alvo de bombas e da IA que desvia).
const GROUND_HAZARDS := ["casca", "ratoeira"]


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
				sfx("crowd")
				k.celebrate()
	if state == "racing" and humans_finished():  # RF-65
		state = "finished"
		end_timer = RESULTS_DELAY
	if state == "finished" and not results_shown:
		end_timer -= delta
		if end_timer <= 0.0 or all_finished():
			results_shown = true
			_award_gp()  # RF-192
			_tt_submit()  # RF-232
			if results_hud:
				results_hud.show_results()


var cam_ups: Array = []  # por câmera


func _update_cameras(delta: float, snap: bool) -> void:
	for i in cameras.size():
		var cam: Camera3D = cameras[i]
		var p: Node3D = players[i]
		var fr: Array = p.cam_frame()  # RF-321: no looping a câmera gira junto
		var f: Vector3 = fr[0]
		var up: Vector3 = fr[1]
		# "pra cima" suavizado: no looping a câmera gira macio, sem tranco na entrada e na saída
		while cam_ups.size() <= i:
			cam_ups.append(Vector3.UP)
		cam_ups[i] = up if snap else (cam_ups[i] as Vector3).slerp(up, 1.0 - exp(-9.0 * delta)).normalized()
		up = cam_ups[i]
		var desired: Vector3 = p.position - f * 8.0 + up * 4.1
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
			cam.position = cam.position.lerp(desired, 1.0 - exp(-(12.0 if p.on_loop else 8.0) * delta))
		cam.look_at(p.position + f * 9.0 + up * 1.0, up)
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


# ---------------------------------------------------------------- Grand Prix (RF-190..195)

var gp_gained := {}   # id -> pontos ganhos nesta corrida


func is_gp() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.is_gp()


func _award_gp() -> void:
	if not is_gp():
		return
	var ids := []
	for k in ranking():
		ids.append(k.char_id)
	var got: Dictionary = get_node("/root/Game").gp_award(ids)
	if not got.is_empty():
		gp_gained = got


## Botão PRÓXIMA / PÓDIO DO GP.
func gp_continue() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	_leave()
	if game.gp_next():
		game.go_race(true)  # RF-350
	else:
		get_tree().change_scene_to_file("res://scenes/gp_final.tscn")


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


# ---------------------------------------------------------------- contra o relógio (RF-230..234)

var tt_record := {}                  # recorde da pista antes desta corrida
var tt_laps: Array = []              # tempo de cada volta do jogador
var tt_lap_start := 0.0
var tt_last_lap := 1
var tt_ghost_rec := PackedFloat32Array()  # gravação desta corrida (x, y, z, heading)
var tt_prev := {}                    # amostra do quadro anterior (pra gravar no instante exato)
var tt_ghost_data := PackedFloat32Array()  # fantasma do recorde (reprodução)
var tt_ghost: Node3D
var tt_result := {}                  # {"race": bool, "lap": bool} depois do submit
var tt_submitted := false


func _tt_setup() -> void:
	tt_record = Records.get_record(track.def["id"])
	tt_ghost_data = tt_record.get("ghost", PackedFloat32Array())
	if tt_ghost_data.size() < 8:
		return
	var who: Dictionary = Chars.find(String(tt_record.get("race_char", "fejaum")))
	tt_ghost = KartScript.new()
	tt_ghost.name = "Fantasma"
	add_child(tt_ghost)
	tt_ghost.setup(who, -1, track, self)
	if tt_ghost.name_label:
		tt_ghost.name_label.text = "RECORDE"
	_ghostify(tt_ghost)
	_tt_ghost_pose(0.0)


## Deixa o kart translúcido e sem sombra.
func _ghostify(n: Node) -> void:
	if n is GeometryInstance3D:
		n.transparency = 0.5
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GPUParticles3D or n is CPUParticles3D:
		n.emitting = false
		n.visible = false
	for c in n.get_children():
		_ghostify(c)


func _tt_ghost_pose(t: float) -> void:
	if tt_ghost == null:
		return
	var s := Records.ghost_sample(tt_ghost_data, t)
	if s.is_empty():
		tt_ghost.visible = t <= 0.0
		return
	tt_ghost.visible = true
	tt_ghost.position = s["pos"]
	tt_ghost.rotation.y = s["heading"]


func _tt_step() -> void:
	var t := race_time if state != "countdown" else 0.0
	_tt_ghost_pose(t)
	if state == "countdown" or player == null:
		return
	# voltas
	var lap := lap_of(player)
	if lap > tt_last_lap and not player.finished:
		tt_laps.append(race_time - tt_lap_start)
		tt_lap_start = race_time
	tt_last_lap = lap
	# RF-233: grava nos instantes exatos k*GHOST_STEP interpolando com o quadro anterior
	var cur := {"t": race_time, "pos": player.position, "h": player.heading}
	if tt_prev.is_empty():
		tt_prev = {"t": 0.0, "pos": player.position, "h": player.heading}
		_tt_push(tt_prev["pos"], tt_prev["h"])
	while not player.finished:
		var next_t := (tt_ghost_rec.size() / 4) * Records.GHOST_STEP
		if next_t > race_time:
			break
		var span: float = cur["t"] - tt_prev["t"]
		var w: float = 1.0 if span <= 0.0 else clampf((next_t - tt_prev["t"]) / span, 0.0, 1.0)
		_tt_push(tt_prev["pos"].lerp(cur["pos"], w), lerp_angle(tt_prev["h"], cur["h"], w))
	tt_prev = cur


func _tt_push(p: Vector3, h: float) -> void:
	tt_ghost_rec.append_array(PackedFloat32Array([p.x, p.y, p.z, h]))


## Fecha a última volta e grava o recorde (uma vez só).
func _tt_submit() -> void:
	if not time_trial or tt_submitted or not player.finished:
		return
	tt_submitted = true
	if tt_laps.size() < laps:
		tt_laps.append(player.finish_time - tt_lap_start)
	tt_result = Records.submit(track.def["id"], player.char_id, player.finish_time, tt_best_lap(), tt_ghost_rec)


func tt_best_lap() -> float:
	var best := INF
	for l in tt_laps:
		best = minf(best, l)
	return best


# ---------------------------------------------------------------- perigos da pista (RF-271/272, RF-450)
# Cada tipo mora em scripts/hazards/<tipo>.gd (registro em scripts/hazards/registry.gd).

var track_hazards: Array = []  # {spec, state, ...o que o script do tipo guardar}
var hazard_clock := 0.0        # anda sempre (visual); perigo só depois do VAI!


func _spawn_track_hazards() -> void:
	for s in track.hazard_specs:
		var impl := HazardRegistry.of(String(s["kind"]))
		if impl == null:
			push_warning("perigo desconhecido: %s" % s["kind"])
			continue
		var h := {"spec": s, "state": "off", "impl": impl}
		impl.spawn(self, h)
		track_hazards.append(h)
	_update_track_hazards(0.0, false)


func _update_track_hazards(delta: float, can_drive: bool) -> void:
	hazard_clock += delta
	var t_live := race_time if state != "countdown" else -1.0
	var n: int = track.sample_count()
	for h in track_hazards:
		h["impl"].update(self, h, can_drive, t_live, n)


## RF-272: perigos que a IA deve evitar agora (mesmo formato da casca: id, lat).
func _track_hazards_ahead(k: Node3D, samples: int, out: Array) -> void:
	var n: int = track.sample_count()
	for hi in track_hazards.size():
		var h: Dictionary = track_hazards[hi]
		var ds := wrapi(int(h["spec"]["idx"]) - k.track_idx, 0, n)
		if ds > 0 and ds < samples:
			h["impl"].ahead(self, h, hi, ds, out)
	for pi in track.pits.size():  # RF-390: buracos (desvio obrigatório)
		var pt: Dictionary = track.pits[pi]
		var dp := wrapi(int(pt["idx"]) - k.track_idx, 0, n)
		if dp > 0 and dp < samples:
			out.append({"id": 3000000 + pi, "lat": float(pt["lat"]), "r": float(pt["r"]), Ids.AHEAD_PIT: true})
	for zi in track.zones.size():
		var z: Dictionary = track.zones[zi]
		if not Ids.SLOW_ZONES.has(z["kind"]):
			continue
		var dz := wrapi(int(z["i0"]) - k.track_idx, 0, n)
		if dz > 0 and dz < samples:
			out.append({"id": 2000000 + zi, "lat": (float(z["lat0"]) + float(z["lat1"])) * 0.5})


# ---------------------------------------------------------------- poderes (RF-420..428, RF-451)
# Cada poder mora em scripts/powers/<id>.gd (registro em scripts/powers/registry.gd).

signal power_used(k: Node3D, power: String, msg: String)


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
