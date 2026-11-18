extends RefCounted
## Modelos procedurais dos itens jogados na pista (RF-201..203).

const Gfx = preload("res://scripts/gfx.gd")
const CHEESE_MODEL := "res://assets/kenney/food/cheese.glb"


static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func bomb() -> Node3D:
	var root := Node3D.new()
	root.name = "bomba"
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	var mat := _mat(Color(0.08, 0.08, 0.08), 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05)
	mat.emission_energy_multiplier = 0.8
	_mi(root, m, mat, Vector3.ZERO)
	var fuse := CylinderMesh.new()
	fuse.top_radius = 0.05
	fuse.bottom_radius = 0.05
	fuse.height = 0.35
	_mi(root, fuse, _mat(Color(0.6, 0.45, 0.2)), Vector3(0.15, 0.55, 0), Vector3(0, 0, -0.5))
	return root


## RF-202: ratoeira de madeira com a barra de metal e uma isca de queijo.
static func mousetrap() -> Node3D:
	var root := Node3D.new()
	root.name = "ratoeira"
	var wood := _mat(Color(0.72, 0.5, 0.28), 0.8)
	var metal := _mat(Color(0.75, 0.76, 0.8), 0.25, 0.9)
	var board := BoxMesh.new()
	board.size = Vector3(1.0, 0.12, 1.6)
	_mi(root, board, wood, Vector3(0, 0.06, 0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.9, 0.05, 0.05)
	_mi(root, bar, metal, Vector3(0, 0.16, -0.55))
	_mi(root, bar, metal, Vector3(0, 0.16, 0.25))
	var side := BoxMesh.new()
	side.size = Vector3(0.05, 0.05, 0.8)
	_mi(root, side, metal, Vector3(-0.43, 0.16, -0.15))
	_mi(root, side, metal, Vector3(0.43, 0.16, -0.15))
	var bait := Gfx.prop(CHEESE_MODEL, 0.45)
	bait.position = Vector3(0, 0.12, 0.5)
	root.add_child(bait)
	return root


## RF-201: gato laranja procedural (corpo, cabeça, orelhas, rabo, olhos), olhando pra -Z.
static func cat() -> Node3D:
	var root := Node3D.new()
	root.name = "gato"
	var fur := _mat(Color(0.95, 0.55, 0.15), 0.85)
	var light := _mat(Color(1.0, 0.85, 0.65), 0.85)
	var dark := _mat(Color(0.05, 0.05, 0.05), 0.3)
	var green := _mat(Color(0.5, 1.0, 0.3), 0.2)
	green.emission_enabled = true
	green.emission = Color(0.4, 1.0, 0.2)
	green.emission_energy_multiplier = 1.4
	var body := CapsuleMesh.new()
	body.radius = 0.45
	body.height = 1.8
	_mi(root, body, fur, Vector3(0, 0.6, 0.2), Vector3(PI / 2, 0, 0))
	var head := SphereMesh.new()
	head.radius = 0.48
	head.height = 0.96
	_mi(root, head, fur, Vector3(0, 1.0, -0.85))
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.22
	muzzle.height = 0.44
	_mi(root, muzzle, light, Vector3(0, 0.88, -1.25), Vector3.ZERO, Vector3(1.3, 0.8, 0.8))
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.2
	ear.height = 0.4
	for x in [-0.26, 0.26]:
		_mi(root, ear, fur, Vector3(x, 1.45, -0.8), Vector3(0, 0, -x * 0.9))
		var eye := SphereMesh.new()
		eye.radius = 0.1
		eye.height = 0.2
		_mi(root, eye, green, Vector3(x * 0.7, 1.08, -1.25))
		_mi(root, eye, dark, Vector3(x * 0.7, 1.08, -1.32), Vector3.ZERO, Vector3(0.35, 0.9, 0.5))
	var leg := CylinderMesh.new()
	leg.top_radius = 0.12
	leg.bottom_radius = 0.12
	leg.height = 0.5
	for p in [Vector3(-0.28, 0.25, -0.35), Vector3(0.28, 0.25, -0.35), Vector3(-0.28, 0.25, 0.75), Vector3(0.28, 0.25, 0.75)]:
		_mi(root, leg, fur, p)
	var tail := CapsuleMesh.new()
	tail.radius = 0.1
	tail.height = 1.1
	_mi(root, tail, fur, Vector3(0, 1.0, 1.3), Vector3(deg_to_rad(-40), 0, 0))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.7, 0.04, 0.14)
	var stripe_mat := _mat(Color(0.75, 0.35, 0.08), 0.85)
	for z in [-0.2, 0.2, 0.6]:
		_mi(root, stripe, stripe_mat, Vector3(0, 1.035, z))
	return root
