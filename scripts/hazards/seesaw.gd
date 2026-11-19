extends RefCounted
## RF-303: gangorra numa metade da pista. Ponta de trás no chão = rampa (lança o kart);
## ponta de trás no alto = parede (bate e roda). Anda sempre; só pega depois do VAI!

const HALF := 3.5        # meia tábua (m)
const PIVOT_Y := 0.8
const TILT := 0.23       # ponta encosta no chão
const RAMP_Y := 0.45     # ponta de trás abaixo disso = rampa


static func spawn(race: Node, h: Dictionary) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var lat: Array = s["lat"]
	var wdt: float = absf(float(lat[1]) - float(lat[0]))
	var mid: float = (float(lat[0]) + float(lat[1])) * 0.5
	var base_pos: Vector3 = t.points[i] + t.rights[i] * mid
	var yaw := Basis(Vector3.UP, t.heading_at(i))
	var fulcrum := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.9
	fm.height = PIVOT_Y
	fm.radial_segments = 4
	fulcrum.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.45, 0.95)
	fulcrum.material_override = fmat
	fulcrum.basis = yaw * Basis(Vector3.UP, PI / 4.0).scaled(Vector3(wdt * 0.5, 1.0, 0.8))
	fulcrum.position = base_pos + Vector3.UP * PIVOT_Y * 0.5
	race.add_child(fulcrum)
	var pivot := Node3D.new()
	pivot.position = base_pos + Vector3.UP * PIVOT_Y
	race.add_child(pivot)
	var plank := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(wdt, 0.3, HALF * 2.0)
	plank.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(1.0, 0.78, 0.2)
	plank.material_override = pmat
	pivot.add_child(plank)
	for e in [-1.0, 1.0]:  # alças vermelhas nas pontas
		var grip := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(wdt * 0.6, 0.7, 0.25)
		grip.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.9, 0.2, 0.2)
		grip.material_override = gmat
		grip.position = Vector3(0, 0.45, e * (HALF - 0.6))
		pivot.add_child(grip)
	h["node"] = pivot
	h["yaw"] = yaw
	h["mid"] = mid
	h["half"] = wdt * 0.5
	h["angle"] = 0.0


static func update(race: Node, h: Dictionary, can_drive: bool, _t_live: float, n: int) -> void:
	var s: Dictionary = h["spec"]
	var i: int = s["idx"]
	var t = race.track
	var ang: float = TILT * clampf(1.6 * sin(TAU * (race.hazard_clock + float(s.get("phase", 0.0))) / float(s.get("period", 3.0))), -1.0, 1.0)
	h["angle"] = ang
	var rear_y := PIVOT_Y - HALF * sin(ang)
	h["state"] = "ramp" if rear_y < RAMP_Y else "wall"
	var pv: Node3D = h["node"]
	pv.basis = (h["yaw"] as Basis) * Basis(Vector3.RIGHT, ang)
	if not can_drive:
		return
	for k in race.karts:
		if k.airborne or k.spin_time > 0.0:
			continue
		if absi(wrapi(k.track_idx - i, -n / 2, n / 2)) > 4 or absf(k.lateral - float(h["mid"])) > float(h["half"]) + 0.4:
			continue
		var along: float = (k.position - t.points[i]).dot(t.tangents[i])
		if along < -HALF - 0.8 or along > -HALF + 1.4:
			continue
		if h["state"] == "ramp":
			if k.speed > 6.0:
				k.airborne = true
				k.on_ramp = false
				k.position.y = k.ground + 0.4
				k.vy = 7.0 + k.speed * 0.12
				k.air_time = 0.0
				k.trick = false
				if k.is_player:
					race.sfx("drop")
		else:
			k.hit(1.0)
			k.position -= t.tangents[i] * 1.5
			race.shake(k, 0.4)


static func ahead(_race: Node, h: Dictionary, hi: int, ds: int, out: Array) -> void:
	if h["state"] == "wall" or ds < 6:
		out.append({"id": 1000000 + hi * 100, "lat": float(h["mid"])})
