extends "res://scripts/race_state.gd"
## Corrida — mundo: ambiente, câmeras e tela dividida, karts no grid, áudio e configurações gráficas.
## (camada de race.gd — ver o topo de race.gd)


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
	sun.shadow_enabled = q >= 1  # RF-478: no BAIXO (padrão do navegador) sem sombra do sol: metade dos desenhos
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


## RF-180..183: aplica as configurações na corrida (chamado no início e quando o jogador
## muda algo na tela de configurações, inclusive com o jogo pausado).
func apply_settings() -> void:
	if track == null or world_env == null:
		return
	var q := Gfx.quality()
	Gfx.apply_quality(world_env.environment, q)
	sun_light.shadow_enabled = q >= 1  # RF-478
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


# ---------------------------------------------------------------- shaders prontos antes da largada (RF-480)

## O Godot só prepara (compila) o shader de um objeto quando ele aparece na tela pela 1ª vez. No
## navegador isso trava a página por um instante: cada trecho de pista, item ou efeito novo era um
## tranco no meio da corrida. Aqui, ainda com a tela de "Carregando", uma câmera de cima enxerga a
## pista inteira e uma vitrine com um exemplo de cada coisa que só aparece depois (itens no chão,
## escudo, anéis dos poderes, kart fantasma, faíscas e fogo). Tudo é desenhado uma vez e some.
var warmup: SubViewport
const WARMUP_LAYER := 1 << 19   # camada 20 do 3D: só a vitrine do aquecimento


func _warm_up_shaders() -> void:
	if track == null or track.points.is_empty():
		return
	var lo: Vector3 = track.points[0]
	var hi: Vector3 = track.points[0]
	for p in track.points:
		lo = lo.min(p)
		hi = hi.max(p)
	var center := (lo + hi) * 0.5
	warmup = SubViewport.new()
	warmup.name = "ShaderWarmup"
	warmup.size = Vector2i(320, 180)
	warmup.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(warmup)   # mesmo mundo 3D da corrida (mesmo céu, neblina e luz = mesmos shaders)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(hi.x - lo.x, hi.z - lo.z) + 120.0
	cam.near = 1.0
	cam.far = hi.y - lo.y + 1200.0
	cam.position = Vector3(center.x, hi.y + 600.0, center.z)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	warmup.add_child(cam)
	cam.current = true
	# vitrine: um exemplo de cada visual que só nasce durante a corrida
	var show := Node3D.new()
	show.name = "Showcase"
	show.position = Vector3(center.x, hi.y + 20.0, center.z)
	add_child(show)
	var things: Array = [Gfx.prop(BANANA_MODEL, 1.5), HazardModels.mousetrap(), HazardModels.cat(), HazardModels.bomb()]
	var shield := MeshInstance3D.new()
	shield.mesh = SphereMesh.new()
	var shm := ShaderMaterial.new()
	shm.shader = KartScript.ShieldShader
	shield.material_override = shm
	things.append(shield)
	for unshaded in [false, true]:  # anel do FeJauM (luz) e do baixo (sem luz): transparentes e brilhando
		var ring := MeshInstance3D.new()
		ring.mesh = TorusMesh.new()
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1, 1, 1, 0.8)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.emission_enabled = true
		if unshaded:
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		things.append(ring)
	if not karts.is_empty():
		var k0: Node3D = karts[0]
		var ghost: Node3D = k0.model.duplicate()  # poder do fantasma: o kart fica transparente
		for gi in ghost.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).transparency = 0.65
		things.append(ghost)
		for pp in k0.find_children("*", "CPUParticles3D", true, false):
			var cp: CPUParticles3D = pp.duplicate()
			cp.preprocess = 0.3
			cp.set_meta("warm_emit", true)
			things.append(cp)
	for i in things.size():
		var n: Node3D = things[i]
		n.position = Vector3((i % 6) * 3.0, 0.0, (i / 6) * 3.0)
		show.add_child(n)
		if n.has_meta("warm_emit"):
			(n as CPUParticles3D).emitting = true  # só depois de entrar na cena
	Gfx.simplify_meshes(show)
	# a vitrine fica numa camada que só a câmera do aquecimento vê (o jogador nunca enxerga)
	for vi in show.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = WARMUP_LAYER
	for c in find_children("*", "Camera3D", true, false):
		if c != cam:
			(c as Camera3D).cull_mask &= ~WARMUP_LAYER
	_end_warm_up.call_deferred(show)


func _end_warm_up(show: Node3D) -> void:
	for i in 3:
		await get_tree().process_frame  # 3 quadros: o 1º já desenhou (e compilou) tudo
	if is_instance_valid(show):
		show.queue_free()
	if is_instance_valid(warmup):
		warmup.queue_free()
		warmup = null
