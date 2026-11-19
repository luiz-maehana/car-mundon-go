extends RefCounted
## RF-391: robô aspirador indo e voltando ao longo da pista (com um leve zigue-zague).

const Fx = preload("res://scripts/hazards/hazard_fx.gd")
const R := 2.0


static func spawn(race: Node, h: Dictionary) -> void:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.7
	cm.bottom_radius = 1.8
	cm.height = 0.7
	body.mesh = cm
	var m := Fx.flat(Color(0.15, 0.15, 0.18))
	m.metallic = 0.5
	m.roughness = 0.35
	body.material_override = m
	body.position.y = 0.4
	root.add_child(body)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.85
	rm.bottom_radius = 1.85
	rm.height = 0.2
	ring.mesh = rm
	ring.material_override = Fx.emissive(Color(0.25, 0.7, 1.0), 2.5)
	ring.position.y = 0.55
	root.add_child(ring)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.25
	em.height = 0.5
	eye.mesh = em
	eye.material_override = Fx.emissive(Color(1.0, 0.3, 0.2), 3.0)
	eye.position = Vector3(0, 0.85, -1.2)
	root.add_child(eye)
	race.add_child(root)
	h["node"] = root
	h["lat"] = float(h["spec"].get("lat", 0.0))


static func update(race: Node, h: Dictionary, can_drive: bool, _t_live: float, n: int) -> void:
	var s: Dictionary = h["spec"]
	var t = race.track
	var ph: float = TAU * (race.hazard_clock + float(s.get("phase", 0.0))) / float(s.get("period", 3.0))
	var fi: float = float(int(s["idx"])) + float(s.get("span", 12.0)) * sin(ph)
	var a := wrapi(int(floorf(fi)), 0, n)
	var b := (a + 1) % n
	var lat: float = float(s.get("lat", 0.0)) + 2.0 * sin(ph * 2.3)
	h["lat"] = lat
	h["state"] = "on"
	h["at"] = a
	var rv: Node3D = h["node"]
	rv.position = t.points[a].lerp(t.points[b], fi - floorf(fi)) + t.rights[a] * lat
	var fwd: Vector3 = t.tangents[a] * signf(cos(ph) + 0.0001)
	rv.rotation.y = atan2(-fwd.x, -fwd.z)
	if not can_drive:
		return
	for k in race.karts:
		if Fx.touches(k, rv.position, R, 2.0):
			k.hit(1.0)
			if k.is_player:
				race.sfx("bump")


static func ahead(_race: Node, h: Dictionary, hi: int, _ds: int, out: Array) -> void:
	out.append({"id": 1000000 + hi * 100, "lat": float(h["lat"])})
