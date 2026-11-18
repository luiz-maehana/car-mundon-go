extends RefCounted
## RF-171: camundongo piloto feito em código, com o visual de cada amigo (`look` em characters.gd).
## Origem = assento; frente = -Z. build() devolve um Node3D; as peças do visual ficam nomeadas
## (Hair, Beard, Glasses, Headphones...) pra facilitar testes.

const SKIN_PINK := Color(1.0, 0.56, 0.62)


static func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func _sphere(r: float, segs := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = int(segs / 2.0)
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func build(look: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Mouse"
	var fur_c: Color = look.get("fur", Color(0.9, 0.75, 0.6))
	var hair_c: Color = look.get("hair_color", Color(0.1, 0.08, 0.07))
	var beard_c: Color = look.get("beard_color", hair_c)
	var fur := _mat(fur_c, 0.85)
	var fur_light := _mat(fur_c.lightened(0.3), 0.85)
	var pink := _mat(SKIN_PINK, 0.6)
	var hair := _mat(hair_c, 0.75)
	var beard := _mat(beard_c, 0.85)
	var shirt := _mat(look.get("shirt", Color(0.12, 0.12, 0.14)), 0.8)
	var white := _mat(Color(0.97, 0.97, 0.97), 0.4)
	var black := _mat(Color(0.03, 0.03, 0.04), 0.25)

	# corpo, braços no volante e rabo
	_add(root, _capsule(0.34, 0.85), shirt, Vector3(0, 0.42, 0))
	for x in [-1.0, 1.0]:
		_add(root, _capsule(0.1, 0.55), shirt, Vector3(x * 0.3, 0.55, -0.22), Vector3(deg_to_rad(-62), 0, -x * 0.35))
		_add(root, _sphere(0.11, 12), white, Vector3(x * 0.19, 0.4, -0.48))
	var tail := _capsule(0.05, 0.6)
	_add(root, tail, pink, Vector3(0, 0.18, 0.45), Vector3(deg_to_rad(70), 0, 0))
	_add(root, tail, pink, Vector3(0, 0.45, 0.72), Vector3(deg_to_rad(20), 0, 0))

	# cabeção
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.2, 0)
	root.add_child(head)
	_add(head, _sphere(0.5), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.95, 0.95))
	_add(head, _sphere(0.28), fur_light, Vector3(0, -0.1, -0.36), Vector3.ZERO, Vector3(1.25, 0.8, 0.85))
	_add(head, _sphere(0.085, 12), pink, Vector3(0, -0.03, -0.62))
	for x in [-1.0, 1.0]:
		_add(head, _sphere(0.12, 16), white, Vector3(x * 0.17, 0.13, -0.4), Vector3.ZERO, Vector3(1, 1.15, 0.6))
		_add(head, _sphere(0.065, 12), black, Vector3(x * 0.16, 0.12, -0.47))
		var hl := _add(head, _sphere(0.022, 8), _mat(Color(2, 2, 2)), Vector3(x * 0.14, 0.15, -0.51))
		(hl.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add(head, _box(Vector3(0.17, 0.04, 0.05)), hair, Vector3(x * 0.17, 0.29, -0.42), Vector3(0, 0, -x * 0.18))
		for k in [0.0, 1.0]:
			_add(head, _box(Vector3(0.42, 0.012, 0.012)), white, Vector3(x * 0.36, -0.06 - k * 0.06, -0.48), Vector3(0, x * 0.25, x * (0.12 - k * 0.22)))
		# orelhonas
		var ear := Node3D.new()
		ear.position = Vector3(x * 0.46, 0.42, 0.05)
		ear.rotation = Vector3(0, 0, -x * 0.35)
		head.add_child(ear)
		_add(ear, _sphere(0.4), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.22))
		_add(ear, _sphere(0.3), pink, Vector3(0, 0, -0.05), Vector3.ZERO, Vector3(1, 1, 0.18))

	_hair(head, look.get("hair", "short"), hair)
	_beard(head, look.get("beard", "none"), beard)
	_glasses(head, look.get("glasses", "none"), black)
	if look.get("headphones", false):
		var hp := Node3D.new()
		hp.name = "Headphones"
		hp.position = Vector3(0, 0.88, 0)
		root.add_child(hp)
		var band := TorusMesh.new()
		band.inner_radius = 0.3
		band.outer_radius = 0.38
		var hp_mat := _mat(look.get("headphones_color", Color(0.12, 0.15, 0.3)), 0.4)
		_add(hp, band, hp_mat, Vector3.ZERO)
		var cup := CylinderMesh.new()
		cup.top_radius = 0.13
		cup.bottom_radius = 0.13
		cup.height = 0.1
		for x in [-1.0, 1.0]:
			_add(hp, cup, hp_mat, Vector3(x * 0.3, 0.0, -0.14), Vector3(0, 0, PI / 2))
	return root


static func _hair(head: Node3D, kind: String, mat: Material) -> void:
	var g := Node3D.new()
	g.name = "Hair"
	head.add_child(g)
	var cap := SphereMesh.new()
	cap.radius = 0.53
	cap.height = 0.53
	cap.is_hemisphere = true
	_add(g, cap, mat, Vector3(0, 0.2, 0.1), Vector3(deg_to_rad(-24), 0, 0), Vector3(1.0, 0.7, 1.0))
	match kind:
		"messy":
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.13
			spike.height = 0.32
			var pts := [[-0.2, 0.5, -0.25, -0.5], [0.05, 0.55, -0.3, -0.2], [0.25, 0.48, -0.2, 0.4], [-0.3, 0.45, 0.05, -0.8], [0.32, 0.43, 0.08, 0.8], [0.0, 0.57, 0.05, 0.0]]
			for p in pts:
				_add(g, spike, mat, Vector3(p[0], p[1], p[2]), Vector3(deg_to_rad(-35), 0, p[3]))
		"curly":
			var curl := _sphere(0.15, 10)
			for i in 10:
				var a := TAU * i / 10.0
				_add(g, curl, mat, Vector3(cos(a) * 0.36, 0.46 + 0.05 * sin(a * 3.0), sin(a) * 0.3 - 0.05))
			_add(g, _sphere(0.2, 12), mat, Vector3(0, 0.6, 0.0))
		"long":
			_add(g, _capsule(0.42, 1.0), mat, Vector3(0, -0.05, 0.28), Vector3.ZERO, Vector3(1.05, 1.0, 0.55))
			for x in [-1.0, 1.0]:
				_add(g, _capsule(0.14, 0.75), mat, Vector3(x * 0.44, -0.12, -0.08), Vector3(0, 0, x * 0.1))
		_:
			pass  # "short": só a touca de cabelo


static func _beard(head: Node3D, kind: String, mat: Material) -> void:
	if kind == "none":
		return
	var g := Node3D.new()
	g.name = "Beard"
	head.add_child(g)
	match kind:
		"full":
			_add(g, _sphere(0.36), mat, Vector3(0, -0.26, -0.26), Vector3.ZERO, Vector3(1.15, 0.75, 0.85))
			_add(g, _box(Vector3(0.36, 0.06, 0.08)), mat, Vector3(0, -0.15, -0.55))  # bigode
		"goatee":
			_add(g, _sphere(0.17), mat, Vector3(0, -0.33, -0.42), Vector3.ZERO, Vector3(1.0, 1.2, 0.8))
			_add(g, _box(Vector3(0.34, 0.06, 0.08)), mat, Vector3(0, -0.15, -0.55))
		"stubble":
			var m: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.55
			_add(g, _sphere(0.33), m, Vector3(0, -0.24, -0.24), Vector3.ZERO, Vector3(1.12, 0.7, 0.85))


static func _glasses(head: Node3D, kind: String, black: Material) -> void:
	if kind == "none":
		return
	var g := Node3D.new()
	g.name = "Glasses"
	head.add_child(g)
	var z := -0.55
	if kind == "sun":
		var lens := CylinderMesh.new()
		lens.top_radius = 0.135
		lens.bottom_radius = 0.135
		lens.height = 0.04
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.04, 0.03)
		dark.metallic = 0.6
		dark.roughness = 0.08
		for x in [-1.0, 1.0]:
			_add(g, lens, dark, Vector3(x * 0.17, 0.13, z), Vector3(PI / 2, 0, 0))
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.1
		ring.outer_radius = 0.135
		for x in [-1.0, 1.0]:
			_add(g, ring, black, Vector3(x * 0.17, 0.13, z), Vector3(PI / 2, 0, 0))
	_add(g, _box(Vector3(0.1, 0.03, 0.03)), black, Vector3(0, 0.15, z))
	for x in [-1.0, 1.0]:
		_add(g, _box(Vector3(0.03, 0.03, 0.42)), black, Vector3(x * 0.31, 0.15, z + 0.2))
