extends "res://scripts/track_visuals.gd"
## Pista — cenário: pórtico, arquibancada, boxes, decoração de cada tema (árvores, geladeira, telhados, feira...).
## (camada de track.gd — ver o topo de track.gd)


# ---------------------------------------------------------------- telhados (RF-330..333)

## Prédios embaixo dos trechos de telhado (um bloco por trecho entre vãos), com janelas.
func _build_rooftops() -> void:
	if not def.get("buildings", false):
		return
	var n := points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var facades := [Color(0.78, 0.68, 0.55), Color(0.62, 0.7, 0.78), Color(0.8, 0.6, 0.55), Color(0.7, 0.75, 0.62), Color(0.85, 0.8, 0.68)]
	var boxes: Array = []
	var box_cols: Array = []
	var lit: Array[Transform3D] = []
	var dark: Array[Transform3D] = []
	var seg := 0
	var was_gap := false
	for i in range(0, n, 5):
		var g := gap_at(i) or gap_at((i + 2) % n)
		if g:
			was_gap = true
			continue
		if was_gap:
			seg += 1
			was_gap = false
		var top := points[i].y - 0.9
		var w := wall_at(i) + WALL_T
		var yaw := Basis(Vector3.UP, heading_at(i))
		var base := Vector3(points[i].x, 0.0, points[i].z)
		boxes.append(Transform3D(yaw.scaled(Vector3(w * 2.0, top, 10.6)), base + Vector3.UP * top * 0.5))
		box_cols.append(facades[seg % facades.size()])
		for s in [1.0, -1.0]:
			var y := 3.0
			while y < top - 1.5:
				for c in [-2.5, 2.5]:
					var p: Vector3 = base + rights[i] * s * (w + 0.06) + tangents[i] * c
					p.y = y
					(lit if rng.randf() < 0.45 else dark).append(Transform3D(yaw, p))
				y += 3.6
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	_multimesh_colored(cube, boxes, box_cols, _vc_mat(0.85))
	_windows(lit, dark)
	scenery_count += boxes.size()
	# varais de roupa atravessando a pista (só enfeite: ficam bem acima dos karts)
	var poles: Array[Transform3D] = []
	var lines: Array[Transform3D] = []
	var clothes: Array = []
	var cloth_cols: Array = []
	var cpal := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.9, 0.3), Color(0.95, 0.95, 0.95), Color(0.5, 0.85, 0.45), Color(0.95, 0.55, 0.8)]
	for f in def.get("clotheslines", []):
		var i := int(n * float(f))
		var w := wall_at(i) + 0.4
		var yaw := Basis(Vector3.UP, heading_at(i))
		for s in [1.0, -1.0]:
			poles.append(Transform3D(yaw, points[i] + rights[i] * s * w + Vector3.UP * 3.5))
		lines.append(Transform3D(yaw, points[i] + Vector3.UP * 6.8))
		var k := 0
		var lat := -w + 1.5
		while lat < w - 1.5:
			var sz := Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(1.4, 2.4), 0.08)
			clothes.append(Transform3D(yaw.scaled(sz), points[i] + rights[i] * lat + Vector3.UP * (6.7 - sz.y * 0.5)))
			cloth_cols.append(cpal[(k + i) % cpal.size()])
			lat += sz.x + rng.randf_range(0.4, 1.4)
			k += 1
	if not poles.is_empty():
		var pole := CylinderMesh.new()
		pole.top_radius = 0.12
		pole.bottom_radius = 0.15
		pole.height = 7.0
		pole.material = _deco_mat(Color(0.35, 0.35, 0.38))
		_multimesh(pole, poles, Vector3.ZERO)
		var line := BoxMesh.new()
		line.size = Vector3((ROAD_HALF + CURB + OFFROAD + 0.4) * 2.0, 0.05, 0.05)
		line.material = _deco_mat(Color(0.9, 0.9, 0.9))
		_multimesh(line, lines, Vector3.ZERO)
		var cloth := BoxMesh.new()
		cloth.size = Vector3.ONE
		var cm := _vc_mat(0.9)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_multimesh_colored(cloth, clothes, cloth_cols, cm)
		scenery_count += clothes.size()


## Janelas: acesas (amarelo que brilha) e apagadas.
func _windows(lit: Array[Transform3D], dark: Array[Transform3D]) -> void:
	var win := BoxMesh.new()
	win.size = Vector3(1.4, 1.9, 1.4)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.85, 0.45)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.78, 0.35)
	lm.emission_energy_multiplier = 1.6
	win.material = lm
	if not lit.is_empty():
		_multimesh(win, lit, Vector3.ZERO)
	var dwin := BoxMesh.new()
	dwin.size = win.size
	dwin.material = _deco_mat(Color(0.12, 0.14, 0.22))
	if not dark.is_empty():
		_multimesh(dwin, dark, Vector3.ZERO)


## Lua cheia grande no céu (não some na neblina).
func _build_moon() -> void:
	if not def.get("moon", false):
		return
	var c := (bounds_max + bounds_min) * 0.5
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 60.0
	sm.height = 120.0
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.97, 0.85)
	mm.disable_fog = true
	moon.material_override = mm
	moon.position = Vector3(c.x + 700.0, 380.0, c.y - 900.0)
	moon.name = "Moon"
	add_child(moon)


## Ilha de barracas (calçada + bancas + toldos por cima do atalho) e barracas nos trechos apertados.
func _build_market() -> void:
	if islands.is_empty() and not def.get("market", false):
		return
	var n := points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tables: Array = []
	var table_cols: Array = []
	var fruit: Array = []
	var fruit_cols: Array = []
	var posts: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var fpal := [Color(1.0, 0.55, 0.1), Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.2), Color(0.55, 0.2, 0.5)]
	for isl in islands:
		var la: float = isl["lat0"]
		var lb: float = isl["lat1"]
		var side: float = isl["side"]
		for k in int(isl["len"]):
			var i := (int(isl["i0"]) + k) % n
			# calçada da ilha (um degrau)
			_strip_e(st, i, la, lb, la, lb, 0.25, 0.25, Color(0.78, 0.76, 0.72))
			for e in [la, lb]:
				_strip_e(st, i, e, e, e, e, 0.0, 0.25, Color(0.6, 0.58, 0.55))
			if k % 4 != 1:
				continue
			# banca: mesa com frutas, dois postes e o toldo inclinado por cima da faixa do atalho
			var yaw := Basis(Vector3.UP, heading_at(i))
			var mid := (la + lb) * 0.5
			var c := points[i] + rights[i] * mid
			tables.append(Transform3D(yaw.scaled(Vector3(lb - la - 1.0, 1.0, 6.0)), c + Vector3.UP * 0.75))
			table_cols.append(Color(0.55, 0.36, 0.2))
			for q in 6:
				var fp := c + rights[i] * rng.randf_range(la - mid + 0.8, lb - mid - 0.8) + tangents[i] * rng.randf_range(-2.5, 2.5) + Vector3.UP * 1.45
				var s := rng.randf_range(0.5, 0.9)
				fruit.append(Transform3D(Basis().scaled(Vector3.ONE * s), fp))
				fruit_cols.append(fpal[(k + q) % fpal.size()])
			var edge_in := la if side < 0.0 else lb          # lado do atalho
			var far := -road_half(i) + 1.0 if side < 0.0 else road_half(i) - 1.0
			for t in [-3.0, 3.0]:
				posts.append(Transform3D(yaw, points[i] + rights[i] * edge_in + tangents[i] * t + Vector3.UP * AWNING_H * 0.5))
			var col: Color = STALL_COLS[(k / 4) % STALL_COLS.size()]
			for stripe in 4:
				var f0 := float(stripe) / 4.0
				var f1 := float(stripe + 1) / 4.0
				var l0 := lerpf(edge_in, far, f0)
				var l1 := lerpf(edge_in, far, f1)
				var y0 := lerpf(AWNING_H, AWNING_H - 0.8, f0)
				var y1 := lerpf(AWNING_H, AWNING_H - 0.8, f1)
				var cc := col if stripe % 2 == 0 else Color(0.97, 0.97, 0.95)
				var a0 := points[i] + rights[i] * l0 - tangents[i] * 3.6 + Vector3.UP * y0
				var b0 := points[i] + rights[i] * l1 - tangents[i] * 3.6 + Vector3.UP * y1
				var b1 := points[i] + rights[i] * l1 + tangents[i] * 3.6 + Vector3.UP * y1
				var a1 := points[i] + rights[i] * l0 + tangents[i] * 3.6 + Vector3.UP * y0
				_quad(st, a0, b0, b1, a1, cc)
	# barracas coladas no muro nos trechos apertados (a pista "afunila entre as barracas")
	for i in range(0, n, 5):
		if road_half(i) >= ROAD_HALF - 1.5 or not island_at(i).is_empty():
			continue
		var yaw := Basis(Vector3.UP, heading_at(i))
		for s in [1.0, -1.0]:
			var w := wall_at(i) + WALL_T + 1.8
			var c: Vector3 = points[i] + rights[i] * s * w
			tables.append(Transform3D(yaw.scaled(Vector3(3.0, 1.0, 8.0)), c + Vector3.UP * 0.75))
			table_cols.append(Color(0.55, 0.36, 0.2))
			for q in 5:
				var fp: Vector3 = c + rights[i] * rng.randf_range(-1.0, 1.0) + tangents[i] * rng.randf_range(-3.2, 3.2) + Vector3.UP * 1.45
				fruit.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 0.9)), fp))
				fruit_cols.append(fpal[(i + q) % fpal.size()])
			var col: Color = STALL_COLS[(i / 5 + (1 if s > 0 else 0)) % STALL_COLS.size()]
			# toldo inclinado pra pista, por cima do muro
			var l_out: float = s * (w + 2.0)
			var l_in: float = s * (wall_at(i) - 0.6)
			for stripe in 4:
				var f0 := float(stripe) / 4.0
				var f1 := float(stripe + 1) / 4.0
				var cc := col if stripe % 2 == 0 else Color(0.97, 0.97, 0.95)
				var p0 := lerpf(l_out, l_in, f0)
				var p1 := lerpf(l_out, l_in, f1)
				var y0 := lerpf(SIDE_AWNING_H + 0.8, SIDE_AWNING_H, f0)
				var y1 := lerpf(SIDE_AWNING_H + 0.8, SIDE_AWNING_H, f1)
				_quad(st, points[i] + rights[i] * p0 - tangents[i] * 4.4 + Vector3.UP * y0, points[i] + rights[i] * p1 - tangents[i] * 4.4 + Vector3.UP * y1,
					points[i] + rights[i] * p1 + tangents[i] * 4.4 + Vector3.UP * y1, points[i] + rights[i] * p0 + tangents[i] * 4.4 + Vector3.UP * y0, cc)
			posts.append(Transform3D(yaw.scaled(Vector3(1, (SIDE_AWNING_H + 0.8) / AWNING_H, 1)), points[i] + rights[i] * s * (w + 2.0) + Vector3.UP * (SIDE_AWNING_H + 0.8) * 0.5))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := _vc_mat(0.8)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "Market"
	add_child(mi)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	_multimesh_colored(cube, tables, table_cols, _vc_mat(0.85))
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	_multimesh_colored(ball, fruit, fruit_cols, _vc_mat(0.5))
	var post := CylinderMesh.new()
	post.top_radius = 0.1
	post.bottom_radius = 0.1
	post.height = AWNING_H
	post.material = _deco_mat(Color(0.75, 0.75, 0.78))
	if not posts.is_empty():
		_multimesh(post, posts, Vector3.ZERO)
	scenery_count += tables.size()
	_market_signs()


## Barraca do pastel e do caldo de cana perto da largada, com placa.
func _market_signs() -> void:
	var n := points.size()
	var spots := [[int(n * 0.03), 1.0, "PASTEL", Color(0.95, 0.75, 0.2)], [int(n * 0.97), -1.0, "CALDO DE CANA", Color(0.45, 0.8, 0.3)]]
	for sp in spots:
		var i: int = sp[0]
		var s: float = sp[1]
		var pos: Vector3 = points[i] + rights[i] * s * (wall_at(i) + 6.0)
		pos.y = 0.0
		var yaw := Basis.looking_at(-rights[i] * s)
		var booth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.0, 3.0, 4.0)
		booth.mesh = bm
		booth.material_override = _deco_mat(Color(0.95, 0.95, 0.92))
		booth.basis = yaw
		booth.position = pos + Vector3.UP * 1.5
		add_child(booth)
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(9.0, 0.4, 5.0)
		roof.mesh = rm
		roof.material_override = _deco_mat(sp[3])
		roof.basis = yaw
		roof.position = pos + Vector3.UP * 5.2
		add_child(roof)
		for x in [-4.2, 4.2]:
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.12
			pm.bottom_radius = 0.12
			pm.height = 2.2
			pole.mesh = pm
			pole.material_override = _deco_mat(Color(0.7, 0.7, 0.72))
			pole.position = pos + yaw * Vector3(x, 4.1, 0.0)
			add_child(pole)
		var lbl := Label3D.new()
		lbl.text = sp[2]
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.outline_size = 16
		lbl.modulate = Color(1, 1, 1)
		lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lbl.position = pos + Vector3.UP * 6.4
		add_child(lbl)
		scenery_count += 1


## RF-173: pórtico de largada com semáforo (Racing Kit) e o nome do jogo.
func _build_arch() -> void:
	var gantry := Gfx.prop(RACING + "overheadLights.glb", (ROAD_HALF + 3.0) * 2.0)
	gantry.name = "StartGantry"
	gantry.position = points[0]
	gantry.basis = Basis(Vector3.UP, heading_at(0))
	add_child(gantry)
	var box := Gfx.aabb_of(gantry)
	# placa em cima do pórtico, com o nome em cada face (cada texto só de um lado, sem
	# espelhar: Label3D é dupla face por padrão e os dois se sobrepunham ilegíveis)
	var sign_y := box.size.y + 1.3
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(15.0, 2.4, 0.5)
	panel.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.1, 0.14)
	panel.material_override = pmat
	panel.position = Vector3(0, sign_y, 0)
	panel.name = "StartSign"
	gantry.add_child(panel)
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "Car Mundon'GO"
		lbl.font_size = 110
		lbl.pixel_size = 0.014
		lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.85, 0.2)
		lbl.double_sided = false
		lbl.position = Vector3(0, sign_y, side * 0.28)
		if side < 0:
			lbl.rotation.y = PI
		gantry.add_child(lbl)
	_start_lights(gantry, box)


## RF-460: semáforo da largada — 3 lâmpadas que acendem vermelhas no 3, 2, 1 e ficam verdes
## no VAI! (as lâmpadas do modelo, que eram uma peça só, ficam apagadas por baixo).
const LAMP_COUNT := 3
const LAMP_OFF := Color(0.12, 0.1, 0.1)
const LAMP_RED := Color(1.0, 0.12, 0.08)
const LAMP_GREEN := Color(0.15, 1.0, 0.3)
var start_lamps: Array = []   # StandardMaterial3D de cada lâmpada (as duas faces usam o mesmo)
var start_lamp_state := -2


func _start_lights(gantry: Node3D, box: AABB) -> void:
	for mi in gantry.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m and m.get_surface_count() > 2:
			(mi as MeshInstance3D).set_surface_override_material(2, _deco_mat(LAMP_OFF))
	var depth: float = box.size.z + 0.5
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.4, 2.0, depth)
	board.mesh = bm
	board.material_override = _deco_mat(Color(0.08, 0.08, 0.1))
	board.position = Vector3(0, box.size.y - 1.4, 0)
	board.name = "StartLights"
	gantry.add_child(board)
	for k in LAMP_COUNT:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = LAMP_OFF
		mat.emission_enabled = true
		mat.emission = LAMP_OFF
		mat.emission_energy_multiplier = 0.0
		start_lamps.append(mat)
		for side in [1.0, -1.0]:
			var lamp := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.62
			cm.bottom_radius = 0.62
			cm.height = 0.12
			lamp.mesh = cm
			lamp.material_override = mat
			lamp.rotation.x = PI / 2.0
			lamp.position = Vector3((k - (LAMP_COUNT - 1) * 0.5) * 1.6, 0.0, side * (depth * 0.5 + 0.03))
			board.add_child(lamp)


## Acende as lâmpadas: lit = quantas vermelhas (0..3); green = todas verdes (VAI!).
func set_start_lights(lit: int, green: bool) -> void:
	var st := -1 if green else lit
	if st == start_lamp_state:
		return
	start_lamp_state = st
	for k in start_lamps.size():
		var mat: StandardMaterial3D = start_lamps[k]
		var on := green or k < lit
		var c: Color = LAMP_GREEN if green else (LAMP_RED if on else LAMP_OFF)
		mat.albedo_color = c
		mat.emission = c
		mat.emission_energy_multiplier = 3.5 if on else 0.0


## RF-173: boxes, tendas, torres de faixa e outdoors do Racing Kit perto da largada.
func _racing_props() -> void:
	var n := points.size()
	# lado oposto ao da arquibancada
	var side := -1.0 if _clear_of_track(points[0] + rights[0] * (WALL + 20.0), 6.0) else 1.0
	var placed := 0
	var spots := [
		[-14, "pitsGarage.glb", 13.0], [-7, "pitsGarage.glb", 13.0], [0, "pitsOffice.glb", 13.0],
		[7, "tentLong.glb", 12.0], [14, "tent.glb", 9.0],
	]
	for sp in spots:
		var i := wrapi(int(sp[0]), 0, n)
		var pos: Vector3 = points[i] + rights[i] * side * (WALL + 11.0)
		pos.y = 0.0
		if not _clear_of_track(pos, 7.0):
			continue
		var p := Gfx.prop(RACING + String(sp[1]), float(sp[2]))
		p.position = pos
		p.basis = Basis.looking_at(rights[i] * side)  # frente (+Z) virada pra pista
		add_child(p)
		placed += 1
	# torres de faixa nas pontas da reta
	for k in [-22, 22]:
		for s in [-1.0, 1.0]:
			var i := wrapi(k, 0, n)
			var pos: Vector3 = points[i] + rights[i] * s * (WALL + 3.5)
			if not _clear_of_track(pos, 2.0):
				continue
			var t := Gfx.prop(RACING + ("bannerTowerRed.glb" if s > 0 else "bannerTowerGreen.glb"), 9.0, true)
			t.position = pos
			t.basis = Basis(Vector3.UP, heading_at(i))
			add_child(t)
			placed += 1
	# outdoors espalhados pela pista, virados pra ela
	for f in [0.22, 0.42, 0.62, 0.84]:
		var i := int(n * f)
		var s := 1.0 if (int(f * 100) / 2) % 2 == 0 else -1.0
		var pos: Vector3 = points[i] + rights[i] * s * (WALL + 7.0)
		if not _clear_of_track(pos, 4.0):
			s = -s
			pos = points[i] + rights[i] * s * (WALL + 7.0)
			if not _clear_of_track(pos, 4.0):
				continue
		var b := Gfx.prop(RACING + "billboard.glb", 9.0)
		b.position = pos
		b.basis = Basis.looking_at(rights[i] * s)
		add_child(b)
		placed += 1
	scenery_count += placed


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 160 and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(bounds_min.x - 120, bounds_max.x + 120), 0, rng.randf_range(bounds_min.y - 120, bounds_max.y + 120))
		if not _clear_of_track(p, 6.0):
			continue
		var s := rng.randf_range(0.8, 1.6)
		xforms.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p))
	var deco_color: Color = def["deco_color"]
	match def["deco"]:
		"skewer":
			# RF-273: espetos gigantes fincados na mesa (metade) e garrafas de vidro (outra metade)
			var sk: Array[Transform3D] = []
			var bt: Array[Transform3D] = []
			for i in xforms.size():
				(sk if i % 2 == 0 else bt).append(xforms[i])
			var stick := CylinderMesh.new()
			stick.top_radius = 0.12
			stick.bottom_radius = 0.12
			stick.height = 11.0
			stick.material = _deco_mat(Color(0.75, 0.75, 0.78))
			_multimesh(stick, sk, Vector3(0, 5.5, 0))
			var chunk_cols := [Color(0.45, 0.2, 0.1), Color(0.85, 0.75, 0.85), Color(0.2, 0.55, 0.15), Color(0.55, 0.15, 0.1)]
			for c in chunk_cols.size():
				var chunk := BoxMesh.new()
				chunk.size = Vector3(1.3, 1.1, 1.3)
				chunk.material = _deco_mat(chunk_cols[c])
				_multimesh(chunk, sk, Vector3(0, 3.0 + c * 1.6, 0))
			var glass := CylinderMesh.new()
			glass.top_radius = 1.0
			glass.bottom_radius = 1.0
			glass.height = 5.0
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.15, 0.45, 0.2, 0.75)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.1
			gm.metallic_specular = 1.0
			glass.material = gm
			var neck := CylinderMesh.new()
			neck.top_radius = 0.35
			neck.bottom_radius = 0.9
			neck.height = 2.2
			neck.material = gm
			var label := CylinderMesh.new()
			label.top_radius = 1.03
			label.bottom_radius = 1.03
			label.height = 1.6
			label.material = _deco_mat(Color(0.95, 0.85, 0.2))
			_multimesh(glass, bt, Vector3(0, 2.5, 0))
			_multimesh(neck, bt, Vector3(0, 6.1, 0))
			_multimesh(label, bt, Vector3(0, 2.6, 0))
		"city":
			# RF-333: a vila em volta — prédios com janelas, caixas de água e antenas nos telhados
			var rngc := RandomNumberGenerator.new()
			rngc.seed = 777
			var bx: Array = []
			var bc: Array = []
			var lit: Array[Transform3D] = []
			var dark: Array[Transform3D] = []
			var tanks: Array[Transform3D] = []
			var masts: Array[Transform3D] = []
			var pal := [Color(0.55, 0.5, 0.48), Color(0.45, 0.5, 0.6), Color(0.6, 0.45, 0.4), Color(0.5, 0.55, 0.45), Color(0.65, 0.6, 0.52)]
			for i in xforms.size():
				var o := xforms[i].origin
				if not _clear_of_track(o, 14.0):
					continue  # prédio largo não pode invadir a pista
				var h := rngc.randf_range(10.0, 34.0)
				var w := rngc.randf_range(14.0, 22.0)
				var d := rngc.randf_range(14.0, 22.0)
				var yaw := Basis(Vector3.UP, rngc.randf() * TAU)
				bx.append(Transform3D(yaw.scaled(Vector3(w, h, d)), o + Vector3.UP * h * 0.5))
				bc.append((pal[i % pal.size()] as Color).darkened(rngc.randf() * 0.2))
				for face in 4:
					var nrm: Vector3 = yaw * [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][face]
					var half := (w if face < 2 else d) * 0.5
					var span := (d if face < 2 else w) * 0.5 - 2.0
					var along: Vector3 = nrm.cross(Vector3.UP).normalized()
					var y := 3.0
					while y < h - 2.0:
						var x := -span
						while x <= span:
							if rngc.randf() < 0.3:
								lit.append(Transform3D(yaw, o + nrm * (half + 0.05) + along * x + Vector3.UP * y))
							x += 4.0
						y += 3.6
				if i % 3 == 0:
					tanks.append(Transform3D(Basis(), o + Vector3.UP * h))
				elif i % 3 == 1:
					masts.append(Transform3D(Basis(), o + Vector3.UP * h))
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			_multimesh_colored(cube, bx, bc, _vc_mat(0.9))
			_windows(lit, dark)
			var tank := CylinderMesh.new()
			tank.top_radius = 2.2
			tank.bottom_radius = 2.2
			tank.height = 3.2
			tank.material = _deco_mat(Color(0.3, 0.42, 0.65))
			_multimesh(tank, tanks, Vector3(0, 3.6, 0))
			var legs := BoxMesh.new()
			legs.size = Vector3(3.6, 2.0, 3.6)
			legs.material = _deco_mat(Color(0.25, 0.25, 0.28))
			_multimesh(legs, tanks, Vector3(0, 1.0, 0))
			var mast := CylinderMesh.new()
			mast.top_radius = 0.08
			mast.bottom_radius = 0.12
			mast.height = 6.0
			mast.material = _deco_mat(Color(0.7, 0.7, 0.72))
			_multimesh(mast, masts, Vector3(0, 3.0, 0))
			var bar := BoxMesh.new()
			bar.size = Vector3(3.0, 0.08, 0.08)
			bar.material = mast.material
			_multimesh(bar, masts, Vector3(0, 5.0, 0))
			_multimesh(bar, masts, Vector3(0, 4.0, 0))
		"market":
			# RF-372: em volta da rua — tendas coloridas (metade) e pilhas de caixotes com fruta (metade)
			var tents: Array = []
			var tent_cols: Array = []
			var crates: Array = []
			var crate_cols: Array = []
			var tops: Array = []
			var top_cols: Array = []
			var fp := [Color(1.0, 0.55, 0.1), Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.2)]
			for i in xforms.size():
				var o := xforms[i].origin
				var yaw := Basis(Vector3.UP, float(i) * 2.3)
				if i % 2 == 0:
					tents.append(Transform3D(yaw.scaled(Vector3(7.0, 2.6, 5.0)), o + Vector3.UP * 1.3))
					tent_cols.append(Color(0.95, 0.95, 0.92))
					tops.append(Transform3D(yaw.scaled(Vector3(8.0, 2.4, 6.0)), o + Vector3.UP * 3.8))
					top_cols.append(STALL_COLS[(i / 2) % STALL_COLS.size()])
				else:
					for h in 3:
						crates.append(Transform3D(yaw.scaled(Vector3(2.4, 1.3, 1.8)), o + Vector3.UP * (0.65 + h * 1.35)))
						crate_cols.append(Color(0.62, 0.42, 0.22).darkened(0.08 * h))
					tops.append(Transform3D(Basis().scaled(Vector3(2.0, 0.8, 1.5)), o + Vector3.UP * 4.4))
					top_cols.append(fp[i % fp.size()])
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			_multimesh_colored(cube, tents, tent_cols, _vc_mat(0.8))
			_multimesh_colored(cube, crates, crate_cols, _vc_mat(0.9))
			var prism := PrismMesh.new()
			prism.size = Vector3.ONE
			_multimesh_colored(prism, tops, top_cols, _vc_mat(0.7))
		"fridge":
			# RF-324: comida gigante de geladeira — caixas de leite, potes de iogurte, ovos e garrafas
			var groups: Array = [[], [], [], []]
			for i in xforms.size():
				(groups[i % 4] as Array).append(xforms[i])
			var milk: Array[Transform3D] = []
			milk.assign(groups[0])
			var carton := BoxMesh.new()
			carton.size = Vector3(5.0, 11.0, 5.0)
			carton.material = _deco_mat(Color(0.97, 0.97, 0.98))
			_multimesh(carton, milk, Vector3(0, 5.5, 0))
			var band := BoxMesh.new()
			band.size = Vector3(5.1, 3.0, 5.1)
			band.material = _deco_mat(Color(0.25, 0.55, 0.95))
			_multimesh(band, milk, Vector3(0, 6.5, 0))
			var roof := PrismMesh.new()
			roof.size = Vector3(5.0, 2.2, 5.0)
			roof.material = _deco_mat(Color(0.95, 0.95, 0.97))
			_multimesh(roof, milk, Vector3(0, 12.1, 0))
			var yog: Array[Transform3D] = []
			yog.assign(groups[1])
			var pot := CylinderMesh.new()
			pot.top_radius = 3.0
			pot.bottom_radius = 2.4
			pot.height = 5.0
			pot.material = _deco_mat(Color(1.0, 0.92, 0.95))
			_multimesh(pot, yog, Vector3(0, 2.5, 0))
			var lid := CylinderMesh.new()
			lid.top_radius = 3.15
			lid.bottom_radius = 3.15
			lid.height = 0.25
			lid.material = _deco_mat(Color(0.9, 0.3, 0.5))
			_multimesh(lid, yog, Vector3(0, 5.1, 0))
			var eggs: Array[Transform3D] = []
			for x in groups[2]:
				eggs.append(Transform3D(x.basis.scaled(Vector3(1.0, 1.3, 1.0)), x.origin))
			var egg := SphereMesh.new()
			egg.radius = 2.2
			egg.height = 4.4
			egg.material = _deco_mat(Color(0.98, 0.9, 0.78))
			_multimesh(egg, eggs, Vector3(0, 2.6, 0))
			var bot: Array[Transform3D] = []
			bot.assign(groups[3])
			var bottle := CylinderMesh.new()
			bottle.top_radius = 1.6
			bottle.bottom_radius = 1.6
			bottle.height = 9.0
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(0.85, 0.15, 0.1)
			bm.roughness = 0.3
			bottle.material = bm
			_multimesh(bottle, bot, Vector3(0, 4.5, 0))
			var cap := CylinderMesh.new()
			cap.top_radius = 0.6
			cap.bottom_radius = 1.2
			cap.height = 2.0
			cap.material = _deco_mat(Color(0.95, 0.95, 0.95))
			_multimesh(cap, bot, Vector3(0, 10.0, 0))
		"playground":
			# RF-304: praça — árvores do Racing Kit, balanços (pórtico + assentos) e bolas coloridas
			var trees: Array[Transform3D] = []
			var swings: Array[Transform3D] = []
			var balls: Array[Transform3D] = []
			for i in xforms.size():
				var x := xforms[i]
				match i % 4:
					0, 1:
						trees.append(Transform3D(x.basis.scaled(Vector3.ONE * 9.0), x.origin))
					2:
						swings.append(Transform3D(Basis(Vector3.UP, float(i) * 1.7), x.origin))
					3:
						balls.append(x)
			_multimesh_scene(RACING + "treeLarge.glb", trees)
			var leg := BoxMesh.new()
			leg.size = Vector3(0.35, 8.6, 0.35)
			leg.material = _deco_mat(Color(0.2, 0.45, 0.9))
			for sx in [-4.0, 4.0]:
				for sz in [-1.2, 1.2]:
					var tilted: Array[Transform3D] = []
					for x in swings:
						tilted.append(Transform3D(x.basis * Basis(Vector3.RIGHT, -signf(sz) * 0.14), x.origin + x.basis * Vector3(sx, 0, sz)))
					_multimesh(leg, tilted, Vector3(0, 4.2, 0))
			var bar := BoxMesh.new()
			bar.size = Vector3(8.6, 0.4, 0.4)
			bar.material = _deco_mat(Color(0.95, 0.3, 0.3))
			_multimesh(bar, swings, Vector3(0, 8.4, 0))
			var rope := BoxMesh.new()
			rope.size = Vector3(0.08, 6.0, 0.08)
			rope.material = _deco_mat(Color(0.3, 0.3, 0.32))
			var seat := BoxMesh.new()
			seat.size = Vector3(1.6, 0.18, 0.8)
			seat.material = _deco_mat(Color(1.0, 0.8, 0.2))
			for sx in [-2.0, 2.0]:
				_multimesh(rope, swings, Vector3(sx - 0.6, 5.3, 0))
				_multimesh(rope, swings, Vector3(sx + 0.6, 5.3, 0))
				_multimesh(seat, swings, Vector3(sx, 2.3, 0))
			var ball := SphereMesh.new()
			ball.radius = 1.6
			ball.height = 3.2
			var cols := [Color(0.95, 0.25, 0.25), Color(0.25, 0.55, 1.0), Color(1.0, 0.85, 0.2), Color(0.35, 0.8, 0.35)]
			var bxf: Array = []
			var bcol: Array = []
			for k in balls.size():
				bxf.append(Transform3D(balls[k].basis, balls[k].origin + Vector3.UP * 1.6 * balls[k].basis.get_scale().y))
				bcol.append(cols[k % cols.size()])
			_multimesh_colored(ball, bxf, bcol, _vc_mat(0.4))
		"machine":
			# RF-274: chaminés com faixa (metade) e máquinas-caixa com luz (outra metade)
			var ch: Array[Transform3D] = []
			var mc: Array[Transform3D] = []
			for i in xforms.size():
				(ch if i % 2 == 0 else mc).append(xforms[i])
			var pipe := CylinderMesh.new()
			pipe.top_radius = 1.1
			pipe.bottom_radius = 1.4
			pipe.height = 18.0
			pipe.material = _deco_mat(deco_color)
			var band := CylinderMesh.new()
			band.top_radius = 1.2
			band.bottom_radius = 1.2
			band.height = 1.2
			band.material = _deco_mat(Color(0.75, 0.15, 0.1))
			_multimesh(pipe, ch, Vector3(0, 9.0, 0))
			_multimesh(band, ch, Vector3(0, 15.0, 0))
			var box := BoxMesh.new()
			box.size = Vector3(6.0, 4.0, 5.0)
			box.material = _deco_mat(Color(0.25, 0.26, 0.3))
			var lamp := BoxMesh.new()
			lamp.size = Vector3(6.1, 0.4, 5.1)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(1.0, 0.6, 0.15)
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.55, 0.1)
			lm.emission_energy_multiplier = 2.0
			lamp.material = lm
			_multimesh(box, mc, Vector3(0, 2.0, 0))
			_multimesh(lamp, mc, Vector3(0, 3.2, 0))
		"cactus":
			var body := CylinderMesh.new()
			body.top_radius = 0.5
			body.bottom_radius = 0.55
			body.height = 4.5
			body.material = _deco_mat(deco_color)
			var arm := CylinderMesh.new()
			arm.top_radius = 0.32
			arm.bottom_radius = 0.32
			arm.height = 1.8
			arm.material = body.material
			_multimesh(body, xforms, Vector3(0, 2.25, 0))
			_multimesh(arm, xforms, Vector3(0.75, 2.8, 0))
			_multimesh(arm, xforms, Vector3(-0.7, 2.1, 0))
		"lamp":
			# postes em fila do lado de fora do muro, alternando os lados
			xforms.clear()
			for i in range(0, points.size(), 18):
				var side := 1.0 if (i / 18) % 2 == 0 else -1.0
				xforms.append(Transform3D(Basis(), points[i] + rights[i] * side * (WALL + 2.0)))
			var post := CylinderMesh.new()
			post.top_radius = 0.12
			post.bottom_radius = 0.18
			post.height = 6.0
			post.material = _deco_mat(Color(0.2, 0.2, 0.25))
			var bulb := SphereMesh.new()
			bulb.radius = 0.55
			bulb.height = 1.1
			var bulb_mat := StandardMaterial3D.new()
			bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bulb_mat.albedo_color = deco_color
			bulb.material = bulb_mat
			var halo := QuadMesh.new()
			halo.size = Vector2(4.0, 4.0)
			var halo_mat := StandardMaterial3D.new()
			halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			halo_mat.albedo_color = Color(deco_color.r, deco_color.g, deco_color.b, 0.5)
			var grad := Gradient.new()
			grad.set_color(0, Color(1, 1, 1, 1))
			grad.set_color(1, Color(1, 1, 1, 0))
			var glow := GradientTexture2D.new()
			glow.gradient = grad
			glow.fill = GradientTexture2D.FILL_RADIAL
			glow.fill_from = Vector2(0.5, 0.5)
			glow.fill_to = Vector2(0.5, 0.0)
			glow.width = 64
			glow.height = 64
			halo_mat.albedo_texture = glow
			halo.material = halo_mat
			_multimesh(post, xforms, Vector3(0, 3.0, 0))
			_multimesh(bulb, xforms, Vector3(0, 6.2, 0))
			_multimesh(halo, xforms, Vector3(0, 6.2, 0))
		_:
			# RF-173: árvores do Racing Kit (Kenney), metade grandes, metade pequenas
			var big: Array[Transform3D] = []
			var small: Array[Transform3D] = []
			for i in xforms.size():
				var x := xforms[i]
				var t := Transform3D(x.basis.scaled(Vector3.ONE * 9.0), x.origin)
				(big if i % 2 == 0 else small).append(t)
			_multimesh_scene(RACING + "treeLarge.glb", big)
			_multimesh_scene(RACING + "treeSmall.glb", small)


func _build_scenery() -> void:
	if def.get("stands", true):  # nos telhados não tem arquibancada nem boxes
		_grandstand()
		_racing_props()
		_flags()
		_tire_stacks()
	_scatter()


func _clear_of_track(pos: Vector3, radius: float) -> bool:
	# no plano (x, z): um trecho alto também ocupa o chão embaixo dele
	for i in points.size():
		if Vector2(pos.x - points[i].x, pos.z - points[i].z).length() <= wall_at(i) + radius:
			return false
	return true


## Arquibancada com torcida do lado de fora da largada (o lado que tiver espaço).
func _grandstand() -> void:
	var side := 1.0
	if not _clear_of_track(points[0] + rights[0] * (WALL + 20.0), 6.0):
		side = -1.0
	var stand := Node3D.new()
	stand.name = "Grandstand"
	stand.position = points[0] + rights[0] * side * (WALL + 9.0)
	stand.basis = Basis(Vector3.UP, heading_at(0))
	add_child(stand)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.62, 0.66)
	concrete.albedo_texture = Gfx.noise_tex("grain", 0.35, [Color(0.72, 0.72, 0.72), Color(0.92, 0.92, 0.92), Color(1, 1, 1)])
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var length := 44.0
	for k in 4:
		var tier := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.6, 0.9 * (k + 1), length)
		tier.mesh = bm
		tier.material_override = concrete
		tier.position = Vector3(side * (k * 2.6), 0.45 * (k + 1), 0)
		stand.add_child(tier)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = def["wall"][0]
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(12.0, 0.35, length + 2.0)
	roof.mesh = rm
	roof.material_override = roof_mat
	roof.position = Vector3(side * 4.0, 7.2, 0)
	stand.add_child(roof)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.18
	post_mesh.bottom_radius = 0.18
	post_mesh.height = 7.2
	for z in [-length * 0.5, 0.0, length * 0.5]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = concrete
		post.position = Vector3(side * 9.5, 3.6, z)
		stand.add_child(post)
	# placa pendurada na frente do telhado: o letreiro tem fundo (antes flutuava no ar)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = def["wall"][0]
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.08, 0.09, 0.16)
	for part in [[Vector3(0.22, 2.3, 33.0), frame_mat, -1.62], [Vector3(0.12, 1.9, 32.2), board_mat, -1.75]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = part[0]
		mi.mesh = bx
		mi.material_override = part[1]
		mi.position = Vector3(side * float(part[2]), 5.9, 0)
		mi.name = "BannerBoard"
		stand.add_child(mi)
	var banner := Label3D.new()
	banner.text = "Car Mundon'GO"
	banner.font_size = 150
	banner.pixel_size = 0.0115
	banner.outline_size = 24
	banner.modulate = Color(1.0, 0.85, 0.2)
	banner.position = Vector3(side * -1.84, 5.9, 0)
	banner.rotation.y = -PI / 2.0 * side
	banner.double_sided = false  # sem texto espelhado por trás
	stand.add_child(banner)
	# torcida: cápsulas coloridas nos degraus
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var fan := CapsuleMesh.new()
	fan.radius = 0.28
	fan.height = 1.0
	var xf: Array = []
	var cols: Array = []
	for k in 4:
		var z := -length * 0.5 + 0.6
		while z < length * 0.5 - 0.6:
			if rng.randf() < 0.85:
				var local := Vector3(side * (k * 2.6), 0.9 * (k + 1) + 0.5, z + rng.randf_range(-0.15, 0.15))
				xf.append(Transform3D(stand.basis, stand.position + stand.basis * local))
				cols.append(Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.0)))
			z += 0.85
	_multimesh_colored(fan, xf, cols, _vc_mat())


## Bandeirolas quadriculadas dos dois lados da reta de largada.
func _flags() -> void:
	var n := points.size()
	var poles: Array = []
	var flags: Array = []
	for k in range(-24, 25, 6):
		var i := wrapi(k, 0, n)
		for side in [-1.0, 1.0]:
			var base: Vector3 = points[i] + rights[i] * side * (WALL + WALL_T + 1.2)
			poles.append(Transform3D(Basis(), base + Vector3.UP * 2.5))
			flags.append(Transform3D(Basis(Vector3.UP, heading_at(i) + PI / 2.0), base + Vector3.UP * 4.4 - tangents[i] * 0.8))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 5.0
	var white: Array = []
	for t in poles:
		white.append(Color(0.85, 0.85, 0.9))
	_multimesh_colored(pole, poles, white, _vc_mat(0.4))
	var flag := QuadMesh.new()
	flag.size = Vector2(1.6, 1.0)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = Gfx.checker_tex(Color.WHITE, Color(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05), "flag")
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.uv1_scale = Vector3(2, 2, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = flag
	mm.instance_count = flags.size()
	for i in flags.size():
		mm.set_instance_transform(i, flags[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = fm
	add_child(mmi)
	scenery_count += flags.size()


## Pilhas de pneu do lado de fora das curvas mais fechadas.
func _tire_stacks() -> void:
	var n := points.size()
	var tire := TorusMesh.new()
	tire.inner_radius = 0.28
	tire.outer_radius = 0.55
	var xf: Array = []
	var cols: Array = []
	var last := -100
	for i in range(0, n, 2):
		if i - last < 12 or curvature_at(i) < 0.75:
			continue
		last = i
		var turn := tangents[i].cross(tangents[(i + 10) % n]).y
		var outer := 1.0 if turn > 0.0 else -1.0
		for s in [-1, 0, 1]:
			var j := wrapi(i + 5 + s, 0, n)
			var base: Vector3 = points[j] + rights[j] * outer * (WALL - 0.7)
			for h in 3:
				xf.append(Transform3D(Basis(), base + Vector3.UP * (0.15 + h * 0.3)))
				var top_c := Color(0.9, 0.15, 0.1) if s == 0 else Color(0.92, 0.92, 0.92)
				cols.append(top_c if h == 2 else Color(0.08, 0.08, 0.09))
	_multimesh_colored(tire, xf, cols, _vc_mat(0.9))


## Tufos/pedras (ou queijos gigantes na cozinha) espalhados fora da pista.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var kind: String = def.get("scenery", "rocks_green")
	var tufts: Array = []
	var tuft_cols: Array = []
	var rocks: Array = []
	var rock_cols: Array = []
	var count := 260 if kind != "cheese" else 30
	if kind == "none":
		return
	if kind == "ice":
		count = 70
	if kind == "fruit":
		count = 110
	if kind == "bbq":
		count = 90
	var tries := 0
	while tufts.size() + rocks.size() < count and tries < 6000:
		tries += 1
		var i := rng.randi_range(0, points.size() - 1)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p: Vector3 = points[i] + rights[i] * side * rng.randf_range(WALL + 3.0, WALL + 55.0)
		p.y = 0.0
		if not _clear_of_track(p, 2.5):
			continue
		var yaw := rng.randf() * TAU
		if kind == "fruit":  # RF-372: laranjas, tomates e melancias caídos da feira
			var fpal := [[Color(1.0, 0.55, 0.1), Vector3(1, 1, 1)], [Color(0.85, 0.12, 0.1), Vector3(1, 0.85, 1)], [Color(0.2, 0.55, 0.2), Vector3(1.6, 1.1, 1.1)]]
			var fk: Array = fpal[rng.randi_range(0, fpal.size() - 1)]
			var fs := rng.randf_range(0.7, 1.6)
			var fv: Vector3 = fk[1] * fs
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(fv), p + Vector3.UP * fv.y * 0.45))
			rock_cols.append((fk[0] as Color).darkened(rng.randf() * 0.1))
			continue
		if kind == "bbq":  # RF-273: tomates, pães e cebolas gigantes na mesa
			var pal := [[Color(0.85, 0.12, 0.08), Vector3(1, 0.9, 1)], [Color(0.78, 0.55, 0.28), Vector3(2.2, 0.8, 1)], [Color(0.62, 0.3, 0.55), Vector3(1, 1.1, 1)], [Color(0.95, 0.9, 0.75), Vector3(1.6, 0.5, 1.6)]]
			var pk: Array = pal[rng.randi_range(0, pal.size() - 1)]
			var s := rng.randf_range(2.0, 4.5)
			var sv: Vector3 = pk[1] * s
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(sv), p + Vector3.UP * sv.y * 0.45))
			rock_cols.append((pk[0] as Color).darkened(rng.randf() * 0.12))
		elif kind == "ice":  # RF-324: cubos de gelo derretendo no fundo da geladeira
			var s := rng.randf_range(1.5, 4.0)
			var axis := Vector3(rng.randf() - 0.5, 1.0, rng.randf() - 0.5).normalized()
			rocks.append(Transform3D(Basis(axis, yaw).scaled(Vector3(s, s * 0.85, s)), p + Vector3.UP * s * 0.4))
			rock_cols.append(Color(0.75, 0.9, 1.0).lightened(rng.randf() * 0.2))
		elif kind == "cheese":
			var s := rng.randf_range(3.0, 8.0)
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * 0.6, s)), p + Vector3.UP * s * 0.3))
			rock_cols.append(Color(1.0, 0.8, 0.25).darkened(rng.randf() * 0.15))
		elif rng.randf() < (0.8 if kind == "rocks_green" else 0.35):
			var s := rng.randf_range(0.6, 1.4)
			tufts.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.8, 1.5), s)), p + Vector3.UP * 0.35 * s))
			var g: Color = Color(0.2, 0.45, 0.15) if kind == "rocks_green" else Color(0.55, 0.45, 0.2)
			tuft_cols.append(g.lightened(rng.randf_range(-0.1, 0.2)))
		else:
			var s := rng.randf_range(0.5, 2.2)
			var axis := Vector3(rng.randf(), 1.0, rng.randf()).normalized()
			rocks.append(Transform3D(Basis(axis, yaw).scaled(Vector3(s, s * 0.6, s * 0.8)), p + Vector3.UP * s * 0.2))
			var rc: Color = Color(0.5, 0.5, 0.52) if kind == "rocks_green" else Color(0.65, 0.5, 0.35)
			rock_cols.append(rc.darkened(rng.randf() * 0.25))
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.45
	tuft.height = 0.9
	tuft.radial_segments = 5
	_multimesh_colored(tuft, tufts, tuft_cols, _vc_mat(1.0))
	var rock: Mesh
	if kind == "ice":
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		rock = cube
	elif kind == "cheese":
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 3
		c.rings = 1
		rock = c
	else:
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 7
		sp.rings = 4
		rock = sp
	_multimesh_colored(rock, rocks, rock_cols, _vc_mat(0.85))
