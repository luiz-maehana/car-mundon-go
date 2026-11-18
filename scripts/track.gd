extends Node3D
## Pista procedural. As pistas são dados (TRACKS, RF-120): nome, pontos de controle e tema.
## Linha central = spline Catmull-Rom fechada, reamostrada a cada SPACING metros.
## Tudo (grama, muro, progresso, IA) é resolvido pela distância lateral à linha central.

const Gfx = preload("res://scripts/gfx.gd")
const RACING := "res://assets/kenney/racing/"

const ROAD_HALF := 8.0
const CURB := 1.2
const OFFROAD := 7.0
const WALL := ROAD_HALF + OFFROAD
const WALL_H := 1.1
const WALL_T := 0.8
const SPACING := 2.0
const ITEM_ROWS := [0.18, 0.47, 0.76]

## RF-121. deco: "pine" | "cactus" | "lamp". sun = [energia, pitch em graus, cor].
const TRACKS := [
	{
		"id": "queijo", "name": "Circuito Queijo Suíço",
		"points": [
			Vector2(-120, 80), Vector2(0, 92), Vector2(110, 80), Vector2(165, 30),
			Vector2(140, -30), Vector2(70, -45), Vector2(35, -95), Vector2(65, -150),
			Vector2(140, -160), Vector2(175, -215), Vector2(110, -265), Vector2(-20, -255),
			Vector2(-100, -205), Vector2(-70, -130), Vector2(-140, -75), Vector2(-170, 10),
		],
		"ground": Color(0.15, 0.32, 0.11), "offroad": Color(0.33, 0.45, 0.17),
		"road": [Color(0.2, 0.2, 0.22), Color(0.23, 0.23, 0.25)],
		"curb": [Color(0.85, 0.1, 0.1), Color(0.95, 0.95, 0.95)],
		"wall": [Color(0.15, 0.35, 0.9), Color(0.95, 0.95, 0.95)],
		"sky_top": Color(0.25, 0.5, 0.9), "sky_horizon": Color(0.7, 0.82, 0.95),
		"ambient": Color(0.62, 0.64, 0.7), "sun": [1.1, -55.0, Color(1, 1, 1)],
		"deco": "pine", "deco_color": Color(0.13, 0.42, 0.18),
		"ground_tex": "grass", "clouds": 0.55, "fog": 0.0007, "exposure": 0.92, "scenery": "rocks_green",
	},
	{
		"id": "deserto", "name": "Deserto do Parmesão",
		"points": [
			Vector2(-180, 0), Vector2(-150, -90), Vector2(-60, -130), Vector2(40, -110),
			Vector2(90, -150), Vector2(170, -120), Vector2(190, -30), Vector2(140, 40),
			Vector2(170, 110), Vector2(100, 160), Vector2(0, 130), Vector2(-80, 170),
			Vector2(-160, 120),
		],
		"ground": Color(0.62, 0.45, 0.27), "offroad": Color(0.55, 0.4, 0.25),
		"road": [Color(0.32, 0.27, 0.24), Color(0.35, 0.3, 0.26)],
		"curb": [Color(0.95, 0.55, 0.1), Color(1.0, 0.95, 0.8)],
		"wall": [Color(0.9, 0.45, 0.15), Color(1.0, 0.92, 0.75)],
		"sky_top": Color(0.35, 0.45, 0.8), "sky_horizon": Color(1.0, 0.7, 0.45),
		"ambient": Color(0.75, 0.62, 0.55), "sun": [1.25, -25.0, Color(1.0, 0.85, 0.65)],
		"deco": "cactus", "deco_color": Color(0.3, 0.55, 0.25),
		"ground_tex": "sand", "clouds": 0.25, "fog": 0.0015, "exposure": 1.05, "cloud_color": Color(1.0, 0.85, 0.75), "scenery": "rocks",
	},
	{
		"id": "cozinha", "name": "Cozinha à Meia-Noite",
		"points": [
			Vector2(-150, 60), Vector2(-40, 70), Vector2(30, 20), Vector2(110, 60),
			Vector2(170, 10), Vector2(150, -70), Vector2(60, -90), Vector2(0, -50),
			Vector2(-60, -100), Vector2(-150, -90), Vector2(-190, -20),
		],
		"ground": Color(0.12, 0.1, 0.16), "offroad": Color(0.22, 0.18, 0.28),
		"road": [Color(0.16, 0.16, 0.2), Color(0.19, 0.19, 0.24)],
		"curb": [Color(0.1, 0.85, 0.9), Color(0.9, 0.2, 0.8)],
		"wall": [Color(0.55, 0.2, 0.85), Color(0.1, 0.8, 0.9)],
		"sky_top": Color(0.02, 0.02, 0.08), "sky_horizon": Color(0.18, 0.1, 0.3),
		"ambient": Color(0.45, 0.45, 0.65), "sun": [0.45, -60.0, Color(0.6, 0.7, 1.0)],
		"deco": "lamp", "deco_color": Color(1.0, 0.85, 0.4),
		"ground_tex": "tiles", "clouds": 0.15, "fog": 0.003, "exposure": 1.2, "stars": true, "cloud_color": Color(0.25, 0.22, 0.35), "scenery": "cheese",
	},
]

var def: Dictionary
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var length := 0.0
var bounds_min := Vector2.ZERO
var bounds_max := Vector2.ZERO


func _init(track_id := "queijo") -> void:
	def = find(track_id)
	_build_path()
	_place_features()


# ---------------------------------------------------------------- setas, rampa, queijos (v0.8)

const RAMP_LEN := 3          # amostras (6 m)
const RAMP_H := 1.0
const PAD_LEN := 3
const CHEESE_ROWS := [[0.28, -3.5], [0.55, 3.5], [0.9, 0.0]]
const PAD_RANGES := [[0.07, 0.14], [0.6, 0.7]]
const RAMP_RANGE := [0.3, 0.42]

var pads: Array = []     # {idx, lat}
var ramp_idx := -1


## Curvatura em i: ângulo entre a tangente 10 amostras antes e 20 depois.
func curvature_at(i: int) -> float:
	var n := points.size()
	return tangents[wrapi(i - 10, 0, n)].angle_to(tangents[wrapi(i + 20, 0, n)])


func _straightest(f0: float, f1: float) -> int:
	var n := points.size()
	var best := int(n * f0)
	var best_c := INF
	for i in range(int(n * f0), int(n * f1)):
		var c := curvature_at(i)
		if c < best_c:
			best_c = c
			best = i
	return best


func _place_features() -> void:
	var lats := [-4.0, 4.0]
	for k in PAD_RANGES.size():
		pads.append({"idx": _straightest(PAD_RANGES[k][0], PAD_RANGES[k][1]), "lat": lats[k]})
	ramp_idx = _straightest(RAMP_RANGE[0], RAMP_RANGE[1])


## Kart está em cima de uma seta? (RF-140)
func on_pad(i: int, lat: float) -> bool:
	var n := points.size()
	for p in pads:
		var d := wrapi(i - int(p["idx"]), 0, n)
		if d <= PAD_LEN and absf(lat - float(p["lat"])) < 2.4:
			return true
	return false


## Fração (0..1) do kart ao longo da rampa, ou -1 se não está nela (RF-141).
func ramp_frac(i: int, along: float, lat: float) -> float:
	if ramp_idx < 0 or absf(lat) > ROAD_HALF:
		return -1.0
	var d := wrapi(i - ramp_idx, 0, points.size())
	if d > RAMP_LEN + 1:
		return -1.0
	var f := (d + along / SPACING) / RAMP_LEN
	return f if f >= 0.0 and f <= 1.0 else -1.0


func cheese_positions() -> Array:
	var out := []
	var n := points.size()
	for row in CHEESE_ROWS:
		var i0 := int(n * float(row[0]))
		for k in 5:
			var i := (i0 + k * 4) % n
			out.append(points[i] + rights[i] * float(row[1]) + Vector3.UP * 0.7)
	return out


static func find(track_id: String) -> Dictionary:
	for t in TRACKS:
		if t["id"] == track_id:
			return t
	return TRACKS[0]


func _ready() -> void:
	_build_visuals()


func sample_count() -> int:
	return points.size()


func lateral_of(pos: Vector3, i: int) -> float:
	return (pos - points[i]).dot(rights[i])


func along_of(pos: Vector3, i: int) -> float:
	return (pos - points[i]).dot(tangents[i])


func heading_at(i: int) -> float:
	var t := tangents[i]
	return atan2(-t.x, -t.z)


## Índice da amostra mais próxima. Com hint >= 0 busca só numa janela local
## (barato e não "pula" para outro trecho da pista que passe perto).
func nearest_index(pos: Vector3, hint: int = -1, window: int = 12) -> int:
	var n := points.size()
	var best := 0
	var best_d := INF
	if hint < 0:
		for i in n:
			var d := pos.distance_squared_to(points[i])
			if d < best_d:
				best_d = d
				best = i
		return best
	for o in range(-window, window + 1):
		var i := wrapi(hint + o, 0, n)
		var d := pos.distance_squared_to(points[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func item_box_positions() -> Array:
	var out := []
	var n := points.size()
	for f in ITEM_ROWS:
		var i := int(n * float(f))
		for lat in [-6.0, -2.0, 2.0, 6.0]:
			out.append(points[i] + rights[i] * lat + Vector3.UP * 1.2)
	return out


# ---------------------------------------------------------------- path

func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	var v := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
	return Vector3(v.x, 0.0, v.y)


func _build_path() -> void:
	var cps: Array = def["points"]
	var m := cps.size()
	var dense: Array[Vector3] = []
	for i in m:
		var p0: Vector2 = cps[(i - 1 + m) % m]
		var p1: Vector2 = cps[i]
		var p2: Vector2 = cps[(i + 1) % m]
		var p3: Vector2 = cps[(i + 2) % m]
		for s in 40:
			dense.append(_cr(p0, p1, p2, p3, s / 40.0))
	var dn := dense.size()
	var cum := PackedFloat64Array()
	cum.append(0.0)
	for i in dn:
		cum.append(cum[i] + dense[i].distance_to(dense[(i + 1) % dn]))
	length = cum[dn]
	var n := int(roundf(length / SPACING))
	var step_len := length / n
	var j := 0
	for k in n:
		var d := k * step_len
		while j < dn - 1 and cum[j + 1] < d:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var f := 0.0 if seg <= 0.0 else (d - cum[j]) / seg
		points.append(dense[j].lerp(dense[(j + 1) % dn], f))
	bounds_min = Vector2(INF, INF)
	bounds_max = Vector2(-INF, -INF)
	for i in n:
		var t := (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
		tangents.append(t)
		rights.append(t.cross(Vector3.UP))
		var p := points[i]
		bounds_min = Vector2(minf(bounds_min.x, p.x), minf(bounds_min.y, p.z))
		bounds_max = Vector2(maxf(bounds_max.x, p.x), maxf(bounds_max.y, p.z))


# ---------------------------------------------------------------- visuals

func _build_visuals() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	for i in n:
		var road_c: Color = def["road"][(i / 4) % 2]
		_strip(st, i, -ROAD_HALF, ROAD_HALF, 0.03, 0.03, road_c)
		var curb_c: Color = def["curb"][(i / 2) % 2]
		_strip(st, i, ROAD_HALF, ROAD_HALF + CURB, 0.04, 0.04, curb_c)
		_strip(st, i, -ROAD_HALF - CURB, -ROAD_HALF, 0.04, 0.04, curb_c)
		var off_c: Color = def["offroad"]
		_strip(st, i, ROAD_HALF + CURB, WALL, 0.02, 0.02, off_c)
		_strip(st, i, -WALL, -ROAD_HALF - CURB, 0.02, 0.02, off_c)
		var wall_c: Color = def["wall"][(i / 3) % 2]
		# muro direito: face interna, topo, face externa
		_strip(st, i, WALL, WALL, 0.0, WALL_H, wall_c)
		_strip(st, i, WALL, WALL + WALL_T, WALL_H, WALL_H, wall_c)
		_strip(st, i, WALL + WALL_T, WALL + WALL_T, WALL_H, 0.0, wall_c)
		# muro esquerdo
		_strip(st, i, -WALL, -WALL, WALL_H, 0.0, wall_c)
		_strip(st, i, -WALL - WALL_T, -WALL, WALL_H, WALL_H, wall_c)
		_strip(st, i, -WALL - WALL_T, -WALL - WALL_T, 0.0, WALL_H, wall_c)
	_start_line(st)
	_pads_and_ramp(st)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Gfx.track_material()  # RF-162
	mi.name = "TrackMesh"
	add_child(mi)
	_build_ground()
	_build_arch()
	_build_trees()
	_build_scenery()


func _strip(st: SurfaceTool, i: int, la: float, lb: float, ya: float, yb: float, c: Color) -> void:
	var n := points.size()
	var k := (i + 1) % n
	var a0 := points[i] + rights[i] * la + Vector3.UP * ya
	var b0 := points[i] + rights[i] * lb + Vector3.UP * yb
	var a1 := points[k] + rights[k] * la + Vector3.UP * ya
	var b1 := points[k] + rights[k] * lb + Vector3.UP * yb
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


## RF-173: pórtico de largada com semáforo (Racing Kit) e o nome do jogo.
func _build_arch() -> void:
	var gantry := Gfx.prop(RACING + "overheadLights.glb", (ROAD_HALF + 3.0) * 2.0)
	gantry.name = "StartGantry"
	gantry.position = points[0]
	gantry.basis = Basis(Vector3.UP, heading_at(0))
	add_child(gantry)
	var box := Gfx.aabb_of(gantry)
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "CAR'MUNDON'GO!"
		lbl.font_size = 110
		lbl.pixel_size = 0.014
		lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.85, 0.2)
		lbl.position = Vector3(0, box.size.y + 1.2, 0)
		if side < 0:
			lbl.rotation.y = PI
		gantry.add_child(lbl)


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
		var i := nearest_index(p)
		if p.distance_to(points[i]) < WALL + 6.0:
			continue
		var s := rng.randf_range(0.8, 1.6)
		xforms.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p))
	var deco_color: Color = def["deco_color"]
	match def["deco"]:
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
	if ramp_idx < 0:
		return
	for k in RAMP_LEN:
		var i := (ramp_idx + k) % n
		var j := (i + 1) % n
		var y0 := RAMP_H * float(k) / RAMP_LEN
		var y1 := RAMP_H * float(k + 1) / RAMP_LEN
		var stripes := 6
		for s in stripes:
			var la := -ROAD_HALF + 2.0 * ROAD_HALF * s / stripes
			var lb := -ROAD_HALF + 2.0 * ROAD_HALF * (s + 1) / stripes
			var c := Color(1.0, 0.8, 0.1) if (s + k) % 2 == 0 else Color(0.1, 0.1, 0.12)
			_quad(st, points[i] + rights[i] * la + Vector3.UP * y0, points[i] + rights[i] * lb + Vector3.UP * y0,
				points[j] + rights[j] * lb + Vector3.UP * y1, points[j] + rights[j] * la + Vector3.UP * y1, c)
		# laterais
		for side in [-ROAD_HALF, ROAD_HALF]:
			_quad(st, points[i] + rights[i] * side, points[i] + rights[i] * side + Vector3.UP * y0,
				points[j] + rights[j] * side + Vector3.UP * y1, points[j] + rights[j] * side, Color(0.25, 0.25, 0.28))
	# face de trás (queda)
	var e := (ramp_idx + RAMP_LEN) % n
	_quad(st, points[e] - rights[e] * ROAD_HALF, points[e] + rights[e] * ROAD_HALF,
		points[e] + rights[e] * ROAD_HALF + Vector3.UP * RAMP_H, points[e] - rights[e] * ROAD_HALF + Vector3.UP * RAMP_H, Color(0.25, 0.25, 0.28))


# ---------------------------------------------------------------- cenário (RF-167)

var scenery_count := 0


func _build_scenery() -> void:
	_grandstand()
	_racing_props()
	_flags()
	_tire_stacks()
	_scatter()


func _clear_of_track(pos: Vector3, radius: float) -> bool:
	var i := nearest_index(pos)
	return Vector2(pos.x - points[i].x, pos.z - points[i].z).length() > WALL + radius


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
	var banner := Label3D.new()
	banner.text = "CAR'MUNDON'GO!"
	banner.font_size = 160
	banner.pixel_size = 0.02
	banner.outline_size = 24
	banner.modulate = Color(1.0, 0.85, 0.2)
	banner.position = Vector3(side * -1.9, 6.3, 0)
	banner.rotation.y = -PI / 2.0 * side
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
	var tries := 0
	while tufts.size() + rocks.size() < count and tries < 6000:
		tries += 1
		var i := rng.randi_range(0, points.size() - 1)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p: Vector3 = points[i] + rights[i] * side * rng.randf_range(WALL + 3.0, WALL + 55.0)
		if not _clear_of_track(p, 2.5):
			continue
		var yaw := rng.randf() * TAU
		if kind == "cheese":
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
	if kind == "cheese":
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
