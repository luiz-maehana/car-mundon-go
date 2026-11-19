extends RefCounted
## RF-271/273: labareda da grelha — brasa avisa (WARN s), depois o fogo sobe por "on" s.
## Interface de perigo: spawn(race, h) · update(race, h, can_drive, t_live, n) · ahead(race, h, hi, ds, out)

const Fx = preload("res://scripts/hazards/hazard_fx.gd")
const WARN := 0.6


static func spawn(race: Node, h: Dictionary) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var flames := []
	var embers := []
	for lat in s["lats"]:
		var base: Vector3 = t.points[i] + t.rights[i] * float(lat)
		var fl := Node3D.new()
		fl.position = base
		var outer := MeshInstance3D.new()
		var om := CylinderMesh.new()
		om.top_radius = 0.0
		om.bottom_radius = 1.0
		om.height = 3.2
		outer.mesh = om
		var omat := Fx.emissive(Color(1.0, 0.45, 0.08), 2.5)
		omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		omat.albedo_color.a = 0.85
		outer.material_override = omat
		outer.position.y = 1.6
		fl.add_child(outer)
		var inner := MeshInstance3D.new()
		var im := CylinderMesh.new()
		im.top_radius = 0.0
		im.bottom_radius = 0.5
		im.height = 2.0
		inner.mesh = im
		inner.material_override = Fx.emissive(Color(1.0, 0.9, 0.35), 4.0)
		inner.position.y = 1.0
		fl.add_child(inner)
		fl.visible = false
		race.add_child(fl)
		flames.append(fl)
		var em := MeshInstance3D.new()  # brasa que acende antes do fogo
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.05
		em.mesh = cm
		var emat := Fx.emissive(Color(1.0, 0.3, 0.05), 0.2)
		em.material_override = emat
		em.position = base + Vector3.UP * 0.1
		race.add_child(em)
		embers.append(emat)
	h["flames"] = flames
	h["embers"] = embers


static func update(race: Node, h: Dictionary, can_drive: bool, t_live: float, _n: int) -> void:
	var s: Dictionary = h["spec"]
	var period: float = s.get("period", 3.0)
	var on_dur: float = s.get("on", 1.0)
	var t := fmod(t_live + float(s.get("phase", 0.0)), period) if t_live >= 0.0 else -1.0
	var st := "off"
	if t >= 0.0 and t < WARN:
		st = "warn"
	elif t >= WARN and t < WARN + on_dur:
		st = "on"
	h["state"] = st
	var clock: float = race.hazard_clock
	for fl in h["flames"]:
		fl.visible = st == "on"
		if fl.visible:
			fl.scale = Vector3(1.0, 1.0 + 0.18 * sin(clock * 31.0 + fl.position.x), 1.0)
	for em in h["embers"]:
		em.emission_energy_multiplier = 3.0 if st == "on" else (1.2 + 1.2 * sin(clock * 25.0) if st == "warn" else 0.2)
	if st == "on" and can_drive:
		for fl in h["flames"]:
			for k in race.karts:
				var d := Vector2(k.position.x - fl.position.x, k.position.z - fl.position.z).length()
				if d < 1.9 and k.position.y - fl.position.y < 2.5:
					k.hit(1.0)


static func ahead(_race: Node, h: Dictionary, hi: int, _ds: int, out: Array) -> void:
	if h["state"] == "off":
		return
	var lats: Array = h["spec"]["lats"]
	for j in lats.size():
		out.append({"id": 1000000 + hi * 100 + j, "lat": float(lats[j])})
