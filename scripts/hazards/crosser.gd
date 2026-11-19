extends RefCounted
## RF-332/391: bicho (gato, vaca) ou bola de feno atravessando a pista de um lado pro outro.

const HazardModels = preload("res://scripts/hazard_models.gd")
const Fx = preload("res://scripts/hazards/hazard_fx.gd")
const CAT_SCALE := 2.6
const RADIUS := {"cat": 2.6, "cow": 3.0, "tumbleweed": 1.9}


static func spawn(race: Node, h: Dictionary) -> void:
	var node := model(String(h["spec"].get("model", "cat")))
	race.add_child(node)
	h["node"] = node
	h["lat"] = 0.0


static func update(race: Node, h: Dictionary, can_drive: bool, _t_live: float, _n: int) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var kind := String(s.get("model", "cat"))
	var ph: float = TAU * (race.hazard_clock + float(s.get("phase", 0.0))) / float(s.get("period", 3.0))
	var lat: float = float(s.get("amp", 6.0)) * sin(ph)
	h["lat"] = lat
	h["state"] = "on"
	var node: Node3D = h["node"]
	var dir: Vector3 = t.rights[i] * signf(cos(ph) + 0.0001)
	node.position = t.points[i] + t.rights[i] * lat + Vector3.UP * absf(sin(race.hazard_clock * 9.0)) * 0.3
	if kind == "tumbleweed":  # rola de lado
		node.position.y = t.points[i].y + 1.3
		node.rotation = Vector3(0.0, t.heading_at(i), -lat / 1.3)
	else:
		node.rotation.y = atan2(-dir.x, -dir.z)
	if not can_drive:
		return
	var r: float = RADIUS.get(kind, RADIUS["cat"])
	var ground: Vector3 = Vector3(node.position.x, t.points[i].y, node.position.z)
	for k in race.karts:
		if Fx.touches(k, ground, r, 2.5):
			k.hit(1.0)
			if k.is_player:
				race.sfx("meow" if kind == "cat" else "bump")


static func ahead(_race: Node, h: Dictionary, hi: int, _ds: int, out: Array) -> void:
	out.append({"id": 1000000 + hi * 100, "lat": float(h["lat"])})


## Modelo do atravessador: gato, vaca ou bola de feno.
static func model(kind: String) -> Node3D:
	if kind == "cat":
		var cat: Node3D = HazardModels.cat()
		cat.scale = Vector3.ONE * CAT_SCALE
		return cat
	var root := Node3D.new()
	if kind == "tumbleweed":
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.3
		sm.height = 2.6
		sm.radial_segments = 10
		sm.rings = 6
		ball.mesh = sm
		var m := Fx.flat(Color(0.62, 0.48, 0.25))
		m.roughness = 1.0
		ball.material_override = m
		root.add_child(ball)
		for k in 3:  # galhos em volta
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 1.25
			tm.outer_radius = 1.45
			ring.mesh = tm
			ring.material_override = Fx.flat(Color(0.45, 0.33, 0.16))
			ring.rotation = Vector3(k * 1.05, k * 0.7, 0.0)
			root.add_child(ring)
		return root
	# vaca: corpo branco com manchas pretas, cabeça, chifrinhos e pernas
	var white := Fx.flat(Color(0.95, 0.95, 0.93))
	var black := Fx.flat(Color(0.08, 0.08, 0.09))
	var pink := Fx.flat(Color(0.95, 0.6, 0.65))
	var parts := [
		[Vector3(2.2, 1.5, 3.6), Vector3(0, 2.1, 0), white], [Vector3(1.3, 1.2, 1.3), Vector3(0, 2.6, -2.3), white],
		[Vector3(1.0, 0.6, 0.5), Vector3(0, 2.2, -3.0), pink], [Vector3(1.0, 0.8, 1.2), Vector3(0.9, 2.4, 0.4), black],
		[Vector3(0.8, 0.7, 1.0), Vector3(-0.9, 2.0, -0.8), black],
	]
	for lx in [-0.75, 0.75]:
		for lz in [-1.3, 1.3]:
			parts.append([Vector3(0.4, 1.4, 0.4), Vector3(lx, 0.7, lz), white])
	for hx in [-0.5, 0.5]:
		parts.append([Vector3(0.15, 0.4, 0.15), Vector3(hx, 3.3, -2.3), black])
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[1]
		root.add_child(mi)
	return root
