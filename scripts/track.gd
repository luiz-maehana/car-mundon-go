extends Node3D
## Pista procedural. As pistas são dados (TRACKS, RF-120): nome, pontos de controle e tema.
## Linha central = spline Catmull-Rom fechada, reamostrada a cada SPACING metros.
## Tudo (grama, muro, progresso, IA) é resolvido pela distância lateral à linha central.

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
		"ground": Color(0.22, 0.42, 0.16), "offroad": Color(0.42, 0.55, 0.22),
		"road": [Color(0.2, 0.2, 0.22), Color(0.23, 0.23, 0.25)],
		"curb": [Color(0.85, 0.1, 0.1), Color(0.95, 0.95, 0.95)],
		"wall": [Color(0.15, 0.35, 0.9), Color(0.95, 0.95, 0.95)],
		"sky_top": Color(0.25, 0.5, 0.9), "sky_horizon": Color(0.7, 0.82, 0.95),
		"ambient": Color(0.62, 0.64, 0.7), "sun": [1.1, -55.0, Color(1, 1, 1)],
		"deco": "pine", "deco_color": Color(0.13, 0.42, 0.18),
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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic_specular = 0.15
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	_build_ground()
	_build_arch()
	_build_trees()


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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["ground"]
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(center.x, -0.02, center.y)
	add_child(mi)


func _build_arch() -> void:
	var arch := Node3D.new()
	arch.position = points[0]
	arch.rotation.y = heading_at(0)
	add_child(arch)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.1)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 7.0, 0.8)
		post.mesh = bm
		post.material_override = mat
		post.position = Vector3(side * (ROAD_HALF + 2.5), 3.5, 0)
		arch.add_child(post)
	var bar := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3((ROAD_HALF + 2.5) * 2.0 + 0.8, 1.8, 0.6)
	bar.mesh = bb
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.1, 0.1, 0.15)
	bar.material_override = bar_mat
	bar.position = Vector3(0, 7.0, 0)
	arch.add_child(bar)
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "CAR'MUNDON'GO!"
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.outline_size = 16
		lbl.modulate = Color(1.0, 0.85, 0.2)
		lbl.position = Vector3(0, 7.0, side * 0.32)
		if side < 0:
			lbl.rotation.y = PI
		arch.add_child(lbl)


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
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.35
			trunk.bottom_radius = 0.45
			trunk.height = 2.0
			trunk.material = _deco_mat(Color(0.4, 0.25, 0.12))
			var leaves := CylinderMesh.new()
			leaves.top_radius = 0.0
			leaves.bottom_radius = 2.4
			leaves.height = 5.0
			leaves.material = _deco_mat(deco_color)
			_multimesh(trunk, xforms, Vector3(0, 1.0, 0))
			_multimesh(leaves, xforms, Vector3(0, 4.3, 0))


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
