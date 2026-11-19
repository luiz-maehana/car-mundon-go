extends "res://scripts/track_features.gd"
## Pista — desenho: malha da pista, rampas, zonas, buracos, esteiras, pontes, pilares, túneis e ajudantes de malha.
## (camada de track.gd — ver o topo de track.gd)


## RF-324: túneis (caixa de leite) por cima da pista e a "geladeira" em volta do mundo.
func _build_tunnels_and_enclosure() -> void:
	var n := points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for tn in def.get("tunnels", []):
		var i0 := int(n * float(tn[0]))
		var i1 := int(n * float(tn[1]))
		for k in wrapi(i1 - i0, 0, n):
			var i := (i0 + k) % n
			var w0 := wall_at(i) + WALL_T
			var w1 := wall_at((i + 1) % n) + WALL_T
			var band := (k / 6) % 2 == 0
			var side_c := Color(0.97, 0.97, 0.98) if band else Color(0.25, 0.55, 0.95)
			for s in [1.0, -1.0]:
				_strip_e(st, i, s * w0, s * w0, s * w1, s * w1, 0.0, TUNNEL_H, side_c)
			_strip_e(st, i, -w0, w0, -w1, w1, TUNNEL_H, TUNNEL_H, Color(0.92, 0.94, 0.97))
			any = true
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _vc_mat(0.6)
		mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.name = "Tunnels"
		add_child(mi)
	if not def.get("enclosure", false):
		return
	# paredes brancas da geladeira (o céu vira o teto) e a lâmpada lá em cima
	var c := (bounds_max + bounds_min) * 0.5
	var half := (bounds_max - bounds_min) * 0.5 + Vector2(170, 170)
	var h := 140.0
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.9, 0.94, 0.98)
	wall_mat.roughness = 0.35
	var specs := [
		[Vector3(c.x, h * 0.5, c.y - half.y), Vector3(half.x * 2.0, h, 2.0)],
		[Vector3(c.x, h * 0.5, c.y + half.y), Vector3(half.x * 2.0, h, 2.0)],
		[Vector3(c.x - half.x, h * 0.5, c.y), Vector3(2.0, h, half.y * 2.0)],
		[Vector3(c.x + half.x, h * 0.5, c.y), Vector3(2.0, h, half.y * 2.0)],
		[Vector3(c.x, h, c.y), Vector3(half.x * 2.0, 2.0, half.y * 2.0)],
	]
	for sp in specs:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sp[1]
		box.mesh = bm
		box.material_override = wall_mat
		box.position = sp[0]
		box.name = "FridgeWall"
		add_child(box)
	# frisos das prateleiras na parede (as bordas de vidro) e a lâmpada
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.88, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for y in [40.0, 80.0]:
		for sp in specs.slice(0, 4):
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var sz: Vector3 = sp[1]
			bm.size = Vector3(sz.x if sz.x > 3.0 else 30.0, 1.5, sz.z if sz.z > 3.0 else 30.0)
			strip.mesh = bm
			strip.material_override = glass
			strip.position = Vector3(sp[0].x, y, sp[0].z)
			add_child(strip)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 14.0
	lm.height = 14.0
	lamp.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.98, 0.9)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.97, 0.88)
	lmat.emission_energy_multiplier = 3.0
	lamp.material_override = lmat
	lamp.position = Vector3(c.x, h - 4.0, c.y)
	add_child(lamp)
	var light := OmniLight3D.new()
	light.position = lamp.position - Vector3.UP * 20.0
	light.omni_range = 600.0
	light.light_energy = 1.2
	light.light_color = Color(0.9, 0.95, 1.0)
	add_child(light)


## Buraco: borda colorida e fundo preto (desenhado por cima do asfalto).
func _pits_visual(st: SurfaceTool) -> void:
	var rim: Color = def.get("pit_rim", Color(0.35, 0.3, 0.25))
	for p in pits:
		var i: int = p["idx"]
		var c: Vector3 = p["pos"] + Vector3.UP * 0.075
		var r: float = p["r"]
		var t := tangents[i]
		var rr := rights[i]
		var seg := 20
		for k in seg:
			var a0 := TAU * k / seg
			var a1 := TAU * (k + 1) / seg
			var d0 := rr * cos(a0) + t * sin(a0)
			var d1 := rr * cos(a1) + t * sin(a1)
			_quad(st, c, c + d0 * (r - 0.35), c + d1 * (r - 0.35), c, Color(0.02, 0.02, 0.03))
			_quad(st, c + d0 * (r - 0.35), c + d0 * (r + 0.25) + Vector3.UP * 0.01, c + d1 * (r + 0.25) + Vector3.UP * 0.01, c + d1 * (r - 0.35), rim)


## RF-392: ponte — corrimão de madeira dos dois lados e o rio largo passando embaixo.
func _build_bridges() -> void:
	if bridges.is_empty() and not def.has("gap_floor"):
		return
	var n := points.size()
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	# RF-394: fundo do cânion embaixo de cada vão (quando a pista pede)
	if def.has("gap_floor"):
		for g in gaps:
			var gm := (int(g["i0"]) + int(g["len"]) / 2) % n
			var fl := MeshInstance3D.new()
			var fm := PlaneMesh.new()
			fm.size = Vector2(70.0, 26.0)
			fl.mesh = fm
			fl.material_override = _deco_mat(def["gap_floor"])
			fl.basis = Basis(Vector3.UP, heading_at(gm))
			fl.position = Vector3(points[gm].x, 0.03, points[gm].z)
			fl.name = "GapFloor"
			add_child(fl)
	for b in bridges:
		var i0: int = b["i0"]
		var ln: int = b["len"]
		for k in ln + 1:
			var i := (i0 + k) % n
			var yaw := Basis(Vector3.UP, heading_at(i))
			for s in [1.0, -1.0]:
				var p: Vector3 = points[i] + rights[i] * s * (wall_at(i) + WALL_T * 0.5)
				if k % 2 == 0:
					posts.append(Transform3D(yaw, p + Vector3.UP * 1.1))
				rails.append(Transform3D(yaw.scaled(Vector3(1, 1, SPACING * 1.05)), p + Vector3.UP * 2.1 + tangents[i] * SPACING * 0.5))
		# rio: faixa larga de água atravessando embaixo do meio da ponte
		var mid := (i0 + ln / 2) % n
		if float(def.get("river_w", 34.0)) <= 0.0:
			continue
		var water := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(def.get("river_len", 200.0)), float(def.get("river_w", 34.0)))  # atravessa a pista
		water.mesh = pm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = def.get("river_color", Color(0.2, 0.45, 0.75))
		wm.roughness = 0.08
		wm.metallic_specular = 0.9
		water.material_override = wm
		water.basis = Basis(Vector3.UP, heading_at(mid))
		water.position = Vector3(points[mid].x, 0.02, points[mid].z)
		water.name = "River"
		add_child(water)
	if posts.is_empty():
		return
	var post := BoxMesh.new()
	post.size = Vector3(0.3, 2.2, 0.3)
	post.material = _deco_mat(Color(0.45, 0.28, 0.14))
	_multimesh(post, posts, Vector3.ZERO)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.22, 0.22, 1.0)
	rail.material = _deco_mat(Color(0.55, 0.36, 0.18))
	_multimesh(rail, rails, Vector3.ZERO)


## RF-320: pilares embaixo dos trechos altos (caixas de leite/potes na geladeira), fora de outras pistas.
func _build_supports() -> void:
	if def.get("buildings", false):
		return  # nos telhados quem segura a pista são os prédios
	var n := points.size()
	var xf: Array = []
	var cols: Array = []
	var pal: Array = def.get("pillar_colors", [Color(0.95, 0.95, 0.97), Color(0.35, 0.6, 0.95), Color(0.95, 0.4, 0.45)])
	var k := 0
	for i in range(0, n, 9):
		var top := points[i].y - 0.9
		if top < 1.5 or in_loop(i):
			continue
		if def.get("fill_below", false) and not bridge_at(i):
			continue  # terreno maciço não precisa de pilar
		if def.get("river_w", 34.0) <= 0.0 and bridge_at(i):
			continue  # a colher da cozinha fica apoiada nas bancadas
		var base := Vector3(points[i].x, 0.0, points[i].z)
		if _over_other_road(i, base, 1.5):
			continue
		var w := 5.0 + float(k % 3)
		xf.append(Transform3D(Basis(Vector3.UP, heading_at(i)).scaled(Vector3(w, top, w * 0.8)), base + Vector3.UP * top * 0.5))
		cols.append(pal[k % pal.size()])
		k += 1
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multimesh_colored(box, xf, cols, _vc_mat(0.5))
	scenery_count += xf.size()


## O ponto do chão `p` (abaixo da amostra i) cai em cima de outra pista mais baixa?
func _over_other_road(i: int, p: Vector3, margin: float) -> bool:
	var n := points.size()
	for j in n:
		if absi(wrapi(j - i, -n / 2, n / 2)) < 20:
			continue
		if points[j].y < points[i].y - LEVEL_GAP and Vector2(p.x - points[j].x, p.z - points[j].z).length() < wall_at(j) + WALL_T + margin:
			return true
	return false


func _strip(st: SurfaceTool, i: int, la: float, lb: float, ya: float, yb: float, c: Color) -> void:
	_strip_e(st, i, la, lb, la, lb, ya, yb, c)


## Faixa entre as amostras i e i+1, com laterais próprias em cada ponta; a altura segue a normal
## da pista (no looping o "pra cima" gira junto).
func _strip_e(st: SurfaceTool, i: int, la0: float, lb0: float, la1: float, lb1: float, ya: float, yb: float, c: Color) -> void:
	var n := points.size()
	var k := (i + 1) % n
	var ui := ups[i] if not ups.is_empty() else Vector3.UP
	var uk := ups[k] if not ups.is_empty() else Vector3.UP
	var a0 := points[i] + rights[i] * la0 + ui * ya
	var b0 := points[i] + rights[i] * lb0 + ui * yb
	var a1 := points[k] + rights[k] * la1 + uk * ya
	var b1 := points[k] + rights[k] * lb1 + uk * yb
	_quad(st, a0, b0, b1, a1, c)


func _quad(st: SurfaceTool, a0: Vector3, b0: Vector3, b1: Vector3, a1: Vector3, c: Color) -> void:
	var nrm := (b0 - a0).cross(a1 - a0).normalized()
	st.set_color(c)
	st.set_normal(nrm)
	for v in [a0, b1, b0, a0, a1, b1]:
		st.add_vertex(v)


func _start_line(st: SurfaceTool) -> void:
	var p := points[0]
	var r := rights[0]
	var t := tangents[0]
	var cols := 10
	var w := ROAD_HALF * 2.0 / cols
	for row in 2:
		for col in cols:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color(0.05, 0.05, 0.05)
			var la := -ROAD_HALF + col * w
			var al := -1.0 + row * 1.0
			var y := Vector3.UP * 0.05
			var a0 := p + r * la + t * al + y
			var b0 := p + r * (la + w) + t * al + y
			var b1 := p + r * (la + w) + t * (al + 1.0) + y
			var a1 := p + r * la + t * (al + 1.0) + y
			_quad(st, a0, b0, b1, a1, c)


func _build_ground() -> void:
	var size := (bounds_max - bounds_min) + Vector2(400, 400)
	var center := (bounds_max + bounds_min) * 0.5
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = Gfx.ground_material(def.get("ground_tex", "grass"), def["ground"])
	mi.name = "Ground"
	mi.position = Vector3(center.x, -0.02, center.y)
	add_child(mi)


## MultiMesh a partir das malhas de um modelo (.glb), uma MultiMesh por malha.
func _multimesh_scene(path: String, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var local := Gfx._rel_transform(inst, mi)
		var offs: Array[Transform3D] = []
		for x in xforms:
			offs.append(x * local)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = offs.size()
		for i in offs.size():
			mm.set_instance_transform(i, offs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		scenery_count += offs.size()
	inst.free()


func _deco_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], offset: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var x := xforms[i]
		mm.set_instance_transform(i, Transform3D(x.basis, x.origin + x.basis * offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


## Setas de turbo (chevrons laranja/amarelo) e a rampa listrada (RF-140/141).
func _pads_and_ramp(st: SurfaceTool) -> void:
	var n := points.size()
	for p in pads:
		var i0: int = p["idx"]
		var lat: float = p["lat"]
		for k in PAD_LEN + 1:
			var i := (i0 + k) % n
			var c := points[i] + rights[i] * lat + Vector3.UP * 0.06
			var t := tangents[i]
			var r := rights[i]
			# base laranja
			_quad(st, c - r * 2.2 - t * 1.0, c + r * 2.2 - t * 1.0, c + r * 2.2 + t * 1.0, c - r * 2.2 + t * 1.0, Color(0.95, 0.45, 0.05))
			# chevron amarelo apontando pra frente (-tangente é "trás"; a pista anda em +t)
			var up := Vector3.UP * 0.01
			var tip := c + t * 0.8 + up
			_quad(st, c - r * 1.8 - t * 0.6 + up, c - r * 1.2 - t * 0.6 + up, tip + t * 0.0, tip - t * 0.6, Color(1.0, 0.92, 0.2))
			_quad(st, c + r * 1.2 - t * 0.6 + up, c + r * 1.8 - t * 0.6 + up, tip - t * 0.6, tip, Color(1.0, 0.92, 0.2))
	for r in _all_ramps():
		_draw_ramp(st, int(r["idx"]), float(r["h"]), "slide" if int(r["idx"]) == ramp_idx and def.get("ramp_style", "") == "slide" else ("lip" if int(r["idx"]) != ramp_idx else ""))


## Uma rampa: listrada (comum), escorregador (RF-302) ou tábua de beirada antes de um vão (RF-330).
func _draw_ramp(st: SurfaceTool, idx: int, h: float, style: String) -> void:
	var n := points.size()
	var slide := style == "slide"
	var plank := style == "lip"
	for k in RAMP_LEN:
		var i := (idx + k) % n
		var j := (i + 1) % n
		var y0 := h * float(k) / RAMP_LEN
		var y1 := h * float(k + 1) / RAMP_LEN
		var stripes := 6
		for s in stripes:
			var la := -ROAD_HALF + 2.0 * ROAD_HALF * s / stripes
			var lb := -ROAD_HALF + 2.0 * ROAD_HALF * (s + 1) / stripes
			var c := Color(1.0, 0.8, 0.1) if (s + k) % 2 == 0 else Color(0.1, 0.1, 0.12)
			if slide:  # RF-302: escorregador de plástico (vermelho com faixas amarelas)
				c = Color(0.92, 0.22, 0.2) if s % 3 != 1 else Color(1.0, 0.82, 0.2)
			elif plank:  # tábuas de madeira com a ponta pintada de amarelo
				c = Color(0.55, 0.36, 0.2).darkened(0.12 * (s % 2)) if k < RAMP_LEN - 1 else Color(1.0, 0.82, 0.15)
			_quad(st, points[i] + rights[i] * la + Vector3.UP * y0, points[i] + rights[i] * lb + Vector3.UP * y0,
				points[j] + rights[j] * lb + Vector3.UP * y1, points[j] + rights[j] * la + Vector3.UP * y1, c)
		# laterais (no escorregador: parede azul que sobe acima da rampa, a "borda" do brinquedo)
		var side_c := Color(0.2, 0.5, 0.95) if slide else (Color(0.4, 0.26, 0.14) if plank else Color(0.25, 0.25, 0.28))
		var lip := 0.7 if slide else 0.0
		for side in [-ROAD_HALF, ROAD_HALF]:
			_quad(st, points[i] + rights[i] * side, points[i] + rights[i] * side + Vector3.UP * (y0 + lip),
				points[j] + rights[j] * side + Vector3.UP * (y1 + lip), points[j] + rights[j] * side, side_c)
	# face da frente (queda)
	var e := (idx + RAMP_LEN) % n
	var face_c := Color(0.2, 0.5, 0.95) if slide else (Color(0.4, 0.26, 0.14) if plank else Color(0.25, 0.25, 0.28))
	_quad(st, points[e] - rights[e] * ROAD_HALF, points[e] + rights[e] * ROAD_HALF,
		points[e] + rights[e] * ROAD_HALF + Vector3.UP * h, points[e] - rights[e] * ROAD_HALF + Vector3.UP * h, face_c)


func _vc_mat(roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m


func _multimesh_colored(mesh: Mesh, xforms: Array, colors: Array, mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	scenery_count += xforms.size()


func _zones_visual(st: SurfaceTool) -> void:
	var n := points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for z in zones:
		var la: float = z["lat0"]
		var lb: float = z["lat1"]
		for k in int(z["len"]):
			var i := (int(z["i0"]) + k) % n
			match z["kind"]:
				"farofa":
					# areia amarelada com grãos (pontinhos) por cima
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.86, 0.68, 0.36).darkened(rng.randf() * 0.08))
					for g in 6:
						var lat := rng.randf_range(la + 0.3, lb - 0.3)
						var c := points[i] + rights[i] * lat + tangents[i] * rng.randf_range(0.0, SPACING) + Vector3.UP * 0.075
						var s := rng.randf_range(0.12, 0.3)
						_quad(st, c - rights[i] * s - tangents[i] * s, c + rights[i] * s - tangents[i] * s, c + rights[i] * s + tangents[i] * s, c - rights[i] * s + tangents[i] * s, Color(0.98, 0.85, 0.55) if g % 2 == 0 else Color(0.6, 0.42, 0.2))
				"ice":
					# RF-323: gelo azul-claro brilhante com riscos de patins
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.78, 0.92, 1.0).lightened(rng.randf() * 0.1))
					if k % 2 == 0:
						var lat := rng.randf_range(la + 1.0, lb - 3.0)
						_strip(st, i, lat, lat + rng.randf_range(0.15, 0.3), 0.07, 0.07, Color(1, 1, 1))
				"sand":
					# RF-301: caixa de areia clarinha com moldura de madeira e forminhas de brinquedo
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.95, 0.85, 0.6).darkened(rng.randf() * 0.06))
					for lat in [la, lb]:
						_strip(st, i, lat - 0.25, lat + 0.25, 0.14, 0.14, Color(0.6, 0.38, 0.18))
					if k == 0 or k == int(z["len"]) - 1:
						var e := points[i] + tangents[i] * (0.0 if k == 0 else SPACING) + Vector3.UP * 0.14
						_quad(st, e + rights[i] * la - tangents[i] * 0.25, e + rights[i] * lb - tangents[i] * 0.25, e + rights[i] * lb + tangents[i] * 0.25, e + rights[i] * la + tangents[i] * 0.25, Color(0.6, 0.38, 0.18))
					if k % 3 == 1:
						var c := points[i] + rights[i] * rng.randf_range(la + 1.5, lb - 1.5) + Vector3.UP * 0.075
						var s := rng.randf_range(0.4, 0.7)
						var toy: Color = [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.85, 0.2)][(k / 3) % 3]
						_quad(st, c - rights[i] * s - tangents[i] * s, c + rights[i] * s - tangents[i] * s, c + rights[i] * s + tangents[i] * s, c - rights[i] * s + tangents[i] * s, toy)
				"grill":
					# grelha: fundo com brasa e barras escuras atravessadas
					_strip(st, i, la, lb, 0.05, 0.05, Color(0.55, 0.12, 0.02))
					var c0 := points[i] + Vector3.UP * 0.08
					for b in 2:
						var a := c0 + tangents[i] * (0.5 + b * 1.0)
						_quad(st, a + rights[i] * la - tangents[i] * 0.22, a + rights[i] * lb - tangents[i] * 0.22, a + rights[i] * lb + tangents[i] * 0.22, a + rights[i] * la + tangents[i] * 0.22, Color(0.1, 0.1, 0.11))
					if k % 6 == 0:  # longarinas
						for lat in [la + 0.4, lb - 0.4]:
							var p: Vector3 = points[i] + rights[i] * lat + Vector3.UP * 0.09
							_quad(st, p - rights[i] * 0.2, p + rights[i] * 0.2, p + rights[i] * 0.2 + tangents[i] * SPACING * 6.0, p - rights[i] * 0.2 + tangents[i] * SPACING * 6.0, Color(0.12, 0.12, 0.13))


static func _belt_texture() -> Texture2D:
	var img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var c := Color(0.13, 0.13, 0.15) if y % 16 < 11 else Color(0.32, 0.32, 0.36)
		if y % 16 == 11:
			c = Color(0.85, 0.7, 0.15)  # friso amarelo
		for x in 8:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Esteiras: malha própria com UV e material que rola (o _process anda o UV).
func _build_belts() -> void:
	var n := points.size()
	var tex := _belt_texture()
	for z in zones:
		if not String(z["kind"]).begins_with("belt"):
			continue
		var side: bool = z["kind"] == "belt_side"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var la: float = z["lat0"]
		var lb: float = z["lat1"]
		for k in int(z["len"]):
			var i := (int(z["i0"]) + k) % n
			var j := (i + 1) % n
			var y := Vector3.UP * 0.07
			var v0 := float(k) * SPACING / 4.0
			var v1 := float(k + 1) * SPACING / 4.0
			var quad := [points[i] + rights[i] * la + y, points[i] + rights[i] * lb + y, points[j] + rights[j] * lb + y, points[j] + rights[j] * la + y]
			# esteira lateral: frisos ao longo da pista (UV girado), andando pro lado
			var uvs: Array = [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)] if not side else [Vector2(v0, la / 4.0), Vector2(v0, lb / 4.0), Vector2(v1, lb / 4.0), Vector2(v1, la / 4.0)]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[idx])
				st.add_vertex(quad[idx])
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.7
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.name = "Belt"
		add_child(mi)
		var spd: float = (BELT_SIDE_SPEED if side else BELT_SPEED) * float(z["dir"])
		belt_mats.append({"mat": mat, "speed": spd})


func _process(delta: float) -> void:
	for b in belt_mats:
		var m: StandardMaterial3D = b["mat"]
		m.uv1_offset.y = fmod(m.uv1_offset.y - float(b["speed"]) * delta / 4.0, 1.0)


## Base fixa dos perigos (suportes); o que mexe é criado pela corrida.
func _build_hazard_bases() -> void:
	for h in hazard_specs:
		var i: int = h["idx"]
		if h["kind"] == "press":
			# pórtico da prensa: duas colunas e uma viga por cima da faixa
			var lat: Array = h["lat"]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.65, 0.1)
			mat.metallic = 0.4
			mat.roughness = 0.5
			for l in [float(lat[0]) - 0.8, float(lat[1]) + 0.8]:
				var col := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.7, 9.0, 0.7)
				col.mesh = bm
				col.material_override = mat
				col.position = points[i] + rights[i] * l + Vector3.UP * 4.5
				add_child(col)
			var beam := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(absf(float(lat[1]) - float(lat[0])) + 2.4, 0.8, 1.2)
			beam.mesh = bb
			beam.material_override = mat
			beam.position = points[i] + rights[i] * (float(lat[0]) + float(lat[1])) * 0.5 + Vector3.UP * 9.2
			beam.basis = Basis(Vector3.UP, heading_at(i))  # X local = lateral da pista
			add_child(beam)
