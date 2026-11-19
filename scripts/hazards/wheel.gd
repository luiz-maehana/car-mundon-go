extends RefCounted
## RF-274: roda de queijo rolando de um lado pro outro da pista.

const R := 1.8


static func spawn(race: Node, h: Dictionary) -> void:
	var w := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = R
	wm.bottom_radius = R
	wm.height = 1.3
	wm.radial_segments = 20
	w.mesh = wm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.25)
	mat.roughness = 0.6
	w.material_override = mat
	var rind := MeshInstance3D.new()  # casca vermelha nas faces
	var rm := CylinderMesh.new()
	rm.top_radius = R * 0.98
	rm.bottom_radius = R * 0.98
	rm.height = 1.34
	rind.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.8, 0.12, 0.08)
	rind.material_override = rmat
	rind.scale = Vector3(0.7, 1.0, 0.7)
	w.add_child(rind)
	race.add_child(w)
	h["node"] = w
	h["roll"] = 0.0
	h["lat"] = 0.0


static func update(race: Node, h: Dictionary, can_drive: bool, _t_live: float, _n: int) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var lat: float = float(s.get("amp", 10.0)) * sin(TAU * (race.hazard_clock + float(s.get("phase", 0.0))) / float(s.get("period", 3.0)))
	h["roll"] = float(h["roll"]) + (lat - float(h["lat"])) / R
	h["lat"] = lat
	h["state"] = "on"
	var w: MeshInstance3D = h["node"]
	# cilindro deitado com o eixo na tangente da pista; rola pro lado
	var lying := Basis(Vector3.UP, t.heading_at(i)) * Basis(Vector3.RIGHT, PI / 2.0)
	w.basis = Basis(t.tangents[i], -float(h["roll"])) * lying
	w.position = t.points[i] + t.rights[i] * lat + Vector3.UP * R
	if can_drive:
		for k in race.karts:
			if Vector2(k.position.x - w.position.x, k.position.z - w.position.z).length() < R + 0.7 and k.position.y - (w.position.y - R) < 3.0:
				k.hit(1.0)


static func ahead(_race: Node, h: Dictionary, hi: int, _ds: int, out: Array) -> void:
	out.append({"id": 1000000 + hi * 100, "lat": float(h["lat"])})
