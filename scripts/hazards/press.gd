extends RefCounted
## RF-274: prensa da fábrica — sobe, fica no alto, treme (aviso), desce com tudo e segura embaixo.

const RISE := 0.5
const WARN := 0.8
const SLAM := 0.2
const UP_Y := 7.0
const DOWN_Y := 0.75


static func spawn(race: Node, h: Dictionary) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var lat: Array = s["lat"]
	var wdt: float = absf(float(lat[1]) - float(lat[0]))
	var blk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(wdt, 1.5, 3.6)
	blk.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.47, 0.52)
	pm.metallic = 0.6
	pm.roughness = 0.4
	blk.material_override = pm
	blk.basis = Basis(Vector3.UP, t.heading_at(i))
	race.add_child(blk)
	var shadow := MeshInstance3D.new()
	var sm := PlaneMesh.new()
	sm.size = Vector2(wdt, 3.6)
	shadow.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0, 0, 0, 0.0)
	shadow.material_override = smat
	shadow.basis = blk.basis
	shadow.position = t.points[i] + t.rights[i] * (float(lat[0]) + float(lat[1])) * 0.5 + Vector3.UP * 0.09
	race.add_child(shadow)
	h["node"] = blk
	h["shadow"] = smat
	h["mid"] = (float(lat[0]) + float(lat[1])) * 0.5
	h["half"] = wdt * 0.5
	h["y"] = UP_Y


static func update(race: Node, h: Dictionary, can_drive: bool, _t_live: float, n: int) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var period: float = s.get("period", 3.0)
	var hold: float = s.get("down", 0.8)
	var up_time := maxf(0.4, period - RISE - WARN - SLAM - hold)
	var clock: float = race.hazard_clock
	var tt := fmod(clock + float(s.get("phase", 0.0)), period)
	var y := UP_Y
	var st := "up"
	var shade := 0.0
	if tt < RISE:
		y = lerpf(DOWN_Y, UP_Y, tt / RISE)
		st = "rise"
		shade = 0.6 * (1.0 - tt / RISE)
	elif tt < RISE + up_time:
		y = UP_Y
	elif tt < RISE + up_time + WARN:
		var f := (tt - RISE - up_time) / WARN
		y = lerpf(UP_Y, UP_Y - 1.2, f) + 0.08 * sin(clock * 60.0)
		st = "warn"
		shade = 0.25 + 0.35 * f
	elif tt < RISE + up_time + WARN + SLAM:
		var f := (tt - RISE - up_time - WARN) / SLAM
		y = lerpf(UP_Y - 1.2, DOWN_Y, f * f)
		st = "slam"
		shade = 0.6
	else:
		y = DOWN_Y
		st = "down"
		shade = 0.6
	h["state"] = st
	h["y"] = y
	h["shadow"].albedo_color.a = shade
	var blk: MeshInstance3D = h["node"]
	blk.position = t.points[i] + t.rights[i] * float(h["mid"]) + Vector3.UP * y
	if can_drive and y < 1.8:
		for k in race.karts:
			var along: float = (k.position - t.points[i]).dot(t.tangents[i])
			var near_idx: bool = absi(wrapi(k.track_idx - i, -n / 2, n / 2)) < 4
			if near_idx and absf(k.lateral - float(h["mid"])) < float(h["half"]) + 0.6 and absf(along) < 2.4 and k.spin_time <= 0.0:
				k.hit(1.4)
				race.shake(k, 0.6)


static func ahead(_race: Node, h: Dictionary, hi: int, _ds: int, out: Array) -> void:
	if h["state"] != "up":
		out.append({"id": 1000000 + hi * 100, "lat": float(h["mid"])})
